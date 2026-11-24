`timescale 1ns/1ps
module tb_pir_irq_controller;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0, pir=0, arm=1, enable=1, ack=0, clear=0;
    wire irq,ready,level,pulse,pending;
    wire [31:0] count;
    integer pulses=0;
    pir_irq_controller #(
        .WARMUP_CYCLES(64'd20), .FILTER_CYCLES(3)
    ) dut (
        .clk(clk),.resetn(resetn),.pir_in_async(pir),
        .arm(arm),.irq_enable(enable),
        .irq_ack_pulse(ack),.count_clear_pulse(clear),
        .irq(irq),.warmup_ready(ready),.pir_level(level),
        .motion_pulse(pulse),.event_pending(pending),.event_count(count)
    );
    always @(posedge clk) if (pulse) pulses=pulses+1;
    task advance;
        input integer cycles;
        integer k;
        begin for(k=0;k<cycles;k=k+1) @(negedge clk); end
    endtask
    task set_pir;
        input value;
        begin @(negedge clk);pir=value; end
    endtask
    task do_ack;
        begin @(negedge clk);ack=1;@(negedge clk);ack=0;end
    endtask
    initial begin
        advance(4);resetn=1;
        set_pir(1);advance(9);
        if(ready || count!=0 || pending || irq)
            $fatal(1,"warmup early event");
        advance(20);
        if(!ready || !level || pending || count!=0)
            $fatal(1,"warmup high should be baseline, not event");
        $display("P2_18_PIR_WARMUP_MASK_PASS");

        set_pir(0);advance(9);
        if(level!==0) $fatal(1,"falling edge not synchronized");
        // 1-cycle glitch is shorter than FILTER_CYCLES, ignore.
        set_pir(1);advance(1);set_pir(0);advance(9);
        if(level || count || pending) $fatal(1,"glitch counted");
        $display("P2_18_PIR_GLITCH_FILTER_PASS");

        set_pir(1);advance(11);
        if(!level || !pending || !irq || count!=1 || pulses!=1)
            $fatal(1,"rising event count=%0d pulses=%0d",count,pulses);
        advance(30);
        if(count!=1 || pulses!=1) $fatal(1,"stuck HIGH duplicate event");
        $display("P2_18_PIR_RISE_ONLY_STICKY_IRQ_PASS");

        // Mask IRQ without clearing pending; re-enable reveals pending.
        @(negedge clk);enable=0;
        #1;
        if(irq || !pending) $fatal(1,"enable mask failure");
        @(negedge clk);enable=1;
        #1;
        if(!irq) $fatal(1,"unmask pending failure");
        do_ack();advance(2);
        if(irq || pending || count!=1)
            $fatal(1,"ack failed or counter lost");
        $display("P2_18_PIR_IRQ_ENABLE_ACK_PASS");

        // Returning LOW and then HIGH creates another event.
        set_pir(0);advance(9);
        set_pir(1);advance(10);
        if(count!=2 || !irq || pulses!=2)
            $fatal(1,"second motion not counted");
        do_ack();
        $display("P2_18_PIR_RETRIGGER_PASS");

        // Disable ARM, next high does not create event;
        // enabling ARM while sensor stays high also does not.
        set_pir(0);advance(10);
        @(negedge clk);arm=0;
        set_pir(1);advance(10);
        if(count!=2 || pending || irq)
            $fatal(1,"arm gate failed");
        @(negedge clk);arm=1;advance(7);
        if(count!=2 || pending) $fatal(1,"arm caused fake rise");
        $display("P2_18_PIR_ARM_GATE_PASS");

        set_pir(0);advance(10);
        // ACK coincides with new event: event MUST win.
        set_pir(1);
        wait(dut.qualified_rise);
        @(negedge clk);ack=1;
        @(negedge clk);ack=0;
        advance(4);
        if(count!=3 || !pending || !irq || pulses!=3)
            $fatal(1,"simultaneous ACK erased event");
        $display("P2_18_PIR_ACK_EVENT_PRIORITY_PASS");

        // Clear counter, but not the independent pending bit.
        @(negedge clk);clear=1;
        @(negedge clk);clear=0;
        advance(2);
        if(count!=0 || !pending) $fatal(1,"counter clear affected pending");
        do_ack();
        if(pending || irq || count!=0)
            $fatal(1,"final ACK failed");
        $display("P2_18_PIR_COUNT_CLEAR_PASS");
        $display("P2_18_PIR_IRQ_CONTROLLER_RTL PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT");end
endmodule
