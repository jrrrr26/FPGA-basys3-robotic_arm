`timescale 1ns / 1ps

// 8N1 UART transmitter.
module uart_tx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data_in,
    output reg        txd,
    output reg        ready,
    output reg        done
);

    localparam integer BAUD_DIV_RAW = (CLK_HZ + BAUD / 2) / BAUD;
    localparam integer BAUD_DIV = (BAUD_DIV_RAW < 2) ? 2 : BAUD_DIV_RAW;

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] baud_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_IDLE;
            baud_count <= 16'd0;
            bit_index  <= 3'd0;
            data_reg   <= 8'd0;
            txd        <= 1'b1;
            ready      <= 1'b1;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    txd   <= 1'b1;
                    ready <= 1'b1;
                    if (start) begin
                        data_reg   <= data_in;
                        txd        <= 1'b0;
                        baud_count <= 16'd0;
                        bit_index  <= 3'd0;
                        ready      <= 1'b0;
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    if (baud_count >= BAUD_DIV - 1) begin
                        baud_count <= 16'd0;
                        txd        <= data_reg[0];
                        bit_index  <= 3'd0;
                        state      <= ST_DATA;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                ST_DATA: begin
                    if (baud_count >= BAUD_DIV - 1) begin
                        baud_count <= 16'd0;
                        if (bit_index == 3'd7) begin
                            txd   <= 1'b1;
                            state <= ST_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            txd       <= data_reg[bit_index + 1'b1];
                        end
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (baud_count >= BAUD_DIV - 1) begin
                        baud_count <= 16'd0;
                        txd        <= 1'b1;
                        done       <= 1'b1;
                        ready      <= 1'b1;
                        state      <= ST_IDLE;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
