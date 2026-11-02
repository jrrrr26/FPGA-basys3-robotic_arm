`timescale 1ns / 1ps

// MPU6050 burst reader: ACCEL_X/Y/Z, temperature, GYRO_X/Y/Z.
// One transaction reads registers 0x3B through 0x48 (14 bytes).
module mpu6050_six_axis_reader #(
    parameter integer CLK_HZ         = 100_000_000,
    parameter integer I2C_HZ         = 100_000,
    parameter integer READ_PERIOD_MS = 10,
    parameter integer POWER_ON_MS    = 100,
    parameter integer INIT_WAIT_MS   = 100
) (
    input  wire               clk,
    input  wire               rst,
    inout  wire               i2c_sda,
    output wire               i2c_scl,
    output reg signed [15:0]  accel_x,
    output reg signed [15:0]  accel_y,
    output reg signed [15:0]  accel_z,
    output reg signed [15:0]  temperature,
    output reg signed [15:0]  gyro_x,
    output reg signed [15:0]  gyro_y,
    output reg signed [15:0]  gyro_z,
    output reg                data_valid,
    output reg                i2c_error
);

    localparam integer QDIV_RAW = CLK_HZ / (4 * I2C_HZ);
    localparam integer QDIV     = (QDIV_RAW < 2) ? 2 : QDIV_RAW;
    localparam integer QW       = (QDIV <= 2) ? 1 : $clog2(QDIV);
    localparam integer POWER_CYCLES =
        (CLK_HZ / 1_000 < 1) ? 1 : (CLK_HZ / 1_000) * POWER_ON_MS;
    localparam integer INIT_CYCLES =
        (CLK_HZ / 1_000 < 1) ? 1 : (CLK_HZ / 1_000) * INIT_WAIT_MS;
    localparam integer READ_CYCLES =
        (CLK_HZ / 1_000 < 1) ? 1 : (CLK_HZ / 1_000) * READ_PERIOD_MS;

    localparam [5:0] S_POWER_WAIT      = 6'd0;
    localparam [5:0] S_START           = 6'd1;
    localparam [5:0] S_LOAD_WAKE_ADDR  = 6'd2;
    localparam [5:0] S_TX              = 6'd3;
    localparam [5:0] S_ACK_AFTER_TX    = 6'd4;
    localparam [5:0] S_LOAD_WAKE_REG   = 6'd5;
    localparam [5:0] S_LOAD_WAKE_DATA  = 6'd6;
    localparam [5:0] S_PREP_STOP_INIT  = 6'd7;
    localparam [5:0] S_STOP            = 6'd8;
    localparam [5:0] S_INIT_SETTLE     = 6'd9;
    localparam [5:0] S_READ_WAIT       = 6'd10;
    localparam [5:0] S_LOAD_READ_ADDR  = 6'd11;
    localparam [5:0] S_LOAD_READ_REG   = 6'd12;
    localparam [5:0] S_PREP_RESTART    = 6'd13;
    localparam [5:0] S_LOAD_READ_ADDR_R= 6'd14;
    localparam [5:0] S_RX              = 6'd15;
    localparam [5:0] S_RX_DONE         = 6'd16;
    localparam [5:0] S_SEND_ACK        = 6'd17;
    localparam [5:0] S_NEXT_RX         = 6'd18;
    localparam [5:0] S_PREP_STOP_READ  = 6'd19;
    localparam [5:0] S_RX_PREP         = 6'd20;

    reg [QW-1:0] quarter_count;
    reg          quarter_tick;
    reg [1:0]    q;

    reg [5:0] state;
    reg [5:0] after_start_state;
    reg [5:0] after_tx_state;
    reg [5:0] after_rx_state;
    reg [5:0] after_ack_state;
    reg [5:0] after_stop_state;

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_count;
    reg       ack_bit;
    reg       sda_low;
    reg       scl;
    reg [31:0] delay_count;
    reg [3:0] byte_index;
    reg [7:0] burst_data [0:13];

    assign i2c_sda = sda_low ? 1'b0 : 1'bz;
    assign i2c_scl = scl;
    wire sda_in = i2c_sda;

    always @(posedge clk) begin
        if (rst) begin
            quarter_count <= {QW{1'b0}};
            quarter_tick  <= 1'b0;
        end else if (quarter_count >= QDIV - 1) begin
            quarter_count <= {QW{1'b0}};
            quarter_tick  <= 1'b1;
        end else begin
            quarter_count <= quarter_count + 1'b1;
            quarter_tick  <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state              <= S_POWER_WAIT;
            after_start_state  <= S_LOAD_WAKE_ADDR;
            after_tx_state     <= S_LOAD_WAKE_REG;
            after_rx_state     <= S_RX_DONE;
            after_ack_state    <= S_NEXT_RX;
            after_stop_state   <= S_READ_WAIT;
            tx_shift           <= 8'd0;
            rx_shift           <= 8'd0;
            bit_count          <= 3'd0;
            ack_bit            <= 1'b0;
            sda_low            <= 1'b0;
            scl                <= 1'b1;
            q                  <= 2'd0;
            delay_count        <= 32'd0;
            byte_index         <= 4'd0;
            accel_x            <= 16'sd0;
            accel_y            <= 16'sd0;
            accel_z            <= 16'sd0;
            temperature        <= 16'sd0;
            gyro_x             <= 16'sd0;
            gyro_y             <= 16'sd0;
            gyro_z             <= 16'sd0;
            data_valid         <= 1'b0;
            i2c_error          <= 1'b0;
        end else if ((state == S_POWER_WAIT) ||
                     (state == S_INIT_SETTLE) ||
                     (state == S_READ_WAIT)) begin
            if ((state == S_POWER_WAIT && delay_count >= POWER_CYCLES - 1) ||
                (state == S_INIT_SETTLE && delay_count >= INIT_CYCLES - 1) ||
                (state == S_READ_WAIT && delay_count >= READ_CYCLES - 1)) begin
                delay_count <= 32'd0;
                q           <= 2'd0;
                after_start_state <=
                    (state == S_POWER_WAIT) ? S_LOAD_WAKE_ADDR : S_LOAD_READ_ADDR;
                if (state == S_READ_WAIT)
                    i2c_error <= 1'b0;
                state <= S_START;
            end else begin
                delay_count <= delay_count + 1'b1;
            end
        end else if (quarter_tick) begin
            data_valid <= 1'b0;

            case (state)
                S_START: begin
                    if (q == 2'd0 || q == 2'd1) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b1;
                    end else if (q == 2'd2) begin
                        sda_low <= 1'b1;
                        scl     <= 1'b1;
                    end else begin
                        sda_low <= 1'b1;
                        scl     <= 1'b0;
                        q       <= 2'd0;
                        state   <= after_start_state;
                    end
                end

                S_LOAD_WAKE_ADDR: begin
                    tx_shift       <= 8'hD0;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_LOAD_WAKE_REG;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_LOAD_WAKE_REG: begin
                    tx_shift       <= 8'h6B;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_LOAD_WAKE_DATA;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_LOAD_WAKE_DATA: begin
                    tx_shift       <= 8'h00;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_PREP_STOP_INIT;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_TX: begin
                    scl     <= (q >= 2'd2);
                    sda_low <= ~tx_shift[7];
                    if (q == 2'd3) begin
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        if (bit_count == 3'd7) begin
                            bit_count <= 3'd0;
                            q         <= 2'd0;
                            state     <= S_ACK_AFTER_TX;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                S_ACK_AFTER_TX: begin
                    if (q == 2'd0 || q == 2'd1) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b0;
                    end else if (q == 2'd2) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b1;
                    end else begin
                        if (sda_in)
                            i2c_error <= 1'b1;
                        sda_low <= 1'b0;
                        scl     <= 1'b0;
                        q       <= 2'd0;
                        state   <= after_tx_state;
                    end
                end

                S_PREP_STOP_INIT: begin
                    after_stop_state <= S_INIT_SETTLE;
                    q                <= 2'd0;
                    state            <= S_STOP;
                end

                S_STOP: begin
                    if (q == 2'd0 || q == 2'd1) begin
                        sda_low <= 1'b1;
                        scl     <= (q == 2'd1);
                    end else if (q == 2'd2) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b1;
                    end else begin
                        sda_low     <= 1'b0;
                        scl         <= 1'b1;
                        delay_count <= 32'd0;
                        q           <= 2'd0;
                        state       <= after_stop_state;
                    end
                end

                S_LOAD_READ_ADDR: begin
                    tx_shift       <= 8'hD0;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_LOAD_READ_REG;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_LOAD_READ_REG: begin
                    tx_shift       <= 8'h3B;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_PREP_RESTART;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_PREP_RESTART: begin
                    after_start_state <= S_LOAD_READ_ADDR_R;
                    q                 <= 2'd0;
                    state             <= S_START;
                end

                S_LOAD_READ_ADDR_R: begin
                    tx_shift       <= 8'hD1;
                    bit_count      <= 3'd0;
                    after_tx_state <= S_RX_PREP;
                    byte_index     <= 4'd0;
                    q              <= 2'd0;
                    state          <= S_TX;
                end

                S_RX_PREP: begin
                    after_rx_state <= S_RX_DONE;
                    bit_count      <= 3'd0;
                    rx_shift       <= 8'd0;
                    q              <= 2'd0;
                    state          <= S_RX;
                end

                S_RX: begin
                    if (q == 2'd0 || q == 2'd1) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b0;
                    end else if (q == 2'd2) begin
                        sda_low <= 1'b0;
                        scl     <= 1'b1;
                    end else begin
                        rx_shift <= {rx_shift[6:0], sda_in};
                        scl      <= 1'b1;
                        if (bit_count == 3'd7) begin
                            bit_count <= 3'd0;
                            q         <= 2'd0;
                            state     <= after_rx_state;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                S_RX_DONE: begin
                    burst_data[byte_index] <= rx_shift;
                    if (byte_index == 4'd13) begin
                        ack_bit         <= 1'b1; // NACK final byte
                        after_ack_state <= S_PREP_STOP_READ;
                    end else begin
                        ack_bit         <= 1'b0; // ACK more bytes
                        after_ack_state <= S_NEXT_RX;
                    end
                    q     <= 2'd0;
                    state <= S_SEND_ACK;
                end

                S_NEXT_RX: begin
                    byte_index     <= byte_index + 1'b1;
                    after_rx_state <= S_RX_DONE;
                    bit_count      <= 3'd0;
                    rx_shift       <= 8'd0;
                    q              <= 2'd0;
                    state          <= S_RX;
                end

                S_SEND_ACK: begin
                    if (q == 2'd0 || q == 2'd1) begin
                        sda_low <= ~ack_bit;
                        scl     <= 1'b0;
                    end else if (q == 2'd2) begin
                        sda_low <= ~ack_bit;
                        scl     <= 1'b1;
                    end else begin
                        sda_low <= 1'b0;
                        scl     <= 1'b0;
                        q       <= 2'd0;
                        state   <= after_ack_state;
                    end
                end

                S_PREP_STOP_READ: begin
                    accel_x     <= {burst_data[0], burst_data[1]};
                    accel_y     <= {burst_data[2], burst_data[3]};
                    accel_z     <= {burst_data[4], burst_data[5]};
                    temperature <= {burst_data[6], burst_data[7]};
                    gyro_x      <= {burst_data[8], burst_data[9]};
                    gyro_y      <= {burst_data[10], burst_data[11]};
                    gyro_z      <= {burst_data[12], burst_data[13]};
                    data_valid  <= 1'b1;
                    after_stop_state <= S_READ_WAIT;
                    q           <= 2'd0;
                    state       <= S_STOP;
                end

                default: state <= S_POWER_WAIT;
            endcase

            if (state == S_START || state == S_TX ||
                state == S_RX || state == S_ACK_AFTER_TX ||
                state == S_SEND_ACK || state == S_STOP) begin
                if (q == 2'd3)
                    q <= 2'd0;
                else
                    q <= q + 1'b1;
            end
        end
    end

endmodule
