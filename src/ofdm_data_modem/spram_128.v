/* allows simultaneous 1-read-1-write */
/* check read/write flag before calling */

module spram_128 
(
    input           rst_n       ,

    input           clk_a       ,
    input           we_a        ,
    input   [6:0]   addr_a      ,
    input   [7:0]   din_a       ,
    output  [7:0]   dout_a      ,

    input           clk_b       ,
    input           we_b        ,
    input   [6:0]   addr_b      ,
    input   [7:0]   din_b       ,
    output  [7:0]   dout_b      
);

integer i;
reg [7:0]   int_mem [127:0];
reg [7:0]   out_mem_a;
reg [7:0]   out_mem_b;

always @(negedge rst_n) begin
    for (i = 0; i < 128; i = i + 1) begin
        int_mem[i] <= 0;
    end
end

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