`default_nettype none
`include "core/memory/block_ram.sv"

module hart
#(
  parameter XLEN = 32,
  parameter W = XLEN
)
(
	clk,
  o_wb_we,
  o_wb_sel,
  o_wb_stb,
  i_data,
  i_data_ack,
  i_data_stall,
  o_data,
  o_data_addr,
	rom_addr,
	rom_in,
  fw_rom_addr,
  fw_rom_in
);

input clk;

output [W-1:0] o_data_addr;
output o_wb_we, o_wb_stb;
output [3:0] o_wb_sel;
output [W-1:0] o_data;
input  [W-1:0] i_data;
input i_data_stall, i_data_ack;

output [W-1:0] rom_addr;
input  [W-1:0] rom_in;

output [W-1:0] fw_rom_addr;
input  [W-1:0] fw_rom_in;

// Registers
reg [W-1:0] registers [1:0][31:0];

integer i;
integer k;
initial begin
    for(k = 0; k < 2; k=k+1) begin
        for(i=0; i < 32; i=i+1)
            registers[k][i] = 0;
    end
end

// Dual mode extra registers
reg [W-1:0] extra_regs [255:0];

integer t;
initial begin
    for(t = 0; t < 256; t=t+1)
        extra_regs[t] = 0;
end

// Processor modes
parameter NORMAL_MODE = 1'b0;
parameter DUAL_MODE   = 1'b1;

// Timers
reg [63:0] mtime;
reg [63:0] mtimecmp;

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

// Signals
wire mem_stall; // Written by MEM block.
wire kill; // Written by the WB block.

// IF interface
reg  [ 0:0] if_mode = NORMAL_MODE;
wire [ 0:0] if_op = kill ? IF_NOP : IF_FETCH;
reg  [31:0] if_pc_request;
reg  [ 0:0] if_prediction_failed;

parameter IF_FETCH = 1'b0;
parameter IF_NOP   = 1'b1;

// IF-ID interface
reg  [ 0:0] id_mode = NORMAL_MODE;
reg  [31:0] instruction;
reg  [ 0:0] id_op_request = ID_NOP;
wire [ 0:0] id_op;
reg  [31:0] id_pc;

parameter ID_DECODE = 1'b0;
parameter ID_NOP    = 1'b1;

assign id_op = kill ? ID_NOP : id_op_request;

// ID-EXE interface
reg  [ 0:0] exe_mode = NORMAL_MODE;
reg  [ 4:0] exe_op_request = EXE_NOP;
wire [ 4:0] exe_op;
reg  [ 4:0] exe_rd;
reg  [31:0] exe_pc;
reg  [31:0] exe_inst;
reg  [31:0] exe_offset;
reg  [ 2:0] exe_mem_data_ty;

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

parameter EXE_TRAP  = 5'b10010;

parameter EXE_NOP   = 5'b10011;
parameter EXE_ERR   = 5'b10011;

parameter DATA_B  = 3'b000; // Byte.
parameter DATA_H  = 3'b001; // Half word: Sign-extends.
parameter DATA_W  = 3'b010; // Word: Sign-extends.
parameter DATA_BU = 3'b100; // Byte: Zero-extends.
parameter DATA_HU = 3'b101; // Half word: Zero-extends.

assign exe_op = kill ? EXE_NOP : exe_op_request;

// EXE-MEM interface
reg  [ 0:0] mem_mode = NORMAL_MODE;
reg  [ 2:0] mem_op_request = MEM_NOP;
wire [ 2:0] mem_op;
reg  [31:0] mem_target;
reg  [31:0] mem_pc;
reg  [31:0] mem_inst;
reg  [ 2:0] mem_data_ty;

parameter MEM_FORWARD = 3'b000;
parameter MEM_JUMP    = 3'b001;
parameter MEM_LOAD    = 3'b010;
parameter MEM_STORE   = 3'b011;
parameter MEM_TRAP    = 3'b100;
parameter MEM_NOP     = 3'b101;
parameter MEM_ERR     = 3'b110;

assign mem_op = kill ? MEM_NOP : mem_op_request;

// MEM-WB interface
reg [ 0:0] wb_mode = NORMAL_MODE;
reg [ 2:0] wb_op = WB_NOP;
reg [ 4:0] wb_rd;
reg [31:0] wb_res;
reg [31:0] wb_pc;
reg [31:0] wb_inst;
reg [31:0] wb_trap_tgt_addr;

parameter WB_WRITE = 3'b000;
parameter WB_JUMP  = 3'b001;
parameter WB_TRAP  = 3'b010;
parameter WB_NOP   = 3'b011;
parameter WB_ERR   = 3'b110;

// IF block
reg  [31:0] pc = 0;
wire [31:0] if_new_pc;

assign if_new_pc = if_prediction_failed ? if_pc_request : pc + 4;
assign rom_addr = if_new_pc;
assign fw_rom_addr = if_new_pc;

