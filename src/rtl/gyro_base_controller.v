`timescale 1ns / 1ps

// Converts the selected wrist gyro axis into a bounded base-servo target.
// A direction must remain above the deadband before motion starts.
// Slow: 25 deg/s, medium: 50 deg/s, fast: 100 deg/s.
module gyro_base_controller #(
    parameter integer CENTER_ANGLE     = 90,
    parameter integer MIN_ANGLE        = 10,
    parameter integer MAX_ANGLE        = 170,
    parameter integer DEADBAND         = 2_600,
    parameter integer MED_THRESHOLD    = 5_000,
    parameter integer FAST_THRESHOLD   = 10_000,
    parameter integer CONFIRM_SAMPLES  = 12
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    input  wire signed [15:0] gyro_axis,
    input  wire               calibrated,
    input  wire               calibrate,
    output reg                active,
    output reg                moving,
    output reg  [8:0]         target
);

    localparam integer COUNT_W = (CONFIRM_SAMPLES <= 1) ? 1 : $clog2(CONFIRM_SAMPLES);

    reg [1:0] rate_div;
    reg [COUNT_W-1:0] confirm_count;
    reg confirm_increasing;

    wire [15:0] magnitude =
        gyro_axis[15] ? (~gyro_axis + 1'b1) : gyro_axis;
    wire increasing = !gyro_axis[15];
    wire over_deadband = magnitude > DEADBAND;
    wire same_direction = (confirm_increasing == increasing);
    wire confirmed =
        over_deadband &&
        (same_direction && confirm_count >= CONFIRM_SAMPLES - 1);

    always @(posedge clk) begin
        if (rst) begin
            active             <= 1'b0;
            moving             <= 1'b0;
            target             <= CENTER_ANGLE;
            rate_div           <= 2'd0;
            confirm_count      <= {COUNT_W{1'b0}};
            confirm_increasing <= 1'b1;
        end else if (calibrate) begin
            active             <= 1'b0;
            moving             <= 1'b0;
            target             <= CENTER_ANGLE;
            rate_div           <= 2'd0;
            confirm_count      <= {COUNT_W{1'b0}};
            confirm_increasing <= 1'b1;
        end else if (sample_valid && calibrated) begin
            if (!over_deadband) begin
                confirm_count <= {COUNT_W{1'b0}};
                rate_div      <= 2'd0;
                moving        <= 1'b0;
            end else if (confirm_count == 0 || !same_direction) begin
                confirm_increasing <= increasing;
                confirm_count      <= 1'b1;
                rate_div           <= 2'd0;
                moving             <= 1'b0;
            end else if (confirm_count < CONFIRM_SAMPLES) begin
                confirm_count <= confirm_count + 1'b1;
            end

            if (confirmed) begin
                active <= 1'b1;
                moving <= 1'b1;

                if (magnitude >= FAST_THRESHOLD) begin
                    rate_div <= 2'd0;
                    if (increasing) begin
                        if (target < MAX_ANGLE) target <= target + 1'b1;
                    end else begin
                        if (target > MIN_ANGLE) target <= target - 1'b1;
                    end
                end else if (magnitude >= MED_THRESHOLD) begin
                    if (rate_div[0]) begin
                        rate_div <= 2'd0;
                        if (increasing) begin
                            if (target < MAX_ANGLE) target <= target + 1'b1;
                        end else begin
                            if (target > MIN_ANGLE) target <= target - 1'b1;
                        end
                    end else begin
                        rate_div <= rate_div + 1'b1;
                    end
                end else begin
                    if (rate_div == 2'd3) begin
                        rate_div <= 2'd0;
                        if (increasing) begin
                            if (target < MAX_ANGLE) target <= target + 1'b1;
                        end else begin
                            if (target > MIN_ANGLE) target <= target - 1'b1;
                        end
                    end else begin
                        rate_div <= rate_div + 1'b1;
                    end
                end
            end
        end
    end

endmodule
