-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
-- Date        : Fri Jul 12 19:46:49 2024
-- Host        : DESKTOP-5JNUKTK running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               f:/F_prj/ofdm/ofdm_tx/ofdm_tx.srcs/sources_1/ip/pll_clk/pll_clk_stub.vhdl
-- Design      : pll_clk
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z020clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pll_clk is
  Port ( 
    clk_7_5m : out STD_LOGIC;
    clk_20m : out STD_LOGIC;
    clk_60m : out STD_LOGIC;
    clk_80m : out STD_LOGIC;
    reset : in STD_LOGIC;
    locked : out STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end pll_clk;

architecture stub of pll_clk is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_7_5m,clk_20m,clk_60m,clk_80m,reset,locked,clk_in1";
begin
end;
