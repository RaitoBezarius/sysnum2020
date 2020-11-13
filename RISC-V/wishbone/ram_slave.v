`default_nettype none

module wb_ram_child(i_clk,
  i_wb_cyc, i_wb_stb, i_wb_we, i_wb_data, i_wb_addr,
  o_wb_ack, o_wb_stall, o_wb_data);

  parameter MEM_SIZE = 4095;

  input i_clk;
  input i_wb_cyc, i_wb_stb, i_wb_we;
  input [31:0] i_wb_data, i_wb_addr;

  output wire o_wb_ack;
  output wire o_wb_stall;
  output reg [31:0] o_wb_data;

  reg [31:0] memory [MEM_SIZE:0]; // Big memory.

  always @(posedge i_clk)
    if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall))
    begin
      memory[i_wb_addr] <= i_wb_data;
    end

  always @(posedge i_clk)
    o_wb_data <= memory[i_wb_addr];

  assign o_wb_ack = i_wb_stb;
  assign o_wb_stall = 1'b0;

endmodule
