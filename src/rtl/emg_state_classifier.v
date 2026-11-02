`timescale 1ns / 1ps

// One-channel relaxed/tense classifier.
// A calibration pass averages CALIB_SAMPLES relaxed MAV values. The enter and
// exit thresholds include hysteresis and scale up if the measured baseline is
// noisy. CALIB_SAMPLES must be a power of two.
module emg_state_classifier #(
    parameter integer CALIB_SAMPLES     = 128,
    parameter integer CALIB_SHIFT       = 7,
    parameter integer MIN_ENTER_MARGIN  = 40,
    parameter integer LEVEL_W           = 13
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    feature_valid,
    input  wire [LEVEL_W-1:0]      level,
    input  wire                    calibrate,
    output reg                     ready,
    output reg                     calibrating,
    output reg                     tense,
    output reg  [LEVEL_W-1:0]      baseline,
    output wire [LEVEL_W:0]        enter_threshold,
    output wire [LEVEL_W:0]        exit_threshold,
    output wire [LEVEL_W-1:0]      activity_level
);

    localparam integer CALIB_W =
        (CALIB_SAMPLES <= 1) ? 1 : $clog2(CALIB_SAMPLES);
    localparam integer SUM_W =
        LEVEL_W + CALIB_W + 1;

    reg [CALIB_W-1:0] calib_count;
    reg [SUM_W-1:0]   calib_sum;

    wire [SUM_W-1:0] calib_total = calib_sum + level;
    wire [LEVEL_W:0] half_baseline = baseline >> 1;
    wire [LEVEL_W:0] min_enter_margin = MIN_ENTER_MARGIN;
    wire [LEVEL_W:0] enter_margin =
        (half_baseline > min_enter_margin)
        ? half_baseline
        : min_enter_margin;
    wire [LEVEL_W:0] exit_margin = enter_margin >> 1;

    assign enter_threshold = baseline + enter_margin;
    assign exit_threshold  = baseline + exit_margin;
    assign activity_level  = (level > baseline) ? (level - baseline)
                                               : {LEVEL_W{1'b0}};

    always @(posedge clk) begin
        if (rst) begin
            ready         <= 1'b0;
            calibrating   <= 1'b1;
            tense         <= 1'b0;
            baseline      <= {LEVEL_W{1'b0}};
            calib_count   <= {CALIB_W{1'b0}};
            calib_sum     <= {SUM_W{1'b0}};
        end else if (calibrate) begin
            ready       <= 1'b0;
            calibrating <= 1'b1;
            tense       <= 1'b0;
            calib_count <= {CALIB_W{1'b0}};
            calib_sum   <= {SUM_W{1'b0}};
        end else if (feature_valid) begin
            if (calibrating) begin
                calib_sum <= calib_total;
                if (calib_count == CALIB_SAMPLES - 1) begin
                    baseline    <= calib_total >> CALIB_SHIFT;
                    calib_count <= {CALIB_W{1'b0}};
                    calib_sum   <= {SUM_W{1'b0}};
                    calibrating <= 1'b0;
                    ready       <= 1'b1;
                    tense       <= 1'b0;
                end else begin
                    calib_count <= calib_count + 1'b1;
                end
            end else if (ready) begin
                if (level >= enter_threshold) begin
                    tense <= 1'b1;
                end else if (level <= exit_threshold) begin
                    tense <= 1'b0;
                end
            end
        end
    end

endmodule
