#!/bin/bash
# ============================================================
# ROSLander 仿真环境 - 进入容器
# ============================================================
set -e

# 允许 X11 连接
xhost +local:docker > /dev/null 2>&1 || true

if docker ps --format '{{.Names}}' | grep -q 'roslander_sim'; then
    docker exec -it roslander_sim bash
else
    echo "容器未运行，请先执行 ./run.sh"
    exit 1
fi
