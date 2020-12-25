
`default_nettype none

`include "core/hart.sv"
`include "core/memory/system.sv"

/* verilator lint_off PINMISSING */
module memsys_testbed(clk, reset);

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

input reg clk;
input reg reset;

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
wire [3:0] bram_sel;

// A FPGA Block RAM.
block_ram #(
  .XLEN(XLEN)
) bus1_bram(
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

wire [W-1:0] memsys_rw_i_addr, memsys_rw_i_data, memsys_rw_o_data;
wire memsys_rw_stb, memsys_rw_stall, memsys_rw_ack,
  memsys_we, memsys_rw_cyc, memsys_rw_err;
wire [(W/8-1):0] memsys_sel;

// Memory system
memory_system #(
  .XLEN(XLEN),
  .MW(W) // Simpler for now.
)
  membus(
    .i_clk(clk),
    .i_reset(reset),

    // RW interface
    .i_rw_addr(memsys_rw_i_addr),
    .i_data(memsys_rw_i_data),
    .i_be(memsys_sel),
    .i_we(memsys_we),
    .i_rw_stb(memsys_rw_stb),
    .o_rw_ack(memsys_rw_ack),
    .o_rw_stall(memsys_rw_stall),
    .o_rw_err(memsys_rw_err),
    .o_rw_data(memsys_rw_o_data),
    .o_rw_cyc(memsys_rw_cyc),
    // RO interface
    .i_ro_stb(1'b0), // Hardwire strobe for read-only.

    // BUS 1: Block RAM
    .i_wbs1_data(bram_o_data),
    .o_wbs1_data(bram_i_data),
    .o_wbs1_addr(bram_i_addr),
    .i_wbs1_ack(bram_ack),
    .i_wbs1_stall(bram_stall),
    .i_wbs1_err(1'b0), // Hardwire error, as BRAM cannot fail.
    .o_wbs1_be(bram_sel),
    .o_wbs1_stb(bram_stb),
    .o_wbs1_we(bram_we),
    // Hardwire all disabled buses.
    .i_wbs2_err(1'b1),
    .i_wbs3_err(1'b1),
    .i_wbs4_err(1'b1),
    .i_wbs5_err(1'b1)
  );

// RISC-V Hart

hart #(
  .XLEN(XLEN)
) hart0(
  .clk(clk),

  .i_data(memsys_rw_o_data),
  .i_data_ack(memsys_rw_ack),
  .i_data_stall(memsys_rw_stall),
  .o_data(memsys_rw_i_data),
  .o_data_addr(memsys_rw_i_addr),
  .o_wb_we(memsys_we),
  .o_wb_sel(memsys_sel),
  .o_wb_stb(memsys_rw_stb),

  .rom_addr(rom_addr),
  .rom_in(rom_out),
  .fw_rom_addr(fw_rom_addr),
  .fw_rom_in(fw_rom_out)
);

// Simulation tracing and run.
initial begin
        $display("Simulation starts now and finish in %d ticks.", `N_TICKS);
end

endmodule

