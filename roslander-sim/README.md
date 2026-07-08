# ROSLander 月球探索仿真环境

> 第28届CRAIC 机器人任务挑战赛（复合机器人月球探索）仿真调试环境

## 环境要求

| 组件 | 要求 | 状态检查 |
|------|------|----------|
| 操作系统 | Ubuntu 20.04+ | `lsb_release -a` |
| Docker | ≥ 19.03 | `docker --version` |
| docker-compose | v1.29+ (带连字符) | `docker-compose --version` |
| NVIDIA Container Toolkit | ≥ 1.13 | `dpkg -l nvidia-container-toolkit` |
| 磁盘空间 | ≥ 15GB 可用 | `df -h` |

**注意**: 本系统使用的是 `docker-compose`（带连字符，v1），不是 `docker compose`（v2 插件）。

## 目录结构

```
roslander_sim/
├── docker/                    # Docker 容器配置
│   ├── Dockerfile             # ROS Noetic + Gazebo 11 镜像
│   ├── docker-compose.yml     # 一键启动配置（v1兼容）
│   └── entrypoint.sh          # 容器入口脚本
├── scripts/                   # 管理脚本
│   ├── build.sh               # 构建镜像 + 解压源码
│   ├── run.sh                 # 启动容器
│   ├── enter.sh               # 进入容器终端
│   └── stop.sh                # 停止容器
├── scenes/                    # 比赛场景
│   ├── worlds/
│   │   └── moon_exploration.world   # 月球探索比赛场景
│   └── launch/
│       └── moon_exploration.launch  # 启动文件
└── ros_ws/                    # ROS 工作空间（由 build.sh 解压）
    └── src/
        ├── simulations/       # ROSLander Gazebo 仿真包
        │   ├── roslander_description/   # 机器人 URDF 模型
        │   ├── roslander_gazebo/        # Gazebo 世界和模型
        │   └── roslander_moveit_config/ # MoveIt 配置
        └── competition/       # 比赛功能包（导航/夹取/语音/视觉）
```

## 快速开始

### 1. 构建

```bash
cd ~/roslander_sim
chmod +x scripts/*.sh
./scripts/build.sh
```

`build.sh` 自动完成：
1. 配置 X11 转发以支持 GUI
2. 从培训资料解压 ROSLander 源码（`src.zip`）和比赛功能包（`competition.zip`）
3. 部署比赛场景文件到仿真包
4. 构建 Docker 镜像（首次约 10-20 分钟，下载 ROS Noetic + Gazebo + MoveIt，约 2-3GB）

### 2. 启动容器

```bash
./scripts/run.sh
```

### 3. 进入容器编译

```bash
./scripts/enter.sh
```

容器内执行（首次需要编译，后续启动不需要）：
```bash
cd /root/ros_ws
rosdep install --from-paths src --ignore-src -r -y
catkin build
source devel/setup.bash
```

### 4. 启动比赛仿真

在容器内：
```bash
# 基础场景（仅机器人 + 空场地）
roslaunch roslander_gazebo worlds.launch

# 比赛场景（3.92m×2.16m 月球探索场地 + 全部道具）
roslaunch roslander_gazebo moon_exploration.launch

# 房间仿真（用于 SLAM 建图调试）
roslaunch roslander_gazebo room_worlds.launch
```

### 5. 停止

```bash
./scripts/stop.sh
```

## 比赛场景说明

`moon_exploration.world` 包含完整比赛场地：

| 道具 | 尺寸 | 数量 | 说明 |
|------|------|------|------|
| 场地 | 3.92m × 2.16m | 1 | 月球探索地图 |
| 围挡 | 500mm 高 | 4面 | 扁铝型材 |
| 月球基地 | 837×400×105mm | 1 | 出发点斜坡平台 |
| 月球资源库 | 148×148×50mm | 1 | 红色收纳盒 |
| 障碍物 | 360×360×360mm | 5 | 3固定 + 2随机 |
| 采集平台 | 230×140×70mm | 2 | EVA方块 |
| 矿石(正方体) | 30×30×30mm | 2 | 绿色 |
| 矿石(长方体) | 30×30×60mm | 2 | 黄色 |
| 矿石(圆柱体) | Φ30×45mm | 2 | 蓝色 |
| 任务卡片 | 148×148mm | 3 | 贴围挡上 |

> **注意**：道具坐标是估算值，需根据实际无纺布地图在 Gazebo 中微调。

## 比赛任务流程（仿真调试）

| 步骤 | 任务 | 满分 | 仿真中可调试的部分 |
|------|------|------|-------------------|
| ① | 基地出发 — 语音唤醒 → 驶入场地 | 10 | 语音识别触发、底盘运动控制 |
| ② | 目标确认 — 识别任务卡片 → 确认矿石种类 | 10 | YOLO 形状识别、颜色阈值 |
| ③ | 障碍穿越 — SLAM导航过障碍 | 20 | 路径规划参数、避障 |
| ④ | 矿石采集回收 — 夹取 → 搬运 ×2 | 40 | 机械臂运动学、夹取位姿 |
| ⑤ | 月球环境识别 — 视觉大模型识别 3 个场景 | 10 | 场景识别模型 |
| ⑥ | 返回基地 — 回坡道 → 播报完成 | 10 | 回程导航精度 |

