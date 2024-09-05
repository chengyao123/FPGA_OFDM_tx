/*
    导频插入：
            在52个子载波中插入4个导频符号，位置  {-21，-7,7,21}
            4个导频初始极性  1,1,1，-1
    导频所处位置的值，是根据一个循环的导频的极性控制序列来完成的
        P0v - P126v = {1,1,1,1,-1,-1-1,1,-1,-1,-1,-1,1,1,...,-1,-1}
    P0v - P126v为OFDM符号     P0v是signal符号的极性控制信号  P1v-P126v是data域
    当Pnv =  1时，对应OFDM符号的导频符号不改变极性
    当Pnv = -1时，对应OFDM符号的导频符号改变极性    -1 >> 1; 1 >> -1 (对于1,1,1，-1)

    P0v - P126v 通过扰码器来产生     扰码器初始状态 7'b111_1111

    64位IFFT变换：
        0        置0
        1 - 26   映射IFFT端口 1 - 26
        -26 - -1 映射IFFT端口 38 - 63
        IFFT剩余端口 27 - 37 置0   
    
    输入48个数据64位IFFT变换规则：
        数据标号        M(k)        IFFT端口
        0 - 4       -26 - -22       38 - 42
    插入导频1           -21            43
        5 - 17      -20 - -8        44 - 56
    插入导频2           -7             57
        18 - 23      -6 - -1        58 - 63
    中心频率             0              0
        24 - 29       1 - 6          1 - 6
    插入导频3            7              7
        30 - 42       8 - 20         8 - 20
    插入导频4            21             21
        43 - 47      22 - 26        22 - 26

    空余            -32 - -27       32 - 37
                    27 - 31         27 - 31
*/

module data_pilot_insert 
(
    input               clk             ,
    input               rst_n           ,

    input       [7:0]   pilot_din_re    ,
    input       [7:0]   pilot_din_im    ,
    input               pilot_en        ,
    input       [5:0]   pilot_index     ,
    input               pilot_start     , //导频插入初始化

    output reg  [7:0]   pilot_dout_re   ,
    output reg  [7:0]   pilot_dout_im   ,
    output reg          pilot_vld       
);

reg         re_we_a;
reg  [6:0]  re_addr_a;
reg  [7:0]  re_din_a;
reg         im_we_a;
reg  [6:0]  im_addr_a;
reg  [7:0]  im_din_a;

reg         wen_out;
reg  [6:0]  out_addr;
reg  [7:0]  din_b;
wire [7:0]  re_dout_b;
wire [7:0]  im_dout_b;

//打拍
reg         pilot_en1;
reg         pilot_en2;
wire        wr_done;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pilot_en1 <= 0;
        pilot_en2 <= 0;
    end
    else begin
        pilot_en1 <= pilot_en;
        pilot_en2 <= pilot_en1;
    end
end

assign  wr_done = pilot_en1 && ~pilot_en;

//************************ 扰码 **************************************//

//导频极性控制
reg  [6:0]  shift_reg;
wire        scram_out;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        shift_reg <= 0;
    else    if(pilot_start)
        shift_reg <= 7'b111_1111;
    else    if(wr_done)
        shift_reg <= {shift_reg[5:0],(shift_reg[6] + shift_reg[3])}; //S(x) = x^7 + x^4 + 1 
end

//当 scram_out == 0 不改变极性  当 scram_out == 1 改变极性
assign  scram_out = (shift_reg[6] + shift_reg[3]); // OFDM符号极性 x^7 + x^4

//************************ 错序写入 **********************************//
//在输出时对输出顺序作变换，数据输出顺序符合IFFT输入要求

reg  [6:0]  cnt_symbol;
reg         insert;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        re_we_a <= 0;
        re_addr_a <= 0;
        re_din_a <= 0;
    end
    else    if(pilot_en) begin //写入复数实部样值
        re_addr_a[6] <= cnt_symbol[0] ? 1: 0; //每两个符号依次写入前一半和后一半的地址空间中
        case (pilot_index)                    //保证前一符号读出与后一符号写入不发生冲突
            0,1,2,3,4: 
                re_addr_a[5:0] <= pilot_index + 38;
            5,6,7,8,9,10,11,12,13,14,15,16,17:
                re_addr_a[5:0] <= pilot_index + 39;
            18,19,20,21,22,23:
                re_addr_a[5:0] <= pilot_index + 40;
            24,25,26,27,28,29:
                re_addr_a[5:0] <= pilot_index - 23;
            30,31,32,33,34,35,36,37,38,39,40,41,42:
                re_addr_a[5:0] <= pilot_index - 22;
            43,44,45,46,47:
                re_addr_a[5:0] <= pilot_index - 21;
            default: re_addr_a[5:0] <= 0;
        endcase
        re_we_a <= 1;
        re_din_a <= pilot_din_re;
    end
    else    if(insert) //插入导频
        case (re_addr_a[5:0]) //  顺序    1,1,1,-1 >> 43  57  7  21
            0: begin
                re_addr_a[5:0] <= 7; //IFFT 7
                re_din_a <= scram_out ? 8'b1100_0000 : 8'b0100_0000; // -1 : 1
                re_we_a <= 1;
            end
            7: begin
                re_addr_a[5:0] <= 21; //IFFT 21
                re_din_a <= scram_out ? 8'b0100_0000 : 8'b1100_0000; // 1 : -1
                re_we_a <= 1;
            end
            21: begin
                re_addr_a[5:0] <= 43; //IFFT 43
                re_din_a <= scram_out ? 8'b1100_0000 : 8'b0100_0000; // -1 : 1
                re_we_a <= 1;
            end
            43: begin
                re_addr_a[5:0] <= 57; //IFFT 57
                re_din_a <= scram_out ? 8'b1100_0000 : 8'b0100_0000; // -1 : 1
                re_we_a <= 1;
            end
            57: begin
                re_addr_a[5:0] <= 0;
                re_we_a <= 0;
            end
            default: begin
                re_addr_a[5:0] <= 0;
                re_we_a <= 0;
            end
        endcase
    else begin
        re_addr_a[6] <= cnt_symbol[0] ? 1: 0;
        re_addr_a[5:0] <= 0;
        re_we_a <= 0;
    end
