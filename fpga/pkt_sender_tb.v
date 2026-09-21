`timescale 1ns/1ps

module pkt_sender_tb;
    localparam integer CLK_FREQ = 100_000_000;
    localparam integer BAUD     = 5_000_000;
    localparam integer BIT_NS   = 200;

    reg clk = 1'b0;
    reg rst = 1'b1;

    reg               mv_pulse = 0;
    reg signed [31:0] mv_x = 0, mv_y = 0;
    reg               btn_pulse = 0;
    reg [1:0]         btn_state = 0;
    reg               hand_pulse = 0;
    reg               hand_state = 0;
    reg               dpi_pulse = 0;
    wire              tx;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    pkt_sender #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
        .clk(clk), .rst(rst),
        .mv_pulse(mv_pulse), .mv_x(mv_x), .mv_y(mv_y),
        .btn_pulse(btn_pulse), .btn_state(btn_state),
        .hand_pulse(hand_pulse), .hand_state(hand_state),
        .dpi_pulse(dpi_pulse),
        .tx(tx)
    );

    reg [7:0] rx_mem [0:255];
    integer   rx_n = 0;
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
            rx_mem[rx_n] = rxb;
            rx_n = rx_n + 1;
            #(BIT_NS / 2);
        end
    end

    function [7:0] crc8_byte(input [7:0] crc_in, input [7:0] d);
        integer i;
        reg [7:0] c;
        begin
            c = crc_in ^ d;
            for (i = 0; i < 8; i = i + 1)
                c = c[7] ? ({c[6:0], 1'b0} ^ 8'h07) : {c[6:0], 1'b0};
            crc8_byte = c;
        end
    endfunction

    task check_frame(input integer base, input [7:0] ptype, input [7:0] plen, input [63:0] pl,
                     input [8*12-1:0] name);
        reg [7:0] c;
        integer i;
        reg ok;
        begin
            ok = 1'b1;
            if (rx_mem[base]     !== 8'hAA)  ok = 1'b0;
            if (rx_mem[base + 1] !== ptype)  ok = 1'b0;
            if (rx_mem[base + 2] !== plen)   ok = 1'b0;
            c = crc8_byte(8'h00, ptype);
            c = crc8_byte(c, plen);
            for (i = 0; i < plen; i = i + 1) begin
                if (rx_mem[base + 3 + i] !== pl[8*i +: 8]) ok = 1'b0;
                c = crc8_byte(c, pl[8*i +: 8]);
            end
            if (rx_mem[base + 3 + plen] !== c) ok = 1'b0;

            if (ok) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] quadro %0s", name);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] quadro %0s (base=%0d)", name, base);
            end
        end
    endtask

    task pulse_wait;
        begin
            @(posedge clk);
            #1;
            mv_pulse = 0; btn_pulse = 0; hand_pulse = 0; dpi_pulse = 0;
            #60000;
        end
    endtask

    initial begin
        #100 rst = 1'b0;
        #100;

        $display("--- Teste 1: lateralidade (canhoto) ---");
        rx_n = 0;
        @(posedge clk); #1; hand_state = 1'b1; hand_pulse = 1'b1;
        pulse_wait;
        if (rx_n != 5) begin fail_cnt = fail_cnt + 1; $display("[FAIL] esperados 5 bytes, recebidos %0d", rx_n); end
        else check_frame(0, 8'h48, 8'd1, 64'h01, "hand=1");

        $display("--- Teste 2: botao direito pressionado ---");
        rx_n = 0;
        @(posedge clk); #1; btn_state = 2'b10; btn_pulse = 1'b1;
        pulse_wait;
        if (rx_n != 5) begin fail_cnt = fail_cnt + 1; $display("[FAIL] esperados 5 bytes, recebidos %0d", rx_n); end
        else check_frame(0, 8'h42, 8'd1, 64'h02, "btn=10");

        $display("--- Teste 3: clique de DPI ---");
        rx_n = 0;
        @(posedge clk); #1; dpi_pulse = 1'b1;
        pulse_wait;
        if (rx_n != 5) begin fail_cnt = fail_cnt + 1; $display("[FAIL] esperados 5 bytes, recebidos %0d", rx_n); end
        else check_frame(0, 8'h44, 8'd1, 64'h01, "dpi");

        $display("--- Teste 4: movimento (x=1000, y=-1000) ---");
        rx_n = 0;
        @(posedge clk); #1; mv_x = 32'sd1000; mv_y = -32'sd1000; mv_pulse = 1'b1;
        pulse_wait;
        if (rx_n != 12) begin fail_cnt = fail_cnt + 1; $display("[FAIL] esperados 12 bytes, recebidos %0d", rx_n); end
        else check_frame(0, 8'h4D, 8'd8, {32'hFFFFFC18, 32'h000003E8}, "move");

        $display("--- Teste 5: todos os eventos juntos (prioridade D > B > H > M) ---");
        rx_n = 0;
        @(posedge clk); #1;
        mv_x = 32'sd5; mv_y = -32'sd7;  btn_state = 2'b01;  hand_state = 1'b0;
        mv_pulse = 1'b1; btn_pulse = 1'b1; hand_pulse = 1'b1; dpi_pulse = 1'b1;
        @(posedge clk); #1;
        mv_pulse = 0; btn_pulse = 0; hand_pulse = 0; dpi_pulse = 0;
        #200000;
        if (rx_n != 27) begin fail_cnt = fail_cnt + 1; $display("[FAIL] esperados 27 bytes, recebidos %0d", rx_n); end
        else begin
            check_frame(0,  8'h44, 8'd1, 64'h01, "prio D");
            check_frame(5,  8'h42, 8'd1, 64'h01, "prio B");
            check_frame(10, 8'h48, 8'd1, 64'h00, "prio H");
            check_frame(15, 8'h4D, 8'd8, {32'hFFFFFFF9, 32'h00000005}, "prio M");
        end

        $display("");
        $display("[SIM] RESULTADO: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #2000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule