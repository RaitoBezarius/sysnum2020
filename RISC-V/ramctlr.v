module ramctlr(ram_link, cpu_link_adress, cpu_link_write, cpu_link_read, write_enable, clk);

input [15:0] ram_link;
input clk;
input [31:0] cpu_link_write;
input [31:0] cpu_link_adress;
output reg [31:0] cpu_link_read;
input write_enable;

reg [31:0] RAM [127:0];

integer i;
initial
  begin
    for(i=0;i<128;i=i+1)
      RAM[i] = 32'b0;
  end

always @(posedge clk) begin
  if (write_enable) begin
    RAM[cpu_link_adress] <= cpu_link_write;
  end
  cpu_link_read = RAM[cpu_link_adress];
end

endmodule
