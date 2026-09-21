module crc8_bram (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] addr,
    output reg  [7:0] q,
    output reg        ready
);
    function [7:0] crc8_byte(input [7:0] d);
        integer i;
        reg [7:0] c;
        begin
            c = d;
            for (i = 0; i < 8; i = i + 1)
                c = c[7] ? ({c[6:0], 1'b0} ^ 8'h07) : {c[6:0], 1'b0};
            crc8_byte = c;
        end
    endfunction

    reg [7:0] mem [0:255];
    reg [8:0] init_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            init_cnt <= 9'd0;
            ready    <= 1'b0;
        end else begin
            if (!init_cnt[8]) init_cnt <= init_cnt + 9'd1;
            ready <= init_cnt[8];
        end
    end

    always @(posedge clk) begin
        if (!init_cnt[8]) mem[init_cnt[7:0]] <= crc8_byte(init_cnt[7:0]);
        q <= mem[addr];
    end
endmodule
