/*
    交织：一级分组交织器 i = (N_CBPS / 16)(kmod16) + floor(k/16), k = 0,1,...,N_CBPS-1 

    调制方式           交织深度（bit）
      BPSK              48          
      QPSK              96
      16-QAM            192
      64-QAM            288
    
    Signal域符号采用BPSK调制，因此其交织只涉及第一级变换

    Data域符号采用16-QAM调制，需要两级交织处理
    第一级为标准的分组交织器
    第二级交织为每24个比特为一个单元，前12个顺序保持不变，后12个每相邻两位交换位置
*/

module data_interleaver 
#(
    parameter SIGNAL_INTV_TO_QAM_FRE = 4  //QAM_FRONT_FREQUENCY / QAM_BACK_FREQUENCY  80M/20M
)
(
    input               cb_clk          , //80Mhz
    input               rst_n           ,

    input               intv_din        ,
    input               intv_en         ,
    input       [1:0]   intv_con        , //type 48bit,96bit,192bit,288bit
    input               signal_flag_in  ,

    output reg  [1:0]   map_type        ,
    output reg          intv_dout       ,
    output reg          intv_vld        
);

localparam  N_48 =2'b00,
            N_96 =2'b01,
            N_192=2'b10,
            N_288=2'b11;

reg         i;
reg         we_a;
reg [8:0]   addr_a;
reg         din_a;
wire        we_b;
reg [8:0]   addr_b;
wire        dout_b;

reg [8:0]   cnt_index;
reg [8:0]   cnt_index_max;
wire        end_cnt_index;
wire        add_cnt_index;

reg         buf_a_flag;
reg         buf_b_flag;
reg [8:0]   data_buf_len;

reg         signal_flag_reg;

reg [1:0]   intv_con1;

reg [8:0]   cnt_bit;
reg [3:0]   cnt_bit_12;  //模12计数器
reg         back_12bits; //每相邻两位交换位置

reg [2:0]   signal_bit_cnt;
reg [2:0]   signal_interval_time;


//*************************** Write Data Buffer ****************************//

always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        cnt_index <= 0;
    else    if(end_cnt_index)
        cnt_index <= 0;
    else    if(add_cnt_index)
        cnt_index <= cnt_index + 1'b1;
end

assign  add_cnt_index = intv_en;
assign  end_cnt_index = add_cnt_index && (cnt_index == cnt_index_max - 1);

always @(*) begin
    case (intv_con)
        N_48 : cnt_index_max <= 48;
        N_96 : cnt_index_max <= 96;
        N_192: cnt_index_max <= 192;
        N_288: cnt_index_max <= 288;
        default: cnt_index_max <= 48;
    endcase  
end

//流水线设计结构，能够对数据进行连续处理
//乒乓缓存，交叉写入buffer
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        we_a <= 0;
        addr_a <= 0;
        din_a <= 0;
        i <= 0;
    end
    else    if(add_cnt_index && (i == 0)) begin
        case (intv_con)
            N_48: begin     //N = 48
                we_a <= 1;  //i = (48/16)(cnt_index mod16) + floor(cnt_index/16) = 3 * cnt_index[3:0] + (cnt_index>>4)
                addr_a <= cnt_index[3:0] + (cnt_index[3:0] << 1) + cnt_index[8:4]; //cnt_index * 3 (N / 16 = 3)
                din_a <= intv_din;
            end
            N_96: begin     //N = 96
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 1) + (cnt_index[3:0] << 2) + cnt_index[8:4]; //cnt_index * 6
                din_a <= intv_din;
            end
            N_192: begin     //N = 192
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 2) + (cnt_index[3:0] << 3) + cnt_index[8:4]; //cnt_index * 12
                din_a <= intv_din;
            end
            N_288: begin     //N = 288
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 4) + (cnt_index[3:0] << 1) + cnt_index[8:4]; //cnt_index * 18
                din_a <= intv_din;
            end
            default:;
        endcase
        if(end_cnt_index)   i <= 1;
    end
    else    if(add_cnt_index && (i == 1)) begin
        case (intv_con)
            N_48: begin     //N = 48
                we_a <= 1;
                addr_a <= cnt_index[3:0] + (cnt_index[3:0] << 1) + cnt_index[8:4] + 288; //cnt_index * 3 (N / 16 = 3)
                din_a <= intv_din;
            end
            N_96: begin     //N = 96
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 1) + (cnt_index[3:0] << 2) + cnt_index[8:4] + 288; //cnt_index * 6
                din_a <= intv_din;
            end
            N_192: begin     //N = 192
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 2) + (cnt_index[3:0] << 3) + cnt_index[8:4] + 288; //cnt_index * 12
                din_a <= intv_din;
            end
            N_288: begin     //N = 288
                we_a <= 1;
                addr_a <= (cnt_index[3:0] << 4) + (cnt_index[3:0] << 1) + cnt_index[8:4] + 288; //cnt_index * 18
                din_a <= intv_din;
            end
            default:;
        endcase
        if(end_cnt_index)   i <= 0;
    end
    else
        we_a <= 0;
end

sync_buffer  spram
(
    .rst_n      (rst_n  ),

    .clk_a      (cb_clk ),
    .we_a       (we_a   ),
    .addr_a     (addr_a ),
    .din_a      (din_a  ),
    .dout_a     (       ),

    .clk_b      (cb_clk ),
    .we_b       (we_b   ),
    .addr_b     (addr_b ),
    .din_b      (       ),
    .dout_b     (dout_b )
);

