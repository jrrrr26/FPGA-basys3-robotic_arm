`timescale 1ns / 1ps

module tb_flex_angle_mapper;

    reg clk;
    reg rst;
    reg tick;
    reg sample_valid;
    reg [12:0] level;
    reg calibrate;
    wire ready;
    wire calibrating;
    wire active;
    wire [12:0] baseline;
    wire [8:0] angle;

    integer errors;
    integer i;
    reg [8:0] held_angle;

    always #5 clk = ~clk;

    flex_angle_mapper #(
        .LEVEL_W(13),
        .MIN_ANGLE(20),
        .MAX_ANGLE(160),
        .START_ANGLE(90),
        .STEP_ANGLE(2),
        .HIGH_ENTER(3000),
        .HIGH_RELEASE(2500),
        .LOW_ENTER(800),
        .LOW_RELEASE(1200)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .sample_valid(sample_valid),
        .level(level),
        .calibrate(calibrate),
        .ready(ready),
        .calibrating(calibrating),
        .active(active),
        .baseline(baseline),
        .angle(angle)
    );

    task automatic send_sample(input [12:0] value);
        begin
            @(negedge clk);
            level = value;
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;
            level = 13'd0;
        end
    endtask

    task automatic pulse_tick;
        begin
            @(negedge clk);
            tick = 1'b1;
            @(negedge clk);
            tick = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        tick = 1'b0;
        sample_valid = 1'b0;
        level = 13'd0;
        calibrate = 1'b0;
        errors = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        if (ready || active || angle != 9'd90) begin
            $display("FAIL startup ready=%0d active=%0d angle=%0d",
                     ready, active, angle);
            errors = errors + 1;
        end else begin
            $display("PASS startup stopped at angle=%0d", angle);
        end

        send_sample(13'd3500);
        repeat (2) @(posedge clk);
        if (!ready || !active) begin
            $display("FAIL high state ready=%0d active=%0d", ready, active);
            errors = errors + 1;
        end

        repeat (5) pulse_tick();
        repeat (2) @(posedge clk);
        if (angle != 9'd100) begin
            $display("FAIL high jog angle=%0d expected=100", angle);
            errors = errors + 1;
        end else begin
            $display("PASS high jog angle=%0d", angle);
        end

        send_sample(13'd1500);
        repeat (2) @(posedge clk);
        held_angle = angle;
        if (active) begin
            $display("FAIL deadband active=1 angle=%0d", angle);
            errors = errors + 1;
        end
        repeat (10) pulse_tick();
        repeat (2) @(posedge clk);
        if (angle != held_angle) begin
            $display("FAIL deadband angle changed %0d -> %0d",
                     held_angle, angle);
            errors = errors + 1;
        end else begin
            $display("PASS deadband holds angle=%0d with PWM stopped", angle);
        end

        send_sample(13'd100);
        repeat (2) @(posedge clk);
        if (!active) begin
            $display("FAIL low state active=0 angle=%0d", angle);
            errors = errors + 1;
        end
        repeat (5) pulse_tick();
        repeat (2) @(posedge clk);
        if (angle != 9'd90) begin
            $display("FAIL low jog angle=%0d expected=90", angle);
            errors = errors + 1;
        end else begin
            $display("PASS low jog angle=%0d", angle);
        end

        send_sample(13'd3500);
        repeat (2) @(posedge clk);
        for (i = 0; i < 40; i = i + 1)
            pulse_tick();
        repeat (3) @(posedge clk);
        if (angle != 9'd160 || active) begin
            $display("FAIL upper limit angle=%0d active=%0d", angle, active);
            errors = errors + 1;
        end else begin
            $display("PASS upper limit angle=160 with PWM stopped");
        end

        send_sample(13'd100);
        repeat (2) @(posedge clk);
        for (i = 0; i < 80; i = i + 1)
            pulse_tick();
        repeat (3) @(posedge clk);
        if (angle != 9'd20 || active) begin
            $display("FAIL lower limit angle=%0d active=%0d", angle, active);
            errors = errors + 1;
        end else begin
            $display("PASS lower limit angle=20 with PWM stopped");
        end

        if (errors == 0)
            $display("TB_FLEX_DIRECTION_CONTROLLER: PASS");
        else
            $fatal(1, "TB_FLEX_DIRECTION_CONTROLLER: %0d failure(s)", errors);
        $finish;
    end

endmodule
