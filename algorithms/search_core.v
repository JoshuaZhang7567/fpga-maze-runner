module search_core(clock, resetn, start, algorithm, start_cell, current_cell, success, fail,
                   maze_addr, maze_data, maze_wren, maze_cell_code);
    parameter WAIT_CYCLES = 25_000_000;

    input clock, resetn;

    // start: 1 for (at least) one cycle to start a new search from start_cell
    // algorithm: BFS = 0, DFS = 1
    input start, algorithm;
    input [9:0] start_cell;

    // current_cell: the cell being expanded, for the top level to highlight
    // success: stays 1 once the goal is found; fail: stays 1 once every reachable cell was visited
    output [9:0] current_cell;
    output success, fail;

    // maze_ram port A
    output [13:0] maze_addr;
    output [2:0] maze_data;
    output maze_wren;
    input [2:0] maze_cell_code;

    wire wait_counter_pulse;
    counter #(.W(25)) wait_counter (
        .resetn(resetn),
        .clock(clock),
        .init(25'd0),
        .limit(WAIT_CYCLES - 1),
        .step(25'd1),
        .enable(1'b1),
        .z(),
        .pulse(wait_counter_pulse)
    );

    wire fifo_sclr, fifo_rdreq, fifo_wrreq, fifo_empty;
    wire [9:0] fifo_data, fifo_q;
    fifo_1024x10 queue (
        .clock(clock),
        .data(fifo_data),
        .rdreq(fifo_rdreq),
        .sclr(fifo_sclr),
        .wrreq(fifo_wrreq),
        .empty(fifo_empty),
        .full(),
        .q(fifo_q),
        .usedw()
    );

    bfs_dfs bfs (
        .clock(clock),
        .resetn(resetn),
        .half_second_pulse(wait_counter_pulse),
        .start(start),
        .algorithm(algorithm),
        .start_cell(start_cell),
        .current_cell(current_cell),
        .success(success),
        .fail(fail),
        .fifo_sclr(fifo_sclr),
        .fifo_rdreq(fifo_rdreq),
        .fifo_wrreq(fifo_wrreq),
        .fifo_data(fifo_data),
        .fifo_q(fifo_q),
        .empty(fifo_empty),
        .address_a(maze_addr),
        .data_a(maze_data),
        .wren_a(maze_wren),
        .q_a(maze_cell_code)
    );
endmodule
