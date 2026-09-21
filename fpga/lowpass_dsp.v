module lowpass_dsp #(
    parameter USE_DSP = 0
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               in_valid,
    input  wire signed [15:0] x,
    input  wire        [8:0]  alpha,
    output reg  signed [15:0] y,
    output reg                out_valid
);
    reg signed [16:0] diff;
    reg signed [15:0] xs1, xs2;
    reg        [8:0]  alpha1;
    reg               v1, v2;
    reg               seeded;

    wire signed [17:0] mult_a = {diff[16], diff};          
    wire signed [17:0] mult_b = {9'd0, alpha1};
    wire signed [35:0] mult_p;

    mult18s #(.USE_DSP(USE_DSP)) u_mult (
        .clk(clk), .rst(rst), .ce(v1),
        .a(mult_a), .b(mult_b), .p(mult_p)
    );

    wire signed [35:0] rnd_sum = mult_p + 36'sd128;
    wire signed [35:0] step    = rnd_sum >>> 8;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            diff <= 17'sd0;  xs1 <= 16'sd0;  xs2 <= 16'sd0;  alpha1 <= 9'd0;
            v1 <= 1'b0;  v2 <= 1'b0;  seeded <= 1'b0;
            y <= 16'sd0;  out_valid <= 1'b0;
        end else begin
            v1        <= in_valid;
            v2        <= v1;
            out_valid <= v2;

            if (in_valid) begin
                diff   <= x - y;
                xs1    <= x;
                alpha1 <= alpha;
            end

            if (v1) xs2 <= xs1;

            if (v2) begin
                if (!seeded) begin
                    y      <= xs2;
                    seeded <= 1'b1;
                end else begin
                    y <= y + step[15:0];
                end
            end
        end
    end
endmodule
