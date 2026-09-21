module pkt_sender #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
) (
    input  wire               clk,
    input  wire               rst,

    input  wire               mv_pulse,
    input  wire signed [31:0] mv_x,
    input  wire signed [31:0] mv_y,

    input  wire               btn_pulse,
    input  wire [1:0]         btn_state,

    input  wire               hand_pulse,
    input  wire               hand_state,

    input  wire               dpi_pulse,

    output wire               tx
);
    localparam [7:0] T_MOVE = 8'h4D, T_BTN = 8'h42, T_HAND = 8'h48, T_DPI = 8'h44;

    reg               p_mv, p_btn, p_hand, p_dpi;
    reg signed [31:0] mvx, mvy;
    reg [1:0]         btn_l;
    reg               hand_l;

    localparam [1:0] S_IDLE = 2'd0, S_SEND = 2'd1, S_WAIT = 2'd2;

    reg [1:0]  state;
    reg [3:0]  idx;
    reg [7:0]  ptype;
    reg [3:0]  plen;
    reg [63:0] pl;
    reg [7:0]  crc;
    reg        crc_pending;

    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;
    wire       tx_done;

    uart_tx_fifo #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst(rst),
        .start(tx_start), .data(tx_data),
        .tx(tx), .busy(tx_busy), .done(tx_done)
    );

    wire [3:0] end_idx = 4'd3 + plen; 
    wire [3:0] pidx    = idx - 4'd3;

    reg [7:0] cur_byte;
    always @* begin
        if (idx == 4'd0)        cur_byte = 8'hAA;
        else if (idx == 4'd1)   cur_byte = ptype;
        else if (idx == 4'd2)   cur_byte = {4'd0, plen};
        else if (idx < end_idx) cur_byte = pl[8*pidx +: 8];
        else                    cur_byte = crc;
    end

    wire [7:0] crc_q;
    wire       crc_ready;

    crc8_bram u_crc (
        .clk(clk), .rst(rst),
        .addr(crc ^ cur_byte),              
        .q(crc_q),
        .ready(crc_ready)
    );

    wire any_pending = p_dpi | p_btn | p_hand | p_mv;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;  idx <= 4'd0;  ptype <= 8'h00;  plen <= 4'd0;
            pl <= 64'd0;      crc <= 8'h00;  crc_pending <= 1'b0;
            tx_start <= 1'b0;  tx_data <= 8'h00;
            p_mv <= 1'b0;  p_btn <= 1'b0;  p_hand <= 1'b0;  p_dpi <= 1'b0;
            mvx <= 32'sd0;  mvy <= 32'sd0;  btn_l <= 2'b00;  hand_l <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (any_pending && crc_ready) begin
                        idx   <= 4'd0;
                        crc   <= 8'h00;
                        state <= S_SEND;
                        if (p_dpi) begin
                            ptype <= T_DPI;   plen <= 4'd1;  pl <= 64'h01;
                            p_dpi <= 1'b0;
                        end else if (p_btn) begin
                            ptype <= T_BTN;   plen <= 4'd1;  pl <= {62'd0, btn_l};
                            p_btn <= 1'b0;
                        end else if (p_hand) begin
                            ptype <= T_HAND;  plen <= 4'd1;  pl <= {63'd0, hand_l};
                            p_hand <= 1'b0;
                        end else begin
                            ptype <= T_MOVE;  plen <= 4'd8;  pl <= {mvy, mvx};
                            p_mv <= 1'b0;
                        end
                    end
                end

                S_SEND: begin
                    tx_data  <= cur_byte;
                    tx_start <= 1'b1;

                    if (idx >= 4'd1 && idx < end_idx) crc_pending <= 1'b1;
                    state <= S_WAIT;
                end

                S_WAIT: begin
                    if (crc_pending) begin 
                        crc         <= crc_q;
                        crc_pending <= 1'b0;
                    end
                    if (tx_done) begin
                        if (idx == end_idx) begin
                            state <= S_IDLE;
                        end else begin
                            idx   <= idx + 4'd1;
                            state <= S_SEND;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase

            if (mv_pulse)   begin mvx <= mv_x;  mvy <= mv_y;  p_mv   <= 1'b1; end
            if (btn_pulse)  begin btn_l <= btn_state;         p_btn  <= 1'b1; end
            if (hand_pulse) begin hand_l <= hand_state;       p_hand <= 1'b1; end
            if (dpi_pulse)  begin                             p_dpi  <= 1'b1; end
        end
    end
endmodule
