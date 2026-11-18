// Board test for the keyboard module (DE1-SoC)
//   LEDR[7:0] = last byte received, in binary (e.g. W pressed -> 0001_1101 = 1D)
//   LEDR[9]   = flips every time a byte arrives
//   KEY[0]    = reset (hold down to reset)
module keyboard_test(CLOCK_50, KEY, PS2_CLK, PS2_DAT, LEDR);
    input CLOCK_50;
    input [3:0] KEY;            // all 4 declared to match the .qsf; only KEY[0] used
    inout PS2_CLK, PS2_DAT;
    output [9:0] LEDR;

    wire [7:0] data;
    wire data_valid;

    // Named connections: .port(signal) - can't be mixed up if keyboard's
    // port order ever changes
    keyboard_ps2 k (
        .clock(CLOCK_50),
        .resetn(KEY[0]),
        .kb_clock_pin(PS2_CLK),
        .kb_data_pin(PS2_DAT),
        .data(data),
        .data_valid(data_valid)
    );

    // 'data' is only guaranteed correct on the cycle data_valid is 1,
    // so catch it in a register then. data_valid is the register's enable.
    reg [7:0] last_byte;

    // data_valid lasts 20 ns - too short to see on an LED. Flipping a
    // register on each pulse leaves a visible change behind.
    reg toggle;

    always @ (posedge CLOCK_50) begin
        if (!KEY[0]) begin
            last_byte <= 8'h00;
            toggle    <= 1'b0;
        end else if (data_valid) begin
            last_byte <= data;
            toggle    <= ~toggle;
        end
    end

    assign LEDR[7:0] = last_byte;
    assign LEDR[8]   = 1'b0;
    assign LEDR[9]   = toggle;
endmodule
