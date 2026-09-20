module i2c_master #(
    parameter CLK_DIV = 675
) (
    input wire clk,
    input wire rst,

    input wire [2:0] cmd,
    input wire start_cmd,
    input wire [7:0] tx_data,
    output reg [7:0] rx_data,
    output reg busy,
    output reg done,
    output reg ack_error,

    inout wire sda,
    inout wire scl
);
    localparam CMD_IDLE = 3'd0;
    localparam CMD_START = 3'd1;
    localparam CMD_WRITE = 3'd2;
    localparam CMD_READ_ACK = 3'd3;
    localparam CMD_READ_NACK = 3'd4;
    localparam CMD_STOP = 3'd5;
    localparam CMD_CHK_ACK = 3'd6;
    localparam CMD_SEND_ACK = 3'd7;

    reg sda_out_reg;
    reg scl_out_reg;

    reg read_send_nack;

    assign sda = (sda_out_reg == 1'b0) ? 1'b0 : 1'bz;
    assign scl = (scl_out_reg == 1'b0) ? 1'b0 : 1'bz;

    reg [2:0] sda_sync;
    reg [2:0] scl_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sda_sync <= 3'b111;
            scl_sync <= 3'b111;
        end else begin
            sda_sync <= {sda_sync[1:0], sda};
            scl_sync <= {scl_sync[1:0], scl};
        end
    end

    wire sda_filt = (sda_sync[2] & sda_sync[1]) | (sda_sync[1] & sda_sync[0]) | (sda_sync[2] & sda_sync[0]);
    wire scl_filt = (scl_sync[2] & scl_sync[1]) | (scl_sync[1] & scl_sync[0]) | (scl_sync[2] & scl_sync[0]);

    wire scl_stretched = (scl_out_reg == 1'b1 && scl_filt == 1'b0);

    reg [9:0] div_cnt;
    reg qbit;

    reg [3:0] state;
    reg [2:0] current_cmd;
    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;
    reg [1:0] qcnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt <= 0;
            qbit <= 0;
        end else begin
            qbit <= 0;

            if (scl_stretched) begin
                div_cnt <= div_cnt;
            end else if (state == 0) begin
                div_cnt <= 0;
            end else if (div_cnt == CLK_DIV - 1) begin
                div_cnt <= 0;
                qbit <= 1;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            scl_out_reg <= 1'b1;
            sda_out_reg <= 1'b1;
            busy <= 0;
            done <= 0;
            ack_error <= 0;
            qcnt <= 0;
            rx_data <= 8'h00;
            shift_reg <= 8'h00;
            bit_cnt <= 4'd0;
            current_cmd <= CMD_IDLE;
            read_send_nack <= 1'b0;
        end else begin
            done <= 0;

            if (state == 0) begin
                if (start_cmd) begin
                    busy <= 1;
                    current_cmd <= cmd;
                    shift_reg <= tx_data;
                    bit_cnt <= 7;
                    qcnt <= 0;

                    ack_error <= 0;
                    read_send_nack <= (cmd == CMD_READ_NACK);

                    state <= 1;
                end else begin
                    busy <= 0;
                end
            end else if (qbit) begin
                qcnt <= qcnt + 1;

                case (current_cmd)
                    CMD_START: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= 1;
                            scl_out_reg <= 1;
                        end

                        2'b01: begin
                            sda_out_reg <= 0;
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            sda_out_reg <= 0;
                            scl_out_reg <= 0;
                        end

                        2'b11: begin
                            state <= 0;
                            done <= 1;
                        end
                    endcase

                    CMD_WRITE: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= shift_reg[7];
                            scl_out_reg <= 0;
                        end

                        2'b01: begin
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            scl_out_reg <= 1;
                        end

                        2'b11: begin
                            scl_out_reg <= 0;

                            if (bit_cnt == 0) begin
                                current_cmd <= CMD_CHK_ACK;
                                qcnt <= 0;
                            end else begin
                                shift_reg <= {shift_reg[6:0], 1'b0};
                                bit_cnt <= bit_cnt - 1;
                                qcnt <= 0;
                            end
                        end
                    endcase

                    CMD_CHK_ACK: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= 1;
                            scl_out_reg <= 0;
                        end

                        2'b01: begin
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            ack_error <= sda_filt;
                            scl_out_reg <= 1;
                        end

                        2'b11: begin
                            scl_out_reg <= 0;
                            state <= 0;
                            done <= 1;
                        end
                    endcase

                    CMD_READ_ACK, CMD_READ_NACK: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= 1;
                            scl_out_reg <= 0;
                        end

                        2'b01: begin
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            shift_reg <= {shift_reg[6:0], sda_filt};
                            scl_out_reg <= 1;
                        end

                        2'b11: begin
                            scl_out_reg <= 0;

                            if (bit_cnt == 0) begin
                                current_cmd <= CMD_SEND_ACK;
                                rx_data <= shift_reg;
                                qcnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                qcnt <= 0;
                            end
                        end
                    endcase

                    CMD_SEND_ACK: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= read_send_nack ? 1'b1 : 1'b0;
                            scl_out_reg <= 0;
                        end

                        2'b01: begin
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            scl_out_reg <= 1;
                        end

                        2'b11: begin
                            scl_out_reg <= 0;
                            sda_out_reg <= 1;
                            state <= 0;
                            done <= 1;
                        end
                    endcase

                    CMD_STOP: case (qcnt)
                        2'b00: begin
                            sda_out_reg <= 0;
                            scl_out_reg <= 0;
                        end

                        2'b01: begin
                            sda_out_reg <= 0;
                            scl_out_reg <= 1;
                        end

                        2'b10: begin
                            sda_out_reg <= 1;
                            scl_out_reg <= 1;
                        end

                        2'b11: begin
                            state <= 0;
                            done <= 1;
                        end
                    endcase
                endcase
            end
        end
    end
endmodule