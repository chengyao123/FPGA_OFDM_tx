/*
    映射：

    调制方式        K(mod)
      BPSK          1               //signal域  1bit
      QPSK          1/√2
      16QAM         1/√10           //data数据  4bit 
      64QAM         1/√42

        16QAM编码表
    b0b1        Re/I        b2b3        Im/Q    //b为输入 4bit一组 输入b0在最前面
    00          -3          00          -3
    01          -1          01          -1
    11          1           11          1
    10          3           10          3 

    经映射后得到I/Q数据乘上1/√10进行归一化，即得到调制后的I/Q值

    d = (I + jQ) * K(mod) (K为归一化因子)

    signal 1bit     data 4bit

    需要跨时钟域处理，将数据传输速率从80M → 20M
*/

module data_mapping 
(
    input               cb_clk      , //80Mhz
    input               clk         , //20Mhz
    input               rst_n       ,
    input               tx_clr      ,

    input       [1:0]   map_type    , //映射类型
    input               QAM16_din   ,
    input               QAM16_en    ,

    output reg  [7:0]   QAM16_re    , //映射后的I 实部
    output reg  [7:0]   QAM16_im    , //映射后的Q 虚部
    output reg          QAM16_vld   ,
    output reg  [5:0]   index_out     //输出标号
);

//80Mhz
reg     [5:0]   map_bits;
reg     [5:0]   map_bits_reg;
reg     [1:0]   map_type_reg;
reg             map_bits_vld_80m;
wire            map_vld_80m_20m;

reg     [2:0]   cnt_bits;
reg     [2:0]   cnt_bits_max;
wire            end_cnt_bits;
wire            add_cnt_bits;

//20Mhz
reg             map_bits_vld_20m;
reg     [5:0]   map_bits_20m;
reg     [1:0]   map_type_20m; 

always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n || tx_clr)
        cnt_bits <= 0;
    else    if(end_cnt_bits)
        cnt_bits <= 0;
    else    if(add_cnt_bits)
        cnt_bits <= cnt_bits + 1'b1;
end

assign  add_cnt_bits = QAM16_en;
assign  end_cnt_bits = add_cnt_bits && (cnt_bits == cnt_bits_max - 1);

always @(*) begin
    case (map_type)
        2'b00: cnt_bits_max = 1;     //BPSK
        2'b01: cnt_bits_max = 2;     //QPSK
        2'b10: cnt_bits_max = 4;     //16-QAM
        2'b11: cnt_bits_max = 6;     //64-QAM 
        default: cnt_bits_max = 1;
    endcase
end

// 通过调制方式不同，得到cnt_bits不同的最大值，进行缓存
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n)
        map_bits <= 0;
    else    if(add_cnt_bits)
        case (map_type)
            2'b00: 
                case (cnt_bits)
                    0: map_bits[0] <= QAM16_din;
                    default:; 
                endcase
            2'b01:
                case (cnt_bits)
                    0: map_bits[0] <= QAM16_din;
                    1: map_bits[1] <= QAM16_din;
                    default:; 
                endcase
            2'b10:
                case (cnt_bits)
                    0: map_bits[0] <= QAM16_din;
                    1: map_bits[1] <= QAM16_din;
                    2: map_bits[2] <= QAM16_din;
                    3: map_bits[3] <= QAM16_din;
                    default:; 
                endcase
            2'b11:
                case (cnt_bits)
                    0: map_bits[0] <= QAM16_din;
                    1: map_bits[1] <= QAM16_din;
                    2: map_bits[2] <= QAM16_din;
                    3: map_bits[3] <= QAM16_din;
                    4: map_bits[4] <= QAM16_din;
                    5: map_bits[5] <= QAM16_din;
                    default:; 
                endcase
            default:;
        endcase
end

//map_bits_reg map_type_reg map_bits_vld_80m
always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        map_bits_reg <= 0;
        map_type_reg <= 0;
        map_bits_vld_80m <= 0;
    end
    else    if(end_cnt_bits) begin
        map_bits_reg <= map_bits;
        map_type_reg <= map_type;
        map_bits_vld_80m <= 1;
    end
    else
        map_bits_vld_80m <= 0;
end

//打拍
reg map_bits_vld_80m1,map_bits_vld_80m2,map_bits_vld_80m3;

always @(posedge cb_clk or negedge rst_n) begin
    if(!rst_n) begin
        map_bits_vld_80m1 <= 0;
        map_bits_vld_80m2 <= 0;
        map_bits_vld_80m3 <= 0;
    end
    else begin
        map_bits_vld_80m1 <= map_bits_vld_80m;
        map_bits_vld_80m2 <= map_bits_vld_80m1;
        map_bits_vld_80m3 <= map_bits_vld_80m2;
    end
end

assign  map_vld_80m_20m = map_bits_vld_80m3 || map_bits_vld_80m2 || map_bits_vld_80m1 || map_bits_vld_80m;

