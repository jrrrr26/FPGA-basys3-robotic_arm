# 常见问题排查

## 1. 上电后没有 LED0 心跳

- 检查 Basys 3 电源和 USB 数据线。
- 检查 bitstream 是否对应 `basys3_arm_final_top.bit`。
- 按 `btnC` 复位。

## 2. 肌电没有响应

- 确认 MyoWare ENV 接 Pmod AD1 A0。
- 确认 MyoWare 和 ADC 共地。
- 上电后保持放松约 1.5 秒完成基线校准。
- 观察串口 `raw`、`mav`、`baseline` 和 `threshold`。

## 3. 弯曲前臂不动作

- 确认弯曲分压中点接 A1，不是 JA3 数字引脚。
- 测量 A1 电压并观察 `flex` 字段。
- 高值门限为 3000，低值门限为 800。
- 确认 JC3 信号为 N17，舵机使用独立 5 V 电源。

## 4. 底座不动作或方向相反

- 确认 SDA=A14、SCL=A16，AD0 接地。
- 确认 LED7 未点亮；若点亮，表示 I2C ACK 异常。
- 上电后保持手腕静止完成陀螺仪校准。
- 切换 `SW0/V17` 检查方向。
- 如果串口 `gyro` 始终为 `-1` 或 `status` 含 I2C 错误，先检查接线，不要改阈值。

## 5. 舵机抖动或复位

- 舵机必须使用独立 5 V 电源。
- 外部电源 GND 必须与 Basys 3 GND 相连。
- 在舵机电源端并联 470～1000 uF 电容。
- 检查机械结构是否卡住或超过安全角度。

## 6. 串口没有数据

- 确认 USB-UART 驱动正常。
- 串口参数为 115200、8N1。
- 关闭其他占用 COM 口的程序。
- 使用 `python board/software/read_arm_com.py --list` 查看端口。

## 7. 修改参数后行为异常

修改 `basys3_arm_final_top.v` 中阈值、角度或方向后，必须：

1. 重新运行 `sim/run_simulation.tcl`。
2. 重新运行 `build/build_bitstream.tcl`。
3. 重新下载 bitstream。
4. 更新 `board/SHA256SUMS.txt`。
