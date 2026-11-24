//   KEY[0]    = reset (hold down to reset)
//   LEDR[3:0] = state of point_select_fsm (see the FSM States in control/fsm.v)
//   LEDR[4]   = show_cursor
//   LEDR[5]   = searching
//   LEDR[6]   = search succeeded
//   LEDR[7]   = search failed
//   LEDR[8]   = core_start was seen (start and destination are both picked)
//   LEDR[9]   = flips on every key event (W/A/S/D, arrows, Space; press or release)
module top(CLOCK_50, KEY, LEDR, PS2_CLK, PS2_DAT,
           VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input CLOCK_50;
    input [3:0] KEY;            // all 4 declared to match the .qsf; only KEY[0] used
    inout PS2_CLK, PS2_DAT;
    output [9:0] LEDR;

    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    localparam DIM_X = 32;
    localparam DIM_Y = 32;
    localparam SCALE = 14;
    localparam ORIGIN_X = (640 - DIM_X * SCALE) / 2;   // 96: center horizontally
    localparam ORIGIN_Y = (480 - DIM_Y * SCALE) / 2;   // 16: center vertically

    // color codes
    `include "wall_codes.vh"

    wire resetn = KEY[0];

    // action from keyboard decoder
    wire [3:0] action;

    keyboard keyboard (
        .clock(CLOCK_50),
        .resetn(resetn),
        .kb_clock_pin(PS2_CLK),
        .kb_data_pin(PS2_DAT),
        .action(action)
    );

    // fsm_addr, fsm_data, fsm_wren: port A inputs from point_select_fsm
    // core_addr, core_data, core_wren: port A inputs from search_core
    // ram_cell_color: port A inputs from search_core and point_select_fsm, they won't use this port at the same time
    // draw_addr, draw_cell_color: port B, the cell that maze_drawer is drawing
    wire [13:0] fsm_addr, core_addr, draw_addr;
    wire [2:0] fsm_data, core_data, ram_cell_color, draw_cell_color;
    wire fsm_wren, core_wren;

    // searching: 1 during RUN_SIM. point_select_fsm and search_core never need port A at the same time,
    // so port A is time-shared: search_core gets it while searching, point_select_fsm the rest of the time
    wire searching;
    wire [13:0] ram_addr_a = searching ? core_addr : fsm_addr;
    wire [2:0]  ram_data_a = searching ? core_data : fsm_data;
    wire        ram_wren_a = searching ? core_wren : fsm_wren;

    maze_ram maze_ram (
        .clock(CLOCK_50),
        .address_a(ram_addr_a),
        .data_a(ram_data_a),
        .wren_a(ram_wren_a),
        .q_a(ram_cell_color),
        .address_b(draw_addr),
        .data_b(3'd0),
        .wren_b(1'b0),
        .q_b(draw_cell_color)
    );

    wire draw_start, draw_done, core_start, core_done, show_cursor;
    wire [3:0] state;
    wire [6:0] start_x, start_y;
    top_fsm #(
        .DIM_X(DIM_X),
        .DIM_Y(DIM_Y)
    ) point_select_fsm (
        .clock(CLOCK_50),
        .resetn(resetn),
        .action(action),
        .draw_done(draw_done),
        .core_done(core_done),
        .maze_cell_color(ram_cell_color),
        .maze_addr(fsm_addr),
        .maze_data(fsm_data),
        .maze_wren(fsm_wren),
        .draw_start(draw_start),
        .core_start(core_start),
        .show_cursor(show_cursor),
        .searching(searching),
        .start_x(start_x),
        .start_y(start_y),
        .dest_x(),
        .dest_y(),
        .cursor_x(),
        .cursor_y(),
        .state(state)
    );

    wire [9:0] current_cell;
    wire core_success, core_fail;
    search_core search_core (
        .clock(CLOCK_50),
        .resetn(resetn),
        .start(core_start),
        .algorithm(1'b0),
        .start_cell({start_y[4:0], start_x[4:0]}),      // = start_y * 32 + start_x
        .current_cell(current_cell),
        .success(core_success),
        .fail(core_fail),
        .maze_addr(core_addr),
        .maze_data(core_data),
        .maze_wren(core_wren),
        .maze_cell_color(ram_cell_color)
    );
    assign core_done = core_success | core_fail;

    // Delay 1 cycle, since maze_ram takes 1 cycle to get the cell_color at draw_addr
    reg [13:0] draw_addr_q;
    always @ (posedge CLOCK_50)
        draw_addr_q <= draw_addr;

    // draw_color_code: if we are now on cursor or on current cell, draw current color
    // The reason cursor and current related logic is different from other color is because they are not written into the RAM 
    // Instead, they are superpositioned onto the display
    wire on_cursor  = show_cursor && (draw_addr_q == fsm_addr);
    wire on_current = searching   && (draw_addr_q == {4'd0, current_cell});
    wire [2:0] draw_color_code = (on_cursor | on_current) ? CODE_CURRENT : draw_cell_color;

    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;
    wire vga_write;
    maze_drawer #(
        .DIM_X(DIM_X),
        .DIM_Y(DIM_Y),
        .SCALE_FACTOR(SCALE)
    ) maze_drawer (
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

    // started: 1 if core_start was seen
    // toggle: flips on every key event from the keyboard (action != NONE)
    reg started, toggle;
    always @ (posedge CLOCK_50) begin
        if(!resetn) begin
            started <= 1'b0;
            toggle <= 1'b0;
        end
        else begin
            if(core_start) started <= 1'b1;
            if(action != 4'b1111) toggle <= ~toggle;
        end
    end

    assign LEDR[3:0] = state;
    assign LEDR[4] = show_cursor;
    assign LEDR[5] = searching;
    assign LEDR[6] = core_success;
    assign LEDR[7] = core_fail;
    assign LEDR[8] = started;
    assign LEDR[9] = toggle;
endmodule
