# OpenSTA static timing analysis for mult_array (SKY130, sky130_fd_sc_hd, typical corner).
# Run from the repository root:  sta sta/sta.tcl
# The clock period defaults to 10 ns; override it with the T environment variable:
#   T=7.50 sta sta/sta.tcl

set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

if {[info exists ::env(T)]} {
    set T $::env(T)
} else {
    set T 10.0
}
puts "Clock period T = $T ns"

# 1. Read the cell timing library
read_liberty $lib

# 2. Read and link the netlist
read_verilog synth/mult_array_netlist.v
link_design mult_array

# 3. Define the clock with period T in ns
create_clock -name clk -period $T [get_ports clk]

# 4. Input arrival time
set_input_delay 1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]

# 5. Output required time
set_output_delay 1.0 -clock clk [all_outputs]

# 6. Print the worst setup slack
report_worst_slack -max -digits 3

# 7. Save the critical path report
report_checks -path_delay max -digits 3 > sta/mult_array_timing.rpt

exit
