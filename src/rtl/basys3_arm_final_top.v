`timescale 1ns / 1ps

// Sensor-to-arm integration:
// A0 MyoWare ENV -> JC4 gripper open/close
// A1 flex sensor -> JC3 forearm position
// MPU6050 gyro Y -> JC1 base target angle
// JC2 is not used.
module basys3_arm_final_top #(
    parameter integer CLK_HZ          = 100_000_000,
    parameter integer SAMPLE_HZ       = 1_000,
    parameter integer SPI_HZ          = 1_000_000,
    parameter integer CONV_NS         = 1_000,
    parameter integer UART_BAUD       = 115_200,
    parameter integer WINDOW_LEN      = 64,
    parameter integer STEP_LEN        = 8,
    parameter integer CALIB_SAMPLES   = 128,
    parameter integer MIN_EMG_MARGIN  = 40,
    parameter integer FLEX_HIGH_ENTER   = 3_000,
    parameter integer FLEX_HIGH_RELEASE = 2_500,
    parameter integer FLEX_LOW_ENTER    = 800,
    parameter integer FLEX_LOW_RELEASE  = 1_200,
    parameter integer MIN_ANGLE       = 10,
    parameter integer MAX_ANGLE       = 170,
    parameter integer GRIP_OPEN_ANGLE = 30,
    parameter integer GRIP_CLOSED_ANGLE = 150,
    parameter integer GYRO_DEADBAND   = 2_600,
    parameter integer GYRO_MED        = 5_000,
    parameter integer GYRO_FAST       = 10_000,
    parameter integer SERVO_STEP      = 2
) (
    input  wire        clk,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        sw0,
    output reg  [15:0] led,
    output wire        uart_txd,
    output wire        servo_jc1_pwm,
    output wire        servo_jc3_pwm,
    output wire        servo_jc4_pwm,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        dp,
    output wire        i2c_scl,
    inout  wire        i2c_sda,
    output wire        adc_cs_n,
    output wire        adc_sclk,
    input  wire        adc_d0,
    input  wire        adc_d1
);

    localparam integer POR_CYCLES =
        (CLK_HZ / 1_000 < 1) ? 1 : CLK_HZ / 1_000;
    localparam integer POR_W =
        (POR_CYCLES <= 2) ? 1 : $clog2(POR_CYCLES);

    reg [2:0] reset_sync;
    reg [POR_W-1:0] por_count;
    reg por_done;
    wire rst = reset_sync[2] | ~por_done;

    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], btnC};
        if (btnC) begin
            por_count <= {POR_W{1'b0}};
            por_done  <= 1'b0;
        end else if (!por_done) begin
            if (por_count >= POR_CYCLES - 1) begin
                por_count <= {POR_W{1'b0}};
                por_done  <= 1'b1;
            end else begin
                por_count <= por_count + 1'b1;
            end
        end
    end

    wire recalibrate_pulse;
    button_debounce #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(20)
    ) u_recalibrate_button (
        .clk(clk),
        .rst(rst),
        .button_in(btnU),
        .press_pulse(recalibrate_pulse)
    );

    wire sample_tick;
    wire [11:0] raw_ch0;
    wire [11:0] raw_ch1;
    wire adc_valid;
    wire [12:0] env_average;
    wire feature_valid;
    wire [12:0] flex_average;
    wire flex_valid;

    sample_tick_gen #(
        .CLK_HZ(CLK_HZ),
        .SAMPLE_HZ(SAMPLE_HZ)
    ) u_sample_tick (
        .clk(clk),
        .rst(rst),
        .sample_tick(sample_tick)
    );

    spi_adc #(
        .CLK_HZ(CLK_HZ),
        .SPI_HZ(SPI_HZ),
        .CONV_NS(CONV_NS)
    ) u_spi_adc (
        .clk(clk),
        .rst(rst),
        .sample_req(sample_tick),
        .adc_d0(adc_d0),
        .adc_d1(adc_d1),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .raw_ch0(raw_ch0),
        .raw_ch1(raw_ch1),
        .data_valid(adc_valid)
    );

    window_average_unsigned #(
        .WINDOW_LEN(WINDOW_LEN),
        .STEP_LEN(STEP_LEN),
        .IN_W(12),
        .OUT_W(13)
    ) u_env_average (
        .clk(clk),
        .rst(rst),
        .sample_valid(adc_valid),
        .sample_in(raw_ch0),
        .average(env_average),
        .average_valid(feature_valid)
    );

    window_average_unsigned #(
        .WINDOW_LEN(WINDOW_LEN),
        .STEP_LEN(STEP_LEN),
        .IN_W(12),
        .OUT_W(13)
    ) u_flex_average (
        .clk(clk),
        .rst(rst),
        .sample_valid(adc_valid),
        .sample_in(raw_ch1),
        .average(flex_average),
        .average_valid(flex_valid)
    );

    wire emg_ready;
    wire emg_calibrating;
    wire tense;
    wire [12:0] emg_baseline;
    wire [13:0] emg_enter_threshold;
    wire [12:0] emg_activity;

    emg_state_classifier #(
        .CALIB_SAMPLES(CALIB_SAMPLES),
        .CALIB_SHIFT(7),
        .MIN_ENTER_MARGIN(MIN_EMG_MARGIN),
        .LEVEL_W(13)
    ) u_emg_classifier (
        .clk(clk),
        .rst(rst),
        .feature_valid(feature_valid),
        .level(env_average),
        .calibrate(recalibrate_pulse),
        .ready(emg_ready),
        .calibrating(emg_calibrating),
        .tense(tense),
        .baseline(emg_baseline),
        .enter_threshold(emg_enter_threshold),
        .exit_threshold(),
        .activity_level(emg_activity)
    );

    wire signed [15:0] gyro_raw;
    wire gyro_raw_valid;
    wire i2c_error;
    wire signed [15:0] gyro_filtered;
    wire gyro_calibrated;

    mpu6050_six_axis_reader #(
        .CLK_HZ(CLK_HZ),
        .I2C_HZ(100_000),
        .READ_PERIOD_MS(10),
        .POWER_ON_MS(100),
        .INIT_WAIT_MS(100)
    ) u_mpu6050 (
        .clk(clk),
        .rst(rst),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .accel_x(),
        .accel_y(),
        .accel_z(),
        .temperature(),
        .gyro_x(),
        .gyro_y(gyro_raw),
        .gyro_z(),
        .data_valid(gyro_raw_valid),
        .i2c_error(i2c_error)
    );

    gyro_bias_calibrator #(
        .CALIB_SAMPLES(CALIB_SAMPLES),
        .SUM_SHIFT(7),
        .FILTER_SHIFT(3)
    ) u_gyro_calibrator (
        .clk(clk),
        .rst(rst),
        .sample_valid(gyro_raw_valid),
        .sample_in(gyro_raw),
        .calibrate(recalibrate_pulse),
        .sample_out(gyro_filtered),
        .calibrated(gyro_calibrated)
    );

    wire flex_ready;
    wire flex_calibrating;
    wire flex_active;
    wire [12:0] flex_baseline;
    wire [8:0] flex_angle;
    wire servo_tick;

    flex_angle_mapper #(
        .LEVEL_W(13),
        .MIN_ANGLE(20),
        .MAX_ANGLE(160),
        .START_ANGLE(90),
        .STEP_ANGLE(SERVO_STEP),
        .HIGH_ENTER(FLEX_HIGH_ENTER),
        .HIGH_RELEASE(FLEX_HIGH_RELEASE),
        .LOW_ENTER(FLEX_LOW_ENTER),
        .LOW_RELEASE(FLEX_LOW_RELEASE)
    ) u_flex_direction (
        .clk(clk),
        .rst(rst),
        .tick(servo_tick),
        .sample_valid(flex_valid),
        .level(flex_average),
        .calibrate(recalibrate_pulse),
        .ready(flex_ready),
        .calibrating(flex_calibrating),
        .active(flex_active),
        .baseline(flex_baseline),
        .angle(flex_angle)
    );

    wire base_active;
    wire base_moving;
    wire [8:0] base_target_angle;

    gyro_base_controller #(
        .CENTER_ANGLE(90),
        .MIN_ANGLE(MIN_ANGLE),
        .MAX_ANGLE(MAX_ANGLE),
        .DEADBAND(GYRO_DEADBAND),
        .MED_THRESHOLD(GYRO_MED),
        .FAST_THRESHOLD(GYRO_FAST),
        .CONFIRM_SAMPLES(12)
    ) u_gyro_base (
        .clk(clk),
        .rst(rst),
        .sample_valid(gyro_raw_valid),
        .gyro_axis(sw0 ? gyro_filtered : -gyro_filtered),
        .calibrated(gyro_calibrated),
        .calibrate(recalibrate_pulse),
        .active(base_active),
        .moving(base_moving),
        .target(base_target_angle)
    );

    sample_tick_gen #(
        .CLK_HZ(CLK_HZ),
        .SAMPLE_HZ(50)
    ) u_servo_tick (
        .clk(clk),
        .rst(rst),
        .sample_tick(servo_tick)
    );

    reg grip_active;
    wire [8:0] grip_target_angle =
        tense ? GRIP_CLOSED_ANGLE : GRIP_OPEN_ANGLE;

    always @(posedge clk) begin
        if (rst || recalibrate_pulse || emg_calibrating) begin
            grip_active <= 1'b0;
        end else if (emg_ready && tense) begin
            grip_active <= 1'b1;
        end
    end

    wire base_slew_active;
    wire grip_slew_active;
    wire [8:0] base_angle;
    wire [8:0] grip_angle;

    angle_slew #(
        .STEP_ANGLE(SERVO_STEP),
        .START_ANGLE(90)
    ) u_base_slew (
        .clk(clk),
        .rst(rst),
        .tick(servo_tick),
        .enable(base_active),
        .target(base_moving ? base_target_angle : base_angle),
        .active(base_slew_active),
        .angle(base_angle)
    );

    angle_slew #(
        .STEP_ANGLE(SERVO_STEP),
        .START_ANGLE(GRIP_OPEN_ANGLE)
    ) u_grip_slew (
        .clk(clk),
        .rst(rst),
        .tick(servo_tick),
        .enable(grip_active),
        .target(grip_target_angle),
        .active(grip_slew_active),
        .angle(grip_angle)
    );

    wire [15:0] base_pulse_us =
        base_slew_active
        ? 500 + (base_angle * 2_000) / 180
        : 16'd0;
    wire [15:0] flex_pulse_us =
        flex_active
        ? 500 + (flex_angle * 2_000) / 180
        : 16'd0;
    wire [15:0] grip_pulse_us =
        grip_slew_active
        ? 500 + (grip_angle * 2_000) / 180
        : 16'd0;

    servo_pwm_pulse #(
        .CLK_HZ(CLK_HZ),
        .PWM_HZ(50)
    ) u_servo_jc1 (
        .clk(clk),
        .rst(rst),
        .pulse_us(base_pulse_us),
        .servo_pwm(servo_jc1_pwm)
    );

    servo_pwm_pulse #(
        .CLK_HZ(CLK_HZ),
        .PWM_HZ(50)
    ) u_servo_jc3 (
        .clk(clk),
        .rst(rst),
        .pulse_us(flex_pulse_us),
        .servo_pwm(servo_jc3_pwm)
    );

    servo_pwm_pulse #(
        .CLK_HZ(CLK_HZ),
        .PWM_HZ(50)
    ) u_servo_jc4 (
        .clk(clk),
        .rst(rst),
        .pulse_us(grip_pulse_us),
        .servo_pwm(servo_jc4_pwm)
    );

    reg [15:0] frame_seq;
    always @(posedge clk) begin
        if (rst)
            frame_seq <= 16'd0;
        else if (feature_valid)
            frame_seq <= frame_seq + 1'b1;
    end

    wire [7:0] status = {
        base_slew_active,
        i2c_error,
        gyro_calibrated,
        flex_ready,
        grip_slew_active,
        emg_calibrating,
        emg_ready,
        tense
    };

    uart_single_frame_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(UART_BAUD)
    ) u_uart_frame (
        .clk(clk),
        .rst(rst),
        .frame_start(feature_valid),
        .seq(frame_seq),
        .raw(raw_ch0),
        .mav(env_average),
        .baseline(emg_baseline),
        .threshold(emg_enter_threshold),
        .flex_raw(raw_ch1),
        .gyro_z(sw0 ? gyro_filtered : -gyro_filtered),
        .status(status),
        .txd(uart_txd),
        .frame_busy()
    );

    seven_segment_raw_display #(
        .CLK_HZ(CLK_HZ),
        .SCAN_HZ(1_000),
        .UPDATE_HZ(1)
    ) u_raw_display (
        .clk(clk),
        .rst(rst),
        .value_valid(adc_valid),
        .value(raw_ch0),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

    reg [31:0] heartbeat_count;
    reg heartbeat;
    always @(posedge clk) begin
        if (rst) begin
            heartbeat_count <= 32'd0;
            heartbeat       <= 1'b0;
        end else if (heartbeat_count >= (CLK_HZ / 2) - 1) begin
            heartbeat_count <= 32'd0;
            heartbeat       <= ~heartbeat;
        end else begin
            heartbeat_count <= heartbeat_count + 1'b1;
        end
    end

    integer bar_index;
    always @(*) begin
        led       = 16'd0;
        led[0]    = heartbeat;
        led[1]    = emg_ready && !tense;
        led[2]    = emg_ready && tense;
        led[3]    = emg_calibrating || flex_calibrating ||
                    !gyro_calibrated;
        led[4]    = grip_slew_active;
        led[5]    = flex_active;
        led[6]    = gyro_calibrated;
        led[7]    = i2c_error;
        for (bar_index = 0; bar_index < 8; bar_index = bar_index + 1) begin
            led[15-bar_index] =
                emg_ready && (emg_activity >= ((bar_index + 1) * 96));
        end
    end

endmodule
