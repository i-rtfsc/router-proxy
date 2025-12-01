#!/bin/bash

###############################################################################
# Claude Code 中转代理 - VPS 端一键配置脚本
#
# 用途：在 VPS 上配置 nginx 反向代理，转发 Claude Code 请求到中转站
# 使用：sudo bash claude-proxy-vps-setup.sh
###############################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量（可修改）
PROXY_PORT=8080
UPSTREAM_URL="anyrouter.top"
NGINX_CONFIG_PATH="/etc/nginx/sites-available/anthropic-proxy"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/anthropic-proxy"

###############################################################################
# 辅助函数
###############################################################################

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用 root 权限运行此脚本"
        echo "使用命令: sudo bash $0"
        exit 1
    fi
}

###############################################################################
# 主要功能函数
###############################################################################

# 1. 检查并安装 nginx
install_nginx() {
    print_header "步骤 1: 安装 Nginx"

    if command -v nginx &> /dev/null; then
        print_info "Nginx 已安装，版本: $(nginx -v 2>&1 | cut -d'/' -f2)"
    else
        print_info "正在安装 Nginx..."
        apt update -qq
        apt install -y nginx
        print_success "Nginx 安装完成"
    fi
}

# 2. 备份现有配置
backup_config() {
    print_header "步骤 2: 备份配置"

    local backup_dir="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    if [ -f /etc/nginx/nginx.conf ]; then
        cp /etc/nginx/nginx.conf "$backup_dir/"
        print_success "已备份 nginx.conf 到 $backup_dir"
    fi

    if [ -d /etc/nginx/sites-available ]; then
        cp -r /etc/nginx/sites-available "$backup_dir/"
        print_success "已备份 sites-available 到 $backup_dir"
    fi
}

# 3. 检查端口占用
check_port() {
    print_header "步骤 3: 检查端口占用"

    if ss -tulpn | grep -q ":$PROXY_PORT "; then
        print_error "端口 $PROXY_PORT 已被占用："
        ss -tulpn | grep ":$PROXY_PORT "

        read -p "是否要使用其他端口？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "请输入新端口号: " PROXY_PORT
            print_info "使用端口: $PROXY_PORT"
        else
            print_error "无法继续配置，请先释放端口 $PROXY_PORT"
            exit 1
        fi
    else
        print_success "端口 $PROXY_PORT 可用"
    fi
}

# 4. 配置 nginx.conf
configure_nginx_main() {
    print_header "步骤 4: 配置 Nginx 主配置"

    # 检查是否有冲突的 stream 配置
    if grep -q "listen.*8443" /etc/nginx/nginx.conf 2>/dev/null; then
        print_info "发现端口 8443 配置，正在注释..."
        sed -i '/^stream {/,/^}/s/^/# /' /etc/nginx/nginx.conf
        print_success "已注释旧的 stream 配置"
    fi

    # 确保 http 块包含 sites-enabled
    if ! grep -q "include.*sites-enabled" /etc/nginx/nginx.conf; then
        print_info "添加 sites-enabled 包含..."
        sed -i '/http {/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
        print_success "已添加 sites-enabled 配置"
    fi
}

# 5. 创建反向代理配置
create_proxy_config() {
    print_header "步骤 5: 创建反向代理配置"

    cat > "$NGINX_CONFIG_PATH" <<EOF
server {
    listen $PROXY_PORT;
    server_name _;

    location / {
        proxy_pass https://$UPSTREAM_URL;
        proxy_ssl_server_name on;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;

        # 保留原始请求的所有头
        proxy_pass_request_headers on;

        # 只设置必要的头，其他都从客户端传递
        proxy_set_header Host $UPSTREAM_URL;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Connection "";

        # HTTP 1.1 支持
        proxy_http_version 1.1;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;

        # 缓冲设置
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

    print_success "反向代理配置已创建: $NGINX_CONFIG_PATH"
}

# 6. 启用配置
enable_config() {
    print_header "步骤 6: 启用配置"

    # 删除默认配置
    if [ -L /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
        print_success "已删除默认配置"
    fi

    # 创建软链接
    ln -sf "$NGINX_CONFIG_PATH" "$NGINX_ENABLED_PATH"
    print_success "已启用反向代理配置"
}

# 7. 测试并重启 nginx
restart_nginx() {
    print_header "步骤 7: 测试并重启 Nginx"

    print_info "测试配置文件..."
    if nginx -t; then
        print_success "配置文件测试通过"
    else
        print_error "配置文件测试失败"
        exit 1
    fi

    print_info "重启 Nginx..."
    systemctl restart nginx
    systemctl enable nginx

    if systemctl is-active --quiet nginx; then
        print_success "Nginx 启动成功"
    else
        print_error "Nginx 启动失败"
        journalctl -xeu nginx.service --no-pager | tail -20
        exit 1
    fi
}

# 8. 验证配置
verify_setup() {
    print_header "步骤 8: 验证配置"

    sleep 2  # 等待服务完全启动

    # 检查端口监听
    if ss -tulpn | grep -q ":$PROXY_PORT "; then
        print_success "端口 $PROXY_PORT 正在监听"
    else
        print_error "端口 $PROXY_PORT 未监听"
        exit 1
    fi

    # 测试代理
    print_info "测试代理连接..."
    local response=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://localhost:$PROXY_PORT/v1/messages 2>&1 || echo "000")

    if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
        print_success "代理响应正常 (HTTP $response)"
    else
        print_error "代理响应异常 (HTTP $response)"
        print_info "这可能是正常的，因为需要有效的 API 请求才能完全测试"
    fi
}

# 9. 显示配置信息
show_summary() {
    print_header "配置完成"

    local public_ip=$(curl -s ifconfig.me || echo "无法获取")

    echo ""
    echo "🎉 Claude Code 中转代理配置成功！"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  VPS 信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  公网 IP:    $public_ip"
    echo "  监听端口:   $PROXY_PORT"
    echo "  上游地址:   https://$UPSTREAM_URL"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  本地配置 (在你的电脑上执行)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  临时配置:"
    echo "  export ANTHROPIC_BASE_URL=\"http://$public_ip:$PROXY_PORT\""
    echo "  claude"
    echo ""
    echo "  永久配置 (bash):"
    echo "  echo 'export ANTHROPIC_BASE_URL=\"http://$public_ip:$PROXY_PORT\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
    echo ""
    echo "  永久配置 (zsh):"
    echo "  echo 'export ANTHROPIC_BASE_URL=\"http://$public_ip:$PROXY_PORT\"' >> ~/.zshrc"
    echo "  source ~/.zshrc"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  管理命令"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  查看状态:   systemctl status nginx"
    echo "  重启服务:   systemctl restart nginx"
    echo "  查看日志:   tail -f /var/log/nginx/access.log"
    echo "  编辑配置:   vim $NGINX_CONFIG_PATH"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "配置文档已保存到: /root/code/claude-proxy-setup.md"
    echo ""
}

###############################################################################
# 主流程
###############################################################################

main() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Code 中转代理配置脚本"
    echo "  VPS 端配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_root
    install_nginx
    backup_config
    check_port
    configure_nginx_main
    create_proxy_config
    enable_config
    restart_nginx
    verify_setup
    show_summary
}

# 运行主函数
main
