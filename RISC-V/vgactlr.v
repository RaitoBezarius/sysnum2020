module vgactlr(cpu_bus, led1, clk);

inout [31:0] cpu_bus;
output reg [2:0] led1;
input clk;

always @(posedge clk) begin
  if (cpu_bus == 32'b1) begin
    led1 = ~ led1;
  end
end
endmodule
