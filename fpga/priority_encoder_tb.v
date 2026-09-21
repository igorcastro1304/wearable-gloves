`timescale 1ns / 1ps

module priority_encoder_tb;

    reg [3:0] r_buttons;
    wire [1:0] w_encoded_val;
    wire w_valid_press;

    priority_encoder uut (
       .buttons(r_buttons),
       .encoded_val(w_encoded_val),
       .valid_press(w_valid_press)
    );

    initial begin
        $dumpfile("priority_encoder_tb.vcd");
        $dumpvars(0, priority_encoder_tb);

        r_buttons = 4'b0000;
        #10;

        r_buttons = 4'b0001;
        #10;

        r_buttons = 4'b0011;
        #10;

        r_buttons = 4'b0110;
        #10;

        r_buttons = 4'b1000;
        #10;

        r_buttons = 4'b0000;
        #10;

        $display("Simulação de testes digitais concluída com sucesso.");
        $finish;
    end
endmodule
