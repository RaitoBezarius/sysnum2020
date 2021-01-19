`default_nettype none

`include "core/hart.sv"
`include "core/memory/system.sv"
`include "core/cache/dcache.sv"

/* verilator lint_off PINMISSING */
module soc
#(
  parameter XLEN = 32,
  parameter AW = XLEN,
  parameter DW = XLEN,
  parameter MW = XLEN
)
(
  i_clk, 
  i_reset,
  rom_addr,
  rom_out,
  fw_rom_addr,
  fw_rom_out
);

input reg i_clk, i_reset;

output wire [AW-1:0] rom_addr, fw_rom_addr;
input wire [DW-1:0] rom_out, fw_rom_out;

// FPGA Block RAM
// FIXME(Ryan): add a `ifdef to test arbitrarily slow RAM (e.g. 300 cycles,
// etc).
// TODO(Ryan): replace me by a real DDR3L controller someday.

wire [AW-1:0] bram_i_addr;
wire [MW-1:0] bram_i_data, bram_o_data;
wire bram_we, bram_stall, bram_ack, bram_stb;
wire [3:0] bram_sel;

block_ram #(
  .XLEN(XLEN)
) bus1_bram(
  .i_clk(i_clk),
  .i_reset(i_reset),
  .i_wb_stb(bram_stb),
  
  .i_addr(bram_i_addr),
  .i_data(bram_i_data),
  .i_wb_we(bram_we),
  .i_wb_sel(bram_sel),

  .o_wb_data(bram_o_data),
  .o_wb_stall(bram_stall),
  .o_wb_ack(bram_ack)
);

wire [AW-1:0] memsys_rw_i_addr;
wire [DW-1:0] memsys_rw_i_data, memsys_rw_o_data;
wire memsys_rw_stb, memsys_rw_stall, memsys_rw_ack,
  memsys_we, memsys_rw_cyc, memsys_rw_err;
wire [(DW/8-1):0] memsys_sel;

memory_system #(
  .XLEN(XLEN),
  .MW(MW)
) memsys(
  .i_clk(i_clk),
  .i_reset(i_reset),

  .i_rw_addr(l1d_mem_addr),
  .i_data(l1d_o_mem_data),
  .i_be(l1d_mem_be),
  .i_we(l1d_mem_we),
  .i_rw_stb(l1d_mem_stb),

  .o_rw_ack(l1d_mem_ack),
  .o_rw_stall(l1d_mem_stall),
  .o_rw_err(l1d_wb_err),

  // Bus 1: BRAM
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

// Cache→CPU interface.
wire l1d_wb_cyc, l1d_wb_stb;
wire l1d_wb_we;
wire [(AW/8-1):0] l1d_wb_be;
wire l1d_wb_stall, l1d_wb_ack, l1d_wb_err;
wire [(AW-1):0] l1d_i_addr;
wire [(DW-1):0] l1d_i_data, l1d_o_data;

// Cache→Memory interface
wire [(AW-1):0] l1d_mem_addr;
wire [(MW-1):0] l1d_i_mem_data, l1d_o_mem_data;
wire l1d_mem_we, l1d_mem_stb, l1d_mem_wb_err, l1d_mem_ack, l1d_mem_stall;
wire [(MW/8-1):0] l1d_mem_be;
wire [(DW-1):0] l1d_cache_hits, l1d_cache_misses;

dcache #(
  .AW(AW),
  .DW(DW),
  .MW(MW)
) l1d(
  .i_clk(i_clk),
  .i_reset(i_reset),

  // Statistics.
  .o_cache_hits(l1d_cache_hits),
  .o_cache_misses(l1d_cache_misses),

  // CPU interconnection.
  .i_wb_stb(l1d_wb_stb),
  .i_addr(l1d_i_addr),
  .i_data(l1d_i_data),
  .i_be(l1d_wb_be),
  .i_we(l1d_wb_we),
  .o_wb_stall(l1d_wb_stall),
  .o_wb_ack(l1d_wb_ack),
  .o_wb_err(l1d_wb_err),
  .o_data(l1d_o_data),

  // Memory system interconnection.
  .i_mem_ack(l1d_mem_ack),
  .i_mem_stall(l1d_mem_stall),
  .i_mem_wb_err(l1d_mem_wb_err),
  .i_mem_data(l1d_i_mem_data),
  .o_mem_addr(l1d_mem_addr),
  .o_mem_data(l1d_o_mem_data),
  .o_mem_wb_stb(l1d_mem_stb),
  .o_mem_wb_we(l1d_mem_we),
  .o_mem_wb_be(l1d_mem_be)
);

hart #(
  .XLEN(XLEN)
  //.OPT_DATA_CACHE(1),
) hart0(
  .clk(i_clk),

  // L1d cache wires
  .i_data(l1d_o_data),
  .i_data_ack(l1d_wb_ack),
  .i_data_stall(l1d_wb_stall),
  .i_data_err(l1d_wb_err),

  .o_data(l1d_i_data),
  .o_data_addr(l1d_i_addr),

  // FIXME(Ryan): rename o_wb into o_wb_data rather.
  .o_wb_sel(l1d_wb_be),
  .o_wb_we(l1d_wb_we),
  .o_wb_stb(l1d_wb_stb),

  // Statistics for CSR.
  .i_data_cache_hits(l1d_cache_hits),
  .i_data_cache_misses(l1d_cache_misses),

  // FIXME: Legacy ROM / firmware ROM
  .rom_addr(rom_addr),
  .rom_in(rom_out),

  .fw_rom_addr(fw_rom_addr),
  .fw_rom_in(fw_rom_out)
);

endmodule
