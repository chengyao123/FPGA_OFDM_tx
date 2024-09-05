vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xil_defaultlib

vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vcom -work xil_defaultlib -64 -93 \
"../../../../ofdm_tx.srcs/sources_1/ip/fft/sim/fft.vhd" \


vlog -work xil_defaultlib \
"glbl.v"

