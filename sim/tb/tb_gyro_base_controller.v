`timescale 1ns / 1ps

module tb_gyro_base_controller;

    reg clk;
    reg rst;
    reg sample_valid;
    reg signed [15:0] gyro_axis;
    reg calibrated;
    reg calibrate;
    wire active;
    wire moving;
    wire [8:0] target;

    integer i;
    integer errors;
    reg [8:0] held_target;

    always #500 clk = ~clk;

    gyro_base_controller #(
        .CENTER_ANGLE(90),
        .MIN_ANGLE(10),
        .MAX_ANGLE(170),
        .DEADBAND(2_600),
        .MED_THRESHOLD(5_000),
        .FAST_THRESHOLD(10_000),
        .CONFIRM_SAMPLES(12)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .gyro_axis(gyro_axis),
        .calibrated(calibrated),
        .calibrate(calibrate),
        .active(active),
        .moving(moving),
        .target(target)
    );

    task automatic sample_gyro(input signed [15:0] value);
        begin
            gyro_axis = value;
            sample_valid = 1'b1;
            @(posedge clk);
            #1 sample_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk          = 1'b0;
        rst          = 1'b1;
        sample_valid = 1'b0;
        gyro_axis    = 16'sd0;
        calibrated   = 1'b0;
        calibrate    = 1'b0;
        errors       = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        calibrated = 1'b1;
        repeat (2) @(posedge clk);

        for (i = 0; i < 11; i = i + 1)
            sample_gyro(16'sd12000);
        if (active || moving || target != 9'd90) begin
            $display("FAIL confirmation started early active=%0d moving=%0d target=%0d",
                     active, moving, target);
            errors = errors + 1;
        end

        sample_gyro(16'sd12000);
        if (!active || !moving || target != 9'd91) begin
            $display("FAIL first confirmed motion active=%0d moving=%0d target=%0d",
                     active, moving, target);
            errors = errors + 1;
        end else begin
            $display("PASS confirmation and positive motion target=%0d", target);
        end

        for (i = 0; i < 5; i = i + 1)
            sample_gyro(16'sd12000);
        if (target <= 9'd91) begin
            $display("FAIL sustained motion stopped after confirmation target=%0d",
                     target);
            errors = errors + 1;
        end else begin
            $display("PASS sustained motion target=%0d", target);
        end
        held_target = target;
        for (i = 0; i < 4; i = i + 1)
            sample_gyro(16'sd0);
        if (moving || target != held_target) begin
            $display("FAIL deadband moving=%0d target %0d -> %0d",
                     moving, held_target, target);
            errors = errors + 1;
        end else begin
            $display("PASS deadband freezes target=%0d", target);
        end

        for (i = 0; i < 11; i = i + 1)
            sample_gyro(-16'sd12000);
        if (moving || target != held_target) begin
            $display("FAIL negative started before confirmation moving=%0d target=%0d",
                     moving, target);
            errors = errors + 1;
        end
        sample_gyro(-16'sd12000);
        if (target >= held_target) begin
            $display("FAIL negative motion target=%0d", target);
            errors = errors + 1;
        end else begin
            $display("PASS negative motion target=%0d", target);
        end

        calibrate = 1'b1;
        @(posedge clk);
        #1 calibrate = 1'b0;
        @(posedge clk);
        #1;
        if (active || moving || target != 9'd90) begin
            $display("FAIL calibrate active=%0d moving=%0d target=%0d",
                     active, moving, target);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("TB_GYRO_BASE_CONTROLLER: PASS");
        else
            $fatal(1, "TB_GYRO_BASE_CONTROLLER: %0d failure(s)", errors);
        $finish;
    end

endmodule