always @(posedge clk) begin
    if(!mem_stall) begin
        case(if_op)
            IF_FETCH: begin
                id_mode <= if_mode;
                instruction <= if_mode == DUAL_MODE ? fw_rom_in : rom_in;
                id_op_request <= ID_DECODE;
                id_pc <= if_new_pc;
                pc <= if_new_pc;
            end
            IF_NOP: begin
                id_op_request <= ID_NOP; 
            end
        endcase
    end
end

// ID block
// Outputs: exe_op, exe_rd, op_1, op_2
parameter OP_IMM = 5'b00100;
parameter LUI    = 5'b01101;
parameter AUIPC  = 5'b00101;
parameter OP     = 5'b01100;
parameter JAL    = 5'b11011;
parameter JALR   = 5'b11001;
parameter BRANCH = 5'b11000;
parameter LOAD   = 5'b00000;
parameter STORE  = 5'b01000;
parameter SYSTEM = 5'b11100;

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
wire [6:0] func7;

wire [31:0] rs1_val;
wire [31:0] rs2_val;

// Used by integer arithmetic operations.
wire [4:0] alu_op;

assign rs1   = instruction[19:15];
assign rs2   = instruction[24:20];
assign rd    = instruction[11:7 ];
assign func3 = instruction[14:12];
assign func7 = instruction[31:25];

wire [4:0] branch_inst;
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

// go-go-gadgeto-forwarding
assign rs1_val = (wb_rd == rs1 && wb_triggers_write) ? wb_res : registers[if_mode][rs1];
assign rs2_val = (wb_rd == rs2 && wb_triggers_write) ? wb_res : registers[if_mode][rs2];

