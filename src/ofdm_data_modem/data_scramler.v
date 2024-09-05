// 扰码：S(x) = x^7 + x^4 + 1 
module data_scramler
(
    input               clk             , //20Mhz
    input               rst_n           ,

    input               scram_din       ,
    input               scram_en        ,
    input       [6:0]   scram_seed      , //移位寄存器初始化向量
    input               tx_clr          , //扰码初始化
    input               singal_flag_in  ,
    output  reg         signal_flag_out ,
    output  reg         scram_dout      ,
    output  reg         scram_vld       
);

reg     [6:0]       shift_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_reg <= 0;
        scram_dout <= 0;
        scram_vld <= 0;
    end 
    else    if(tx_clr) begin
        shift_reg <= scram_seed;
        scram_vld <= 0;
    end
    else    if(scram_en && ~singal_flag_in) begin
        scram_dout <= shift_reg[6] + shift_reg[3] + scram_din; //s(x) = x^7 + x^4 + 1 
        scram_vld <= 1;
        shift_reg <= {shift_reg[5:0],(shift_reg[6] + shift_reg[3])}; //寄存器自移位
    end
    else    if(scram_en && singal_flag_in) begin //signal信号不扰码
        scram_dout <= scram_din;
        scram_vld <= 1;
    end
    else begin
        scram_vld <= 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        signal_flag_out <= 0;
    else    if(~singal_flag_in)
        signal_flag_out <= 0;
    else    if(singal_flag_in)
        signal_flag_out <= 1;
end

endmodule