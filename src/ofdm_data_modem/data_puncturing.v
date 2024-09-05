/* 
    删余：
    3/4 码率  6bit-2bit 删除第4、5bit的数据 3组卷积码 删除2bit   data符号采用3/4码率
    2/3 码率  4bit-1bit 删除第4bit的数据    2组卷积码 删除1bit  (卷积编码输出的2位并行数据依次计数)
    1/2 码率  不删bit  signal符号直接采用1/2码率，不删余
*/
// signal :1/2码率 ；data数据 2/3码率
// signal域数据 3clk间隔
// rate_con 不对signal符号调制类型做配置

module data_puncturing 
(
    input               din_clk         ,//60Mhz
    input               cb_clk          ,//80Mhz
    input               rst_n           ,

    input        [3:0]  rate_con        ,
    input               singal_flag_in  ,
    input        [1:0]  punt_din        ,//bit输入 lsb在前，msb在后 输入144bit信号 组成192个ofdm符号
    input               punt_en         ,
    output  reg  [1:0]  symbol_len_con  ,
    output  reg         signal_flag_out ,
    output  reg         punt_dout       ,
    output  reg         punt_vld        
);

reg [5:0]   puncture_in;
reg [5:0]   puncture_reg;
reg [5:0]   puncture_reg1;

reg [2:0]   cnt_index;
reg [2:0]   cnt_bit;
reg [2:0]   cnt_bit_max;

reg         cache_valid;
reg         cache_valid_reg;
reg         cache_valid_reg1;

reg         singal_flag1,singal_flag2,singal_flag3,singal_flag4;

//当为signal域时，强制设置Rate类型
wire [3:0]  Rate_Con;
assign  Rate_Con = singal_flag_in ?'b1101 : rate_con; //signal域: BPSK,1/2,6Mb/s

//接收卷积编码后的数据 提供缓存指示信号
always @(posedge din_clk or negedge rst_n) begin
    if(!rst_n) begin
        puncture_in <= 0;
        cnt_index <= 0;
        cache_valid <= 0;
    end
    else    if(punt_en) begin //每clk输入2位符号 间隔3clk 有效 
        case (Rate_Con)
            4'b1101,4'b0101,4'b1001: begin // Rate is 1/2 .
                puncture_in[1:0] <= punt_din;
                cnt_index <= 0;
                cache_valid <= 1;
            end
            4'b1111,4'b0111,4'b1011,4'b0011: begin // Rate is 3/4 .
                puncture_in <= {puncture_in[3:0],punt_din};
                if(cnt_index == 2) begin
                    cnt_index <= 0;
                    cache_valid <= 1;
                end
                else begin
                    cnt_index <= cnt_index + 1'b1;
                    cache_valid <= 0;
                end
            end
            4'b0001: begin // Rate is 2/3 .
                puncture_in <= {puncture_in[3:0],punt_din};
                if(cnt_index == 1) begin
                    cnt_index <= 0;
                    cache_valid <= 1;
                end
                else begin
                    cnt_index <= cnt_index + 1'b1;
                    cache_valid <= 0;
                end
            end
            default: ;
        endcase
    end
    else
        cache_valid <= 0;   
end

always @(posedge din_clk or negedge rst_n) begin
    if(!rst_n)
        singal_flag1 <= 0;
    else    if(~singal_flag_in)
        singal_flag1 <= 0;
    else    if(singal_flag_in)
        singal_flag1 <= 1;
end

//**********************  跨时钟域 60M → 80M  *********************************************//
//**********************  慢时钟域到快时钟域，直接打拍处理  *************************//

//打拍
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        singal_flag2 <= 0;
        singal_flag3 <= 0;
        singal_flag4 <= 0;
        puncture_reg <= 0;
        puncture_reg1 <= 0;
        cache_valid_reg <= 0;
        cache_valid_reg1 <= 0;
    end
    else begin
        singal_flag2 <= singal_flag1;   //打3拍
        singal_flag3 <= singal_flag2;
        singal_flag4 <= singal_flag3;
        puncture_reg <= punt_din;       //打2拍
        puncture_reg1 <= puncture_reg;
        cache_valid_reg <= cache_valid;
        cache_valid_reg1 <= ~cache_valid_reg1 && cache_valid_reg; //起始，结束 边沿检测
    end
end

//output bit count max 
always @(*) begin
    if(singal_flag3 || singal_flag4) //singal域 不删余
        cnt_bit_max <= 1;
    else
        case (Rate_Con)
            4'b1101,4'b0101,4'b1001: 
                cnt_bit_max <= 1;
            4'b1111,4'b0111,4'b1011,4'b0011:
                cnt_bit_max <= 3;
            4'b0001:
                cnt_bit_max <= 2;
            default: cnt_bit_max <= 1;
        endcase
end

//output bit count
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        cnt_bit <= 0;
    else    if(cnt_bit >= cnt_bit_max)
        cnt_bit <= 0;
    else    if(cnt_bit > 0)
        cnt_bit <= cnt_bit + 1'b1;
    else    if(cache_valid_reg1)
        cnt_bit <= 1;
end

//output dout valid
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        punt_dout <= 0;
        punt_vld <= 0;
    end
    else    if(cache_valid_reg1 || (cnt_bit > 0))
        case (cnt_bit_max)
            1: // 1/2码率 不删余
                case (cnt_bit) 
                    0: begin
                        punt_dout <= puncture_reg1[0];
                        punt_vld <= 1;
                    end
                    1: begin
                        punt_dout <= puncture_reg1[1];
                        punt_vld <= 1;
                    end
                    default:;
                endcase
            2: // 2/3码率 删除第4个bit
                case (cnt_bit) 
                    0: begin
                        punt_dout <= puncture_reg1[0];
                        punt_vld <= 1;
                    end
                    1: begin
                        punt_dout <= puncture_reg1[1];
                        punt_vld <= 1;
                    end
                    2: begin
                        punt_dout <= puncture_reg1[2];
                        punt_vld <= 1;
                    end
                    default:;
                endcase
            3: // 3/4码率 删除第4、5个bit
                case (cnt_bit) 
                    0: begin
                        punt_dout <= puncture_reg1[0];
                        punt_vld <= 1;
                    end
                    1: begin
                        punt_dout <= puncture_reg1[1];
                        punt_vld <= 1;
                    end
                    2: begin
                        punt_dout <= puncture_reg1[2];
                        punt_vld <= 1;
                    end
                    3: begin
                        punt_dout <= puncture_reg1[5];
                        punt_vld <= 1;
                    end
                    default:;
                endcase
            default: ;
        endcase
    else
        punt_vld <= 0;
end

//output symbol_len_con
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        symbol_len_con <= 0;
    else    if(singal_flag3 || singal_flag4)
        symbol_len_con <= 2'b00;
    else    if(cnt_bit == 0)
        case (Rate_Con)
            4'b1101,4'b1111: symbol_len_con <= 2'b00;   // Len == 48
            4'b0101,4'b0111: symbol_len_con <= 2'b01;   // Len == 96
            4'b1001,4'b1011: symbol_len_con <= 2'b10;   // Len == 192
            4'b0001,4'b0011: symbol_len_con <= 2'b11;   // Len == 288
            default: symbol_len_con <= 2'b00;
        endcase
end

//output signal_flag_out
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        signal_flag_out <= 0;
    else    if(singal_flag3 || singal_flag4)
        signal_flag_out <= 1;
    else
        signal_flag_out <= 0;
end
    
endmodule