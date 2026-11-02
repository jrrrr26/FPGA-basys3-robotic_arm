# 仿真证据

在本仓库根目录执行：

```powershell
$env:PROJECT_ROOT=(Resolve-Path ".").Path
vivado -mode batch -source build/create_project.tcl
vivado -mode batch -source sim/run_simulation.tcl
```

验证内容：

1. `tb_basys3_arm_final_top`：肌电、弯曲、UART、PWM 集成。
2. `tb_flex_angle_mapper`：启动停止、点动、死区、上下限。
3. `tb_gyro_base_controller`：确认、持续运动、死区冻结、反向运动。

三组测试均以 `PASS` 结束。关键输出见 `final_arm_simulation_summary.txt`。
