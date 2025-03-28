#!/bin/bash
set -e

# ========== 颜色 ==========
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# ========== 参数处理 ==========
VAST_API_KEY="$1"

# ========== Root 检查 ==========
if [[ $EUID -ne 0 ]]; then
  echo "❌ 请用 root 权限运行此脚本"
  exit 1
fi

# ========== 切换为清华源 ==========
echo -e "${GREEN}🌐 切换 apt 源为清华镜像${NC}"
cp /etc/apt/sources.list /etc/apt/sources.list.bak
sed -i 's|http://.*.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
apt update

# ========== 登录 Vast ==========
if [[ "$VAST_API_KEY" != "localonly" ]]; then
  echo -e "${GREEN}🔐 登录 Vast.ai...${NC}"
  wget -q https://console.vast.ai/install -O install
  chmod +x install
  if [[ -z "$VAST_API_KEY" ]]; then
    echo "请输入 Vast API key："
    read -r VAST_API_KEY
  fi
  python3 install "$VAST_API_KEY"
fi

# ========== 安装常用工具 ==========
echo -e "${GREEN}📦 安装常用工具...${NC}"
apt install -y vim git curl wget htop screen unzip build-essential python3-pip

# ========== 安装 Docker ==========
echo -e "${GREEN}🐳 安装 Docker（自动选择镜像源）...${NC}"
DOCKER_URL="https://download.docker.com"
if ! curl -s --connect-timeout 3 https://download.docker.com >/dev/null; then
  DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
  echo "⚠️ 切换为清华 Docker 镜像源"
fi

curl -fsSL $DOCKER_URL/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
DISTRO_CODENAME=$(lsb_release -cs)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $DOCKER_URL/linux/ubuntu $DISTRO_CODENAME stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

# ========== 安装 gpu-burn ==========
echo -e "${GREEN}🔥 安装 gpu-burn 工具...${NC}"
cd /root
git clone https://github.com/wilicc/gpu-burn.git || true
cd gpu-burn

if [[ -d /usr/local/cuda/include ]]; then
  CUDA_INCLUDE="/usr/local/cuda/include"
else
  CUDA_INCLUDE=$(find / -name cublas_v2.h 2>/dev/null | head -n1 | xargs dirname)
fi

if [[ -z "$CUDA_INCLUDE" ]]; then
  echo "❌ 未找到 cublas_v2.h，请确保 CUDA 安装正确"
  exit 1
fi

make clean
make EXTRA_FLAGS="-I$CUDA_INCLUDE"

echo -e "${GREEN}✅ 所有任务完成！你可以用下面命令进行测试：${NC}"
echo -e "${GREEN}   cd /root/gpu-burn && ./gpu-burn -d 0 60${NC}"
