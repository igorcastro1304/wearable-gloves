module priority_encoder (
    input wire [3:0] buttons,
    output reg [1:0] encoded_val,
    output reg valid_press
);
    always @(*) begin
	if (buttons) begin
            encoded_val = 2'b11;
            valid_press = 1'b1;
        end else if (buttons) begin
            encoded_val = 2'b10;
            valid_press = 1'b1;
        end else if (buttons) begin
            encoded_val = 2'b01;
            valid_press = 1'b1;
        end else if (buttons) begin
            encoded_val = 2'b00;
            valid_press = 1'b1;
        end else begin
            encoded_val = 2'b00;
            valid_press = 1'b0;
        end
    end

endmodule
