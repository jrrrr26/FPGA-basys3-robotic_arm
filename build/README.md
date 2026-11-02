# 构建脚本与报告

## 脚本

- `create_project.tcl`：从源码、Testbench 和约束创建 Vivado 工程。
- `build_bitstream.tcl`：综合、实现、生成 bitstream，并输出时序、资源和 DRC 报告。

## 报告

- `reports/timing_summary.rpt`
- `reports/utilization.rpt`
- `reports/drc.rpt`
- `reports/metrics.csv`

Vivado 自动生成的工程和中间文件位于 `build/vivado/`，该目录不提交到仓库。
