# Claude Code 中转代理解决方案

> 解决中国大陆使用 Claude Code 连接中转站的问题

---

## 📖 问题背景

在中国使用 Claude Code 时，即使本地通过 v2ray 能访问国外网站，但终端的 Claude Code 可能无法连接到中转站（如 `https://anyrouter.top`）。

**本方案通过在 VPS 上部署 nginx 反向代理，完美解决此问题。**

```
┌─────────┐      ┌──────────┐      ┌────────────┐      ┌──────────────┐
│  本地   │ ───> │ VPS      │ ───> │ 中转站     │ ───> │ Anthropic    │
│ Claude  │      │ (Nginx)  │      │ anyrouter  │      │ API          │
└─────────┘      └──────────┘      └────────────┘      └──────────────┘
```

---

## 🚀 快速开始

### 第一步：VPS 配置（一次性）

SSH 到你的 VPS，下载并运行配置脚本：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/i-rtfsc/router-proxy/main/claude-proxy-vps-setup.sh)"
```

**或者直接在 VPS 上运行（如果脚本已存在）：**

```bash
sudo ./claude-proxy-vps-setup.sh
```

脚本会自动完成所有配置，**记住输出的 VPS IP 和端口**。

---

### 第二步：本地配置

#### 方法 1：一行命令（推荐，临时使用）

```bash
# 替换 YOUR_VPS_IP 为你的实际 VPS IP
export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"
claude
```

#### 方法 2：永久配置

**macOS / Linux (Bash):**
```bash
echo 'export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"' >> ~/.bashrc
source ~/.bashrc
```

**macOS / Linux (Zsh):**
```bash
echo 'export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"' >> ~/.zshrc
source ~/.zshrc
```

**Windows PowerShell:**
```powershell
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'http://YOUR_VPS_IP:8080', 'User')
```

**Windows CMD:**
```cmd
setx ANTHROPIC_BASE_URL "http://YOUR_VPS_IP:8080"
```

#### 方法 3：使用配置脚本（交互式）

```bash
# 下载脚本到本地
curl -O https://raw.githubusercontent.com/i-rtfsc/router-proxy/main/claude-proxy-local-setup.sh
chmod +x claude-proxy-local-setup.sh

# 运行脚本（会提示输入 VPS IP）
./claude-proxy-local-setup.sh
```

---

### 第三步：验证并使用

```bash
# 验证环境变量
echo $ANTHROPIC_BASE_URL
# 应该输出：http://YOUR_VPS_IP:8080

# 测试连接
curl -I $ANTHROPIC_BASE_URL

# 开始使用
claude
```

---

## 📁 项目结构

```
├── README.md                          # 本文档（完整使用指南）
├── claude-proxy-vps-setup.sh          # VPS 端一键配置脚本
└── claude-proxy-local-setup.sh        # 本地端交互式配置脚本
```

---

## 🔧 VPS 端详细说明

### 自动配置脚本做了什么

`claude-proxy-vps-setup.sh` 会自动：

1. ✅ 安装 nginx（如果未安装）
2. ✅ 备份现有配置
3. ✅ 检查端口占用（默认 8080）
4. ✅ 配置 nginx 反向代理到 anyrouter.top
5. ✅ 处理端口冲突（注释旧的 stream 配置）
6. ✅ 启动并验证服务
7. ✅ 输出完整的使用说明

### 配置文件位置

- **主配置：** `/etc/nginx/nginx.conf`
- **代理配置：** `/etc/nginx/sites-available/anthropic-proxy`
- **访问日志：** `/var/log/nginx/access.log`
- **错误日志：** `/var/log/nginx/error.log`

### nginx 代理配置详解

```nginx
server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass https://anyrouter.top;
        proxy_ssl_server_name on;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;

        # 保留原始请求的所有头
        proxy_pass_request_headers on;

        # 只设置必要的头
        proxy_set_header Host anyrouter.top;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;

        # HTTP 1.1 支持（必需）
        proxy_http_version 1.1;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;

        # 关闭缓冲，支持流式传输
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
```

### 管理命令

```bash
# 查看服务状态
systemctl status nginx

# 重启服务
systemctl restart nginx

# 重新加载配置（不中断服务）
systemctl reload nginx

