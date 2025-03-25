#!/bin/bash
set -e

DURATION=300  # 5 分钟
WORKDIR=~/gpu_test_parallel

echo "🚀 GPU 并行压力测试启动"
echo "测试时长：$((DURATION / 60)) 分钟"

mkdir -p $WORKDIR
cd $WORKDIR

# 检查驱动
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA 驱动未安装，无法进行测试"
    exit 1
fi

# 获取显卡数量
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
echo "✅ 检测到 $GPU_COUNT 张 NVIDIA 显卡"

# 安装依赖
echo ""
echo "📦 安装必要依赖..."
sudo apt update
sudo apt install -y git make g++ libncurses5 > /dev/null

# 拉取并编译 gpu-burn
echo ""
echo "📥 准备 gpu-burn 工具..."
if [ ! -d gpu-burn ]; then
    git clone https://github.com/wilicc/gpu-burn.git > /dev/null
fi
cd gpu-burn
make > /dev/null
cd ..

# 获取测试前状态
echo ""
echo "📋 收集每张显卡测试前状态..."
for i in $(seq 0 $((GPU_COUNT - 1))); do
    nvidia-smi --id=$i --query-gpu=name,driver_version,utilization.gpu,temperature.gpu --format=csv > gpu${i}_before.txt
done

# 启动并行测试
echo ""
echo "🔥 开始并行测试每张显卡 ${DURATION}s ..."
PIDS=()

for i in $(seq 0 $((GPU_COUNT - 1))); do
    echo "▶️ GPU $i 开始测试..."
    CUDA_VISIBLE_DEVICES=$i ./gpu-burn/gpu_burn $DURATION > gpu${i}_burn.log 2>&1 &
    PIDS+=($!)
done

# 等待所有测试进程结束
for pid in "${PIDS[@]}"; do
    wait $pid
done

# 获取测试后状态
echo ""
echo "📋 收集每张显卡测试后状态..."
for i in $(seq 0 $((GPU_COUNT - 1))); do
    nvidia-smi --id=$i --query-gpu=name,driver_version,utilization.gpu,temperature.gpu --format=csv > gpu${i}_after.txt
done

# 汇总报告
echo ""
echo "🧾 GPU 压力测试报告："
echo "========================================"
echo "测试时长：$((DURATION / 60)) 分钟"
for i in $(seq 0 $((GPU_COUNT - 1))); do
    echo ""
    echo "----- GPU $i 测试报告 -----"
    echo ">> 测试前："
    cat gpu${i}_before.txt
    echo ">> 测试后："
    cat gpu${i}_after.txt
done
echo "========================================"
echo "✅ 所有显卡测试完成"

# 可选：你也可以保留或自动清理临时目录
# rm -rf $WORKDIR
