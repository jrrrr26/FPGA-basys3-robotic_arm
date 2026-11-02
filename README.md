# 基于 Basys 3 的肌电、弯曲与陀螺仪机械臂控制系统

本项目使用一块 Digilent Basys 3（XC7A35T）完成三路传感器到三路舵机的实时控制：

- MyoWare 2.0 肌电包络控制 JC4 机械手张开/闭合。
- 弯曲传感器控制 JC3 前臂位置。
- MPU6050 陀螺仪 Y 轴控制 JC1 底座左右转动。
- 所有处理在 FPGA 内部完成，不依赖上位机闭环。

## 团队信息

- 团队编号：55240
- 队伍名称：南北红豆
- 团队成员：杜涵宇、郑钧仁
- 参赛方向：AMD-自主选题（初级），本科组

## 功能映射

| 输入 | 控制目标 | 控制方式 |
| --- | --- | --- |
| MyoWare ENV -> Pmod AD1 A0 | JC4 机械手 | 放松张开，紧绷闭合 |
| 弯曲传感器 -> Pmod AD1 A1 | JC3 前臂 | 高值向 160°、低值向 20° 点动，中间停止 |
| GY-521 MPU6050 GY -> JB I2C | JC1 底座 | 手腕角速度控制目标角，带确认和死区 |

JC2/M18 不使用。三路舵机均为 180° 位置舵机，使用 50 Hz、0.5～2.5 ms PWM。

## 操作方式

1. 上电后保持肌肉放松、手腕静止约 1.5 秒，让肌电基线和陀螺仪零偏自动完成。
2. `btnC/U18`：全局复位。
3. `btnU/T18`：重新校准肌电基线和陀螺仪零偏。
4. 肌电从放松变为紧绷：JC4 机械手逐渐闭合；恢复放松后逐渐张开。
5. 弯曲传感器大于 3000：JC3 向 160° 转动；小于 800：向 20° 转动。
6. 弯曲传感器回到中间区：停止 JC3 PWM，并保持最后指令角度。
7. 手腕转动：GY 角速度经过约 120 ms 连续确认后，JC1 开始响应。
8. `SW0/V17` 向上：GY 方向不取反；向下：GY 方向取反。

## 硬件连接

| 模块 | 连接 |
| --- | --- |
| Pmod AD1 | JA1～JA6 |
| MyoWare ENV | Pmod AD1 模拟输入 A0 |
| 弯曲传感器分压中点 | Pmod AD1 模拟输入 A1 |
| GY-521 SDA | JB1 / A14 |
| GY-521 SCL | JB2 / A16 |
| GY-521 VCC | JB6 / 3.3 V |
| GY-521 GND、AD0 | JB5 / GND |
| JC1 底座舵机 | K17 |
| JC3 前臂舵机 | N17 |
| JC4 机械手舵机 | P18 |

完整接线和供电要求见 [board/wiring.md](board/wiring.md)，结构化引脚表见 [board/pinmap.csv](board/pinmap.csv)。

> 三个舵机必须使用独立稳压 5 V 电源，并与 Basys 3 共地。不要从 Basys 3 给舵机供电。

## 仓库结构

```text
.
├── README.md
├── LICENSE
├── src/
│   └── rtl/
├── sim/
│   ├── tb/
│   └── results/
├── build/
│   └── reports/
├── board/
│   ├── constraints/
│   ├── photos/
│   └── measurements/
├── data/
├── skill/
└── report/
```

## 快速开始

### 1. 创建工程

在仓库根目录执行：

```powershell
$env:PROJECT_ROOT=(Resolve-Path ".").Path
vivado -mode batch -source build/create_project.tcl
```

### 2. 运行全部仿真

```powershell
vivado -mode batch -source sim/run_simulation.tcl
```

应看到：

```text
TB_BASYS3_ARM_FINAL_TOP: PASS
TB_FLEX_DIRECTION_CONTROLLER: PASS
TB_GYRO_BASE_CONTROLLER: PASS
```

### 3. 生成 bitstream

```powershell
vivado -mode batch -source build/build_bitstream.tcl
```

生成位置：

```text
build/vivado/basys3_arm_final.runs/impl_1/basys3_arm_final_top.bit
```

### 4. 下载到开发板

连接 Basys 3 后执行：

```powershell
vivado -mode batch -source board/program.tcl
```

