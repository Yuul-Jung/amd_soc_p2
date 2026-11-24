`timescale 1ns/1ps
// P2-18: 32-bit AXI4-Lite register block around pir_irq_controller.
// Register offsets:
// 0x00 CTRL R/W: bit0 ARM, bit1 IRQ_ENABLE
// 0x04 CMD  W: bit0 ACK pending, bit1 CLEAR event_count (W1P)
// 0x08 STATUS R: bit0 warmup_ready, bit1 pir_level,
//                bit2 event_pending, bit3 irq
// 0x0C EVENT_COUNT R
// 0x10 ID R=0x00180001
// AXI WSTRB honored. Illegal/misaligned/unmapped access -> SLVERR.
// GPIO input asynchronous. CPU IRQ is LEVEL (not a one-clock pulse).
module p2_18_axi_pir_irq_v1_0 #(
    parameter [63:0] WARMUP_CYCLES=64'd6000000000,
    parameter integer FILTER_CYCLES=3
)(
    input wire S_AXI_ACLK,input wire S_AXI_ARESETN,
    input wire [5:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID,output wire S_AXI_AWREADY,
    input wire [31:0] S_AXI_WDATA,
    input wire [3:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,output wire S_AXI_WREADY,
    output reg [1:0] S_AXI_BRESP,
    output reg S_AXI_BVALID,input wire S_AXI_BREADY,
    input wire [5:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID,output wire S_AXI_ARREADY,
    output reg [31:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP,
    output reg S_AXI_RVALID,input wire S_AXI_RREADY,
    input wire pir_in_async,output wire irq
);
    localparam [1:0] OKAY=2'b00, SLVERR=2'b10;
    reg arm,irq_enable,ack_strobe,clear_strobe;
    wire ready,level,pulse,pending;
    wire [31:0] count;
    reg aw_hold,w_hold;
    reg [5:0] saved_addr;
    reg [31:0] saved_data;
    reg [3:0] saved_strb;
    pir_irq_controller #(
        .WARMUP_CYCLES(WARMUP_CYCLES),.FILTER_CYCLES(FILTER_CYCLES)
    ) u_core(
        .clk(S_AXI_ACLK),.resetn(S_AXI_ARESETN),
        .pir_in_async(pir_in_async),.arm(arm),
        .irq_enable(irq_enable),
        .irq_ack_pulse(ack_strobe),.count_clear_pulse(clear_strobe),
        .irq(irq),.warmup_ready(ready),
        .pir_level(level),.motion_pulse(pulse),
        .event_pending(pending),.event_count(count)
    );
    assign S_AXI_AWREADY=S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY =S_AXI_ARESETN && !w_hold && !S_AXI_BVALID;
    assign S_AXI_ARREADY=S_AXI_ARESETN && !S_AXI_RVALID;
    always @(posedge S_AXI_ACLK)begin
        if(!S_AXI_ARESETN)begin
            arm<=0;irq_enable<=0;ack_strobe<=0;clear_strobe<=0;
            aw_hold<=0;w_hold<=0;saved_addr<=0;saved_data<=0;
            saved_strb<=0;S_AXI_BRESP<=OKAY;S_AXI_BVALID<=0;
            S_AXI_RRESP<=OKAY;S_AXI_RVALID<=0;S_AXI_RDATA<=0;
        end else begin
            ack_strobe<=0;clear_strobe<=0;
            if(S_AXI_AWVALID && S_AXI_AWREADY)begin
                saved_addr<=S_AXI_AWADDR;aw_hold<=1;
            end
            if(S_AXI_WVALID && S_AXI_WREADY)begin
                saved_data<=S_AXI_WDATA;saved_strb<=S_AXI_WSTRB;
                w_hold<=1;
            end
            if(S_AXI_BVALID && S_AXI_BREADY)S_AXI_BVALID<=0;
            if(aw_hold && w_hold && !S_AXI_BVALID)begin
                aw_hold<=0;w_hold<=0;S_AXI_BVALID<=1;
                S_AXI_BRESP<=OKAY;
                case(saved_addr)
                6'h00:if(saved_strb[0])begin
                    arm<=saved_data[0];irq_enable<=saved_data[1];
                end
                6'h04:if(saved_strb[0])begin
                    ack_strobe<=saved_data[0];
                    clear_strobe<=saved_data[1];
                end
                default:S_AXI_BRESP<=SLVERR;
                endcase
            end
            if(S_AXI_RVALID && S_AXI_RREADY)S_AXI_RVALID<=0;
            if(S_AXI_ARVALID && S_AXI_ARREADY)begin
                S_AXI_RVALID<=1;S_AXI_RRESP<=OKAY;
                case(S_AXI_ARADDR)
                6'h00:S_AXI_RDATA<={30'b0,irq_enable,arm};
                6'h08:S_AXI_RDATA<={28'b0,irq,pending,level,ready};
                6'h0c:S_AXI_RDATA<=count;
                6'h10:S_AXI_RDATA<=32'h00180001;
                default:begin S_AXI_RRESP<=SLVERR;S_AXI_RDATA<=0;end
                endcase
            end
        end
    end
endmodule
