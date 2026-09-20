module deadzone_filter #(
    parameter signed [15:0] DEADZONE = 16'sd300
) (
    input wire clk,
    input wire rst,
    input wire data_ready,
    input wire signed [15:0] raw_axis,
    input wire [1:0] dpi_multiplier,
    output reg signed [31:0] filtered_axis,
    output reg filter_done
);
    localparam signed [15:0] DZ = (DEADZONE < 0) ? -DEADZONE : DEADZONE;

    reg signed [15:0] dz_result;

    always @* begin
        if (raw_axis > DZ)
            dz_result = raw_axis - DZ;
        else if (raw_axis < -DZ)
            dz_result = raw_axis + DZ;
        else
            dz_result = 16'sd0;
    end

    reg signed [15:0] sub_stage;
    reg [1:0] dpi_stage;
    reg signed [31:0] mul_stage;
    reg valid1, valid2;

    wire signed [2:0] dpi_s = {1'b0, dpi_stage};
    wire signed [31:0] product = sub_stage * dpi_s;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sub_stage <= 16'sd0;
            dpi_stage <= 2'd0;
            mul_stage <= 32'sd0;
            filtered_axis <= 32'sd0;
            valid1 <= 1'b0;
            valid2 <= 1'b0;
            filter_done <= 1'b0;
        end else begin
            valid1 <= data_ready;
            valid2 <= valid1;
            filter_done <= valid2;

            if (data_ready) begin
                sub_stage <= dz_result;
                dpi_stage <= dpi_multiplier;
            end

            if (valid1)
                mul_stage <= product;

            if (valid2)
                filtered_axis <= mul_stage;
        end
    end
endmodule