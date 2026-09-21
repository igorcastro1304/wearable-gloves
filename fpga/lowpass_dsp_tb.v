`timescale 1ns/1ps

module lowpass_dsp_tb #(parameter USE_DSP = 0);
    reg               clk = 1'b0;
    reg               rst = 1'b1;
    reg               in_valid = 1'b0;
    reg signed [15:0] x = 16'sd0;
    reg        [8:0]  alpha = 9'd64;
    wire signed [15:0] y;
    wire               out_valid;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    lowpass_dsp #(.USE_DSP(USE_DSP)) dut (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .x(x), .alpha(alpha), .y(y), .out_valid(out_valid)
    );

    integer y_ref;
    reg     seeded_ref;
    integer diff_i, prod_i, step_i;

    task ref_update(input integer xv, input integer a);
        begin
            if (!seeded_ref) begin
                y_ref = xv;
                seeded_ref = 1'b1;
            end else begin
                diff_i = xv - y_ref;
                prod_i = diff_i * a;
                step_i = (prod_i + 128) >>> 8;
                y_ref  = y_ref + step_i;
            end
        end
    endtask

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

    integer mism;
    integer prev_y;
    integer overshoot;
    integer nonmono;

    task send(input integer xv, input integer a);
        begin
            ref_update(xv, a);
            @(posedge clk); #1;
            x = xv; alpha = a; in_valid = 1'b1;
            @(posedge clk); #1;
            in_valid = 1'b0;
            repeat (5) @(posedge clk);
            #1;
            if (y !== y_ref) mism = mism + 1;
        end
    endtask

    integer i, n, w;

    initial begin
        seeded_ref = 1'b0;  y_ref = 0;  mism = 0;
        repeat (4) @(posedge clk);
        @(posedge clk); #1 rst = 1'b0;
        repeat (3) @(posedge clk);

        check(y === 16'sd0 && out_valid === 1'b0, "apos o reset: y=0 e out_valid=0");

        mism = 0;
        send(5000, 64);
        check(y === 16'sd5000 && mism == 0, "primeira amostra semeia y (sem transitorio)");

        mism = 0; overshoot = 0; nonmono = 0; prev_y = y;
        for (i = 0; i < 40; i = i + 1) begin
            send(8000, 64);
            if (y > 8000) overshoot = overshoot + 1;
            if (y < prev_y) nonmono = nonmono + 1;
            prev_y = y;
        end
        check(mism == 0, "degrau +8000: igual ao modelo em todas as amostras");
        check(overshoot == 0 && nonmono == 0, "sem sobressinal e monotonico (positivo)");
        check(y >= 7997 && y <= 8000, "converge para perto de 8000 (dentro de 3 LSB)");

        mism = 0; overshoot = 0; nonmono = 0; prev_y = y;
        for (i = 0; i < 80; i = i + 1) begin
            send(-8000, 64);
            if (y < -8000) overshoot = overshoot + 1;
            if (y > prev_y) nonmono = nonmono + 1;
            prev_y = y;
        end
        check(mism == 0, "degrau -8000: igual ao modelo em todas as amostras");
        check(overshoot == 0 && nonmono == 0, "sem sobressinal e monotonico (negativo)");
        check(y <= -7997 && y >= -8000, "converge para perto de -8000 (dentro de 3 LSB)");

        mism = 0;
        send(1234, 256);
        check(y === 16'sd1234 && mism == 0, "alpha = 256: saida = entrada");
        send(-32768, 256);
        check(y === -16'sd32768 && mism == 0, "alpha = 256 com o menor valor de 16 bits");
        send(32767, 256);
        check(y === 16'sd32767 && mism == 0, "alpha = 256 com o maior valor de 16 bits");
        send(-500, 0);
        check(y === 16'sd32767 && mism == 0, "alpha = 0: saida congelada");

        @(posedge clk); #1; x = 16'sd100; alpha = 9'd128; in_valid = 1'b1;
        ref_update(100, 128);
        @(posedge clk); #1; in_valid = 1'b0;
        n = 0;
        while (out_valid !== 1'b1 && n < 20) begin @(posedge clk); n = n + 1; end
        check(n == 3, "out_valid sobe 3 ciclos depois da amostra");
        w = 1;
        @(posedge clk);
        while (out_valid === 1'b1 && w < 10) begin w = w + 1; @(posedge clk); end
        check(w == 1, "out_valid dura 1 ciclo");
        #1;
        check(y === y_ref, "y so muda junto com out_valid (valor final correto)");

        @(posedge clk); #1; x = 16'sd7000; alpha = 9'd64; in_valid = 1'b1;
        @(posedge clk); #1; in_valid = 1'b0;
        @(posedge clk); #1; rst = 1'b1;
        repeat (2) @(posedge clk);
        #1 rst = 1'b0;
        repeat (6) @(posedge clk);
        check(y === 16'sd0 && out_valid === 1'b0, "reset descarta a amostra em voo");
        seeded_ref = 1'b0;  mism = 0;
        send(-321, 64);
        check(y === -16'sd321 && mism == 0, "apos o reset a primeira amostra semeia de novo");

        $display("");
        $display("[SIM] lowpass_dsp_tb: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #5000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule
