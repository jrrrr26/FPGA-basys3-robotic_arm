# 接线与供电说明

## 1. 安全要求

- 三个舵机使用独立稳压 5 V 电源，不得从 Basys 3 取电。
- 舵机电源 GND、Basys 3 GND、Pmod AD1 GND、MyoWare GND、GY-521 GND 必须共地。
- MyoWare ENV 和弯曲分压节点不得超过 3.3 V。
- 改线前先断电。
- 首次测试时舵机空载，确认方向和限位后再装机械结构。

## 2. Pmod AD1 与 Basys 3

| Pmod AD1 | Basys 3 JA | FPGA 引脚 | 功能 |
| --- | --- | --- | --- |
| 1 | JA1 | J1 | `adc_cs_n` |
| 2 | JA2 | L2 | `adc_d0` |
| 3 | JA3 | J2 | `adc_d1` |
| 4 | JA4 | G2 | `adc_sclk` |
| 5 | JA5 | GND | 公共地 |
| 6 | JA6 | 3.3 V | ADC 供电 |

模拟输入：

- A0：MyoWare 2.0 ENV。
- A1：弯曲传感器分压中点。

弯曲分压：

```text
3.3 V -> 弯曲传感器 -> A1
                        |
                     12 kOhm
                        |
                       GND
```

## 3. MPU6050 / GY-521

| GY-521 | Basys 3 JB | FPGA 引脚 |
| --- | --- | --- |
| VCC | JB6 | 3.3 V |
| GND | JB5 | GND |
| SCL | JB2 | A16 |
| SDA | JB1 | A14 |
| AD0 | JB5 | GND，地址 0x68 |

`XDA`、`XCL`、`INT` 不接。不要交换 SDA 和 SCL。

如果模块没有板载 I2C 上拉，可分别用 4.7 kOhm 将 SDA、SCL 上拉到 3.3 V。

## 4. 舵机

| 功能 | 信号 | Basys 3 引脚 |
| --- | --- | --- |
| JC1 底座 | `servo_jc1_pwm` | K17 |
| JC3 前臂 | `servo_jc3_pwm` | N17 |
| JC4 机械手 | `servo_jc4_pwm` | P18 |
| JC2 | 不使用 | M18 |

每个舵机：

- 信号线接对应 JC 引脚。
- 红线接独立 5 V 正极。
- 棕/黑线接独立电源负极。
- 独立电源负极接 Basys 3 JC5 或 JC11 GND。

在舵机电源端并联 470～1000 uF 电解电容，减少同时启动时的电压跌落。

## 5. 上电检查

断电检查：

| 检查 | 正常结果 |
| --- | --- |
| 3.3 V 与 GND | 不导通 |
| 5 V 与 GND | 不导通 |
| SDA 与 SCL | 不导通 |
| GY-521 AD0 到 GND | 导通 |
| 所有模块 GND 到公共地 | 导通 |

上电检查：

```text
传感器 3.3 V 对 GND：约 3.3 V
SDA、SCL 空闲：约 3.3 V
舵机电源对 GND：约 5 V
```

## 6. 首次上电顺序

1. 只连接 Basys 3、Pmod AD1 和传感器，断开舵机电源。
2. 下载 bitstream，确认 LED0 心跳。
3. 保持放松、手腕静止约 1.5 秒。
4. 确认 LED1 点亮、LED3 熄灭。
5. 观察串口 `raw`、`mav`、`flex`、`gyro` 和 `status`。
6. 断电后连接外部 5 V 舵机电源，再逐路测试舵机。
7. 确认方向、角度和机械限位后，再安装负载。