assign  we_b = 0;

//*************************** Read Data Buffer ****************************//

//buf_a_flag 流水线A完成标志位
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        buf_a_flag <= 0;
    else    if(buf_a_flag && (cnt_bit == data_buf_len - 1))
        buf_a_flag <= 0;
    else    if(end_cnt_index && (i == 0))
        buf_a_flag <= 1;
end

//buf_b_flag 流水线B完成标志位
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        buf_b_flag <= 0;
    else    if(buf_b_flag && (cnt_bit == data_buf_len - 1))
        buf_b_flag <= 0;
    else    if(end_cnt_index && (i == 1))
        buf_b_flag <= 1;
end

//signal_flag_reg data_buf_len
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        signal_flag_reg <= 0;
        data_buf_len <= 0;
    end
    else    if(signal_flag_reg && (signal_bit_cnt >= 48 - 1) && (signal_interval_time >= SIGNAL_INTV_TO_QAM_FRE - 1)) begin
        signal_flag_reg <= 0;
    end
    else    if(end_cnt_index) begin
        signal_flag_reg <= signal_flag_in;
        data_buf_len <= cnt_index_max;
    end
end

//signal_interval_time signal交织周期 4个cb_clk
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) 
        signal_interval_time <= 0;
    else    if(signal_flag_reg)
        if(signal_interval_time >= SIGNAL_INTV_TO_QAM_FRE - 1)
            signal_interval_time <= 0;
        else
            signal_interval_time <= signal_interval_time + 1'b1;
end

//signal_bit_cnt signal交织rd计数器
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        signal_bit_cnt <= 0;
    else    if(signal_flag_reg && (signal_interval_time >= SIGNAL_INTV_TO_QAM_FRE - 1))
        if(signal_bit_cnt >= data_buf_len - 1)
            signal_bit_cnt <= 0;
        else
            signal_bit_cnt <= signal_bit_cnt + 1'b1;
end

//cnt_bit back_12bits cnt_bit_12
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt_bit <= 0;
        back_12bits <= 0;
        cnt_bit_12 <= 0;
    end
    else    if(buf_a_flag || buf_b_flag) begin
        begin
            if(cnt_bit == data_buf_len - 1) //rd 计数器
                cnt_bit <= 0;
            else
                cnt_bit <= cnt_bit + 1'b1;
        end
        begin
            if((back_12bits == 1) && cnt_bit_12 == 11) //bit交换标志位
                back_12bits <= 0;
            else    if(cnt_bit_12 == 11)
                back_12bits <= 1;
        end
        begin
            if(cnt_bit_12 == 11) //12bit计数器
                cnt_bit_12 <= 0;
            else
                cnt_bit_12 <= cnt_bit_12 + 1'b1;
        end
    end 
end

reg rd_buf_vld;

//顺序读出或二级交织错位读出 
//addr_b rd_buf_vld 二级交织
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_b <= 0;
        rd_buf_vld <= 0;
    end
    else    if(buf_a_flag && ~signal_flag_reg) begin
        rd_buf_vld <= 1;
        if(back_12bits == 0)
            addr_b <= cnt_bit;
        else    if(back_12bits == 1) //后12bit两两交换 00 01 10 11 → 10 11 00 01
            case (cnt_bit[1:0])
                2'b00: addr_b <= {cnt_bit[8:2],2'b10};
                2'b01: addr_b <= {cnt_bit[8:2],2'b11};
                2'b10: addr_b <= {cnt_bit[8:2],2'b00};
                2'b11: addr_b <= {cnt_bit[8:2],2'b01};
                default:;
            endcase
    end
    else    if(buf_b_flag && ~signal_flag_reg) begin
        rd_buf_vld <= 1;
        if(back_12bits == 0)
            addr_b <= 288 + cnt_bit;
        else    if(back_12bits == 1) //后12bit两两交换
            case (cnt_bit[1:0])
                2'b00: addr_b <= 288 + {cnt_bit[8:2],2'b10};
                2'b01: addr_b <= 288 + {cnt_bit[8:2],2'b11};
                2'b10: addr_b <= 288 + {cnt_bit[8:2],2'b00};
                2'b11: addr_b <= 288 + {cnt_bit[8:2],2'b01};
                default:;
            endcase
    end 
    else    if(signal_flag_reg && (signal_interval_time >= SIGNAL_INTV_TO_QAM_FRE - 1)) begin
        addr_b <= signal_bit_cnt;
        rd_buf_vld <= 1;
    end
    else
        rd_buf_vld <= 0;
end

//output intv_dout intv_vld
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        intv_dout <= 0;
        intv_vld <= 0;
    end
    else    if(rd_buf_vld) begin
        intv_dout <= dout_b;
        intv_vld <= 1;
    end
    else
        intv_vld <= 0;
end

//intv_con1
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        intv_con1 <= 0;
    else    if(end_cnt_index)
        intv_con1 <= intv_con;
end

//output map_type
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        map_type <= 0;
    else    if((buf_a_flag || buf_b_flag) && (cnt_bit == 0))
        map_type <= intv_con1;
end

endmodule
