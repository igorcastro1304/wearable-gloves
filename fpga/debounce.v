module debounce #(
    parameter CLK_FREQ = 27_000_000,
    parameter MS = 10,
    parameter ACTIVE_LOW = 1
) (
    input wire clk,
    input wire rst,
    input wire din,
    output reg  pressed,
    output wire pressed_rise
);
    localparam integer MAXC = (CLK_FREQ / 1000) * MS;
    localparam IDLE = (ACTIVE_LOW != 0) ? 1'b1 : 1'b0;

    reg [1:0] sync;
    reg [19:0] cnt;
    reg pressed_d;

    wire level = (sync[1] != IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync      <= {IDLE, IDLE};
            cnt       <= 20'd0;
            pressed   <= 1'b0;
            pressed_d <= 1'b0;
        end else begin
            sync      <= {sync[0], din};
            pressed_d <= pressed;

            if (level == pressed) begin
                cnt <= 20'd0;
            end else if (cnt == MAXC - 1) begin
                pressed <= level;
                cnt     <= 20'd0;
            end else begin
                cnt <= cnt + 20'd1;
            end
        end
    end

    assign pressed_rise = pressed & ~pressed_d;
endmodule