# 停止服务
systemctl stop nginx

# 查看实时日志
tail -f /var/log/nginx/access.log

# 查看错误日志
tail -f /var/log/nginx/error.log

# 测试配置语法
nginx -t

# 查看完整运行配置
nginx -T
```

如，当前我完整配置（`nginx -T`）：

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;

    text/mathml                           mml;
    text/plain                            txt;
    text/vnd.sun.j2me.app-descriptor      jad;
    text/vnd.wap.wml                      wml;
    text/x-component                      htc;

    image/png                             png;
    image/tiff                            tif tiff;
    image/vnd.wap.wbmp                    wbmp;
    image/x-icon                          ico;
    image/x-jng                           jng;
    image/x-ms-bmp                        bmp;
    image/svg+xml                         svg svgz;
    image/webp                            webp;

    application/font-woff                 woff;
    application/java-archive              jar war ear;
    application/json                      json;
    application/mac-binhex40              hqx;
    application/msword                    doc;
    application/pdf                       pdf;
    application/postscript                ps eps ai;
    application/rtf                       rtf;
    application/vnd.apple.mpegurl         m3u8;
    application/vnd.ms-excel              xls;
    application/vnd.ms-fontobject         eot;
    application/vnd.ms-powerpoint         ppt;
    application/vnd.wap.wmlc              wmlc;
    application/vnd.google-earth.kml+xml  kml;
    application/vnd.google-earth.kmz      kmz;
    application/x-7z-compressed           7z;
    application/x-cocoa                   cco;
    application/x-java-archive-diff       jardiff;
    application/x-java-jnlp-file          jnlp;
    application/x-makeself                run;
    application/x-perl                    pl pm;
    application/x-pilot                   prc pdb;
    application/x-rar-compressed          rar;
    application/x-redhat-package-manager  rpm;
    applica
    application/x-shockwave-flash         swf;
    application/x-stuffit                 sit;
    application/x-tcl                     tcl tk;
    application/x-x509-ca-cert            der pem crt;
    application/x-xpinstall               xpi;
    application/xhtml+xml                 xhtml;
    application/xspf+xml                  xspf;
    application/zip                       zip;

    application/octet-stream              bin exe dll;
    application/octet-stream              deb;
    application/octet-stream              dmg;
    application/octet-stream              iso img;
    application/octet-stream              msi msp msm;

    application/vnd.openxmlformats-officedocument.wordprocessingml.document    docx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet          xlsx;
    application/vnd.openxmlformats-officedocument.presentationml.presentation  pptx;

    audio/midi                            mid midi kar;
    audio/mpeg                            mp3;
    audio/ogg                             ogg;
    audio/x-m4a                           m4a;
    audio/x-realaudio                     ra;

    video/3gpp                            3gpp 3gp;
    video/mp2t                            ts;
    video/mp4                             mp4;
    video/mpeg                            mpeg mpg;
    video/quicktime                       mov;
    video/webm                            webm;
    video/x-flv                           flv;
    video/x-m4v                           m4v;
    video/x-mng                           mng;
    video/x-ms-asf                        asx asf;
    video/x-ms-wmv                        wmv;
    video/x-msvideo                       avi;
}

# configuration file /etc/nginx/sites-enabled/anthropic-proxy:
server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass https://anyrouter.top;
        proxy_ssl_server_name on;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;

        # 保留原始请求的所有头
        proxy_pass_request_headers on;

        # 只设置必要的头，其他都从客户端传递
        proxy_set_header Host anyrouter.top;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
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

```

> 如果你有自己的域名，可以把 `server_name _;` 改成 `server_name i-rtfsc.publicvm.com _;`


### 修改中转站地址

如果需要更换中转站：

```bash
# 编辑配置
sudo vim /etc/nginx/sites-available/anthropic-proxy

# 修改这一行：
proxy_pass https://你的新中转站.com;

# 测试配置
sudo nginx -t

# 重新加载
sudo systemctl reload nginx
```

---

## 💻 本地端详细说明

### 换新电脑快速配置

**最快方式（推荐）：**

新开终端，直接运行：

```bash
export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080" && claude
```

**永久配置（一次设置，处处使用）：**