always @(posedge clk) begin
    if(!mem_stall) begin
        case(id_op)
            ID_DECODE: begin
                exe_mode        <= id_mode;
                exe_rd          <= rd;
                exe_pc          <= id_pc;
                exe_inst        <= instruction;
                exe_mem_data_ty <= func3;

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
                        SYSTEM: begin
                            exe_op_request <= EXE_TRAP;
                        end
                        default: exe_op_request <= EXE_ERR;
                    endcase
                end else begin
                    exe_op_request <= EXE_ERR;
                end

                case(op_type)
                    TYPE_R: begin
                        op_1 <= rs1_val;
                        op_2 <= rs2_val;
                        fwd_rs1 <= rs1;
                        fwd_rs2 <= rs2;
                    end
                    TYPE_I: begin
                        op_1 <= registers[id_mode][rs1];
                        op_2 <= {
                            {21{instruction[31]}},
                            instruction[30:20]
                        };
                        fwd_rs1 <= rs1;
                        fwd_rs2 <= 0;
                    end
                    TYPE_S: begin
                        op_1 <= registers[id_mode][rs1];
                        op_2 <= registers[id_mode][rs2];
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
                            op_1 <= registers[id_mode][rs2];
                            op_2 <= registers[id_mode][rs1];
                            fwd_rs1 <= rs2;
                            fwd_rs2 <= rs1;
                        end else begin
                            op_1 <= registers[id_mode][rs1];
                            op_2 <= registers[id_mode][rs2];
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
                    // default: we don't need to decode anything.
                endcase
            end
            ID_NOP: begin
                exe_op_request <= EXE_NOP;
            end
        endcase
    end
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
	exe_op == EXE_SLT  ? ({31'b0, $signed(exe_op_1) < $signed(exe_op_2)}) :
	exe_op == EXE_SLTU ? ({31'b0, exe_op_1 < exe_op_2}) :
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
    if(!mem_stall) begin
        mem_rd      <= exe_rd;
        mem_data_ty <= exe_mem_data_ty;

        if(exe_op != EXE_NOP) begin
            mem_mode <= exe_mode;
            mem_pc   <= exe_pc;
            mem_inst <= exe_inst;
        end

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

            EXE_TRAP: begin
                mem_op_request <= MEM_TRAP;
            end

            EXE_NOP: mem_op_request <= MEM_NOP;
            EXE_ERR: mem_op_request <= MEM_ERR;

            default: begin
                mem_op_request <= MEM_FORWARD;
                res <= exe_res;
            end
        endcase
    end
end

// MEM block
reg [1:0] mem_state;
parameter STATE_NORMAL  = 1'b0;
parameter STATE_WAITING = 1'b1;

assign mem_triggers_write = (mem_op == MEM_FORWARD || mem_op == MEM_LOAD);
assign mem_fwd = mem_op == MEM_FORWARD ? res :
    mem_mode == NORMAL_MODE ? i_data :
    dual_data;

assign o_wb_sel = (mem_data_ty == DATA_B) ? 4'b0001 :
  ((mem_data_ty == DATA_H) ? 4'b0011 :
  ((mem_data_ty == DATA_BU) ? 4'b0001 :
  ((mem_data_ty == DATA_HU) ? 4'b0011 :
  4'b1111)));
assign o_data_addr = mem_target;
assign o_wb_we = (mem_mode == NORMAL_MODE && mem_op == MEM_STORE);
assign o_wb_stb = (mem_mode == NORMAL_MODE && (mem_op == MEM_STORE || mem_op == MEM_LOAD)); // Initiate an operation
assign o_data = (mem_mode == NORMAL_MODE) ? 
  ((mem_data_ty == DATA_B) ? 32'(signed'(res[7:0])) :
  ((mem_data_ty == DATA_H) ? 32'(signed'(res[15:0])) :
  ((mem_data_ty == DATA_BU) ? {24'b0, res[7:0]} :
  ((mem_data_ty == DATA_HU) ? {16'b0, res[15:0]} :
  res)))) : 32'b0; // Garbage as, in dual mode, we are not doing RAM tx.


wire [31:0] dual_data;
assign dual_data = mem_target[8] == 0 ?
        (/*mem_target[5] == 0 ?
            (mem_target[0] ? mtime : mtimecmp) :*/
            registers[NORMAL_MODE][mem_target[4:0]]
        ) : extra_regs[mem_target[7:0]];

// end

always @(posedge clk) begin
    case(mem_state)
        STATE_NORMAL: begin
            wb_rd  <= mem_rd;
            if(mem_op != MEM_NOP) begin
                wb_mode <= mem_mode;
                wb_pc   <= mem_pc;
                wb_inst <= mem_inst;
                wb_trap_tgt_addr <= res;
            end

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
                    if(mem_mode == NORMAL_MODE) begin
                        wb_op <= WB_NOP;
                        mem_state <= STATE_WAITING;
                    end else begin // Dual mode
                        wb_op <= WB_WRITE;
                        wb_res <= dual_data;
                    end
                end
                MEM_STORE  : begin
                    wb_op <= WB_NOP;
                    
                    if(mem_mode == DUAL_MODE) begin
                        // We store directly 32-bit words
                        if(mem_target[8] == 0) begin
                            /*if(mem_target[5] == 0) begin
                                if(mem_target[0] == 0) begin
                                  
                                end else begin

                                end
                            end else begin*/
                            registers[NORMAL_MODE][mem_target[4:0]] <= res;
                            //end
                        end else begin
                            extra_regs[mem_target[7:0]] <= res;
                        end
                    end
                end
                MEM_TRAP   : begin
                    wb_op <= WB_TRAP;
                    wb_res <= mem_inst;
                end
                MEM_NOP    : wb_op <= WB_NOP;
                MEM_ERR    : wb_op <= WB_ERR;
            endcase
        end
        STATE_WAITING: begin
            if(i_data_ack) begin
                wb_op <= WB_WRITE;
                wb_res <= i_data;
                mem_state <= STATE_NORMAL;
            end
        end
    endcase
end

// WB block
assign wb_triggers_write = (wb_op == WB_WRITE);
assign wb_fwd = wb_res;
wire [W-1:0] next_pc;

assign kill = (wb_op == WB_JUMP || wb_op == WB_TRAP || wb_op == WB_ERR);
assign next_pc =
    (wb_op == WB_JUMP) ? wb_res :
    (wb_op == WB_TRAP) ? 4 :
    (wb_op == WB_ERR ) ? 0 :
    pc + 4;

always @(posedge clk) begin
    if_prediction_failed <= kill;

    if(id_mode == NORMAL_MODE) begin
        if(wb_op == WB_TRAP || wb_op == WB_ERR) begin
            if_mode <= DUAL_MODE;
        end
        if_pc_request <= next_pc;
      end else begin
        if(wb_op == WB_TRAP) begin
            // In this case, a SYSTEM instruction was executed.
            // We go back to normal mode.
            if_mode <= NORMAL_MODE;
            if_pc_request <= registers[DUAL_MODE][1];
        end else begin
            if_pc_request <= next_pc;
        end
    end

    if(wb_op == WB_ERR) begin
        $display("!!");
    end

	if(wb_op == WB_JUMP) begin
		$display("%d: jump to %d", $time, next_pc);
	end

	case(wb_op)
		WB_WRITE: begin
			registers[id_mode][wb_rd] <= wb_res;
			$display("%d: r%d <- %d", $time, wb_rd, wb_res);
		end
        WB_TRAP : begin
            // we already prepared pc and id_mode
            
            if(id_mode == NORMAL_MODE) begin
                registers[DUAL_MODE][1] <= next_pc;
                registers[DUAL_MODE][2] <= wb_res;
            end
        end
        WB_NOP  : begin end // Nothing to do.
		WB_ERR  : begin
			// TODO: How to handle this properly ?
			$display("%d: ERROR", $time);
            
            if(id_mode == NORMAL_MODE) begin
                registers[DUAL_MODE][1] <= next_pc;
            end
		end
	endcase
end

endmodule

