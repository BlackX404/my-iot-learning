#!/bin/bash
set -e

# 设置 ROS 环境
source /opt/ros/noetic/setup.bash
echo "=== ROSLander 仿真环境 ==="
echo "ROS: $(rosversion -d)"
echo "Gazebo: $(gazebo --version 2>&1 | head -1)"

# 如果工作空间已编译，则 source
if [ -f /root/ros_ws/devel/setup.bash ]; then
    source /root/ros_ws/devel/setup.bash
    echo "工作空间已就绪"
else
    echo "工作空间尚未编译，请运行: cd /root/ros_ws && catkin build"
fi

# ============================================================
# ROS 网络配置
# ============================================================
export ROS_IP=localhost
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=localhost

# ============================================================
# ROSLander 仿真环境变量
# ============================================================
export ROBOT_HOST=robot_1
export ROBOT_MASTER=robot_1
export MACHINE_TYPE=ROSLanderMecanum
export LIDAR_TYPE=S2L

exec "$@"