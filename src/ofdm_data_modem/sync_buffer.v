/* allows simultaneous 1-read-1-write */
/* check read/write flag before calling */

module sync_buffer
(
    input           rst_n   ,

    input           clk_a   ,
    input           we_a    ,
    input   [8:0]   addr_a  ,
    input           din_a   ,
    output          dout_a  ,

    input           clk_b   ,
    input           we_b    ,
    input   [8:0]   addr_b  ,
    input           din_b   ,
    output          dout_b  
);

integer i;
reg [0:0]   int_mem [575:0];
reg [0:0]   out_mem_a;
reg [0:0]   out_mem_b;
/*
always @(negedge rst_n) begin
    for (i = 0; i < `LPVLC_MEM_BUF_SIZE; i = i + 1) begin
        int_mem[i] <= 0;
    end
end
*/
always @(posedge clk_a) begin
    if(we_a)
        int_mem[addr_a] <= din_a;
    else
        out_mem_a[addr_a] <= int_mem[addr_a];
end

always @(posedge clk_b) begin
    if(we_b)
        int_mem[addr_b] <= din_b;
    else
        out_mem_b[addr_b] <= int_mem[addr_b];
end

assign  dout_a = we_a ? 0 : out_mem_a;
assign  dout_b = we_b ? 0 : out_mem_b;

endmodule