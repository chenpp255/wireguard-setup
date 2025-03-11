#!/bin/bash

### WireGuard 服务器一键安装脚本 ###

set -e  # 遇到错误退出

WG_IF="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
IP_RANGE="10.0.0"
SERVER_IP="$IP_RANGE.1"

# 1. 安装 WireGuard
sudo apt update
sudo apt install -y wireguard openresolv

# 2. 生成服务器密钥
mkdir -p $WG_DIR && chmod 700 $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey

SERVER_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
SERVER_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 3. 配置 WireGuard 服务器
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = true

# 开启 NAT 转发
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens160 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens160 -j MASQUERADE

# 允许 IP 转发
PreUp = sysctl -w net.ipv4.ip_forward=1
EOF

# 4. 启用 IP 转发永久生效
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 5. 使 NAT 规则永久生效
iptables -t nat -A POSTROUTING -o ens160 -j MASQUERADE
iptables -A FORWARD -i wg0 -j ACCEPT
iptables-save | sudo tee /etc/iptables/rules.v4

# 6. 启动 WireGuard
systemctl enable wg-quick@$WG_IF
systemctl start wg-quick@$WG_IF

# 7. 创建客户端 IP 分配记录
if [ ! -f /etc/wireguard/used_ips ]; then
  echo "2" > /etc/wireguard/used_ips
fi

# 8. 显示服务器信息
echo "====================================="
echo "✅ 服务器安装完成！"
echo "🌍 服务器公钥: $SERVER_PUBLIC_KEY"
echo "⚡ 监听端口: $WG_PORT"
echo "🌐 分配的 IP 地址范围: $IP_RANGE.1/24"
echo "====================================="
