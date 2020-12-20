
`default_nettype none

`include "core/core.sv"

module testbed();

// Default implementation.
`ifndef XLEN
`define XLEN 32
`endif

`ifndef N_TICKS
`define N_TICKS 5000
`endif


localparam XLEN = `XLEN;
localparam W = XLEN; // RAM width.

// Clock

reg clk;
reg reset;

initial clk = 1;
initial reset = 0;

always begin
	#1 clk <= ~clk;
end

// ROM
wire [W-1:0] rom_addr, rom_out;
reg [W-1:0] ROM [511:0];
initial $readmemh("test.hex", ROM);
assign rom_out = ROM[rom_addr];
always @(posedge clk) begin
    if(rom_addr[1:0] != 2'b00) begin
		$display("Misaligned ROM address !");
		$finish;
	end
end

// Firmware ROM
// TODO(Julien): Make it as small as possible !
// Answer(Ryan): indeed, it has 2 32-bits entries. :>
// TODO(Ryan, will never be implemented): an interesting way to have small
// core is E extension.

wire [W-1:0] fw_rom_addr, fw_rom_out;
reg [W-1:0] FW_ROM [2:0];
initial $readmemh("firmware.hex", FW_ROM);
assign fw_rom_out = FW_ROM[fw_rom_addr];
always @(posedge clk) begin
	if(fw_rom_addr[1:0] != 2'b00) begin
        $display("Misaligned firmware ROM address !");
		$finish;
	end
end

// B-RAM on FPGA. Will be useful for L1d.
wire [W-1:0] bram_i_addr, bram_i_data, bram_o_data;
wire bram_we, bram_stall, bram_ack;
wire [2:0] bram_sel;

// A FPGA Block RAM.
block_ram #(
  .XLEN(XLEN)
) ram(
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

// RISC-V hart
riscv #(
  .XLEN(XLEN)
) hart(
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

// Simulation tracing and run.
initial begin
        $display("Simulation starts now and finish in %d ticks.", `N_TICKS);
        $dumpfile("trace.vcd");
        $dumpvars(0, testbed);
        #`N_TICKS $finish;
end

endmodule

