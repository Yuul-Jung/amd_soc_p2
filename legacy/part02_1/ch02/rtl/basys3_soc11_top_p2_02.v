// P2-02: top shell (use in copied soc_ip_design_02 project only).
// (유지) P2-01 LED0 is from user AXI LED IP; LED1..15 from old GPIO.
// (추가) Built-in four-digit FND pin connections; no functional logic here.
module basys3_soc11_top (
    input  wire        clk,     // W5: original system clock
    input  wire        btnC,    // U18: original system reset
    input  wire [15:0] sw,
    output wire [15:0] led,
    input  wire        RsRx,
    output wire        RsTx,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        dp
);
    wire [15:0] gpio_led;
    wire ip_led0;

    // (유지) Top permits only simple wiring / bit selection.
    assign led = {gpio_led[15:1], ip_led0};

    // Generated Wrapper must already expose all these exact ports.
    soc11_integration_wrapper u_soc11 (
        .clk(clk), .btnC(btnC),
        .sw_tri_i(sw), .led_tri_o(gpio_led),
        .UART_0_rxd(RsRx), .UART_0_txd(RsTx),
        .p2_led_o(ip_led0),
        .fnd_seg(seg), .fnd_an(an), .fnd_dp(dp)
    );
endmodule
