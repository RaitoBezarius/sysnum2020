<<<<<<< Updated upstream
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
=======
module riscv(ram_link, rom_link, clk_in, led1, led2, RxD, TxD);
  wire [31:0] rom_adress;
>>>>>>> Stashed changes
  wire [31:0] rom_read;
  wire [31:0] ram_address;
  wire [31:0] ram_read;
  wire [31:0] ram_write;
  wire clk;
  wire ram_write_enable;
  wire [31:0] cpu_vga_link;

  wire [15:0] rom_link;
  wire [15:0] ram_link;

<<<<<<< Updated upstream
  core CORE(.ram_address(ram_address), .rom_address(rom_address), .data_in_ram(ram_read), .data_out_ram(ram_write), .data_in_rom(rom_read), .ram_enable_write(ram_write_enable), .vga_link(cpu_vga_link), .clk(clk));
  ramctlr RAM(.ram_link(ram_link), .cpu_link_address(ram_address), .cpu_link_read(ram_read), .cpu_link_write(ram_write), .write_enable(ram_write_enable), .clk(clk));
  romctlr ROM(.rom_link(rom_link), .cpu_link_read(rom_read), .cpu_link_address(rom_address), .clk(clk));
=======
  inout [15:0] ram_link;
  inout [15:0] rom_link;
  input clk_in;

  output [2:0] led1;
  output [2:0] led2;

  output TxD;
  input RxD;

  wire TxD_start;
  wire [7:0] TxD_data;

  wire RxD_data_ready;
  wire [7:0] RxD_data;


  core CORE(.ram_adress(ram_adress), .rom_adress(rom_adress), .data_in_ram(ram_read), .data_out_ram(ram_write), .data_in_rom(rom_read), .ram_enable_write(ram_write_enable), .vga_link(cpu_vga_link), .clk(clk));
  ramctlr RAM(.ram_link(ram_link), .cpu_link_adress(ram_adress), .cpu_link_read(ram_read), .cpu_link_write(ram_write), .write_enable(ram_write_enable), .clk(clk));
  romctlr ROM(.rom_link(rom_link), .cpu_link_read(rom_read), .cpu_link_adress(rom_adress), .clk(clk));
>>>>>>> Stashed changes
  vgactlr VGA(cpu_vga_link, led1, clk);
  clockctlr CLK(.clk_in(clk_in), .clk_out(clk));

  async_transmitter AT(.clk(clk), .TxD_start(TxD_start), .TxD_data(TxD_data), .TxD(TxD));
  async_receiver AR(.clk(clk), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data));
endmodule