```bash
# 检测你的 shell 类型
echo $SHELL

# Bash 用户
echo 'export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"' >> ~/.bashrc
source ~/.bashrc

# Zsh 用户
echo 'export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"' >> ~/.zshrc
source ~/.zshrc

# Fish 用户
echo 'set -x ANTHROPIC_BASE_URL "http://YOUR_VPS_IP:8080"' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

### 取消配置

```bash
# 临时取消（当前终端）
unset ANTHROPIC_BASE_URL

# 永久取消
# 编辑对应的配置文件，删除 ANTHROPIC_BASE_URL 那一行
vim ~/.bashrc  # 或 ~/.zshrc
source ~/.bashrc
```

---

## 🐛 故障排查

### 1. 连接超时

**症状：** `Connection timed out` 或 `Failed to connect`

**检查步骤：**

```bash
# 在本地测试 VPS 连接
ping YOUR_VPS_IP
telnet YOUR_VPS_IP 8080
# 或
nc -zv YOUR_VPS_IP 8080

# 在 VPS 上检查服务
systemctl status nginx
ss -tulpn | grep 8080

# 检查防火墙
sudo ufw status
```

**解决方案：**

```bash
# VPS 上开放端口
sudo ufw allow 8080/tcp

# 如果使用云服务商，检查安全组规则
# 确保 8080 端口对外开放
```

### 2. 403 错误

**症状：** `X-Tengine-Error: denied by http_custom`

**原因：** 中转站的反爬虫机制

**解决方案：**

1. 确认中转站 API key 是否有效
2. 可能是VPS IP被中转站屏蔽

### 3. 环境变量未生效

**症状：** Claude Code 还是连接官方 API

**检查：**

```bash
# 确认环境变量
echo $ANTHROPIC_BASE_URL

# 应该输出: http://YOUR_VPS_IP:8080
# 如果为空，说明未设置成功
```

**解决：**

```bash
# 确保在正确的 shell 配置文件中添加
# 重新加载配置
source ~/.bashrc  # 或 ~/.zshrc

# 或者新开一个终端窗口
```

### 4. nginx 启动失败

**症状：** `nginx.service failed`

**检查：**

```bash
# 查看详细错误
systemctl status nginx
journalctl -xeu nginx.service

# 常见问题：端口占用
ss -tulpn | grep 8080
```

**解决：**

```bash
# 如果端口被占用，重新运行配置脚本
# 脚本会提示你选择其他端口
sudo ./claude-proxy-vps-setup.sh
```

---

## 🔐 安全建议

### 1. 限制访问 IP

```bash
# 只允许特定 IP 访问 8080
sudo ufw allow from YOUR_HOME_IP to any port 8080

# 查看规则
sudo ufw status numbered

# 删除规则（如果设置错误）
sudo ufw delete [规则编号]
```

### 2. 使用 SSH 密钥认证

```bash
# 生成密钥对（本地）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 复制公钥到 VPS
ssh-copy-id root@YOUR_VPS_IP

# 在 VPS 上禁用密码登录
sudo vim /etc/ssh/sshd_config
# 设置: PasswordAuthentication no
sudo systemctl restart sshd
```

### 3. 定期更新系统

```bash
# VPS 上定期运行
sudo apt update && sudo apt upgrade -y
```

### 4. 监控日志

```bash
# 监控访问日志，防止滥用
tail -f /var/log/nginx/access.log

