// paint a w*h rectangle to vga display
module rect_painter(resetn, clock, enable, h, w, x, y, color, done, vga_x, vga_y, vga_color, vga_write);
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

    // 1 if done painting, 0 if not
    output reg done;

    output [9:0] vga_x;
    output [8:0] vga_y;
    output [8:0] vga_color;
    output reg vga_write;

    // FSM States
    parameter IDLE = 2'b00, DRAW_LINE = 2'b01, NEXT_LINE = 2'b10, DONE = 2'b11;
    // y: PS
    // Y: NS
    reg [1:0] y_Q, Y_Q;

    // =1 while the column_counter finishes a row
    reg r_enable, c_enable;
    wire last_row, last_column;

    // the x, y offset produced by the counters
    wire [9:0] dx;
    wire [8:0] dy;

    assign vga_color = color;
    assign vga_x = x + dx;
    assign vga_y = y + dy;

    counter column_counter (
        .resetn(resetn),
        .clock(clock),
        .init(10'd0),
        .limit(w - 1),
        .step(10'd1),
        .enable(c_enable),
        .z(dx),
        .pulse(last_column)
    );
        defparam column_counter.W = 10;

    counter row_counter (
        .resetn(resetn),
        .clock(clock),
        .init(9'd0),
        .limit(h - 1),
        .step(9'd1),
        .enable(r_enable),
        .z(dy),
        .pulse(last_row)
    );
        defparam  row_counter.W = 9;

    // Next state logic
    always @ (*) begin
        case(y_Q)
            IDLE: if(enable) Y_Q = DRAW_LINE; else Y_Q = y_Q;
            DRAW_LINE: if(last_column) Y_Q = NEXT_LINE; else Y_Q = y_Q;
            NEXT_LINE: if(last_row) Y_Q = DONE; else Y_Q = DRAW_LINE;
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
    always @ (*) begin
        case(y_Q)
            IDLE: begin
                done = 1'b0;
                r_enable = 1'b0;
                c_enable = 1'b0;
                vga_write = 1'b0;
            end
            DRAW_LINE: begin
                done = 1'b0;
                r_enable = 1'b0;
                c_enable = 1'b1; // next column
                vga_write = 1'b1;
            end
            NEXT_LINE: begin
                done = 1'b0;
                r_enable = 1'b1; // next row
                c_enable = 1'b0;
                vga_write = 1'b0;
            end
            DONE: begin
                done = 1'b1;
                r_enable = 1'b0;
                c_enable = 1'b0;
                vga_write = 1'b0;
            end
            default: begin
                done = 1'b0;
                r_enable = 1'b0;
                c_enable = 1'b0;
                vga_write = 1'b0;
            end
        endcase
    end
endmodule

