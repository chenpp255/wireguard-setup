#!/bin/bash

set -e

NVIDIA_VERSION="570.133.07"
NVIDIA_RUN_FILE="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
NVIDIA_RUN_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN_FILE}"

echo "🚀 开始安装 NVIDIA 驱动 ${NVIDIA_VERSION}..."

# 下载驱动
if [ ! -f "$NVIDIA_RUN_FILE" ]; then
  echo "⬇️ 下载 NVIDIA 驱动..."
  wget "$NVIDIA_RUN_URL"
else
  echo "✅ 驱动文件已存在：$NVIDIA_RUN_FILE"
fi

# 安装依赖
echo "📦 安装依赖..."
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)

# 禁用 nouveau
echo "🛑 禁用 nouveau..."
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u

# 提取并安装驱动
echo "📦 提取驱动文件..."
chmod +x "$NVIDIA_RUN_FILE"
./"$NVIDIA_RUN_FILE" --extract-only

cd "NVIDIA-Linux-x86_64-${NVIDIA_VERSION}"

echo "⚙️ 静默安装 NVIDIA 驱动（不杀 SSH）..."
sudo ./nvidia-installer --disable-nouveau --dkms --silent

echo "✅ 安装完成！请重启系统后执行：nvidia-smi 检查 GPU 状态"
