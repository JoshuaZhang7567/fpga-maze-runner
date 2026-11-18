# In ModelSim/Questa: cd to keyboard/testbench, then type: do keyboard_tb.do
vlib work

# -timescale gives files without a `timescale line a default (avoids error vsim-3009)
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/altera_reset_synchronizer.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/altera_reset_controller.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/altera_up_ps2_data_in.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/altera_up_ps2_command_out.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/altera_up_ps2.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/submodules/ps2_ip_ps2_0.v
vlog -timescale 1ns/1ns ../ps2_ip/synthesis/ps2_ip.v
vlog -timescale 1ns/1ns ../keyboard.v
vlog -timescale 1ns/1ns ../key_decoder.v
vlog -timescale 1ns/1ns keyboard_tb.v

# altera_mf_ver holds Intel's scfifo, which the PS/2 IP uses for its byte FIFO
vsim -L altera_mf_ver keyboard_tb

add wave /keyboard_tb/clock
add wave /keyboard_tb/resetn
add wave /keyboard_tb/ps2_clk
add wave /keyboard_tb/ps2_dat
add wave -radix hex /keyboard_tb/data
add wave /keyboard_tb/data_valid
add wave /keyboard_tb/dec/releasing
add wave -radix binary /keyboard_tb/action

run -all
wave zoom full
