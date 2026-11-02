`timescale 1ns / 1ps

// Removes the MPU6050 gyro Z zero-rate offset and applies a simple LPF.
module gyro_bias_calibrator #(
    parameter integer CALIB_SAMPLES = 128,
    parameter integer SUM_SHIFT     = 7,
    parameter integer FILTER_SHIFT  = 3
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    input  wire signed [15:0] sample_in,
    input  wire               calibrate,
    output reg  signed [15:0] sample_out,
    output reg                calibrated
);

    localparam integer COUNT_W =
        (CALIB_SAMPLES <= 1) ? 1 : $clog2(CALIB_SAMPLES);
    localparam integer SUM_W = 16 + COUNT_W + 1;

    reg [COUNT_W-1:0] calib_count;
    reg signed [SUM_W-1:0] calib_sum;
    reg signed [15:0] bias;
    reg signed [16:0] filter_acc;
    wire signed [16:0] corrected = sample_in - bias;
    wire signed [16:0] filtered_next =
        filter_acc + ((corrected - filter_acc) >>> FILTER_SHIFT);

    always @(posedge clk) begin
        if (rst) begin
            calib_count <= {COUNT_W{1'b0}};
            calib_sum   <= {SUM_W{1'b0}};
            bias        <= 16'sd0;
            sample_out  <= 16'sd0;
            filter_acc  <= 17'sd0;
            calibrated  <= 1'b0;
        end else if (calibrate) begin
            calib_count <= {COUNT_W{1'b0}};
            calib_sum   <= {SUM_W{1'b0}};
            bias        <= 16'sd0;
            sample_out  <= 16'sd0;
            filter_acc  <= 17'sd0;
            calibrated  <= 1'b0;
        end else if (sample_valid) begin
            if (!calibrated) begin
                calib_sum <= calib_sum + sample_in;
                if (calib_count == CALIB_SAMPLES - 1) begin
                    bias       <= (calib_sum + sample_in) >>> SUM_SHIFT;
                    calib_count <= {COUNT_W{1'b0}};
                    calib_sum  <= {SUM_W{1'b0}};
                    calibrated <= 1'b1;
                    sample_out <= 16'sd0;
                    filter_acc <= 17'sd0;
                end else begin
                    calib_count <= calib_count + 1'b1;
                end
            end else begin
                filter_acc <= filtered_next;
                sample_out <= filtered_next[15:0];
            end
        end
    end

endmodule
