module uart_tx_fifo #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200,
    parameter AW       = 8
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data,
    output wire       tx,
    output wire       busy,
    output reg        done
);
    reg  [7:0] in_data;
    reg        in_pending;
    wire       f_full, f_empty;
    wire       f_wr = in_pending & ~f_full;
    reg        f_rd;
    wire [7:0] f_q;

    byte_fifo #(.AW(AW)) u_fifo (
        .clk(clk), .rst(rst),
        .wr_en(f_wr), .wr_data(in_data),
        .rd_en(f_rd), .rd_data(f_q),
        .full(f_full), .empty(f_empty), .count()
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_pending <= 1'b0;
            in_data    <= 8'h00;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;
            if (in_pending) begin
                if (!f_full) begin           
                    in_pending <= 1'b0;
                    done       <= 1'b1;
                end
            end else if (start) begin
                in_pending <= 1'b1;
                in_data    <= data;
            end
        end
    end

    assign busy = in_pending;

    reg        u_start;
    reg  [7:0] u_data;
    wire       u_busy, u_done;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst(rst),
        .start(u_start), .data(u_data),
        .tx(tx), .busy(u_busy), .done(u_done)
    );

    localparam [1:0] D_IDLE = 2'd0, D_RD = 2'd1, D_LOAD = 2'd2, D_WAIT = 2'd3;
    reg [1:0] d_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            d_state <= D_IDLE;
            f_rd    <= 1'b0;
            u_start <= 1'b0;
            u_data  <= 8'h00;
        end else begin
            f_rd    <= 1'b0;
            u_start <= 1'b0;

            case (d_state)
                D_IDLE: if (!f_empty && !u_busy) begin
                    f_rd    <= 1'b1;
                    d_state <= D_RD;
                end
                D_RD:   d_state <= D_LOAD;
                D_LOAD: begin
                    u_data  <= f_q;
                    u_start <= 1'b1;
                    d_state <= D_WAIT;
                end
                D_WAIT: if (u_done) d_state <= D_IDLE;
                default: d_state <= D_IDLE;
            endcase
        end
    end
endmodule
