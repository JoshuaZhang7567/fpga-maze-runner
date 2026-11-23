# In ModelSim: cd to algorithms/bfs-dfs/testbench, then type: do testbench.tcl

# stop any simulation that is currently running
quit -sim

# create the default "work" library
vlib work

# maze_ram loads MAZE_1.mif from the folder ModelSim runs in
file copy -force ../../../MAZE_1.mif .

# +incdir+..       : bfs-dfs.v's `include "../../wall_codes.vh" is found from its own folder
# +incdir+../../.. : testbench.v's `include "wall_codes.vh" is found in the repo root
# -timescale       : gives files without a `timescale line a default (avoids error vsim-3009)
vlog -timescale 1ns/1ps +incdir+.. +incdir+../../.. ../bfs-dfs.v
vlog -timescale 1ns/1ps ../../../maze_ram.v
vlog -timescale 1ns/1ps ../../../data-structures/fifo/fifo_1024x10.v
vlog -timescale 1ns/1ps +incdir+.. +incdir+../../.. testbench.v

# start the Simulator; +acc keeps internal registers and wires visible in the wave window
vsim -voptargs="+acc" work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog

# show waveforms specified in wave.do
do wave.do

# run until the testbench calls $stop
run -all
wave zoom full