也可以直接在 Vivado Hardware Manager 中下载 [已验证 bitstream](board/basys3_arm_final_top.bit)。

## 串口数据

串口参数：`115200 8N1`，固定 18 字节帧。

```text
AA 55
seq_hi seq_lo
raw_hi raw_lo
mav_hi mav_lo
baseline_hi baseline_lo
threshold_hi threshold_lo
flex_hi flex_lo
gyro_hi gyro_lo
status
xor_checksum
```

`status`：

- bit0：肌电紧绷。
- bit1：肌电校准完成。
- bit2：肌电正在校准。
- bit3：机械手控制已激活。
- bit4：弯曲方向控制器已获得有效输入。
- bit5：陀螺仪校准完成。
- bit6：I2C ACK 异常。
- bit7：底座控制已激活。

读取数据：

```powershell
python -m pip install -r board/software/requirements.txt
python board/software/read_arm_com.py --port COM9
```

保存 CSV：

```powershell
python board/software/read_arm_com.py --port COM9 --csv data/samples/arm_telemetry.csv
```

## 指示灯

- LED0：心跳。
- LED1：肌电放松。
- LED2：肌电紧绷。
- LED3：正在校准或陀螺仪尚未准备。
- LED4：机械手控制已激活。
- LED5：JC3 弯曲控制已激活。
- LED6：陀螺仪校准完成。
- LED7：I2C 通信错误。
- LED15～LED8：肌电活动强度条。

四位数码管显示 MyoWare ENV 的 12 位原始值。

## 已验证结果

| 项目 | 结果 |
| --- | --- |
| 仿真 | 最终集成、弯曲控制、陀螺仪控制三组 Testbench 全部 PASS |
| 综合 | 0 error |
| 实现 | 0 error |
| DRC | 0 error，18 条 DSP 流水线性能建议 |
| 时序 | WNS `+1.048 ns`，WHS `+0.065 ns` |
| Slice LUT | 1448 / 20800（6.96%） |
| Slice Register | 971 / 41600（2.33%） |
| DSP | 6 / 90（6.67%） |
| Block RAM | 0 / 50 |
| bitstream 大小 | 2,192,144 字节 |
| bitstream SHA256 | `D489C8CF15FD0207EB3866C9796E268C7C53CCDDDA10FFFEC5AE7690FEAC56AA` |

30 分钟连续运行测试记录异常复位 2 次、舵机异常动作 15 次，I2C 为偶发错误。连续运行项目前未通过，详细记录见[测试报告](report/test-report.md)。

详细报告：

- [测试报告](report/test-report.md)
- [完整设计报告 Markdown](report/design-report.md)
- [完整设计报告 Word](report/design-report.docx)
- [完整设计报告 PDF](report/design-report.pdf)
- [AI 协作记录](report/ai-collaboration-log.md)
- [可复用技能包](skill/README.md)
- [时序报告](build/reports/timing_summary.rpt)
- [资源报告](build/reports/utilization.rpt)
- [DRC 报告](build/reports/drc.rpt)
- [板级测试记录](board/measurements/board-validation.csv)
- [量化测量模板](board/measurements/quantitative-results.csv)
- [上板测试与测量方法](report/board-test-method.md)
- [仿真记录](sim/results/final_arm_simulation_summary.txt)
- [演示视频入口](report/demo-links.md)

> 时序和资源结论来自最终布线后的 Vivado 报告。赛事指南推荐 Vivado 2026.1 或 2025.2；本项目使用 Vivado 2025.1，并已通过自包含脚本从干净仓库复现仿真、综合和实现。详细说明见设计报告第 9.1 节。

> 仓库内 `board/basys3_arm_final_top.bit` 是实际验证的 bitstream。

## 参数调整入口

最终参数集中在 `src/rtl/basys3_arm_final_top.v`：

```verilog
FLEX_HIGH_ENTER   = 3000
FLEX_HIGH_RELEASE = 2500
FLEX_LOW_ENTER    = 800
FLEX_LOW_RELEASE  = 1200

GRIP_OPEN_ANGLE   = 30
GRIP_CLOSED_ANGLE = 150

GYRO_DEADBAND     = 2600
GYRO_MED          = 5000
GYRO_FAST         = 10000
```


## 许可证

本项目使用 [MIT License](LICENSE)。
