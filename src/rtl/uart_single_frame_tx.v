`timescale 1ns / 1ps

// Single-channel telemetry frame:
// AA 55 | seq | raw | mav | baseline | enter_threshold |
// flex_raw | gyro_z | status | xor_checksum
// status[0]=EMG tense, [1]=EMG ready, [2]=EMG calibrating,
// [3]=grip closed, [4]=flex ready, [5]=gyro calibrated,
// [6]=I2C error.
module uart_single_frame_tx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115_200
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_start,
    input  wire [15:0] seq,
    input  wire [11:0] raw,
    input  wire [12:0] mav,
    input  wire [12:0] baseline,
    input  wire [13:0] threshold,
    input  wire [11:0] flex_raw,
    input  wire [15:0] gyro_z,
    input  wire [7:0]  status,
    output wire        txd,
    output wire        frame_busy
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_LOAD = 2'd1;
    localparam [1:0] ST_WAIT = 2'd2;

    reg [1:0]  state;
    reg [4:0]  byte_index;
    reg        tx_start;
    reg [15:0] stored_seq;
    reg [11:0] stored_raw;
    reg [12:0] stored_mav;
    reg [12:0] stored_baseline;
    reg [13:0] stored_threshold;
    reg [11:0] stored_flex_raw;
    reg [15:0] stored_gyro_z;
    reg [7:0]  stored_status;
    reg [7:0]  stored_checksum;
    reg [7:0]  tx_byte;

    wire tx_ready;
    wire tx_done;

    wire [7:0] checksum_now =
        8'hAA ^ 8'h55 ^
        seq[15:8] ^ seq[7:0] ^
        {4'b0000, raw[11:8]} ^ raw[7:0] ^
        {3'b000, mav[12:8]} ^ mav[7:0] ^
        {3'b000, baseline[12:8]} ^ baseline[7:0] ^
        {2'b00, threshold[13:8]} ^ threshold[7:0] ^
        {4'b0000, flex_raw[11:8]} ^ flex_raw[7:0] ^
        gyro_z[15:8] ^ gyro_z[7:0] ^
        status;

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .data_in(tx_byte),
        .txd(txd),
        .ready(tx_ready),
        .done(tx_done)
    );

    always @(*) begin
        case (byte_index)
            5'd0:  tx_byte = 8'hAA;
            5'd1:  tx_byte = 8'h55;
            5'd2:  tx_byte = stored_seq[15:8];
            5'd3:  tx_byte = stored_seq[7:0];
            5'd4:  tx_byte = {4'b0000, stored_raw[11:8]};
            5'd5:  tx_byte = stored_raw[7:0];
            5'd6:  tx_byte = {3'b000, stored_mav[12:8]};
            5'd7:  tx_byte = stored_mav[7:0];
            5'd8:  tx_byte = {3'b000, stored_baseline[12:8]};
            5'd9:  tx_byte = stored_baseline[7:0];
            5'd10: tx_byte = {2'b00, stored_threshold[13:8]};
            5'd11: tx_byte = stored_threshold[7:0];
            5'd12: tx_byte = {4'b0000, stored_flex_raw[11:8]};
            5'd13: tx_byte = stored_flex_raw[7:0];
            5'd14: tx_byte = stored_gyro_z[15:8];
            5'd15: tx_byte = stored_gyro_z[7:0];
            5'd16: tx_byte = stored_status;
            5'd17: tx_byte = stored_checksum;
            default: tx_byte = 8'h00;
        endcase
    end

    assign frame_busy = (state != ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state           <= ST_IDLE;
            byte_index      <= 5'd0;
            tx_start        <= 1'b0;
            stored_seq      <= 16'd0;
            stored_raw      <= 12'd0;
            stored_mav      <= 13'd0;
            stored_baseline <= 13'd0;
            stored_threshold <= 14'd0;
            stored_flex_raw <= 12'd0;
            stored_gyro_z   <= 16'd0;
            stored_status   <= 8'd0;
            stored_checksum <= 8'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_start <= 1'b0;
                    if (frame_start) begin
                        stored_seq       <= seq;
                        stored_raw       <= raw;
                        stored_mav       <= mav;
                        stored_baseline  <= baseline;
                        stored_threshold <= threshold;
                        stored_flex_raw  <= flex_raw;
                        stored_gyro_z    <= gyro_z;
                        stored_status    <= status;
                        stored_checksum  <= checksum_now;
                        byte_index       <= 5'd0;
                        tx_start         <= 1'b1;
                        state            <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    tx_start <= 1'b0;
                    state    <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (tx_done) begin
                        if (byte_index == 5'd17) begin
                            state <= ST_IDLE;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            tx_start   <= 1'b1;
                            state      <= ST_LOAD;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
