`timescale 1ns / 1ps

module my_and_tb();
    reg in1, in2;
    wire out;

    // Instantiate the my_and module
    my_and uut (
        .in1(in1),
        .in2(in2),
        .out(out)
    );

    initial begin
        // Initialize inputs
        in1 = 0;
        in2 = 0;

        // Wait for a while and then change inputs
        #10;
        in1 = 1; in2 = 0; // Expect out = 0
        #10;
        in1 = 0; in2 = 1; // Expect out = 0
        #10;
        in1 = 1; in2 = 1; // Expect out = 1
        #10;

        // Finish simulation
        $stop;
    end
endmodule
