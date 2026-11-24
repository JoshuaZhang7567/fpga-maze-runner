# Run from the ModelSim/ folder in ModelSim:  do maze_drawer.do
vlib work
vlog ../counter.v ../monitor/monitor.v tb_maze_drawer.v
vsim work.tb_maze_drawer

add wave -divider inputs
add wave tb_maze_drawer/clock tb_maze_drawer/resetn tb_maze_drawer/enable
add wave -divider "cell iterator"
add wave -unsigned tb_maze_drawer/dut/cell_iterator/current_state
add wave -unsigned tb_maze_drawer/dut/cx tb_maze_drawer/dut/cy
add wave -unsigned tb_maze_drawer/maze_addr
add wave -binary tb_maze_drawer/maze_q
add wave tb_maze_drawer/dut/rect_drawer_enable tb_maze_drawer/dut/rect_done
add wave -divider outputs
add wave tb_maze_drawer/vga_write
add wave -unsigned tb_maze_drawer/vga_x tb_maze_drawer/vga_y
add wave -binary tb_maze_drawer/vga_color
add wave tb_maze_drawer/done

run -all
wave zoom full
