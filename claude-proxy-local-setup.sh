#!/bin/bash

###############################################################################
# Claude Code 中转代理 - 本地端配置脚本
#
# 用途：在本地电脑上配置 ANTHROPIC_BASE_URL 环境变量
# 使用：bash claude-proxy-local-setup.sh
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

###############################################################################
# 检测 Shell 类型
###############################################################################

detect_shell() {
    local shell_name=$(basename "$SHELL")
    local config_file=""

    case "$shell_name" in
        bash)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                config_file="$HOME/.bash_profile"
            else
                config_file="$HOME/.bashrc"
            fi
            ;;
        zsh)
            config_file="$HOME/.zshrc"
            ;;
        fish)
            config_file="$HOME/.config/fish/config.fish"
            ;;
        *)
            config_file="$HOME/.profile"
            ;;
    esac

    echo "$config_file"
}

###############################################################################
# 主要功能
###############################################################################

configure_env() {
    print_header "Claude Code 本地配置"

    # 获取 VPS IP
    echo "请输入你的 VPS IP 地址:"
    read -p "IP: " vps_ip

    if [[ -z "$vps_ip" ]]; then
        print_error "IP 地址不能为空"
        exit 1
    fi

    # 获取端口
    echo ""
    echo "请输入代理端口 (默认: 8080):"
    read -p "端口: " proxy_port
    proxy_port=${proxy_port:-8080}

    # 构建 URL
    local base_url="http://${vps_ip}:${proxy_port}"

    print_header "配置信息确认"
    echo "  VPS IP:     $vps_ip"
    echo "  代理端口:   $proxy_port"
    echo "  完整地址:   $base_url"
    echo ""
    read -p "确认配置？(y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "已取消配置"
        exit 1
    fi

    # 测试连接
    print_header "测试连接"
    print_info "正在测试代理连接..."

    if command -v curl &> /dev/null; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$base_url/v1/messages" 2>&1 || echo "000")
        if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
            print_success "连接测试成功 (HTTP $response)"
        else
            print_error "连接测试失败 (HTTP $response)"
            print_info "请检查 VPS IP 和端口是否正确"
            read -p "是否继续配置？(y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_info "未安装 curl，跳过连接测试"
    fi

    # 检测 Shell 配置文件
    print_header "配置环境变量"
    local config_file=$(detect_shell)
    local shell_name=$(basename "$SHELL")

    echo "检测到 Shell: $shell_name"
    echo "配置文件: $config_file"
    echo ""

    # 检查是否已存在配置
    if [ -f "$config_file" ] && grep -q "ANTHROPIC_BASE_URL" "$config_file"; then
        print_info "检测到已有配置，正在更新..."
        # 使用临时文件安全地替换
        local temp_file=$(mktemp)
        grep -v "ANTHROPIC_BASE_URL" "$config_file" > "$temp_file"
        mv "$temp_file" "$config_file"
    fi

    # 添加新配置
    echo "" >> "$config_file"
    echo "# Claude Code 中转代理配置 (自动添加于 $(date '+%Y-%m-%d %H:%M:%S'))" >> "$config_file"
    echo "export ANTHROPIC_BASE_URL=\"$base_url\"" >> "$config_file"

    print_success "环境变量已添加到 $config_file"

    # 立即生效
    export ANTHROPIC_BASE_URL="$base_url"
    print_success "当前终端环境变量已设置"

    # 显示完成信息
    print_header "配置完成"
    echo ""
    echo "🎉 配置成功！"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  下一步"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. 重新加载配置 (选择其一):"
    echo ""
    if [[ "$shell_name" == "bash" ]]; then
        echo "     source ~/.bashrc"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "     或 source ~/.bash_profile"
        fi
    elif [[ "$shell_name" == "zsh" ]]; then
        echo "     source ~/.zshrc"
    elif [[ "$shell_name" == "fish" ]]; then
        echo "     source ~/.config/fish/config.fish"
    else
        echo "     source $config_file"
    fi
    echo ""
    echo "     或者直接新开一个终端窗口"
    echo ""
    echo "  2. 验证配置:"
    echo "     echo \$ANTHROPIC_BASE_URL"
    echo ""
    echo "  3. 开始使用:"
    echo "     claude"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 提供取消配置的方法
    print_info "如需取消配置，编辑 $config_file 并删除相关行"
}

###############################################################################
# 主流程
###############################################################################

main() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Code 中转代理配置脚本"
    echo "  本地端配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    configure_env
}

# 运行主函数
main
