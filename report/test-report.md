# 测试报告

## 1. 结论

本报告记录最终工程的仿真、综合、实现、时序、DRC、bitstream 和板级功能测试结果。

最终控制关系：

```text
MyoWare ENV -> JC4 机械手
弯曲传感器 -> JC3 前臂
MPU6050 GY -> JC1 底座
```

## 2. 仿真结果

### 2.1 最终系统集成

```text
PASS EMG and flex calibration completed
PASS gripper closed: angle=58 pulse=1144 us
PASS flex JC3 angle=160 pulse=0 us
TB_BASYS3_ARM_FINAL_TOP: PASS
```

### 2.2 弯曲方向控制

```text
PASS startup stopped at angle=90
PASS high jog angle=100
PASS deadband holds angle=100 with PWM stopped
PASS low jog angle=90
PASS upper limit angle=160 with PWM stopped
PASS lower limit angle=20 with PWM stopped
TB_FLEX_DIRECTION_CONTROLLER: PASS
```

### 2.3 陀螺仪底座控制

```text
PASS confirmation and positive motion target=91
PASS sustained motion target=96
PASS deadband freezes target=96
PASS negative motion target=95
TB_GYRO_BASE_CONTROLLER: PASS
```

关键记录见 [../sim/results/final_arm_simulation_summary.txt](../sim/results/final_arm_simulation_summary.txt)。

## 3. 最终构建结果

| 项目 | 结果 |
| --- | --- |
| Vivado | 2025.1 |
| 器件 | `xc7a35tcpg236-1` |
| 完成时间 | 2026-11-01 19:21:04 |
| 综合 | 0 error |
| 实现 | 0 error |
| 时序 | WNS `+1.048 ns`，WHS `+0.065 ns` |
| 失败端点 | 0 |
| DRC | 0 error，18 条 DSP 流水线性能建议 |
| Slice LUT | 1448 / 20800（6.96%） |
| Slice Register | 971 / 41600（2.33%） |
| DSP | 6 / 90（6.67%） |
| Block RAM | 0 / 50 |
| bitstream 大小 | 2,192,144 字节 |
| bitstream SHA256 | `D489C8CF15FD0207EB3866C9796E268C7C53CCDDDA10FFFEC5AE7690FEAC56AA` |

权威文件：

- `build/reports/timing_summary.rpt`
- `build/reports/utilization.rpt`
- `build/reports/drc.rpt`
- `board/basys3_arm_final_top.bit`

## 4. 板级测试结果

| 功能 | 结果 | 说明 |
| --- | --- | --- |
| 心跳与复位 | PASS | LED0 正常，按键可复位 |
| 肌电自动校准 | PASS | 保持放松约 1.5 秒后进入就绪 |
| 机械手开合 | PASS | 紧绷闭合，放松张开 |
| 弯曲前臂点动 | PASS | 高值/低值方向正确，中间停止 |
| 陀螺仪底座 | PASS | 手腕转动驱动，停止后冻结角度 |
| SW0 方向切换 | PASS | 可适配安装方向 |
| UART | PASS | 60.13 秒内有效帧 7497，校验错误 0，序号跳变 0 |
| 独立舵机供电 | PASS | 外部 5 V 与 Basys 3 共地 |

30 分钟连续运行共记录异常复位 2 次、舵机异常动作 15 次，I2C 为偶发错误。该项未达到“无异常复位、无异常动作”的判定标准，结果记为 `FAIL`。量化数据见 `board/measurements/quantitative-results.csv`。

## 5. 采样记录

仓库提供一段 MPU6050 短时调试数据：

- `data/samples/mpu_axes_sample.csv`：MPU6050 六轴原始数据片段，用于确认 GY 轴。

该样本用于确认轴向；系统采用规则阈值控制，不使用训练集/测试集。

## 6. 仍需按实物状态检查的参数

- 舵机停止脉宽和机械零位。
- 机械结构的安全角度范围。
- 不同佩戴者的肌电基线。
- 不同安装方向下的 GY 正负方向和 SW0 设置。

修改机械结构或更换舵机后，应重新执行 [test-plan.md](test-plan.md) 中的板级测试。
