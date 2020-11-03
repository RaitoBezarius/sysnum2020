`include "riscv.v"

module testbed();
  reg clk = 1;

  wire [15:0] ram_link;
  wire [15:0] rom_link;

  wire [2:0] led1;
  wire [2:0] led2;

  riscv soc(ram_link, rom_link, clk, led1, led2);

  initial
  begin
          $dumpfile("riscv.vcd");
          $dumpvars(0, testbed);
  end

  always #1
  begin
          clk <= ~clk;
  end

endmodule
