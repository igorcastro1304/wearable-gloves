module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy,
    output reg        done
);
    localparam integer DIV = CLK_FREQ / BAUD; 

    reg [15:0] cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  shifter;                       

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx      <= 1'b1;
            busy    <= 1'b0;
            done    <= 1'b0;
            cnt     <= 16'd0;
            bit_idx <= 4'd0;
            shifter <= 10'h3FF;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (start) begin
                    shifter <= {1'b1, data, 1'b0};
                    busy    <= 1'b1;
                    cnt     <= 16'd0;
                    bit_idx <= 4'd0;
                    tx      <= 1'b0;
                end
            end else begin
                if (cnt == DIV - 1) begin
                    cnt <= 16'd0;
                    if (bit_idx == 4'd9) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        tx   <= 1'b1;
                    end else begin
                        bit_idx <= bit_idx + 4'd1;
                        tx      <= shifter[bit_idx + 4'd1];
                    end
                end else begin
                    cnt <= cnt + 16'd1;
                end
            end
        end
    end
endmodule
