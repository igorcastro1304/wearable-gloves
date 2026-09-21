module mult18s #(
    parameter USE_DSP = 0
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               ce,
    input  wire signed [17:0] a,
    input  wire signed [17:0] b,
    output wire signed [35:0] p
);
    generate
        if (USE_DSP != 0) begin : g_dsp
            MULT18X18 #(
                .AREG(1'b0),            
                .BREG(1'b0),            
                .OUT_REG(1'b1),         
                .PIPE_REG(1'b0),
                .ASIGN_REG(1'b0),
                .BSIGN_REG(1'b0),
                .SOA_REG(1'b0),
                .MULT_RESET_MODE("SYNC")
            ) u_mult (
                .A(a),
                .B(b),
                .ASIGN(1'b1),           
                .BSIGN(1'b1),           
                .ASEL(1'b0),            
                .BSEL(1'b0),
                .SIA(18'd0),
                .SIB(18'd0),
                .CE(ce),
                .CLK(clk),
                .RESET(rst),
                .DOUT(p),
                .SOA(),
                .SOB()
            );
        end else begin : g_beh
            reg signed [35:0] p_r;
            always @(posedge clk) begin
                if (rst)     p_r <= 36'sd0;
                else if (ce) p_r <= a * b;
            end
            assign p = p_r;
        end
    endgenerate
endmodule
