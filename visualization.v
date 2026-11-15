// Paint a w*h rectangle on the VGA display
module rect_drawer(resetn, clock, enable, h, w, x, y, color, done, vga_x, vga_y, vga_color, vga_write);
    input resetn, clock, enable;
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
    iterator_2d rect_iterator (
        .resetn(resetn),
        .clock(clock),
        .start(enable),
        .enable(1'b1),
        .dimX(w),
        .dimY(h),
        .col(dx),
        .row(dy),
        .done(done),
        .run(vga_write)
    );
        defparam rect_iterator.NX = 10;
        defparam rect_iterator.NY = 9;
    assign vga_x = x + dx;
    assign vga_y = y + dy;
    assign vga_color = color;
endmodule

// Draw a DIM*DIM maze on the VGA Display
module maze_drawer(resetn, clock, enable, x, y, done, vga_x, vga_y, vga_color, vga_write);
    input resetn, clock, enable;
    // ! Assume the resolution of the display is 640*480
    parameter DIM = 16;
    parameter SCALE_FACTOR = 16;
    parameter MAZE = "MAZE_1.mif";

    // x: x coord. of the left top cornor
    // y: y coord. of the left top cornor
    input [9:0] x;
    input [8:0] y;

    output done;
    output [9:0] vga_x;
    output [8:0] vga_y;
    output [8:0] vga_color;
    output vga_write;

    // (cx, cy) represents the logic pixel coordinate of a cell
    // each cell is then mapped into SCALE_FACTOR**2 physical pixels
    // Here 6 bit should be enough for 16x16 or 32x32 maze
    wire [5:0] cx;
    wire [5:0] cy;

    // rect_drawer_enable: while iterator is in RUN state, let rect drawer do its work
    // rect_done: when rect_draw finishes all the work, the rect_done signal is then connected to 'enable' port of iterator_2d, updating the iterator
    wire rect_drawer_enable, rect_done;
    iterator_2d cell_iterator (
        .resetn(resetn),
        .clock(clock),
        .start(enable),
        .enable(rect_done),
        .dimX(DIM),
        .dimY(DIM),
        .col(cx),
        .row(cy),
        .done(done),
        .run(rect_drawer_enable)
    );
        defparam cell_iterator.NX = 6;
        defparam cell_iterator.NY = 6;

    // !!! if each cell color could be more than just black and white, This line should be updated
    wire [9:0] addr = cy*DIM + cx; // Similar as how we get memory address in c

    // TODO: Read MIF

    // (px, py) represent the physical pixel coordinate
    // 10bit/9bit must be enough for px/py, if it doesn't, that means something else is screwed up and make the cell outside of the physical screen
    wire [9:0] px = x + cx * SCALE_FACTOR;
    wire [8:0] py = y + cy * SCALE_FACTOR;

    // TODO: cell_color_decoder

    rect_drawer cell_drawer (
        .resetn(resetn),
        .clock(clock),
        .enable(rect_drawer_enable),
        .h(SCALE_FACTOR),
        .w(SCALE_FACTOR),
        .x(px),
        .y(py),
        .color(), // TODO:
        .done(rect_done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );
endmodule

// Translate color from 2bit codename to 3bit depth RGB value
// should be pure combinational logic
module cell_color_decoder(mem_value, color);
    input [1:0] mem_value;
    output [8:0] color;
    // TODO
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
    parameter IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10;
    // y: PS
    // Y: NS
    reg [1:0] y_Q, Y_Q;

    // last_column: 1 if column_counter reaches the last column
    // last_row: 1 if the row_couter reaches the last row
    wire last_column, last_row;
    // column_counter_enable: counter should work ONLY if the iterator is enabled AND it's in RUN state
    wire column_counter_enable = run & enable;
    wire row_counter_enable = column_counter_enable & last_column;
    counter column_counter (
        .resetn(resetn),
        .clock(clock),
        .init({NX{1'd0}}), // NX-bit of 0
        .limit(dimX - 1),
        .step({{NX-1{1'b0}}, 1'b1}), // 1
        .enable(column_counter_enable),
        .z(col),
        .pulse(last_column)
    );
        defparam column_counter.W = NX;

    counter row_counter (
        .resetn(resetn),
        .clock(clock),
        .init({NY{1'd0}}), // NX-bit of 0
        .limit(dimY - 1),
        .step({{NY-1{1'b0}}, 1'b1}), // 1
        .enable(row_counter_enable),
        .z(row),
        .pulse(last_row)
    );
        defparam  row_counter.W = NY;

    // Next state logic
    always @ (*) begin
        case(y_Q)
            IDLE: if(start) Y_Q = RUN; else Y_Q = y_Q;
            RUN: if(last_column & last_row & enable) Y_Q = DONE; else Y_Q = y_Q;
            DONE: Y_Q = IDLE;
            default: Y_Q = IDLE;
        endcase
    end

    always @ (posedge clock) begin
        if(!resetn)
            y_Q <= IDLE;
        else
            y_Q <= Y_Q;
    end

    // Output logic
    assign done = (y_Q == DONE);
    assign run = (y_Q == RUN);
endmodule
