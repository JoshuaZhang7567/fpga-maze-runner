// Top level control: draw the maze, pick a start and a destination with W/A/S/D + Space, then start the search core
// The start and destination are written into maze_ram as START/GOAL, then maze_drawer redraws the whole maze
// The cursor is NOT written into maze_ram: the top level shows it on top of the maze while show_cursor is 1
module top_fsm(clock, resetn, action, draw_done, core_done, reset_done, maze_cell_color,
                        maze_addr, maze_data, maze_wren, draw_start, core_start, reset_start, show_cursor, searching,
                        start_x, start_y, dest_x, dest_y, cursor_x, cursor_y, state);
    // ! DIM_X, DIM_Y must be the same as the ones in maze_drawer, otherwise maze_addr points at the wrong cell
    parameter DIM_X = 32;
    parameter DIM_Y = 32;

    input clock, resetn;

    // draw_done: 1 for one cycle when maze_drawer finishes a redraw
    // core_done: 1 when the search core finishes
    // reset_done: 1 when maze_cleaner finishes
    input draw_done, core_done, reset_done;

    // maze_cell_color: the color code read from maze_ram, it is the cell under the cursor
    // maze_addr: the address of the maze_ram that we wanna read/write, it always points at the cursor
    // maze_data: the color code we wanna write into maze_ram
    // maze_wren: 1 if we write maze_data into maze_ram at the next posedge clk
    input [2:0] maze_cell_color;
    output [13:0] maze_addr;
    output [2:0] maze_data;
    output maze_wren;

    // draw_start: start maze_drawer, 1 while we are waiting for draw_done
    // core_start: start the search core, 1 for one cycle
    // show_cursor: 1 if the top level should draw the cursor (at maze_addr) on top of the maze
    // searching: 1 while the search core runs, the top level gives maze_ram port A to the core
    output draw_start, core_start, reset_start, show_cursor, searching;

    // (start_x, start_y): the start that the user picked
    // (dest_x, dest_y): the destination that the user picked
    // (cursor_x, cursor_y): current position of the cursor
    //
    // The position here is the cell coordinate in the maze, it is not physical pixel on the screen
    // Therefore 7bit should be more than enough.
    output reg [6:0] start_x, start_y, dest_x, dest_y;
    output reg [6:0] cursor_x, cursor_y;

    // state: current state, for LEDs
    output [3:0] state;

    // action: from the decoder
    input [3:0] action;

    // Color codes, shared with cell_color_decoder
    `include "../wall_codes.vh"

    // FSM States
    localparam DRAW_MAZE   = 4'b0000; // keep maze_drawer started and wait until it finishes
    localparam PICK_START  = 4'b0001; // wait for a key while picking the start
    localparam PICK_DEST   = 4'b0010; // wait for a key while picking the destination
    localparam START_SIM   = 4'b0011; // start the search core
    localparam RUN_SIM     = 4'b0100; // wait until the search core finishes
    localparam DONE        = 4'b0101; // stay here until reset
    localparam CONFIRM     = 4'b0110; // write START/GOAL into the cell under the cursor
    localparam RESET       = 4'b0111; // Reset the maze

    // y_Q: PS
    // Y_Q: NS
    reg [3:0] y_Q, Y_Q;

    // only key presses (release bit = 0) move the cursor or confirm
    wire w_pressed     = (action == 4'b0000); // W / Up
    wire a_pressed     = (action == 4'b0001); // A / Left
    wire s_pressed     = (action == 4'b0010); // S / Down
    wire d_pressed     = (action == 4'b0011); // D / Right
    wire space_pressed = (action == 4'b0100); // Space confirms (the decoder has no Enter)

    // picking_dest: 1 if the start is picked and we are picking the destination
    // dest_picked: 1 if the destination is picked
    reg picking_dest, dest_picked;

    // (next_x, next_y): where the cursor goes after the key that was just pressed
    // the cursor can go over walls, but stays inside the maze
    reg [6:0] next_x, next_y;
    // prevent cursor from going out of bound
    always @ (*) begin
        next_x = cursor_x;
        next_y = cursor_y;
        if(w_pressed && cursor_y != 7'd0) next_y = cursor_y - 7'd1;
        if(s_pressed && cursor_y != DIM_Y - 1) next_y = cursor_y + 7'd1;
        if(a_pressed && cursor_x != 7'd0) next_x = cursor_x - 7'd1;
        if(d_pressed && cursor_x != DIM_X - 1) next_x = cursor_x + 7'd1;
    end

    // cursor_move: 1 if the cursor is able to move
    wire cursor_move = (next_x != cursor_x) | (next_y != cursor_y);

    // on_start: 1 if the cursor is on the start
    // start_valid: 1 if Space is pressed on a cell that is not a wall
    // dest_valid: 1 if Space is pressed on a cell that is neither a wall nor the start
    //
    // maze_cell_color can be used directly: maze_addr has been pointing at the cursor for the whole redraw,
    // so the 1 cycle delay of maze_ram is long over when we are back in PICK_START/PICK_DEST
    wire on_start = (cursor_x == start_x) & (cursor_y == start_y);
    wire start_valid = space_pressed & (maze_cell_color != CODE_WALL);
    wire dest_valid = space_pressed & (maze_cell_color != CODE_WALL) & ~on_start;

    // Next state logic
    always @ (*) begin
        Y_Q = y_Q;
        case(y_Q)
            // after a redraw, go back to where we came from
            DRAW_MAZE: begin
                if(!draw_done) Y_Q = y_Q;
                else if(dest_picked) Y_Q = START_SIM;
                else if(picking_dest) Y_Q = PICK_DEST;
                else Y_Q = PICK_START;
            end
            PICK_START: begin
                if(cursor_move) Y_Q = DRAW_MAZE;
                else if(start_valid) Y_Q = CONFIRM;
            end
            PICK_DEST: begin
                if(cursor_move) Y_Q = DRAW_MAZE;
                else if(dest_valid) Y_Q = CONFIRM;
            end
            CONFIRM: Y_Q = DRAW_MAZE;
            START_SIM: Y_Q = RUN_SIM;
            RUN_SIM: if(core_done) Y_Q = DONE;
            DONE: ;
            RESET: if(reset_done) Y_Q = DRAW_MAZE;
            default: Y_Q = DRAW_MAZE;
        endcase
    end

    // FFs
    always @ (posedge clock) begin
        if(!resetn)
            y_Q <= RESET;
        else
            y_Q <= Y_Q;
    end

    always @ (posedge clock) begin
        if(!resetn) begin
            // initial position of cursor: (1, 1)
            cursor_x <= 7'd1;
            cursor_y <= 7'd1;
            start_x <= 7'd0;
            start_y <= 7'd0;
            dest_x <= 7'd0;
            dest_y <= 7'd0;
            picking_dest <= 1'b0;
            dest_picked <= 1'b0;
        end
        else begin
            case(y_Q)
                // move the cursor right away, the redraw shows it at the new place
                PICK_START, PICK_DEST: begin
                    cursor_x <= next_x;
                    cursor_y <= next_y;
                end
                CONFIRM: begin
                    if(!picking_dest) begin
                        // if we just picked start
                        start_x <= cursor_x;
                        start_y <= cursor_y;
                        picking_dest <= 1'b1;
                    end
                    else begin
                        // if we just picked destination
                        dest_x <= cursor_x;
                        dest_y <= cursor_y;
                        dest_picked <= 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    // Output logic
    assign maze_addr = cursor_y*DIM_X + cursor_x;

    // maze_ram is only written in CONFIRM
    assign maze_wren = (y_Q == CONFIRM);
    assign maze_data = picking_dest ? CODE_GOAL : CODE_START;

    // draw_start stays 1 for the whole DRAW_MAZE,
    // since iterator_2d only check start signal in IDLE, so drawer wouldn't be activated twice;
    assign draw_start = (y_Q == DRAW_MAZE) | (y_Q == RUN_SIM) | (y_Q == DONE);
    assign core_start = (y_Q == START_SIM);
    assign reset_start = (y_Q == RESET);
    assign searching = (y_Q == RUN_SIM);
    // the cursor is shown until the destination is picked
    assign show_cursor = ~dest_picked;

    // FOR DEBUG USAGE
    assign state = y_Q;
endmodule
