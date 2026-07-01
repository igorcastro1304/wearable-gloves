module deadzone_filter (
    input signed [7:0] raw_axis,
    input [1:0] dpi_multiplier,
    output reg signed [7:0] filtered_axis
);
    parameter signed [7:0] DEADZONE = 8'sd8;

    always @(*) begin
        if (raw_axis > DEADZONE) begin
            filtered_axis = (raw_axis - DEADZONE) * $signed({6'b0, dpi_multiplier});
        end else if (raw_axis < -DEADZONE) begin
            filtered_axis = (raw_axis + DEADZONE) * $signed({6'b0, dpi_multiplier});
        end else begin
            filtered_axis = 8'sd0;
        end
    end
endmodule