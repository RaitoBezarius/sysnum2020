`default_nettype none

module block_ram
#(
  parameter XLEN = 32,
  parameter LGMEMSZ = 19,
  parameter W = XLEN,
  parameter AW = W, // Address width
  parameter DW = W // Data width
)
(
  i_clk, i_reset, i_wb_stb, i_addr, i_data,
  i_wb_we, i_wb_sel,
  o_wb_data, o_wb_stall, o_wb_ack
);

// Wishbone slave control
input wire i_clk, i_wb_stb, i_reset;

input wire [AW-1:0] i_addr;
input wire [DW-1:0] i_data;
input wire i_wb_we; // Write enable
input wire [(DW/8)-1:0] i_wb_sel; // Byte enable
output reg [DW-1:0] o_wb_data;

output wire o_wb_stall;
output reg o_wb_ack;

initial o_wb_ack = 1'b0;

// RAM block
reg [DW-1:0] ram [(1 << LGMEMSZ) - 1:0];

assign o_wb_stall = 1'b0; // We can read/write each clock rate.

always @(posedge i_clk)
  o_wb_data <= ram[i_addr];

always @(posedge i_clk)
if (i_reset)
  o_wb_ack <= 1'b0;
else
  o_wb_ack <= ((i_wb_stb)&&(!o_wb_stall));

always @(posedge i_clk)
begin
  if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall)&&(i_wb_sel[3]))
    ram[i_addr][31:24] <= i_data[31:24];

  if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall)&&(i_wb_sel[2]))
    ram[i_addr][23:16] <= i_data[23:16];

  if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall)&&(i_wb_sel[1]))
    ram[i_addr][15:8] <= i_data[15:8];

  if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall)&&(i_wb_sel[0]))
    ram[i_addr][7:0] <= i_data[7:0];
end

`ifdef FORMAL
  // We want to proceed to a thorough verification when verified in a larger
  // design, e.g. CPU.
  // We want those assume to be assert so that the CPU performs the right
  // operations.
  `ifdef ISOLATED
    `define ASSUME assume
  `else
    `define ASSUME assert
  `endif
  // Inspired from ZipCPU blog post on formal verification of memories.
  (* anyconst *) wire [AW-1:0] f_addr;
  reg f_past_valid;
  reg [DW-1:0] f_data;

  initial assume (f_data == ram[f_addr]);
  initial f_past_valid = 1'b0;

  always @(posedge i_clk)
    if ((f_past_valid)&&($past(i_wb_stb))&&($past(o_wb_stall)))
    begin
      `ASSUME(i_wb_stb);
      `ASSUME(i_wb_we == $past(i_wb_we));
      `ASSUME(i_addr == $past(i_addr));
      `ASSUME(i_data == $past(i_data));
      `ASSUME(i_wb_sel == $past(i_wb_sel));
    end

  always @(posedge i_clk)
    f_past_valid <= 1'b1;

  always @(*)
    assert(ram[f_addr] == f_data);

  // Verify if we had a wishbone tx, we were reading from our memory and at
  // the right address.
  always @(posedge i_clk)
  if ((f_past_valid) && ($past(i_wb_stb)) && (!$past(i_wb_we)) && ($past(i_addr == f_addr)))
    assert(o_wb_data == f_data);

  // Update the f_data.
  always @(posedge i_clk)
  if ((i_wb_stb) && (i_wb_we) && (i_addr == f_addr))
  begin
    if (i_wb_sel[3])
      f_data[31:24] <= i_data[31:24];
    if (i_wb_sel[2])
      f_data[23:16] <= i_data[23:16];
    if (i_wb_sel[1])
      f_data[15:8] <= i_data[15:8];
    if (i_wb_sel[0])
      f_data[7:0] <= i_data[7:0];
  end
`endif

endmodule
