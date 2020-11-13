module core(i_clk, i_reset, i_interrupt,
  i_halt,
  o_wb_gbl_cyc, o_wb_gbl_stb,
  o_wb_lcl_cyc, o_wb_lcl_stb,
  o_wb_we, o_wb_addr, o_wb_data, o_wb_sel,
  i_wb_stall, i_wb_ack, i_wb_data,
  i_wb_err)
  // XLEN-bits.
  parameter XLEN = 32;

  // Options: ISA.
  `ifdef M_SUPPORT
    parameter [0:0] M_SUPPORT = 1;
  `else
    parameter [0:0] M_SUPPORT = 0;
  `endif

  // The NULL register.
  parameter X0 = 5'b0;

  //Opcodes uniques
  parameter LUI =     7'b0110111;
  parameter AUIPC =   7'b0010111;
  parameter JAL =     7'b1101111;
  parameter JALR =    7'b1100111;

  //Opcodes partagés
  parameter OP =      7'b0110011;
  parameter BRANCH =  7'b1100011;
  parameter LOAD =    7'b0000011;
  parameter STORE =   7'b0100011;
  parameter IMM =     7'b0010011;

  //Opcodes spéciaux, partagés
  parameter MISCMEM = 7'b0001111;
  parameter SYSTEM =  7'b1110011;

  //Codes funct3 OP
  parameter ADD =   3'b000;
  parameter SLL =   3'b001;
  parameter SLT =   3'b010;
  parameter SLTU =  3'b011;
  parameter XOR =   3'b100;
  parameter SRL =   3'b101;
  parameter OR =    3'b110;
  parameter AND =   3'b111;

  //Codes imm OP
  parameter VANILLA = 7'b0;
  parameter SUBSRA =  7'b0100000;
  parameter MULT =    7'b0000001;


  parameter NULL =    32'b0;

  // Some I/O
  input wire i_clk, i_reset, i_interrupt;
  // Debugging
  input wire i_halt;

  // Wishbone interface
  output wire o_wb_gbl_cyc, o_wb_gbl_stb;
  output wire o_wb_lcl_cyc, o_wb_lcl_stb, o_wb_we;
  output wire [31:0] o_wb_addr; // Address.
  output wire [31:0] o_wb_data; // Actual data.
  output wire [3:0] o_wb_sel; // Selector.
  input wire i_wb_stall, i_wb_ack; // Protocol-related Wishbone stuff: stalling & acknowledgement.
  input wire [31:0] i_wb_data;
  input wire i_wb_err;

  // Pipeline stage #2: Instruction decoding.

  reg op_valid, op_valid_mem, op_valid_alu;
  reg op_valid_div;

  reg op_stall, dcd_ce, dcd_phase; // dcd = decoding.

  wire [6:0] dcd_opn; // opcode.
  wire dcd_valid;
  wire [31:0] dcd_pc;

  wire dcd_lui, dcd_auipc, dcd_jal, dcd_jalr,
    dcd_alu, dcd_system, dcd_fence, dcd_load,
    dcd_store;

  // Pipeline stage #3: Data fetching: memory and registers.
  wire [4:0] d_rs1, d_rs2, d_rd;
  wire [2:0] d_funct3;
  wire [7:0] d_funct7;
  wire [6:0] d_immS;
  wire [11:0] d_immI;
  wire [20:0] d_immU;

  reg [31:0] d_regs [32:0]; // FIXME(Ryan): is it really fine to put it here?

  wire mem_ce, mem_stalled;
  wire mem_valid, mem_stall, mem_ack, mem_err, bus_err,
    mem_cyc_gbl, mem_cyc_lcl, mem_stb_gbl, mem_stb_lcl, mem_we;
  wire [4:0] mem_wreg;
  wire mem_busy, mem_rdbusy;
  wire [31:0] mem_addr;
  wire [31:0] mem_data, mem_result;
  wire [3:0] mem_sel;

  // Pipeline stage #4: Execution.
  wire [31:0] alu_pc;
  reg r_alu_pc_valid, mem_pc_valid;
  wire alu_pc_valid;
  wire alu_phase;
  wire [31:0] alu_result;
  wire alu_valid, alu_busy;

  wire div_ce, div_error, div_busy, div_valid;
  wire [31:0] div_result;

  wire bus_lock;
  
  // Pipeline stage #5: Write-back phase.
  wire wr_discard, wr_write_pc;
  reg wr_reg_ce;
  reg [2:0] wr_index;
  wire [4:0] wr_reg_id;
  wire [31:0] wr_gpreg_vl, wr_spreg_vl;
  wire w_switch_to_interrupt, w_release_from_interrupt;

  // Master: Clock enable.
  assign master_ce = ((!i_halt)||(alu_phase));

  // Compute stalled conditions.
  always @(*)
    dcd_stalled = (!master_ce)||(dcd_valid)||(op_valid)
                  ||(alu_busy)||(div_busy)||(mem_busy);
  end

  assign op_stall = 1'b0;
  assign op_ce = (dcd_valid)&&(!op_stall);

  assign alu_stall = master_stall;
  assign alu_ce = op_valid_alu;

  assign mem_ce = (master_ce)&&(op_valid_mem)&&(!mem_stalled);

  assign master_stall = (!master_ce)||(!op_valid)
                        ||(pending_interrupt)
                        ||(!alu_phase)
                        ||(alu_busy)||(div_busy);

  assign dcd_ce = !dcd_stalled;

  idecode #(.M_SUPPORT(M_SUPPORT))
    instruction_decoder(i_clk, …);


  initial op_valid = 1'b0;
  initial op_valid_alu = 1'b0;
  initial op_valid_mem = 1'b0;
  initial op_valid_div = 1'b0;

  always @(posedge i_clk)
  if (i_reset)
  begin
    op_valid <= 1'b0;
    op_valid_alu <= 1'b0;
    op_valid_mem <= 1'b0;
    op_valid_div <= 1'b0;
  end else if (op_ce)
  begin
    // First, we determine if we have a valid instruction.
    if (!op_valid)
    begin
      op_valid <= w_op_valid;
      op_valid_alu <= (w_op_valid)&&((dcd_alu)||(dcd_illegal));
      op_valid_mem <= (dcd_load||dcd_store)&&(!dcd_illegal)&&(w_op_valid);
      op_valid_div <= (M_SUPPORT)&&(dcd_alu)&&(!dcd_illegal)&&(w_op_valid);
    end else if (mem_ce)
    begin
      op_valid <= 1'b0;
      op_valid_alu <= 1'b0;
      op_valid_mem <= 1'b0;
      op_valid_div <= 1'b0;
    end
  end else if (mem_ce)
    op_valid <= 1'b0;
    op_valid_alu <= 1'b0;
    op_valid_mem <= 1'b0;
    op_valid_div <= 1'b0;
  end

  initial op_illegal = 1'b0;
  always @(posedge i_clk)
  if (i_reset)
    op_illegal <= 1'b0;
  else
  begin
    if (dcd_valid)
      op_illegal <= cd_illegal;
  end

  // Pipeline stage #4: Execution.
  // The only ^, able to compute everything.
  // FIXME(Ryan): add division here.
  alu #(M_SUPPORT) circonflex(i_clk, i_reset,
    alu_ce, dcd_opn, d_rs1, d_rs2,
    alu_result, alu_valid, alu_busy);

  initial wr_index = 0;
  always @(posedge i_clk)
  begin
    if (op_valid)
    begin
      wr_index <= 0;
      wr_index[0] <= (op_valid_mem | op_valid_div);
      wr_index[1] <= (op_valid_alu | op_valid_div);
    end
  end

  assign alu_pc = op_pc;
  assign alu_illegal = op_illegal;

  always @(posedge i_clk)
    if (i_reset)
      mem_pc_valid <= 1'b0;
    else
      mem_pc_valid <= mem_ce;

  // The only \, able to remember everything.
  memops backslash(i_clk, i_reset,
    mem_ce, d_rs1, d_rs2, d_rd,
    mem_busy,
    mem_valid, bus_err, mem_wreg, mem_result,
    mem_cyc_gbl, mem_cyc_lcl,
    mem_stb_gbl, mem_stb_lcl,
    mem_we, mem_addr, mem_data, mem_sel,
    mem_stall, mem_ack, mem_err, i_wb_data);

  assign mem_rdbusy = (mem_busy)&&(!mem_we); // Read business.
  // Pipeline #5: write-back.
  // No matter what, this shall be performed.

  assign wr_discard = alu_illegal;
  // Determine when we shall write back.
  always @(*)
    case (wr_index)
      3'b01: wr_reg_ce = mem_valid;
      3'b11: wr_reg_ce = (!wr_discard)&&(div_valid)&&(!div_error);
      default: wr_reg_ce = (!wr_discard)&&(alu_valid);
    endcase

  // Determine what we shall write back.
  always @(*)
    case (wr_index)
      3'b01: wr_gpreg_vl = mem_result;
      3'b11: wr_gpreg_vl = div_result;
      default: wr_gpreg_vl = alu_result;
    endcase

  // Write it.
  always @(posedge i_clk)
    if (wr_reg_ce)
      registers[rd] <= wr_gpreg_vl;

end
