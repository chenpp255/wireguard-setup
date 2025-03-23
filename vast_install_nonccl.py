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

    # 跳过 docker 安装，假设你已完成
    print("=> [跳过 NCCL 测试]")
    print("=> 启动 vast daemon")

    os.makedirs("/var/lib/vastai_kaalia", exist_ok=True)

    # 检查本地是否已有 vastai/vast-host 镜像
    print("=> 检查是否已有本地镜像 vastai/vast-host:latest")
    try:
        run("docker image inspect vastai/vast-host:latest", shell=True)
        print("=> 本地镜像存在，直接运行")
    except subprocess.CalledProcessError:
        print("❌ 没有本地镜像 vastai/vast-host:latest，请先手动构建或从其它机器导入")
        sys.exit(1)

    # 运行 vast-host 容器
    run("docker run --rm --privileged --pid=host -v /:/host_root -e INSTALL_ONLY=1 vastai/vast-host:latest", shell=True)

    print("✅ Vast Host 安装完成！请运行 vastai status 验证")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("请使用 root 权限运行：sudo python3 vast_install_nonccl.py")
        sys.exit(1)
    install_vast()
