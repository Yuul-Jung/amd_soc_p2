`timescale 1ns/1ps
// P2-05 board-independent LED PWM gate. Input/output polarities are active-high.
// MANUAL (AUTO=0): retain P2-04 PWM output unmodified.
// AUTO=1: allow configured PWM only after stable dark is confirmed.
// If PWM=0%, AUTO ON does NOT force light on: user sets PWM brightness first.
module auto_light_controller (
    input  wire pwm_led_i,
    input  wire auto_enable_i,
    input  wire sensor_dark_i,
    input  wire sensor_valid_i,
    output wire led1_o
);
    assign led1_o = pwm_led_i &
                    (~auto_enable_i | (sensor_valid_i & sensor_dark_i));
endmodule
