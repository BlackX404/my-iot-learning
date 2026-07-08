#!/bin/bash
# ============================================================
# ROSLander 仿真环境 - 构建脚本
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
DOCKER_DIR="${PROJECT_DIR}/docker"

echo "======================================"
echo "  ROSLander 仿真环境构建"
echo "======================================"

# 1. 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi
echo "✅ Docker: $(docker --version)"

# 2. 检查 NVIDIA Container Toolkit
if ! dpkg -l nvidia-container-toolkit &> /dev/null; then
    echo "⚠️  nvidia-container-toolkit 未安装"
    echo "   运行: sudo apt install -y nvidia-container-toolkit"
else
    echo "✅ nvidia-container-toolkit 已安装"
fi

# 3. 允许 X11 连接
echo ""
echo ">>> 配置 X11 显示转发..."
xhost +local:docker > /dev/null 2>&1 || true
echo "✅ X11 已配置"

# 4. 创建宿主机 ros_ws/src 目录
mkdir -p "${PROJECT_DIR}/ros_ws/src"

# 5. 解压源码（如果还没解压）
SRC_ZIP="/home/bleak-x/yuetana/1-幻尔月球探索培训资料（较全）★★★(1)/ROSLander多模态机器人-2024版（Jetson Nano）/4.源码/src.zip"
COMP_ZIP="/home/bleak-x/yuetana/1-幻尔月球探索培训资料（较全）★★★(1)/ROSLander月球探索实现引导-2025版/附件/比赛功能包/jetson nano competition.zip"

if [ ! -d "${PROJECT_DIR}/ros_ws/src/simulations" ]; then
    echo ""
    echo ">>> 解压 ROSLander 源码..."
    if [ -f "$SRC_ZIP" ]; then
        unzip -q -o "$SRC_ZIP" -d "${PROJECT_DIR}/ros_ws/"
        echo "✅ 源码解压完成"
    else
        echo "⚠️  源码 zip 未找到: $SRC_ZIP"
    fi
else
    echo "✅ 源码已存在，跳过解压"
fi

if [ ! -d "${PROJECT_DIR}/ros_ws/src/competition" ]; then
    echo ""
    echo ">>> 解压比赛功能包..."
    if [ -f "$COMP_ZIP" ]; then
        unzip -q -o "$COMP_ZIP" -d "${PROJECT_DIR}/ros_ws/src/"
        echo "✅ 比赛功能包解压完成"
    else
        echo "⚠️  比赛功能包 zip 未找到: $COMP_ZIP"
    fi
else
    echo "✅ 比赛功能包已存在，跳过解压"
fi

# 6. 部署比赛场景到仿真包
echo ""
echo ">>> 部署比赛场景文件..."
GAZEBO_WORLDS="${PROJECT_DIR}/ros_ws/src/simulations/roslander_gazebo/worlds"
GAZEBO_LAUNCH="${PROJECT_DIR}/ros_ws/src/simulations/roslander_gazebo/launch"
mkdir -p "$GAZEBO_WORLDS" "$GAZEBO_LAUNCH"
cp -v "${PROJECT_DIR}/scenes/worlds/moon_exploration.world" "$GAZEBO_WORLDS/"
cp -v "${PROJECT_DIR}/scenes/launch/moon_exploration.launch" "$GAZEBO_LAUNCH/"
echo "✅ 比赛场景已部署"

# 7. 创建 Gazebo 缓存目录
mkdir -p ~/.gazebo/models

# 8. 构建 Docker 镜像
echo ""
echo ">>> 构建 Docker 镜像 (这可能需要 10-20 分钟)..."
cd "${DOCKER_DIR}"
docker-compose build

echo ""
echo "======================================"
echo "  构建完成！"
echo "======================================"
echo ""
echo "下一步："
echo "  1. 启动容器:   ./run.sh"
echo "  2. 进入容器:   ./enter.sh"
echo "  3. 编译代码:   cd /root/ros_ws && catkin build"
echo ""
