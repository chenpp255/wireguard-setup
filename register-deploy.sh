#!/bin/bash

### 部署 WireGuard 客户端注册接口（Flask）服务 ###

set -e

APP_FILE="/root/register-api.py"
SERVICE_FILE="/etc/systemd/system/wg-register.service"

# 1. 安装依赖
sudo apt update
sudo apt install -y python3 python3-flask

# 2. 写入接口脚本
cat > $APP_FILE <<'EOF'
from flask import Flask, request
import subprocess
import os

app = Flask(__name__)

WG_INTERFACE = "wg0"
USED_IP_FILE = "/etc/wireguard/used_ips"
IP_PREFIX = "10.0.0"

@app.route("/register-client", methods=["POST"])
def register():
    pubkey = request.form.get("pubkey")
    if not pubkey:
        return "Missing pubkey", 400

    if not os.path.exists(USED_IP_FILE):
        with open(USED_IP_FILE, "w") as f:
            f.write("2")

    with open(USED_IP_FILE, "r") as f:
        last_ip = int(f.read().strip())

    client_ip = f"{IP_PREFIX}.{last_ip}"
    next_ip = last_ip + 1

    with open(USED_IP_FILE, "w") as f:
        f.write(str(next_ip))

    subprocess.run([
        "wg", "set", WG_INTERFACE,
        "peer", pubkey,
        "allowed-ips", f"{client_ip}/32"
    ], check=True)

    config_path = f"/etc/wireguard/{WG_INTERFACE}.conf"
    with open(config_path, "a") as conf:
        conf.write(f"\n[Peer]\nPublicKey = {pubkey}\nAllowedIPs = {client_ip}/32\n")

    return f"Assigned-IP: {client_ip}\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
EOF

# 3. 创建 systemd 服务文件
cat > $SERVICE_FILE <<EOF
[Unit]
Description=WireGuard 客户端注册服务
After=network.target

[Service]
ExecStart=/usr/bin/python3 $APP_FILE
WorkingDirectory=/root
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 4. 启动服务
sudo systemctl daemon-reload
sudo systemctl enable --now wg-register

# 5. 状态输出
echo "✅ 注册服务已部署并运行在 8000 端口。"
systemctl status wg-register --no-pager
