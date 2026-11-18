`timescale 1ns / 1ns

// Testbench for rect_drawer (monitor/monitor.v)
//   Test 1: draw a 4x3 rectangle at (10, 20)
//   Test 2: draw a 2x2 rectangle at (100, 50) with another color (checks that it can restart)
// For every pixel written we check that it is inside the rectangle, has the right color
// and is written exactly once. At the end the number of pixels must be w*h and done must pulse.
module tb_rect_drawer;
    reg clock, resetn, enable;
    reg [8:0] h;
    reg [9:0] w;
    reg [9:0] x;
    reg [8:0] y;
    reg [8:0] color;

    wire done, vga_write;
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;

    rect_drawer dut (
        .resetn(resetn),
        .clock(clock),
        .enable(enable),
        .h(h),
        .w(w),
        .x(x),
        .y(y),
        .color(color),
        .done(done),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_color(vga_color),
        .vga_write(vga_write)
    );

    // 50 MHz clock
    initial clock = 1'b0;
    always #10 clock = ~clock;

    // hit[dy][dx] = how many times pixel (x+dx, y+dy) was written in the current test
    integer hit [0:15][0:15];
    integer n_pixels, n_errors, i, j;

    // Watch the VGA side on every clock edge
    always @ (posedge clock) begin
        if (resetn && vga_write) begin
            $display("  t=%0t  write (%0d, %0d) color=%b", $time, vga_x, vga_y, vga_color);
            n_pixels = n_pixels + 1;
            if (vga_x < x || vga_x >= x + w || vga_y < y || vga_y >= y + h) begin
                $display("  ERROR: pixel (%0d, %0d) is outside the rectangle", vga_x, vga_y);
                n_errors = n_errors + 1;
            end else begin
                hit[vga_y - y][vga_x - x] = hit[vga_y - y][vga_x - x] + 1;
            end
            if (vga_color !== color) begin
                $display("  ERROR: color %b, expected %b", vga_color, color);
                n_errors = n_errors + 1;
            end
        end
    end

    // Draw one rectangle and check the result
    task draw_rect(input [9:0] tw, input [8:0] th, input [9:0] tx, input [8:0] ty, input [8:0] tcolor);
        integer timeout;
        begin
            $display("Drawing %0dx%0d rectangle at (%0d, %0d), color %b", tw, th, tx, ty, tcolor);
            w = tw; h = th; x = tx; y = ty; color = tcolor;
            n_pixels = 0;
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1)
                    hit[i][j] = 0;

            // one-cycle start pulse
            @(negedge clock) enable = 1'b1;
            @(negedge clock) enable = 1'b0;

            // wait for done (with a timeout in case it never comes)
            timeout = 0;
            while (!done && timeout < 1000) begin
                @(negedge clock);
                timeout = timeout + 1;
            end
            if (!done) begin
                $display("  ERROR: done never went high");
                n_errors = n_errors + 1;
            end
            @(negedge clock);
            if (done) begin
                $display("  ERROR: done should only be high for one cycle");
                n_errors = n_errors + 1;
            end

            if (n_pixels != tw * th) begin
                $display("  ERROR: %0d pixels written, expected %0d", n_pixels, tw * th);
                n_errors = n_errors + 1;
            end
            for (i = 0; i < th; i = i + 1)
                for (j = 0; j < tw; j = j + 1)
                    if (hit[i][j] != 1) begin
                        $display("  ERROR: pixel (%0d, %0d) written %0d times", tx + j, ty + i, hit[i][j]);
                        n_errors = n_errors + 1;
                    end
            $display("  %0d pixels written", n_pixels);

            repeat (5) @(negedge clock);
            if (vga_write) begin
                $display("  ERROR: vga_write is still high after done");
                n_errors = n_errors + 1;
            end
        end
    endtask

    initial begin
        n_errors = 0;
        n_pixels = 0;
        enable = 1'b0;
        w = 0; h = 0; x = 0; y = 0; color = 0;

        resetn = 1'b0;
        repeat (3) @(negedge clock);
        resetn = 1'b1;
        repeat (2) @(negedge clock);

        draw_rect(10'd4, 9'd3, 10'd10, 9'd20, 9'b111_000_111);  // violet
        draw_rect(10'd2, 9'd2, 10'd100, 9'd50, 9'b000_111_000); // green

        if (n_errors == 0) $display("PASS: rect_drawer works");
        else               $display("FAIL: %0d error(s)", n_errors);
        $stop;
    end
endmodule
