#!/bin/bash

# 安装依赖
echo "🔧 正在安装依赖环境..."
sudo apt update
sudo apt install -y bzip2 tar curl

# 切换到 root 用户执行安装（如果不是 root）
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ 当前不是 root 用户，将尝试使用 sudo 执行安装..."
    SUDO='sudo'
else
    SUDO=''
fi

# 安装 ShellCrash 主源
echo "🌐 尝试从主源安装 ShellCrash..."
$SUDO bash -c "
    export url='https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master' && \
    wget -q --no-check-certificate -O /tmp/install.sh \$url/install.sh && \
    bash /tmp/install.sh && \
    source /etc/profile &> /dev/null
"

# 如果主源失败，尝试备用源
if [ $? -ne 0 ]; then
    echo "⚠️ 主源安装失败，尝试备用源..."
    $SUDO bash -c "
        export url='https://gh.jwsc.eu.org/master' && \
        bash -c \"\$(curl -kfsSl \$url/install.sh)\" && \
        source /etc/profile &> /dev/null
    "
fi

# 检查安装结果
if command -v crash &>/dev/null; then
    echo "✅ ShellCrash 安装成功！你可以输入 crash 来运行它。"
else
    echo "❌ ShellCrash 安装失败，请检查网络或源地址。"
fi
