`timescale 1ns/1ps
module tb_fnd_scan_controller;
    reg clk=0;
    always #5 clk=~clk;
    reg resetn=0;
    reg [15:0] display_bcd=16'h0000;
    reg display_enable=0;
    wire [6:0] seg;
    wire [3:0] an;
    wire dp;
    integer i, hits[0:3];
    reg [6:0] expected_seg;

    fnd_scan_controller #(.TICKS_PER_DIGIT(3)) dut (
        .clk(clk), .resetn(resetn), .display_bcd(display_bcd),
        .display_enable(display_enable), .seg(seg), .an(an), .dp(dp)
    );

    task require;
        input condition;
        input [240*8-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s time=%0t an=%b seg=%b",message,$time,an,seg);
                $fatal(1);
            end
        end
    endtask
    task check_frame;
        input [15:0] bcd;
        integer k;
        reg [3:0] digit;
        reg [6:0] pattern;
        begin
            for (k=0;k<4;k=k+1) hits[k]=0;
            for (k=0;k<48;k=k+1) begin
                @(posedge clk); #1;
                require(dp===1'b1,"decimal point must stay off");
                case (an)
                    4'b1110: begin digit=bcd[3:0]; hits[0]=hits[0]+1; end
                    4'b1101: begin digit=bcd[7:4]; hits[1]=hits[1]+1; end
                    4'b1011: begin digit=bcd[11:8]; hits[2]=hits[2]+1; end
                    4'b0111: begin digit=bcd[15:12]; hits[3]=hits[3]+1; end
                    default: begin
                        $display("FAIL: unexpected an %b",an); $fatal(1);
                    end
                endcase
                case (digit)
                    0: pattern=7'b1000000;
                    1: pattern=7'b1111001;
                    2: pattern=7'b0100100;
                    3: pattern=7'b0110000;
                    4: pattern=7'b0011001;
                    5: pattern=7'b0010010;
                    6: pattern=7'b0000010;
                    7: pattern=7'b1111000;
                    8: pattern=7'b0000000;
                    9: pattern=7'b0010000;
                    default: pattern=7'b1111111;
                endcase
                if (seg !== pattern) begin
                    $display("FAIL: BCD mismatch an=%b seg=%b expected=%b",an,seg,pattern);
                    $fatal(1);
                end
            end
            for (k=0;k<4;k=k+1) require(hits[k]>0,"all four digits must scan");
        end
    endtask
    initial begin
        #1; require(an===4'b1111,"off during reset");
        @(negedge clk); resetn=1;
        @(negedge clk); display_bcd=16'h1234; display_enable=1;
        repeat(16) @(posedge clk);
        check_frame(16'h1234);
        @(negedge clk); display_bcd=16'h0050;
        repeat(16) @(posedge clk);
        check_frame(16'h0050); // leading zeros must NOT be blanked
        @(negedge clk); display_enable=0;
        repeat(16) @(posedge clk);
        for(i=0;i<12;i=i+1) begin
            @(posedge clk); #1;
            require(an===4'b1111 && seg===7'b1111111,"DISP OFF");
        end
        @(negedge clk); resetn=0;
        #1; // synchronous reset: wait a clock edge
        @(posedge clk); #1;
        require(an===4'b1111,"reset turns display off");
        $display("FND_SCAN_TB PASS");
        $finish;
    end
endmodule
