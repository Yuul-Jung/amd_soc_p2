// P2-05 USER TOP (Shell/Wrapper ONLY): no priority, arithmetic or FSM here.
// Keep Basys3 LED0 (P2-01), LED1 PWM (P2-04) and GPIO[15:2] ownership.
// (변경) P2-04 pwm_led1 is an INTERNAL source; auto_light_controller owns LED1.
// IMPORTANT: generated soc11_integration_wrapper ports MUST be rechecked.
module basys3_soc11_top (
    input wire clk, input wire btnC,
    input wire btnU, input wire btnD, input wire btnL, input wire btnR,
    input wire cds_digital, // JA1 J1 (verified only at XDC level, module not yet)
    input wire [15:0] sw, output wire [15:0] led,
    input wire RsRx, output wire RsTx,
    output wire [6:0] seg, output wire [3:0] an, output wire dp
);
    wire [15:0] gpio_led;
    wire p2_led0;
    wire pwm_led1;
    wire auto_enable;
    wire cds_dark;
    wire cds_valid;
    wire light_led1;

    // (추가) Board-independent mode controller owns LED1 logic.
    auto_light_controller u_light_controller (
        .pwm_led_i(pwm_led1), .auto_enable_i(auto_enable),
        .sensor_dark_i(cds_dark), .sensor_valid_i(cds_valid),
        .led1_o(light_led1)
    );
    // (유지) Top uses simple bit select and concatenation only.
    assign led = {gpio_led[15:2], light_led1, p2_led0};

    soc11_integration_wrapper u_soc11 (
        .clk(clk), .btnC(btnC),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .sw_tri_i(sw), .led_tri_o(gpio_led),
        .UART_0_rxd(RsRx), .UART_0_txd(RsTx),
        .p2_led_o(p2_led0), .pwm_led1(pwm_led1),
        .fnd_seg(seg), .fnd_an(an), .fnd_dp(dp),
        .cds_digital(cds_digital),
        .cds_dark(cds_dark), .cds_valid(cds_valid),
        .cds_auto_enable(auto_enable)
    );
endmodule
