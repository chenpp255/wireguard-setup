#!/bin/bash
set -e

echo "==== 停止 Docker 服务（如果存在） ===="
sudo systemctl stop docker || true

echo "==== 卸载 NVIDIA 驱动（如果存在） ===="
if [ -f "/usr/bin/nvidia-uninstall" ]; then
    sudo /usr/bin/nvidia-uninstall -s || true
fi

echo "==== 移除 NVIDIA 驱动相关模块 ===="
sudo modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia || true

echo "==== 清理 NVIDIA 驱动包 ===="
sudo apt purge -y '*nvidia*' 'libnvidia*' 'cuda*' 'nsight*' || true
sudo apt autoremove -y
sudo apt clean

echo "==== 清理 NVIDIA 容器工具链 ===="
sudo apt purge -y nvidia-container-toolkit nvidia-docker2 || true
sudo rm -rf /etc/docker/daemon.json
sudo rm -rf /etc/systemd/system/docker.service.d

echo "==== 移除残余 GRUB 配置 ===="
sudo sed -i 's/modprobe.blacklist=.*//g' /etc/default/grub
sudo update-grub

echo "==== 重置 NVIDIA 环境变量 ===="
sudo rm -f /etc/profile.d/cuda.sh
sudo rm -f /etc/ld.so.conf.d/nvidia*.conf
sudo ldconfig

echo "==== 重启前再次确认 NVIDIA 模块 ===="
lsmod | grep nvidia || echo "✅ NVIDIA 模块已卸载"

echo "==== 清理完成，建议现在重启系统 ===="
echo "👉 重启后你可以重新运行你的 NVIDIA 安装脚本。"
