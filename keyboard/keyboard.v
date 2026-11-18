module keyboard(clock, resetn, kb_clock_pin, kb_data_pin, action);
    input clock, resetn;
	inout kb_clock_pin, kb_data_pin;
    output [3:0] action;

    wire data_valid;
    wire [7:0] data;

    // Interface with the PS/2 keyboard
    keyboard_ps2 ps2(.clock(clock),
                     .resetn(resetn),
                     .kb_clock_pin(kb_clock_pin), 
                     .kb_data_pin(kb_data_pin), 
                     .data(data), 
                     .data_valid(data_valid));

    // Decode the data coming from the keyboard
    key_decoder decoder(.clock(clock), 
                        .data(data), .data_valid(data_valid), 
                        .action(action), 
                        .resetn(resetn));

endmodule