# 仿真

## 文件

- `run_simulation.tcl`：运行三个 Testbench。
- `tb/`：最终系统、弯曲控制和陀螺仪控制的 Testbench。
- `results/`：关键 PASS 摘要和复现说明。

## 运行

```powershell
$env:PROJECT_ROOT=(Resolve-Path ".").Path
vivado -mode batch -source sim/run_simulation.tcl
```
