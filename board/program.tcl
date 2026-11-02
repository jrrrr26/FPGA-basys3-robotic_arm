set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
if {[info exists ::env(PROJECT_ROOT)]} {
    set root_dir [file normalize $::env(PROJECT_ROOT)]
}

set bit_file [file join $root_dir board basys3_arm_final_top.bit]

if {![file exists $bit_file]} {
    error "Bitstream not found: $bit_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets]
if {[llength $targets] == 0} {
    error "No JTAG target found"
}
open_hw_target [lindex $targets 0]

set devices [get_hw_devices xc7a35t_0]
if {[llength $devices] == 0} {
    error "Basys 3 device xc7a35t_0 not found"
}
set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device $dev
puts "PROGRAMMED=$bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
