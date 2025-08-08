#-----------------------------------------------------------------------------
#-  Copyright (c) 2025 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_base_ram_sdp
# Load in Vivado using "read_xdc -ref olo_base_ram_sdp <path>/olo_base_ram_sdp.tcl"

# These constraints are only necessary when the RAM is implemented as LUTRAM
set ram_type [expr {[regexp {LUTRAM} [get_property PRIMITIVE_SUBGROUP [get_cells -hierarchical g_async.Mem_v*]]] ? "LUTRAM" : ""}]

if {$ram_type eq "LUTRAM"} {
    set launch_clk [get_clocks -of_objects [get_cell -hierarchical g_async.Mem_v*]]
    set latch_clk [get_clocks -of_objects [get_cell -hierarchical g_async.RdPipe_reg[1][*]]]

    set period [get_property -min PERIOD [get_clocks "$launch_clk $latch_clk"]]

    set_max_delay -from $launch_clk -to [get_cell -hierarchical g_async.RdPipe_reg[1][*]] -datapath_only $period
}