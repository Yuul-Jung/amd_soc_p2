`timescale 1ns/1ps
// P2-13 · VersionReg(0x37) read once per request, independent controller.
// No card detection or UID authentication performed by this module.
module mfrc522_version_probe (
    input wire clk, input wire resetn,
    input wire start_pulse,
    output reg [7:0] version,
    output reg done_pulse, output reg busy,
    output wire cmd_valid, input wire cmd_ready,
    output wire cmd_read, output wire [5:0] cmd_addr,
    output wire [7:0] cmd_wdata,
    input wire [7:0] rsp_rdata, input wire rsp_valid
);
    localparam [1:0] WAIT=0, SEND=1, RESPONSE=2;
    reg [1:0] state;
    assign cmd_valid=(state == SEND);
    assign cmd_read=1'b1;
    assign cmd_addr=6'h37;
    assign cmd_wdata=8'h00;
    always @(posedge clk) begin
        if(!resetn) begin
            state<=WAIT; version<=8'd0; done_pulse<=0; busy<=0;
        end else begin
            done_pulse<=0;
            case(state)
            WAIT: if(start_pulse) begin busy<=1; state<=SEND; end
            SEND: if(cmd_ready) state<=RESPONSE;
            RESPONSE: if(rsp_valid) begin
                version<=rsp_rdata; done_pulse<=1; busy<=0; state<=WAIT;
            end
            default: begin state<=WAIT;busy<=0;end
            endcase
        end
    end
endmodule
