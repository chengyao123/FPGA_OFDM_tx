module   trans_mcu
(  
                           	input               rst_n           ,
                           	input               mac_clk         , //7.5MHz
                           	input               clk_20m         ,
                           	input               clk_60m         ,
    //MAC interface
(* mark_debug = "true" *)  	output reg          phy_status      , //发射矢量参数信号
(* mark_debug = "true" *)  	input               txstart_req     , //请求发射MCU开始工作信号
(* mark_debug = "true" *)  	input      [20:0]   tx_param        , //发射参数21bits,包括待发射PSDU帧长(12bits)、发射速率(6bits)和发射功率等级(3bits)
(* mark_debug = "true" *)  	input      [7:0]    din             , //数据输入
(* mark_debug = "true" *)  	input               din_vld         , 
(* mark_debug = "true" *)  	output reg          din_req         ,
    //module control signal
(* mark_debug = "true" *)   output reg        	tx_clr          , //清除处理并复位
    						output reg         	start_en  		, //序列训练开始信号
(* mark_debug = "true" *)   output             	modem_bit       , //调制bit控制信号
(* mark_debug = "true" *)   output             	modem_bit_vld   , //signal data有效信号
(* mark_debug = "true" *)   output             	signal_flag     , //singal标志位
(* mark_debug = "true" *)   output reg [3:0]   	rate_con        , //传输速率控制信号
    						output reg [2:0]    txpwr           , //发射功率输出端口
    						output reg [6:0]    scram_seed		  //扰码器的移位寄存器初始化向量
);

// 7.5MHz
localparam      OFDM_SYMBOL_BYTES = 18;

reg             txstart_req1;
reg  [11:0]     byte_length;
reg  [5:0]      rate;
reg  [23:0]     signal_region;
reg  [4:0]      req_byte_cnt;
wire            add_req_byte_cnt;
wire            end_req_byte_cnt;
reg             mac_data_req1;

// 60MHz
localparam  	SYMBOL_PERIOD_TIME = 240;
localparam  	SIGNAL_BIT_PERIOD = 6;
localparam  	DATA_SYMBO_WAIT_TIME = 105;

reg  			txstart_req_wait;
reg [8:0]		symbol_delay_time;
reg				txstart_req2,txstart_req3;
reg				ofdm_runing;
reg				ofdm_byte_req;
reg [8:0]		symbol_period;
wire 			add_symbol_period;
wire 			end_symbol_period;
reg	[7:0]		ofdm_symbol_cnt;
reg	[7:0]		ofdm_symbol_cnt_max;
wire			add_ofdm_symbol_cnt;
wire			end_ofdm_symbol_cnt;
reg				rd_fifo_en;
reg				rd_fifo_vld;
wire			rd_fifo_data;
reg				signal_flag_reg1,signal_flag_reg2;
reg	[2:0]		signal_bit_period;
reg				signal_bit_out;
reg				signal_bit_vld;
reg	[4:0]		signal_bit_cnt;
reg				signal_bit_vld1;
reg				signal_bit_out1;

// 20MHz
reg				train_runing;

/***************************************  mac 7.5MHz  ***************************************/
/*1. 同步MAC端数据发射请求，并解析数据
  2. 同步来自60MHz时钟域下的MAC数据请求，向MAC端请求数据作为异步FIFO输入缓存
  3. 全局初始化		*/

//start_req1
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n)
		txstart_req1 <= 0;
	else
		txstart_req1 <= txstart_req;
end

//对ofdm基带发射机系统 清除处理并复位到初始状态
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n)
		tx_clr <= 0;
	else	if(txstart_req)
		tx_clr <= 1'b1;
	else
		tx_clr <= 0;
end

//接收MAC发射请求
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n) begin
		byte_length <= 0;
		rate <= 0;
		rate_con <= 0;
		txpwr <= 0;
		scram_seed <= 0;
	end
	else	if(txstart_req || txstart_req1) begin
		byte_length <= tx_param[20:9];
		rate <= tx_param[8:3];
		txpwr <= tx_param[2:0];
		scram_seed <= 7'b1011101;
		case (tx_param[8:3]) //发射速率
            6'd6 : rate_con <= 4'b1101 ;
            6'd9 : rate_con <= 4'b1111 ;
            6'd12: rate_con <= 4'b0101 ;
            6'd18: rate_con <= 4'b0111 ;
            6'd24: rate_con <= 4'b1001 ;
            6'd36: rate_con <= 4'b1011 ;
            6'd48: rate_con <= 4'b0010 ;
            6'd54: rate_con <= 4'b0011 ;
			default: rate_con <= 4'b0000;
		endcase
	end
