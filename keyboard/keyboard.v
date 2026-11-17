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

// Translate the bytes from keyboard ip into one-cycle pulses of WASD, Enter
module key_decoder(clock, resetn, kb_data, kb_valid, w_pressed, a_pressed, s_pressed, d_pressed, enter_pressed);
    input clock, resetn;
    input [7:0] kb_data;
    input kb_valid;
    output reg w_pressed, a_pressed, s_pressed, d_pressed, enter_pressed;

    parameter SCAN_W     = 8'h1D;
    parameter SCAN_A     = 8'h1C;
    parameter SCAN_S     = 8'h1B;
    parameter SCAN_D     = 8'h23;
    parameter SCAN_ENTER = 8'h5A;
    parameter SCAN_BREAK = 8'hF0; // keyboard is not pressed anymore

    // skip_next: 1 if the next byte should be skipped (it follows F0)
    reg skip_next;

    always @ (posedge clock) begin
        if(!resetn) begin
            skip_next <= 1'b0;
            w_pressed <= 1'b0;
            a_pressed <= 1'b0;
            s_pressed <= 1'b0;
            d_pressed <= 1'b0;
            enter_pressed <= 1'b0;
        end
        else begin
            // default value here
            w_pressed <= 1'b0;
            a_pressed <= 1'b0;
            s_pressed <= 1'b0;
            d_pressed <= 1'b0;
            enter_pressed <= 1'b0;
            // only update while keyboard is producing valid output
            if(kb_valid) begin
                case(kb_data)
                    // F0: the byte after it should be skipped
                    SCAN_BREAK: skip_next <= 1'b1;
                    default: begin
                        if(skip_next)
                            skip_next <= 1'b0; // skipped 1 cycle, restore the state to 0 here
                        else begin
                            case(kb_data)
                                SCAN_W: w_pressed <= 1'b1;
                                SCAN_A: a_pressed <= 1'b1;
                                SCAN_S: s_pressed <= 1'b1;
                                SCAN_D: d_pressed <= 1'b1;
                                SCAN_ENTER: enter_pressed <= 1'b1;
                                default: ; // we only care about WASD, Enter
                            endcase
                        end
                    end
                endcase
            end
        end
    end
endmodule

