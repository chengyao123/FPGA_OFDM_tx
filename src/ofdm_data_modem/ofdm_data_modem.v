/*
    signal  1/2码率  BPSK调制
        24bit--48
        60M->80M->20M
    data    3/4码率  16-QAM调制
        144bit--288--192--48
        60-->120-->80-->20
*/

module ofdm_data_modem 
#(
    parameter  SIGNAL_INTV_TO_QAM_FRE = 4
)
(
    input           sys_clk     , //20M
    input           din_clk     , //60M
    input           cb_clk      , //80M
    input           rst_n       ,
    //control signal
    input           tx_clr      ,
    input   [3:0]   rate_con    ,
    input           signal_flag ,
    input   [6:0]   scram_seed  ,
    //data signal
    input           data_bit    ,
    input           data_bit_vld,
    output  [7:0]   dout_re     ,
    output  [7:0]   dout_im     ,
    output          dout_vld    
);

//1.扰码
wire    scram_din;
wire    scram_en;
wire    signal_flag_scram;
wire    scram_dout;     
wire    scram_vld; 

assign  scram_din = data_bit;
assign  scram_en = data_bit_vld;

data_scramler u_scram
(
    .clk                (sys_clk            ), //20Mhz
    .rst_n              (rst_n              ),

    .scram_din          (scram_din          ),
    .scram_en           (scram_en           ),
    .scram_seed         (scram_seed         ), //移位寄存器初始化向量
    .tx_clr             (tx_clr             ), //扰码初始化
    .singal_flag_in     (signal_flag        ),
    .signal_flag_out    (signal_flag_scram  ),
    .scram_dout         (scram_dout         ),
    .scram_vld          (scram_vld          )
);

//2.卷积编码

wire        conv_din;
wire        conv_en;
wire        signal_flag_conv;
wire [1:0]  conv_dout;       
wire        conv_vld;        

assign  conv_din = scram_dout;
assign  conv_en = scram_vld;

data_conv_code u_conv_code
(
    .din_clk            (din_clk            ),//60Mhz
    .rst_n              (rst_n              ),

    .singal_flag_in     (signal_flag_scram  ),
    .conv_din           (conv_din           ),//bit输入 lsb在前，msb在后
    .conv_en            (conv_en            ),
    .signal_flag_out    (signal_flag_conv   ),
    .conv_dout          (conv_dout          ),
    .conv_vld           (conv_vld           )
);

//3.删余

wire [1:0]  punt_din;
wire        punt_en;
wire [1:0]  symbol_len_con;
wire        signal_flag_punt;
wire        punt_dout;
wire        punt_vld;

assign  punt_din = conv_dout;
assign  punt_en = conv_vld;

data_puncturing u_punt
(
    .din_clk            (din_clk            ),//60Mhz
    .cb_clk             (cb_clk             ),//80Mhz
    .rst_n              (rst_n              ),

    .rate_con           (rate_con           ),
    .singal_flag_in     (signal_flag_conv   ),
    .punt_din           (punt_din           ),//bit输入 lsb在前，msb在后 输入288bit信号 组成192个ofdm符号
    .punt_en            (punt_en            ),
    .symbol_len_con     (symbol_len_con     ),
    .signal_flag_out    (signal_flag_punt   ),
    .punt_dout          (punt_dout          ),
    .punt_vld           (punt_vld           )
);

//4.交织

wire        intv_din;
wire        intv_en;
wire [1:0]  map_type; 
wire        intv_dout;
wire        intv_vld; 

assign  intv_din = punt_dout;
assign  intv_en = punt_vld;

data_interleaver 
#(
    .SIGNAL_INTV_TO_QAM_FRE  (SIGNAL_INTV_TO_QAM_FRE)  //QAM_FRONT_FREQUENCY / QAM_BACK_FREQUENCY  80M/20M
)
u_intv
(
    .cb_clk             (cb_clk             ), //80Mhz
    .rst_n              (rst_n              ),

    .intv_din           (intv_din           ),
    .intv_en            (intv_en            ),
    .intv_con           (symbol_len_con     ), //type 48bit,96bit,192bit,288bit
    .signal_flag_in     (signal_flag_punt   ),

    .map_type           (map_type           ),
    .intv_dout          (intv_dout          ),
    .intv_vld           (intv_vld           )
);

//5.符号调制

wire        QAM16_din;
wire        QAM16_en;
wire [7:0]  QAM16_re; 
wire [7:0]  QAM16_im; 
wire        QAM16_vld;
wire [5:0]  index_out;

assign  QAM16_din = intv_dout;
assign  QAM16_en = intv_vld;

data_mapping u_QAM16
(
    .cb_clk             (cb_clk     ), //80Mhz
    .clk                (sys_clk    ), //20Mhz
    .rst_n              (rst_n      ),
    .tx_clr             (tx_clr     ),

    .map_type           (map_type   ), //映射类型
    .QAM16_din          (QAM16_din  ),
    .QAM16_en           (QAM16_en   ),

    .QAM16_re           (QAM16_re   ), //映射后的I 实部
    .QAM16_im           (QAM16_im   ), //映射后的Q 虚部
    .QAM16_vld          (QAM16_vld  ),
    .index_out          (index_out  )  //输出标号
);

//6.导频插入

wire [7:0]  pilot_din_re;
wire [7:0]  pilot_din_im;
wire        pilot_en;    
wire [7:0]  pilot_dout_re;
wire [7:0]  pilot_dout_im;
wire        pilot_vld;    

assign  pilot_din_re = QAM16_re;
assign  pilot_din_im = QAM16_im;
assign  pilot_en =  QAM16_vld;

data_pilot_insert u_data_pilot_insert
(
    .clk                (sys_clk        ), //20Mhz
    .rst_n              (rst_n          ),

    .pilot_din_re       (pilot_din_re   ),
    .pilot_din_im       (pilot_din_im   ),
    .pilot_en           (pilot_en       ),
    .pilot_index        (index_out      ),
    .pilot_start        (tx_clr         ), //导频插入初始化

    .pilot_dout_re      (pilot_dout_re  ),
    .pilot_dout_im      (pilot_dout_im  ),
    .pilot_vld          (pilot_vld      )
);

assign  dout_re = pilot_dout_re;
assign  dout_im = pilot_dout_im;
assign  dout_vld = pilot_vld;

endmodule