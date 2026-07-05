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

        // Estado inicial de repouso: todas as entradas em nível lógico baixo
        r_buttons = 4'b0000;
        #10;

        // Estímulo 1: Acionamento exclusivo do botão de menor prioridade (Botão 0)
        r_buttons = 4'b0001;
        #10;

        // Estímulo 2: Acionamento simultâneo do Botão 1 e Botão 0 (Mapeia o índice do Botão 1)
        r_buttons = 4'b0011;
        #10;

        // Estímulo 3: Acionamento simultâneo do Botão 2 (Índice 2'b10 deve assumir prioridade)
        r_buttons = 4'b0110;
        #10;

        // Estímulo 4: Acionamento do canal de maior prioridade (Botão 3)
        r_buttons = 4'b1000;
        #10;

        // Estímulo 5: Retorno ao estado de repouso com ausência de sinais lógicos
        r_buttons = 4'b0000;
        #10;

        $display("Simulação de testes digitais concluída com sucesso.");
        $finish;
    end
endmodule
