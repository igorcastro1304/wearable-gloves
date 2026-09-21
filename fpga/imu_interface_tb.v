`timescale 1ns/1ps

module imu_interface_tb;
    reg clk;
    reg rst;

    wire sda;
    wire scl;
    wire signed [15:0] accel_x;
    wire signed [15:0] accel_y;

    wire data_ready;
    wire data_valid;
    wire data_error;

    reg force_fail;
    reg force_sensor_reset;

    reg signed [15:0] last_valid_x;
    reg signed [15:0] last_valid_y;

    reg saw_data_ready_during_error;
    reg saw_error;
    reg saw_recovery;

    reg [31:0] timeout_cnt;
    integer i;

    localparam signed [15:0] EXP_X = 16'sd8096; 
    localparam signed [15:0] EXP_Y = -16'sd8112;

    assign (weak1, weak0) sda = 1'b1;
    assign (weak1, weak0) scl = 1'b1;

    imu_interface dut (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .scl(scl),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .data_ready(data_ready),
        .data_valid(data_valid),
        .data_error(data_error)
    );

    mpu6050_mock u_mock (
        .sda(sda),
        .scl(scl),
        .force_fail(force_fail),
        .force_sensor_reset(force_sensor_reset)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("imu_interface_tb.vcd");
        $dumpvars(0, imu_interface_tb);

        clk = 0;
        rst = 1;

        force_fail = 0;
        force_sensor_reset = 0;

        last_valid_x = 0;
        last_valid_y = 0;

        saw_data_ready_during_error = 0;
        saw_error = 0;
        saw_recovery = 0;

        #100;
        rst = 0;

        $display("");
        $display("--- TESTE 1: Leitura normal ---");

        timeout_cnt = 0;

        while (!data_ready && timeout_cnt < 1000000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end

        if (timeout_cnt >= 1000000) begin
            $display("[TIMEOUT] Nenhuma leitura válida foi produzida.");
            $finish;
        end else begin
            $display("[SUCCESS] data_ready recebido.");
            $display("[DATA] accel_x = %d", accel_x);
            $display("[DATA] accel_y = %d", accel_y);
            $display("[DATA] data_valid = %b", data_valid);

            if (data_valid !== 1'b1) begin
                $display("[FAIL] data_ready ocorreu, mas data_valid não está ativo!");
            end
            else if (accel_x !== EXP_X || accel_y !== EXP_Y) begin
                $display("[FAIL] Dados incorretos: X=%d Y=%d", accel_x, accel_y);
            end else begin
                $display("[PASS] Primeira leitura válida.");

                last_valid_x = accel_x;
                last_valid_y = accel_y;
            end
        end

        $display("");
        $display("--- TESTE 2: Sensor desconectado / NACK ---");

        force_fail = 1;

        saw_error = 0;
        saw_data_ready_during_error = 0;

        for (i = 0; i < 200000; i = i + 1) begin
            @(posedge clk);
            if (data_error && !saw_error) begin
                saw_error = 1;
                $display("[PASS] data_error detectou a falha do sensor.");

                if (data_valid !== 1'b0) begin
                    $display("[FAIL] data_valid continua ativo durante erro!");
                end else begin
                    $display("[PASS] data_valid foi desativado.");
                end
            end

            if (data_ready) begin
                saw_data_ready_during_error = 1;
                $display("[FAIL] data_ready apareceu enquanto o sensor estava offline!");
            end
        end

        if (!saw_error) begin
            $display("[FAIL] Nenhum data_error foi gerado para o NACK.");
        end

        if (saw_data_ready_during_error) begin
            $display("[FAIL] A interface publicou dados inválidos durante a falha.");
        end else begin
            $display("[PASS] Nenhuma leitura foi publicada durante a falha.");
        end

        if (accel_x !== last_valid_x || accel_y !== last_valid_y) begin
            $display("[FAIL] accel_x/y foram alterados durante a falha!");
        end else begin
            $display("[PASS] Última amostra válida foi preservada.");
        end

        force_fail = 0;

        $display("");
        $display("--- TESTE 3: Recuperação após NACK ---");

        timeout_cnt = 0;

        while (!data_ready && timeout_cnt < 1000000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end

        if (timeout_cnt >= 1000000) begin
            $display("[TIMEOUT] Interface não se recuperou do NACK.");
            $finish;
        end else begin
            if (data_valid === 1'b1 && accel_x === EXP_X && accel_y === EXP_Y) begin
                $display("[PASS] Interface se recuperou automaticamente.");
            end else begin
                $display("[FAIL] Recuperação produziu dados inválidos.");
            end
        end

        $display("");
        $display("--- TESTE 4: Reset do sensor / SLEEP ---");

        saw_error = 0;
        saw_recovery = 0;

        force_sensor_reset = 1;
        #100;
        force_sensor_reset = 0;

        timeout_cnt = 0;

        while (!(saw_error && saw_recovery) && timeout_cnt < 2000000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;

            if (data_error && !saw_error) begin
                saw_error = 1;
                $display("[PASS] Reset/SLEEP do sensor foi detectado.");

                if (data_valid !== 1'b0) begin
                    $display("[FAIL] data_valid permaneceu ativo após reset!");
                end else begin
                    $display("[PASS] data_valid foi invalidado.");
                end
            end

            if (data_ready && saw_error && !saw_recovery) begin
                if (data_valid === 1'b1 && accel_x === EXP_X && accel_y === EXP_Y) begin
                    saw_recovery = 1;
                    $display("[PASS] Sensor foi reconfigurado e voltou a fornecer dados.");
                    $display("[DATA] accel_x = %d", accel_x);
                    $display("[DATA] accel_y = %d", accel_y);
                end else begin
                    $display("[FAIL] Recuperação retornou dados inválidos.");
                end
            end
        end

        if (!saw_error || !saw_recovery) begin
            $display("[TIMEOUT] Sensor não completou detecção/recuperação do reset.");
        end

        $display("");
        $display("==========================================================================");
        $display("[SIM] RESULTADO FINAL");
        $display("==========================================================================");

        if (!saw_error) begin
            $display("[FAIL] Reset do sensor não gerou data_error.");
        end else begin
            $display("[PASS] Reset do sensor gerou alerta.");
        end

        if (!saw_recovery) begin
            $display("[FAIL] Sensor não voltou a fornecer dados válidos.");
        end else begin
            $display("[PASS] Sensor recuperado.");
        end

        if (data_valid !== 1'b1) begin
            $display("[FAIL] Estado final deveria ser data_valid = 1.");
        end else begin
            $display("[PASS] Estado final data_valid = 1.");
        end

        $display("");
        $display("==========================================================================");
        $display("[SIM] FIM DOS TESTES");
        $display("==========================================================================");

        $finish;
    end
endmodule

module mpu6050_mock (
    inout wire sda,
    input wire scl,
    input wire force_fail,
    input wire force_sensor_reset
);
    localparam [6:0] SLAVE_ADDR = 7'h68;

    localparam [2:0]
        S_IDLE = 3'd0,
        S_ADDR = 3'd1,
        S_ADDR_ACK = 3'd2,
        S_WRITE= 3'd3,
        S_WRITE_ACK = 3'd4,
        S_READ = 3'd5,
        S_READ_ACK = 3'd6;

    reg [7:0] memory [0:255];
    reg [7:0] reg_ptr;
    reg reg_ptr_set;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg is_read;
    reg master_nack;
    reg sda_low;

    assign sda = sda_low ? 1'b0 : 1'bz;

    task init_memory;
        begin
            memory[8'h3B] = 8'h1F;
            memory[8'h3C] = 8'hA0;
            memory[8'h3D] = 8'hE0;
            memory[8'h3E] = 8'h50;
            memory[8'h6B] = 8'h40;
            reg_ptr = 8'h00;
            reg_ptr_set = 1'b0;
        end
    endtask

    task load_tx_byte;
        reg [7:0] value;
        begin
            value = memory[reg_ptr];
            if (memory[8'h6B][6] && reg_ptr >= 8'h3B && reg_ptr <= 8'h48)
                value = 8'h00; 

            tx_shift = {value[6:0], 1'b0};
            sda_low = ~value[7];           
            reg_ptr = reg_ptr + 8'd1;
            bit_cnt = 4'd0;
        end
    endtask

    initial begin
        sda_low = 1'b0;
        state = S_IDLE;
        bit_cnt = 4'd0;
        rx_shift = 8'h00;
        tx_shift = 8'h00;
        is_read = 1'b0;
        master_nack = 1'b1;
        init_memory;
    end

    always @(posedge force_sensor_reset) init_memory;

    always @(posedge force_fail) begin
        sda_low = 1'b0;
        state   = S_IDLE;
    end

    always @(negedge sda) begin
        if (scl === 1'b1 && !force_fail) begin
            state = S_ADDR;
            bit_cnt = 4'd0;
            rx_shift = 8'h00;
            reg_ptr_set = 1'b0;
            sda_low = 1'b0;
        end
    end

    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state = S_IDLE;
            reg_ptr_set = 1'b0;
            sda_low = 1'b0;
        end
    end

    always @(posedge scl) begin
        if (!force_fail) begin
            case (state)
                S_ADDR, S_WRITE: begin
                    rx_shift = {rx_shift[6:0], sda};
                    bit_cnt  = bit_cnt + 4'd1;
                end
                S_READ: bit_cnt = bit_cnt + 4'd1;
                S_READ_ACK: master_nack = sda;
            endcase
        end
    end

    always @(negedge scl) begin
        if (!force_fail) begin
            case (state)
                S_ADDR: if (bit_cnt == 4'd8) begin
                    if (rx_shift[7:1] == SLAVE_ADDR) begin
                        is_read = rx_shift[0];
                        sda_low = 1'b1;            
                        state   = S_ADDR_ACK;
                    end else begin
                        state = S_IDLE;            
                    end
                end

                S_ADDR_ACK: begin
                    sda_low = 1'b0;
                    if (is_read) begin
                        load_tx_byte;
                        state = S_READ;
                    end else begin
                        bit_cnt = 4'd0;
                        state   = S_WRITE;
                    end
                end

                S_WRITE: if (bit_cnt == 4'd8) begin
                    if (!reg_ptr_set) begin
                        reg_ptr = rx_shift;
                        reg_ptr_set = 1'b1;
                    end else begin
                        memory[reg_ptr] = rx_shift;
                        reg_ptr = reg_ptr + 8'd1;
                    end
                    sda_low = 1'b1;                
                    state   = S_WRITE_ACK;
                end

                S_WRITE_ACK: begin
                    sda_low = 1'b0;
                    bit_cnt = 4'd0;
                    state   = S_WRITE;
                end

                S_READ: begin
                    if (bit_cnt == 4'd8) begin
                        sda_low = 1'b0;           
                        state   = S_READ_ACK;
                    end else begin
                        sda_low  = ~tx_shift[7];
                        tx_shift = {tx_shift[6:0], 1'b0};
                    end
                end

                S_READ_ACK: begin
                    if (master_nack) begin
                        sda_low = 1'b0;
                        state   = S_IDLE;
                    end else begin
                        load_tx_byte;
                        state = S_READ;
                    end
                end
            endcase
        end
    end
endmodule