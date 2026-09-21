`timescale 1ns/1ps

module uart_tx_tb;
    localparam integer CLK_FREQ = 100_000_000;
    localparam integer BAUD     = 5_000_000;
    localparam integer DIV      = CLK_FREQ / BAUD;
    localparam integer BIT_NS   = DIV * 10;   

    reg        clk   = 1'b0;
    reg        rst   = 1'b1;
    reg        start = 1'b0;
    reg  [7:0] data  = 8'h00;
    wire       tx, busy, done;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
        .clk(clk), .rst(rst), .start(start), .data(data),
        .tx(tx), .busy(busy), .done(done)
    );

    reg [7:0] rx_mem [0:63];
    integer   rx_n      = 0;
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

    integer busy_cnt = 0;
    integer done_cnt = 0;
    reg     both_err = 1'b0;

    always @(posedge clk) begin
        if (busy) busy_cnt = busy_cnt + 1;
        if (done) done_cnt = done_cnt + 1;
        if (busy && done) both_err = 1'b1;
    end

    integer n_edges  = 0;
    integer bad_gaps = 0;
    integer last_t   = 0;
    reg     capture  = 1'b0;

    always @(tx) begin
        if (capture) begin
            if (n_edges > 0 && ($time - last_t) != BIT_NS) bad_gaps = bad_gaps + 1;
            last_t  = $time;
            n_edges = n_edges + 1;
        end
    end

    task check(input ok, input [8*64-1:0] name);
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

    task tick(input integer n);
        begin repeat (n) @(posedge clk); end
    endtask

    task pulse_start(input [7:0] d);
        begin
            @(posedge clk); #1;
            data  = d;
            start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
        end
    endtask

    task wait_done;     
        integer n;
        begin
            n = 0;
            while (done_cnt == 0 && n < 2000) begin
                @(posedge clk);
                n = n + 1;
            end
            tick(3);                
        end
    endtask

    task clear_counters;
        begin
            busy_cnt = 0;  done_cnt = 0;  both_err = 1'b0;
        end
    endtask

    task send_and_check(input [7:0] d, input [8*64-1:0] name);
        integer before;
        begin
            before = rx_n;
            clear_counters;
            pulse_start(d);
            wait_done;
            check(rx_n == before + 1 && rx_mem[before] === d, name);
        end
    endtask

    initial begin
        tick(4);
        @(posedge clk); #1 rst = 1'b0;
        tick(4);

        check(tx === 1'b1 && busy === 1'b0 && done === 1'b0, "ocioso: tx=1, busy=0, done=0");

        clear_counters;  n_edges = 0;  bad_gaps = 0;  frame_err = 0;  capture = 1'b1;
        pulse_start(8'h55);
        wait_done;
        capture = 1'b0;
        check(rx_n == 1 && rx_mem[0] === 8'h55,   "0x55 recebido corretamente");
        check(frame_err == 0,                     "bit de parada = 1");
        check(n_edges == 10 && bad_gaps == 0,     "periodo de bit = DIV ciclos (baud correto)");
        check(busy_cnt == 10 * DIV,               "busy dura 10 bits (10*DIV ciclos)");
        check(done_cnt == 1,                      "done e um pulso de 1 ciclo");
        check(!both_err,                          "busy e done nunca juntos");
        check(tx === 1'b1 && busy === 1'b0,       "volta ao repouso apos o quadro");

        send_and_check(8'h01, "0x01 (so o bit 0)");
        send_and_check(8'h80, "0x80 (so o bit 7)");
        send_and_check(8'h00, "0x00 (todos os bits 0)");
        send_and_check(8'hFF, "0xFF (todos os bits 1)");
        send_and_check(8'hA3, "0xA3 (padrao misto)");

        rx_n = 0;  clear_counters;
        pulse_start(8'h3C);
        tick(DIV * 4);     
        pulse_start(8'hC3);
        wait_done;
        tick(DIV * 15);    
        check(rx_n == 1 && rx_mem[0] === 8'h3C, "start ignorado durante a transmissao");

        rx_n = 0;  clear_counters;
        @(posedge clk); #1;  data = 8'h96;  start = 1'b1;
        @(posedge clk); #1;  start = 1'b0;  data  = 8'h69;   
        wait_done;
        check(rx_n == 1 && rx_mem[0] === 8'h96, "dado travado no start (mudanca posterior ignorada)");

        rx_n = 0;  frame_err = 0;  clear_counters;
        pulse_start(8'h11);
        while (done_cnt == 0) @(posedge clk);       
        pulse_start(8'h22);                         
        tick(DIV * 12);
        check(rx_n == 2 && rx_mem[0] === 8'h11 && rx_mem[1] === 8'h22, "bytes seguidos sem perda");
        check(frame_err == 0, "sem erro de quadro nos bytes seguidos");

        pulse_start(8'hAA);
        tick(DIV * 3);
        @(posedge clk); #1 rst = 1'b1;
        #1;
        check(tx === 1'b1 && busy === 1'b0 && done === 1'b0, "reset no meio: linha volta a 1 e busy=0");
        tick(2);
        @(posedge clk); #1 rst = 1'b0;
        tick(DIV * 12);                
        rx_n = 0;  frame_err = 0;  clear_counters;
        pulse_start(8'h5A);
        wait_done;
        check(rx_n == 1 && rx_mem[0] === 8'h5A, "recupera e transmite normalmente apos o reset");

        $display("");
        $display("[SIM] uart_tx_tb: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #2000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule
