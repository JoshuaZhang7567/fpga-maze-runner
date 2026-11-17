module keyboard(clock, resetn, kb_clock_pin, kb_data_pin, data, data_valid);

	input clock, resetn;
	output [7:0] data;
	output data_valid;
	inout kb_clock_pin, kb_data_pin;
	
	ps2_ip u0 (
		.ps2_0_PS2_CLK       (kb_clock_pin),       //      ps2_0_external_interface.CLK
		.ps2_0_PS2_DAT       (kb_data_pin),       //                              .DAT
		.ps2_0_command       (8'b0000_0000),       // ps2_0_avalon_ps2_command_sink.data
		.ps2_0_command_valid (1'b0), //                              .valid
		.ps2_0_command_ready (), //                              .ready
		.ps2_0_data_ready    (1'b1),    //  ps2_0_avalon_ps2_data_source.ready
		.ps2_0_data          (data),          //                              .data
		.ps2_0_data_valid    (data_valid),    //                              .valid
		.clk_clk             (clock),             //                           clk.clk
		.reset_reset_n       (resetn)        //                         reset.reset_n
	);
endmodule