## 调试要点

### 导航调参
- `ros_ws/src/competition/config/teb_local_planner_params.yaml` — 局部规划器
- `ros_ws/src/competition/config/costmap_common_params.yaml` — 代价地图
- 建图后如果定位漂移，调整 `amcl.launch` 中的 `update_min_d` 和 `update_min_a`

### 夹取校准
- `ros_ws/src/competition/config/config.yaml`
  - `pick_location_time` — 夹取前进时间（碰台子就减，够不着就加）
  - `up_ramp_time` — 上坡前进时间（碰围挡就减）

### 形状识别
- `ros_ws/src/competition/scripts/navigation_transport/shape_recognition/shape_recognition_down.py`
  — 通过宽度/高度/边数和标准差判断正方体/长方体/圆柱体
- YOLO 模型位置：`competition/scripts/navigation_transport/yolo5/`

### 主程序
- `ros_ws/src/competition/scripts/navigation_transport/voice_control_navigation.py`
  — 各导航点的坐标、角度、模式配置

## 培训资料参考

```
~/yuetana/1-幻尔月球探索培训资料（较全）★★★(1)/
├── 4.2025ROSLander月球探索实现引导.pdf     # 调试全流程指南
├── 2.ROSLander快速使用手册.pdf              # 硬件操作手册
├── 3.场地组装指导.pdf                        # 实体场地搭建
└── ROSLander多模态机器人-2024版（Jetson Nano）/
    ├── 1.教程资料/15 MoveIt及Gazebo仿真/    # 仿真教程
    │   ├── 1 URDF模型入门.pdf
    │   ├── 2 Moveit仿真.pdf
    │   └── 3 Gazebo仿真.pdf
    ├── 4.源码/src.zip                        # ROSLander 完整源码
    └── 3.系统镜像/                            # Jetson Nano 系统镜像
```

比赛规则：
```
~/下载/CRAIC-月球探索赛项-比赛规则（国赛）/
└── 2026CRAIC-机器人任务挑战赛（复合机器人月球探索）-线上-比赛规则（国赛初赛）.pdf
```

仿真设计参考：
```
~/下载/ROSLander仿真.docx    # 之前的咨询记录（含Kimi的方案建议）
```

## 故障排查

### Docker Hub 拉取超时（国内网络）

```bash
# 现象: failed to resolve reference "docker.io/library/ros:noetic-ros-base": i/o timeout

# 方案一：配置 Docker daemon 镜像加速
sudo tee /etc/docker/daemon.json <<'EOF'
{
    "runtimes": {
        "nvidia": {
            "args": [],
            "path": "nvidia-container-runtime"
        }
    },
    "registry-mirrors": [
        "https://docker.m.daocloud.io"
    ]
}
EOF
sudo systemctl restart docker

# 方案二：Dockerfile 中直接使用镜像前缀
# 将 FROM ros:noetic-ros-base 改为 FROM docker.m.daocloud.io/ros:noetic-ros-base
```

### `docker compose` 命令不识别

```bash
# 现象: docker: unknown command: docker compose
# 原因: 系统安装的是 docker-compose v1（带连字符），非 v2 插件

# 验证
docker-compose --version   # 应该输出 docker-compose version 1.29.2

# 所有脚本已使用 docker-compose（带连字符），无需修改
```

### Gazebo 启动慢/黑屏

```bash
# 在宿主机上设置
export LIBGL_ALWAYS_SOFTWARE=0   # 使用 NVIDIA 硬件渲染
# 或
export LIBGL_ALWAYS_SOFTWARE=1   # 使用软件渲染（兼容性好但慢）
```

### 编译依赖缺失

```bash
# 在容器内
rosdep update
rosdep install --from-paths src --ignore-src -r -y
```

### 导航地图偏移

调整 AMCL 参数：减小 `update_min_d` 和 `update_min_a` 提高定位精度。

## 已知限制

1. **道具坐标是估算值** — 比赛俯视图中精确坐标无法从 PDF 提取，需在 Gazebo 中微调
2. **硬件相关节点** — 比赛功能包中的语音模块（讯飞 SDK）、舵机控制等依赖真实硬件，仿真中需 mock 或跳过
3. **YOLO TensorRT 模型** — 编译后的 `.engine` 文件是 Jetson 架构的，在 x86 Docker 中无法运行，需重新训练或使用 CPU 版 YOLO
4. **仿真 vs 实机差异** — 摩擦力、传感器噪声、光照等物理参数需按实际调校
