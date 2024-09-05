module IFFT 
(
    input               clk_80m     , //80M
    input               sys_clk     , //20M
    input               rst_n       ,

    input  signed [7:0] din_re      , //signed：处理有符号数
    input  signed [7:0] din_im      ,
    input         [0:0] din_en      ,

    output reg    [5:0] dout_index  ,
    output signed [7:0] dout_re     ,
    output signed [7:0] dout_im     ,
    output reg          dout_vld    
);

wire    [15:0]      infifo_din;
wire    [0:0]       infifo_wen;
wire    [15:0]      infifo_dout;
reg     [0:0]       infifo_ren;
wire    [0:0]       infifo_full;
wire    [0:0]       infifo_empty;
wire    [6:0]       infifo_rd_count; //infifo中可读取的数据数量

reg                 rd_flag;
reg                 last_flag;
reg     [6:0]       rd_cnt_num;

wire                fft_s_config_tready;//fft ip核配置参数准备好
wire                fft_s_data_tready;  //fft output 输入数据准备好
reg                 fft_s_data_tvalid;  //数据有效信号
reg                 fft_s_data_tlast;   //标识每帧的最后一个数据
wire signed [31:0]  fft_s_data_tdata;   //输入数据。低16位为实数输入，高16位为虚数输入
wire signed [31:0]  fft_m_data_tdata;   //数据输出（复数）
wire signed [7:0]   fft_m_data_tuser;   //输出数据的下标
wire                fft_m_data_tvalid;  //数据有效
wire                fft_m_data_tready;  //接收数据准备好
wire                fft_m_data_tlast;   //标识最后一个数据
wire                fft_event_frame_started;//开始处理一个新帧
wire                fft_event_tlast_unexpected;//当没有接收到一帧的最后一个数据而fft_s_data_tlast拉高时，这表明输入数据的长度与ip核预设的数据不匹配
wire                fft_event_tlast_missing;//当接收到一帧的最后一个数据而fft_s_data_tlast没有拉高时，这表明输入数据的长度与ip核预设的数据不匹配
wire                fft_event_status_channel_halt;//data output通道写入数据，但通道中的缓冲区已满而无法写入
wire                fft_event_data_in_channel_halt;//ip核需要来自数据输入通道的数据但没有可用数据
wire                fft_event_data_out_channel_halt;//ip核需要向Status通道写入数据,但由于通道上的缓冲区已满而无法写入

reg     [15:0]      outfifo_din;
reg     [0:0]       outfifo_wen;
wire    [15:0]      outfifo_dout;
wire    [0:0]       outfifo_ren;
wire    [0:0]       outfifo_full;
wire    [0:0]       outfifo_empty;
wire    [6:0]       outfifo_rd_count; //outfifo中可读取的数据数量

reg                 out_flag;
reg     [5:0]       out_index;

//************************ fifo in *********************************//

assign  infifo_din = {din_im,din_re};
assign  infifo_wen = din_en;

fifo_asyn u_fifo_in
(
    .wr_clk          (sys_clk           ), 
    .rd_clk          (clk_80m           ), 
    .din             (infifo_din        ), 
    .wr_en           (infifo_wen        ), 
    .rd_en           (infifo_ren        ),
    .dout            (infifo_dout       ), 
    .full            (infifo_full       ), 
    .empty           (infifo_empty      ), 
    .rd_data_count   (infifo_rd_count   )
);

//fifo_in数据读取控制信号，以及IFFT输入数据
always @(posedge clk_80m or negedge rst_n) begin
    if(!rst_n)
        rd_flag <= 0;
    else    if(rd_cnt_num >= 63)
        rd_flag <= 0;
    else    if(infifo_rd_count >= 63)
        rd_flag <= 1;
end

always @(posedge clk_80m or negedge rst_n) begin
    if(!rst_n) begin
        infifo_ren <= 0;
        rd_cnt_num <= 0;
        last_flag <= 0;
    end
    else    if(rd_cnt_num >= 64) begin
        infifo_ren <= 0;
        rd_cnt_num <= 0;
        last_flag <= 0;
    end
    else    if(rd_flag && fft_s_data_tready && ~infifo_empty) begin
        infifo_ren <= 1;
        rd_cnt_num <= rd_cnt_num + 1;
        if(rd_cnt_num == 63)   last_flag <=1;
    end
    else begin
        infifo_ren <= 0;
        last_flag <= 0;
    end
end

