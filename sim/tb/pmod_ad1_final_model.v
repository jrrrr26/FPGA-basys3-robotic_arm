`timescale 1ns / 1ps

// Pmod AD1 model with MyoWare ENV on D0 and a flex-sensor sweep on D1.
module pmod_ad1_final_model #(
    parameter integer REST_SAMPLES = 2_400,
    parameter integer TENSE_SAMPLES = 1_000,
    parameter integer FLEX_SAMPLES = 2_600,
    parameter integer REST_LEVEL = 200,
    parameter integer TENSE_LEVEL = 800,
    parameter integer FLEX_REST = 200,
    parameter integer FLEX_BENT = 4_000
) (
    input  wire cs_n,
    input  wire sclk,
    output reg  d0,
    output reg  d1
);

    reg [15:0] shift0;
    reg [15:0] shift1;
    integer sample_count;
    integer value0;
    integer value1;

    initial begin
        shift0       = 16'd0;
        shift1       = 16'd0;
        sample_count = 0;
        d0           = 1'b0;
        d1           = 1'b0;
    end

    task automatic load_sample;
        begin
            sample_count = sample_count + 1;
            if (sample_count <= REST_SAMPLES)
                value0 = REST_LEVEL;
            else if (sample_count <= REST_SAMPLES + TENSE_SAMPLES)
                value0 = TENSE_LEVEL;
            else
                value0 = REST_LEVEL;

            if (sample_count <= FLEX_SAMPLES)
                value1 = FLEX_REST;
            else
                value1 = FLEX_BENT;

            shift0 = {4'b0000, value0[11:0]};
            shift1 = {4'b0000, value1[11:0]};
        end
    endtask

    always @(negedge cs_n) begin
        load_sample;
    end

    always @(negedge sclk) begin
        if (!cs_n) begin
            d0     <= shift0[15];
            d1     <= shift1[15];
            shift0 <= {shift0[14:0], 1'b0};
            shift1 <= {shift1[14:0], 1'b0};
        end
    end

endmodule
