// BFS over a 32x32 maze in maze_ram; one cell is expanded per half_second_pulse
// Cell number = {y[4:0], x[4:0]}; the cell colours in RAM double as the visited flags
module bfs_dfs(
    clock, resetn, half_second_pulse, start, algorithm, start_cell, current_cell, success, fail,
    fifo_sclr, fifo_rdreq, fifo_wrreq, fifo_data, fifo_q, empty,
    address_a, data_a, wren_a, q_a, parent_addr, parent_data, parent_wren, parent_q);

    // path is relative to this file; wall_codes.vh is in the repo root
    `include "../../wall_codes.vh"

    input clock, resetn;
    input half_second_pulse; // 1 for one clock cycle every 0.5 s
    input start;
    input algorithm;         // BFS = 0, DFS = 1; not used yet (DFS: swap the FIFO for a stack in top.v)
    input [9:0] start_cell;
    output [9:0] current_cell; // the cell being expanded, for top.v to highlight
    output success, fail;

    // FIFO (fifo_1024x10, showahead off: q is valid the cycle after rdreq)
    output reg fifo_sclr, fifo_rdreq, fifo_wrreq;
    output reg [9:0] fifo_data;
    input [9:0] fifo_q;
    input empty;

    // maze_ram port A: read a cell, and mark it VISITED (q_a is valid the cycle after address_a)
    output reg [13:0] address_a;
    output reg [2:0] data_a;
    output reg wren_a;
    input [2:0] q_a;

    // parent_ram
    output reg [9:0] parent_addr;
    output reg parent_wren;
    output reg [1:0] parent_data;
    input [1:0] parent_q;

    localparam BFS = 1'b0, DFS = 1'b1;

    localparam  IDLE       = 5'd0,
                CLEAR      = 5'd1, // empty the FIFO
                PUSH_START = 5'd2, // push the start cell
                WAIT       = 5'd3, // wait for the pulse, then pop
                POP        = 5'd4, // fifo_q is valid: save it
                ADDR       = 5'd5, // send the neighbour's address to the RAM
                CHECK      = 5'd6, // q_a is valid: push + mark, or finish
                DONE       = 5'd7,
                FAIL       = 5'd8,
                BT_WAIT    = 5'd9, // wait for the pulse and update the display
                BT_MOVE    = 5'd10; // move according to the value read from parent_ram

    localparam N = 2'd0, S = 2'd1, E = 2'd2, W = 2'd3;

    reg [4:0] current_state, next_state;
    reg [9:0] popped; // the cell being expanded
    reg [1:0] dir;    // which neighbour: N, S, E, W

    assign current_cell = popped;

    // the neighbour in direction dir, and whether it is inside the maze
    wire [4:0] x = popped[4:0];
    wire [4:0] y = popped[9:5];
    reg [9:0] nb;
    reg nb_inside;
    always @(*) begin
        case (dir)
            N: begin 
                nb = popped - 10'd32; 
                nb_inside = (y != 5'd0);  
            end
            S: begin 
                nb = popped + 10'd32; 
                nb_inside = (y != 5'd31); 
            end
            E: begin 
                nb = popped + 10'd1;  
                nb_inside = (x != 5'd31); 
            end
            default: begin 
                nb = popped - 10'd1; 
                nb_inside = (x != 5'd0); 
            end 
        endcase
    end

    wire found = (current_state == CHECK) & nb_inside & (q_a == CODE_GOAL);

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE:       next_state = start ? CLEAR : IDLE;
            CLEAR:      next_state = PUSH_START;
            PUSH_START: next_state = WAIT;
            WAIT: begin
                if (!half_second_pulse) next_state = WAIT;
                else if (empty)         next_state = FAIL;
                else                    next_state = POP;
            end
            POP:   next_state = ADDR;
            ADDR:  next_state = CHECK;
            CHECK: begin
                if (found)          next_state = DONE;
                else if (dir == W)  next_state = WAIT;
                else                next_state = ADDR;
            end
            DONE: next_state = BT_WAIT; // stay until reset
            BT_WAIT: begin
                if(!half_second_pulse) next_state = BT_MOVE;
                    else if(popped == start_cell) next_state = DONE;
                else next_state = BT_WAIT;
            end
            BT_MOVE: next_state = BT_WAIT;
            FAIL: next_state = FAIL; // stay until reset
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        fifo_sclr  = 1'b0;
        fifo_rdreq = 1'b0;
        fifo_wrreq = 1'b0;
        fifo_data  = 10'd0;
        address_a  = 14'd0;
        data_a     = 3'd0;
        wren_a     = 1'b0;

        case (current_state)
            CLEAR: fifo_sclr = 1'b1;
            PUSH_START: begin
                fifo_wrreq = 1'b1;
                fifo_data  = start_cell;
            end
            WAIT: fifo_rdreq = half_second_pulse & ~empty;
            ADDR: address_a = {4'd0, nb};
            CHECK: begin
                address_a = {4'd0, nb};
                if (nb_inside && q_a == CODE_OPEN) begin
                    // push the neighbour into FIFO
                    fifo_wrreq = 1'b1;
                    fifo_data  = nb;
                    wren_a     = 1'b1;          // and mark it VISITED
                    data_a     = CODE_VISITED;

                    // Update parent
                    parent_wren = 1'b1;
                    parent_data = {dir[1], dir[0]}; // N <-> S, E <-> W
                end
            end
            BT_WAIT: if(half_second_pulse && popped != start_cell) begin
                wren_a = 1'b1;
                data_a = CODE_PATH;
                address_a = {4'b0, popped}; // prepare the address right now, read its value on next clock cycle
            end
            BT_MOVE: begin
                case(parent_q)
                    N: begin
                        popped <= popped - 10'd32;
                    end
                    S: begin
                        popped <= popped + 10'd32;
                    end
                    E: begin
                        popped <= popped + 10'd1;
                    end
                    W: begin
                        popped <= popped - 10'd1;
                    end
                    default: ;
                endcase
            end
        endcase
    end

    assign success = (current_state == DONE);
    assign fail    = (current_state == FAIL);

    // FFs
    always @(posedge clock) begin
        if (!resetn) begin
            current_state <= IDLE;
            popped <= 10'd0;
            dir <= N;
        end else begin
            current_state <= next_state;
            // current_cell shows the start until the first pop, instead of cell 0
            if (current_state == CLEAR)
                popped <= start_cell;
            if (current_state == POP) begin
                popped <= fifo_q;
                dir <= N;
            end
            if (current_state == CHECK)
                dir <= dir + 2'd1;
        end
    end
endmodule
