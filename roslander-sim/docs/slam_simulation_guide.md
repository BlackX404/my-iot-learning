# ROSLander 仿真环境 — 完整搭建与 SLAM 建图手册

> 从零开始：Docker 构建 → 编译 → 配置 → 仿真启动 → SLAM 建图 → 地图保存 → 导航。
> 所有踩坑和修复方案均已记录。

---

## 目录

1. [环境要求](#一环境要求)
2. [构建 Docker 镜像](#二构建-docker-镜像)
3. [启动容器与编译](#三启动容器与编译)
4. [环境变量配置](#四环境变量配置)
5. [安装缺失的 ROS 包](#五安装缺失的-ros-包)
6. [源码修改（两个必须的 fix）](#六源码修改两个必须的-fix)
7. [启动仿真与 SLAM](#七启动仿真与-slam)
8. [建图、保存、导航](#八建图保存导航)
9. [诊断命令速查](#九诊断命令速查)
10. [故障排查总表](#十故障排查总表)

---

## 一、环境要求

| 组件 | 要求 | 检查命令 |
|---|---|---|
| 操作系统 | Ubuntu 20.04+ | `lsb_release -a` |
| Docker | ≥ 19.03 | `docker --version` |
| docker-compose | v1（带连字符，新版 v2 也不行） | `docker-compose --version` |
| NVIDIA Container Toolkit | ≥ 1.13 | `dpkg -l nvidia-container-toolkit` |
| 磁盘空间 | ≥ 15GB | `df -h` |

> **注意**：本项目使用 `docker-compose`（带连字符的 v1），**不是** `docker compose`（v2 插件）。

---

## 二、构建 Docker 镜像

```bash
cd ~/roslander_sim
chmod +x scripts/*.sh
./scripts/build.sh
```

首次构建约 10-20 分钟，会下载 ROS Noetic + Gazebo 11 + MoveIt，约 2-3GB。

`build.sh` 自动完成：
1. 配置 X11 转发（GUI 支持）
2. 解压 ROSLander 源码（`src.zip`）和比赛功能包（`competition.zip`）
3. 部署比赛场景文件到仿真包
4. 构建 Docker 镜像

---

## 三、启动容器与编译

### 3.1 启动容器

```bash
./scripts/run.sh
```

### 3.2 进入容器并编译

```bash
./scripts/enter.sh
```

在容器内执行：

```bash
source /opt/ros/noetic/setup.bash
cd /root/ros_ws

# 安装 rosdep 依赖
rosdep update
rosdep install --from-paths src --ignore-src -r -y

# 编译（首次约 5-15 分钟）
catkin build

# 加载工作空间
source devel/setup.bash
```

以后每次新开终端，只需：
```bash
source /opt/ros/noetic/setup.bash && source devel/setup.bash
```

---

## 四、环境变量配置

Gazebo 和 SLAM 启动依赖以下环境变量。在容器内执行：

```bash
export ROBOT_HOST=robot_1
export ROBOT_MASTER=robot_1
export MACHINE_TYPE=ROSLanderMecanum    # 或 ROSLanderOmni，根据车型
export LIDAR_TYPE=S2L
```

**持久化**（写入 `~/.bashrc`，下次进入容器自动生效）：

```bash
echo 'export ROBOT_HOST=robot_1'            >> ~/.bashrc
echo 'export ROBOT_MASTER=robot_1'          >> ~/.bashrc
echo 'export MACHINE_TYPE=ROSLanderMecanum' >> ~/.bashrc
echo 'export LIDAR_TYPE=S2L'                >> ~/.bashrc
source ~/.bashrc
```

| 变量 | 说明 | 可选值 |
|---|---|---|
| `ROBOT_HOST` | 机器人节点命名空间 | `robot_1`, `robot_2`, ... |
| `ROBOT_MASTER` | 主机器人标识（多机时区分主从） | 通常与 `ROBOT_HOST` 相同 |
| `MACHINE_TYPE` | 底盘类型 | `ROSLanderMecanum`（麦克纳姆轮）/ `ROSLanderOmni`（全向轮） |
| `LIDAR_TYPE` | 激光雷达型号 | `S2L`, `G4` |

> ⚠️ **常见错误**：`environment variable 'ROBOT_MASTER' is not set`
> — `echo '...' >> ~/.bashrc` 只写入文件，**不改变当前终端**。必须 `source ~/.bashrc` 或直接 `export`。

---

## 五、安装缺失的 ROS 包

Docker 镜像（`Dockerfile`）遗漏了以下包，必须手动安装：

```bash
apt update && apt install -y \
    ros-noetic-robot-state-publisher \
    ros-noetic-laser-filters
```

| 包名 | 作用 | 缺失时的错误信息 |
|---|---|---|
| `ros-noetic-robot-state-publisher` | 发布 URDF 模型的 tf 坐标变换 | `ERROR: cannot launch node of type [robot_state_publisher/robot_state_publisher]` |
| `ros-noetic-laser-filters` | 激光雷达角度滤波节点 | `ERROR: cannot launch node of type [laser_filters/scan_to_scan_filter_chain]` |

---

## 六、源码修改（两个必须的 fix）

以下两处是仿真环境下必须修改的，否则 SLAM 无法工作。

### Fix 1：gmapping 启用仿真时间

**文件**：`ros_ws/src/slam/launch/slam.launch`

**问题**：gmapping 节点未设置 `use_sim_time`，导致其内部的 `MessageFilter` 用系统时间（wall time）去匹配 Gazebo 发布的仿真时间（sim time），时间戳对不上 → 100% 的激光消息被丢弃。

**修改**：在第 5 行附近，`<arg name="use_joy">` 下方添加一行：

```diff
     <arg name="sim"         default="false"/>
     <arg name="app"         default="false"/>
     <arg name="use_joy"     default="true"/>
+
+    <param if="$(arg sim)" name="/use_sim_time" value="true"/>
```

### Fix 2：激光雷达 frame 名称与 tf 树对齐

**文件**：`ros_ws/src/simulations/roslander_gazebo/launch/spwan_model.launch`

**问题**：Gazebo 的 laser plugin 发布 scan 消息时 `frame_id: "lidar_sim_frame"`（不带命名空间前缀），但 `robot_state_publisher` 用 `tf_prefix=robot_1` 给所有 tf frame 加了前缀，tf 树里实际叫 `robot_1/lidar_sim_frame`。frame 名不一致导致 gmapping 无法将激光数据从 lidar 坐标系变换到 odom 坐标系。

**修改**：

```diff
-    <arg name="lidar_frame"         default="lidar_sim_frame"/>
+    <arg name="lidar_frame"         default="$(arg frame_prefix)lidar_sim_frame"/>
```

> 修改后 scan 消息的 `frame_id` 会变成 `robot_1/lidar_sim_frame`，与 tf 树一致。

---

## 七、启动仿真与 SLAM

> 需要**两个终端**，一个跑 Gazebo，一个跑 SLAM。

### 终端 1：Gazebo 仿真

```bash
cd ~/roslander_sim && ./scripts/enter.sh
source /opt/ros/noetic/setup.bash && source devel/setup.bash

# 空地场景（默认）
roslaunch roslander_gazebo worlds.launch

# 或房间场景（有墙壁，方便建图调试）
roslaunch roslander_gazebo room_worlds.launch

# 或比赛月球场景
roslaunch roslander_gazebo moon_exploration.launch
```

正常启动后应看到 Gazebo GUI 窗口，机器人模型出现在场景中。

### 终端 2：SLAM 建图

```bash
cd ~/roslander_sim && ./scripts/enter.sh
source /opt/ros/noetic/setup.bash && source devel/setup.bash

roslaunch slam slam.launch sim:=true use_joy:=false
```

参数说明：
- `sim:=true` — 仿真模式（不启动真实硬件驱动）
- `use_joy:=false` — 跳过手柄控制和 `ros_robot_controller` 硬件节点（仿真中无 `/dev/rrc` 串口，启动即崩溃）

### 确认正常

SLAM 终端应输出：

```
[INFO] Initialization complete
[INFO] Registering First Scan
```

**不应出现** `MessageFilter Dropped 100.00%` 警告。

可以忽略的警告：
- `No p gain specified for pid` — 机械臂 PID 增益未配，不影响底盘建图
- `TF_REPEATED_DATA` — gmapping 和别的源同时发布 `map→odom` 变换，tf2 自动去重

---

## 八、建图、保存、导航

### 8.1 控制机器人移动

新开终端 3（键盘控制）：

```bash
cd ~/roslander_sim && ./scripts/enter.sh
source /opt/ros/noetic/setup.bash && source devel/setup.bash

rosrun teleop_twist_keyboard teleop_twist_keyboard.py cmd_vel:=/robot_1/controller/cmd_vel
```

| 按键 | 动作 |
|---|---|
| `i` | 前进 |
| `,` | 后退 |
| `j` | 左转 |
| `l` | 右转 |
| `k` | 停止 |
| `q` | 加速 / `z` 减速 |

让机器人在场景中走一圈，终端 2（SLAM）会看到 `update ld=... ad=...` 日志，Gazebo 窗口也会同步运动。

### 8.2 保存地图

走完后，在新终端或当前终端执行：

```bash
source /opt/ros/noetic/setup.bash && source devel/setup.bash
rosrun map_server map_saver -f ~/my_map map:=/robot_1/map
```

生成两个文件：
- `~/my_map.pgm` — 地图图片（可直接查看）
- `~/my_map.yaml` — 地图配置文件（分辨率、原点等）

### 8.3 使用地图导航

Ctrl-C 停止终端 2 的 SLAM 进程，然后启动导航：

```bash
source /opt/ros/noetic/setup.bash && source devel/setup.bash
roslaunch navigation navigation.launch sim:=true use_joy:=false
```

---

## 九、诊断命令速查

在容器内（需先 source ROS 环境）：

```bash
# 查看所有话题
rostopic list | grep robot_1

# 查看激光原始数据（Gazebo 直接发布的）
rostopic echo /robot_1/scan_raw -n 1

# 查看滤波后的激光数据（gmapping 订阅的）
rostopic echo /robot_1/scan -n 1

# 查看里程计数据
rostopic echo /robot_1/odom -n 1

# 查看 tf 坐标变换树（生成 frames.pdf）
rosrun tf view_frames

# 查看运行中的节点
rosnode list

# 查看某个节点的详细信息
rosnode info /robot_1/slam_gmapping
```

---

## 十、故障排查总表

| 错误信息 | 原因 | 解决 |
|---|---|---|
| `environment variable 'ROBOT_MASTER' is not set` | 环境变量未在当前终端生效 | `export ROBOT_MASTER=robot_1` 或 `source ~/.bashrc` |
| `cannot launch node of type [robot_state_publisher/...]` | 包未安装 | `apt install -y ros-noetic-robot-state-publisher` |
| `cannot launch node of type [laser_filters/...]` | 包未安装 | `apt install -y ros-noetic-laser-filters` |
| `ros_robot_controller` 崩溃，`/dev/rrc: No such file` | 仿真中启动了硬件驱动节点 | 启动时加 `use_joy:=false` |
| `MessageFilter Dropped 100.00%` | use_sim_time 缺失 **或** lidar frame 不匹配 | 检查 [Fix 1](#fix-1gmapping-启用仿真时间) 和 [Fix 2](#fix-2激光雷达-frame-名称与-tf-树对齐) |
| `No p gain specified for pid` (joint1~5, r_joint) | 机械臂 PID 增益未配置 | 不影响底盘建图，可忽略 |
| `TF_REPEATED_DATA` 警告 | tf 重复时间戳 | 不影响建图，可忽略 |
| SLAM 启动后卡住无反应 | Gazebo 未启动或话题不对 | 确认 Gazebo 已启动，`rostopic echo /robot_1/scan_raw` 有数据 |
| Gazebo 黑屏/启动慢 | GPU 渲染问题 | 宿主机设置 `export LIBGL_ALWAYS_SOFTWARE=1` |
| `docker-compose: command not found` | 未安装或安装了 v2 | 安装 v1：`apt install docker-compose` |
| Docker 拉取镜像超时（国内） | 网络问题 | 配置 DaoCloud 镜像加速，见 `docker/install_docker.sh` |

---

## 附录：修改记录

| 日期 | 修改 | 文件 |
|---|---|---|
| 2026-07-08 | 添加 `use_sim_time` 参数 | `ros_ws/src/slam/launch/slam.launch` |
| 2026-07-08 | 修复 lidar frame 前缀 | `ros_ws/src/simulations/roslander_gazebo/launch/spwan_model.launch` |
