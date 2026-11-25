`timescale 1ns / 1ns

//   A 4x4 maze is filled with walls, open cells and "dirty" cells (start, goal, visited,
//   current, path). After one start pulse, every dirty cell should become OPEN and every
//   wall / open cell should stay as it is.
module tb_maze_cleaner;
    localparam DIM = 4;

    `include "../wall_codes.vh"

    reg clock, resetn, start;

    wire [13:0] maze_addr;
    reg  [2:0]  maze_q;
    wire        maze_wren;
    wire [2:0]  maze_data;
    wire        done;

    maze_cleaner #(.DIM_X(DIM), .DIM_Y(DIM)) dut (
        .resetn(resetn),
        .clock(clock),
        .start(start),
        .maze_cell_code(maze_q),
        .maze_addr(maze_addr),
        .maze_wren(maze_wren),
        .maze_data(maze_data),
        .done(done)
    );

    reg [2:0] maze [0:DIM*DIM-1];
    always @ (posedge clock) begin
        if (maze_wren) maze[maze_addr] <= maze_data;
        maze_q <= maze[maze_addr];
    end

    initial clock = 1'b0;
    always #10 clock = ~clock;

    // count writes
    integer n_writes;
    always @ (posedge clock)
        if (resetn && maze_wren) n_writes = n_writes + 1;

    function [7:0] code_to_char(input [2:0] code);
        case (code)
            CODE_WALL:    code_to_char = "#";
            CODE_OPEN:    code_to_char = ".";
            CODE_START:   code_to_char = "S";
            CODE_GOAL:    code_to_char = "G";
            CODE_VISITED: code_to_char = "v";
            CODE_CURRENT: code_to_char = "C";
            CODE_PATH:    code_to_char = "P";
            default:      code_to_char = "?";
        endcase
    endfunction

    task print_maze;
        integer r, c;
        reg [8*DIM-1:0] line;
        begin
            for (r = 0; r < DIM; r = r + 1) begin
                for (c = 0; c < DIM; c = c + 1)
                    line[8*(DIM-1-c) +: 8] = code_to_char(maze[r*DIM + c]);
                $display("  %s", line);
            end
        end
    endtask

    reg [2:0] before [0:DIM*DIM-1];
    reg [2:0] expected;
    integer i, n_dirty, n_errors, timeout;

    initial begin
        // the maze (address = y*DIM + x):
        //   S . # .
        //   P # v .
        //   P C # #
        //   P P P G
        maze[ 0] = CODE_START;   maze[ 1] = CODE_OPEN;    maze[ 2] = CODE_WALL;    maze[ 3] = CODE_OPEN;
        maze[ 4] = CODE_PATH;    maze[ 5] = CODE_WALL;    maze[ 6] = CODE_VISITED; maze[ 7] = CODE_OPEN;
        maze[ 8] = CODE_PATH;    maze[ 9] = CODE_CURRENT; maze[10] = CODE_WALL;    maze[11] = CODE_WALL;
        maze[12] = CODE_PATH;    maze[13] = CODE_PATH;    maze[14] = CODE_PATH;    maze[15] = CODE_GOAL;

        n_dirty = 0;
        for (i = 0; i < DIM*DIM; i = i + 1) begin
            before[i] = maze[i];
            if (maze[i] != CODE_WALL && maze[i] != CODE_OPEN) n_dirty = n_dirty + 1;
        end
        n_writes = 0; n_errors = 0;

        $display("Before cleaning:");
        print_maze;

        start  = 1'b0;
        resetn = 1'b0;
        repeat (3) @(negedge clock);
        resetn = 1'b1;
        repeat (2) @(negedge clock);

        // one-cycle start pulse
        @(negedge clock) start = 1'b1;
        @(negedge clock) start = 1'b0;

        timeout = 0;
        while (!done && timeout < 1000) begin
            @(negedge clock);
            timeout = timeout + 1;
        end
        if (!done) begin
            $display("ERROR: done never went high");
            n_errors = n_errors + 1;
        end
        repeat (3) @(negedge clock);

        $display("After cleaning (done after %0d cycles, %0d writes, %0d dirty cells):",
                 timeout, n_writes, n_dirty);
        print_maze;

        // ---------------- check every cell ----------------
        if (n_writes != n_dirty) begin
            $display("ERROR: %0d writes, expected %0d", n_writes, n_dirty);
            n_errors = n_errors + 1;
        end
        for (i = 0; i < DIM*DIM; i = i + 1) begin
            expected = (before[i] == CODE_WALL) ? CODE_WALL : CODE_OPEN;
            if (maze[i] !== expected) begin
                $display("ERROR: cell (%0d, %0d) is %b, expected %b", i % DIM, i / DIM, maze[i], expected);
                n_errors = n_errors + 1;
            end
        end

        if (n_errors == 0) $display("PASS: maze_cleaner works");
        else               $display("FAIL: %0d error(s)", n_errors);
        $stop;
    end
endmodule
