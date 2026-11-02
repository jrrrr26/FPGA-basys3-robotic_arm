# Vivado 干净构建检查

## 适用场景

任何以 Vivado 为构建工具、使用 Tcl 脚本创建工程的 RTL 项目。

## 输入

- `src/rtl/*.v`
- `sim/tb/*.v`
- `board/constraints/*.xdc`
- `build/create_project.tcl`
- `sim/run_simulation.tcl`
- `build/build_bitstream.tcl`

## 使用步骤

1. 检查仓库是否干净：

```powershell
python skill/vivado-clean-build/check_repo.py .
```

2. 从零创建工程：

```powershell
$env:PROJECT_ROOT=(Resolve-Path ".").Path
vivado -mode batch -source build/create_project.tcl
```

3. 运行仿真：

```powershell
vivado -mode batch -source sim/run_simulation.tcl
```

4. 生成 bitstream 和报告：

```powershell
vivado -mode batch -source build/build_bitstream.tcl
```

5. 检查：

- 所有 Testbench 是否打印 PASS。
- `build/reports/timing_summary.rpt` 是否存在 WNS。
- `build/reports/utilization.rpt` 是否有资源和器件总量。
- `build/reports/drc.rpt` 是否有 Error。
- bitstream 是否生成。

## 失效条件

- Vivado 版本与脚本不兼容。
- 缺少器件型号或约束。
- 工程依赖仓库外部文件。
- 仿真 Testbench 依赖未被提交的数据。

## 已验证结果

- 项目：Basys 3 机械臂控制系统
- Vivado：2025.1
- 三组仿真：PASS
- 综合与实现：0 error
- WNS：`+1.048 ns`
- 资源：LUT 1448、FF 971、DSP 6、BRAM 0

## 提炼来源

- 原工程依赖多个相邻目录，移动或复制后曾出现源码路径失效。
- 构建目录和自动生成日志混入源码目录后，网页上传容易误传大量无关文件。
- 将路径检查、仿真、综合和报告输出固定为独立流程后，陌生环境可以从仓库根目录重新执行。

## 迁移到其他项目

保留检查思路，替换 RTL、约束、Testbench 和预期输出即可。不要直接复用本项目的引脚和阈值。
