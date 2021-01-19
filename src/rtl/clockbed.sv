
`default_nettype none

`include "core/hart.sv"

module clockbed(clk, reset);

// Default implementation.
`ifndef XLEN
`define XLEN 32
`endif

localparam XLEN = `XLEN;
localparam W = XLEN; // RAM width.

// Clock

input wire clk;
input wire reset;

// ROM
wire [W-1:0] rom_addr, rom_out;
reg [W-1:0] ROM [511:0];
initial $readmemh("test.hex", ROM);
assign rom_out = ROM[rom_addr >> 2];
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
wire bram_we, bram_stall, bram_ack, bram_stb;
wire [2:0] bram_sel;

// A FPGA Block RAM.
block_ram #(
  .XLEN(XLEN)
) bram(
  .i_clk(clk),
  .i_reset(reset),
  .i_wb_stb(bram_stb),

  .i_addr(bram_i_addr),
  .i_data(bram_i_data),
  .i_wb_we(bram_we),
  .i_wb_sel(bram_sel),

  .o_wb_data(bram_o_data),
  .o_wb_stall(bram_stall),
  .o_wb_ack(bram_ack)
);

// RISC-V hart
hart #(
  .XLEN(XLEN)
) hart0(
	.clk(clk),

  .i_data(bram_o_data),
  .i_data_err(1'b0),
  .i_data_cache_hits(1'b0),
  .i_data_cache_misses(1'b0),
  .i_data_ack(bram_ack),
  .i_data_stall(bram_stall),
  .o_data(bram_i_data),
  .o_data_addr(bram_i_addr),
  .o_wb_sel(bram_sel),
  .o_wb_we(bram_we),
  .o_wb_stb(bram_stb),

	.rom_addr(rom_addr),
	.rom_in(rom_out),

  .fw_rom_addr(fw_rom_addr),
  .fw_rom_in(fw_rom_out)
);

endmodule

