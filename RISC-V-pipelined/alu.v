module alu(
  input [31:0] A, //operand A
  input [31:0] B, //operand B
  input [3:0] O,  // operation code
  input [1:0] S,  // whether or not the operands should be consirdered signed
  input clk,      // system clock
  output [31:0] R,// result output
  output [31:0] F // flag output
  );
 /*
 operation codes :
 0000 R = 0
 0001 R = A
 0010 R = A + 1
 0011 R = A - 1
 0100 R = A + B
 0101 R = A - B
 0110 R = A / B
 0111 R = A % B
 1000 R = A
 1001 R = A
 1010 R = A
 1011 R = A
 1100 R = A
 1101 R = A
 1110 R = A
 1111 R = A
 */
endmodule
