
`default_nettype none

module riscv(
	clk,

	ram_read_addr,
	ram_write_addr,
	ram_write_enable,
	ram_data_out,
	ram_data_in,

	rom_addr,
	rom_in,
);

input clk;

output [31:0] ram_read_addr;
output [31:0] ram_write_addr;
output        ram_write_enable;
output [31:0] ram_data_out;
input  [31:0] ram_data_in;

output [31:0] rom_addr;
input  [31:0] rom_in;

assign ram_data_out = rom_in;

// Registers
reg [31:0] registers [4:0];

integer i;
initial begin
	for(i=0; i < 32; i=i+1)
		registers[i] = 0;
end

// ID-Forwarding interface
reg [31:0] op_1;
reg [31:0] op_2;
reg [ 4:0] fwd_rs1;
reg [ 4:0] fwd_rs2;

// EXE-Forwarding interface
wire [31:0] exe_op_1;
wire [31:0] exe_op_2;

// MEM-Forwarding interface
wire mem_triggers_write;
wire [31:0] mem_fwd;
// mem_rd is also read

// WB-Forwarding interface;
wire wb_triggers_write;
wire [31:0] wb_fwd;
// wb_rd is also read

// Forwarding
assign exe_op_1 =
	(mem_triggers_write && mem_rd == fwd_rs1) ? mem_fwd :
	( wb_triggers_write &&  wb_rd == fwd_rs1) ? wb_fwd  :
	op_1;

assign exe_op_2 =
	(mem_triggers_write && mem_rd == fwd_rs2) ? mem_fwd :
	( wb_triggers_write &&  wb_rd == fwd_rs2) ? wb_fwd  :
	op_2;

// Stalling signal
wire kill; // Written by the WB block.

// IF-ID interface
reg  [31:0] instruction;
reg  [ 0:0] id_op_request = ID_NOP;
wire [ 0:0] id_op;
reg  [31:0] id_pc;

parameter ID_DECODE = 1'b0;
parameter ID_NOP    = 1'b1;

assign id_op = kill ? ID_NOP : id_op_request;

// ID-EXE interface
reg  [ 4:0] exe_op_request = EXE_NOP;
wire [ 4:0] exe_op;
reg  [ 4:0] exe_rd;
reg  [31:0] exe_pc;
reg  [11:0] exe_offset;

parameter EXE_ADD   = 5'b00000;
parameter EXE_SUB   = 5'b00001;
parameter EXE_SLT   = 5'b00010;
parameter EXE_SLTU  = 5'b00011;
parameter EXE_AND   = 5'b00100;
parameter EXE_OR    = 5'b00101;
parameter EXE_XOR   = 5'b00110;
parameter EXE_SLL   = 5'b00111;
parameter EXE_SRL   = 5'b01000;
parameter EXE_SRA   = 5'b01001;

parameter EXE_LUI   = 5'b01010;

parameter EXE_JUMP  = 5'b01011;
parameter EXE_BEQ   = 5'b01100;
parameter EXE_BNE   = 5'b01101;
parameter EXE_BLT   = 5'b01110;
parameter EXE_BLTU  = 5'b01111;

parameter EXE_LOAD  = 5'b10000;
parameter EXE_STORE = 5'b10001;

parameter EXE_NOP   = 5'b10010;
parameter EXE_ERR   = 5'b10001;

assign exe_op = kill ? EXE_NOP : exe_op_request;

// EXE-MEM interface
reg  [ 2:0] mem_op_request = MEM_NOP;
wire [ 2:0] mem_op;
reg  [31:0] mem_target;
parameter MEM_FORWARD = 3'b000;
parameter MEM_JUMP    = 3'b001;
parameter MEM_LOAD    = 3'b010;
parameter MEM_STORE   = 3'b011;
parameter MEM_NOP     = 3'b100;
parameter MEM_ERR     = 3'b101; // May cause a TRAP,
                                // therefore a jump ?

assign mem_op = kill ? MEM_NOP : mem_op_request;

// MEM-WB interface

// The WB block will eventually have to handle writes,
// jumps, NOPs and errors.
reg [ 1:0] wb_op = WB_NOP;
reg [ 4:0] wb_rd;
reg [31:0] wb_res;

parameter WB_WRITE = 2'b00;
parameter WB_JUMP  = 2'b01;
parameter WB_NOP   = 2'b10;
parameter WB_ERR   = 2'b11;

// IF block
reg [31:0] pc = 0;

assign rom_addr = pc;

always @(posedge clk) begin
	instruction <= rom_in;
	id_op_request <= ID_DECODE;
end

// ID block
// Outputs: exe_op, exe_rd, op_1, op_2
parameter OP_IMM = 7'b00100;
parameter LUI    = 7'b01101;
parameter AUIPC  = 7'b00101;
parameter OP     = 7'b01100;
parameter JAL    = 7'b11011;
parameter JALR   = 7'b11001;
parameter BRANCH = 7'b11000;
parameter LOAD   = 7'b00000;
parameter STORE  = 7'b01000;

reg [2:0] op_type;
parameter TYPE_R = 3'b000;
parameter TYPE_I = 3'b001;
parameter TYPE_S = 3'b010;
parameter TYPE_B = 3'b011;
parameter TYPE_U = 3'b100;
parameter TYPE_J = 3'b101;

wire [4:0] rd;
wire [4:0] rs1;
wire [4:0] rs2;
wire [2:0] func3;
wire [2:0] func7;

// Used by integer arithmetic operations.
wire [4:0] alu_op;

assign rs1   = instruction[19:15];
assign rs2   = instruction[24:20];
assign rd    = instruction[11:7 ];
assign func3 = instruction[14:12];
assign func7 = instruction[31:25];

wire [1:0] branch_inst;
wire reverse_operands;

assign alu_op =
	(func3 == 3'b000) ? EXE_ADD :
	(func3 == 3'b010) ? EXE_SLT :
	(func3 == 3'b011) ? EXE_SLTU :
	(func3 == 3'b100) ? EXE_XOR :
	(func3 == 3'b110) ? EXE_OR :
	(func3 == 3'b111) ? EXE_AND :
	(func3 == 3'b001) ? EXE_SLL :
	(func3 == 3'b101) ? (
		(func7 == 7'b0000000) ? EXE_SRL :
		(func7 == 7'b0100000) ? EXE_SRA :
		EXE_ERR
	) :
	EXE_ERR;

assign branch_inst =
	(func3 == 3'b000) ? EXE_BEQ :
	(func3 == 3'b001) ? EXE_BNE :
	(func3 == 3'b100) ? EXE_BLT :
	(func3 == 3'b101) ? EXE_BLT :
	(func3 == 3'b110) ? EXE_BLTU :
	(func3 == 3'b111) ? EXE_BLTU :
	EXE_ERR;

assign reverse_operands = ((func3 == 3'b101) || (func3 == 3'b111));

always @(posedge clk) begin
	case(id_op)
		ID_DECODE: begin
			exe_rd <= rd;
			exe_pc <= id_pc;

			if(instruction[1:0] == 2'b11) begin
				case(instruction[6:2])
					OP_IMM: begin
						if(
							alu_op == EXE_ADD &&
							rd == 0 && rs1 == 0 &&
							instruction[31:20] == 0
						) begin
							exe_op_request <= EXE_NOP;
						end else begin
							op_type = TYPE_I;
							exe_op_request <= alu_op;
						end
					end
					LUI: begin
						op_type = TYPE_U;
						exe_op_request <= EXE_LUI;
					end
					AUIPC: begin
						op_type = TYPE_U;
						exe_op_request <= EXE_ADD;

						op_2 <= id_pc;
					end
					OP: begin
						op_type = TYPE_R;
						exe_op_request <= alu_op;
					end
					JAL: begin
						op_type = TYPE_J;
						exe_op_request <= EXE_JUMP;
					end
					JALR: begin
						if(func3 == 0) begin
							op_type = TYPE_I;
							exe_op_request <= EXE_JUMP;
						end else begin
							$display("Error");
						end
					end
					BRANCH: begin
						exe_op_request <= branch_inst;
					end
					LOAD: begin
						op_type = TYPE_I;
						exe_op_request <= EXE_LOAD;
					end
					STORE: begin
						op_type = TYPE_S;
						exe_op_request <= EXE_STORE;
					end
					default: $display("Unhandled");
				endcase
			end

			case(op_type)
				TYPE_R: begin
					op_1 <= registers[rs1];
					op_2 <= registers[rs2];
					fwd_rs1 <= rs1;
					fwd_rs2 <= rs2;
				end
				TYPE_I: begin
					op_1 <= registers[rs1];
					op_2 <= {
						{21{instruction[31]}},
						instruction[30:20]
					};
					fwd_rs1 <= rs1;
					fwd_rs2 <= 0;
				end
				TYPE_S: begin
					op_1 <= registers[rs1];
					op_2 <= registers[rs2];
					fwd_rs1 <= rs1;
					fwd_rs2 <= rs2;
					exe_offset <= {
						{21{instruction[31]}},
						instruction[30:25],
						instruction[11:8],
						instruction[7]
					};
				end
				TYPE_B: begin
					if(reverse_operands) begin
						op_1 <= registers[rs2];
						op_2 <= registers[rs1];
						fwd_rs1 <= rs2;
						fwd_rs2 <= rs1;
					end else begin
						op_1 <= registers[rs1];
						op_2 <= registers[rs2];
						fwd_rs1 <= rs1;
						fwd_rs2 <= rs2;
					end

					// exe_pc is already set.
					exe_offset <= {
						{20{instruction[31]}},
						instruction[7],
						instruction[30:25],
						instruction[11:8],
						1'b0
					};
				end
				TYPE_U: begin
					op_1 <= {instruction[31:12], 12'b0};
					// If op_2 is needed, it has already been set.
					fwd_rs1 <= rs1;
					fwd_rs2 <= rs2;
				end
				TYPE_J: begin
					op_1 <= id_pc;
					op_2 <= {{
						12{instruction[31]}},
						instruction[19:12],
						instruction[20],
						instruction[30:21],
						1'b0
					};
					fwd_rs1 <= 0;
					fwd_rs2 <= 0;
				end
				default: $display("Unhandled");
			endcase
		end
		ID_NOP: begin
			exe_op_request <= EXE_NOP;
		end
	endcase
end

// EXE block
// Inputs: exe_op, exe_rd, exe_op_1, exe_op_2
// Outputs: mem_rd, res
reg [ 4:0] mem_rd;
reg [31:0] res;

wire [31:0] exe_res;
wire [4:0 ] shift_amount;
wire [31:0] exe_jmp_target;
wire        cond_pass;

assign shift_amount = exe_op_2[4:0];

assign exe_res =
	exe_op == EXE_ADD  ? (exe_op_1 + exe_op_2) :
	exe_op == EXE_SUB  ? (exe_op_1 - exe_op_2) :
	exe_op == EXE_SLT  ? ($signed(exe_op_1) < $signed(exe_op_2)) :
	exe_op == EXE_SLTU ? (exe_op_1 < exe_op_2) :
	exe_op == EXE_AND  ? (exe_op_1 & exe_op_2) :
	exe_op == EXE_OR   ? (exe_op_1 | exe_op_2) :
	exe_op == EXE_XOR  ? (exe_op_1 ^ exe_op_2) :
	exe_op == EXE_SLL  ? (exe_op_1 << shift_amount) :
	exe_op == EXE_SRL  ? (exe_op_1 >> shift_amount) :
	exe_op == EXE_SRA  ? (exe_op_1 >>> shift_amount) :
	// Special case when jumping : we still want the sum.
	exe_op == EXE_JUMP ? (exe_op_1 + exe_op_2) :
	0;

assign cond_pass =
	exe_op == EXE_BEQ  ? (exe_op_1 == exe_op_2) :
	exe_op == EXE_BNE  ? (exe_op_1 != exe_op_2) :
	exe_op == EXE_BLT  ? ($signed(exe_op_1) < $signed(exe_op_2)) :
	exe_op == EXE_BLTU ? (exe_op_1 < exe_op_2) :
	0;

always @(posedge clk) begin
	mem_rd <= exe_rd;

	case(exe_op)
		EXE_JUMP: begin
			mem_op_request <= MEM_JUMP;
			mem_target <= exe_res;
		end
		EXE_BEQ, EXE_BNE, EXE_BLT, EXE_BLTU: begin
			if(cond_pass) begin
				mem_op_request <= MEM_JUMP;
				mem_target <= exe_pc + exe_offset;
			end else begin
				mem_op_request <= MEM_NOP;
			end
		end

		EXE_LUI: begin
			mem_op_request <= MEM_FORWARD;
			res <= exe_op_1;
		end

		EXE_LOAD: begin
			mem_op_request <= MEM_LOAD;
			mem_target <= exe_op_1 + exe_offset;
		end
		EXE_STORE: begin
			mem_op_request <= MEM_STORE;
			mem_target <= exe_op_1 + exe_offset;
			res <= exe_op_2;
		end

		EXE_NOP: mem_op_request <= MEM_NOP;
		EXE_ERR: mem_op_request <= MEM_ERR;

		default: begin
			mem_op_request <= MEM_FORWARD;
			res <= exe_res;
		end
	endcase
end

// MEM block
// Just forwards data for now.
assign mem_triggers_write = (mem_op == MEM_FORWARD);
assign mem_fwd = res;

assign ram_write_enable = (mem_op == MEM_STORE);
assign ram_data_out     = res;

always @(posedge clk) begin
	wb_rd  <= mem_rd;
	
	case(mem_op)
		MEM_FORWARD: begin
			wb_op <= WB_WRITE;
			wb_res <= res;
		end
		MEM_JUMP   : begin
			wb_op <= WB_JUMP;
			wb_res <= mem_target;
		end
		MEM_LOAD   : begin
			wb_op <= WB_WRITE;
			wb_res <= ram_data_in;
		end
		MEM_STORE  : begin
			wb_op <= WB_NOP;
		end
		MEM_NOP    : wb_op <= WB_NOP;
		MEM_ERR    : wb_op <= WB_ERR;
	endcase
end

// WB block
assign wb_triggers_write = (wb_op == WB_WRITE);
assign wb_fwd = wb_res;
wire [31:0] next_pc;

assign kill = (wb_op == WB_JUMP || wb_op == WB_ERR);
assign next_pc = (wb_op == WB_JUMP) ? wb_res : pc + 4;

always @(posedge clk) begin
	pc <= next_pc;
	id_pc <= next_pc;

	if(wb_op == WB_JUMP) begin
		$display("%d: jump to %d", $time, next_pc);
	end

	case(wb_op)
		WB_WRITE: begin
			registers[wb_rd] <= wb_res;
			$display("%d: r%d <- %d", $time, wb_rd, wb_res);
		end
		WB_NOP  : begin end // Nothing to do.
		WB_ERR  : begin
			// TODO: How to handle this properly ?
			$display("%d: ERROR", $time);
		end
	endcase
end

endmodule

