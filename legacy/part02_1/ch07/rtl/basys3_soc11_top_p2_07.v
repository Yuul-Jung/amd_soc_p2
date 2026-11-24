// P2-07 USER TOP: Shell/Wrapper ONLY. No always/FSM/policy expressions.
// (유지) LED0 P2-01; LED1 P2-05 AUTO/PWM controller;
// (변경) LED2 P2-06 sonic_alert, LED3~15 old GPIO.
// WARNING: generated BD Wrapper MUST expose motor outputs before use.
module basys3_soc11_top (
    input wire clk, input wire btnC,
    input wire btnU, input wire btnD, input wire btnL, input wire btnR,
    input wire cds_digital, // JA1, J1 (P2-05)
    output wire sonic_trig, // JA2, L2; see level-shifting note
    input wire sonic_echo,  // JA3, J2; external 5V->3.3V conversion required
    output wire motor_in1, output wire motor_in2, output wire motor_ena,
    input wire [15:0] sw, output wire [15:0] led,
    input wire RsRx, output wire RsTx,
    output wire [6:0] seg, output wire [3:0] an, output wire dp
);
    wire [15:0] gpio_led;
    wire p2_led0;
    wire pwm_led1;
    wire auto_enable, cds_dark, cds_valid;
    wire light_led1;
    wire sonic_alert, sonic_unsafe;
    auto_light_controller u_light_controller (
        .pwm_led_i(pwm_led1),.auto_enable_i(auto_enable),
        .sensor_dark_i(cds_dark),.sensor_valid_i(cds_valid),
        .led1_o(light_led1)
    );
    // (변경) Pure board-bit wiring; LED2 has exactly one source.
    assign led = {gpio_led[15:3], sonic_alert, light_led1, p2_led0};
    soc11_integration_wrapper u_soc11 (
        .clk(clk),.btnC(btnC),
        .btnU(btnU),.btnD(btnD),.btnL(btnL),.btnR(btnR),
        .sw_tri_i(sw),.led_tri_o(gpio_led),
        .UART_0_rxd(RsRx),.UART_0_txd(RsTx),
        .p2_led_o(p2_led0),.pwm_led1(pwm_led1),
        .fnd_seg(seg),.fnd_an(an),.fnd_dp(dp),
        .cds_digital(cds_digital),
        .cds_dark(cds_dark),.cds_valid(cds_valid),
        .cds_auto_enable(auto_enable),
        .sonic_trig(sonic_trig),.sonic_echo(sonic_echo),
        .sonic_alert(sonic_alert),.sonic_unsafe(sonic_unsafe),
        .motor_in1(motor_in1),.motor_in2(motor_in2),
        .motor_ena(motor_ena)
    );
endmodule
