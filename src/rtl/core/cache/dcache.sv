`default_nettype none

module dcache #(
  parameter XLEN = 32,
  parameter W = XLEN,
  parameter DW = XLEN, // Cache data width
  parameter AW = XLEN, // Cache address width
  parameter MW = W, // Memory width, depends on what do we connect on the other side.
  parameter SIZE = 64, // kb.
  parameter BLOCK_SIZE = XLEN,
  parameter WAYS = 2 // associativity.
)
(
  i_clk, i_reset, i_flush,
  i_stb, i_op, i_addr, i_data,
  o_busy
);

localparam PAGE_SIZE = 4*1024; // 4kb.
localparam MAX_IDX_BITS = $clog2(PAGE_SIZE) - $clog2(BLOCK_SIZE); // log_2(page_size / block_size)
localparam SETS = (SIZE*1024) / BLOCK_SIZE / WAYS;
localparam BLK_OFF_BITS = $clog2(BLOCK_SIZE); // Number of BlockOffset bits
localparam IDX_BITS = $clog2(SETS); // Number of Index bits
localparam TAG_BITS = XLEN - IDX_BITS - BLK_OFF_BITS; // Number of tag bits.

localparam [1:0] DC_IDLE = 2'b00;
localparam [1:0] DC_WRITE = 2'b01;
localparam [1:0] DC_READS = 2'b10; // Read a single value cached
localparam [1:0] DC_READM = 2'b11; // Read a whole cache line

enum logic [1:0] {DC_IDLE, DC_WRITE, DC_READS, DC_READM} state; // Cache FSM state.

typedef struct {
  logic [IDX_BITS - 1:0] idx;
  logic [XLEN - 1: 0] addr; // it must be a physical address here.
  logic [XLEN/8 - 1:0] be; // byte enable.
  logic [XLEN - 1:0] data;

  // private signals
  logic [WAYS - 1:0] hit;
  logic was_write;
} pipeline_write_buffer_t;

typedef struct {
  logic valid;
  logic dirty;
  logic [TAG_BITS-1:0] tag;
} tag_struct;
localparam TAG_STRUCT_BITS = $bits(tag_struct);

input wire i_clk, i_reset, i_flush;
// CPU→Cache interface
input wire i_wb_cyc, i_wb_stb; // Wishbone specific.
input wire i_we; // Write enable.
input wire [(AW-1):0] i_addr; // Target address.
input wire [(DW-1):0] i_data; // For the cache writes.
input wire [(AW/8-1):0] i_be; // Byte enable.

output reg o_wb_stall, o_wb_ack, o_wb_err; // Wishbone specific.
output reg o_valid; // Valid data.
output reg [(DW-1):0] o_data; // Actual data under valid flag.

// Cache→Memory interface

generate
  for (way = 0; way < WAYS ; way++)
  begin: gen_ways_tag
    // Place block RAM for tags
    block_ram #(
      .AW(IDX_BITS),
      .DW(TAG_BITS),
      .LGMEMSZ(IDX_BITS) // idx_bits entries.
    ) tag_ram(
      .i_reset(i_reset),
      .i_clk(i_clk),
      .i_addr(tag_idx),
      .i_wb_we(tag_we[way]),
      .i_wb_be({(TAG_BITS+7)/8{1'b1}}),
      .i_data(tag_in[way].tag),
      .o_wb_data(tag_out[way].tag),
      .i_wb_stb(tag_stb),
      .o_wb_stall(tag_stall),
      .o_wb_ack(tag_ack)
    );


  end
endgenerate

output wire o_wb_cyc;
output reg o_wb_stb, o_wb_we;
output reg [(AW-1):0] o_wb_addr;
output reg [(MW-1):0] o_wb_data; // Memory data.
output reg [(W/8-1):0] o_wb_sel;

// Wishbone master interface
output wire o_wb_cyc;
output reg o_wb_stb;
output reg o_wb_we;
output reg [(W-1):0] o_wb_addr;
output reg [(W-1):0] o_wb_data;
output reg [(W/8-1):0] o_wb_sel;

// Wishbone slave interface
input wire i_wb_stall, i_wb_ack, i_wb_err;
input wire [(W-1):0] i_wb_data;

// Cache
tag_struct tag_in[WAYS];
logic cache_hit;


always @(posedge i_clk)
end
