/*
    卷积编码 (1,6,2) //1输入, 深度6, 2输出

    Sa(x) = x^6 + x^5 + x^3 + x^2 + 1
    Sb(x) = x^6 + x^3 + x^2 + x^1 + 1
*/
module data_conv_code 
(
    input                   din_clk         ,//60Mhz
    input                   rst_n           ,

    input                   singal_flag_in  ,
    input                   conv_din        ,//bit输入 lsb在前，msb在后
    input                   conv_en         ,
    output  reg             signal_flag_out ,
    output  reg     [1:0]   conv_dout       ,
    output  reg             conv_vld        
);

reg     [5:0]   shift_reg;

always @(posedge din_clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_reg <= 0;
        conv_dout <= 0;
        conv_vld <= 0;
    end
    else    if(conv_en) begin //每输入1比特数据，都将会同时输出2比特数据A和B，实现1/2码率的卷积编码
        conv_dout[0] <= shift_reg[5] + shift_reg[4] + shift_reg[2] + shift_reg[1] + conv_din;
        conv_dout[1] <= shift_reg[5] + shift_reg[2] + shift_reg[1] + shift_reg[0] + conv_din;
        conv_vld <= 1;
        shift_reg <= {shift_reg[4:0],conv_din}; //移位寄存器  
    end
    else
        conv_vld <= 0;
end

always @(posedge din_clk or negedge rst_n) begin
    if(!rst_n)
        signal_flag_out <= 0;
    else    if(~singal_flag_in)
        signal_flag_out <= 0;
    else    if(singal_flag_in)
        signal_flag_out <= 1;
end

endmodule