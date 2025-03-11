#!/bin/bash

### WireGuard 客户端一键安装脚本 ###

set -e  # 遇到错误退出

WG_IF="wg0"
WG_SERVER_IP="183.20.128.15"
WG_SERVER_PORT="51820"
WG_DIR="/etc/wireguard"
IP_RANGE="10.0.0"

# 1. 安装 WireGuard 和 resolvconf
sudo apt update
sudo apt install -y wireguard openresolv

# 2. 生成密钥
mkdir -p $WG_DIR && chmod 700 $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey

CLIENT_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
CLIENT_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 获取默认网卡名称
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}')
DEFAULT_GATEWAY=$(ip route | grep default | awk '{print $3}')

# 自动分配不重复的 IP
LAST_IP=$(grep -oP '(?<=AllowedIPs = 10.0.0.)\d+' /etc/wireguard/wg0.conf | sort -n | tail -1)
if [ -z "$LAST_IP" ]; then
  CLIENT_IP="$IP_RANGE.2"
else
  CLIENT_IP="$IP_RANGE.$((LAST_IP + 1))"
fi

# 3. 配置 WireGuard 客户端
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $CLIENT_IP/24
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 8.8.8.8

# 确保 SSH 22 端口走本地网络，其他流量走代理
PostUp = ip rule add from $CLIENT_IP table 128
PostUp = ip route add table 128 default via $DEFAULT_GATEWAY
PostUp = ip rule add dport 22 table 128
PostDown = ip rule delete from $CLIENT_IP table 128
PostDown = ip route delete table 128 default via $DEFAULT_GATEWAY
PostDown = ip rule delete dport 22 table 128

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
echo "✅ 客户端安装完成！"
echo "🌍 请在服务器上执行以下命令添加客户端："
echo "sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32"
echo "====================================="


