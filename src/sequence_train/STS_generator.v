module   STS_generator
(  
    input                   clk         ,   
    input                   rst_n       ,   
    input                   tx_clr      ,   
    input                   sts_en      ,

    output reg [7:0]        sts_im      ,
    output reg [7:0]        sts_re      ,
    output reg              sts_dv     ,
    output reg [7:0]        sts_index   ,
    output reg              sts_done             
);

reg  [15:0] short_mem [15:0];
reg  [3:0]  i,j;
wire        sts_req;

assign sts_req = sts_en || (sts_index > 0);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin  //时域样值Re       Im
        short_mem[0]  <= {8'b00001100 , 8'b00001100};
        short_mem[1]  <= {8'b11011110 , 8'b00000001};
        short_mem[2]  <= {8'b11111101 , 8'b11101100};
        short_mem[3]  <= {8'b00100100 , 8'b11111101};
        short_mem[4]  <= {8'b00011000 , 8'b00000000};
        short_mem[5]  <= {8'b00100100 , 8'b11111101};
        short_mem[6]  <= {8'b11111101 , 8'b11101100};
        short_mem[7]  <= {8'b11011110 , 8'b00000001};
        short_mem[8]  <= {8'b00001100 , 8'b00001100};
        short_mem[9]  <= {8'b00000001 , 8'b11011110};
        short_mem[10] <= {8'b11101100 , 8'b11111101};
        short_mem[11] <= {8'b11111101 , 8'b00100100};
        short_mem[12] <= {8'b00000000 , 8'b00011000};
        short_mem[13] <= {8'b11111101 , 8'b00100100};
        short_mem[14] <= {8'b11101100 , 8'b11111101};
        short_mem[15] <= {8'b00000001 , 8'b11011110};
        sts_dv <= 0;
        sts_index <=  0;
        sts_done <= 0;
        sts_re <= 0;
        sts_im <= 0;
        i <= 0;
        j <= 0;
       end  
    else if( tx_clr ) begin 
        i <= 0;
        j <= 0;
        sts_dv <= 0;
        sts_index <= 0;
        sts_done <= 0;
    end
    else if( sts_req && (sts_index < 161) ) begin
        sts_index <= sts_index + 1;
        sts_dv <=  1'b1; 
        if(i < 10)    begin
            if(j == 15) begin 
                j <= 0;
                i <= i+ 1; 
                sts_re <= short_mem[j][15:8];  
                sts_im <= short_mem[j][7:0];
            end
            else  begin
                if(i == 0 && j == 0) begin
                    sts_re <= short_mem[j][15:8]>>1; //加窗，右移一 
                    sts_im <= short_mem[j][7:0]>>1; //注意：short_mem[0]为正数
                end
                else begin
                    sts_re <= short_mem[j][15:8];  
                    sts_im <= short_mem[j][7:0];
                end
                j <= j + 1;
            end
        end
        else begin  //最后一位
            sts_re <= short_mem[0][15:8]>>1; //加窗，右移一  第一个值
            sts_im <= short_mem[0][7:0]>>1; 
            sts_done <= 1'b1;
        end
    end 
    else begin 
        sts_dv <= 1'b0;
    end
end

endmodule