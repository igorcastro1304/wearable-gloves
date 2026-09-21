`timescale 1ns/1ps

module debounce_tb;
    localparam integer CLK_FREQ = 100_000;
    localparam integer MS       = 1;
    localparam integer MAXC     = (CLK_FREQ / 1000) * MS;

    reg clk   = 1'b0;
    reg rst   = 1'b1;
    reg press = 1'b0;                 

    wire din_low  = ~press;           
    wire din_high =  press;

    wire pressed_low, rise_low, pressed_high, rise_high;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    always #5 clk = ~clk;

    debounce #(.CLK_FREQ(CLK_FREQ), .MS(MS), .ACTIVE_LOW(1)) dut_low (
        .clk(clk), .rst(rst), .din(din_low),
        .pressed(pressed_low), .pressed_rise(rise_low)
    );

    debounce #(.CLK_FREQ(CLK_FREQ), .MS(MS), .ACTIVE_LOW(0)) dut_high (
        .clk(clk), .rst(rst), .din(din_high),
        .pressed(pressed_high), .pressed_rise(rise_high)
    );

    integer rise_cnt     = 0;         
    integer fall_cnt     = 0;        
    reg     pressed_prev = 1'b0;
    reg     mismatch     = 1'b0;
    reg     mon_en       = 1'b0;

    always @(posedge clk) begin
        if (rise_low) rise_cnt = rise_cnt + 1;
        if (pressed_prev && !pressed_low) fall_cnt = fall_cnt + 1;
        pressed_prev = pressed_low;
        if (mon_en && (pressed_low !== pressed_high || rise_low !== rise_high))
            mismatch = 1'b1;
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

    task drive(input v);
        begin @(posedge clk); #1; press = v; end
    endtask

    task drive_mid(input v);
        begin @(posedge clk); #5; press = v; end
    endtask

    task wait_level(input v, input integer max, output integer n);
        begin
            n = 0;
            while (pressed_low !== v && n < max) begin
                @(posedge clk);
                n = n + 1;
            end
        end
    endtask

    integer lat;

    initial begin
        tick(4);
        @(posedge clk); #1 rst = 1'b0;
        tick(4);
        mon_en = 1'b1;

        check(pressed_low === 1'b0 && pressed_high === 1'b0 && rise_low === 1'b0,
              "apos o reset: pressed=0 e sem rise");

        rise_cnt = 0;  fall_cnt = 0;
        drive(1);  tick(MAXC / 3);  drive(0);
        tick(3 * MAXC);
        check(pressed_low === 1'b0 && rise_cnt == 0, "glitch curto de aperto ignorado");

        rise_cnt = 0;
        drive(1);  tick(10);
        drive(0);  tick(10);
        drive(1);  tick(10);
        drive(0);  tick(10);
        drive(1);                                 
        wait_level(1'b1, 3 * MAXC, lat);
        check(lat >= MAXC, "latencia do aperto >= tempo de debounce");
        check(lat <= MAXC + 6, "latencia do aperto proxima de MAXC");
        tick(20);
        check(rise_cnt == 1, "um unico pulso de rise, com 1 ciclo de largura");

        fall_cnt = 0;
        drive(0);  tick(MAXC / 3);  drive(1);
        tick(3 * MAXC);
        check(pressed_low === 1'b1 && fall_cnt == 0, "glitch curto de soltura ignorado");
        drive(0);
        wait_level(1'b0, 3 * MAXC, lat);
        check(lat >= MAXC && lat <= MAXC + 6, "latencia da soltura dentro do esperado");
        tick(10);
        check(fall_cnt == 1 && rise_cnt == 1, "soltar nao gera rise");

        drive(1);
        wait_level(1'b1, 3 * MAXC, lat);
        @(posedge clk); #1 rst = 1'b1;
        #1;
        check(pressed_low === 1'b0 && pressed_high === 1'b0, "reset limpa pressed imediatamente");
        tick(2);
        @(posedge clk); #1 rst = 1'b0;
        wait_level(1'b1, 3 * MAXC, lat);
        check(lat >= MAXC && lat <= MAXC + 8, "botao ainda pressionado e detectado de novo apos o reset");
        drive(0);
        wait_level(1'b0, 3 * MAXC, lat);
        tick(10);

        rise_cnt = 0;
        @(posedge clk); #1 rst = 1'b1;
        tick(3);
        @(posedge clk); #1 rst = 1'b0;
        tick(3 * MAXC);
        check(rise_cnt == 0 && pressed_low === 1'b0, "reset com botao solto: sem falso clique");

        drive_mid(1);
        wait_level(1'b1, 3 * MAXC, lat);
        check(lat >= MAXC && lat <= MAXC + 6, "entrada assincrona (meio do ciclo) tratada");
        drive_mid(0);
        wait_level(1'b0, 3 * MAXC, lat);
        check(lat >= MAXC && lat <= MAXC + 6, "soltura assincrona tratada");
        tick(10);

        check(!mismatch, "ACTIVE_LOW=1 e ACTIVE_LOW=0 equivalentes");

        $display("");
        $display("[SIM] debounce_tb: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $finish;
    end

    initial begin
        #2000000;
        $display("[TIMEOUT] simulacao travou");
        $finish;
    end
endmodule