end

//signal_region
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n)
		signal_region <= 0;
	else		// {^signal_region[16:0]}运算结果是一个单个位，表示有奇数个1
		signal_region <= {6'b0,{^signal_region[16:0]},byte_length,1'b0,
                          rate_con[0],rate_con[1],rate_con[2],rate_con[3]};
end

//向MAC请求18字节数据
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n)
		din_req <= 0;
	else	if(end_req_byte_cnt)
		din_req <= 0;
	else	if(~mac_data_req1 && ofdm_byte_req)
		din_req <= 1'b1;
end

//ofdm_byte_req
always @(posedge mac_clk or negedge rst_n) begin
    if(!rst_n)
        mac_data_req1 <= 0;
    else
        mac_data_req1 <= ofdm_byte_req;
end

//req_byte_cnt计数器
always @(posedge mac_clk or negedge rst_n) begin
	if(!rst_n)
		req_byte_cnt <= 0;
	else	if(end_req_byte_cnt)
		req_byte_cnt <= 0;
	else	if(add_req_byte_cnt)
		req_byte_cnt <= req_byte_cnt + 1'b1;
end

assign	add_req_byte_cnt = din_req; //请求byte计数信号
assign	end_req_byte_cnt = add_req_byte_cnt && (req_byte_cnt == OFDM_SYMBOL_BYTES-1); //请求byte计数结束信号 计数到17结束

/***************************************  60MHz  ***************************************/
/*1. 控制Signal符号和Data符号生成开始时刻，完成训练符号与Signal符号和Data符号无缝衔接
  2. 完成单个OFDM符号时钟周期计数以及OFDM符号长度计数
  3. 向7.5MHz时钟域发送MAC数据请求，并在Data符号开始时向异步FIFO读取数据
  4. 完成Signal符号数据与Data符号数据不同格式的生成以及相应标志信号生成 */

// 控制序列符号与Signal符号和Data符号时序对齐
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		txstart_req_wait <= 0;
	else
		txstart_req_wait <= txstart_req1;
end

always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		symbol_delay_time <= 0;
	else	if(symbol_delay_time >= DATA_SYMBO_WAIT_TIME)
		symbol_delay_time <= 0;
	else	if(txstart_req_wait && ~txstart_req1)
		symbol_delay_time <= 1;
	else	if(symbol_delay_time > 0)
		symbol_delay_time <= symbol_delay_time + 1'b1;
end

// ofdm_start_en
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n) begin
		txstart_req2 <= 0;
		txstart_req3 <= 0;
	end
	else begin
		txstart_req2 <= (symbol_delay_time >= DATA_SYMBO_WAIT_TIME);
		txstart_req3 <= txstart_req2;
	end
end

// output发射矢量参数信号 
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		phy_status <= 0;
	else	if(~ofdm_runing)
		phy_status <= 0;
	else	if(txstart_req_wait && ~txstart_req1)
		phy_status <= 1'b1;
end

// ofdm_runing
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		ofdm_runing <= 0;
	else	if(end_ofdm_symbol_cnt)
		ofdm_runing <= 0;
	else	if(~txstart_req2 & txstart_req3)
		ofdm_runing <= 1'b1;
end

// symbol_period 一个OFDM符号的时钟周期计数
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		symbol_period <= 0;
	else	if(end_symbol_period)
		symbol_period <= 0;
	else	if(add_symbol_period)
		symbol_period <= symbol_period + 1'b1;
end

assign	add_symbol_period = ofdm_runing;
assign	end_symbol_period = add_symbol_period && (symbol_period == SYMBOL_PERIOD_TIME - 1);

// ofdm_symbol_cnt OFDM符号数计数
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		ofdm_symbol_cnt <= 0;
	else	if(end_ofdm_symbol_cnt)
		ofdm_symbol_cnt <= 0;
	else	if(add_ofdm_symbol_cnt)
		ofdm_symbol_cnt <= ofdm_symbol_cnt + 1'b1;
end

