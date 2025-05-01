#!/bin/bash
set -e

# ===== 基本参数 =====
XRAY_VERSION="v1.8.4"
UUID="6f4027e4-bf44-4e11-9d03-2164c2218316"
SERVER_DOMAIN="aib.vast.pw"
SERVER_PORT=8443
TUN_INTERFACE="utun"
CONFIG_PATH="/usr/local/etc/xray"

# ===== 安装依赖 =====
echo "[1/6] 安装依赖..."
apt update && apt install -y curl unzip iproute2 iptables resolvconf

# ===== 下载并安装 Xray =====
echo "[2/6] 安装 Xray 核心..."
mkdir -p /usr/local/bin /usr/local/etc/xray
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o xray.zip -d /usr/local/bin xray
chmod +x /usr/local/bin/xray
rm xray.zip

# ===== 写入配置文件 =====
echo "[3/6] 写入 Xray 客户端配置..."
cat > $CONFIG_PATH/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "tun-in",
      "protocol": "tun",
      "settings": {
        "domainStrategy": "AsIs",
        "mtu": 9000,
        "stack": "system",
        "inactivityTimeout": 300,
        "autoRoute": true,
        "autoRouteExclude": [],
        "interfaceName": "$TUN_INTERFACE"
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
        "security": "tls",
        "tlsSettings": {
          "serverName": "$SERVER_DOMAIN"
        },
        "network": "tcp"
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

# ===== 创建 systemd 服务 =====
echo "[4/6] 创建 systemd 服务..."
cat > /etc/systemd/system/xray-client.service <<EOF
[Unit]
Description=Xray Client (TUN)
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config $CONFIG_PATH/config.json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# ===== 启动服务并开机自启 =====
echo "[5/6] 启动并设置开机启动..."
systemctl daemon-reload
systemctl enable xray-client
systemctl start xray-client

# ===== 完成 =====
echo "[6/6] 部署完成，当前全局流量将通过 TUN 接入中转服务器：$SERVER_DOMAIN:$SERVER_PORT"
echo "✅ 建议执行：ip a 查看 $TUN_INTERFACE 是否已启用"
