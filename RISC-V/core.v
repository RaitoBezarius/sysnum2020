module core(ram_adress, rom_adress, data_in_ram, data_out_ram, data_in_rom, ram_enable_write, vga_link, clk);
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

  output reg [31:0] ram_adress = 32'b0;
  output reg [31:0] rom_adress = 32'b0;

  input [31:0] data_in_ram;
  input [31:0] data_in_rom;

  output reg [31:0] data_out_ram = 32'b0;
  output reg ram_enable_write = 0;

  output reg [31:0] vga_link;


  input clk;

  reg [31:0] pointer = 32'b0;
  reg [31:0] instruction = 32'b0;
  reg [31:0] immediate = 32'b0;
  reg [31:0] registers [32:0];

  reg [31:0] registre = 32'b0;


  //Décomposition de l'instruction
  reg [4:0] rs1 = 5'b0;
  reg [4:0] rs2 = 5'b0;
  reg [4:0] rd  = 5'b0;

  reg [6:0] opcode = 7'b0;
  reg [2:0] funct3 = 3'b0;

  reg [6:0] immS = 7'b0;
  reg [11:0] immL = 12'b0;

  integer i;
  initial
    begin
      for(i=0;i<32;i=i+1)
        registers[i] = 32'b0;
    end

  always @(posedge clk)
    begin

      //Pre-process
      instruction = data_in_rom;
      rom_adress = pointer;

      //Instruction handling
      opcode = instruction[6:0];
      funct3 = instruction[14:12];
      rs1 =    instruction[19:15];
      rs2 =    instruction[24:20];
      rd =     instruction[11:7];
      immS =   instruction[31:25];
      immL =   instruction[31:20];
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
            pointer = pointer + {{19{immL[11]}}, {{{immL[11], {rs1, funct3}}, immL[10:0]}, 1'b0}} - 1;
            registers[rd] <= pointer + 1;
          end
        JALR :
          begin
            $display("Got JALR");
          end
        IMM :
          begin
            //$display("Got IMM");
            case(funct3)
              ADD : registers[rd] <= registers[rs1] + {{20{immL[11]}}, immL};
              SLT : registers[rd] <= {31'b0, $signed(registers[rs1]) < $signed({{20{immL[11]}}, immL})};
              SLTU : registers[rd] <= {31'b0, registers[rs1] < {{20{immL[11]}}, immL}};
              XOR : registers[rd] <= registers[rs1] ^ {{20{immL[11]}}, immL};
              OR : registers[rd] <= registers[rs1] || {{20{immL[11]}}, immL};
              AND : registers[rd] <= registers[rs1] && {{20{immL[11]}}, immL};
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
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              SLL : begin
                      if(registers[rs1] != registers[rs2])
                      begin
                        //$display("Went backwards");
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
                    end
              XOR : if($signed(registers[rs1]) < $signed(registers[rs2]))
                      begin
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              SRL : if($signed(registers[rs1]) >= $signed(registers[rs2]))
                      begin
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              OR : if(registers[rs1] < registers[rs2])
                      begin
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              AND : if(registers[rs1] >= registers[rs2])
                      begin
                        pointer = pointer + {{{{{{19{immS[6]}}, immS[6]}, immS[5:0]},  rd[0]}, rd[4:1]}, 1'b0} - 1;
                      end
              endcase
          end
        LOAD :
          begin
            $display("Got ");
          end
        STORE :
          begin
            $display("Got ");
          end
        MISCMEM :
          begin
            $display("Got ");
          end
        SYSTEM :
          begin
            $display("Got ");
          end
        //default : $display("ERROR : ");
      endcase
      pointer = pointer + 1;
      vga_link = vga_link + 1;
    end
endmodule
