TOP=blink
DEVICE=xc7a100t-1csG324
PCF=$(TOP).pcf
VERILOG=$(TOP).v

all: $(TOP).bit

$(TOP).json: $(VERILOG)
	yosys -p "synth_xilinx -top $(TOP) -json $@" $<

$(TOP).asc: $(TOP).json $(PCF)
	nextpnr-xilinx --chipdb /usr/share/nextpnr-xilinx/xc7a100t.bin \
		--json $< --write $@ --top $(TOP) --pcf $(PCF) \
		--package csg324 --speed -1

$(TOP).bit: $(TOP).asc
	xc7bitstream $< $@

prog: $(TOP).bit
	openFPGALoader -b arty-a7-100t $<

clean:
	rm -f *.json *.asc *.bit

.PHONY: all prog clean



# # 完整的开源 FPGA 工具链

# # 工具定义
# YOSYS = yosys
# NEXTPNR = nextpnr-xilinx
# OPENOCD = openocd

# # 目标文件
# VERILOG_SOURCES = soc_top.v cfu.v $(wildcard ../build/*.v)
# SYNTH_EDIF = build/synth.edif
# PNR_FASM = build/routed.fasm
# BITSTREAM = build/arty.bit

# # 默认目标
# all: $(BITSTREAM)

# # 1. 综合 (Synthesis)
# $(SYNTH_EDIF): $(VERILOG_SOURCES)
#     @echo "=== Synthesis ==="
#     mkdir -p build
#     $(YOSYS) -p "read_verilog $(VERILOG_SOURCES); \
#                  hierarchy -top soc_top; \
#                  synth_xilinx -family xc7; \
#                  write_edif $@"

# # 2. 布局布线 (Place & Route)  
# $(PNR_FASM): $(SYNTH_EDIF)
#     @echo "=== Place and Route ==="
#     $(NEXTPNR) --chipdb db/xc7a100t.bin \
#                --edif $(SYNTH_EDIF) \
#                --xdc constraints/arty_a7.xdc \
#                --part xc7a100tcsg324-1 \
#                --write $@

# # 3. 比特流生成 (Bitstream)
# $(BITSTREAM): $(PNR_FASM)  
#     @echo "=== Bitstream Generation ==="
#     fasm2bels --part xc7a100tcsg324-1 \
#               --fasm $(PNR_FASM) \
#               --bit $@

# # 4. 烧录 (Programming)
# load: $(BITSTREAM)
#     @echo "=== Programming Arty A7-100T ==="
#     $(OPENOCD) -f openocd/arty_a7.cfg \
#                -c "init; pld load 0 $(BITSTREAM); shutdown"

# # 清理
# clean:
#     rm -rf build

# # 检查工具链
# check-tools:
#     @echo "Checking toolchain..."
#     @which $(YOSYS) || echo "Missing: yosys"
#     @which $(NEXTPNR) || echo "Missing: nextpnr-xilinx"  
#     @which $(OPENOCD) || echo "Missing: openocd"

# .PHONY: all load clean check-tools