set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
if {[info exists ::env(PROJECT_ROOT)]} {
    set root_dir [file normalize $::env(PROJECT_ROOT)]
}

set project_file [file join $root_dir build vivado basys3_arm_final.xpr]
set sim_dir [file join $root_dir build xsim_project]
set vivado_bin $::env(XILINX_VIVADO)/bin

if {![file exists $project_file]} {
    source [file join $root_dir build create_project.tcl]
}

file mkdir $sim_dir
cd $sim_dir

set rtl_files [glob -nocomplain [file join $root_dir src rtl *.v]]
set tb_files [glob -nocomplain [file join $root_dir sim tb *.v]]

exec [file join $vivado_bin xvlog.bat] {*}$rtl_files {*}$tb_files

foreach {top snapshot} {
    tb_basys3_arm_final_top arm_final_test
    tb_flex_angle_mapper flex_mapper_test
    tb_gyro_base_controller gyro_control_test
} {
    exec [file join $vivado_bin xelab.bat] \
        $top -s $snapshot --debug typical
    set output [exec [file join $vivado_bin xsim.bat] \
        $snapshot -runall]
    puts $output
}

puts "Final arm simulation finished."
