#!/usr/bin/env python3
import subprocess
import sys
import os

def run(cmd, shell=False):
    print(f"=> Running: {cmd}")
    result = subprocess.run(cmd, shell=shell, check=True, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    return result

def install_vast():
    print("=> Installing Vast.ai host software")

    # 安装 Docker
    run(["apt-get", "update"])
    run(["apt-get", "-y", "install", "docker.io"])
    run(["systemctl", "enable", "--now", "docker"])

    # 安装 nvidia-docker2
    run(["apt-get", "-y", "install", "nvidia-container-toolkit"])
    run(["systemctl", "restart", "docker"])

    # 确保 GPU 可用
    run("nvidia-smi", shell=True)

    # 这里跳过 NCCL 测试 !!!
    print("=> [跳过 NCCL 测试]")

    # 拉取并启动 Vast Daemon
    print("=> 启动 vast daemon")
    os.makedirs("/var/lib/vastai_kaalia", exist_ok=True)
    run("docker pull vastai/vast-host:latest", shell=True)
    run("docker run --rm --privileged --pid=host -v /:/host_root -e INSTALL_ONLY=1 vastai/vast-host:latest", shell=True)
    print("=> Vast 安装完成，请登录控制台查看")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("请使用 root 权限运行：sudo python3 vast_install_nonccl.py")
        sys.exit(1)
    install_vast()

