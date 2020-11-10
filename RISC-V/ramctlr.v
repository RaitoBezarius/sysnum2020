module ramctlr(DATA, ADDR_OUT, ADDR_IN, VALUE, WD, clk1, clk2);

output reg [31:0] DATA;

input clk1, clk2;

input [31:0] VALUE;
input [31:0] ADDR_OUT;
input [31:0] ADDR_IN;

reg [31:0] ADDR_OUT_reg;

input WD;

reg [31:0] RAM [127:0];

integer i;
initial
  begin
    for(i=0;i<128;i=i+1)
      RAM[i] = 32'b0;
  end

always @(posedge clk1) begin
  DATA <= RAM[ADDR_OUT_reg];
  ADDR_OUT_reg <= ADDR_OUT;
end

always @(posedge clk2) begin
  if (WD)
    RAM[ADDR_IN] <= VALUE;
end

endmodule
