`timescale 1ns/1ps

module crc8_bram_tb;
    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg  [7:0] addr = 8'h00;
    wire [7:0] q;
    wire       ready;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    crc8_bram dut (.clk(clk), .rst(rst), .addr(addr), .q(q), .ready(ready));

    function [7:0] ref_crc(input [7:0] d);
        integer i;
        reg [7:0] c;
        begin
            c = d;
            for (i = 0; i < 8; i = i + 1)
                c = c[7] ? ({c[6:0], 1'b0} ^ 8'h07) : {c[6:0], 1'b0};
            ref_crc = c;
        end
    endfunction

    task check(input ok, input [8*60-1:0] name);
        begin
            if (ok) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0s", name);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0s", name);
            end
        end
    endtask

    integer a, n, bad;

    initial begin
        repeat (4) @(posedge clk);
        @(posedge clk); #1 rst = 1'b0;

        check(ready === 1'b0, "ready = 0 logo apos o reset");

        n = 0;
        while (ready !== 1'b1 && n < 400) begin @(posedge clk); n = n + 1; end
        check(n >= 256 && n <= 262, "tabela carregada em cerca de 256 ciclos");

        bad = 0;
        for (a = 0; a < 256; a = a + 1) begin
            @(posedge clk); #1; addr = a;
            @(posedge clk); #1;
            if (q !== ref_crc(a)) bad = bad + 1;
        end
        check(bad == 0, "as 256 posicoes conferem com o CRC-8 bit a bit");

        bad = 0;
        @(posedge clk); #1; addr = 8'h00;
        for (a = 1; a < 200; a = a + 1) begin
            @(posedge clk); #1; addr = a;
            if (q !== ref_crc(a - 1)) bad = bad + 1;
        end
        check(bad == 0, "leituras consecutivas com latencia de 1 ciclo");

        $display("");
        $display("[SIM] crc8_bram_tb: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #1000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule
