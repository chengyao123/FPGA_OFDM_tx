vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xil_defaultlib

vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xil_defaultlib -64 -incr "+incdir+../../../ipstatic" \
"../../../../ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk_clk_wiz.v" \
"../../../../ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk.v" \


vlog -work xil_defaultlib \
"glbl.v"

