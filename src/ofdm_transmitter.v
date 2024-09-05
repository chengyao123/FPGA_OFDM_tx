module ofdm_transmitter 
(
    input               sys_clk     ,
    input               sys_rst_n   ,

    //MAC interface
    output              mac_clk     , //7.5MHz
    output              phy_status  , //发射矢量参数信号
    input               txstart_req ,
    input   [20:0]      tx_param    ,
    input   [7:0]       din         ,
    input               din_vld     ,
    output              din_req     ,

    //data out
    (* mark_debug = "true" *)  output  [7:0]  dout_re ,
    (* mark_debug = "true" *)  output  [7:0]  dout_im ,
    (* mark_debug = "true" *)  output         dout_vld,
    output  [2:0]       dout_txpwr   //发射功率输出端口
);

//***********************  varible definition **********************************//

wire            locked;
wire            rst_n = sys_rst_n & locked;

//pll
wire            clk_20m; //20MHz
wire            clk_60m; //60MHz
wire            clk_80m; //80MHz

//symbol_train module signal
wire            tx_clr;
wire            train_start_en;
wire    [7:0]   train_re;
wire    [7:0]   train_im;
wire            train_vld;
wire    [8:0]   train_index;
wire            train_done;

//ofdm signal modem
wire    [3:0]   rate_con;
wire            signal_flag;
wire    [6:0]   scram_seed;
wire            modem_data;
wire            modem_data_vld;      
(* mark_debug = "true" *) wire    [7:0]   modem_dout_re;
(* mark_debug = "true" *) wire    [7:0]   modem_dout_im;
(* mark_debug = "true" *) wire            modem_dout_vld;

//IFFT
wire    [5:0]   ifft_dout_index;
(* mark_debug = "true" *) wire    [7:0]   ifft_dout_re;
(* mark_debug = "true" *) wire    [7:0]   ifft_dout_im;
(* mark_debug = "true" *) wire            ifft_dout_vld;

//cp & adder
(* mark_debug = "true" *) wire    [7:0]   cp_dout_re;  
(* mark_debug = "true" *) wire    [7:0]   cp_dout_im;  
(* mark_debug = "true" *) wire            cp_dout_vld;

//***********************  module instances **********************************//

pll_clk u_pll
(
    .clk_7_5m       (mac_clk        ),
    .clk_20m        (clk_20m        ),
    .clk_60m        (clk_60m        ),
    .clk_80m        (clk_80m        ),
    .reset          (~sys_rst_n     ),
    .locked         (locked         ),
    .clk_in1        (sys_clk        )
);

//训练序列生成
symbol_train u_train
(  
    .clk            (clk_20m        ),   
    .rst_n          (rst_n          ),   
    .tx_clr         (tx_clr         ),   
    .start_en       (train_start_en ),

    .train_im       (train_im       ),
    .train_re       (train_re       ),
    .train_dv       (train_vld      ),
    .train_index    (train_index    ),
    .train_done     (train_done     )
); 

//OFDM符号频域调制
ofdm_data_modem
#(
    .SIGNAL_INTV_TO_QAM_FRE       (4)
)
u_ofdm_modem
(
    .sys_clk        (clk_20m        ), //20M
    .din_clk        (clk_60m        ), //60M
    .cb_clk         (clk_80m        ), //80M
    .rst_n          (rst_n          ),
    //control signal
    .tx_clr         (tx_clr         ),
    .rate_con       (rate_con       ),
    .signal_flag    (signal_flag    ),
    .scram_seed     (scram_seed     ),
    //data signal
    .data_bit       (modem_data     ),
    .data_bit_vld   (modem_data_vld ),
    .dout_re        (modem_dout_re  ),
    .dout_im        (modem_dout_im  ),
    .dout_vld       (modem_dout_vld )
);

//IFFT
IFFT u_ifft
(
    .clk_80m        (clk_80m        ), //80M
    .sys_clk        (clk_20m        ), //20M
    .rst_n          (rst_n          ),

    .din_re         (modem_dout_re  ), //signed：处理有符号�?
    .din_im         (modem_dout_im  ),
    .din_en         (modem_dout_vld ),

    .dout_index     (ifft_dout_index),
    .dout_re        (ifft_dout_re   ),
    .dout_im        (ifft_dout_im   ),
    .dout_vld       (ifft_dout_vld  )
);

//循环前缀 & 加窗
cp_adder u_cp_adder
(
    .clk            (clk_20m        ), //20M
    .rst_n          (rst_n          ),

    .din_re         (ifft_dout_re   ),
    .din_im         (ifft_dout_im   ),
    .din_en         (ifft_dout_vld  ),
    .din_index      (ifft_dout_index),

    .dout_re        (cp_dout_re     ),
    .dout_im        (cp_dout_im     ),
    .dout_vld       (cp_dout_vld    )
);

assign  dout_re = train_vld ? train_re : cp_dout_re;
assign  dout_im = train_vld ? train_im : cp_dout_im;
assign  dout_vld = train_vld ? train_vld : cp_dout_vld;

//MCU control module
trans_mcu u_trans_mcu
(  
    .rst_n           (rst_n         ),
    .mac_clk         (mac_clk       ), //7.5MHz
    .clk_20m         (clk_20m       ),
    .clk_60m         (clk_60m       ),
    //MAC interface
    .phy_status      (phy_status    ), //发射矢量参数信号
    .txstart_req     (txstart_req   ), //请求发射MCU�?始工作信�?
    .tx_param        (tx_param      ), //发射参数21bits,包括待发射PSDU帧长(12bits)、发射�?�率(6bits)和发射功率等�?(3bits)
    .din             (din           ), //数据输入
    .din_vld         (din_vld       ), 
    .din_req         (din_req       ), //向mac层请求数�?
    //module control signal
    .tx_clr          (tx_clr        ), //清除处理并复�?
    .start_en  		 (train_start_en), //序列训练�?始信�?
    .modem_bit       (modem_data    ), //调制bit控制信号
    .modem_bit_vld   (modem_data_vld), //signal data有效信号
    .signal_flag     (signal_flag   ), //singal标志�?
    .rate_con        (rate_con      ), //传输速率控制信号
    .txpwr           (dout_txpwr    ), //发射功率输出端口
    .scram_seed		 (scram_seed    )  //扰码器的移位寄存器初始化向量
);

endmodule