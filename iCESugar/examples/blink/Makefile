# Makefile for building blinky on iCE40 UP5K

TOP = blink
DEVICE = up5k

all: $(TOP).bin

$(TOP).json: $(TOP).v
	yosys -p 'synth_ice40 -top $(TOP) -json $(TOP).json' $(TOP).v

$(TOP).asc: $(TOP).json $(TOP).pcf
	nextpnr-ice40 \
		--$(DEVICE) --json $(TOP).json --pcf $(TOP).pcf --asc $(TOP).asc

$(TOP).bin: $(TOP).asc
	icepack $(TOP).asc $(TOP).bin

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).

# Programming: only Linux will work, drag .bin to the iCESugar drive on MacOS
prog: $(TOP).bin
	sudo icesprog $(TOP).bin