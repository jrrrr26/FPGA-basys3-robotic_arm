`timescale 1ns / 1ps

// Generates one-cycle sample_tick pulses at SAMPLE_HZ.
module sample_tick_gen #(
    parameter integer CLK_HZ    = 100_000_000,
    parameter integer SAMPLE_HZ = 1_000
) (
    input  wire clk,
    input  wire rst,
    output reg  sample_tick
);

    localparam integer DIV    = CLK_HZ / SAMPLE_HZ;
    localparam integer DIV_SAFE = (DIV < 1) ? 1 : DIV;
    localparam integer CNT_W  = (DIV_SAFE <= 2) ? 1 : $clog2(DIV_SAFE);

    reg [CNT_W-1:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count       <= {CNT_W{1'b0}};
            sample_tick <= 1'b0;
        end else if (count == DIV_SAFE - 1) begin
            count       <= {CNT_W{1'b0}};
            sample_tick <= 1'b1;
        end else begin
            count       <= count + 1'b1;
            sample_tick <= 1'b0;
        end
    end

endmodule
