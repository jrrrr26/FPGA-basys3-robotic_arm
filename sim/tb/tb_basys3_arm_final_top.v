`timescale 1ns / 1ps

module tb_basys3_arm_final_top;

    localparam integer CLK_HZ = 100_000;

    reg clk;
    reg btnC;
    reg btnU;
    reg sw0;
    wire [15:0] led;
    wire uart_txd;
    wire servo_jc1_pwm;
    wire servo_jc3_pwm;
    wire servo_jc4_pwm;
    wire [6:0] seg;
    wire [3:0] an;
    wire dp;
    wire i2c_scl;
    wire i2c_sda;
    wire adc_cs_n;
    wire adc_sclk;
    wire adc_d0;
    wire adc_d1;

    integer errors;

    always #5_000 clk = ~clk;
    pullup (i2c_sda);

    basys3_arm_final_top #(
        .CLK_HZ(CLK_HZ),
        .SAMPLE_HZ(1_000),
        .SPI_HZ(50_000),
        .CONV_NS(1_000),
        .UART_BAUD(115_200),
        .WINDOW_LEN(64),
        .STEP_LEN(8),
        .CALIB_SAMPLES(128)
    ) dut (
        .clk(clk),
        .btnC(btnC),
        .btnU(btnU),
        .sw0(sw0),
        .led(led),
        .uart_txd(uart_txd),
        .servo_jc1_pwm(servo_jc1_pwm),
        .servo_jc3_pwm(servo_jc3_pwm),
        .servo_jc4_pwm(servo_jc4_pwm),
        .seg(seg),
        .an(an),
        .dp(dp),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_d0(adc_d0),
        .adc_d1(adc_d1)
    );

    pmod_ad1_final_model u_adc_model (
        .cs_n(adc_cs_n),
        .sclk(adc_sclk),
        .d0(adc_d0),
        .d1(adc_d1)
    );

    initial begin
        clk    = 1'b0;
        btnC   = 1'b1;
        btnU   = 1'b0;
        sw0    = 1'b1;
        errors = 0;

        repeat (8) @(posedge clk);
        btnC = 1'b0;

        #2_000_000_000;
        if (!dut.emg_ready || !dut.flex_ready) begin
            $display("FAIL calibration emg_ready=%0d flex_ready=%0d",
                     dut.emg_ready, dut.flex_ready);
            errors = errors + 1;
        end else begin
            $display("PASS EMG and flex calibration completed");
        end

        #700_000_000;
        if (!dut.tense || !dut.grip_slew_active ||
            dut.grip_pulse_us === 16'd0) begin
            $display("FAIL gripper tense=%0d active=%0d pulse=%0d",
                     dut.tense, dut.grip_slew_active, dut.grip_pulse_us);
            errors = errors + 1;
        end else begin
            $display("PASS gripper closed: angle=%0d pulse=%0d us",
                     dut.grip_angle, dut.grip_pulse_us);
        end

        #1_500_000_000;
        if (!dut.flex_ready || dut.flex_angle < 9'd140) begin
            $display("FAIL flex ready=%0d angle=%0d pulse=%0d",
                     dut.flex_ready, dut.flex_angle,
                     dut.flex_pulse_us);
            errors = errors + 1;
        end else begin
            $display("PASS flex JC3 angle=%0d pulse=%0d us",
                     dut.flex_angle, dut.flex_pulse_us);
        end

        if (errors == 0) begin
            $display("TB_BASYS3_ARM_FINAL_TOP: PASS");
        end else begin
            $fatal(1, "TB_BASYS3_ARM_FINAL_TOP: %0d failure(s)", errors);
        end
        $finish;
    end

endmodule
