// Top level board test (DE1-SoC): draw the maze, then pick a start and a destination with the keyboard
//   After reset the maze (MAZE_1.mif, 32x32) is drawn with a yellow cursor at (1, 1)
//   W/A/S/D = move the cursor, Enter = confirm the start (cyan), then the destination (violet)
//   ! The search core is not built yet, KEY[1] pretends that it finished
//
//   KEY[0]    = reset (hold down to reset)
//   KEY[1]    = pretend the search core finished (RUN_SIM -> DONE)
//   LEDR[3:0] = state of point_select_fsm (see the FSM States in point_select_fsm.v)
//   LEDR[4]   = show_cursor
//   LEDR[8]   = core_start was seen (start and destination are both picked)
//   LEDR[9]   = flips every time a byte arrives from the keyboard
module top(CLOCK_50, KEY, LEDR, PS2_CLK, PS2_DAT,
           VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input CLOCK_50;
    input [3:0] KEY;            // all 4 declared to match the .qsf; KEY[1:0] used
    inout PS2_CLK, PS2_DAT;
    output [9:0] LEDR;

    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // ! DIM_X, DIM_Y go to BOTH maze_drawer and point_select_fsm, so they agree on the address of every cell
    // 32 * 14 = 448 pixels, which fits in 480 rows
    parameter DIM_X = 32;
    parameter DIM_Y = 32;
    parameter SCALE = 14;
    parameter ORIGIN_X = (640 - DIM_X * SCALE) / 2;   // 96: center horizontally
    parameter ORIGIN_Y = (480 - DIM_Y * SCALE) / 2;   // 16: center vertically

    parameter CODE_CURRENT = 3'b101; // color code of the cursor (yellow)

    wire resetn = KEY[0];

    // kb_data: the byte received from the keyboard
    // kb_valid: 1 for one cycle when kb_data is a new byte
    wire [7:0] kb_data;
    wire kb_valid;
    keyboard keyboard (
        .clock(CLOCK_50),
        .resetn(resetn),
        .kb_clock_pin(PS2_CLK),
        .kb_data_pin(PS2_DAT),
        .data(kb_data),
        .data_valid(kb_valid)
    );

    // ---------------------------------------------------------------------------------
    // core_done: 1 for one cycle when KEY[1] is pressed, stands in for the search core
    // ---------------------------------------------------------------------------------
    reg [2:0] key1_sync;        // KEY is active-low and asynchronous: synchronize it first
    always @ (posedge CLOCK_50)
        key1_sync <= {key1_sync[1:0], KEY[1]};
    wire core_done = key1_sync[2] & ~key1_sync[1];   // 1 -> 0 edge

    // ---------------------------------------------------------------------------------
    // maze_ram: port A = point_select_fsm, port B = maze_drawer
    // ---------------------------------------------------------------------------------
    // fsm_addr, fsm_data, fsm_wren, fsm_cell_color: port A, always points at the cursor
    // draw_addr, draw_cell_color: port B, the cell that maze_drawer is drawing
    wire [13:0] fsm_addr, draw_addr;
    wire [2:0] fsm_data, fsm_cell_color, draw_cell_color;
    wire fsm_wren;
    maze_ram maze_ram (
        .clock(CLOCK_50),
        .address_a(fsm_addr),
        .data_a(fsm_data),
        .wren_a(fsm_wren),
        .q_a(fsm_cell_color),
        .address_b(draw_addr),
        .data_b(3'd0),
        .wren_b(1'b0),
        .q_b(draw_cell_color)
    );

    // ---------------------------------------------------------------------------------
    // Point selection
    // ---------------------------------------------------------------------------------
    wire draw_start, draw_done, core_start, show_cursor;
    wire [3:0] state;
    top_fsm point_select_fsm (
        .clock(CLOCK_50),
        .resetn(resetn),
        .kb_data(kb_data),
        .kb_valid(kb_valid),
        .draw_done(draw_done),
        .core_done(core_done),
        .maze_cell_color(fsm_cell_color),
        .maze_addr(fsm_addr),
        .maze_data(fsm_data),
        .maze_wren(fsm_wren),
        .draw_start(draw_start),
        .core_start(core_start),
        .show_cursor(show_cursor),
        .start_x(),
        .start_y(),
        .dest_x(),
        .dest_y(),
        .cursor_x(),
        .cursor_y(),
        .state(state)
    );
        defparam point_select_fsm.DIM_X = DIM_X;
        defparam point_select_fsm.DIM_Y = DIM_Y;

    // ---------------------------------------------------------------------------------
    // Cursor: drawn on top of the maze, it is never written into maze_ram
    // ---------------------------------------------------------------------------------
    // draw_addr_q: the address that draw_cell_color belongs to, since maze_ram has 1 cycle delay
    reg [13:0] draw_addr_q;
    always @ (posedge CLOCK_50)
        draw_addr_q <= draw_addr;

    // draw_color_code: CURRENT if maze_drawer is reading the cursor cell, otherwise whatever is in maze_ram
    wire [2:0] draw_color_code = (show_cursor && draw_addr_q == fsm_addr) ? CODE_CURRENT : draw_cell_color;

    // ---------------------------------------------------------------------------------
    // Maze drawer (monitor/monitor.v), started only by point_select_fsm
    // ---------------------------------------------------------------------------------
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;
    wire vga_write;
    maze_drawer maze_drawer (
        .resetn(resetn),
        .clock(CLOCK_50),
        .enable(draw_start),
        .maze_cell_color(draw_color_code),
        .maze_addr(draw_addr),
        .x(ORIGIN_X[9:0]),
        .y(ORIGIN_Y[8:0]),
        .done(draw_done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );
        defparam maze_drawer.DIM_X = DIM_X;
        defparam maze_drawer.DIM_Y = DIM_Y;
        defparam maze_drawer.SCALE_FACTOR = SCALE;

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
    // started: 1 if core_start was seen
    // toggle: flips every time a byte arrives from the keyboard
    reg started, toggle;
    always @ (posedge CLOCK_50) begin
        if(!resetn) begin
            started <= 1'b0;
            toggle <= 1'b0;
        end
        else begin
            if(core_start) started <= 1'b1;
            if(kb_valid) toggle <= ~toggle;
        end
    end

    assign LEDR[3:0] = state;
    assign LEDR[4] = show_cursor;
    assign LEDR[7:5] = 3'd0;
    assign LEDR[8] = started;
    assign LEDR[9] = toggle;
endmodule
