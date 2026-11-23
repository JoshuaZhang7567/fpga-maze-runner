onerror {resume}

# state and direction names instead of numbers
virtual type {IDLE CLEAR PUSH_START WAIT POP ADDR CHECK DONE FAIL} bfs_state_t
virtual type {N S E W} bfs_dir_t
virtual function -install /testbench/dut {(bfs_state_t)/testbench/dut/current_state} current_state_name
virtual function -install /testbench/dut {(bfs_state_t)/testbench/dut/next_state} next_state_name
virtual function -install /testbench/dut {(bfs_dir_t)/testbench/dut/dir} dir_name

quietly WaveActivateNextPane {} 0

add wave -noupdate -divider Testbench
add wave -noupdate -label clock /testbench/clock
add wave -noupdate -label resetn /testbench/resetn
add wave -noupdate -label pulse_count -radix unsigned /testbench/pulse_count
add wave -noupdate -label half_second_pulse /testbench/half_second_pulse
add wave -noupdate -label start /testbench/start
add wave -noupdate -label algorithm /testbench/algorithm
add wave -noupdate -label start_cell -radix unsigned /testbench/start_cell
add wave -noupdate -label success /testbench/success
add wave -noupdate -label fail /testbench/fail
add wave -noupdate -label cycles -radix unsigned /testbench/cycles
add wave -noupdate -label pushes -radix unsigned /testbench/pushes
add wave -noupdate -label visited_writes -radix unsigned /testbench/visited_writes

add wave -noupdate -divider {bfs_dfs FSM}
add wave -noupdate -label current_state /testbench/dut/current_state_name
add wave -noupdate -label current_state(raw) -radix unsigned /testbench/dut/current_state
add wave -noupdate -label next_state /testbench/dut/next_state_name
add wave -noupdate -label next_state(raw) -radix unsigned /testbench/dut/next_state
add wave -noupdate -label found /testbench/dut/found

add wave -noupdate -divider {bfs_dfs cells}
add wave -noupdate -label popped -radix unsigned /testbench/dut/popped
add wave -noupdate -label x -radix unsigned /testbench/dut/x
add wave -noupdate -label y -radix unsigned /testbench/dut/y
add wave -noupdate -label dir /testbench/dut/dir_name
add wave -noupdate -label dir(raw) -radix unsigned /testbench/dut/dir
add wave -noupdate -label nb -radix unsigned /testbench/dut/nb
add wave -noupdate -label nb_x -radix unsigned /testbench/nb_x
add wave -noupdate -label nb_y -radix unsigned /testbench/nb_y
add wave -noupdate -label nb_inside /testbench/dut/nb_inside

add wave -noupdate -divider {FIFO (fifo_1024x10)}
add wave -noupdate -label sclr /testbench/fifo/sclr
add wave -noupdate -label wrreq /testbench/fifo/wrreq
add wave -noupdate -label data -radix unsigned /testbench/fifo/data
add wave -noupdate -label rdreq /testbench/fifo/rdreq
add wave -noupdate -label q -radix unsigned /testbench/fifo/q
add wave -noupdate -label empty /testbench/fifo/empty
add wave -noupdate -label full /testbench/fifo/full
add wave -noupdate -label usedw -radix unsigned /testbench/fifo/usedw

add wave -noupdate -divider {maze_ram port A (bfs_dfs)}
add wave -noupdate -label address_a -radix unsigned /testbench/ram/address_a
add wave -noupdate -label wren_a /testbench/ram/wren_a
add wave -noupdate -label data_a -radix binary /testbench/ram/data_a
add wave -noupdate -label q_a -radix binary /testbench/ram/q_a

add wave -noupdate -divider {maze_ram port B (testbench)}
add wave -noupdate -label address_b -radix unsigned /testbench/ram/address_b
add wave -noupdate -label wren_b /testbench/ram/wren_b
add wave -noupdate -label data_b -radix binary /testbench/ram/data_b
add wave -noupdate -label q_b -radix binary /testbench/ram/q_b

add wave -noupdate -divider {bfs_dfs parameters}
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/BFS
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/DFS
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/IDLE
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/CLEAR
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/PUSH_START
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/WAIT
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/POP
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/ADDR
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/CHECK
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/DONE
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/FAIL
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/N
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/S
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/E
add wave -noupdate -group {bfs_dfs parameters} -radix unsigned /testbench/dut/W

add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_WALL
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_OPEN
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_START
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_GOAL
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_VISITED
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_CURRENT
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CODE_PATH
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/WALL
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/OPEN
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/START
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/GOAL
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/VISITED
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/CURRENT
add wave -noupdate -group {colour codes (wall_codes.vh)} -radix binary /testbench/dut/PATH

add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/CLOCK_PERIOD
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/PULSE_EVERY
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/START_X
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/START_Y
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/GOAL_X
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/GOAL_Y
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/PLACE_GOAL
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/ALGORITHM
add wave -noupdate -group {testbench parameters} -radix unsigned /testbench/TIMEOUT

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 160
configure wave -valuecolwidth 80
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
