// 제2부 01장(P2-01) 사용자 Top — 보드 연결 전용
// (변경) LED0을 신규 AXI IP 단독 출력에 연결한다.
// (유지) LED1~15, SW, UART, Clock, Reset은 기존 Wrapper에 연결한다.
module basys3_soc11_top (
    input  wire        clk,     // Basys3 100 MHz: W5
    input  wire        btnC,    // 기존 시스템 Reset: U18
    input  wire [15:0] sw,      // 기존 스위치 입력
    output wire [15:0] led,     // 내장 LED[15:0]
    input  wire        RsRx,    // PC -> FPGA UART
    output wire        RsTx     // FPGA -> PC UART
);
    wire [15:0] gpio_led;       // 기존 AXI GPIO 출력, bit0은 미사용
    wire        ip_led0;        // 새 사용자 AXI IP 출력

    // (변경) 결합된 신호를 보드 출력에 연결한다.
    // LED[15:1]은 gpio_led[15:1], LED[0]은 ip_led0으로 연결.
    // 연산이나 상태 결정이 아닌 단순 배선이다.
    assign led = {gpio_led[15:1], ip_led0};

    soc11_integration_wrapper u_soc11 (
        .clk(clk),
        .btnC(btnC),
        .sw_tri_i(sw),
        .led_tri_o(gpio_led),
        .UART_0_rxd(RsRx),
        .UART_0_txd(RsTx),
        .p2_led_o(ip_led0)       // BD에서 외부화한 포트; 생성 Wrapper와 대조
    );
endmodule
