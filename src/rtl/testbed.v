
`default_nettype none

`include "core/core.sv"

module testbed();

localparam XLEN = 32;
localparam W = XLEN;

// Clock

reg clk;
reg reset;

initial clk = 1;
initial reset = 0;

always begin
	#1 clk <= ~clk;
end

// RAM (unused atm)

wire [31:0] ram_read_addr;
wire [31:0] ram_write_addr;
wire        ram_write_enable;
wire [31:0] ram_data_in;
wire [31:0] ram_data_out;

reg [31:0] RAM [31:0];

assign ram_data_out = RAM[ram_read_addr];

always @(posedge clk) begin
    if (ram_write_enable) begin
        RAM[ram_write_addr] <= ram_data_in;
    end
end

// ROM

wire [31:0] rom_addr;
wire [31:0] rom_out;

reg [31:0] ROM [53:0];
// wire [31:0] base_addr;

initial $readmemh("test.hex", ROM);

assign rom_out = ROM[rom_addr];

always @(posedge clk) begin
    if(rom_addr[1:0] != 2'b00) begin
		$display("Misaligned ROM address !");
		$finish;
	end
end

// Firmware ROM
// TODO: Make it as small as possible !

wire [31:0] fw_rom_addr;
wire [31:0] fw_rom_out;

reg [31:0] FW_ROM [2:0];
// wire [31:0] fw_base_addr;

initial $readmemh("firmware.hex", FW_ROM);

assign fw_rom_out = FW_ROM[fw_rom_addr];

always @(posedge clk) begin
	if(fw_rom_addr[1:0] != 2'b00) begin
        $display("Misaligned firmware ROM address !");
		$finish;
	end
end

wire [W-1:0] bram_i_addr, bram_i_data, bram_o_data;
wire bram_we, bram_stall, bram_ack;
wire [2:0] bram_sel;

// A FPGA Block RAM.
block_ram ram(
  .i_clk(clk),
  .i_reset(reset),
  .i_wb_stb(),

  .i_addr(bram_i_addr),
  .i_data(bram_i_data),
  .i_wb_we(bram_we),
  .i_wb_sel(bram_sel),

  .o_wb_data(bram_o_data),
  .o_wb_stall(bram_stall),
  .o_wb_ack(bram_ack)
);

// Processor
riscv soc(
	.clk(clk),

  .i_data(bram_o_data),
  .o_data(bram_i_data),
  .o_data_addr(bram_i_addr),
  .o_wb_sel(bram_sel),
  .o_wb_we(bram_we),

	.rom_addr(rom_addr),
	.rom_in(rom_out),

  .fw_rom_addr(fw_rom_addr),
  .fw_rom_in(fw_rom_out)
);

// Simulation setup

initial begin
        $display("Simulation starts now and finish in 5000 ticks.");
        $dumpfile("test.vcd");
        $dumpvars(0, testbed);
        #5000 $finish;
end

endmodule

