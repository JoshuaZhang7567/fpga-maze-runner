// Paint a w*h rectangle on the VGA display
module rect_drawer(resetn, clock, start, h, w, x, y, color, done, vga_x, vga_y, vga_color, vga_write);
    input resetn, clock, start;
    // h: height of the rectangle
    // w: width of the rectangle
    // ! Assume the resolution of the display is 640*480
    input [8:0] h;
    input [9:0] w;

    // x: x coord. of the left top cornor
    // y: y coord. of the left top cornor
    input [9:0] x;
    input [8:0] y;

    // color: color of the rectangle, (R, G, B) depth = 3bit
    input [8:0] color;

    output done;
    output [9:0] vga_x;
    output [8:0] vga_y;
    output [8:0] vga_color;
    output vga_write;

    wire [9:0] dx;
    wire [8:0] dy;
    iterator_2d #(
        .NX(10),
        .NY(9)
    ) rect_iterator (
        .resetn(resetn),
        .clock(clock),
        .start(start),
        .enable(1'b1),
        .dimX(w),
        .dimY(h),
        .col(dx),
        .row(dy),
        .done(done),
        .run(vga_write)
    );
    assign vga_x = x + dx;
    assign vga_y = y + dy;
    assign vga_color = color;
endmodule

// Draw a DIM*DIM maze on the VGA Display
module maze_drawer(resetn, clock, start, maze_cell_code, maze_addr, origin_x, origin_y, done, vga_x, vga_y, vga_color, vga_write);
    input resetn, clock, start;

    // maze_cell_code: the color code name read from the maze_ram
    // maze_addr: the address of the maze_ram that we wanna read
    // since address is calculated inside maze_drawer, we need to provide a output of maze_addr to ram in order to get color input
    input [2:0] maze_cell_code;
    output [13:0] maze_addr;
    // ! Assume the resolution of the display is 640*480
    parameter DIM_X = 16;
    parameter DIM_Y = 16;
    parameter SCALE_FACTOR = 16;

    // origin_x: x coord. of the left top cornor
    // origin_y: y coord. of the left top cornor
    input [9:0] origin_x;
    input [8:0] origin_y;

    output done;
    output [9:0] vga_x;
    output [8:0] vga_y;
    output [8:0] vga_color;
    output vga_write;

    // (cx, cy) represents the logic pixel coordinate of a cell
    // each cell is then mapped into SCALE_FACTOR**2 physical pixels
    // Here 6 bit should be enough for 16x16 or 32x32 maze
    wire [7:0] cx;
    wire [6:0] cy;

    // rect_drawer_enable: while iterator is in RUN state, let rect drawer do its work
    // rect_done: when rect_draw finishes all the work, the rect_done signal is then connected to 'enable' port of iterator_2d, updating the iterator
    wire rect_drawer_enable, rect_done;
    iterator_2d #(
        .NX(8),
        .NY(7)
    ) cell_iterator (
        .resetn(resetn),
        .clock(clock),
        .start(start),
        .enable(rect_done),
        .dimX(DIM_X),
        .dimY(DIM_Y),
        .col(cx),
        .row(cy),
        .done(done),
        .run(rect_drawer_enable)
    );

    assign maze_addr = cy*DIM_X + cx; // Similar as how we get memory address in c

    // (px, py) represent the physical pixel coordinate
    // 10bit/9bit must be enough for px/py, if it doesn't, that means something else is screwed up and make the cell outside of the physical screen
    wire [9:0] px = origin_x + cx * SCALE_FACTOR;
    wire [8:0] py = origin_y + cy * SCALE_FACTOR;

    wire [8:0] cell_color;
    cell_color_decoder cell_color_decoder (
        .color_code(maze_cell_code),
        .color(cell_color)
    );

    rect_drawer cell_drawer (
        .resetn(resetn),
        .clock(clock),
        .start(rect_drawer_enable),
        .h(SCALE_FACTOR),
        .w(SCALE_FACTOR),
        .x(px),
        .y(py),
        .color(cell_color),
        .done(rect_done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );
endmodule

// Translate color from 3bit codename to 3bit depth RGB value
// should be pure combinational logic
module cell_color_decoder(color_code, color);
    input [2:0] color_code;
    output reg [8:0] color;

    // path is relative to this file; wall_codes.vh is in the repo root
    `include "../wall_codes.vh"

    always @ (*) begin
        case(color_code)
            CODE_WALL: color = WALL;
            CODE_OPEN: color = OPEN;
            CODE_START: color = START;
            CODE_GOAL: color = GOAL;
            CODE_VISITED: color = VISITED;
            CODE_CURRENT: color = CURRENT;
            CODE_PATH: color = PATH;
            default: color = OPEN;
        endcase
    end
endmodule

// Similar to a double loop that iterate through dimX*dimY
module iterator_2d(resetn, clock, start, enable, dimX, dimY, col, row, done, run);
    parameter NX = 10, NY = 9; // number of bit of dimX, dimY
    // start: start the iterator
    // enable: 1 if the iterator update each posedge clk
    input resetn, clock, start, enable;

    // dimX: number of column
    // dimY: number of lines
    input [NX - 1:0] dimX;
    input [NY - 1:0] dimY;

    // col: iterating signal in [0, dimX -1]
    // row: iterating signal in [0, dimY -1]
    output [NX - 1:0] col;
    output [NY - 1:0] row;

    // 1 if iterator finishes, 0 if not
    output wire done;
    // 1 if iterator is in RUN state, for something else to happen during RUN
    output wire run;

    // FSM States
    localparam IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10;
    // current_state: PS
    // next_state: NS
    reg [1:0] current_state, next_state;

    // last_column: 1 if column_counter reaches the last column
    // last_row: 1 if the row_couter reaches the last row
    wire last_column, last_row;
    // column_counter_enable: counter should work ONLY if the iterator is enabled AND it's in RUN state
    wire column_counter_enable = run & enable;
    wire row_counter_enable = column_counter_enable & last_column;
    counter #(.W(NX)) column_counter (
        .resetn(resetn),
        .clock(clock),
        .init({NX{1'd0}}), // NX-bit of 0
        .limit(dimX - 1),
        .step({{NX-1{1'b0}}, 1'b1}), // 1
        .enable(column_counter_enable),
        .z(col),
        .pulse(last_column)
    );

    counter #(.W(NY)) row_counter (
        .resetn(resetn),
        .clock(clock),
        .init({NY{1'd0}}), // NX-bit of 0
        .limit(dimY - 1),
        .step({{NY-1{1'b0}}, 1'b1}), // 1
        .enable(row_counter_enable),
        .z(row),
        .pulse(last_row)
    );

    // Next state logic
    always @ (*) begin
        case(current_state)
            IDLE: if(start) next_state = RUN; else next_state = current_state;
            RUN: if(last_column & last_row & enable) next_state = DONE; else next_state = current_state;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @ (posedge clock) begin
        if(!resetn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Output logic
    assign done = (current_state == DONE);
    assign run = (current_state == RUN);
endmodule


// Since the start/des selection module and the core logic module in the future are trying to
// write directly to the maze ram, and we can not re-initialize the ram block at runtime
// Therefore, we create this little moudule for resetting ram
module maze_cleaner(resetn, clock, start, maze_cell_code, maze_addr, maze_wren, maze_data, done);
    parameter DIM_X = 16;
    parameter DIM_Y = 16;

    input resetn, clock, start;

    // maze_cell_code: the color code name read from the maze_ram
    // maze_addr: the address of the maze_ram that we wanna read
    // since address is calculated inside maze_drawer, we need to provide a output of maze_addr to ram in order to get color input
    input [2:0] maze_cell_code; // valid 1 cycle after updating the address
    output [13:0] maze_addr;

    output done;
    output [2:0] maze_data;
    output maze_wren;

    `include "../wall_codes.vh"

    wire run;
    reg phase; // 1 for write, 0 for read

    always @ (posedge clock) begin
        if(!resetn | !run) phase <= 1'b0;
        else phase <= ~phase; // flip the phase to wait 1 cycle
    end

    // (cx, cy) represents the logic pixel coordinate of a cell
    // each cell is then mapped into SCALE_FACTOR**2 physical pixels
    wire [7:0] cx;
    wire [6:0] cy;
    iterator_2d #(
        .NX(8),
        .NY(7)
    ) cell_iterator (
        .resetn(resetn),
        .clock(clock),
        .start(start),
        .enable(phase),
        .dimX(DIM_X),
        .dimY(DIM_Y),
        .col(cx),
        .row(cy),
        .done(done),
        .run(run)
    );

    assign maze_addr = cy*DIM_X + cx; // Similar as how we get memory address in c

    wire dirty = (maze_cell_code != CODE_OPEN) & (maze_cell_code != CODE_WALL);

    assign maze_wren = dirty & phase;
    assign maze_data = CODE_OPEN;
endmodule
