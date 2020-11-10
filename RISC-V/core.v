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
      XIDATA <= INSTR_DATA; // TODO: do better.

      //Instruction handling
      opcode = XIDATA[6:0];
      funct3 = XIDATA[14:12];
      rs1 =    XIDATA[19:15];
      rs2 =    XIDATA[24:20];
      rd =     XIDATA[11:7];
      immS =   XIDATA[31:25];
      immI =   XIDATA[31:20];

      case(opcode)
        LUI :
          begin
            $display("Got LUI");
          end
        AUIPC :
          begin
            $display("Got AUIPC");
          end
        JAL :
          begin
            //$display("Got JAL");
            pc = pc + {{19{immI[11]}}, {{{immI[11], {rs1, funct3}}, immI[10:0]}, 1'b0}} - 1;
            registers[rd] <= pc + 1;
          end
        JALR :
          begin
            $display("Got JALR");
          end
        IMM :
          begin
            //$display("Got IMM");
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
            //$display("Got OP");
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
                  //$display("Got MULTDIV");
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
            //$display("Got Branch");
            case(funct3)
              ADD : if(registers[rs1] == registers[rs2])
                      begin
                        pc = pc + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              SLL : begin
                      if(registers[rs1] != registers[rs2])
                      begin
                        //$display("Went backwards");
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
            // FIXME: debug
            $display("Got LOAD for addr: %h", DATA_ADDR);
            // registers[rd] <= data_in_ram;
          end
        STORE :
          begin
            $display("Got STORE");
          end
        MISCMEM :
          begin
            $display("Got MISCMEM");
          end
        SYSTEM :
          begin
            $display("Got SYSTEM");
          end
        //default : $display("ERROR : ");
      endcase
      assign IADDR = pc + 1;
      pc = pc + 1;
    end
endmodule
