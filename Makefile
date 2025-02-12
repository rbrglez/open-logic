.PHONY: olo-lib 
olo-lib:
	fusesoc library add src

.PHONY: tutorials-lib 
tutorials-lib:
	fusesoc library add doc/tutorials

.PHONY: submodules-core-lib 
submodules-core-lib:
	fusesoc library add submodules

.PHONY: remote-core-lib 
remote-core-lib:
	fusesoc library add remote_core

.PHONY: setup-submodule 
setup-submodule: olo-lib tutorials-lib submodules-core-lib 

.PHONY: setup-remote-core 
setup-remote-core: olo-lib tutorials-lib remote-core-lib 

.PHONY: run
run:
	fusesoc run --target zybo_z7 vivado_tutorial

.PHONY: clean
clean:
	rm -rf build/
	rm -f fusesoc.conf
	rm -rf ~/.cache/fusesoc