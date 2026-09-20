module imu_interface (
    input wire clk,
    input wire rst,

    inout wire sda,
    inout wire scl,

    output reg signed [15:0] accel_x,
    output reg signed [15:0] accel_y,

    output reg data_ready,
    output reg data_valid,
    output reg data_error
);
    localparam SLAVE_ADDR_WRITE = 8'hd0;
    localparam SLAVE_ADDR_READ = 8'hd1;

    localparam CMD_IDLE = 3'd0;
    localparam CMD_START = 3'd1;
    localparam CMD_WRITE = 3'd2;
    localparam CMD_READ_ACK = 3'd3;
    localparam CMD_READ_NACK = 3'd4;
    localparam CMD_STOP = 3'd5;

    reg [2:0] i2c_cmd;
    reg i2c_start;
    reg [7:0] i2c_tx_data;

    wire [7:0] i2c_rx_data;
    wire i2c_busy;
    wire i2c_done;
    wire ack_error;

    i2c_master u_i2c (
        .clk(clk),
        .rst(rst),
        .cmd(i2c_cmd),
        .start_cmd(i2c_start),
        .tx_data(i2c_tx_data),
        .rx_data(i2c_rx_data),
        .busy(i2c_busy),
        .done(i2c_done),
        .ack_error(ack_error),
        .sda(sda),
        .scl(scl)
    );

    localparam [5:0]
        ST_INIT_START = 6'd0,
        ST_INIT_ADDR = 6'd1,
        ST_INIT_REG = 6'd2,
        ST_INIT_VALUE = 6'd3,
        ST_INIT_STOP = 6'd4,

        ST_READ_START = 6'd5,
        ST_READ_ADDR = 6'd6,
        ST_READ_REG = 6'd7,
        ST_READ_STOP1 = 6'd8,
        ST_READ_START2 = 6'd9,
        ST_READ_ADDR2 = 6'd10,
        ST_READ_XH = 6'd11,
        ST_READ_XL = 6'd12,
        ST_READ_YH = 6'd13,
        ST_READ_YL = 6'd14,
        ST_READ_STOP2 = 6'd15,
        ST_READ_FINISH = 6'd16,

        ST_CHECK_START = 6'd17,
        ST_CHECK_ADDR  = 6'd18,
        ST_CHECK_REG = 6'd19,
        ST_CHECK_STOP1 = 6'd20,
        ST_CHECK_START2 = 6'd21,
        ST_CHECK_ADDR2 = 6'd22,
        ST_CHECK_READ = 6'd23,
        ST_CHECK_STOP2 = 6'd24,

        ST_ERR_STOP = 6'd25;

    reg [5:0] step;
    reg [7:0] buffer_x_h, buffer_x_l, buffer_y_h, buffer_y_l;

    reg [7:0] power_mgmt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            step <= ST_INIT_START;
            i2c_cmd <= CMD_IDLE;
            i2c_start <= 1'b0;
            i2c_tx_data <= 8'h00;

            buffer_x_h <= 8'h00;
            buffer_x_l <= 8'h00;
            buffer_y_h <= 8'h00;
            buffer_y_l <= 8'h00;

            power_mgmt <= 8'h00;

            accel_x <= 16'sd0;
            accel_y <= 16'sd0;

            data_ready <= 1'b0;
            data_valid <= 1'b0;
            data_error <= 1'b0;
        end else begin
            i2c_start <= 1'b0;
            data_ready <= 1'b0;
            data_error <= 1'b0;

            if (i2c_done) begin
                if (ack_error) begin
                    data_valid <= 1'b0;
                    data_error <= 1'b1;

                    i2c_cmd <= CMD_STOP;
                    i2c_start <= 1'b1;

                    step <= ST_ERR_STOP;
                end else begin
                    case (step)
                        ST_ERR_STOP: begin
                            step <= ST_INIT_START;
                        end

                        ST_INIT_START: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= SLAVE_ADDR_WRITE;
                            i2c_start <= 1'b1;

                            step <= ST_INIT_ADDR;
                        end

                        ST_INIT_ADDR: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= 8'h6B;
                            i2c_start <= 1'b1;

                            step <= ST_INIT_REG;
                        end

                        ST_INIT_REG: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= 8'h00;
                            i2c_start <= 1'b1;

                            step <= ST_INIT_VALUE;
                        end

                        ST_INIT_VALUE: begin
                            i2c_cmd <= CMD_STOP;
                            i2c_start <= 1'b1;

                            step <= ST_INIT_STOP;
                        end

                        ST_INIT_STOP: begin
                            step <= ST_READ_START;
                        end

                        ST_READ_START: begin
                            buffer_x_h <= 8'h00;
                            buffer_x_l <= 8'h00;
                            buffer_y_h <= 8'h00;
                            buffer_y_l <= 8'h00;


                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= SLAVE_ADDR_WRITE;
                            i2c_start <= 1'b1;

                            step <= ST_READ_ADDR;
                        end

                        ST_READ_ADDR: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= 8'h3B;
                            i2c_start <= 1'b1;

                            step <= ST_READ_REG;
                        end

                        ST_READ_REG: begin
                            i2c_cmd <= CMD_STOP;
                            i2c_start <= 1'b1;

                            step <= ST_READ_STOP1;
                        end

                        ST_READ_STOP1: begin
                            i2c_cmd <= CMD_START;
                            i2c_start <= 1'b1;

                            step <= ST_READ_START2;
                        end

                        ST_READ_START2: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= SLAVE_ADDR_READ;
                            i2c_start <= 1'b1;

                            step <= ST_READ_ADDR2;
                        end

                        ST_READ_ADDR2: begin
                            i2c_cmd <= CMD_READ_ACK;
                            i2c_start <= 1'b1;

                            step <= ST_READ_XH;
                        end

                        ST_READ_XH: begin
                            buffer_x_h <= i2c_rx_data;

                            i2c_cmd <= CMD_READ_ACK;
                            i2c_start <= 1'b1;

                            step <= ST_READ_XL;
                        end

                        ST_READ_XL: begin
                            buffer_x_l <= i2c_rx_data;

                            i2c_cmd <= CMD_READ_ACK;
                            i2c_start <= 1'b1;

                            step <= ST_READ_YH;
                        end

                        ST_READ_YH: begin
                            buffer_y_h <= i2c_rx_data;

                            i2c_cmd <= CMD_READ_NACK;
                            i2c_start <= 1'b1;

                            step <= ST_READ_YL;
                        end

                        ST_READ_YL: begin
                            buffer_y_l <= i2c_rx_data;

                            i2c_cmd <= CMD_STOP;
                            i2c_start <= 1'b1;

                            step <= ST_READ_STOP2;
                        end

                        ST_READ_STOP2: begin
                            step <= ST_CHECK_START;
                        end

                        ST_CHECK_START: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= SLAVE_ADDR_WRITE;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_ADDR;
                        end

                        ST_CHECK_ADDR: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= 8'h6B;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_REG;
                        end

                        ST_CHECK_REG: begin
                            i2c_cmd <= CMD_STOP;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_STOP1;
                        end

                        ST_CHECK_STOP1: begin
                            i2c_cmd <= CMD_START;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_START2;
                        end

                        ST_CHECK_START2: begin
                            i2c_cmd <= CMD_WRITE;
                            i2c_tx_data <= SLAVE_ADDR_READ;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_ADDR2;
                        end

                        ST_CHECK_ADDR2: begin
                            i2c_cmd <= CMD_READ_NACK;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_READ;
                        end

                        ST_CHECK_READ: begin
                            power_mgmt <= i2c_rx_data;

                            i2c_cmd <= CMD_STOP;
                            i2c_start <= 1'b1;

                            step <= ST_CHECK_STOP2;
                        end

                        ST_CHECK_STOP2: begin
                            if (power_mgmt[6]) begin
                                data_valid <= 1'b0;
                                data_error <= 1'b1;

                                step <= ST_INIT_START;
                            end else begin
                                accel_x <= {buffer_x_h, buffer_x_l};
                                accel_y <= {buffer_y_h, buffer_y_l};

                                data_valid <= 1'b1;
                                data_ready <= 1'b1;

                                step <= ST_READ_START;
                            end
                        end

                        default: begin
                            step <= ST_INIT_START;
                        end

                    endcase
                end
            end

            else if (!i2c_busy && !i2c_start) begin
                case (step)
                    ST_INIT_START,
                    ST_READ_START,
                    ST_CHECK_START: begin
                        i2c_cmd <= CMD_START;
                        i2c_start <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule