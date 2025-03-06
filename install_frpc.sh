#!/bin/bash

# 设置 FRP 版本
FRP_VERSION="0.54.0"
INSTALL_DIR="/opt/frp"
CONFIG_FILE="${INSTALL_DIR}/frpc.toml"
SYSTEMD_SERVICE="/etc/systemd/system/frpc.service"

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用 root 权限运行此脚本！"
   exit 1
fi

# 如果系统没有安装 dos2unix，则自动安装
if ! command -v dos2unix >/dev/null 2>&1; then
    echo "📌 检测到 dos2unix 未安装，正在安装..."
    apt update && apt install -y dos2unix
fi

# FRP 服务器 IP 和端口
SERVER_IP="47.113.224.6"
SERVER_PORT=7000
AUTH_TOKEN="vast.99"

# 生成随机未使用的 50000+ 端口
get_random_port() {
    while :; do
        RANDOM_PORT=$((RANDOM % 10000 + 50000))  # 50000-60000 之间
        if ! ss -tuln | awk '{print $4}' | grep -q ":$RANDOM_PORT\$"; then
            echo "$RANDOM_PORT"
            return
        fi
    done
}

REMOTE_PORT=$(get_random_port)
echo "✅ 已分配远程端口: $REMOTE_PORT"

# 创建目录
mkdir -p "$INSTALL_DIR"

# 下载并解压 FRP
echo "📥 正在下载 FRP v${FRP_VERSION}..."
wget -qO- "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" | tar xz --strip-components=1 -C "$INSTALL_DIR"

# 生成 frpc.toml 配置文件
cat > "$CONFIG_FILE" <<EOF
#frpc.toml
transport.tls.enable = true
server_addr = "$SERVER_IP"
server_port = $SERVER_PORT
auth.token = "$AUTH_TOKEN"

[[proxies]]
name = "ssh"
type = "tcp"
local_ip = "127.0.0.1"
local_port = 22
remote_port = $REMOTE_PORT
EOF

echo "✅ frpc.toml 配置文件已创建在 $CONFIG_FILE"

# 转换配置文件为 Linux 格式（防止 Windows 换行符）
dos2unix "$CONFIG_FILE"

# 创建 systemd 服务
cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Frp Client
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/frpc -c ${CONFIG_FILE}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动 frpc
systemctl daemon-reload
systemctl enable frpc
systemctl restart frpc

echo "🎉 frpc 安装完成，并已启动！"
echo "✅ 远程端口已分配: $REMOTE_PORT"
echo "✅ 运行 'systemctl status frpc' 查看状态"

