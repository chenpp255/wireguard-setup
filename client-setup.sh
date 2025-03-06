#!/bin/bash

### WireGuard 客户端一键安装脚本 ###

set -e  # 遇到错误退出

WG_IF="wg0"
WG_SERVER_IP="61.222.202.243"
WG_SERVER_PORT="51820"
CLIENT_IP="10.0.0.2"
WG_DIR="/etc/wireguard"

# 1. 安装 WireGuard 和 resolvconf
sudo apt update
sudo apt install -y wireguard openresolv

# 2. 生成密钥
mkdir -p $WG_DIR && chmod 700 $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey

CLIENT_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
CLIENT_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 3. 配置 WireGuard 客户端
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $CLIENT_IP/24
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 8.8.8.8

[Peer]
PublicKey = jmlOeivB5INpgiA4vYNdfKbsmoSweh5DKkNlK0S8kAw=
Endpoint = $WG_SERVER_IP:$WG_SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# 4. 启动 WireGuard
systemctl enable wg-quick@$WG_IF
systemctl start wg-quick@$WG_IF

# 5. 在中转服务器上添加客户端（手动执行）
echo "====================================="
echo "✅ WireGuard 客户端安装完成！"
echo "🌍 请在服务器上执行以下命令添加客户端："
echo "sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32"
echo "====================================="


