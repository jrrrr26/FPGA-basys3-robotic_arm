set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
if {[info exists ::env(PROJECT_ROOT)]} {
    set root_dir [file normalize $::env(PROJECT_ROOT)]
}

set project_file [file join $root_dir build vivado basys3_arm_final.xpr]

if {![file exists $project_file]} {
    source [file join $script_dir create_project.tcl]
}

open_project $project_file
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Final arm synthesis failed."
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Final arm implementation failed."
}

open_run impl_1
report_utilization -file [file join $root_dir build reports utilization.rpt]
report_timing_summary -file [file join $root_dir build reports timing_summary.rpt]
report_drc -file [file join $root_dir build reports drc.rpt]

set final_wns [get_property STATS.WNS [get_runs impl_1]]
puts "ARM_FINAL_WNS=$final_wns ns"
if {$final_wns < 0} {
    error "Final arm timing is not met."
}