//***************************************** 跨时钟域处理 *************************************************//
//***************************************** 映射并归一化 *************************************************//

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        map_bits_vld_20m <= 0;
        map_bits_20m <= 0;
        map_type_20m <= 0;
    end
    else    if(map_vld_80m_20m) begin
        map_bits_vld_20m <= 1;
        map_bits_20m <= map_bits_reg;
        map_type_20m <= map_type_reg;
    end
    else
        map_bits_vld_20m <= 0;
end

// 映射，输出的8bits数据为经过归一化处理后的数据
// 映射后的数据格式为8位：一位符号位，一位整数位，六位小数位，负数用补码表示
always @(posedge clk or negedge rst_n) begin
    if(!rst_n || tx_clr) begin
        QAM16_re  <= 0;
        QAM16_im  <= 0;
        QAM16_vld <= 0;
        index_out <= 6'b111_111;
    end
    else    if(map_bits_vld_20m)
        case (map_type_20m)
            2'b00: begin     //BPSK
                case (map_bits_20m[0])
                    1'b0: QAM16_re <= 8'b1100_0000; //-1 * 1
                    1'b1: QAM16_re <= 8'b0100_0000; // 1 * 1
                    default: QAM16_re <= 0;
                endcase
                QAM16_im <= 8'b0000_0000;
                QAM16_vld <= 1;
                index_out <= index_out + 1'b1;
            end
            2'b01: begin     //QPSK
                case (map_bits_20m[0])
                    1'b0: QAM16_re <= 8'b1101_0011; //-1 * 1/√2 = -0.703125
                    1'b1: QAM16_re <= 8'b0010_1101; // 1 * 1/√2 = 0.703125
                    default: QAM16_re <= 0;
                endcase
                case (map_bits_20m[1])
                    1'b0: QAM16_im <= 8'b1101_0011;
                    1'b1: QAM16_im <= 8'b0010_1101;
                    default: QAM16_im <= 0;
                endcase
                QAM16_vld <= 1;
                index_out <= index_out + 1'b1;
            end
            2'b10: begin     //16-QAM
                case (map_bits_20m[1:0])    //负数用 补码 = 原码的反码 + 1
                    2'b00: QAM16_re <= 8'b1100_0011; //-3 * 1/√10 = -0.953125 归一化
                    2'b10: QAM16_re <= 8'b0011_1101; // 3 * 1/√10 = 0.953125
                    2'b01: QAM16_re <= 8'b1110_1100; //-1 * 1/√10 = -0.3125
                    2'b11: QAM16_re <= 8'b0001_0100; // 1 * 1/√10 = 0.3125
                    default: QAM16_re <= 0;
                endcase
                case (map_bits_20m[3:2])
                    2'b00: QAM16_im <= 8'b1100_0011;
                    2'b10: QAM16_im <= 8'b0011_1101;
                    2'b01: QAM16_im <= 8'b1110_1100;
                    2'b11: QAM16_im <= 8'b0001_0100;
                    default: QAM16_im <= 0;
                endcase
                QAM16_vld <= 1;
                index_out <= index_out + 1'b1;
            end
            2'b11: begin     //64-QAM
                case (map_bits_20m[2:0])
                    3'b000: QAM16_re <= 8'b1011_1011; //-7 * 1/√42 = -1.078125
                    3'b100: QAM16_re <= 8'b0100_0101; // 7 * 1/√42 = 1.078125
                    3'b001: QAM16_re <= 8'b1100_1111; //-5 * 1/√42 = -0.765625
                    3'b101: QAM16_re <= 8'b0011_0001; // 5 * 1/√42 = 0.765625
                    3'b011: QAM16_re <= 8'b1110_0011; //-3 * 1/√42 = -0.453125
                    3'b111: QAM16_re <= 8'b0001_1101; // 3 * 1/√42 = 0.453125
                    3'b010: QAM16_re <= 8'b1111_0111; //-1 * 1/√42 = -0.140625
                    3'b110: QAM16_re <= 8'b0000_1001; // 1 * 1/√42 = 0.140625
                    default: QAM16_re <= 0;
                endcase
                case (map_bits_20m[5:3])
                    3'b000: QAM16_im <= 8'b1011_1011;
                    3'b100: QAM16_im <= 8'b0100_0101;
                    3'b001: QAM16_im <= 8'b1100_1111;
                    3'b101: QAM16_im <= 8'b0011_0001;
                    3'b011: QAM16_im <= 8'b1110_0011;
                    3'b111: QAM16_im <= 8'b0001_1101;
                    3'b010: QAM16_im <= 8'b1111_0111;
                    3'b110: QAM16_im <= 8'b0000_1001;
                    default: QAM16_im <= 0;
                endcase
                QAM16_vld <= 1;
                index_out <= index_out + 1'b1;
            end
            default:;
        endcase
    else begin
        QAM16_vld <= 0;
        index_out <= 6'b111_111;
    end
end

endmodule