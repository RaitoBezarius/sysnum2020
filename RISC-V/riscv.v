`include "core.v"
`include "ramctlr.v"
`include "romctlr.v"
`include "vgactlr.v"
`include "clockctlr.v"

module riscv(
        inout [15:0] ram_link,
        inout [15:0] rom_link,
        input clk_in,
        output [2:0] led1,
        output [2:0] led2);
  wire [31:0] rom_address;
  wire [31:0] rom_read;
  wire [31:0] ram_address;
  wire [31:0] ram_read;
  wire [31:0] ram_write;
  wire clk;
  wire ram_write_enable;
  wire [31:0] cpu_vga_link;

  wire [15:0] rom_link;
  wire [15:0] ram_link;

  output TxD;
  input RxD;

  wire TxD_start;
  wire [7:0] TxD_data;

  wire RxD_data_ready;
  wire [7:0] RxD_data;


  ramctlr RAM(
    .DATA(),
    .ADDR_OUT(),
    .ADDR_IN(),
    .VALUE(),
    .WD(),
    .clk1(clk),
    .clk2(clk)
  );
  core CORE(
    .DATA_ADDR(ram_address),
    .INSTR_ADDR(rom_address),
    .DATA_IN(ram_read),
    .DATA_OUT(ram_write),
    .INSTR_DATA(rom_read),
    .WRITE_ENABLE(ram_write_enable),
    .READ_ENABLE(ram_read_enable),
    .BYTE_ENABLE(be),
    .clk(clk));
  ramctlr RAM(.ram_link(ram_link), .cpu_link_address(ram_address), .cpu_link_read(ram_read), .cpu_link_write(ram_write), .write_enable(ram_write_enable), .clk(clk));
  romctlr ROM(.rom_link(rom_link), .cpu_link_read(rom_read), .cpu_link_address(rom_address), .clk(clk));

  vgactlr VGA(cpu_vga_link, led1, clk);
  clockctlr CLK(.clk_in(clk_in), .clk_out(clk));
endmodule
