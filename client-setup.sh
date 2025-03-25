#!/bin/bash

### WireGuard 客户端一键安装脚本（自动生成密钥、注册并配置全流量代理，排除 SSH，自动获取网卡）###

set -e

WG_IF="wg0"
WG_DIR="/etc/wireguard"
SERVER_API="47.238.98.234"
WG_PORT="51820"

# 安装 WireGuard
sudo apt update
sudo apt install -y wireguard openresolv curl

# 创建配置目录
sudo mkdir -p $WG_DIR && sudo chmod 700 $WG_DIR

# 生成密钥
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey
CLIENT_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
CLIENT_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 注册到服务器并获取分配 IP（调用远程注册脚本）
echo "\n📡 正在向服务器注册客户端..."
REGISTER_RESPONSE=$(curl -s --max-time 10 --retry 3 --retry-delay 2 \
  -X POST "http://$SERVER_API:8000/register-client" \
  -d "pubkey=$CLIENT_PUBLIC_KEY")

if [[ -z "$REGISTER_RESPONSE" || "$REGISTER_RESPONSE" != *"Assigned-IP:"* ]]; then
  echo "❌ 注册失败，服务器无响应或格式错误"
  exit 1
fi

# 从响应中解析分配的 IP
CLIENT_IP=$(echo "$REGISTER_RESPONSE" | grep "Assigned-IP:" | awk '{print $2}')

# 自动获取默认网卡和网关
DEFAULT_IF=$(ip route get 1 | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}')
DEFAULT_GW=$(ip route | grep default | awk '{print $3}')
LOCAL_IP=$(ip -4 addr show $DEFAULT_IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# 写入 WireGuard 配置
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $CLIENT_IP/24
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 8.8.8.8

# SSH 流量走本地，其它走 VPN
PostUp = ip rule add from $LOCAL_IP table 128
PostUp = ip route add table 128 default via $DEFAULT_GW
PostUp = iptables -t mangle -A OUTPUT -p tcp --dport 22 -j MARK --set-mark 128
PostDown = ip rule delete from $LOCAL_IP table 128
PostDown = ip route delete table 128 default via $DEFAULT_GW
PostDown = iptables -t mangle -D OUTPUT -p tcp --dport 22 -j MARK --set-mark 128

[Peer]
PublicKey = loO9B8dlchzYw6gjfpUgPaEDGDXeT029GE6adN3F7Sc=
Endpoint = $SERVER_API:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# 启动 WireGuard
sudo systemctl enable wg-quick@$WG_IF
sudo systemctl start wg-quick@$WG_IF

# 测试连接
sleep 2
curl -s ifconfig.me || echo "❗ 检查代理是否生效"
