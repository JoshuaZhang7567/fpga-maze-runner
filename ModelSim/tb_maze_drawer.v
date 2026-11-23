`timescale 1ns / 1ns

// Testbench for maze_drawer (monitor/monitor.v)
//   A small 4x4 maze, every cell drawn as a 2x2 block (SCALE_FACTOR = 2), top-left corner at (8, 4).
//   So the maze covers x = 8..15, y = 4..11 on the screen, 4*4*2*2 = 64 pixels in total.
//
//   maze_ram is replaced by a tiny behavioral RAM with the same timing as the real one
//   (address registered on the clock edge, output not registered -> 1 cycle read latency),
//   so no altera_mf library or MIF file is needed.
//
//   Every VGA write is stored in a small frame buffer. After done, the frame buffer is
//   printed as ASCII art and every pixel is compared with the color it should have.
module tb_maze_drawer;
    localparam DIM = 4;
    localparam SCALE = 2;
    localparam X0 = 8;
    localparam Y0 = 4;
    localparam SIZE = DIM * SCALE;   // 8x8 pixels on screen

    // color codes and RGB colors, shared with cell_color_decoder
    `include "../wall_codes.vh"

    reg clock, resetn, enable;

    wire [13:0] maze_addr;
    reg  [2:0]  maze_q;
    wire done, vga_write;
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;

    maze_drawer #(.DIM_X(DIM), .DIM_Y(DIM), .SCALE_FACTOR(SCALE)) dut (
        .resetn(resetn),
        .clock(clock),
        .enable(enable),
        .maze_cell_color(maze_q),
        .maze_addr(maze_addr),
        .x(X0[9:0]),
        .y(Y0[8:0]),
        .done(done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );

    // ---------------- behavioral maze RAM (1 cycle read latency) ----------------
    reg [2:0] maze [0:DIM*DIM-1];
    always @ (posedge clock)
        maze_q <= maze[maze_addr];

    // ---------------- clock ----------------
    initial clock = 1'b0;
    always #10 clock = ~clock;

    // ---------------- frame buffer ----------------
    reg [8:0] fb      [0:SIZE-1][0:SIZE-1];   // fb[row][col]
    integer   fb_hits [0:SIZE-1][0:SIZE-1];
    integer n_pixels, n_errors, n_outside, r, c, timeout;

    always @ (posedge clock) begin
        if (resetn && vga_write) begin
            n_pixels = n_pixels + 1;
            if (vga_x < X0 || vga_x >= X0 + SIZE || vga_y < Y0 || vga_y >= Y0 + SIZE) begin
                if (n_outside < 5)
                    $display("  ERROR: pixel (%0d, %0d) is outside the maze area", vga_x, vga_y);
                n_outside = n_outside + 1;
            end else begin
                fb[vga_y - Y0][vga_x - X0] = vga_color;
                fb_hits[vga_y - Y0][vga_x - X0] = fb_hits[vga_y - Y0][vga_x - X0] + 1;
            end
        end
    end

    // expected 9-bit color of a color code
    function [8:0] code_to_color(input [2:0] code);
        case (code)
            CODE_WALL:    code_to_color = WALL;
            CODE_OPEN:    code_to_color = OPEN;
            CODE_START:   code_to_color = START;
            CODE_GOAL:    code_to_color = GOAL;
            CODE_VISITED: code_to_color = VISITED;
            CODE_CURRENT: code_to_color = CURRENT;
            CODE_PATH:    code_to_color = PATH;
            default:      code_to_color = OPEN;
        endcase
    endfunction

    // one character per color, for the ASCII picture
    function [7:0] color_to_char(input [8:0] color);
        case (color)
            WALL:         color_to_char = "#";  // wall
            OPEN:         color_to_char = ".";  // open
            START:        color_to_char = "S";  // start
            GOAL:         color_to_char = "G";  // goal
            VISITED:      color_to_char = "v";  // visited
            CURRENT:      color_to_char = "C";  // current
            PATH:         color_to_char = "P";  // path
            default:      color_to_char = "?";
        endcase
    endfunction

    reg [8*SIZE-1:0] line;
    reg [8:0] expected;

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

        for (r = 0; r < SIZE; r = r + 1)
            for (c = 0; c < SIZE; c = c + 1) begin
                fb[r][c] = 9'bx;
                fb_hits[r][c] = 0;
            end
        n_pixels = 0; n_errors = 0; n_outside = 0;

        enable = 1'b0;
        resetn = 1'b0;
        repeat (3) @(negedge clock);
        resetn = 1'b1;
        repeat (2) @(negedge clock);

        // one-cycle start pulse
        $display("Start drawing a %0dx%0d maze, scale %0d, at (%0d, %0d)", DIM, DIM, SCALE, X0, Y0);
        @(negedge clock) enable = 1'b1;
        @(negedge clock) enable = 1'b0;

        timeout = 0;
        while (!done && timeout < 5000) begin
            @(negedge clock);
            timeout = timeout + 1;
        end
        if (!done) begin
            $display("ERROR: done never went high");
            n_errors = n_errors + 1;
        end
        $display("done after %0d cycles, %0d pixels written (expected %0d)",
                 timeout, n_pixels, SIZE * SIZE);
        repeat (5) @(negedge clock);

        // ---------------- print what ended up on the "screen" ----------------
        $display("Screen (x = %0d..%0d, y = %0d..%0d):", X0, X0 + SIZE - 1, Y0, Y0 + SIZE - 1);
        for (r = 0; r < SIZE; r = r + 1) begin
            for (c = 0; c < SIZE; c = c + 1)
                line[8*(SIZE-1-c) +: 8] = color_to_char(fb[r][c]);
            $display("  %s", line);
        end

        // ---------------- check every pixel ----------------
        if (n_pixels != SIZE * SIZE) n_errors = n_errors + 1;
        n_errors = n_errors + n_outside;
        for (r = 0; r < SIZE; r = r + 1)
            for (c = 0; c < SIZE; c = c + 1) begin
                expected = code_to_color(maze[(r / SCALE) * DIM + (c / SCALE)]);
                if (fb_hits[r][c] != 1) begin
                    $display("ERROR: pixel (%0d, %0d) written %0d times", X0 + c, Y0 + r, fb_hits[r][c]);
                    n_errors = n_errors + 1;
                end else if (fb[r][c] !== expected) begin
                    $display("ERROR: pixel (%0d, %0d) color %b, expected %b", X0 + c, Y0 + r, fb[r][c], expected);
                    n_errors = n_errors + 1;
                end
            end

        if (n_errors == 0) $display("PASS: maze_drawer works");
        else               $display("FAIL: %0d error(s)", n_errors);
        $stop;
    end
endmodule
