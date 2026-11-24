// P2-03: user board shell. Use only after BD regenerates wrapper ports.
// (유지) BTN C is system reset, not an event input.
// (유지) LED0 uses P2-01 IP; FND outputs use P2-02 IP.
// (추가) Four separate button ports; IRQ stays inside BD -> AXI INTC.
module basys3_soc11_top (
    input wire clk, input wire btnC,
    input wire btnU, input wire btnD, input wire btnL, input wire btnR,
    input wire [15:0] sw,
    output wire [15:0] led,
    input wire RsRx, output wire RsTx,
    output wire [6:0] seg, output wire [3:0] an, output wire dp
);
    wire [15:0] gpio_led;
    wire ip_led0;
    assign led = {gpio_led[15:1], ip_led0}; // Shell-only bit connection.

    soc11_integration_wrapper u_soc11 (
        .clk(clk), .btnC(btnC),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .sw_tri_i(sw), .led_tri_o(gpio_led),
        .UART_0_rxd(RsRx), .UART_0_txd(RsTx),
        .p2_led_o(ip_led0),
        .fnd_seg(seg), .fnd_an(an), .fnd_dp(dp)
    );
endmodule
