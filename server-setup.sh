#!/bin/bash

### 服务器端一键安装脚本 ###

set -e  # 遇到错误退出

WG_IF="wg0"
WG_PORT="51820"
WG_NET="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
ETH_INTERFACE=$(ip route | grep default | awk '{print $5}')

# 1. 安装 WireGuard
sudo apt update
sudo apt install -y wireguard

# 2. 生成密钥
WG_DIR="/etc/wireguard"
mkdir -p $WG_DIR && chmod 700 $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey

SERVER_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
SERVER_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 3. 配置 WireGuard 服务器
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = true

# 开启 NAT 转发
PostUp = iptables -A FORWARD -i $WG_IF -j ACCEPT; iptables -t nat -A POSTROUTING -o $ETH_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_IF -j ACCEPT; iptables -t nat -D POSTROUTING -o $ETH_INTERFACE -j MASQUERADE

# 允许 IP 转发
PreUp = sysctl -w net.ipv4.ip_forward=1
EOF

# 4. 启动 WireGuard
systemctl enable wg-quick@$WG_IF
systemctl start wg-quick@$WG_IF

# 5. 确保 IP 转发永久生效
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 6. 确保 NAT 转发规则持久化
sudo iptables -t nat -A POSTROUTING -o $ETH_INTERFACE -j MASQUERADE

# 7. 输出服务器公钥
echo "====================================="
echo "✅ 服务器安装完成！"
echo "🌐 服务器公钥: $SERVER_PUBLIC_KEY"
echo "📍 服务器 IP: $(curl -s ifconfig.me)"
echo "====================================="
