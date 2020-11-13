module core(INSTR_DATA, INSTR_ADDR, DATA_IN, DATA_OUT, DATA_ADDR, BYTE_ENABLE, WRITE_ENABLE, READ_ENABLE, clk);
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

  input [31:0] INSTR_DATA; // Instruction data bus.
  output [31:0] INSTR_ADDR; // Instruction addr bus.

  input [31:0] DATA_IN; // Data bus for input.
  output [31:0] DATA_OUT; // Data bus for output, e.g. RAM.
  output [31:0] DATA_ADDR; // Address bus (addressing)
  output [3:0]  BYTE_ENABLE; // Multibyte support (for lw/etc.)

  output WRITE_ENABLE;
  output READ_ENABLE;

  input clk;

  reg [31:0] pc = 32'b0;
  reg [31:0] XIDATA = 32'b0;
  reg [31:0] immediate = 32'b0;
  reg [31:0] registers [32:0];

  //Décomposition de l'XIDATA
  reg [4:0] rs1 = 5'b0;
  reg [4:0] rs2 = 5'b0;
  reg [4:0] rd  = 5'b0;

  reg [6:0] opcode = 7'b0;
  reg [2:0] funct3 = 3'b0;

  reg [6:0] immS = 7'b0;
  reg [11:0] immI = 12'b0;

  integer i;
  initial
    begin
      for(i=0;i<32;i=i+1)
        registers[i] = 32'b0;
    end

  always @(posedge clk)
    begin

      //Pre-process
      pc = INSTR_ADDR; // TODO(Ryan): weird, we should remove pc or INSTR_ADDR.
      XIDATA <= INSTR_DATA; // TODO: do better.

      //Instruction handling
      // FIXME(Ryan): S, I, U, B, J-types of instructions are made to be manually
      // optimized for decoding in the hardware.
      // Currently, we let Verilog determine a good way to perform this.
      // This is not wanted.
      // Section 2.3 of RISC-V specs explain how to perform such decoding
      // efficiently. It should be aimed to reproduce a very aggressively
      // optimized decoder.
      opcode   = XIDATA[6:0];
      funct3   = XIDATA[14:12];
      funct7   = XIDATA[31:25];
      rs1   =    XIDATA[19:15];
      rs2   =    XIDATA[24:20];
      rd   =     XIDATA[11:7];
      immS   =   XIDATA[31:25];
      immI   =   XIDATA[31:20];
      immU   =   XIDATA[31:12];

      case(opcode)
        LUI :
          begin
            registers[rd] <= {12'b0, immU};
          end
        AUIPC :
          begin
            registers[rd] <= pc + {12'b0, immU};
          end
        // TODO(Ryan): JAL, JALR do not handle misaligned target address.
        // We should check that target addr is aligned on a 4-byte boundary.
        // If not, the CPU should go into exception state or trap state, and
        // halt itself, if no one catch the trap state.
        JAL :
          begin
            pc = pc + {{19{immI[11]}}, {{{immI[11], {rs1, funct3}}, immI[10:0]}, 1'b0}} - 1;
            registers[rd] <= rd == X0 ? 0 : pc + 1;
          end
        JALR :
          begin
            pc = {registers[rs1] + $signed(immI), 1'b0} - 1;
            registers[rd] <= rd == X0 ? 0 : pc + 1;
          end
        IMM :
          begin
            case(funct3)
              ADD : registers[rd] <= registers[rs1] + {{20{immI[11]}}, immI};
              SLT : registers[rd] <= {31'b0, $signed(registers[rs1]) < $signed({{20{immI[11]}}, immI})};
              SLTU : registers[rd] <= {31'b0, registers[rs1] < {{20{immI[11]}}, immI}};
              XOR : registers[rd] <= registers[rs1] ^ {{20{immI[11]}}, immI};
              OR : registers[rd] <= registers[rs1] || {{20{immI[11]}}, immI};
              AND : registers[rd] <= registers[rs1] && {{20{immI[11]}}, immI};
            endcase
          end
        OP :
          begin
            case(immS)
              VANILLA :
                begin
                  case(funct3)
                    ADD : registers[rd] <= registers[rs1] + registers[rs2];
                    SLL : registers[rd] <= registers[rs1] << registers[rs2][4:0];
                    SRL : registers[rd] <= registers[rs1] >> registers[rs2][4:0];
                    SLT : registers[rd] <= {31'b0, $signed(registers[rs1]) < $signed(registers[rs2])};
                    SLTU : registers[rd] <= {31'b0, registers[rs1] < registers[rs2]};
                    XOR : registers[rd] <= (registers[rs1] ^ registers[rs2]);
                    OR : registers[rd] <= (registers[rs1] || registers[rs2]);
                    AND : registers[rd] <= (registers[rs1] && registers[rs2]);
                  endcase
                end
              SUBSRA :
                begin
                  case(funct3)
                    ADD : registers[rd] <= registers[rs1] - registers[rs2];
                    SRL : registers[rd] <= (registers[rs1] >>> registers[rs2][4:0]);
                  endcase
                end
              MULT :
                begin
                  case(funct3)
                    ADD : registers[rd] <= ($signed(registers[rs1]) * $signed(registers[rs2]));
                    SLL : registers[rd] <= ($signed(registers[rs1]) * $signed(registers[rs2])) >> 32;
                    SLT : registers[rd] <= ($signed(registers[rs1]) * registers[rs2]) >> 32;
                    SLTU : registers[rd] <= (registers[rs1] * registers[rs2]) >> 32;
                    XOR : registers[rd] <= ($signed(registers[rs1]) / $signed(registers[rs2]));
                    SRL : registers[rd] <= (registers[rs1] / registers[rs2]);
                    OR : registers[rd] <= ($signed(registers[rs1]) % $signed(registers[rs2]));
                    AND : registers[rd] <= (registers[rs1] % registers[rs2]);
                  endcase
                end
              endcase
          end
        BRANCH :
          begin
            case(funct3)
              ADD : if(registers[rs1] == registers[rs2])
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              SLL : begin
                      if(registers[rs1] != registers[rs2])
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
                    end
              XOR : if($signed(registers[rs1]) < $signed(registers[rs2]))
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              SRL : if($signed(registers[rs1]) >= $signed(registers[rs2]))
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              OR : if(registers[rs1] < registers[rs2])
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              AND : if(registers[rs1] >= registers[rs2])
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              endcase
          end
        LOAD :
          begin
            // Set the effective address.
            assign DATA_ADDR = registers[rs1] + $signed(immI);
            // Perform a read.
            assign READ_ENABLE = 1;
            pc = pc - 1;
            $display("Got LOAD for addr: %h", DATA_ADDR);
            // registers[rd] <= data_in_ram;
          end
        STORE :
          begin
            $display("Got STORE");
          end
        MISCMEM :
          begin
            $display("Got MISCMEM (FENCE)");
            // FIXME(Ryan): Basically, a nop for now. It makes no sense to
            // order operations until we have multiple cores or stuff like
            // this.
          end
        SYSTEM :
          begin
            $display("Got SYSTEM");
          end
        //default : $display("ERROR : ");
      endcase
      assign INSTR_ADDR = pc + 1;
      pc = pc + 1;
    end
endmodule
