module riscv(ram_link, rom_link, clk_in, led1, led2);
  wire [31:0] rom_adress;
  wire [31:0] rom_read;
  wire [31:0] ram_adress;
  wire [31:0] ram_read;
  wire [31:0] ram_write;
  wire clk;
  wire ram_write_enable;
  wire [31:0] cpu_vga_link;

  wire [15:0] rom_link;
  wire [15:0] ram_link;

  inout [15:0] ram_link;
  inout [15:0] rom_link;
  input clk_in;

  output [2:0] led1;
  output [2:0] led2;

  core CORE(.ram_adress(ram_adress), .rom_adress(rom_adress), .data_in_ram(ram_read), .data_out_ram(ram_write), .data_in_rom(rom_read), .ram_enable_write(ram_write_enable), .vga_link(cpu_vga_link), .clk(clk));
  ramctlr RAM(.ram_link(ram_link), .cpu_link_adress(ram_adress), .cpu_link_read(ram_read), .cpu_link_write(ram_write), .write_enable(ram_write_enable), .clk(clk));
  romctlr ROM(.rom_link(rom_link), .cpu_link_read(rom_read), .cpu_link_adress(rom_adress), .clk(clk));
  vgactlr VGA(cpu_vga_link, led1, clk);
  clockctlr CLK(.clk_in(clk_in), .clk_out(clk));
endmodule
