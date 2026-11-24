`timescale 1ns / 1ps
// P2-02: Basys3 four-digit seven-segment scanning controller.
// This module has no AXI or board pin names; it is reusable.
module fnd_scan_controller #(
    parameter integer TICKS_PER_DIGIT = 100000
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire [15:0] display_bcd,    // [15:12] leftmost .. [3:0] rightmost
    input  wire        display_enable,
    output wire [6:0]  seg,            // {g,f,e,d,c,b,a}, active low
    output wire [3:0]  an,             // an[0] rightmost, active low
    output wire        dp              // decimal point off, active low
);
    localparam integer COUNT_WIDTH = (TICKS_PER_DIGIT > 1) ?
        $clog2(TICKS_PER_DIGIT) : 1;

    reg [COUNT_WIDTH-1:0] divider_count;
    reg [1:0] scan_index;
    reg [15:0] frame_bcd;
    reg frame_enable;
    reg [3:0] current_digit;
    reg [6:0] seg_mux;
    reg [3:0] an_mux;

    assign dp = 1'b1; // decimal point is always off
    // 첫 리셋 클록 전에도 외부 핀에 X가 노출되지 않게 즉시 소등한다.
    assign seg = resetn ? seg_mux : 7'b1111111;
    assign an  = resetn ? an_mux  : 4'b1111;

    // Latch all four digits only at a scan-frame boundary.
    // One write to REG0 can never tear individual digits within a frame.
    always @(posedge clk) begin
        if (!resetn) begin
            divider_count <= {COUNT_WIDTH{1'b0}};
            scan_index    <= 2'd0;
            frame_bcd     <= 16'h0000;
            frame_enable  <= 1'b0;
        end else if (divider_count == TICKS_PER_DIGIT - 1) begin
            divider_count <= {COUNT_WIDTH{1'b0}};
            scan_index <= scan_index + 2'd1;
            if (scan_index == 2'd3) begin
                frame_bcd <= display_bcd;
                frame_enable <= display_enable;
            end
        end else begin
            divider_count <= divider_count + 1'b1;
        end
    end

    // Basys3 AN0 is the rightmost digit; AN3 is the leftmost.
    always @(*) begin
        case (scan_index)
            2'd0: current_digit = frame_bcd[3:0];
            2'd1: current_digit = frame_bcd[7:4];
            2'd2: current_digit = frame_bcd[11:8];
            default: current_digit = frame_bcd[15:12];
        endcase

        // seg[0] is segment 'a'; 0 lights a segment.
        case (current_digit)
            4'd0: seg_mux = 7'b1000000;
            4'd1: seg_mux = 7'b1111001;
            4'd2: seg_mux = 7'b0100100;
            4'd3: seg_mux = 7'b0110000;
            4'd4: seg_mux = 7'b0011001;
            4'd5: seg_mux = 7'b0010010;
            4'd6: seg_mux = 7'b0000010;
            4'd7: seg_mux = 7'b1111000;
            4'd8: seg_mux = 7'b0000000;
            4'd9: seg_mux = 7'b0010000;
            default: seg_mux = 7'b1111111; // invalid BCD nibble -> blank
        endcase

        if (!frame_enable) begin
            an_mux = 4'b1111; // OFF: disable all digits
            seg_mux = 7'b1111111;
        end else begin
            case (scan_index)
                2'd0: an_mux = 4'b1110;
                2'd1: an_mux = 4'b1101;
                2'd2: an_mux = 4'b1011;
                default: an_mux = 4'b0111;
            endcase
        end
    end
endmodule
