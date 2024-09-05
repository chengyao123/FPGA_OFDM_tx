module   symbol_train
(  
    input               clk         ,   
    input               rst_n       ,   
    input               tx_clr      ,   
    input               start_en    ,

    output  [7:0]       train_im    ,
    output  [7:0]       train_re    ,
    output              train_dv    ,
    output  [8:0]       train_index ,
    output              train_done  
); 

wire        sts_en;
(* mark_debug = "true" *)   wire    [7:0]       sts_im;
(* mark_debug = "true" *)   wire    [7:0]       sts_re;
(* mark_debug = "true" *)   wire                sts_dv;
wire        sts_index;
wire        sts_done;

wire        lts_en;
(* mark_debug = "true" *)   wire    [7:0]       lts_im;
(* mark_debug = "true" *)   wire    [7:0]       lts_re;
(* mark_debug = "true" *)   wire                lts_dv;
wire        lts_index;
wire        lts_done;

STS_generator STS
(  
    .clk         (clk),   
    .rst_n       (rst_n),   
    .tx_clr      (tx_clr),   
    .sts_en      (sts_en), 

    .sts_im      (sts_im),
    .sts_re      (sts_re),
    .sts_dv      (sts_dv),
    .sts_index   (sts_index),
    .sts_done    (sts_done)         
); 

LTS_generator LTS
(  
    .clk         (clk),   
    .rst_n       (rst_n),   
    .tx_clr      (tx_clr),   
    .lts_en      (lts_en),

    .lts_im      (lts_im),
    .lts_re      (lts_re),
    .lts_dv      (lts_dv),
    .lts_index   (lts_index),
    .lts_done    (lts_done)
); 

assign  train_im = sts_dv ? sts_im : lts_dv ? lts_im : 8'b0;
assign  train_re = sts_dv ? sts_re : lts_dv ? lts_re : 8'b0;
assign  train_dv = sts_dv ? 1'b1 : lts_dv ? 1'b1 : 1'b0;
assign  train_index = sts_index + lts_index;
assign  train_done = lts_done;

assign  sts_en = start_en;
assign  lts_en = sts_done;

endmodule