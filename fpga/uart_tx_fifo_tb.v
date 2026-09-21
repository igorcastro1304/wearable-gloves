`timescale 1ns/1ps

module uart_tx_fifo_tb;
    localparam integer CLK_FREQ = 100_000_000;
    localparam integer BAUD     = 5_000_000;
    localparam integer BIT_NS   = 200;
    localparam integer N        = 300;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        start = 1'b0;
    reg  [7:0] data  = 8'h00;
    wire       tx, busy, done;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    uart_tx_fifo #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
        .clk(clk), .rst(rst), .start(start), .data(data),
        .tx(tx), .busy(busy), .done(done)
    );

    reg [7:0] rx_mem [0:1023];
    integer   rx_n = 0;
    integer   frame_err = 0;
    reg [7:0] rxb;
    integer   k;

    initial begin
        forever begin
            @(negedge tx);
            #(BIT_NS + BIT_NS / 2);
            for (k = 0; k < 8; k = k + 1) begin
                rxb[k] = tx;
                #(BIT_NS);
            end
            if (tx !== 1'b1) frame_err = frame_err + 1;
            rx_mem[rx_n] = rxb;
            rx_n = rx_n + 1;
            #(BIT_NS / 2);
        end
    end

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

    task push(input [7:0] d, output integer lat);
        begin
            @(posedge clk); #1;
            data = d;  start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
            lat = 0;
            while (done !== 1'b1 && lat < 100000) begin
                @(posedge clk);
                lat = lat + 1;
            end
        end
    endtask

    function [7:0] pat(input integer i);
        begin
            pat = (i * 7 + 3) & 255;
        end
    endfunction

    integer i, lat, max_early, max_late, bad;

    initial begin
        repeat (4) @(posedge clk);
        @(posedge clk); #1 rst = 1'b0;
        repeat (4) @(posedge clk);

        max_early = 0;  max_late = 0;
        for (i = 0; i < N; i = i + 1) begin
            push(pat(i), lat);
            if (i < 200 && lat > max_early) max_early = lat;
            if (i >= N - 20 && lat > max_late) max_late = lat;
        end
        check(max_early <= 6, "FIFO com espaco: done em poucos ciclos");
        check(max_late > 50,  "FIFO cheia: a entrada espera vaga (contrapressao)");

        i = 0;
        while (rx_n < N && i < 400000) begin @(posedge clk); i = i + 1; end
        repeat (30) @(posedge clk);

        check(rx_n == N, "todos os bytes chegaram (nenhum perdido ou repetido)");
        bad = 0;
        for (i = 0; i < N; i = i + 1)
            if (rx_mem[i] !== pat(i)) bad = bad + 1;
        check(bad == 0, "ordem e valores corretos (inclusive apos a volta da FIFO)");
        check(frame_err == 0, "sem erro de quadro na linha serial");
        check(tx === 1'b1 && busy === 1'b0, "linha em repouso e entrada livre no fim");

        rx_n = 0;
        for (i = 0; i < 40; i = i + 1) push(8'hEE, lat);
        @(posedge clk); #1 rst = 1'b1;
        repeat (3) @(posedge clk);
        #1 rst = 1'b0;
        repeat (300) @(posedge clk);
        rx_n = 0;
        repeat (4000) @(posedge clk);
        check(rx_n == 0, "apos o reset a FIFO esta vazia (nada sai)");

        push(8'h5A, lat);
        repeat (600) @(posedge clk);
        check(rx_n == 1 && rx_mem[0] === 8'h5A, "transmite normalmente apos o reset");

        $display("");
        $display("[SIM] uart_tx_fifo_tb: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #10000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule
