`timescale 1ns / 1ps

module my_and(
    input wire in1, in2,
    output wire out
    );
    assign out = in1 & in2;
endmodule
