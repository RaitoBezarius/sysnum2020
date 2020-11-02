`include "riscv.v"
`include "ramctlr.v"
`include "romctlr.v"

module riscv_tb();
  parameter integer STEPS_AMOUNT = 1000;

  wire [31:0] ram_adress;
  wire [31:0] ram_data_in;
  wire [31:0] ram_data_out;
  wire ram_enable_write;

  wire [31:0] rom_adress;
  wire [31:0] rom_data_in;

  reg clk = 1;

  reg step = 0;

  romctlr rom_ctlr(rom_adress, rom_data_in, clk);
  ramctlr ram_ctlr(ram_adress, ram_data_in, ram_enable_write, ram_data_out, clk);
  riscv riscv_core(ram_adress, rom_adress, ram_data_in, ram_data_out, rom_data_in, ram_enable_write, clk);

  initial
    begin
      $dumpfile("riscv.vcd");
      $dumpvars(0, riscv_tb);
    end

  always #1
    begin
      clk <= ~clk;
    end
endmodule
