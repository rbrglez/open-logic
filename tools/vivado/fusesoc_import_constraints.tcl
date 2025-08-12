#Automatically load all constraints
namespace eval fusesoc_import_constraints {
	puts "#################################################"
	puts "## fusesoc_import_constraints"
	puts "#################################################"

	add_files -fileset constrs_1 -norecurse tools/vivado/all_constraints_amd.tcl
	set_property used_in_synthesis false [get_files tools/vivado/all_constraints_amd.tcl]
	set_property used_in_simulation false [get_files tools/vivado/all_constraints_amd.tcl]
	set_property PROCESSING_ORDER LATE [get_files tools/vivado/all_constraints_amd.tcl]
}