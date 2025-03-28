#!/bin/bash

set -e

NVIDIA_VERSION=${1:-"570.124.04"}
NVIDIA_RUN="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
NVIDIA_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN}"

echo "🛠️ Installing NVIDIA Driver version $NVIDIA_VERSION ..."

# 安装依赖
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r) curl wget

# 屏蔽 nouveau
echo "🚫 Disabling nouveau..."
cat <<EOF | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

sudo update-initramfs -u

# 移除已加载 nouveau（如果存在）
sudo rmmod nouveau || true

# 下载 NVIDIA 驱动
echo "🌐 Downloading $NVIDIA_RUN ..."
wget -N $NVIDIA_URL
chmod +x $NVIDIA_RUN

# 切换到字符界面，防止图形界面干扰
sudo systemctl isolate multi-user.target || true

# 安装 NVIDIA 驱动
echo "🚀 Installing NVIDIA driver silently..."
sudo ./$NVIDIA_RUN --silent --dkms --kernel-module-type=kernel-open || {
  echo "❌ 安装失败，请检查日志或重试。"
  exit 1
}

# 自动修复 nvidia-drm
echo "🧩 Rebuilding module and fixing nvidia-drm..."
sudo dkms autoinstall || true
sudo modprobe nvidia-drm || true

# 验证是否安装成功（仅提示）
echo "🔍 驱动是否正常请稍后用 nvidia-smi 验证"

# 重启
echo "✅ 安装完成，系统将在 5 秒后重启..."
sleep 5
sudo reboot
