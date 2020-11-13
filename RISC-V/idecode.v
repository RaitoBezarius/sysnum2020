`default_nettype none

module idecode(i_clk, i_reset, i_ce, i_stalled,
  i_instruction, i_pc,
  i_illegal, o_valid,
  o_phase, o_illegal,
  o_pc,
  o_rs1, o_rs2, o_rd,
  o_funct3, o_funct7,
  o_lui, o_auipc, o_jal, o_jalr,
  o_alu, o_system, o_fence, o_load,
  o_store, o_branch)

  localparam M_SUPPORT = 1'b0;

  input wire i_clk, i_reset, i_ce, i_stalled;
  input wire [31:0] i_instruction;
  input wire [31:0] i_pc;

  output wire o_valid, o_phase;
  output reg o_illegal;
  output reg [31:0] o_pc;
  output reg [31:0] o_rs1, o_rs2, o_rd, o_funct3, o_funct7;
  output reg o_lui, o_auipc, o_jal,
    o_jalr, o_alu, o_system, o_fence, o_load,
    o_store, o_branch;

  // Decode properly the opcode.
  // Then proceed to decode smartly the immediates based
  // on the instruction format.
end


