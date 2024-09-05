set_property SRC_FILE_INFO {cfile:f:/F_prj/ofdm/ofdm_tx/ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk.xdc rfile:../../../ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.2
