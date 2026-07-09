# ROSLander 月球探索仿真环境
# 基于 ROS Noetic + Gazebo 11
FROM ros:noetic-ros-base

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# 1. 基础系统依赖
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git vim \
    python3-pip python3-dev \
    python3-catkin-tools \
    python3-rosdep \
    ros-noetic-rosbash \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 2. Gazebo 11 仿真
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-gazebo-ros-pkgs \
    ros-noetic-gazebo-ros-control \
    ros-noetic-ros-control \
    ros-noetic-ros-controllers \
    ros-noetic-joint-state-controller \
    ros-noetic-effort-controllers \
    ros-noetic-position-controllers \
    ros-noetic-velocity-controllers \
    ros-noetic-diff-drive-controller \
    ros-noetic-joint-trajectory-controller \
    ros-noetic-gazebo-plugins \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 3. MoveIt（机械臂运动规划）
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-moveit \
    ros-noetic-moveit-visual-tools \
    ros-noetic-moveit-ros-planning \
    ros-noetic-moveit-ros-manipulation \
    ros-noetic-moveit-ros-move-group \
    ros-noetic-moveit-kinematics \
    ros-noetic-moveit-planners-ompl \
    ros-noetic-moveit-ros-control-interface \
    ros-noetic-moveit-simple-controller-manager \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 4. SLAM & 导航
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-navigation \
    ros-noetic-slam-gmapping \
    ros-noetic-map-server \
    ros-noetic-amcl \
    ros-noetic-move-base \
    ros-noetic-teb-local-planner \
    ros-noetic-dwa-local-planner \
    ros-noetic-global-planner \
    ros-noetic-explore-lite \
    ros-noetic-rgbd-launch \
    ros-noetic-depthimage-to-laserscan \
    ros-noetic-joy \
    ros-noetic-teleop-twist-keyboard \
    ros-noetic-rviz \
    ros-noetic-robot-state-publisher \
    ros-noetic-laser-filters \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 5. Python 依赖
# ============================================================
RUN pip3 install --no-cache-dir \
    pyserial \
    pyyaml \
    numpy \
    opencv-python \
    scipy \
    transforms3d

# ============================================================
# 6. 环境变量
# ============================================================
ENV ROS_WS=/root/ros_ws
ENV GAZEBO_MODEL_PATH=${ROS_WS}/src/simulations/roslander_gazebo/models:${GAZEBO_MODEL_PATH}
ENV GAZEBO_PLUGIN_PATH=${ROS_WS}/devel/lib:${GAZEBO_PLUGIN_PATH}
ENV GAZEBO_RESOURCE_PATH=${ROS_WS}/src/simulations/roslander_gazebo:${GAZEBO_RESOURCE_PATH}

# ============================================================
# 7. 工作空间入口
# ============================================================
RUN mkdir -p ${ROS_WS}/src
WORKDIR ${ROS_WS}

# 初始化 rosdep
RUN rosdep update

# 复制源码（由 docker-compose volume 挂载）
# 编译脚本放在 entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]