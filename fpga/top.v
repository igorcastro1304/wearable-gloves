module top (
    input wire clk,
    input wire rst,

    inout wire i2c_sda,
    output wire i2c_scl,

    output wire led_x,
    output wire led_y
);
    wire signed [15:0] raw_x;
    wire signed [15:0] raw_y;
    wire imu_data_ready;

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
        .data_ready(imu_data_ready)
    );

    deadzone_filter u_dsp_x (
        .clk(clk),
        .rst(rst),
        .data_ready(imu_data_ready),
        .raw_axis(raw_x),
        .dpi_multiplier(test_dpi),
        .filtered_axis(final_x),
        .filter_done(filter_x_done)
    );

        deadzone_filter u_dsp_y (
        .clk(clk),
        .rst(rst),
        .data_ready(imu_data_ready),
        .raw_axis(raw_y),
        .dpi_multiplier(test_dpi),
        .filtered_axis(final_y),
        .filter_done(filter_y_done)
    );

    assign led_x = (final_x != 32'sd0) ? 1'b1 : 1'b0;
    assign led_y = (final_y != 32'sd0) ? 1'b1 : 1'b0;
endmodule