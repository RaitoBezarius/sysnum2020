`default_nettype none

module block_ram
#(
  parameter XLEN = 32,
  parameter LGMEMSZ = 9,
  parameter W = XLEN
)
(
  i_clk, i_reset, i_wb_stb, i_addr, i_data,
  i_wb_we, i_wb_sel,
  o_wb_data, o_wb_stall, o_wb_ack
);

// Wishbone slave control
input wire i_clk, i_wb_stb, i_reset;

input wire [W-1:0] i_addr;
input wire [W-1:0] i_data;
input wire i_wb_we; // Write enable
input wire [2:0] i_wb_sel; // Byte enable
output reg [W-1:0] o_wb_data;

output wire o_wb_stall;
output reg o_wb_ack;

// RAM block
reg [W-1:0] ram [(1 << LGMEMSZ) - 1:0];

integer k;
initial 
begin
  for (k = 0; k < (1 << LGMEMSZ); k = k + 1)
    ram[k] = 0;
end

assign o_wb_stall = 1'b0; // We can read/write each clock rate.

always @(posedge i_clk)
  o_wb_data <= ram[i_addr];

always @(posedge i_clk)
if (i_reset)
  o_wb_ack <= 1'b0;
else
  o_wb_ack <= ((i_wb_stb)&&(!o_wb_stall));

always @(posedge i_clk)
if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall))
begin
  ram[i_addr] <= i_data;
end

endmodule
