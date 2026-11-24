`timescale 1ns/1ps
// P2-11: P2-04 pwm_core.v를 수정 없이 재사용하는 PWM 경계 동작 테스트.
// 20ms 실제 주기를 200 tick으로 축척한 교육용 시뮬레이션.
// 실물 설정(100MHz)은 C 함수 단위 테스트에서 별도로 검증.
module tb_servo_pwm_reuse;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg resetn=0, apply=0, enable=0;
    reg [31:0] period=200, duty=10;
    wire pwm;
    wire pending;
    wire [31:0] active_period, active_duty;
    wire active_enable, active_polarity;
    integer highs, i;
    pwm_core #(.RESET_PERIOD(32'd200)) dut (
        .clk(clk), .resetn(resetn), .cfg_apply(apply),
        .cfg_period(period), .cfg_duty(duty),
        .cfg_enable(enable), .cfg_polarity(1'b0),
        .pwm_out(pwm), .pending(pending),
        .active_period(active_period), .active_duty(active_duty),
        .active_enable(active_enable), .active_polarity(active_polarity)
    );
    task request_pwm;
        input [31:0] new_duty;
        begin
            @(negedge clk);
            duty=new_duty; enable=1; apply=1;
            @(negedge clk); apply=0;
            // 설정은 주기 경계에서만 활성화된다.
            wait(active_enable && active_duty == new_duty);
        end
    endtask
    task check_frame;
        input integer expected_high;
        begin
            highs=0;
            // 주기 시작을 동기화하기 위해 high-to-low 후 다음 high 시작 검출.
            wait(pwm == 1'b0);
            @(posedge pwm);
            for (i=0;i<200;i=i+1) begin
                @(negedge clk);
                if (pwm) highs=highs+1;
            end
            if (highs != expected_high) begin
                $display("FAIL expected=%0d actual=%0d",expected_high,highs);
                $fatal(1);
            end
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);
        resetn=1;
        request_pwm(10);
        check_frame(10);
        request_pwm(15);
        check_frame(15);
        request_pwm(20);
        check_frame(20);
        $display("P2_11_RTL_PWM_REUSE PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT"); end
endmodule
