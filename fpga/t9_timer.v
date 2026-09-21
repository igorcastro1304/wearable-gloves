module t9_timer #(
    parameter CLK_FREQ = 27000000
) (
    input wire clk,
    input wire reset,
    input wire start,
    output reg timeout
);
    localparam COUNT_MAX = CLK_FREQ / 2;
    reg [24:0] counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 25'd0;
            timeout <= 1'b0;
        end else if (start) begin
            if (counter >= COUNT_MAX) begin
                timeout <= 1'b1;
                counter <= counter;
            end else begin
                counter <= counter + 1'b1;
                timeout <= 1'b0;
            end
        end else begin
            counter <= 25'd0;
            timeout <= 1'b0;
        end
    end
endmodule