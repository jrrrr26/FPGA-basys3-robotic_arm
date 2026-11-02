# UART 遥测帧检查

## 适用场景

使用固定帧头、固定长度和异或校验的二进制 UART 遥测协议。

## 本项目帧格式

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

总长度 18 字节。

## 使用步骤

1. 从串口复制一帧 18 字节数据。
2. 运行：

```powershell
python skill/uart-telemetry-check/check_frame.py "AA 55 00 01 ..."
```

3. 检查脚本输出的：

- `frame_size`
- `checksum_ok`
- `seq`
- `raw`
- `mav`
- `baseline`
- `threshold`
- `flex`
- `gyro_axis`
- `status_bits`

## 失效条件

- 固件修改帧长度但脚本未同步。
- 串口使用不同波特率或 9 位数据。
- 帧头出现在载荷中且同步逻辑不严谨。

## 已验证结果

- 已用项目实际 18 字节遥测帧验证校验和负数解析。
- 可正确识别错误帧长度和错误校验和。

## 提炼来源

- I2C 通信失败时，串口曾显示 `gyro = -1`，对应原始字节为 `FF FF`。
- 仅观察浮点显示无法区分通信错误和真实小信号，因此需要同时检查状态位、帧长和异或校验。
- 该检查方法可迁移到其他固定帧头的二进制 UART 协议。

## 迁移方式

如果目标项目帧头、长度或字段不同，修改脚本顶部常量和字段偏移即可；校验算法需要按目标协议重新确认。
