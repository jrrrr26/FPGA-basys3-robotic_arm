`timescale 1ns / 1ps

// Pmod AD1 / dual AD7476 reader.
// Both converters share CS_N and SCLK and return data on separate D0/D1 pins.
// Each transfer is 16 bits: four leading zeros followed by 12 data bits.
module spi_adc #(
    parameter integer CLK_HZ   = 100_000_000,
    parameter integer SPI_HZ   = 1_000_000,
    parameter integer CONV_NS  = 1_000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_req,
    input  wire        adc_d0,
    input  wire        adc_d1,
    output reg         adc_cs_n,
    output reg         adc_sclk,
    output reg  [11:0] raw_ch0,
    output reg  [11:0] raw_ch1,
    output reg         data_valid
);

    localparam integer HALF_DIV_RAW = CLK_HZ / (2 * SPI_HZ);
    localparam integer HALF_DIV     = (HALF_DIV_RAW < 1) ? 1 : HALF_DIV_RAW;
    localparam integer CONV_CYCLES_RAW = (CLK_HZ * CONV_NS) / 1_000_000_000;
    localparam integer CONV_CYCLES = (CONV_CYCLES_RAW < 1) ? 1 : CONV_CYCLES_RAW;

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_CONVERT = 2'd1;
    localparam [1:0] ST_SHIFT  = 2'd2;

    reg [1:0]  state;
    reg        phase_low;
    reg [4:0]  bit_count;
    reg [15:0] shift0;
    reg [15:0] shift1;
    reg [31:0] delay_count;

    always @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            phase_low   <= 1'b0;
            bit_count   <= 5'd0;
            shift0      <= 16'd0;
            shift1      <= 16'd0;
            delay_count <= 32'd0;
            adc_cs_n    <= 1'b1;
            adc_sclk    <= 1'b1;
            raw_ch0     <= 12'd0;
            raw_ch1     <= 12'd0;
            data_valid  <= 1'b0;
        end else begin
            data_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    adc_cs_n    <= 1'b1;
                    adc_sclk    <= 1'b1;
                    delay_count <= 32'd0;
                    if (sample_req) begin
                        adc_cs_n   <= 1'b0;
                        adc_sclk   <= 1'b1;
                        bit_count  <= 5'd0;
                        phase_low  <= 1'b0;
                        shift0     <= 16'd0;
                        shift1     <= 16'd0;
                        state      <= ST_CONVERT;
                    end
                end

                ST_CONVERT: begin
                    if (delay_count >= CONV_CYCLES - 1) begin
                        delay_count <= 32'd0;
                        adc_sclk    <= 1'b0;
                        phase_low   <= 1'b1;
                        state       <= ST_SHIFT;
                    end else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end

                ST_SHIFT: begin
                    if (phase_low) begin
                        if (delay_count >= HALF_DIV - 1) begin
                            delay_count <= 32'd0;
                            shift0      <= {shift0[14:0], adc_d0};
                            shift1      <= {shift1[14:0], adc_d1};
                            bit_count   <= bit_count + 1'b1;
                            adc_sclk    <= 1'b1;
                            phase_low   <= 1'b0;
                            if (bit_count == 5'd15) begin
                                raw_ch0 <= {shift0[14:0], adc_d0};
                                raw_ch1 <= {shift1[14:0], adc_d1};
                            end
                        end else begin
                            delay_count <= delay_count + 1'b1;
                        end
                    end else begin
                        if (delay_count >= HALF_DIV - 1) begin
                            delay_count <= 32'd0;
                            if (bit_count == 5'd16) begin
                                adc_cs_n   <= 1'b1;
                                adc_sclk   <= 1'b1;
                                data_valid <= 1'b1;
                                state      <= ST_IDLE;
                            end else begin
                                adc_sclk  <= 1'b0;
                                phase_low <= 1'b1;
                            end
                        end else begin
                            delay_count <= delay_count + 1'b1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
