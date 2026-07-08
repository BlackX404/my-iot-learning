#!/bin/bash
# ============================================================
# ROSLander 仿真环境 - 启动脚本
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../docker"

# 允许 X11 连接
xhost +local:docker > /dev/null 2>&1 || true

# 确保 PulseAudio 可用
if [ -S /run/user/1000/pulse/native ]; then
    export PULSE_SERVER=unix:/run/user/1000/pulse/native
fi

echo "启动 ROSLander 仿真容器..."
cd "$DOCKER_DIR"
docker-compose up -d

echo ""
echo "容器已启动，连接终端: ./enter.sh"
echo "或直接进入: docker exec -it roslander_sim bash"
