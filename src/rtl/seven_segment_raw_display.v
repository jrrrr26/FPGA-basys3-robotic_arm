`timescale 1ns / 1ps

// Displays a 12-bit unsigned value (0000..4095) on the Basys 3 four-digit
// common-anode display. Conversions use a registered double-dabble pipeline.
module seven_segment_raw_display #(
    parameter integer CLK_HZ    = 100_000_000,
    parameter integer SCAN_HZ   = 1_000,
    parameter integer UPDATE_HZ = 1
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       value_valid,
    input  wire [11:0] value,
    output reg  [6:0] seg,
    output reg  [3:0] an,
    output wire       dp
);

    localparam integer SCAN_DIV_RAW = CLK_HZ / SCAN_HZ;
    localparam integer SCAN_DIV =
        (SCAN_DIV_RAW < 2) ? 2 : SCAN_DIV_RAW;
    localparam integer SCAN_W =
        (SCAN_DIV <= 2) ? 1 : $clog2(SCAN_DIV);
    localparam integer UPDATE_DIV_RAW = CLK_HZ / UPDATE_HZ;
    localparam integer UPDATE_DIV =
        (UPDATE_DIV_RAW < 1) ? 1 : UPDATE_DIV_RAW;
    localparam integer UPDATE_W =
        (UPDATE_DIV <= 2) ? 1 : $clog2(UPDATE_DIV);

    reg [SCAN_W-1:0] scan_count;
    reg [1:0]        scan_digit;
    reg [UPDATE_W-1:0] update_count;
    reg [11:0] latest_value;

    reg [11:0] work;
    reg [15:0] bcd;
    reg [3:0]  iteration;
    reg        converting;
    reg [3:0]  ones;
    reg [3:0]  tens;
    reg [3:0]  hundreds;
    reg [3:0]  thousands;

    reg [15:0] adjusted_bcd;
    wire [15:0] next_bcd = {adjusted_bcd[14:0], work[11]};
    integer i;

    wire update_tick = (update_count >= UPDATE_DIV - 1);

    always @(*) begin
        adjusted_bcd = bcd;
        for (i = 0; i < 4; i = i + 1) begin
            if (adjusted_bcd[4*i +: 4] >= 4'd5) begin
                adjusted_bcd[4*i +: 4] =
                    adjusted_bcd[4*i +: 4] + 4'd3;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            work        <= 12'd0;
            bcd         <= 16'd0;
            iteration   <= 4'd0;
            converting  <= 1'b0;
            ones        <= 4'd0;
            tens        <= 4'd0;
            hundreds    <= 4'd0;
            thousands   <= 4'd0;
        end else if (update_tick && !converting) begin
            work       <= value_valid ? value : latest_value;
            bcd        <= 16'd0;
            iteration  <= 4'd0;
            converting <= 1'b1;
        end else if (converting) begin
            work <= {work[10:0], 1'b0};
            bcd  <= next_bcd;
            if (iteration == 4'd11) begin
                ones       <= next_bcd[3:0];
                tens       <= next_bcd[7:4];
                hundreds   <= next_bcd[11:8];
                thousands  <= next_bcd[15:12];
                converting <= 1'b0;
            end else begin
                iteration <= iteration + 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            latest_value <= 12'd0;
        end else if (value_valid) begin
            latest_value <= value;
        end
    end

    always @(posedge clk) begin
        if (rst || update_tick) begin
            update_count <= {UPDATE_W{1'b0}};
        end else begin
            update_count <= update_count + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            scan_count <= {SCAN_W{1'b0}};
            scan_digit <= 2'd0;
        end else if (scan_count >= SCAN_DIV - 1) begin
            scan_count <= {SCAN_W{1'b0}};
            scan_digit <= scan_digit + 1'b1;
        end else begin
            scan_count <= scan_count + 1'b1;
        end
    end

    reg [3:0] active_digit;
    always @(*) begin
        case (scan_digit)
            2'd0: begin
                an = 4'b1110;
                active_digit = ones;
            end
            2'd1: begin
                an = 4'b1101;
                active_digit = tens;
            end
            2'd2: begin
                an = 4'b1011;
                active_digit = hundreds;
            end
            default: begin
                an = 4'b0111;
                active_digit = thousands;
            end
        endcase
    end

    always @(*) begin
        case (active_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end

    assign dp = 1'b1;

endmodule
