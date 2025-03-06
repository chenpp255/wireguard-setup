#!/bin/bash

# 更新软件包列表
echo "正在更新软件包列表..."
sudo apt update -y

# 升级已安装的软件包
echo "正在升级已安装的软件包..."
sudo apt upgrade -y

# 安装 Python3 pip
echo "正在安装 pip..."
sudo apt install -y python3-pip

# 安装最新的显卡驱动
echo "正在安装最新的显卡驱动..."
sudo ubuntu-drivers autoinstall

# 关闭系统休眠
echo "正在禁用系统休眠..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 提示即将重启
echo "所有操作完成！系统将在 10 秒后自动重启..."
sleep 10  # 等待 10 秒，避免误触

# 重启系统
sudo reboot
