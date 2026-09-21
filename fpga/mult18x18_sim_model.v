module MULT18X18 #(
    parameter AREG = 1'b0,
    parameter BREG = 1'b0,
    parameter OUT_REG = 1'b1,
    parameter PIPE_REG = 1'b0,
    parameter ASIGN_REG = 1'b0,
    parameter BSIGN_REG = 1'b0,
    parameter SOA_REG = 1'b0,
    parameter MULT_RESET_MODE = "SYNC"
) (
    input  wire [17:0] A,
    input  wire [17:0] B,
    input  wire        ASIGN,
    input  wire        BSIGN,
    input  wire        ASEL,
    input  wire        BSEL,
    input  wire [17:0] SIA,
    input  wire [17:0] SIB,
    input  wire        CE,
    input  wire        CLK,
    input  wire        RESET,
    output wire [35:0] DOUT,
    output wire [17:0] SOA,
    output wire [17:0] SOB
);
    wire signed [18:0] a_ext = ASIGN ? {A[17], A} : {1'b0, A};
    wire signed [18:0] b_ext = BSIGN ? {B[17], B} : {1'b0, B};
    wire signed [37:0] prod  = a_ext * b_ext;

    reg [35:0] q;
    always @(posedge CLK) begin
        if (RESET)   q <= 36'd0;
        else if (CE) q <= prod[35:0];
    end

    assign DOUT = q;
    assign SOA  = A;
    assign SOB  = B;
endmodule
