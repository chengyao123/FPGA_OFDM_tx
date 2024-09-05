// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Fri Jul 12 19:46:49 2024
// Host        : DESKTOP-5JNUKTK running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               f:/F_prj/ofdm/ofdm_tx/ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk_stub.v
// Design      : pll_clk
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module pll_clk(clk_7_5m, clk_20m, clk_60m, clk_80m, reset, locked, 
  clk_in1)
/* synthesis syn_black_box black_box_pad_pin="clk_7_5m,clk_20m,clk_60m,clk_80m,reset,locked,clk_in1" */;
  output clk_7_5m;
  output clk_20m;
  output clk_60m;
  output clk_80m;
  input reset;
  output locked;
  input clk_in1;
endmodule
