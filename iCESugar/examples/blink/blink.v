module blink (
    input  clki,
    output led1
);

    SB_GB clk_gb (
        .USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
        .GLOBAL_BUFFER_OUTPUT(clk)
    );

    // 参数计算：
    // 假设时钟频率为12MHz，要实现0.5秒闪烁
    // 需要计数到：12MHz × 0.5s = 6,000,000
    // log2(6,000,000) ≈ 22.5，所以使用23位计数器
    localparam COUNTER_BITS = 23;
    
    reg [COUNTER_BITS-1:0] counter = 0;
    reg led_state = 0;

    always @(posedge clk) begin
        if (counter == 6000000 - 1) begin  // 0.5秒计数完成
            counter <= 0;
            led_state <= ~led_state;        // 翻转LED状态
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign led1 = led_state;
endmodule
