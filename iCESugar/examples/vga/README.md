# VGA Display Project for iCESugar

This project displays a solid blue screen on a VGA monitor using the iCESugar FPGA board.

## Features
- VGA output at 320x240 resolution with ~125Hz refresh rate
- Displays a solid blue screen (easier for monitors to detect)
- Uses PMOD2 and PMOD3 connectors for VGA interface
- 4-bit color depth per channel (RGB)
- 12MHz pixel clock for better monitor compatibility

## Hardware Connections

### CRITICAL: VGA Resistor Ladders Required!
VGA uses analog RGB signals (0.7V peak). You MUST use resistor ladders to convert the FPGA's 3.3V digital outputs to proper VGA levels:

**For each RGB channel (4-bit DAC):**
- Bit 3 (MSB): 270Ω resistor
- Bit 2: 540Ω resistor  
- Bit 1: 1.1kΩ resistor
- Bit 0 (LSB): 2.2kΩ resistor
- All connect to 75Ω load resistor to ground

**Alternative simple approach:**
- Use 470Ω resistors on each RGB bit
- Connect all to VGA RGB pins (may be bright but should work)

### VGA Connector Pinout
Connect to a standard VGA connector (DB15):

**PMOD2 Connections:**
- P2_1 (Pin 46): HSYNC → VGA Pin 13
- P2_2 (Pin 44): VSYNC → VGA Pin 14
- P2_3 (Pin 42): Red[0] (LSB) → Through resistors to VGA Pin 1
- P2_4 (Pin 37): Red[1] → Through resistors to VGA Pin 1  
- P2_9 (Pin 36): Red[2] → Through resistors to VGA Pin 1
- P2_10 (Pin 38): Red[3] (MSB) → Through resistors to VGA Pin 1
- P2_11 (Pin 43): Green[0] (LSB) → Through resistors to VGA Pin 2
- P2_12 (Pin 45): Green[1] → Through resistors to VGA Pin 2

**PMOD3 Connections:**
- P3_1 (Pin 34): Green[2] → Through resistors to VGA Pin 2
- P3_2 (Pin 31): Green[3] (MSB) → Through resistors to VGA Pin 2
- P3_3 (Pin 27): Blue[0] (LSB) → Through resistors to VGA Pin 3
- P3_4 (Pin 25): Blue[1] → Through resistors to VGA Pin 3
- P3_9 (Pin 23): Blue[2]
- P3_10 (Pin 26): Blue[3] (MSB)

### VGA Cable Wiring
Connect to a standard VGA connector (DB15):
- Pin 1: Red (connect to Red[3:0] through resistor ladder)
- Pin 2: Green (connect to Green[3:0] through resistor ladder)
- Pin 3: Blue (connect to Blue[3:0] through resistor ladder)
- Pin 5: GND (ground)
- Pin 10: GND (ground)
- Pin 13: HSYNC
- Pin 14: VSYNC

### Resistor Ladder for Analog RGB
For proper VGA levels, use resistor ladders:
- Bit 3 (MSB): 2.2kΩ to VGA pin
- Bit 2: 4.7kΩ to VGA pin
- Bit 1: 10kΩ to VGA pin
- Bit 0 (LSB): 22kΩ to VGA pin

## Building and Programming

### Prerequisites
- Yosys (synthesis)
- NextPNR (place and route)
- IceStorm tools (icepack, iceprog)

### Build Commands
```bash
# Synthesize and build
make

# Program the FPGA
make prog
# or with sudo if needed
make sudo-prog

# Clean build files
make clean
```

## Current Limitations

This implementation uses 640x480@60Hz instead of 1920x1080@60Hz because:

1. **Clock Speed**: 1920x1080@60Hz requires a 148.5MHz pixel clock, which is challenging to generate accurately with the iCE40UP5K's limited PLL capabilities.

2. **Memory**: Higher resolution would require more BRAM for frame buffering.

3. **Pin Count**: The iCESugar has limited I/O pins for high-speed digital video.

## Upgrading to 1920x1080

To support 1920x1080@60Hz, you would need:

1. **External Clock**: Use an external crystal oscillator or clock generator for 148.5MHz
2. **Better FPGA**: Consider using a larger FPGA with more PLLs and higher speed capabilities
3. **DDR Memory**: External DDR memory for frame buffering
4. **High-Speed I/O**: Proper impedance matching and high-speed design practices

## Testing

1. Connect your VGA monitor to the PMOD connectors as described above
2. Program the FPGA with `make prog`
3. You should see a white letter 'a' centered on a black background

The green LED on the board will light up to indicate the design is running.
