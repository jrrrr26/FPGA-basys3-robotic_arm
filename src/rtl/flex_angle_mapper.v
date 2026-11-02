`timescale 1ns / 1ps

// Absolute-threshold flex jog controller for a 180-degree positional servo.
// High ADC drives toward MAX_ANGLE; low ADC drives toward MIN_ANGLE.
// The middle band stops PWM and keeps the last commanded angle.
// Reaching either limit also stops PWM to avoid continuous motor stall.
module flex_angle_mapper #(
    parameter integer LEVEL_W         = 13,
    parameter integer MIN_ANGLE       = 20,
    parameter integer MAX_ANGLE       = 160,
    parameter integer START_ANGLE     = 90,
    parameter integer STEP_ANGLE      = 2,
    parameter integer HIGH_ENTER      = 3_000,
    parameter integer HIGH_RELEASE    = 2_500,
    parameter integer LOW_ENTER       = 800,
    parameter integer LOW_RELEASE     = 1_200
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               tick,
    input  wire               sample_valid,
    input  wire [LEVEL_W-1:0] level,
    input  wire               calibrate,
    output reg                ready,
    output reg                calibrating,
    output reg                active,
    output reg  [LEVEL_W-1:0] baseline,
    output reg  [8:0]         angle
);

    localparam [1:0] S_DEAD = 2'd0;
    localparam [1:0] S_HIGH = 2'd1;
    localparam [1:0] S_LOW  = 2'd2;

    reg [1:0] direction_state;
    wire drive_up =
        (direction_state == S_HIGH) && (angle < MAX_ANGLE);
    wire drive_down =
        (direction_state == S_LOW) && (angle > MIN_ANGLE);

    always @(posedge clk) begin
        if (rst) begin
            ready           <= 1'b0;
            calibrating     <= 1'b0;
            active          <= 1'b0;
            baseline        <= LOW_ENTER;
            angle           <= START_ANGLE;
            direction_state <= S_DEAD;
        end else begin
            // `calibrate` is accepted for interface compatibility. Absolute
            // thresholds do not require a straight-finger baseline.
            calibrating <= 1'b0;
            baseline    <= LOW_ENTER;

            if (sample_valid) begin
                ready <= 1'b1;
                case (direction_state)
                    S_HIGH: begin
                        if (level <= LOW_ENTER)
                            direction_state <= S_LOW;
                        else if (level < HIGH_RELEASE)
                            direction_state <= S_DEAD;
                    end
                    S_LOW: begin
                        if (level >= HIGH_ENTER)
                            direction_state <= S_HIGH;
                        else if (level > LOW_RELEASE)
                            direction_state <= S_DEAD;
                    end
                    default: begin
                        if (level >= HIGH_ENTER)
                            direction_state <= S_HIGH;
                        else if (level <= LOW_ENTER)
                            direction_state <= S_LOW;
                    end
                endcase
            end

            active <= drive_up || drive_down;

            if (tick) begin
                if (drive_up) begin
                    if (angle > MAX_ANGLE - STEP_ANGLE)
                        angle <= MAX_ANGLE;
                    else
                        angle <= angle + STEP_ANGLE;
                end else if (drive_down) begin
                    if (angle < MIN_ANGLE + STEP_ANGLE)
                        angle <= MIN_ANGLE;
                    else
                        angle <= angle - STEP_ANGLE;
                end
            end
        end
    end

endmodule
