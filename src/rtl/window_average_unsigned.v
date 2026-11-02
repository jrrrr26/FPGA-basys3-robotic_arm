`timescale 1ns / 1ps

// Moving average for an already-rectified MyoWare ENV signal.
// WINDOW_LEN must be a power of two.
module window_average_unsigned #(
    parameter integer WINDOW_LEN = 64,
    parameter integer STEP_LEN   = 8,
    parameter integer IN_W       = 12,
    parameter integer OUT_W      = 13
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              sample_valid,
    input  wire [IN_W-1:0]   sample_in,
    output reg  [OUT_W-1:0]  average,
    output reg               average_valid
);

    localparam integer SUM_W =
        IN_W + ((WINDOW_LEN <= 1) ? 1 : $clog2(WINDOW_LEN)) + 1;
    localparam integer AVG_SHIFT =
        (WINDOW_LEN <= 1) ? 0 : $clog2(WINDOW_LEN);
    localparam integer STEP_W =
        (STEP_LEN <= 1) ? 1 : $clog2(STEP_LEN);
    localparam integer FILL_W =
        (WINDOW_LEN <= 1) ? 1 : $clog2(WINDOW_LEN + 1);

    reg [IN_W-1:0] window_mem [0:WINDOW_LEN-1];
    reg [SUM_W-1:0] window_sum;
    reg [FILL_W-1:0] fill_count;
    reg [STEP_W-1:0] step_count;

    integer i;
    wire [SUM_W-1:0] window_sum_next =
        window_sum + sample_in - window_mem[0];

    always @(posedge clk) begin
        if (rst) begin
            window_sum    <= {SUM_W{1'b0}};
            fill_count    <= {FILL_W{1'b0}};
            step_count    <= {STEP_W{1'b0}};
            average       <= {OUT_W{1'b0}};
            average_valid <= 1'b0;
            for (i = 0; i < WINDOW_LEN; i = i + 1) begin
                window_mem[i] <= {IN_W{1'b0}};
            end
        end else begin
            average_valid <= 1'b0;
            if (sample_valid) begin
                window_sum <= window_sum_next;
                average    <= window_sum_next >> AVG_SHIFT;

                for (i = 0; i < WINDOW_LEN - 1; i = i + 1) begin
                    window_mem[i] <= window_mem[i+1];
                end
                window_mem[WINDOW_LEN-1] <= sample_in;

                if (fill_count < WINDOW_LEN) begin
                    fill_count <= fill_count + 1'b1;
                end

                if (step_count == STEP_LEN - 1) begin
                    step_count <= {STEP_W{1'b0}};
                    if ((fill_count >= WINDOW_LEN - 1) &&
                        (WINDOW_LEN != 0)) begin
                        average_valid <= 1'b1;
                    end
                end else begin
                    step_count <= step_count + 1'b1;
                end
            end
        end
    end

endmodule