assign	add_ofdm_symbol_cnt = ofdm_runing && end_symbol_period;
assign	end_ofdm_symbol_cnt = add_ofdm_symbol_cnt && (ofdm_symbol_cnt == ofdm_symbol_cnt_max);

// ofdm_symbol_cnt_max
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		ofdm_symbol_cnt_max <= 0;
	else
		ofdm_symbol_cnt_max <= (byte_length + 3) / OFDM_SYMBOL_BYTES; //byte_length + 3 ?
end

// ofdm_byte_req  向7.5MHz时钟域发送MAC数据请求
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		ofdm_byte_req <= 0;
	else	if((symbol_period == SYMBOL_PERIOD_TIME - 60) && (ofdm_symbol_cnt != ofdm_symbol_cnt_max))
		ofdm_byte_req <= 1'b1;
	else	if(symbol_period == SYMBOL_PERIOD_TIME - 50)
		ofdm_byte_req <= 1'b0;
end

// rd_fifo_en
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		rd_fifo_en <= 0;
	else	if(symbol_period == (OFDM_SYMBOL_BYTES << 3) - 2) // 18*8-2=142
		rd_fifo_en <= 1'b0;
	else	if((symbol_period == SYMBOL_PERIOD_TIME - 2) && (ofdm_symbol_cnt!= ofdm_symbol_cnt_max))
		rd_fifo_en <= 1'b1;
end

always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		rd_fifo_vld <= 0;
	else
		rd_fifo_vld <= rd_fifo_en;
end

// signal_flag_reg1
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		signal_flag_reg1 <= 0;
	else	if(~txstart_req2 & txstart_req3)
		signal_flag_reg1 <= 1'b1;
	else	if((signal_bit_cnt >= 23) && (signal_bit_period == SIGNAL_BIT_PERIOD - 1))
		signal_flag_reg1 <= 1'b0;
end

// signal_bit_period
always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		signal_bit_period <= 0;
	else	if(signal_bit_period == SIGNAL_BIT_PERIOD - 1)
		signal_bit_period <= 0;
	else	if(signal_flag_reg1)
		signal_bit_period <= signal_bit_period + 1'b1;
end

always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n || tx_clr) begin
		signal_bit_cnt <= 0;
		signal_bit_out <= 0;
		signal_bit_vld <= 0;
	end
	else	if(signal_flag_reg1 && (signal_bit_period == SIGNAL_BIT_PERIOD - 1)) begin
		signal_bit_cnt <= signal_bit_cnt + 1'b1;
		signal_bit_out <= signal_region[signal_bit_cnt];
		signal_bit_vld <= 1;
	end
	else
		signal_bit_vld <= 1'b0;
end

always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n)
		signal_flag_reg2 <= 0;
	else
		signal_flag_reg2 <= signal_flag_reg1 || signal_bit_vld || signal_bit_vld1;
end

always@(posedge clk_60m or negedge rst_n ) begin
	if(!rst_n) begin
		signal_bit_out1 <= 0;
		signal_bit_vld1 <= 0;
	end
	else begin
		signal_bit_out1 <= signal_bit_out;
		signal_bit_vld1 <= signal_bit_vld;
	end
end

assign	signal_flag = signal_flag_reg2;
assign	modem_bit = signal_flag ? signal_bit_out1 : rd_fifo_data;
assign	modem_bit_vld = signal_flag ? signal_bit_vld1 : rd_fifo_vld;

wire	full;
wire	empty;

fifo_mcu u_byte_to_bit
(
	.rst		(~rst_n			), 
	.wr_clk		(mac_clk		), 
	.rd_clk		(clk_60m		), 
	.din		(din			), 
	.wr_en		(din_vld		), 
	.rd_en		(rd_fifo_en		), 
	.dout		(rd_fifo_data	), 
	.full		(full			), 
  	.empty		(empty			)	
);

/***************************************  20MHz  ***************************************/
/* 同步数据起始信号，驱动序列训练生成 */

//train_runing
always@(posedge clk_20m or negedge rst_n) begin
	if(!rst_n)
		train_runing <= 0;
	else
		train_runing <= txstart_req1;
end

//start_en 训练序列开始信号
always@(posedge clk_20m or negedge rst_n) begin
	if(!rst_n)
		start_en <= 0;
	else	if(train_runing && ~txstart_req1)
		start_en <= 1'b1;
	else
		start_en <= 0;
end

endmodule