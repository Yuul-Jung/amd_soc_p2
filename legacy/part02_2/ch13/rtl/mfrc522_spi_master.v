`timescale 1ns/1ps
// P2-13 · MFRC522 16-bit SPI register transaction.
// CPOL=0, CPHA=0, MSB first; CS asserted throughout 2 bytes.
// CMD handshakes on valid && ready; done pulses after 16 rising edges.
// Input clk only, no generated FPGA clock domain. SCK is output GPIO.
// SPI bit rate = clk / (2 * CLK_DIV). e.g. 100MHz/20 = 5MHz.
// No RST output, antenna setup or RFID card/UID procedure here.
module mfrc522_spi_master #(
    parameter integer CLK_DIV = 10
)(
    input wire clk, input wire resetn,
    input wire cmd_valid, output wire cmd_ready,
    input wire cmd_read,
    input wire [5:0] cmd_addr,
    input wire [7:0] cmd_wdata,
    output reg [7:0] rsp_rdata,
    output reg rsp_valid,
    output reg spi_sck,
    output reg spi_mosi,
    input wire spi_miso,
    output reg spi_nss
);
    localparam [1:0] IDLE=0, LOW=1, HIGH=2, FINISH=3;
    reg [1:0] state;
    reg [15:0] tx_word;
    reg [7:0] rx_shift;
    reg [4:0] bit_pos;
    reg [31:0] div_count;
    assign cmd_ready = (state == IDLE);

    always @(posedge clk) begin
        if (!resetn) begin
            state <= IDLE; tx_word <= 16'd0; rx_shift <= 8'd0;
            bit_pos <= 5'd0; div_count <= 32'd0;
            spi_sck <= 1'b0; spi_mosi <= 1'b0; spi_nss <= 1'b1;
            rsp_rdata <= 8'd0; rsp_valid <= 1'b0;
        end else begin
            rsp_valid <= 1'b0;
            case (state)
            IDLE: begin
                spi_sck <= 1'b0; spi_nss <= 1'b1;
                if (cmd_valid) begin
                    // First byte [R/W, six-bit register address, 0].
                    // For reads: MOSI second byte is dummy 8'h00.
                    tx_word <= {{cmd_read,cmd_addr,1'b0},
                                (cmd_read ? 8'h00 : cmd_wdata)};
                    spi_mosi <= cmd_read; // first outgoing bit
                    spi_nss <= 1'b0;
                    bit_pos <= 5'd15; div_count <= 32'd0;
                    rx_shift <= 8'd0;
                    state <= LOW;
                end
            end
            LOW: begin
                // SCK low for CLK_DIV FPGA cycles; MOSI stable before rising edge.
                if(div_count == CLK_DIV-1) begin
                    div_count <= 32'd0;
                    spi_sck <= 1'b1;
                    if(bit_pos < 5'd8)
                        rx_shift <= {rx_shift[6:0], spi_miso};
                    state <= HIGH;
                end else div_count <= div_count + 32'd1;
            end
            HIGH: begin
                if(div_count == CLK_DIV-1) begin
                    div_count <= 32'd0;
                    spi_sck <= 1'b0;
                    if(bit_pos == 5'd0) begin
                        state <= FINISH;
                    end else begin
                        bit_pos <= bit_pos - 5'd1;
                        // Advance output bit at falling edge, sample next rising edge.
                        spi_mosi <= tx_word[bit_pos-5'd1];
                        state <= LOW;
                    end
                end else div_count <= div_count + 32'd1;
            end
            FINISH: begin
                spi_nss <= 1'b1; spi_sck <= 1'b0;
                rsp_rdata <= rx_shift;
                rsp_valid <= 1'b1;
                state <= IDLE;
            end
            default: state <= IDLE;
            endcase
        end
    end
endmodule
