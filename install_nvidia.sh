#!/bin/bash

# 一键静默安装 NVIDIA 驱动程序脚本

# 设置 NVIDIA 驱动程序版本和下载链接
DRIVER_VERSION="570.124.04"
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run"
DRIVER_FILE="NVIDIA-Linux-x86_64-$DRIVER_VERSION.run"

# 更新系统
echo "开始系统更新..."
sudo apt update && sudo apt upgrade -y

# 安装必要的依赖
echo "安装必要的依赖..."
sudo apt install build-essential libglvnd-dev pkg-config libx11-dev -y
sudo apt install linux-headers-$(uname -r) -y

# 下载 NVIDIA 驱动程序
echo "下载 NVIDIA 驱动程序 $DRIVER_VERSION..."
wget $DRIVER_URL -O $DRIVER_FILE

# 给驱动程序文件赋予执行权限
echo "给驱动程序文件赋予执行权限..."
chmod +x $DRIVER_FILE

# 执行静默安装
echo "开始静默安装 NVIDIA 驱动程序..."
sudo ./$DRIVER_FILE --silent

# 完成安装后禁用 Nouveau 驱动
echo "禁用 Nouveau 驱动..."
echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u

# 提示用户重启以使更改生效
echo "驱动安装完成。请重启计算机以使更改生效。"
echo "您可以使用以下命令重启计算机： sudo reboot"
