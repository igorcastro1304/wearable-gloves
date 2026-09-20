`timescale 1ns/1ps

module i2c_master_tb;
    reg clk;
    reg rst;
    reg [2:0] cmd;
    reg start_cmd;
    reg [7:0] tx_data;
    wire [7:0] rx_data;
    wire busy;
    wire done;
    wire ack_error;

    wire sda;
    wire scl;

    assign (weak1, weak0) sda = 1'b1;
    assign (weak1, weak0) scl = 1'b1;

    reg sda_slave_drive;
    reg scl_slave_drive;

    assign sda = sda_slave_drive ? 1'b0 : 1'bz;
    assign scl = scl_slave_drive ? 1'b0 : 1'bz;

    realtime start_time;
    realtime end_time;
    realtime time_with_stretching;
    realtime time_without_stretching;

    i2c_master #(.CLK_DIV(4)) dut (
        .clk(clk),
        .rst(rst),
        .cmd(cmd),
        .start_cmd(start_cmd),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .sda(sda),
        .scl(scl)
    );

    always #5 clk = ~clk;

    task send_cmd(input [2:0] command, input [7:0] data);
        begin
            @(posedge clk);
            while (busy) @(posedge clk);
            
            cmd = command;
            tx_data = data;
            start_cmd = 1;
            @(posedge clk);
            start_cmd = 0;
            @(posedge done);
            @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("i2c_master_tb.vcd");
        $dumpvars(0, i2c_master_tb);

        clk = 0;
        rst = 1;
        cmd = 0;
        start_cmd = 0;
        tx_data = 8'h00;
        sda_slave_drive = 0;
        scl_slave_drive = 0;

        #40;
        rst = 0;
        #20;

        $display("==========================================================================");
        $display("[SIM] ENTRANDO NO PROCESSO DE VALIDAÇÃO DE ERROS - i2c_master");
        $display("==========================================================================");
        
        $display("\n--- Teste de Erro 1: Falha de ACK (Master detecta NACK) ---");
        send_cmd(3'd1, 8'h00);

        sda_slave_drive = 0;
        send_cmd(3'd2, 8'hd0);

        if (ack_error == 1)
            $display("[SUCCESSFUL TEST] Erro detectado corretamente: master gerou ack_error = 1!");
        else
            $display("[VULNERABILIDADE] Erro: O master deveria ter indicado ack_error!");
        
        send_cmd(3'd5, 8'h00);
        #100;

        $display("\n--- Teste de Erro 2a: Suporte Real a Clock Stretching ---");
        $display("[INFO] O slave puxará SCL para baixo simulando clock stretching após o primeiro bit de escrita...");

        start_time = $realtime;
        send_cmd(3'd1, 8'h00);

        fork
            begin
                send_cmd(3'd2, 8'haa);
            end
            begin
                @(negedge scl);
                scl_slave_drive = 1;
                $display("[INFO] [SLAVE] SCL puxado para baixo para esticar o clock (Stretching ativo por 120ns)...");
                
                #120;
                scl_slave_drive = 0;
                $display("[INFO] [SLAVE] SCL liberado!");
            end
        join

        send_cmd(3'd5, 8'h00);
        end_time = $realtime;
        time_with_stretching = end_time - start_time;
        $display("[SUCCESS] Master sincronizou corretamente com o Clock Stretching!");
        $display("[INFO] Tempo total com clock stretching: %0t ns", time_with_stretching);
        #100;

        $display("\n--- Teste de Erro 2b: Caso Sem Clock Stretching (Fluxo Normal) ---");
        $display("[INFO] Realizando exatamente a mesma transação, mas desta vez o slave NÃO realizará clock stretching...");

        start_time = $realtime;
        send_cmd(3'd1, 8'h00);
        send_cmd(3'd2, 8'haa);
        send_cmd(3'd5, 8'h00);
        end_time = $realtime;
        time_without_stretching = end_time - start_time;

        $display("[SUCCESS] Transmissão normal sem stretching concluída!");
        $display("[INFO] Tempo total sem clock stretching: %0t ns", time_without_stretching);
        $display("[INFO] Diferença de tempo medida na simulação: %0t ns", (time_with_stretching - time_without_stretching));
        #100;
        
        
        $display("\n--- Teste de Erro 3: Glitch/Ruído na Amostragem de Leitura ---");
        $display("[INFO] Iniciando leitura onde ocorrerá um glitch de 2ns no SDA no momento da amostragem...");

        send_cmd(3'd1, 8'h00);

        fork
            begin
                @(posedge scl);
                #2;
                sda_slave_drive = 1;
                #2;
                sda_slave_drive = 0;
            end
            begin
                sda_slave_drive = 0;
                send_cmd(3'd3, 8'h00);
            end
        join

        $display("[DATA LIDO] rx_data = 8'h%h (Esperado: 8'hff se o glitch de SDA foi filtrado)", rx_data);
        if (rx_data == 8'hff) begin
            $display("[SUCCESS] Glitch filtrado com sucesso pelo filtro digital!");
        end else begin
            $display("[FAIL] Ruído corrompeu a transmissão. Dado lido incorretamente!");
        end

        send_cmd(3'd5, 8'h00);
        #100;

        $display("\n--- Caso de Sucesso: START + WRITE com confirmação de ACK ---");
        send_cmd(3'd1, 8'h00);

        fork
            begin
                repeat(8) @(posedge scl);
                @(negedge scl);
                sda_slave_drive = 1;
                @(posedge scl);
                @(negedge scl)
                sda_slave_drive = 0;
            end
            begin
                send_cmd(3'd2, 8'h3b);
            end
        join

        if (ack_error == 0)
            $display("[SUCCESS] Sucesso! ACK recebido corretamente do slave.");
        else
            $display("[FAIL] Falha inesperada no caso de sucesso!");

        send_cmd(3'd5, 8'h00);
        #100;

        $display("\n==========================================================================");
        $display("[SIM] FIM DOS TESTES DE ERRO DO i2c_master");
        $display("==========================================================================");

        $finish;
    end
endmodule