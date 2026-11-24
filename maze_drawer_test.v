// Board test for maze_drawer (DE1-SoC)
//   Draws the maze stored in maze_ram (MAZE_1.mif, 32x32) onto the VGA display.
//
//   KEY[0]   = reset (hold down to reset); the maze is drawn once automatically after reset
//   KEY[1]   = redraw the maze
//   SW[9]    = 1: redraw continuously (so SW changes show up without pressing KEY[1])
//   SW[3]    = 1: ignore the RAM, paint every cell with the color code on SW[2:0]
//                 (000 wall, 001 open, 010 start, 011 goal, 100 visited, 101 current, 110 path)
//   LEDR[0]  = drawing in progress
//   LEDR[1]  = last draw finished (maze_drawer's done was seen)
module maze_drawer_test(CLOCK_50, KEY, SW, LEDR,
                        VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input CLOCK_50;
    input [3:0] KEY;            // all 4 declared to match the .qsf; KEY[1:0] used
    input [9:0] SW;
    output [9:0] LEDR;

    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // MAZE_1.mif is a 32x32 maze. 32 * 14 = 448 pixels, which fits in 480 rows
    // (SCALE_FACTOR = 16 would be 512 rows and run off the bottom of the screen).
    localparam DIM_X = 32;
    localparam DIM_Y = 32;
    localparam SCALE = 14;
    localparam ORIGIN_X = (640 - DIM_X * SCALE) / 2;   // 96: center horizontally
    localparam ORIGIN_Y = (480 - DIM_Y * SCALE) / 2;   // 16: center vertically

    wire resetn = KEY[0];

    // ---------------------------------------------------------------------------------
    // Start pulse: once right after reset, on every KEY[1] press, or always if SW[9] = 1
    // ---------------------------------------------------------------------------------
    reg [2:0] key1_sync;        // KEY is active-low and asynchronous: synchronize it first
    reg auto_start;
    always @ (posedge CLOCK_50) begin
        key1_sync  <= {key1_sync[1:0], KEY[1]};
        auto_start <= !resetn;  // 1 for the first cycle after reset is released
    end
    wire key1_pressed = key1_sync[2] & ~key1_sync[1];   // 1 -> 0 edge
    wire start = auto_start | key1_pressed | SW[9];

    // ---------------------------------------------------------------------------------
    // maze_ram, port B only (port A is reserved for the search FSM)
    // ---------------------------------------------------------------------------------
    wire [13:0] maze_addr;
    wire [2:0] ram_q;
    maze_ram maze_mem (
        .clock(CLOCK_50),
        .address_a(14'd0),
        .data_a(3'd0),
        .wren_a(1'b0),
        .q_a(),
        .address_b(maze_addr),
        .data_b(3'd0),
        .wren_b(1'b0),
        .q_b(ram_q)
    );

    // MAZE_1.mif already holds 3-bit color codes (including start and goal)
    wire [2:0] cell_code = SW[3] ? SW[2:0] : ram_q;

    // ---------------------------------------------------------------------------------
    // Device under test
    // ---------------------------------------------------------------------------------
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;
    wire vga_write, done;
    maze_drawer #(.DIM_X(DIM_X), .DIM_Y(DIM_Y), .SCALE_FACTOR(SCALE)) dut (
        .resetn(resetn),
        .clock(CLOCK_50),
        .start(start),
        .maze_cell_code(cell_code),
        .maze_addr(maze_addr),
        .origin_x(ORIGIN_X[9:0]),
        .origin_y(ORIGIN_Y[8:0]),
        .done(done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );

    // ---------------------------------------------------------------------------------
    // VGA
    // ---------------------------------------------------------------------------------
    vga_adapter #(
        .RESOLUTION("640x480"),
        .COLOR_DEPTH(9),
        .BACKGROUND_IMAGE("UNUSED")   // no background MIF: screen starts black
    ) VGA (
        .resetn(resetn),
        .clock(CLOCK_50),
        .color(vga_color),
        .x(vga_x),
        .y(vga_y),
        .write(vga_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );

    // ---------------------------------------------------------------------------------
    // Status LEDs
    // ---------------------------------------------------------------------------------
    reg busy, finished;
    always @ (posedge CLOCK_50) begin
        if (!resetn) begin
            busy     <= 1'b0;
            finished <= 1'b0;
        end else if (done) begin
            busy     <= 1'b0;
            finished <= 1'b1;
        end else if (start) begin
            busy     <= 1'b1;
            finished <= 1'b0;
        end
    end

    assign LEDR[0]   = busy;
    assign LEDR[1]   = finished;
    assign LEDR[9:2] = 8'd0;
endmodule