end

//cnt_symbol OFDM符号计数器 
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_symbol <= 0;
    else    if(pilot_index)
        cnt_symbol <= 0;
    else    if(wr_done) //一个OFDM符号写入完成 48个复数值
        cnt_symbol <= cnt_symbol + 1;
end

//insert
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        insert <= 0;
    else    if(re_addr_a[5:0] == 57)
        insert <= 0;
    else    if(wr_done || pilot_start)
        insert <= 1;
end

//im 虚部
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        im_we_a <= 0;
        im_addr_a <= 0;
        im_din_a <= 0;
    end
    else    if(pilot_en) begin //写入复数虚部样值
        im_addr_a[6] <= cnt_symbol[0] ? 1: 0;
        case (pilot_index)
            0,1,2,3,4: 
                im_addr_a[5:0] <= pilot_index + 38;
            5,6,7,8,9,10,11,12,13,14,15,16,17:
                im_addr_a[5:0] <= pilot_index + 39;
            18,19,20,21,22,23:
                im_addr_a[5:0] <= pilot_index + 40;
            24,25,26,27,28,29:
                im_addr_a[5:0] <= pilot_index - 23;
            30,31,32,33,34,35,36,37,38,39,40,41,42:
                im_addr_a[5:0] <= pilot_index - 22;
            43,44,45,46,47:
                im_addr_a[5:0] <= pilot_index - 21;
            default: im_addr_a[5:0] <= 0;
        endcase
        im_we_a <= 1;
        im_din_a <= pilot_din_im;
    end
    else begin
        im_addr_a[6] <= cnt_symbol[0] ? 1: 0;
        im_addr_a[5:0] <= 0;
        im_we_a <= 0;
    end
end

//************************************* 128*8 ram ************************************//

wire [7:0]  re_dout_a,im_dout_a;

spram_128 spram_re
(
    .rst_n       (rst_n     ),

    .clk_a       (clk       ),
    .we_a        (re_we_a   ),
    .addr_a      (re_addr_a ),
    .din_a       (re_din_a  ),
    .dout_a      (re_dout_a ),

    .clk_b       (clk       ),
    .we_b        (wen_out   ),
    .addr_b      (out_addr  ),
    .din_b       (din_b     ),
    .dout_b      (re_dout_b )
);

spram_128 spram_im
(
    .rst_n       (rst_n     ),

    .clk_a       (clk       ),
    .we_a        (im_we_a   ),
    .addr_a      (im_addr_a ),
    .din_a       (im_din_a  ),
    .dout_a      (im_dout_a ),

    .clk_b       (clk       ),
    .we_b        (wen_out   ),
    .addr_b      (out_addr  ),
    .din_b       (din_b     ),
    .dout_b      (im_dout_b )
);

//************************************* output ************************************//

/*reg   initialize ;

always@(posedge clk or negedge rst_n ) begin
    if(!rst_n)
        initialize  <= 1;  
    else if(out_addr==127)   
        initialize <= 0 ;
end*/

reg         rdy;
reg         dout_en;

//rdy
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rdy <= 0;
    else    if(out_addr[5:0] == 63)
        rdy <= 0;
    else    if(~pilot_en && pilot_en2)
        rdy <= 1;
end

//wen_out out_addr din_b
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wen_out <= 0;
        out_addr <= 0;
        din_b <= 0;
    end
    /*else    if(initialize) begin //初始化buffer
        wen_out <= 1;  //b端口写入
        out_addr <= out_addr + 1;
        din_b <= 0;
    end*/
    else    if(rdy) begin
        wen_out <= 0; //b端口输出
        out_addr <= out_addr + 1;
    end
    else
        wen_out <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dout_en<= 0;
    end
    else begin
        dout_en <= rdy;
    end
end

//output pilot_dout_re pilot_dout_im pilot_vld
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pilot_dout_re <= 0;
        pilot_dout_im <= 0;
        pilot_vld <= 0;
    end
    else    if(dout_en) begin  //输出一次64个数据
        pilot_dout_re <= re_dout_b;
        pilot_dout_im <= im_dout_b;
        pilot_vld <= 1;
    end
    else
        pilot_vld <= 0;  
end

endmodule