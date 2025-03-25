#!/bin/bash

# 简洁显示 WireGuard 客户端连接状态
WG_INTERFACE="wg0"

# 获取服务器公网 IP（可选）
PUBLIC_IP=$(curl -s ifconfig.me || echo "N/A")
echo "🌐 当前服务端公网 IP: $PUBLIC_IP"
echo "---"

# 检查是否存在 wg 接口
if ! sudo wg show $WG_INTERFACE &>/dev/null; then
  echo "❌ 未找到接口 $WG_INTERFACE，请确认 WireGuard 是否启动"
  exit 1
fi

# 输出头部
printf "%-45s %-18s %-22s %-10s\n" "[公钥]" "[内网 IP]" "[最近握手时间]" "[状态]"
echo "$(printf '%0.s-' {1..100})"

# 解析 wg show 输出
sudo wg show $WG_INTERFACE | awk '
  $1 == "peer:" { key=$2 }
  $1 == "allowed" && $2 == "ips:" { ip=$3 }
  $1 == "latest" && $2 == "handshake:" {
    handshake=$0
    time_str=substr($0, index($0,$3))
    status=(time_str ~ /ago/) ? "🟢 在线" : "⚫ 离线"
    printf "%-45s %-18s %-22s %-10s\n", key, ip, time_str, status
  }
' | sort

# 如果没有握手信息也显示
sudo wg show $WG_INTERFACE | awk '
  $1 == "peer:" { key=$2; have_handshake=0 }
  $1 == "allowed" && $2 == "ips:" { ip=$3 }
  $1 == "latest" && $2 == "handshake:" { have_handshake=1 }
  /^$/ {
    if (!have_handshake) {
      printf "%-45s %-18s %-22s %-10s\n", key, ip, "-", "⚪ 未连接"
    }
  }
'

exit 0
