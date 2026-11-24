`timescale 1ns/1ps
// Fake transaction responder verifies exact DS3231 repeated-start
// sequence, reads 7 BCD register bytes, and injects a bus error.
module tb_ds3231_burst_sequencer;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,start=0,ready=1;
    wire busy,done,error,valid;
    wire [2:0] op;
    wire [7:0] wdata;
    wire [55:0] raw;
    reg rsp_valid=0,rsp_error=0;
    reg [7:0] rsp_data=0;
    reg [7:0] sample [0:6];
    integer cmd_count=0,read_count=0,mode=0;
    ds3231_burst_sequencer dut(
        .clk(clk),.resetn(resetn),.start_pulse(start),
        .busy(busy),.done_pulse(done),.error_pulse(error),
        .bus_valid(valid),.bus_ready(ready),
        .bus_op(op),.bus_wdata(wdata),
        .bus_rsp_valid(rsp_valid),.bus_rsp_error(rsp_error),
        .bus_rdata(rsp_data),.raw_bcd(raw)
    );
    reg queued=0, queued_error=0;
    reg [7:0] queued_data=0;
    // (변경) 유효한 bus_valid/bus_ready 핸드셰이크는 상승 에지에서 수락.
    // 다음 반주기에서 응답을 준비하여 WAIT_RSP 상승 에지까지 유지한다.
    always @(posedge clk) begin
        if(!resetn) queued<=0;
        else begin
            queued<=0;
            if(valid && ready)begin
                if(cmd_count>12) $fatal(1,"too many commands");
                case(cmd_count)
                0:if(op!==0) $fatal(1,"expected START");
                1:if(op!==1 || wdata!==8'hd0) $fatal(1,"expected D0");
                2:if(op!==1 || wdata!==8'h00) $fatal(1,"expected pointer00");
                3:if(op!==2) $fatal(1,"expected RESTART");
                4:if(op!==1 || wdata!==8'hd1) $fatal(1,"expected D1");
                5,6,7,8,9,10:if(op!==3) $fatal(1,"expected READ_ACK");
                11:if(op!==4) $fatal(1,"expected READ_NACK");
                12:if(op!==5) $fatal(1,"expected STOP");
                endcase
                if(cmd_count>=5 && cmd_count<=11)begin
                    queued_data=sample[read_count];
                    read_count=read_count+1;
                end else queued_data=0;
                queued_error=(mode==1 && cmd_count==4);
                cmd_count=cmd_count+1;
                queued<=1;
            end
        end
    end
    always @(negedge clk) begin
        rsp_valid=queued;
        rsp_error=queued_error;
        rsp_data=queued_data;
    end
    task begin_test;
        input integer test_mode;
        begin
            @(negedge clk);mode=test_mode;
            cmd_count=0;read_count=0;start=1;
            @(negedge clk);start=0;
        end
    endtask
    initial begin
        sample[0]=8'h58;sample[1]=8'h42;sample[2]=8'h09;
        sample[3]=8'h04;sample[4]=8'h11;sample[5]=8'h11;
        sample[6]=8'h26;
        repeat(3) @(negedge clk);resetn=1;
        begin_test(0);
        wait(done);#1;
        if(raw!==56'h26111104094258 ||
           cmd_count!=13 || read_count!=7 || busy)
            $fatal(1,"DS3231 burst or packing error %h cmds=%0d reads=%0d",
                   raw,cmd_count,read_count);
        $display("P2_16_RTC_I2C_BURST_SEQUENCE_PASS");
        begin_test(1);
        wait(error);#1;
        if(cmd_count!=5 || raw!==56'h26111104094258 || busy)
            $fatal(1,"partial/error frame unexpectedly published");
        $display("P2_16_RTC_I2C_ERROR_REJECT_PASS");
        $display("P2_16_RTC_BURST_RTL PASS");
        $finish;
    end
    initial begin #100000;$fatal(1,"TIMEOUT");end
endmodule
