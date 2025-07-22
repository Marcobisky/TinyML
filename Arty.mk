SHELL := /bin/bash

# Use F4PGA (SymbiFlow) tools from conda
CONDA_ENV = Arty-symbiflow
F4PGA_INSTALL_DIR = $(realpath ../env/symbiflow)

# Environment setup (only once)
install-sf:
	conda env create -f config/environment-symbiflow.yml
	@echo "SymbiFlow environment created. Use: conda activate $(CONDA_ENV)"





# Files
TOP = vga
VERILOG = $(TOP).v
BIT = $(TOP).bit
PCF = $(TOP).pcf
XDC = $(TOP).xdc
SDC = $(TOP).sdc

# FPGA part
PART = xc7a100tcsg324-1

all: $(BIT)

install-sf:
	conda env create -f conf/environment-symbiflow.yml
	@echo "SymbiFlow environment created. Use: conda activate $(CONDA_ENV)"

$(BIT): $(VERILOG) $(TOP).pcf $(TOP).xdc
	# Step 1: Synthesis
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_synth -t $(TOP) -v $(VERILOG) -d artix7 -p $(PART) -x $(TOP).xdc
	# Step 2: Pack
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_pack -e $(TOP).eblif -P $(PART) -s $(TOP).sdc
	# Step 3: Place
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_place -e $(TOP).eblif -p $(TOP).pcf -n $(TOP).net -P $(PART) -s $(TOP).sdc
	# Step 4: Route
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_route -e $(TOP).eblif -P $(PART) -s $(TOP).sdc
	# Step 5: Generate FASM
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_write_fasm -e $(TOP).eblif -P $(PART)
	# Step 6: Generate bitstream
	F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) conda run -n $(CONDA_ENV) symbiflow_write_bitstream -f $(TOP).fasm -d artix7 -p $(PART) -b $(BIT)

prog: $(BIT)
	openocd -f arty.cfg -c "init; pld load 0 $(BIT); shutdown"

clean:
	rm -f $(TOP).eblif $(TOP).fasm $(TOP).net $(TOP).place $(TOP).route $(TOP).sdc $(BIT) *.log *.rpt

.PHONY: all install-sf prog clean
