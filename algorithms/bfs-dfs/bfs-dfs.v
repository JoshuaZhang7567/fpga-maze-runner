`include "wall_codes.vh"

module BFS_DFS();

    localparam  IDLE = 4'd0,
                POP_REQ = 4'd1,
                FAIL = 4'd2,
                POP = 4'd3,
                IS_GOAL = 4'd4,
                DONE = 4'd5,
                PUSH_N = 4'd6,
                PUSH_S = 4'd7,
                PUSH_E = 4'd8,
                PUSH_W = 4'd9;
    
    localparam BFS = 1'b0, DFS = 1'b1;

    reg [4:0] current_state, next_state;
    reg [9:0] popped;

    always @(*) begin
        case (current_state) 
            IDLE: next_state = start ? S_CLEAR : S_IDLE;
            POP_REQ: next_state = empty ? FAIL : POP;
            FAIL: next_state = IDLE;
            POP: next_state = IS_GOAL;
            IS_GOAL: next_state = (popped == goal) ? DONE : PUSH_N;
            PUSH_N: next_state = PUSH_S;
            PUSH_S: next_state = PUSH_E;
            PUSH_E: next_state = PUSH_W;
            PUSH_W: next_state = POP_REQ;

            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        case (BFS_OR_DFS)
            BFS: begin
                case (current_state)
                    POP: begin
                        fifo_rdreq = 1'b1;
                        popped = fifo_q;          
                    end
                    DONE: success = 1'b1;
                    PUSH_N: begin
                        address_a = popped - 10'd32;
                        if (q_a == CODE_OPEN) begin
                            // write to fifo
                            fifo_wrreq = 1'b1   
                            fifo_data = popped - 10'd32;

                            // update cell colour to visited       
                            address_b = popped - 10'd32;
                            data_b = CODE_VISITED; 
                            wren_b = 1'b1;
                        end
                    end
                    PUSH_S: begin
                        address_a = popped + 10'd32;
                        if (q_a == CODE_OPEN) begin
                            // write to fifo
                            fifo_wrreq = 1'b1   
                            fifo_data = popped + 10'd32;

                            // update cell colour to visited       
                            address_b = popped + 10'd32;
                            data_b = CODE_VISITED; 
                            wren_b = 1'b1;
                        end
                    end
                    PUSH_E: begin
                        address_a = popped + 10'd1;
                        if (q_a == CODE_OPEN) begin
                            // write to fifo
                            fifo_wrreq = 1'b1   
                            fifo_data = popped + 10'd1;

                            // update cell colour to visited       
                            address_b = popped + 10'd1;
                            data_b = CODE_VISITED; 
                            wren_b = 1'b1;
                        end
                    end
                    PUSH_W: begin
                        address_a = popped - 10'd1;
                        if (q_a == CODE_OPEN) begin
                            // write to fifo
                            fifo_wrreq = 1'b1   
                            fifo_data = popped - 10'd1;

                            // update cell colour to visited       
                            address_b = popped - 10'd1;
                            data_b = CODE_VISITED; 
                            wren_b = 1'b1;
                        end
                    end
                    FAIL:
                        failed = 1'b1

                endcase
            end

            DFS: begin
                
            end
        endcase
    end

endmodule