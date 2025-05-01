#!/bin/bash
set -e

UUID="6f4027e4-bf44-4e11-9d03-2164c2218316"
SERVER_DOMAIN="aib.vast.pw"
SERVER_PORT=8443
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"

# 1. 安装依赖
apt update && apt install -y curl unzip iptables iproute2 resolvconf

# 2. 安装 Xray
mkdir -p $CONFIG_DIR
curl -L -o xray.zip "https://ghproxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -o xray.zip -d /usr/local/bin xray
chmod +x $XRAY_BIN
rm -f xray.zip

# 3. 写入配置文件
cat > $CONFIG_DIR/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$SERVER_DOMAIN",
            "port": $SERVER_PORT,
            "users": [
              {
                "id": "$UUID",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$SERVER_DOMAIN"
        }
      }
    },
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

# 4. 写入 systemd 服务文件
cat > /etc/systemd/system/xray-client.service <<EOF
[Unit]
Description=Xray Transparent Proxy
After=network.target

[Service]
ExecStart=$XRAY_BIN run -config $CONFIG_DIR/config.json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. 设置 iptables 重定向所有流量到 12345
iptables -t nat -N XRAY || true
iptables -t nat -F XRAY
iptables -t nat -A XRAY -d 127.0.0.1/32 -j RETURN
iptables -t nat -A XRAY -p tcp -j REDIRECT --to-ports 12345
iptables -t nat -A PREROUTING -p tcp -j XRAY

# 6. 启动服务
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray-client
systemctl restart xray-client

echo "✅ 透明代理已部署成功。所有 TCP 流量将转发到 Xray 中转服务器：$SERVER_DOMAIN:$SERVER_PORT"
