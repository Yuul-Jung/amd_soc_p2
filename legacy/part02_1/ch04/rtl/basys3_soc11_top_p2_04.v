// P2-04 Top은 보드 연결만 담당. PWM 계산 및 always 기능 로직 금지.
// (유지) LED0은 01장 IP, LED14/15는 기존 GPIO UART/Timer.
// (추가) LED1(E19)은 PWM 전용으로 분리하며 GPIO bit1은 외부핀에서 제외.
// (유지) FND는 02장, 방향버튼은 03장, BTNC는 Reset.
module basys3_soc11_top (
    input wire clk, input wire btnC,
    input wire btnU, input wire btnD, input wire btnL, input wire btnR,
    input wire [15:0] sw, output wire [15:0] led,
    input wire RsRx, output wire RsTx,
    output wire [6:0] seg, output wire [3:0] an, output wire dp
);
    wire [15:0] gpio_led;
    wire p2_led0;
    wire pwm_led1;

    // 단순 연결: [15:2] GPIO, bit1 PWM, bit0 LED IP.
    assign led = {gpio_led[15:2], pwm_led1, p2_led0};

    // BD에 pwm_led1 외부 포트를 만든 후에 Wrapper를 재생성해야 한다.
    soc11_integration_wrapper u_soc11 (
        .clk(clk), .btnC(btnC),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .sw_tri_i(sw), .led_tri_o(gpio_led),
        .UART_0_rxd(RsRx), .UART_0_txd(RsTx),
        .p2_led_o(p2_led0), .pwm_led1(pwm_led1),
        .fnd_seg(seg), .fnd_an(an), .fnd_dp(dp)
    );
endmodule
