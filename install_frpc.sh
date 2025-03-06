#!/bin/bash

# 设置 FRP 版本
FRP_VERSION="0.54.0"
INSTALL_DIR="/opt/frp"
CONFIG_FILE="${INSTALL_DIR}/frpc.toml"
SYSTEMD_SERVICE="/etc/systemd/system/frpc.service"

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "请使用 root 权限运行此脚本"
   exit 1
fi

# 服务器 IP（默认你的服务器 47.113.224.6）
DEFAULT_SERVER_IP="47.113.224.6"

# 交互式输入服务器 IP（默认 47.113.224.6）
read -p "请输入你的 FRP 服务器 IP（回车使用默认: $DEFAULT_SERVER_IP）: " SERVER_IP
SERVER_IP=${SERVER_IP:-$DEFAULT_SERVER_IP}

# 交互式输入 FRP 服务器端口
read -p "请输入 FRP 服务器端口（默认 7000）: " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-7000}

# 自动获取未使用的 50000+ 端口
get_random_port() {
    while :; do
        RANDOM_PORT=$((RANDOM % 10000 + 50000))  # 生成 50000 - 60000 之间的随机端口
        if ! ss -tuln | awk '{print $4}' | grep -q ":$RANDOM_PORT$"; then
            echo "$RANDOM_PORT"
            return
        fi
    done
}

REMOTE_PORT=$(get_random_port)
echo "已分配远程端口: $REMOTE_PORT"

# 创建目录
mkdir -p "$INSTALL_DIR"

# 下载并解压 FRP
echo "正在下载 FRP v${FRP_VERSION}..."
wget -qO- "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" | tar xz --strip-components=1 -C "$INSTALL_DIR"

# 生成 frpc.toml 配置文件
cat > "$CONFIG_FILE" <<EOF
[common]
server_addr = "$SERVER_IP"
server_port = $SERVER_PORT

[[proxies]]
name = "ssh"
type = "tcp"
local_ip = "127.0.0.1"
local_port = 22
remote_port = $REMOTE_PORT
EOF

echo "frpc.toml 配置文件已创建在 $CONFIG_FILE"

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

echo "frpc 安装完成，并已启动！"
echo "已分配的 SSH 远程端口: $REMOTE_PORT"
echo "运行 'systemctl status frpc' 查看状态"
