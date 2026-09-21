module byte_fifo #(
    parameter AW = 8
) (
    input  wire          clk,
    input  wire          rst,
    input  wire          wr_en,
    input  wire [7:0]    wr_data,
    input  wire          rd_en,
    output reg  [7:0]    rd_data,
    output wire          full,
    output wire          empty,
    output wire [AW:0]   count
);
    localparam DEPTH = (1 << AW);

    reg [7:0]    mem [0:DEPTH-1];
    reg [AW-1:0] wptr, rptr;
    reg [AW:0]   cnt;

    assign full  = (cnt == DEPTH);
    assign empty = (cnt == 0);
    assign count = cnt;

    wire do_wr = wr_en & ~full;
    wire do_rd = rd_en & ~empty;

    always @(posedge clk) begin
        if (do_wr) mem[wptr] <= wr_data;
        rd_data <= mem[rptr];
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wptr <= {AW{1'b0}};
            rptr <= {AW{1'b0}};
            cnt  <= {(AW+1){1'b0}};
        end else begin
            if (do_wr) wptr <= wptr + 1'b1;
            if (do_rd) rptr <= rptr + 1'b1;
            case ({do_wr, do_rd})
                2'b10:   cnt <= cnt + 1'b1;
                2'b01:   cnt <= cnt - 1'b1;
                default: ;
            endcase
        end
    end
endmodule
