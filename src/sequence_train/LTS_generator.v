module   LTS_generator
(  
    input                   clk         ,   
    input                   rst_n       ,   
    input                   tx_clr      ,   
    input                   lts_en      ,

    output reg [7:0]        lts_im      ,
    output reg [7:0]        lts_re      ,
    output reg              lts_dv      ,
    output reg [7:0]        lts_index   ,
    output reg              lts_done    
); 

reg  [15:0] long_mem [15:0];
reg  [3:0]  i,j;
wire        lts_req;

assign lts_req = lts_en || (lts_index > 0);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin  //时域样值 Re       Im
        long_mem[0]  <= {8'b00101000 , 8'b00000000};
        long_mem[1]  <= {8'b11111111 , 8'b11100001};
        long_mem[2]  <= {8'b00001010 , 8'b11100100};
        long_mem[3]  <= {8'b00011001 , 8'b00010101};
        long_mem[4]  <= {8'b00000101 , 8'b00000111};
        long_mem[5]  <= {8'b00001111 , 8'b11101010};
        long_mem[6]  <= {8'b11100011 , 8'b11110010};
        long_mem[7]  <= {8'b11110110 , 8'b11100101};
        long_mem[8]  <= {8'b00011001 , 8'b11111001};
        long_mem[9]  <= {8'b00001110 , 8'b00000001};
        long_mem[10] <= {8'b00000000 , 8'b11100011};
        long_mem[11] <= {8'b11011101 , 8'b11110100};
        long_mem[12] <= {8'b00000110 , 8'b11110001};
        long_mem[13] <= {8'b00001111 , 8'b11111100};
        long_mem[14] <= {8'b11111010 , 8'b00101001};
        long_mem[15] <= {8'b00011111 , 8'b11111111};
        long_mem[16] <= {8'b00010000 , 8'b11110000};
        long_mem[17] <= {8'b00001001 , 8'b00011001};
        long_mem[18] <= {8'b11110001 , 8'b00001010};
        long_mem[19] <= {8'b11011110 , 8'b00010001};
        long_mem[20] <= {8'b00010101 , 8'b00011000};
        long_mem[21] <= {8'b00010010 , 8'b00000100};
        long_mem[22] <= {8'b11110001 , 8'b00010101};
        long_mem[23] <= {8'b11110010 , 8'b11111010};
        long_mem[24] <= {8'b11110111 , 8'b11011001};
        long_mem[25] <= {8'b11100001 , 8'b11111100};
        long_mem[26] <= {8'b11011111 , 8'b11111011};
        long_mem[27] <= {8'b00010011 , 8'b11101101};
        long_mem[28] <= {8'b11111111 , 8'b00001110};
        long_mem[29] <= {8'b11101000 , 8'b00011101};
        long_mem[30] <= {8'b00010111 , 8'b00011011};
        long_mem[31] <= {8'b00000011 , 8'b00011001};
        long_mem[32] <= {8'b11011000 , 8'b00000000};
        long_mem[33] <= {8'b00000011 , 8'b11100111};
        long_mem[34] <= {8'b00010111 , 8'b11100101};
        long_mem[35] <= {8'b11101000 , 8'b11100011};
        long_mem[36] <= {8'b11111111 , 8'b11110010};
        long_mem[37] <= {8'b00010011 , 8'b00010011};
        long_mem[38] <= {8'b11011111 , 8'b00000101};
        long_mem[39] <= {8'b11100001 , 8'b00000100};
        long_mem[40] <= {8'b11110111 , 8'b00100111};
        long_mem[41] <= {8'b11110010 , 8'b00000110};
        long_mem[42] <= {8'b11110001 , 8'b11101011};
        long_mem[43] <= {8'b00010010 , 8'b11111100};
        long_mem[44] <= {8'b00010101 , 8'b11101000};
        long_mem[45] <= {8'b11011110 , 8'b11101111};
        long_mem[46] <= {8'b11110001 , 8'b11110110};
        long_mem[47] <= {8'b00001001 , 8'b11100111};
        long_mem[48] <= {8'b00010000 , 8'b00010000};
        long_mem[49] <= {8'b00011111 , 8'b00000001};
        long_mem[50] <= {8'b11111010 , 8'b11010111};
        long_mem[51] <= {8'b00001111 , 8'b00000100};
        long_mem[52] <= {8'b00000110 , 8'b00001111};
        long_mem[53] <= {8'b11011101 , 8'b00001100};
        long_mem[54] <= {8'b00000000 , 8'b00011101};
        long_mem[55] <= {8'b00001110 , 8'b11111111};
        long_mem[56] <= {8'b00011001 , 8'b00000111};
        long_mem[57] <= {8'b11110110 , 8'b00011011};
        long_mem[58] <= {8'b11100011 , 8'b00001110};
        long_mem[59] <= {8'b00001111 , 8'b00010110};
        long_mem[60] <= {8'b00000101 , 8'b11111001};
        long_mem[61] <= {8'b00011001 , 8'b11101011};
        long_mem[62] <= {8'b00001010 , 8'b00011100};
        long_mem[63] <= {8'b11111111 , 8'b00011111};
        lts_dv <= 0;
        lts_index <=  0;
        lts_done <= 0;
        lts_re <= 0;
        lts_im <= 0;
        i <= 0;
        j <= 0;
    end
    else if( tx_clr ) begin 
        i <= 0;
        j <= 0;
        lts_dv <= 0;
        lts_index <= 0;
        lts_done <= 0;
    end
    else if( lts_req && (lts_index < 161) ) begin
        lts_index <= lts_index + 1;
        lts_dv <=  1'b1;
        if(i == 0) begin
            if(j == 31) begin
                j <= 0;
                i <= i + 1;
                lts_re <= long_mem[j+32][15:8];
                lts_im <= long_mem[j+32][7:0];
            end
            else begin
                if(j == 0) begin
                    lts_re <= 8'b11101100; //短训练序列到长训练序列的窗口函数
                    lts_im <= long_mem[j+32][7:0];
                end
                else begin
                    lts_re <= long_mem[j+32][15:8];
                    lts_im <= long_mem[j+32][7:0];
                end
                j <= j + 1;
            end
        end
        else if(i == 1 || i == 2) begin
            if(j == 63) begin
                j <= 0;
                i <= i + 1;
                lts_re <= long_mem[j][15:8];
                lts_im <= long_mem[j][7:0];
            end
            else begin
                lts_re <= long_mem[j][15:8];
                lts_im <= long_mem[j][7:0];
                j <= j + 1;
            end    
        end
        else begin  //  加窗处理
            lts_re <= long_mem[j][15:8]>>1; //加窗，右移一位 
            lts_im <= long_mem[j][7:0]>>1;
            lts_done <= 1'b1;
        end
    end
    else begin
        lts_dv <= 1'b0;
    end
end

endmodule