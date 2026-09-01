`timescale 1ns / 1ps

module t9_key_fsm_tb;
    reg clk;
    reg reset;
    reg key_pressed_strobe;
    wire [1:0] char_index;
    wire commit_pulse;

    t9_key_fsm uut (
        .clk(clk),
        .reset(reset),
        .key_pressed_strobe(key_pressed_strobe),
        .char_index(char_index),
        .commit_pulse(commit_pulse)
    );
    
    always #18.5 clk = ~clk;

    initial begin
        $dumpfile("t9_key_fsm_tb.vcd");
        $dumpvars(0, t9_key_fsm_tb);

        clk = 0; reset = 1; key_pressed_strobe = 0;
        #100; reset = 0; #50;

        key_pressed_strobe = 1; #37; key_pressed_strobe = 0;
        #100;
        key_pressed_strobe = 1; #37; key_pressed_strobe = 0;
        #100;
        key_pressed_strobe = 1; #37; key_pressed_strobe = 0;
        #100;

        @(posedge commit_pulse);
        $display("Sucesso: Letra confirmada com índice=%b", char_index);

        #500
        $finish;
    end
endmodule