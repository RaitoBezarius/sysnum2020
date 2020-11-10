`define X_LEN = 32;



module alu(a, b, r, opcode);

  input [32:0] a;
  input [32:0] b;

  output [32:0] r;

  input [4:0] opcode;

  /*
  operation codes :
  0000 R = 0
  0001 R = A
  0010 R = A + 1
  0011 R = A - 1
  0100 R = A + B
  0101 R = A - B
  0110 R = A << B
  0111 R = A >> B
  1000 R = A >>> B
  1001 R =
  1010 R =
  1011 R =
  1100 R =
  1101 R =
  1110 R =
  1111 R =
  */

  parameter nullOp = 5'b00000;
  parameter id = 5'b00001;
  parameter incr = 5'b00010;
  parameter decr = 5'b00011;
  parameter plus = 5'b00100;
  parameter minus = 5'b00101;
  parameter sll = 5'b00110;
  parameter srl = 5'b00111;
  parameter sra = 5'b01000;
  parameter mul = 5'b01001;
  parameter mulh = 5'b01010;
  parameter mulhu = 5'b01011;
  parameter mulhsu = 5'b01100;
  parameter div = 5'b01101;
  parameter divu = 5'b01110;
  parameter rem = 5'b01111;
  parameter remu = 5'b10000;
  parameter orOp = 5'b10001;
  parameter xorOp = 5'b10010;
  parameter andOp = 5'b10011;
  parameter slt = 5'b10100;
  parameter sltu = 5'b10101;

  assign r =
    opcode == nullOp ? 32'b0 :
    opcode == id ? a :
    opcode == incr ? a + 1 :
    opcode == decr ? a - 1 :
    opcode == plus ? a + b :
    opcode == minus ? a - b :
    opcode == sll ? a << b[4:0] :
    opcode == srl ? a >> b[4:0] :
    opcode == sra ? a >>> b[4:0] :
    opcode == mul ? $signed(a) * $signed(b) :
    opcode == mulh ? ($signed(a) * $signed(b)) >> 32 :
    opcode == mulhu ? ($unsigned(a) * $unsigned(b)) >> 32 :
    opcode == mulhsu ? ($signed(a) * $unsigned(b)) >> 32 :
    opcode == div ? ($signed(a) / $signed(b)) :
    opcode == divu ? ($unsigned(a) / $unsigned(b)) :
    opcode == rem ? ($signed(a) % $signed(b)) :
    opcode == remu ? ($unsigned(a) / $unsigned(b)) :
    opcode == orOp ? a || b :
    opcode == xorOp ? a ^ b :
    opcode == andOp ? a && b :
    opcode == slt ? {31'b0, $signed(a) < $signed(b)} :
    opcode == sltu ? {31'b0, $unsigned(a) < $unsigned(b)} : 32'b0;
endmodule
