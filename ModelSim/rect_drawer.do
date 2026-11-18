# Run from the ModelSim/ folder in ModelSim:  do rect_drawer.do
vlib work
vlog ../counter.v ../monitor/monitor.v tb_rect_drawer.v
vsim work.tb_rect_drawer

add wave -divider inputs
add wave tb_rect_drawer/clock tb_rect_drawer/resetn tb_rect_drawer/enable
add wave -unsigned tb_rect_drawer/x tb_rect_drawer/y tb_rect_drawer/w tb_rect_drawer/h
add wave -binary tb_rect_drawer/color
add wave -divider iterator
add wave -unsigned tb_rect_drawer/dut/rect_iterator/y_Q
add wave -unsigned tb_rect_drawer/dut/dx tb_rect_drawer/dut/dy
add wave -divider outputs
add wave tb_rect_drawer/vga_write
add wave -unsigned tb_rect_drawer/vga_x tb_rect_drawer/vga_y
add wave -binary tb_rect_drawer/vga_color
add wave tb_rect_drawer/done

run -all
wave zoom full
