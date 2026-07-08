#!/bin/bash
# ============================================================
# ROSLander 仿真环境 - 停止并清理
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../docker"

echo "停止 ROSLander 仿真容器..."
cd "$DOCKER_DIR"
docker-compose down

echo "容器已停止"
