`timescale 1ns / 1ps

// Active-high pushbutton debounce with a one-clock-cycle press pulse.
module button_debounce #(
    parameter integer CLK_HZ      = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
) (
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  press_pulse
);

    localparam integer DEBOUNCE_CYCLES_RAW =
        (CLK_HZ / 1_000) * DEBOUNCE_MS;
    localparam integer DEBOUNCE_CYCLES =
        (DEBOUNCE_CYCLES_RAW < 1) ? 1 : DEBOUNCE_CYCLES_RAW;
    localparam integer CNT_W =
        (DEBOUNCE_CYCLES <= 2) ? 1 : $clog2(DEBOUNCE_CYCLES);

    reg [1:0] button_sync;
    reg       stable_level;
    reg       stable_level_d;
    reg [CNT_W-1:0] debounce_count;

    always @(posedge clk) begin
        if (rst) begin
            button_sync     <= 2'b00;
            stable_level    <= 1'b0;
            stable_level_d  <= 1'b0;
            debounce_count  <= {CNT_W{1'b0}};
            press_pulse     <= 1'b0;
        end else begin
            button_sync <= {button_sync[0], button_in};
            press_pulse <= stable_level && !stable_level_d;
            stable_level_d <= stable_level;

            if (button_sync[1] != stable_level) begin
                if (debounce_count >= DEBOUNCE_CYCLES - 1) begin
                    debounce_count <= {CNT_W{1'b0}};
                    stable_level   <= button_sync[1];
                end else begin
                    debounce_count <= debounce_count + 1'b1;
                end
            end else begin
                debounce_count <= {CNT_W{1'b0}};
            end
        end
    end

endmodule
