// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Thu Jul 11 19:54:48 2024
// Host        : DESKTOP-5JNUKTK running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               f:/F_prj/ofdm/ofdm_tx/ofdm_tx.srcs/sources_1/ip/fifo_asyn/fifo_asyn_stub.v
// Design      : fifo_asyn
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_3,Vivado 2018.3" *)
module fifo_asyn(wr_clk, rd_clk, din, wr_en, rd_en, dout, full, empty, 
  rd_data_count)
/* synthesis syn_black_box black_box_pad_pin="wr_clk,rd_clk,din[15:0],wr_en,rd_en,dout[15:0],full,empty,rd_data_count[6:0]" */;
  input wr_clk;
  input rd_clk;
  input [15:0]din;
  input wr_en;
  input rd_en;
  output [15:0]dout;
  output full;
  output empty;
  output [6:0]rd_data_count;
endmodule
