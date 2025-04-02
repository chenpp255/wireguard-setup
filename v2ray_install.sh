#!/bin/bash

set -e

VERSION="v5.29.3"
ZIP_NAME="v2ray-linux-64.zip"
DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/$VERSION/$ZIP_NAME"
CONFIG_FILE="/usr/local/etc/v2ray/config.json"

echo "🌐 下载 V2Ray $VERSION ..."
wget -O "$ZIP_NAME" "$DOWNLOAD_URL"

echo "📦 解压文件 ..."
rm -rf v2ray && unzip -q "$ZIP_NAME" -d v2ray

echo "⚙️ 安装核心组件 ..."
sudo install -m 755 v2ray/v2ray /usr/local/bin/v2ray
#sudo install -m 755 v2ray/v2ctl /usr/local/bin/v2ctl
sudo mkdir -p /usr/local/share/v2ray
sudo cp -r v2ray/geo* /usr/local/share/v2ray/

echo "📁 创建配置目录 ..."
sudo mkdir -p /usr/local/etc/v2ray

# ========== 自动导入配置 ==========

read -p "🌐 是否从远程导入配置？请输入配置文件 URL（留空则使用默认 VMess 配置）: " config_url

if [[ -n "$config_url" ]]; then
  echo "⬇️ 正在从 $config_url 下载配置..."
  curl -fsSL "$config_url" -o config_tmp.json
  if jq empty config_tmp.json >/dev/null 2>&1; then
    sudo mv config_tmp.json "$CONFIG_FILE"
    echo "✅ 配置已成功导入"
  else
    echo "❌ 配置文件格式错误，跳过导入"
    rm -f config_tmp.json
  fi
elif [ ! -f "$CONFIG_FILE" ]; then
  echo "📝 写入默认 VMess 配置 ..."
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": 1080,
    "listen": "127.0.0.1",
    "protocol": "socks",
    "settings": {
      "udp": true
    }
  }],
  "outbounds": [{
    "protocol": "vmess",
    "settings": {
      "vnext": [{
        "address": "aia.vast.pw",
        "port": 54417,
        "users": [{
          "id": "638a3a0b-f9de-4503-a477-ec4f053fb944",
          "alterId": 0,
          "security": "auto"
        }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "serverName": "aia.vast.pw",
        "allowInsecure": false
      },
      "wsSettings": {
        "path": "/gtyhgf"
      }
    }
  }]
}
EOF
else
  echo "⚠️ 配置文件已存在，跳过生成"
fi

# ========== systemd 自启 ==========
read -p "🛠️ 是否添加 systemd 开机启动？(y/n): " auto_start

if [[ "$auto_start" == "y" ]]; then
  echo "🔧 配置 systemd 服务 ..."
  sudo tee /etc/systemd/system/v2ray.service > /dev/null <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl enable v2ray
  sudo systemctl restart v2ray
  echo "✅ V2Ray 已启动并设置为开机自启"
else
  echo "✅ 安装完成，可手动运行：sudo v2ray run -config /usr/local/etc/v2ray/config.json"
fi
