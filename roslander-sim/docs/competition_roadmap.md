# 比赛仿真任务路线图

> 当前进度：✅ 环境搭建 + SLAM 建图 | 待完成：导航、夹取、识别、全流程串联

---

## 一、比赛任务总览

| 步骤 | 任务 | 分数 | 仿真状态 | 关键依赖 |
|---|---|---|---|---|
| ① | 基地出发 → 驶入场地 | 10 | ❌ 待调试 | 语音唤醒替代、底盘运动 |
| ② | 目标确认 → 识别矿石种类 | 10 | ❌ 待调试 | YOLO 形状/颜色识别 |
| ③ | 障碍穿越 → SLAM 导航 | 20 | ⚠️ 部分完成 | AMCL 定位 + move_base |
| ④ | 矿石采集回收 → 夹取 + 搬运 ×2 | 40 | ❌ 待调试 | MoveIt 机械臂、夹取控制 |
| ⑤ | 月球环境识别 → 大模型识别 3 场景 | 10 | ❌ 未实现 | 视觉大模型接口 |
| ⑥ | 返回基地 → 回坡道 + 播报完成 | 10 | ❌ 待调试 | 回程导航、坡道对齐 |

---

## 二、下一步具体要做的事

### 2.1 导航调试（步骤③ — 得分 20）

**目标**：让机器人用保存的地图自主导航到指定坐标。

**当前状态**：SLAM 建图已通，地图可保存。

**待做**：
```bash
# 1. 用之前保存的地图启动导航
roslaunch competition navigation_base.launch sim:=true

# 2. 在 Rviz 中发布 2D Nav Goal 测试导航
# 3. 如果路径规划失败：调 costmap_common_params.yaml 和 teb_local_planner_params.yaml
# 4. 如果定位漂移：调 AMCL 参数 update_min_d / update_min_a
```

**关键文件**：
- `ros_ws/src/competition/config/costmap_common_params.yaml`
- `ros_ws/src/competition/config/teb_local_planner_params.yaml`
- `ros_ws/src/competition/config/global_costmap_params.yaml`
- `ros_ws/src/competition/config/local_costmap_params.yaml`

---

### 2.2 语音触发替代（步骤① — 得分 10）

**问题**：`voice_control_navigation.py` 依赖 `xf_mic_asr_offline`（讯飞离线语音），仿真中无此硬件。

**方案**：代码已内置 `/voice_control_nav/test` 服务，调用此服务可绕过语音直接触发任务：

```bash
# 启动全流程程序（需先完成导航初始化）
rosservice call /voice_control_nav/test "{}"
```

---

### 2.3 YOLO 识别调试（步骤② — 得分 10）

**问题**：`yolo5/` 目录下是 Jetson TensorRT `.engine` 模型文件，x86 Docker 无法运行。

**待做**：
1. 在 x86 上重新训练/导出 ONNX 或 CPU 版 YOLO 模型
2. 或者用 Gazebo 相机话题直接做 OpenCV 形状检测替代
3. 矿石灰识别三种：正方体(绿色)、长方体(黄色)、圆柱体(蓝色)

**关键文件**：
- `ros_ws/src/competition/scripts/navigation_transport/yolo5/`
- `ros_ws/src/competition/scripts/navigation_transport/shape_recognition_down.py`

---

### 2.4 机械臂夹取（步骤④ — 得分 40）

**问题**：代码依赖 `bus_servo_control`、`servo_controllers` 等真实舵机驱动，仿真中用 MoveIt。

**待做**：
1. 确认 `roslander_moveit_config` 包在仿真中可用（MoveIt 机械臂运动规划）
2. 将 `voice_control_navigation.py` 中的舵机控制替换为 MoveIt 接口
3. 或者启动 MoveIt 的 `arm_controller`，通过 `/robot_1/arm_controller/command` 话题控制

**关键文件**：
- `ros_ws/src/simulations/roslander_moveit_config/`
- `ros_ws/src/competition/scripts/navigation_transport/automatic_pick.py`

---

### 2.5 场景识别（步骤⑤ — 得分 10）

**当前状态**：代码中无此功能实现。

**待做**：
1. 接入视觉大模型 API（如阿里云通义千问 VL、OpenAI GPT-4V 等）
2. 用 Gazebo 相机拍摄场景 → 调用 API → 获取识别结果
3. 需要识别的 3 个场景：月球基地、月球资源库、障碍区域

---

### 2.6 返回基地（步骤⑥ — 得分 10）

**问题**：代码依赖 `ramp.py`（坡道对齐），依赖深度相机和红外传感器。仿真中需简化。

**待做**：
1. 用纯导航坐标代替坡道传感器反馈
2. 在 `voice_control_navigation.py` 的 `run()` 方法中最后的 `self.control(1.3, -0.07, -180, "back")` 调整坐标

**关键文件**：
- `ros_ws/src/competition/scripts/navigation_transport/ramp.py`
- `ros_ws/src/competition/scripts/navigation_transport/position_correction_pick.launch`

---

### 2.7 全流程串联

所有子模块调试完成后，修改 `voice_control_navigation.py` 的 `run()` 方法：

```python
def run(self):
    # 1. 语音唤醒 → 驶入场地
    self.control(x1, y1, w1, "move")
    
    # 2. 目标确认 → 识别矿石
    self.control(x2, y2, w2, "detect")
    
    # 3. 障碍穿越 → 导航到采集点
    # （导航本身已自动避障）
    
    # 4. 矿石采集 → 夹取 + 搬运 ×2
    self.control(x3, y3, w3, "pick")
    self.control(x4, y4, w4, "place")
    self.control(x5, y5, w5, "pick")
    self.control(x6, y6, w6, "place")
    
    # 5. 场景识别
    self.control(x7, y7, w7, "scene_detect")
    
    # 6. 返回基地
    self.control(x8, y8, w8, "back")
```

> ⚠️ `run()` 中的坐标（x, y, w）是实机测试值，需要在仿真场景中逐一重新测量。

---

## 三、仿真 vs 实机差异速查

| 组件 | 仿真实机 | 仿真方案 |
|---|---|---|
| 语音识别 | 讯飞离线 SDK | `/test` 服务绕过 |
| 底盘驱动 | STM32 串口 `/dev/rrc` | Gazebo PlanarMovePlugin |
| 激光雷达 | 真实 S2L/G4 雷达 | Gazebo Ray Sensor |
| 深度相机 | Astra Pro Plus | Gazebo Camera Plugin |
| 机械臂舵机 | bus_servo_control | MoveIt + ros_control |
| YOLO 识别 | TensorRT .engine（Jetson） | ONNX / OpenCV 替代 |
| 坡道传感器 | 红外 + 深度对齐 | 纯导航坐标替代 |
| IMU | MPU6050 | Gazebo IMU Plugin |
| LED/蜂鸣器 | ROS Robot Controller | `roscpp` 日志替代 |

---

## 四、优先级建议

| 优先级 | 任务 | 理由 |
|---|---|---|
| 🔴 P0 | 导航调试 | 步骤③（20分）+ 是整个流程的基础 |
| 🟡 P1 | YOLO 替代方案 | 步骤②（10分）+ 决定了夹取哪种矿石 |
| 🟡 P1 | MoveIt 机械臂 | 步骤④（40分，最大分值） |
| 🟢 P2 | 语音绕过测试 | 步骤①（10分），已有 `/test` 服务 |
| 🟢 P2 | 返回基地 | 步骤⑥（10分） |
| ⚪ P3 | 场景识别 | 步骤⑤（10分），需外部 API |
