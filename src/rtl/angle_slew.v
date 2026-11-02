`timescale 1ns / 1ps

// Moves a positional-servo target toward a requested angle at a bounded rate.
// Once enabled, it keeps driving the last requested angle until reset.
module angle_slew #(
    parameter integer STEP_ANGLE  = 2,
    parameter integer START_ANGLE = 90
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,
    input  wire       enable,
    input  wire [8:0] target,
    output reg        active,
    output reg  [8:0] angle
);

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            angle  <= START_ANGLE;
        end else begin
            if (enable)
                active <= 1'b1;

            if (tick && active) begin
                if (target > angle) begin
                    if (target - angle > STEP_ANGLE)
                        angle <= angle + STEP_ANGLE;
                    else
                        angle <= target;
                end else if (target < angle) begin
                    if (angle - target > STEP_ANGLE)
                        angle <= angle - STEP_ANGLE;
                    else
                        angle <= target;
                end
            end
        end
    end

endmodule
