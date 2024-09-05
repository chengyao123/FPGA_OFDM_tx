`timescale 1ns / 1ps

module tb_test_ofdm ();

parameter  T = 20;

reg               sys_clk    ;
reg               sys_rst_n  ;
//MAC interface
wire              mac_clk    ;
wire              phy_status ; 
reg               txstart_req;
reg   [20:0]      tx_param   ;
reg   [7:0]       din        ;
reg               din_vld    ;
wire              din_req    ;
//data out
wire     [7:0]    dout_re    ;
wire     [7:0]    dout_im    ;
wire              dout_vld   ;
wire     [2:0]    dout_txpwr ;   

//50Mhz 
initial begin
    sys_clk = 1'b0;
end

always #(T/2) sys_clk = ~sys_clk;

parameter TX_PARAMETER ={12'd360-3, 6'd36, 3'd0}; 

ofdm_transmitter u_test
(
    .sys_clk        (sys_clk    ),
    .sys_rst_n      (sys_rst_n  ),

    .mac_clk        (mac_clk    ),
    .phy_status     (phy_status ), 
    .txstart_req    (txstart_req),
    .tx_param       (tx_param   ),
    .din            (din        ),
    .din_vld        (din_vld    ),
    .din_req        (din_req    ),

    .dout_re        (dout_re    ),
    .dout_im        (dout_im    ),
    .dout_vld       (dout_vld   ),
    .dout_txpwr     (dout_txpwr )
);

always @(posedge mac_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        din <= 0;
        din_vld <= 0;
    end
    else    if(din_req) begin
        if(din_vld) din <= din + $random(din + 142);
        else din <= 8'h55;
        din_vld <= 1;
    end
    else
        din_vld <= 0;
end

initial begin
    sys_rst_n = 1'b0;
    txstart_req = 0;
    tx_param = 0;
    #(20*T)
    sys_rst_n = 1'b1;

    #(500*T)
    @(posedge mac_clk);
        txstart_req = 1;
        tx_param = TX_PARAMETER;
    @(posedge mac_clk);
    @(posedge mac_clk);
        txstart_req = 0;
    //@(phy_status == 1);
    //@(phy_status == 0);
    @(posedge mac_clk);

    #(20000*T)
    $stop;
end

endmodule