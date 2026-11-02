set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
if {[info exists ::env(PROJECT_ROOT)]} {
    set root_dir [file normalize $::env(PROJECT_ROOT)]
}

set project_dir [file join $root_dir build vivado]
set project_name basys3_arm_final
set project_file [file join $project_dir ${project_name}.xpr]

file mkdir $project_dir
create_project -force $project_name $project_dir -part xc7a35tcpg236-1

add_files -fileset sources_1 [glob -nocomplain [file join $root_dir src rtl *.v]]
add_files -fileset sim_1 [glob -nocomplain [file join $root_dir sim tb *.v]]
add_files -fileset constrs_1 [file join $root_dir board constraints basys3_arm_final.xdc]

set_property top basys3_arm_final_top [get_filesets sources_1]
set_property top tb_basys3_arm_final_top [get_filesets sim_1]
set_property target_language Verilog [current_project]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "PROJECT_FILE=$project_file"
close_project
