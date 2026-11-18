`timescale 1ns / 1ns

// Pretends to be a PS/2 keyboard and checks keyboard (PS/2 IP) + key_decoder end to end
module keyboard_tb;
    localparam NONE = 4'b1111;
    localparam HALF = 40000; // half a PS/2 clock period in ns (12.5 kHz, like a real keyboard)

    reg clock = 1'b0;
    reg resetn = 1'b0;
    always #10 clock = ~clock; // 50 MHz

    // PS/2 lines are open-drain: the keyboard only pulls them low, a pull-up makes them 1
    tri1 ps2_clk, ps2_dat;
    reg clk_low = 1'b0;
    reg dat_low = 1'b0;
    assign ps2_clk = clk_low ? 1'b0 : 1'bz;
    assign ps2_dat = dat_low ? 1'b0 : 1'bz;

    wire [7:0] data;
    wire data_valid;
    wire [3:0] action;

    keyboard kb (
        .clock(clock),
        .resetn(resetn),
        .kb_clock_pin(ps2_clk),
        .kb_data_pin(ps2_dat),
        .data(data),
        .data_valid(data_valid)
    );

    key_decoder dec (
        .clock(clock),
        .data(data),
        .data_valid(data_valid),
        .action(action),
        .resetn(resetn)
    );

    // What the checkers expect to see, filled in by send()
    reg [7:0] sent_bytes [0:127];
    reg [3:0] expected   [0:127];
    integer n_sent = 0, n_expected = 0;
    integer n_bytes_seen = 0, n_actions_seen = 0;
    integer errors = 0;

    // Drives one 11-bit frame: start 0, data LSB first, odd parity, stop 1
    task send_frame(input [7:0] b);
        integer i;
        reg [10:0] frame;
        begin
            frame = {1'b1, ~^b, b, 1'b0};
            for (i = 0; i < 11; i = i + 1) begin
                dat_low = ~frame[i]; // change data while the clock is high
                #(HALF / 2);
                clk_low = 1'b1;
                #HALF;
                clk_low = 1'b0;
                #(HALF / 2);
            end
            dat_low = 1'b0;
            #(HALF * 2); // idle gap between bytes
        end
    endtask

    // Sends a byte and records what should come out (exp = NONE: no action expected)
    task send(input [7:0] b, input [3:0] exp);
        begin
            sent_bytes[n_sent] = b;
            n_sent = n_sent + 1;
            if (exp != NONE) begin
                expected[n_expected] = exp;
                n_expected = n_expected + 1;
            end
            send_frame(b);
        end
    endtask

    // Checks every byte the PS/2 IP hands out
    always @(posedge clock) begin
        if (resetn && data_valid) begin
            if (n_bytes_seen >= n_sent) begin
                $display("%t  ERROR: extra byte %h from the IP", $time, data);
                errors = errors + 1;
            end else if (data !== sent_bytes[n_bytes_seen]) begin
                $display("%t  ERROR: IP gave byte %h, expected %h", $time, data, sent_bytes[n_bytes_seen]);
                errors = errors + 1;
            end
            n_bytes_seen = n_bytes_seen + 1;
        end
    end

    // Checks every action pulse; a pulse longer than 1 cycle shows up as an extra action
    always @(posedge clock) begin
        if (resetn && action !== NONE) begin
            if (n_actions_seen >= n_expected) begin
                $display("%t  ERROR: unexpected action %b (byte %h)", $time, action, data);
                errors = errors + 1;
            end else if (action !== expected[n_actions_seen]) begin
                $display("%t  ERROR: action %b, expected %b (byte %h)", $time, action, expected[n_actions_seen], data);
                errors = errors + 1;
            end else
                $display("%t  byte %h -> action %b", $time, data, action);
            n_actions_seen = n_actions_seen + 1;
        end
    end

    initial begin
        #100 resetn = 1'b1;
        #1000;

        send(8'hAA, NONE);    // keyboard power-up self-test byte

        send(8'h1D, 4'b0000); // W press
        send(8'h1D, 4'b0000); // W held: typematic repeat
        send(8'hF0, NONE);
        send(8'h1D, 4'b1000); // W release
        send(8'h1D, 4'b0000); // W pressed again

        send(8'hE0, NONE);    // Up press
        send(8'h75, 4'b0000);
        send(8'hE0, NONE);    // Up release
        send(8'hF0, NONE);
        send(8'h75, 4'b1000);

        send(8'h1C, 4'b0001); // A press
        send(8'hF0, NONE);
        send(8'h1C, 4'b1001); // A release
        send(8'h1B, 4'b0010); // S press
        send(8'h23, 4'b0011); // D press
        send(8'h29, 4'b0100); // Space press
        send(8'hF0, NONE);
        send(8'h29, 4'b1100); // Space release

        send(8'hE0, NONE);    // Left press
        send(8'h6B, 4'b0001);
        send(8'hE0, NONE);    // Down press
        send(8'h72, 4'b0010);
        send(8'hE0, NONE);    // Right press
        send(8'h74, 4'b0011);

        send(8'h15, NONE);    // Q press: not a key we use
        send(8'hF0, NONE);
        send(8'h15, NONE);    // Q release
        send(8'h1D, 4'b0000); // W press: releasing must have cleared after Q

        send(8'hF0, NONE);    // reset halfway through a release...
        #1000 resetn = 1'b0;
        #100  resetn = 1'b1;
        #1000;
        send(8'h1D, 4'b0000); // ...so this 1D is a press, not a release

        #(HALF * 4);
        if (n_bytes_seen != n_sent) begin
            $display("ERROR: IP gave %0d bytes, sent %0d", n_bytes_seen, n_sent);
            errors = errors + 1;
        end
        if (n_actions_seen != n_expected) begin
            $display("ERROR: saw %0d actions, expected %0d", n_actions_seen, n_expected);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: %0d bytes, %0d actions, all correct", n_sent, n_expected);
        else
            $display("FAIL: %0d errors", errors);
        $stop;
    end
endmodule
