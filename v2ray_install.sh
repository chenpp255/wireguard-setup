#!/bin/bash

set -e

# 版本号和文件名
VERSION="v5.29.3"
ZIP_NAME="v2ray-linux-64.zip"
DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/$VERSION/$ZIP_NAME"

echo "🌐 开始下载 V2Ray $VERSION ..."
wget -O "$ZIP_NAME" "$DOWNLOAD_URL"

echo "📦 解压文件 ..."
rm -rf v2ray && unzip -q "$ZIP_NAME" -d v2ray

echo "⚙️ 安装核心组件 ..."
sudo install -m 755 v2ray/v2ray /usr/local/bin/v2ray
sudo install -m 755 v2ray/v2ctl /usr/local/bin/v2ctl
sudo mkdir -p /usr/local/share/v2ray
sudo cp -r v2ray/geo* /usr/local/share/v2ray/

echo "📁 创建配置目录 ..."
sudo mkdir -p /usr/local/etc/v2ray

CONFIG_FILE="/usr/local/etc/v2ray/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "📝 写入默认配置 ..."
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
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
else
  echo "⚠️ 配置文件已存在，跳过生成"
fi

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
