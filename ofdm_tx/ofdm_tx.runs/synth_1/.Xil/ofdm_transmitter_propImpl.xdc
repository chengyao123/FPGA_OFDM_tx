set_property SRC_FILE_INFO {cfile:F:/F_prj/ofdm_7.12/ofdm_tx/ofdm_tx.srcs/constrs_1/new/time.xdc rfile:../../../ofdm_tx.srcs/constrs_1/new/time.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:1 export:INPUT save:INPUT read:READ} [current_design]
set_false_path -reset_path -from [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT1]]
set_property src_info {type:XDC file:1 line:2 export:INPUT save:INPUT read:READ} [current_design]
set_false_path -reset_path -from [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT2]]
set_property src_info {type:XDC file:1 line:3 export:INPUT save:INPUT read:READ} [current_design]
set_false_path -reset_path -from [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT3]]
set_property src_info {type:XDC file:1 line:4 export:INPUT save:INPUT read:READ} [current_design]
set_false_path -reset_path -from [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT2]] -to [get_clocks -of_objects [get_pins u_pll/inst/mmcm_adv_inst/CLKOUT0]]
