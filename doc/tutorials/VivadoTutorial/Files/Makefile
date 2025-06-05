

all: build

.PHONY: build
build: clean
	vivado -nojournal -nolog -mode batch -source scripted_build.tcl

.PHONY: build-sv
build-sv: clean
	vivado -nojournal -nolog -mode batch -source scripted_build_sv.tcl

.PHONY: build-sv-scoped-constraints
build-sv-scoped-constraints:
	vivado -nojournal -nolog -mode batch -source scripted_build_sv_scoped_constraints.tcl

.PHONY: gui
gui:
	vivado -nojournal -nolog tutorial_prj/*.xpr

.PHONY: gui-sv
gui-sv:
	vivado -nojournal -nolog tutorial_prj_sv/*.xpr

.PHONY: gui-sv-scoped-constraints
gui-sv-scoped-constraints:
	vivado -nojournal -nolog tutorial_prj_sv_scoped_constraints/*.xpr

.PHONY: clean
clean:
	rm -rf .Xil
	rm -rf tutorial_prj
	rm -rf tutorial_prj_sv
	rm -rf tutorial_prj_sv_scoped_constraints