# 如果发现异常 IP，可以封禁
sudo ufw deny from 异常IP
```

---


## 📝 配置参数说明

### 可自定义参数

在 `claude-proxy-vps-setup.sh` 中可修改：

```bash
PROXY_PORT=8080              # 监听端口（默认 8080）
UPSTREAM_URL="anyrouter.top" # 中转站地址（默认 anyrouter.top）
```

### 超时参数

根据使用场景调整超时时间：

```nginx
proxy_connect_timeout 60s;   # 连接超时（默认 60 秒）
proxy_send_timeout 60s;      # 发送超时（默认 60 秒）
proxy_read_timeout 300s;     # 读取超时（默认 300 秒，适合长对话）
```

如果经常遇到超时，可以适当增加这些值。

---

## 🤔 常见问题

### Q1: 需要在每台电脑上配置吗？

**A:** 是的，但非常简单。只需在每台新电脑上设置环境变量：

```bash
export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"
```

或者永久配置到 shell 配置文件（~/.bashrc 或 ~/.zshrc）。

### Q2: VPS 需要什么配置？

**A:** 最低配置即可：
- CPU: 1 核
- 内存: 512MB
- 带宽: 1Mbps
- 系统: Ubuntu 18.04+ / Debian 10+

### Q3: 多人同时使用会不会乱？请求能正确返回吗？

**A:** **完全不会乱！每个人的请求都能正确返回。**

**工作原理：**
- Nginx 反向代理基于标准的 **TCP/HTTP 协议**
- 每个连接都是**独立的 TCP 连接**，有唯一的端口标识
- Nginx 会自动维护连接映射，确保响应返回给正确的发起者
- 这和访问一个网站是同样的机制，不会混淆

**简单比喻：**
就像多人同时访问 Google，每个人看到自己的搜索结果，不会看到别人的。

**技术细节：**
```
用户A → VPS:8080 (源端口: 50001) → anyrouter.top → 响应 → 端口50001 → 用户A ✓
用户B → VPS:8080 (源端口: 50002) → anyrouter.top → 响应 → 端口50002 → 用户B ✓
用户C → VPS:8080 (源端口: 50003) → anyrouter.top → 响应 → 端口50003 → 用户C ✓
```

每个连接有唯一的 **(源IP + 源端口)** 标识，操作系统和 Nginx 自动处理路由。

### Q4: 多少人同时使用会影响性能？

**A:** 取决于 VPS 配置和带宽。

**性能估算：**

| VPS 配置 | 并发用户 | 说明 |
|----------|---------|------|
| 1核 512MB 1Mbps | 1-3人 | 适合个人或小团队 |
| 1核 1GB 5Mbps | 5-10人 | 适合小团队 |
| 2核 2GB 10Mbps | 10-20人 | 适合中型团队 |
| 4核 4GB 50Mbps | 50+人 | 适合大团队 |

**主要瓶颈：**
1. **带宽**（最重要）
   - Claude API 响应通常 1-50KB
   - 长对话可能 100-500KB
   - 10人同时对话：约需 5-10Mbps

2. **内存**
   - Nginx 本身很轻量（~10-50MB）
   - 每个连接约占用 10-50KB
   - 100 个并发连接：约 5-10MB

3. **CPU**
   - Nginx 主要做 IO 转发，CPU 占用很低
   - 1 核足够处理数百个并发

**实际经验：**
- **1-5人**：最低配置即可（1核 512MB）
- **5-10人**：建议升级到 1核 1GB，带宽 5Mbps
- **10人以上**：建议 2核 2GB，带宽 10Mbps+

**监控性能：**
```bash
# VPS 上实时监控
# 查看连接数
ss -tan | grep :8080 | wc -l

# 查看带宽使用
iftop -i eth0

# 查看 CPU 和内存
htop
```

**优化建议：**
- 使用亚洲地区 VPS（延迟更低）
- 如果人多，可以配置多个 VPS 负载均衡
- 定期查看 nginx 日志，了解使用情况

### Q5: 会增加延迟吗？

**A:** 会有轻微延迟（取决于 VPS 位置）：
- 新加坡 VPS → 中国：约 50-100ms
- 美国 VPS → 中国：约 150-250ms

推荐使用亚洲地区的 VPS。

### Q6: 配置会被覆盖吗？

**A:** 不会。脚本有备份机制，每次运行前会自动备份配置到：

```
/root/nginx-backup-YYYYMMDD-HHMMSS/
```

### Q7: 如何回滚配置？

**A:** 使用备份恢复：

```bash
# 查看备份
ls -la /root/nginx-backup-*

