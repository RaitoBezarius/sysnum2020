`include "core.v"
`include "ramctlr.v"
`include "romctlr.v"
`include "vgactlr.v"
`include "clockctlr.v"

module riscv(
        inout [15:0] ram_link,
        inout [15:0] rom_link,
        input clk_in,
        input RST,
        output [2:0] led1,
        output [2:0] led2);
  wire [31:0] rom_address;
  wire [31:0] rom_read;
  wire [31:0] ram_address;
  wire [31:0] ram_read;
  wire [31:0] ram_write;


  wire [31:0] RAM_DATA_OUT;
  wire [31:0] RAM_ADDR_OUT;
  wire [31:0] RAM_ADDR_IN;
  wire [31:0] RAM_VALUE;
  wire RAM_WD;



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
    .DATA(RAM_DATA_OUT),
    .ADDR_OUT(RAM_ADDR_OUT),
    .ADDR_IN(RAM_ADDR_IN),
    .VALUE(RAM_VALUE),
    .WD(RAM_WD),
    .clk1(clk),
    .clk2(clk)
  );

  core CORE(
    .DATA_ADDR(RAM_ADDR_OUT),
    .INSTR_ADDR(rom_address),
    .DATA_IN(RAM_DATA_OUT),
    .DATA_OUT(RAM_VALUE),
    .INSTR_DATA(rom_read),
    .WRITE_ENABLE(RAM_WD),
    .READ_ENABLE(RAM_READY),
    .BYTE_ENABLE(be),
    .clk(clk));

  romctlr ROM(.rom_link(rom_link), .cpu_link_read(rom_read), .cpu_link_address(rom_address), .clk(clk));

  vgactlr VGA(cpu_vga_link, led1, clk);
  clockctlr CLK(.clk_in(clk_in), .clk_out(clk));
endmodule
