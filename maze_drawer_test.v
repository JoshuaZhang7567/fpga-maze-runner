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
    parameter DIM_X = 32;
    parameter DIM_Y = 32;
    parameter SCALE = 14;
    parameter ORIGIN_X = (640 - DIM_X * SCALE) / 2;   // 96: center horizontally
    parameter ORIGIN_Y = (480 - DIM_Y * SCALE) / 2;   // 16: center vertically

    // MAZE_1.mif is 1 bit wide with 1 = wall, 0 = open, but cell_color_decoder expects
    // 3-bit codes where 000 = wall, 001 = open. Set to 0 once the MIF holds real color codes.
    parameter MIF_IS_1BIT = 1;

    // Start/goal are not stored in MAZE_1.mif; paint them here so START/GOAL colors get tested.
    parameter START_ADDR = 1 * DIM_X + 1;     // (x, y) = (1, 1)
    parameter GOAL_ADDR  = 29 * DIM_X + 29;   // (x, y) = (29, 29)

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

    // maze_ram registers both the address and the output, so ram_q belongs to the address
    // from 2 cycles ago. Delay the address the same amount to know which cell ram_q is.
    reg [13:0] addr_d1, addr_d2;
    always @ (posedge CLOCK_50) begin
        addr_d1 <= maze_addr;
        addr_d2 <= addr_d1;
    end

    reg [2:0] cell_code;
    always @ (*) begin
        if (SW[3])
            cell_code = SW[2:0];
        else if (addr_d2 == START_ADDR)
            cell_code = 3'b010;
        else if (addr_d2 == GOAL_ADDR)
            cell_code = 3'b011;
        else if (MIF_IS_1BIT)
            cell_code = ram_q[0] ? 3'b000 : 3'b001;
        else
            cell_code = ram_q;
    end

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
        .enable(start),
        .maze_cell_color(cell_code),
        .maze_addr(maze_addr),
        .x(ORIGIN_X[9:0]),
        .y(ORIGIN_Y[8:0]),
        .done(done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );

    // ---------------------------------------------------------------------------------
    // VGA
    // ---------------------------------------------------------------------------------
    vga_adapter VGA (
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
        defparam VGA.RESOLUTION = "640x480";
        defparam VGA.COLOR_DEPTH = 9;
        defparam VGA.BACKGROUND_IMAGE = "UNUSED";   // no background MIF: screen starts black

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
