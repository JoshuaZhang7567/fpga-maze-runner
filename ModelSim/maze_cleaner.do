# Run from the ModelSim/ folder in ModelSim:  do maze_cleaner.do
vlib work
vlog ../counter.v ../monitor/monitor.v tb_maze_cleaner.v
vsim work.tb_maze_cleaner

add wave -divider inputs
add wave tb_maze_cleaner/clock tb_maze_cleaner/resetn tb_maze_cleaner/start
add wave -divider "cell iterator"
add wave -unsigned tb_maze_cleaner/dut/cell_iterator/current_state
add wave tb_maze_cleaner/dut/phase
add wave -unsigned tb_maze_cleaner/dut/cx tb_maze_cleaner/dut/cy
add wave -divider ram
add wave -unsigned tb_maze_cleaner/maze_addr
add wave -binary tb_maze_cleaner/maze_q
add wave tb_maze_cleaner/dut/dirty
add wave tb_maze_cleaner/maze_wren
add wave -binary tb_maze_cleaner/maze_data
add wave -divider output
add wave tb_maze_cleaner/done

run -all
wave zoom full
