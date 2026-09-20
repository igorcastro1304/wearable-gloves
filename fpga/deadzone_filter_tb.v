`timescale 1ns/1ps

module deadzone_filter_tb;
    reg clk;
    reg rst;
    reg data_ready;
    reg signed [15:0] raw_axis;
    reg [1:0] dpi_multiplier;

    wire signed [31:0] filtered_axis;
    wire filter_done;

    integer pass_cnt;
    integer fail_cnt;
    reg verbose;
    integer idx;
    integer sweep_raw;

    localparam integer DZ_TB = 300;

    deadzone_filter dut (
        .clk(clk),
        .rst(rst),
        .data_ready(data_ready),
        .raw_axis(raw_axis),
        .dpi_multiplier(dpi_multiplier),
        .filtered_axis(filtered_axis),
        .filter_done(filter_done)
    );

    always #5 clk = ~clk;

    initial begin
        #500000;
        $display("[TIMEOUT] Watchdog estourou - algum teste travou.");
        $finish;
    end

    function signed [31:0] ref_model(input signed [15:0] raw, input [1:0] dpi);
        integer r;
        begin
            if (raw > DZ_TB) r = raw - DZ_TB;
            
            else if (raw < -DZ_TB) r = raw + DZ_TB;
            
            else r = 0;
            
            ref_model = r * $signed({1'b0, dpi});
        end
    endfunction

    task send_sample(input signed [15:0] raw, input [1:0] dpi);
        begin
            @(posedge clk);
            raw_axis <= raw;
            dpi_multiplier <= dpi;
            data_ready <= 1'b1;
            @(posedge clk); 
            data_ready <= 1'b0;
        end
    endtask

    task wait_done;
        integer n;
        begin
            n = 0;
            while (filter_done !== 1'b1 && n < 20) begin
                @(posedge clk);
                n = n + 1;
            end
            if (n >= 20) begin
                fail_cnt = fail_cnt + 1;
                $display("[TIMEOUT] filter_done nao subiu em 20 ciclos.");
            end
        end
    endtask

    task check_eq(input signed [31:0] got, input signed [31:0] exp);
        begin
            if (got === exp) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] obtido = %0d", got);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] obtido = %0d, esperado = %0d", got, exp);
            end
        end
    endtask

    task run_case(input signed [15:0] raw, input [1:0] dpi, input signed [31:0] expected);
        begin
            send_sample(raw, dpi);
            wait_done;

            if (filtered_axis === expected) begin
                pass_cnt = pass_cnt + 1;
                if (verbose)
                    $display("[PASS] raw=%0d dpi=%0d -> %0d", raw, dpi, filtered_axis);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] raw=%0d dpi=%0d -> obtido %0d, esperado %0d",
                         raw, dpi, filtered_axis, expected);
            end

            if ((raw > 0 && filtered_axis < 0) || (raw < 0 && filtered_axis > 0)) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] SINAL INVERTIDO: raw=%0d -> %0d", raw, filtered_axis);
            end
        end
    endtask

    task test_input_change_after_ready;
        begin
            @(posedge clk);
            raw_axis <= 16'sd1000;
            dpi_multiplier <= 2'd1;
            data_ready <= 1'b1;
            @(posedge clk);                  
            data_ready <= 1'b0;
            dpi_multiplier <= 2'd3;          
            raw_axis <= -16'sd1000;    
            wait_done;
            check_eq(filtered_axis, 32'sd700);
        end
    endtask

    task test_hold_without_ready;
        integer n;
        reg signed [31:0] snapshot;
        reg saw_done, saw_change;
        begin
            repeat (6) @(posedge clk);
            snapshot = filtered_axis;
            saw_done = 1'b0;
            saw_change = 1'b0;

            for (n = 0; n < 20; n = n + 1) begin
                @(posedge clk);
                raw_axis <= n[0] ? 16'sd5000 : -16'sd5000;
                dpi_multiplier <= n[1:0];

                if (filter_done !== 1'b0) saw_done = 1'b1;
                
                if (filtered_axis !== snapshot) saw_change = 1'b1;
            end

            if (saw_done) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] filter_done subiu sem data_ready.");
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] filter_done nao subiu sem data_ready.");
            end

            if (saw_change) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] filtered_axis mudou sem amostra valida (seguiu raw_axis).");
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] filtered_axis ficou estavel sem amostra valida.");
            end
        end
    endtask

    task test_streaming;
        integer n, got;
        reg signed [31:0] exp0, exp1, exp2;
        begin
            exp0 = ref_model(16'sd1000, 2'd1); 
            exp1 = ref_model(-16'sd1000, 2'd2);
            exp2 = ref_model(16'sd500, 2'd3);

            @(posedge clk);
            raw_axis <= 16'sd1000; dpi_multiplier <= 2'd1;  data_ready <= 1'b1;
            @(posedge clk);
            raw_axis <= -16'sd1000; dpi_multiplier <= 2'd2;
            @(posedge clk);
            raw_axis <= 16'sd500; dpi_multiplier <= 2'd3;
            @(posedge clk);
            data_ready <= 1'b0;

            got = 0;
            for (n = 0; n < 12; n = n + 1) begin
                @(posedge clk);
                if (filter_done === 1'b1) begin
                    case (got)
                        0: check_eq(filtered_axis, exp0);
                        1: check_eq(filtered_axis, exp1);
                        2: check_eq(filtered_axis, exp2);
                        default: begin
                            fail_cnt = fail_cnt + 1;
                            $display("[FAIL] filter_done extra: %0d", filtered_axis);
                        end
                    endcase
                    got = got + 1;
                end
            end

            if (got != 3) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] Esperados 3 filter_done, recebidos %0d", got);
            end
        end
    endtask

    task test_reset_midflight;
        integer n;
        reg saw_done;
        begin
            @(posedge clk);
            raw_axis <= 16'sd1000;
            dpi_multiplier <= 2'd2;
            data_ready <= 1'b1;
            @(posedge clk);
            data_ready <= 1'b0;
            @(posedge clk);                
            #1 rst = 1'b1;
            repeat (2) @(posedge clk);
            #1 rst = 1'b0;

            saw_done = 1'b0;
            for (n = 0; n < 10; n = n + 1) begin
                @(posedge clk);

                if (filter_done !== 1'b0) saw_done = 1'b1;
            end

            if (saw_done) begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] Amostra em voo sobreviveu ao reset.");
            end else begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] Reset descartou a amostra em voo.");
            end

            check_eq(filtered_axis, 32'sd0);
        end
    endtask

    initial begin
        $dumpfile("deadzone_filter.vcd");
        $dumpvars(0, deadzone_filter_tb);

        clk = 0;
        rst = 1;
        data_ready = 0;
        raw_axis = 0;
        dpi_multiplier = 0;
        pass_cnt = 0;
        fail_cnt = 0;
        verbose = 1;

        #33 rst = 0;
        repeat (3) @(posedge clk);

        $display("==========================================================================");
        $display("[SIM] INICIO - deadzone_filter");
        $display("==========================================================================");

        $display("\n--- Teste 1: amostras basicas (ganho x1, x2, x3) ---");
        run_case(1000, 2, 1400);
        run_case(2000, 1, 1700);
        run_case(1000, 3, 2100);

        $display("\n--- Teste 2: sinal negativo (simetria) ---");
        run_case(-1000, 2, -1400);
        run_case(-2000, 1, -1700);

        $display("\n--- Teste 3: fronteiras da zona morta (+-300) ---");
        run_case(300, 3, 0);
        run_case(301, 3, 3);
        run_case(-300, 3, 0);
        run_case(-301, 3, -3);
        run_case(0, 2, 0);

        $display("\n--- Teste 4: extremos de 16 bits e ganho 0 ---");
        run_case(32767, 3, 97401);
        run_case(-32768, 3, -97404);
        run_case(1000, 0, 0);

        $display("\n--- Teste 5: varredura -2000..2000 contra modelo de referencia ---");
        verbose = 0;
        for (idx = 0; idx < 81; idx = idx + 1) begin
            sweep_raw = -2000 + idx * 50;
            run_case(sweep_raw, idx[1:0], ref_model(sweep_raw, idx[1:0]));
        end
        verbose = 1;
        $display("[INFO] Varredura concluida.");

        $display("\n--- Teste 6: dpi/raw mudam logo apos o data_ready ---");
        test_input_change_after_ready;

        $display("\n--- Teste 7: sem data_ready a saida nao muda ---");
        test_hold_without_ready;

        $display("\n--- Teste 8: amostras consecutivas (streaming) ---");
        test_streaming;

        $display("\n--- Teste 9: reset no meio do pipeline ---");
        test_reset_midflight;

        $display("\n==========================================================================");
        $display("[SIM] RESULTADO FINAL: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("[SIM] TODOS OS TESTES PASSARAM");
        else
            $display("[SIM] HA FALHAS");
        $display("==========================================================================");
        $finish;
    end
endmodule