`timescale 1ns / 1ps

// Fixed 50 Hz PWM with a runtime-selectable high-pulse width in microseconds.
module servo_pwm_pulse #(
    parameter integer CLK_HZ  = 100_000_000,
    parameter integer PWM_HZ  = 50
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] pulse_us,
    output wire        servo_pwm
);

    localparam integer PERIOD_CYCLES =
        (CLK_HZ / PWM_HZ < 2) ? 2 : CLK_HZ / PWM_HZ;
    localparam integer CLK_WHOLE_MHZ = CLK_HZ / 1_000_000;
    localparam integer CLK_REM_HZ    = CLK_HZ % 1_000_000;

    reg [31:0] period_count;
    wire [31:0] pulse_cycles =
        pulse_us * CLK_WHOLE_MHZ +
        (pulse_us * CLK_REM_HZ) / 1_000_000;

    always @(posedge clk) begin
        if (rst) begin
            period_count <= 32'd0;
        end else if (period_count >= PERIOD_CYCLES - 1) begin
            period_count <= 32'd0;
        end else begin
            period_count <= period_count + 1'b1;
        end
    end

    assign servo_pwm = (period_count < pulse_cycles);

endmodule
