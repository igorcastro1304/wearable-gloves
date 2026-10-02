module top (
    input  wire clk,
    input  wire rst_n,

    inout  wire i2c_sda,
    inout  wire i2c_scl,

    input  wire btn_left,
    input  wire btn_right,
    input  wire btn_dpi,
    input  wire sw_hand,

    output wire led_mov,
    output wire led_hb,

    output wire uart_txd
);
    localparam signed [15:0] DEADZONE_LSB = 16'sd2000;
    localparam [8:0] ALPHA_Q8 = 9'd64;
    localparam LED_ACTIVE_LOW = 1'b0;

    reg [15:0] por_cnt  = 16'd0;
    reg [1:0]  rst_sync = 2'b11;
    wire       por_done = &por_cnt;

    always @(posedge clk) begin
        if (!por_done)
            por_cnt <= por_cnt + 16'd1;
        rst_sync <= {rst_sync[0], (~por_done) | (~rst_n)};
    end

    wire rst = rst_sync[1];

    wire signed [15:0] raw_x;
    wire signed [15:0] raw_y;
    wire imu_data_ready;
    wire imu_data_valid;
    wire imu_data_error;

    wire signed [31:0] final_x;
    wire signed [31:0] final_y;
    wire filter_x_done;
    wire filter_y_done;

    wire [1:0] test_dpi = 2'b01;

    imu_interface u_imu (
        .clk(clk),
        .rst(rst),
        .sda(i2c_sda),
        .scl(i2c_scl),
        .accel_x(raw_x),
        .accel_y(raw_y),
        .data_ready(imu_data_ready),
        .data_valid(imu_data_valid),
        .data_error(imu_data_error)
    );

    wire signed [15:0] lp_x, lp_y;
    wire lp_x_valid, lp_y_valid;

    lowpass_dsp #(.USE_DSP(1)) u_lp_x (
        .clk(clk), .rst(rst), .in_valid(imu_data_ready),
        .x(raw_x), .alpha(ALPHA_Q8), .y(lp_x), .out_valid(lp_x_valid)
    );

    lowpass_dsp #(.USE_DSP(1)) u_lp_y (
        .clk(clk), .rst(rst), .in_valid(imu_data_ready),
        .x(raw_y), .alpha(ALPHA_Q8), .y(lp_y), .out_valid(lp_y_valid)
    );

    deadzone_filter #(.DEADZONE(DEADZONE_LSB), .USE_DSP(1)) u_dsp_x (
        .clk(clk),
        .rst(rst),
        .data_ready(lp_x_valid),
        .raw_axis(lp_x),
        .dpi_multiplier(test_dpi),
        .filtered_axis(final_x),
        .filter_done(filter_x_done)
    );

    deadzone_filter #(.DEADZONE(DEADZONE_LSB), .USE_DSP(1)) u_dsp_y (
        .clk(clk),
        .rst(rst),
        .data_ready(lp_y_valid),
        .raw_axis(lp_y),
        .dpi_multiplier(test_dpi),
        .filtered_axis(final_y),
        .filter_done(filter_y_done)
    );

    wire left_pressed, right_pressed, dpi_pressed, hand_left;
    wire left_rise, right_rise, dpi_rise, hand_rise;

    debounce #(.CLK_FREQ(27_000_000), .MS(10), .ACTIVE_LOW(1)) u_db_left  (.clk(clk), .rst(rst), .din(btn_left),  .pressed(left_pressed),  .pressed_rise(left_rise));
    debounce #(.CLK_FREQ(27_000_000), .MS(10), .ACTIVE_LOW(1)) u_db_right (.clk(clk), .rst(rst), .din(btn_right), .pressed(right_pressed), .pressed_rise(right_rise));
    debounce #(.CLK_FREQ(27_000_000), .MS(10), .ACTIVE_LOW(1)) u_db_dpi   (.clk(clk), .rst(rst), .din(btn_dpi),   .pressed(dpi_pressed),   .pressed_rise(dpi_rise));
    debounce #(.CLK_FREQ(27_000_000), .MS(10), .ACTIVE_LOW(1)) u_db_hand  (.clk(clk), .rst(rst), .din(sw_hand),   .pressed(hand_left),     .pressed_rise(hand_rise));

    reg hand_toggle;
    always @(posedge clk or posedge rst) begin
        if (rst)            hand_toggle <= 1'b0;
        else if (hand_rise) hand_toggle <= ~hand_toggle;
    end

    reg [22:0] refresh_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) refresh_cnt <= 23'd0;
        else     refresh_cnt <= refresh_cnt + 23'd1;
    end
    wire refresh_tick = &refresh_cnt;

    wire [1:0] btn_state = {right_pressed, left_pressed};
    reg  [1:0] btn_state_d;
    reg        hand_d;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_state_d <= 2'b00;
            hand_d      <= 1'b0;
        end else begin
            btn_state_d <= btn_state;
            hand_d      <= hand_toggle;
        end
    end

    wire btn_pulse  = (btn_state != btn_state_d) | refresh_tick;
    wire hand_pulse = (hand_toggle != hand_d)    | refresh_tick;

    pkt_sender #(.CLK_FREQ(27_000_000), .BAUD(115200)) u_pkt (
        .clk(clk),
        .rst(rst),
        .mv_pulse(filter_x_done),
        .mv_x(final_x),
        .mv_y(final_y),
        .btn_pulse(btn_pulse),
        .btn_state(btn_state),
        .hand_pulse(hand_pulse),
        .hand_state(hand_toggle),
        .dpi_pulse(dpi_rise),
        .tx(uart_txd)
    );

    wire led_mov_on = imu_data_valid & ((final_x != 32'sd0) | (final_y != 32'sd0));
    assign led_mov = LED_ACTIVE_LOW ? ~led_mov_on : led_mov_on;

    reg [24:0] hb_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) hb_cnt <= 25'd0;
        else     hb_cnt <= hb_cnt + 25'd1;
    end
    assign led_hb = hb_cnt[24];
endmodule