/*  为实现流水线模式，采样乒乓缓存模式
        使用4个长度为64的RAM，分别存储乒乓缓存A区I/Q两路数据和乒乓缓存B区I/Q两路数据

    添加循环前缀的方法：
        将每个OFDM符号的后16个数据复制到前16个数据中，形成一个80个数据的OFDM符号
        实现上一个OFDM符号的前48个数据存入RAM，后16个数据一边输出，一边写入RAM
        到64个数据输出完成后，再从RAM中按顺序输出64个数据

    加窗：
        加窗处理要求每个OFDM符号最后多输出一个数据,为OFDM符号64个样值中的第一个
        而下一个符号的第一个数据(CP的第一个样值)将和该数据相加且右移1位后再行输出
*/
module cp_adder 
(
    input            clk        ,
    input            rst_n      ,

    input   [7:0]    din_re     ,
    input   [7:0]    din_im     ,
    input            din_en     ,
    input   [5:0]    din_index  ,

    output reg [7:0] dout_re    ,
    output reg [7:0] dout_im    ,
    output reg       dout_vld   
);

//输入写入RAM中

wire        wen_1;
wire        wen_2;
reg         spram_flag;
reg         rd_ram_en;
reg  [5:0]  rd_ram_addr;
reg  [5:0]  rd_data_cnt;
wire [7:0]  dout_re_1;
wire [7:0]  dout_im_1;
wire [7:0]  dout_re_2;
wire [7:0]  dout_im_2;

reg  [7:0]  first_re_1;
reg  [7:0]  first_im_1;
reg  [7:0]  first_re_2;
reg  [7:0]  first_im_2;

assign  wen_1 = din_en && ~spram_flag;
assign  wen_2 = din_en && spram_flag;

//乒乓缓存A区
spram_64 spram_re_1
(
    .rst_n       (rst_n         ),

    .clk_a       (clk           ),
    .we_a        (wen_1         ),
    .addr_a      (din_index     ),
    .din_a       (din_re        ),
    .dout_a      (              ),

    .clk_b       (clk           ),
    .we_b        (1'b0          ),
    .addr_b      (rd_ram_addr   ),
    .din_b       (              ),
    .dout_b      (dout_re_1     )
);

spram_64 spram_im_1
(
    .rst_n       (rst_n         ),

    .clk_a       (clk           ),
    .we_a        (wen_1         ),
    .addr_a      (din_index     ),
    .din_a       (din_im        ),
    .dout_a      (              ),

    .clk_b       (clk           ),
    .we_b        (1'b0          ),
    .addr_b      (rd_ram_addr   ),
    .din_b       (              ),
    .dout_b      (dout_im_1     )
);

//乒乓缓存B区
spram_64 spram_re_2
(
    .rst_n       (rst_n         ),

    .clk_a       (clk           ),
    .we_a        (wen_2         ),
    .addr_a      (din_index     ),
    .din_a       (din_re        ),
    .dout_a      (              ),

    .clk_b       (clk           ),
    .we_b        (1'b0          ),
    .addr_b      (rd_ram_addr   ),
    .din_b       (              ),
    .dout_b      (dout_re_2     )
);

spram_64 spram_im_2
(
    .rst_n       (rst_n         ),

    .clk_a       (clk           ),
    .we_a        (wen_2         ),
    .addr_a      (din_index     ),
    .din_a       (din_im        ),
    .dout_a      (              ),

    .clk_b       (clk           ),
    .we_b        (1'b0          ),
    .addr_b      (rd_ram_addr   ),
    .din_b       (              ),
    .dout_b      (dout_im_2     )
);

//乒乓缓存AB ram转换标志位
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        spram_flag <= 0;
    else    if(din_index == 63)
        spram_flag <= ~spram_flag;
end

//rd_ram_en
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
       rd_ram_en <= 0;
    else    if(din_index == 62) 
        rd_ram_en <= 1;
    else    if(rd_data_cnt >= 63)
        rd_ram_en <= 0;
end

//rd_ram_addr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_ram_addr <= 0;
    else    if(rd_ram_en || (din_index == 63))
        rd_ram_addr <= rd_ram_addr + 1;
    else
        rd_ram_addr <= 0;
end

//rd_data_cnt
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_data_cnt <= 0;
    else    if(rd_ram_en)
        rd_data_cnt <= rd_ram_addr;
    else
        rd_data_cnt <= 0;
end

//缓存第一个样值
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        first_re_1 <= 0;
        first_im_1 <= 0;
        first_re_2 <= 0;
        first_im_2 <= 0;
    end
    else    if(din_index == 0) begin
        case (spram_flag)
            0: begin
                first_re_1 <= din_re;
                first_im_1 <= din_im;
            end
            1: begin
                first_re_2 <= din_re;
                first_im_2 <= din_im;
            end
            default:;
        endcase
    end
end

//读取数据
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dout_re <= 0;
        dout_im <= 0;
        dout_vld <= 0;
    end
    else    if(din_index == 48) begin //加窗 每个OFDM符号最后多输出64个样值中的第一个 
        dout_vld <= 1;                //下一个符号的第一个数据(CP的第一个样值)将和该数据相加且右移1位后再输出
        case (spram_flag) //注意读取缓存第一个样值的顺序
            0: begin
                dout_re <= (first_re_2 + din_re) >> 1;//下一个OFDM第一个样值与上一个OFDM第一个样值相加再除2
                dout_im <= (first_im_2 + din_im) >> 1;
            end
            1: begin
                dout_re <= (first_re_1 + din_re) >> 1;
                dout_im <= (first_im_1 + din_im) >> 1;
            end
            default:; 
        endcase
    end
    else    if(din_index > 48) begin
        dout_re <= din_re;
        dout_im <= din_im;
        dout_vld <= 1;
    end
    else    if(rd_ram_en) begin
        dout_vld <= 1;
        case (spram_flag) //注意读出数据ram顺序 
            0: begin      //spram_flag == 0 输入数据正缓存第一个ram，应读取第二个ram
                dout_re <= dout_re_2;
                dout_im <= dout_im_2;
            end
            1: begin      //spram_flag == 1 输入数据正缓存第二个ram，应读取第一个ram
                dout_re <= dout_re_1;
                dout_im <= dout_im_1;
            end
            default:;
        endcase
    end
    else
        dout_vld <= 0;
end
    
endmodule