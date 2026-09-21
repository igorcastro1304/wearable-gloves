module t9_key_fsm (
    input wire clk,
    input wire reset,
    input wire key_pressed_strobe,
    output reg [1:0] char_index,
    output reg commit_pulse
);
    localparam STATE_IDLE = 2'b00;
    localparam STATE_KEY_COUNT = 2'b01;
    localparam STATE_COMMIT = 2'b10;

    reg [1:0] current_state, next_state;
    reg start_timer;
    wire timer_timeout;

    t9_timer #(.CLK_FREQ(100)) u_timer (
        .clk(clk),
        .reset(reset),
        .start(start_timer),
        .timeout(timer_timeout)
    );

    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= STATE_IDLE;
        else
            current_state <= next_state;    
    end

    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_IDLE: begin
                if (key_pressed_strobe)
                    next_state = STATE_KEY_COUNT;
            end

            STATE_KEY_COUNT: begin
                if (timer_timeout)
                    next_state = STATE_COMMIT;
            end
            STATE_COMMIT: begin
                next_state = STATE_COMMIT;
            end 
            default:
                next_state = STATE_IDLE; 
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            char_index <= 2'b00;
            commit_pulse <= 1'b0;
            start_timer <= 1'b0;
        end else begin
            commit_pulse <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    if (key_pressed_strobe) begin
                        char_index <= 2'b00;
                        start_timer <= 1'b1;
                    end else begin
                        start_timer <= 1'b0;
                    end
                end

                STATE_KEY_COUNT: begin
                    if (key_pressed_strobe) begin
                        if (char_index == 2'b10)
                            char_index <= 2'b00;
                        else
                            char_index <= char_index + 1'b1;
                    
                        start_timer <= 1'b0;
                    end else begin
                        start_timer <= 1'b1;
                    end
                end

                STATE_COMMIT: begin
                    commit_pulse <= 1'b1;
                    start_timer <= 1'b0;
                end
            endcase
        end
    end
endmodule