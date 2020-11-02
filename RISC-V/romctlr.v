module romctlr(rom_link, cpu_link_read, cpu_link_address, clk);

input [15:0] rom_link;
input clk;
input [31:0] cpu_link_address;
output reg [31:0] cpu_link_read;

reg [31:0] ROM [127:0];
initial $readmemh("rom02", ROM);

always @(posedge clk) begin
  cpu_link_read = ROM[cpu_link_address];
end
endmodule
