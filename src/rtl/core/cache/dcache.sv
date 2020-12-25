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
  i_wb_stb, i_addr, i_data, i_be, i_we, o_wb_stall, o_wb_ack, o_wb_err, o_data,
  i_mem_ack, i_mem_stall, i_mem_wb_err,
  i_mem_addr, i_mem_data, o_mem_data, o_mem_wb_stb, o_mem_wb_we, o_mem_wb_be,
  o_cache_hits, o_cache_misses
);

// Syscon
input wire i_clk, i_reset, i_flush;

// CPU interface
input wire i_wb_stb, i_we;
input wire [AW-1:0] i_addr;
input wire [DW-1:0] i_data;
input wire [DW/8-1:0] i_be;

output wire o_wb_stall;
output [DW-1:0] o_data;
output reg o_wb_ack, o_wb_err;

// Memory system interface
input wire i_mem_ack, i_mem_stall, i_mem_wb_err;
input wire [AW-1:0] i_mem_addr;
input wire [MW-1:0] i_mem_data;
output wire [MW-1:0] o_mem_data;
output reg o_mem_wb_stb;
output wire o_mem_wb_we;
output wire [MW/8-1:0] o_mem_wb_we;

localparam PAGE_SIZE = 4*1024; // 4kb.
localparam MAX_IDX_BITS = $clog2(PAGE_SIZE) - $clog2(BLOCK_SIZE); // log_2(page_size / block_size)
localparam SETS = (SIZE*1024) / BLOCK_SIZE / WAYS;
localparam BLK_OFF_BITS = $clog2(BLOCK_SIZE); // Number of BlockOffset bits
localparam IDX_BITS = $clog2(SETS); // Number of Index bits
localparam TAG_BITS = XLEN - IDX_BITS - BLK_OFF_BITS; // Number of tag bits.

/* States */
localparam IDLE = 0;
localparam UNCACHEABLE = 1;
localparam REFRESH_1 = 2;
localparam CLEAN_SINGLE = 3;
localparam FETCH_SINGLE = 4;
localparam REFRESH = 5;
localparam INVALIDATE = 6;
localparam CLEAN = 7;

enum logic [$clog2(MAX_STATE) - 1:0] {IDLE, UNCACHEABLE, REFRESH_1, CLEAN_SINGLE, FETCH_SINGLE, REFRESH, INVALIDATE, CLEAN} state;

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

pipeline_write_buffer_t write_buffer; // To not pay the penalty of a write-through, we implement a write buffer we flush once it's full.

// Cachability (memory mapped IOs exclusion)
wire cachable_addr;
iscachable check_address(i_addr, cachable_addr);

// Tag management interface using BRAMs.
wire tag_stb, tag_stall, tag_ack;
reg [IDX_BITS-1:0] tag_idx;
tag_struct tag_out[WAYS-1:0];
tag_struct tag_in[WAYS-1:0];
reg tag_we[WAYS-1:0];

wire cache_hit;
wire [XLEN-1:0] o_cache_hits, o_cache_misses; // There can be at most 2^32 cache hits, cache misses.

assign o_cache_hits = cache_hit ? o_cache_hits + 1 : o_cache_hits;
assign o_cache_misses = !cache_hit ? o_cache_misses + 1 : o_cache_misses;

// Random way generation
reg [19:0] way_random;
wire [WAYS-1:0] fill_way_select;
initial way_random = 'h0;
always @(posedge i_clk)
  if (!filling) way_random <= {way_random, way_random[19] ~^ way_random[16]}; // LFSR for apparent randomness.

assign fill_way_select = (WAYS == 1) ? 1 : 1 << way_random[$clog2(WAYS)-1:0];

// Extract tag from address.
wire [TAG_BITS-1:0] c_tag;
wire [IDX_BITS-1:0] c_paddr_idx; // Physical index.

assign c_tag = i_addr[XLEN-1 -: TAG_BITS];
assign c_paddr_idx = i_addr[BLK_OFF_BITS +: IDX_BITS];

generate
  for (way = 0; way < WAYS ; way++)
  begin: gen_ways_tag
    // Place block RAM for tags
    block_ram #(
      .AW(IDX_BITS),
      .DW(TAG_BITS),
      .LGMEMSZ(IDX_BITS) // idx_bits entries. FIXME(Ryan): this is a suboptimal way to setup the block ram but it requires rewrite of the parameters.
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

wire should_buffer_write; // This control write buffer behavior vs write through.
assign should_buffer_write = write_buffer.was_write && cachable_addr; // If it's not a cachable addr, it's not useful to try to cache it.

end
