`timescale 1ns / 1ps

// Testbench for bfs_dfs with the real maze_ram (MAZE_1.mif) and fifo_1024x10
// Port B of maze_ram belongs to the testbench: it writes START and GOAL before the search
module testbench ( );

    `include "wall_codes.vh"

    parameter CLOCK_PERIOD = 10;
    parameter PULSE_EVERY  = 4;      // half_second_pulse every 4 clocks instead of every 0.5 s
    parameter START_X = 1, START_Y = 1;
    parameter GOAL_X  = 7, GOAL_Y  = 7; // 12 steps from (1, 1); (29, 29) is 124 steps away
    parameter PLACE_GOAL = 1;        // 0 = no goal: should FAIL after visiting all 462 other open cells
    parameter ALGORITHM  = 1'b0;     // 0 = BFS, 1 = DFS
    parameter TIMEOUT    = 100000;   // clock cycles

    // bfs_dfs inputs
    reg resetn, start, algorithm;
    reg [9:0] start_cell;

    // clock
    reg clock;
    initial clock = 1'b0;
    always #(CLOCK_PERIOD / 2) clock = ~clock;

    // half_second_pulse: 1 for one clock cycle every PULSE_EVERY clocks
    reg [7:0] pulse_count;
    wire half_second_pulse = (pulse_count == PULSE_EVERY - 1);
    always @(posedge clock)
        if (!resetn || half_second_pulse) pulse_count <= 8'd0;
        else                              pulse_count <= pulse_count + 8'd1;

    // bfs_dfs outputs
    wire success, fail;

    // bfs_dfs <-> fifo_1024x10
    wire fifo_sclr, fifo_rdreq, fifo_wrreq;
    wire [9:0] fifo_data, fifo_q, fifo_usedw;
    wire empty, full;

    // bfs_dfs <-> maze_ram port A
    wire [13:0] address_a;
    wire [2:0] data_a, q_a;
    wire wren_a;

    // testbench <-> maze_ram port B
    reg [13:0] address_b;
    reg [2:0] data_b;
    reg wren_b;
    wire [2:0] q_b;

    bfs_dfs dut (
        .clock(clock),
        .resetn(resetn),
        .half_second_pulse(half_second_pulse),
        .start(start),
        .algorithm(algorithm),
        .start_cell(start_cell),
        .success(success),
        .fail(fail),
        .fifo_sclr(fifo_sclr),
        .fifo_rdreq(fifo_rdreq),
        .fifo_wrreq(fifo_wrreq),
        .fifo_data(fifo_data),
        .fifo_q(fifo_q),
        .empty(empty),
        .address_a(address_a),
        .data_a(data_a),
        .wren_a(wren_a),
        .q_a(q_a)
    );

    fifo_1024x10 fifo (
        .clock(clock),
        .data(fifo_data),
        .rdreq(fifo_rdreq),
        .sclr(fifo_sclr),
        .wrreq(fifo_wrreq),
        .empty(empty),
        .full(full),
        .q(fifo_q),
        .usedw(fifo_usedw)
    );

    maze_ram ram (
        .clock(clock),
        .address_a(address_a),
        .data_a(data_a),
        .wren_a(wren_a),
        .q_a(q_a),
        .address_b(address_b),
        .data_b(data_b),
        .wren_b(wren_b),
        .q_b(q_b)
    );

    // (x, y) of the neighbour, for the wave window only (simulation-only hierarchical references)
    wire [4:0] nb_x = dut.nb[4:0];
    wire [4:0] nb_y = dut.nb[9:5];

    // pushes and VISITED writes done by bfs_dfs, counted for the summary
    integer pushes, visited_writes, cycles;
    always @(posedge clock) begin
        if (!resetn) begin
            pushes <= 0;
            visited_writes <= 0;
        end else begin
            if (fifo_wrreq) pushes <= pushes + 1;
            if (wren_a)     visited_writes <= visited_writes + 1;
        end
    end

    // write one cell through port B (inputs change on the falling edge, RAM writes on the rising edge)
    task write_cell(input [4:0] x, input [4:0] y, input [2:0] code);
        begin
            @(negedge clock);
            address_b = {4'd0, y, x};
            data_b    = code;
            wren_b    = 1'b1;
            @(negedge clock);
            wren_b    = 1'b0;
        end
    endtask

    initial begin
        resetn     = 1'b0;
        start      = 1'b0;
        algorithm  = ALGORITHM;
        start_cell = {START_Y[4:0], START_X[4:0]};
        address_b  = 14'd0;
        data_b     = 3'd0;
        wren_b     = 1'b0;

        // reset
        repeat (3) @(negedge clock);
        resetn = 1'b1;

        // place START and GOAL in the maze
        write_cell(START_X, START_Y, CODE_START);
        if (PLACE_GOAL) write_cell(GOAL_X, GOAL_Y, CODE_GOAL);

        // start the search: 1 for one clock cycle
        @(negedge clock);
        start = 1'b1;
        @(negedge clock);
        start = 1'b0;

        // wait for success or fail
        cycles = 0;
        while (!success && !fail && cycles < TIMEOUT) begin
            @(posedge clock);
            cycles = cycles + 1;
        end

        if (success)   $display("SUCCESS after %0d cycles", cycles);
        else if (fail) $display("FAIL after %0d cycles", cycles);
        else           $display("TIMEOUT: no success or fail after %0d cycles", cycles);
        $display("pushes = %0d, VISITED writes = %0d", pushes, visited_writes);

        repeat (5) @(posedge clock);
        $stop;
    end

endmodule
