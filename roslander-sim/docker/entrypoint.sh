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

exec "$@"