always @(posedge clk_80m or negedge rst_n) begin
    if(!rst_n) begin
        fft_s_data_tvalid <= 0;
        fft_s_data_tlast <= 0;
    end
    else    if(infifo_ren) begin
        fft_s_data_tvalid <= 1;
        fft_s_data_tlast <= last_flag;
    end
    else begin
        fft_s_data_tvalid <= 0;
        fft_s_data_tlast <= last_flag;
    end
end

//FFT输入数据是I/Q两路数据经过放大8倍处理的结果
//对I/Q两路数据左移3位，再以高位填充符号位，低位补零形式，扩展为两路16bits数据输入到FFT中
assign  fft_s_data_tdata = { {5{infifo_dout[15]}},infifo_dout[15:8],3'b0 , {5{infifo_dout[7]}},infifo_dout[7:0],3'b0 };

//************************ fft ip **********************************//

fft u_fft
(
    .aclk                       (clk_80m                        ),
    //fft参数配置端口
    .s_axis_config_tdata        (8'd1                           ), //配置参数
    .s_axis_config_tvalid       (1'b1                           ), //配置参数有效
    .s_axis_config_tready       (fft_s_config_tready            ),
    //fft输入控制端口
    .s_axis_data_tdata          (fft_s_data_tdata               ),
    .s_axis_data_tvalid         (fft_s_data_tvalid              ),
    .s_axis_data_tready         (fft_s_data_tready              ),
    .s_axis_data_tlast          (fft_s_data_tlast               ),
    //fft输出控制端口
    .m_axis_data_tdata          (fft_m_data_tdata               ),
    .m_axis_data_tuser          (fft_m_data_tuser               ),
    .m_axis_data_tvalid         (fft_m_data_tvalid              ),
    .m_axis_data_tready         (fft_m_data_tready              ),
    .m_axis_data_tlast          (fft_m_data_tlast               ),
    //fft异常事件触发
    .event_frame_started        (fft_event_frame_started        ),
    .event_tlast_unexpected     (fft_event_tlast_unexpected     ),
    .event_tlast_missing        (fft_event_tlast_missing        ),
    .event_status_channel_halt  (fft_event_status_channel_halt  ),
    .event_data_in_channel_halt (fft_event_data_in_channel_halt ),
    .event_data_out_channel_halt(fft_event_data_out_channel_halt)
);

assign  fft_m_data_tready = 1'b1;

//************************ fifo out ********************************//

always @(posedge clk_80m or negedge rst_n) begin
    if(!rst_n) begin
        outfifo_wen <= 0;
        outfifo_din <= 0;
    end
    else    if(fft_m_data_tvalid) begin
        outfifo_wen <= 1;   //fft输出的两路16bits数据直接取低8bits作为outfifo输入数据
        outfifo_din <= {fft_m_data_tdata[23:16],fft_m_data_tdata[7:0]};
    end
    else
        outfifo_wen <= 0; 
end

fifo_asyn u_fifo_out
(
    .wr_clk          (clk_80m           ), 
    .rd_clk          (sys_clk           ), 
    .din             (outfifo_din       ), 
    .wr_en           (outfifo_wen       ), 
    .rd_en           (outfifo_ren       ),
    .dout            (outfifo_dout      ), 
    .full            (outfifo_full      ), 
    .empty           (outfifo_empty     ), 
    .rd_data_count   (outfifo_rd_count  )
);
   
//out_flag 
always @(posedge sys_clk or negedge rst_n) begin
    if(!rst_n)
        out_flag <= 0;
    else    if(outfifo_ren && (out_index >= 63))
        out_flag <= 0;
    else    if(outfifo_rd_count >= 63)
        out_flag <= 1;
end

//out_index
always @(posedge sys_clk or negedge rst_n) begin
    if(!rst_n)
        out_index <= 0;
    else    if(outfifo_ren && (out_index >= 63))
        out_index <= 0;
    else    if(outfifo_ren)
        out_index <= out_index + 1;
end

always @(posedge sys_clk or negedge rst_n) begin
    if(!rst_n) begin
        dout_vld <= 0;
        dout_index <= 0;
    end
    else    if(outfifo_ren) begin
        dout_vld <= 1;
        dout_index <= out_index;
    end
    else begin
        dout_vld <= 0;
        dout_index <= 0;
    end
end

assign  outfifo_ren = out_flag && ~outfifo_empty;
assign  dout_re = outfifo_dout[7:0];
assign  dout_im = outfifo_dout[15:8];
    
endmodule