# 恢复备份
backup_dir="/root/nginx-backup-20251126-083000"  # 替换为你的备份目录
sudo cp "$backup_dir/nginx.conf" /etc/nginx/
sudo cp -r "$backup_dir/sites-available"/* /etc/nginx/sites-available/
sudo systemctl reload nginx
```

### Q8: 支持多个中转站吗？

**A:** 支持。可以配置多个端口，分别代理到不同中转站：

```nginx
# 8080 → anyrouter.top
server {
    listen 8080;
    proxy_pass https://anyrouter.top;
    ...
}

# 8081 → 另一个中转站
server {
    listen 8081;
    proxy_pass https://another-proxy.com;
    ...
}
```

### Q9: Windows 用户怎么配置？

**A:**

**PowerShell（推荐）：**
```powershell
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'http://YOUR_VPS_IP:8080', 'User')
```

重启终端生效。

**CMD：**
```cmd
setx ANTHROPIC_BASE_URL "http://YOUR_VPS_IP:8080"
```

---

## 🎓 工作原理

### 请求流程

```
1. 本地 Claude Code 发送请求
   ↓ (HTTP)
2. VPS Nginx 接收请求 (8080)
   ↓ (HTTPS)
3. 转发到中转站 (anyrouter.top:443)
   ↓ (HTTPS)
4. 中转站转发到 Anthropic API
   ↓
5. 响应原路返回
```

### 为什么有效？

1. **绕过本地网络限制**：请求通过 VPS 发出，避免本地网络对 HTTPS 的检测
2. **保留请求特征**：Nginx 透传所有请求头，中转站看到的是真实请求
3. **稳定性**：VPS 24/7 在线，不受本地网络波动影响

---

## 📦 文件说明

### claude-proxy-vps-setup.sh

**功能：** VPS 端自动化配置脚本

**特点：**
- ✅ 完全自动化，无需手动操作
- ✅ 幂等性，可安全重复运行
- ✅ 自动备份，防止配置丢失
- ✅ 错误检测，智能处理端口冲突
- ✅ 彩色输出，清晰友好

**使用：**
```bash
sudo ./claude-proxy-vps-setup.sh
```

### claude-proxy-local-setup.sh

**功能：** 本地端交互式配置脚本

**特点：**
- ✅ 交互式引导，适合新手
- ✅ 自动检测 Shell 类型
- ✅ 测试连接可用性
- ✅ 自动更新配置文件

**使用：**
```bash
./claude-proxy-local-setup.sh
```

---

## 🌟 最佳实践

### 1. 开发环境

为不同项目使用不同配置：

```bash
# 在项目目录创建 .envrc
cat > .envrc << 'EOF'
export ANTHROPIC_BASE_URL="http://YOUR_VPS_IP:8080"
EOF

# 使用 direnv 自动加载（需先安装 direnv）
direnv allow
```

### 2. 团队共享

团队成员共享同一个 VPS 代理：

```bash
# 每个成员设置相同的环境变量
export ANTHROPIC_BASE_URL="http://TEAM_VPS_IP:8080"

# 在 VPS 上限制访问 IP
sudo ufw allow from OFFICE_IP to any port 8080
```

### 3. 备用方案

配置多个中转站作为备份：

```bash
# 主中转站
export ANTHROPIC_BASE_URL="http://VPS1_IP:8080"

# 备用中转站（如果主站不可用）
# export ANTHROPIC_BASE_URL="http://VPS2_IP:8080"
```

---

## 📊 性能优化

### 1. nginx worker 进程数

根据 VPS CPU 核心数调整：

```nginx
# /etc/nginx/nginx.conf
worker_processes auto;  # 自动检测（推荐）
# 或手动设置
worker_processes 2;     # 2 核 CPU
```

### 2. 连接数限制

```nginx
events {
    worker_connections 1024;  # 每个 worker 的最大连接数
}
```

### 3. 启用 keepalive

```nginx
# 保持到上游的连接
upstream anyrouter {
    server anyrouter.top:443;
    keepalive 32;
}

server {
    location / {
        proxy_pass https://anyrouter;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

---

## 🔄 更新日志

- **2025-11-26**: 初始版本
  - ✅ 完整的 VPS 配置脚本
  - ✅ 本地配置脚本
  - ✅ 完整文档

---

## 📄 许可证

MIT License - 自由使用和修改

---

## 🙏 致谢

- [Anthropic](https://www.anthropic.com/) - Claude AI
- [Nginx](https://nginx.org/) - 高性能 Web 服务器

---

## 📮 支持

遇到问题？

1. 查看 [故障排查](#-故障排查) 章节
2. 检查 nginx 日志：`tail -f /var/log/nginx/error.log`
3. 提交 Issue（如果使用 GitHub 托管）

