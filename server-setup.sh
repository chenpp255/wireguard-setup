#!/bin/bash

### WireGuard 服务器一键安装脚本（带永久 NAT、IP 转发 和 客户端自动注册）###

set -e

WG_IF="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
IP_RANGE="10.0.0"
SERVER_IP="$IP_RANGE.1"
INTERFACE=$(ip route | grep default | awk '{print $5}')

# 安装 WireGuard 和必要工具
sudo apt update
sudo apt install -y wireguard iptables iptables-persistent openresolv

# 生成密钥对
mkdir -p $WG_DIR && chmod 700 $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey
SERVER_PRIVATE_KEY=$(cat $WG_DIR/privatekey)
SERVER_PUBLIC_KEY=$(cat $WG_DIR/publickey)

# 写入 WireGuard 配置
cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = true

PostUp = iptables -A FORWARD -i $WG_IF -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_IF -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
PreUp = sysctl -w net.ipv4.ip_forward=1
EOF

# 永久启用 IP 转发
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 添加 NAT 转发规则并保存
sudo iptables -A FORWARD -i $WG_IF -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
sudo systemctl enable netfilter-persistent
sudo systemctl restart netfilter-persistent

# 启动 WireGuard 服务
sudo systemctl enable wg-quick@$WG_IF
sudo systemctl start wg-quick@$WG_IF

# 初始化已分配 IP 文件（用于客户端分配）
if [ ! -f /etc/wireguard/used_ips ]; then
  echo "2" > /etc/wireguard/used_ips
fi

# 添加 register-client.sh 用于注册客户端
cat > /usr/local/bin/register-client.sh <<'EOF'
#!/bin/bash
set -e

WG_IF="wg0"
WG_CONF="/etc/wireguard/$WG_IF.conf"
WG_DIR="/etc/wireguard"
IP_RANGE="10.0.0"

if [ -z "$1" ]; then
  echo "❌ 请输入客户端公钥作为参数"
  exit 1
fi
CLIENT_PUBKEY="$1"

if [ ! -f /etc/wireguard/used_ips ]; then
  echo "2" > /etc/wireguard/used_ips
fi

LAST_IP=$(cat /etc/wireguard/used_ips)
CLIENT_IP="$IP_RANGE.$LAST_IP"
echo "$((LAST_IP + 1))" > /etc/wireguard/used_ips

# 添加 Peer
wg set $WG_IF peer "$CLIENT_PUBKEY" allowed-ips "$CLIENT_IP/32"

# 如果 config 文件未包含此 Peer，也追加（仅用于参考，实际控制用 wg）
grep -q "$CLIENT_PUBKEY" "$WG_CONF" || echo -e "\n[Peer]\nPublicKey = $CLIENT_PUBKEY\nAllowedIPs = $CLIENT_IP/32" >> "$WG_CONF"

echo "✅ 已注册客户端: $CLIENT_PUBKEY"
echo "📡 分配 IP: $CLIENT_IP"
EOF

chmod +x /usr/local/bin/register-client.sh

# 输出服务器信息
echo "====================================="
echo "✅ WireGuard 服务器部署完成"
echo "🌐 服务地址: $SERVER_IP"
echo "🔑 公钥: $SERVER_PUBLIC_KEY"
echo "📡 监听端口: $WG_PORT"
echo "📥 客户端注册命令: register-client.sh <客户端公钥>"
echo "====================================="

