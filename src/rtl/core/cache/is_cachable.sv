`default_nettype none

`define BANK_1_BOUNDARY 32'h20000000
`define BANK_2_BOUNDARY 32'h28000000
`define BANK_3_BOUNDARY 32'h30000000
`define BANK_4_BOUNDARY 32'h38000000
`define BANK_5_BOUNDARY 32'h40000000


module is_cachable #(
  parameter BANK_1_CACHABLE = 1'b1, // RAM.
  parameter BANK_2_CACHABLE = 1'b0, // CSR.
  parameter BANK_3_CACHABLE = 1'b0, // UART.
  parameter BANK_4_CACHABLE = 1'b0, // VGA || GPIO.
  parameter BANK_5_CACHABLE = 1'b0 // QSPI.
)
(i_addr, o_cachable);

parameter AW = 32;

input wire [AW-1:0] i_addr;
output reg o_cachable;

always @(*)
begin
  o_cachable = 1'b0;
  // Always start from the end.
  // Otherwise, Verilog will always attribute the BANK_5_CACHABLE status
  // obviously.
  if (i_addr < `BANK_5_BOUNDARY)
    o_cachable = BANK_5_CACHABLE;
  if (i_addr < `BANK_4_BOUNDARY)
    o_cachable = BANK_4_CACHABLE;
  if (i_addr < `BANK_3_BOUNDARY)
    o_cachable = BANK_3_CACHABLE;
  if (i_addr < `BANK_2_BOUNDARY)
    o_cachable = BANK_2_CACHABLE;
  if (i_addr < `BANK_1_BOUNDARY)
    o_cachable = BANK_1_CACHABLE;
end

endmodule
