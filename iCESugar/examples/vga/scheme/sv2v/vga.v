module vga_display (
    input wire clk,          // 12MHz input clock from iCESugar
    input wire reset,        // Reset signal (active high)
    
    // VGA outputs using PMOD2 and PMOD3
    output wire hsync,       // Horizontal sync
    output wire vsync,       // Vertical sync
    output wire [3:0] red,   // Red channel (4 bits)
    output wire [3:0] green, // Green channel (4 bits) 
    output wire [3:0] blue   // Blue channel (4 bits)
);

    // Use 12MHz directly as pixel clock for better compatibility
    // This gives us a custom timing that should work better
    wire pixel_clk = clk;
    
    // Custom 640x480-like timing optimized for 12MHz pixel clock
    // Reduced total pixels to increase refresh rate
    parameter H_DISPLAY = 320;  // Half of 640 for faster timing
    parameter H_FRONT = 8;      // Reduced front porch
    parameter H_SYNC = 32;      // Reduced sync pulse
    parameter H_BACK = 16;      // Reduced back porch
    parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 376

    parameter V_DISPLAY = 240;  // Half of 480 for faster timing
    parameter V_FRONT = 2;      // Reduced front porch
    parameter V_SYNC = 4;       // Standard sync pulse
    parameter V_BACK = 8;       // Reduced back porch
    parameter V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 254

    // Counters for pixel position
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;
    
    // Pixel clock domain logic
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Generate sync signals (negative polarity for VGA compatibility)
    assign hsync = ~((h_count >= (H_DISPLAY + H_FRONT)) && 
                     (h_count < (H_DISPLAY + H_FRONT + H_SYNC)));
    assign vsync = ~((v_count >= (V_DISPLAY + V_FRONT)) && 
                     (v_count < (V_DISPLAY + V_FRONT + V_SYNC)));

    // Display enable signal
    wire display_enable = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // RGB output logic
    reg [3:0] red_reg, green_reg, blue_reg;
    
    always @(posedge pixel_clk) begin
        if (display_enable) begin
            // Simple solid blue screen - easier for monitor to detect
            red_reg <= 4'h0;
            green_reg <= 4'h0;
            blue_reg <= 4'hF;  // Full blue
        end else begin
            // Blanking period - must be black
            red_reg <= 4'h0;
            green_reg <= 4'h0;
            blue_reg <= 4'h0;
        end
    end

    assign red = red_reg;
    assign green = green_reg;
    assign blue = blue_reg;

endmodule

// Top-level module for iCESugar board
module top (
    input wire clk,           // 12MHz clock from iCESugar
    
    // VGA signals mapped to PMOD2 and PMOD3
    output wire P2_1,         // HSYNC
    output wire P2_2,         // VSYNC
    output wire P2_3,         // Red[0]
    output wire P2_4,         // Red[1]
    output wire P2_9,         // Red[2]
    output wire P2_10,        // Red[3]
    output wire P2_11,        // Green[0]
    output wire P2_12,        // Green[1]
    
    output wire P3_1,         // Green[2]
    output wire P3_2,         // Green[3]
    output wire P3_3,         // Blue[0]
    output wire P3_4,         // Blue[1]
    output wire P3_9,         // Blue[2]
    output wire P3_10,        // Blue[3]
    
    // LEDs for status indication
    output wire LED_R,        // Red LED
    output wire LED_G,        // Green LED
    output wire LED_B         // Blue LED
);

    // Internal signals
    wire hsync, vsync;
    wire [3:0] red, green, blue;
    wire reset = 1'b0;  // No reset for now
    
    // Instantiate VGA display module
    vga_display vga_inst (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .red(red),
        .green(green),
        .blue(blue)
    );
    
    // Map VGA signals to PMOD pins
    assign P2_1 = hsync;      // HSYNC
    assign P2_2 = vsync;      // VSYNC
    assign P2_3 = red[0];     // Red LSB
    assign P2_4 = red[1];
    assign P2_9 = red[2];
    assign P2_10 = red[3];    // Red MSB
    assign P2_11 = green[0];  // Green LSB
    assign P2_12 = green[1];
    
    assign P3_1 = green[2];
    assign P3_2 = green[3];   // Green MSB
    assign P3_3 = blue[0];    // Blue LSB
    assign P3_4 = blue[1];
    assign P3_9 = blue[2];
    assign P3_10 = blue[3];   // Blue MSB
    
    // Status LEDs - use for debugging VGA signals
    assign LED_R = hsync;         // Red LED shows hsync activity
    assign LED_G = vsync;         // Green LED shows vsync activity  
    assign LED_B = display_enable; // Blue LED shows when display is active

endmodule