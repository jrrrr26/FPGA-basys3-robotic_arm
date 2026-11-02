# 上位机脚本

## read_arm_com.py

读取最终工程的 18 字节 UART 遥测帧，检查帧头和异或校验，并解析：

- 肌电原始值、滑动平均、基线、阈值。
- 弯曲传感器值。
- 最终选定的陀螺仪轴值。
- 全部状态位。

安装依赖：

```powershell
python -m pip install -r board/software/requirements.txt
```

查看串口：

```powershell
python board/software/read_arm_com.py --list
```

读取 COM9：

```powershell
python board/software/read_arm_com.py --port COM9
```

保存 CSV：

```powershell
python board/software/read_arm_com.py --port COM9 --csv data/samples/arm_telemetry.csv
```
