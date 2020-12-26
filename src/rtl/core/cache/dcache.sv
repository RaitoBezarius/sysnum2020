`default_nettype none

`include "core/cache/is_cachable.sv"

module dcache #(
  parameter XLEN = 32,
  parameter W = XLEN,
  parameter DW = XLEN, // Cache data width
  parameter AW = XLEN, // Cache address width
  parameter MW = W, // Memory width, depends on what do we connect on the other side.
  parameter SIZE = 64, // kb.
  parameter BLOCK_SIZE = XLEN, // XLEN bytes of size
  parameter WAYS = 2, // associativity.

  parameter BANK_1_CACHABLE = 1'b1,
  parameter BANK_2_CACHABLE = 1'b0,
  parameter BANK_3_CACHABLE = 1'b0,
  parameter BANK_4_CACHABLE = 1'b0,
  parameter BANK_5_CACHABLE = 1'b0
)
(
  i_clk, i_reset, i_flush,
  i_wb_stb, i_addr, i_data, i_be, i_we, o_wb_stall, o_wb_ack, o_wb_err, o_data,
  i_mem_ack, i_mem_stall, i_mem_wb_err,
  o_mem_addr, i_mem_data, o_mem_data, o_mem_wb_stb, o_mem_wb_we, o_mem_wb_be,
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
output wire [AW-1:0] o_mem_addr;
input wire [MW-1:0] i_mem_data;
output wire [MW-1:0] o_mem_data;
output reg o_mem_wb_stb;
output wire o_mem_wb_we;
output wire [MW/8-1:0] o_mem_wb_be;

localparam PAGE_SIZE = 4*1024; // 4kb.
localparam MAX_IDX_BITS = $clog2(PAGE_SIZE) - $clog2(BLOCK_SIZE); // log_2(page_size / block_size)
localparam SETS = (SIZE*1024) / BLOCK_SIZE / WAYS;
localparam BLK_OFF_BITS = $clog2(BLOCK_SIZE); // Number of BlockOffset bits
localparam IDX_BITS = $clog2(SETS); // Number of Index bits
localparam TAG_BITS = XLEN - IDX_BITS - BLK_OFF_BITS; // Number of tag bits.
localparam BLK_BITS = 8*BLOCK_SIZE; // Number of bits in a block
localparam DATA_OFF_BITS = $clog2(BLK_BITS) - $clog2(DW); // Byte offset in a given block

/* States */
localparam MAX_STATE = 8;

logic flushing, filling;
enum logic [$clog2(MAX_STATE) - 1:0] {IDLE, READ_TAG, WRITE_SINGLE, UNCACHABLE, FETCH_SINGLE, REFRESH, INVALIDATE, CLEAN} mem_state;
initial mem_state = IDLE;

typedef struct packed {
  logic [IDX_BITS - 1:0] idx;
  logic [AW - 1: 0] addr; // it must be a physical address here.
  logic [DW/8 - 1:0] be; // byte enable.
  logic [DW - 1:0] data;

  // private signals
  logic [WAYS - 1:0] hit;
  logic was_write;
} pipeline_write_buffer_t;

typedef struct packed {
  logic valid;
  logic dirty;
  logic [TAG_BITS-1:0] tag;
} tag_struct;
localparam TAG_STRUCT_BITS = $bits(tag_struct);

pipeline_write_buffer_t write_buffer; // To not pay the penalty of a write-through, we implement a write buffer we flush once it's full.
wire in_writebuffer;

assign in_writebuffer = (i_addr == write_buffer.addr) & |write_buffer.hit;

always @(posedge i_clk)
  write_buffer.was_write <= i_wb_stb & i_we;

always @(posedge i_clk)
  if (i_wb_stb && i_we && cachable_addr)
  begin
    write_buffer.idx <= c_paddr_idx;
    write_buffer.data <= i_data;
    write_buffer.be <= i_be;
  end

always @(posedge i_clk)
  if (i_reset)
    write_buffer.hit <= 'h0;
  else if (write_buffer.was_write)
    write_buffer.hit <= way_hit & {WAYS{i_wb_stb}};

always @(posedge i_clk)
  if (write_buffer.was_write && i_wb_stb) write_buffer.addr <= i_addr;


// Cachability (memory mapped IOs exclusion)
wire cachable_addr;
is_cachable #(
  .BANK_1_CACHABLE(BANK_1_CACHABLE),
  .BANK_2_CACHABLE(BANK_2_CACHABLE),
  .BANK_3_CACHABLE(BANK_3_CACHABLE),
  .BANK_4_CACHABLE(BANK_4_CACHABLE),
  .BANK_5_CACHABLE(BANK_4_CACHABLE)
) check_address(i_addr, cachable_addr);

// Tag management interface using BRAMs.
reg tag_stb;
wire tag_stall, tag_ack;
reg [IDX_BITS-1:0] tag_idx, tag_idx_dly, tag_dirty_write_idx;
logic [WAYS-1:0] way_hit; // We are forced to pack the array, otherwise we get an error at compilation.
tag_struct tag_out[WAYS-1:0];
tag_struct tag_in[WAYS-1:0];
reg [WAYS-1:0] tag_we, tag_we_dirty;
reg [WAYS-1:0][SETS-1:0] tag_valid;
reg [IDX_BITS-1:0] tag_byp_idx[WAYS];
reg [TAG_BITS-1:0] tag_byp_tag[WAYS];

always @(posedge i_clk)
  tag_idx_dly <= tag_idx;

wire cache_hit;
output reg [XLEN-1:0] o_cache_hits, o_cache_misses; // There can be at most 2^32 cache hits, cache misses.

initial o_cache_hits = 32'b0;
initial o_cache_misses = 32'b0;

always @(posedge i_clk)
if (i_reset)
begin
  o_cache_hits <= 32'b0;
  o_cache_misses <= 32'b0;
end
else if ((cache_hit)&&(o_wb_ack))
  o_cache_hits <= o_cache_hits + 1;
else if ((!cache_hit)&&(o_wb_ack))
begin
  // FIXME: we shall ensure we have a pending request and we do not miscount.
  o_cache_misses <= o_cache_misses + 1;
end

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
wire [DATA_OFF_BITS-1:0] c_data_offset;

assign c_tag = i_addr[XLEN-1 -: TAG_BITS];
assign c_paddr_idx = i_addr[BLK_OFF_BITS +: IDX_BITS];
assign c_data_offset = i_addr[BLK_OFF_BITS-1 -: DATA_OFF_BITS];

always_comb
  unique case (mem_state)
    default: tag_idx = c_paddr_idx;
  endcase


genvar way;
generate
  for (way = 0; way < WAYS ; way++)
  begin: gen_ways_tag
    // Place block RAM for tags
    block_ram #(
      .AW(IDX_BITS),
      .DW(TAG_BITS),
      .LGMEMSZ(IDX_BITS) // idx_bits entries. FIXME(Ryan): this is a suboptimal way to setup the block ram but it requires rewrite of the parameters.
    ) tag_ram(
      .i_clk(i_clk),
      .i_reset(i_reset),
      .i_addr(tag_idx),
      .i_wb_we(tag_we[way]),
      .i_wb_sel({(TAG_BITS+7)/8{1'b1}}),
      .i_data(tag_in[way].tag),
      .o_wb_data(tag_out[way].tag),
      .i_wb_stb(tag_stb),
      .o_wb_stall(tag_stall),
      .o_wb_ack(tag_ack)
    );

    // Bypass: Prevent RAW hazard
    always @(posedge i_clk)
      if (tag_we[way])
      begin
        tag_byp_tag[way] <= tag_in[way].tag;
        tag_byp_idx[way] <= tag_idx;
      end

    always @(posedge i_clk)
      if (i_reset)
        tag_valid[way] <= 'h0;
      else if (tag_we[way])
        tag_valid[way][tag_idx] <= tag_in[way].valid;

    // FIXME: metastability issues can arise.
    assign tag_out[way].valid = tag_valid[way][tag_idx];

    // We hit only iff it's valid data *and* the tag is the proper one.
    assign way_hit[way] = tag_out[way].valid && (c_tag == (tag_idx_dly == tag_byp_idx[way] ? tag_byp_tag[way] : tag_out[way].tag));
    //assign way_stall[way] = tag_stall;
  end
endgenerate

// Stalling state of all ways.
//assign cache_ways_stall = & way_stall;

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_dat_we
    always_comb
      unique case (mem_state)
        FETCH_SINGLE: data_we[way] = fill_way_select[way] & i_mem_ack;
        WRITE_SINGLE: data_we[way] = fill_way_select[way];
        IDLE: data_we[way] = 1'b0;
      endcase
  end
endgenerate

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_tag_we
    always_comb
      unique case (mem_state)
        default: tag_we[way] = filling & fill_way_select[way] & i_mem_ack;
      endcase

    always_comb
      unique case (mem_state)
        IDLE: tag_we_dirty[way] = way_hit[way] & (i_wb_stb & i_we);
        default: tag_we_dirty[way] = (filling & fill_way_select[way] & i_mem_ack) |
        (flushing);
      endcase
  end
endgenerate

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_tag
    assign tag_in[way].valid = 1'b1;

    // FIXME: implement write
    always_comb
    unique case (i_mem_ack)
      1: tag_in[way].dirty = 1'b0;
      0: tag_in[way].dirty = 1'b0;
    endcase

    assign tag_in[way].tag = c_tag;
  end
endgenerate

always_comb
  unique case (mem_state)
    default: tag_dirty_write_idx = (i_wb_stb & i_we) ? write_buffer.idx : tag_idx;
  endcase

assign cache_hit = |way_hit;
// If we didn't cache hit, thus we missed.
// We enter in the FETCH_SINGLE state.

assign o_mem_addr = i_addr; // o_mem_addr should always be ready.
assign o_wb_err = i_mem_wb_err; // Memory system errors becomes data cache errors
// FIXME: handle the case when we are doing the load ourself and want to get
// more data directly.
assign o_mem_wb_be = {{(MW/8 - DW/8 + 1){1'b0}}, i_be};

always_comb
  unique case (i_mem_ack)
  1: data_in = o_mem_data;
  0: data_in = write_buffer.data;
  endcase


always @(posedge i_clk)
  unique case (mem_state)
    IDLE:
    begin
      if (o_wb_ack)
        o_wb_ack <= 1'b0;
      if (data_ack)
        data_stb <= 1'b0;

      if ((i_flush) && !(i_wb_stb && i_we))
      begin
        mem_state <= INVALIDATE;
        flushing <= 1'b1;
      end
      else if ((i_wb_stb) && (!cache_hit) && (cachable_addr) && (!i_we)) // Cache miss, we shall fetch and cache.
      begin
        if (tag_out[onehot2int(fill_way_select)].valid && tag_out[onehot2int(fill_way_select)].dirty)
        begin
          // Flush the writes on this line, then refill.
          // TODO
        end
        else
        begin
          mem_state <= FETCH_SINGLE;
          filling <= 1'b1;
          tag_stb <= 1'b1; // Write the tag.
          o_mem_wb_stb <= 1'b1; // Run a transaction to the memory system.
        end
      end
      else if ((i_wb_stb) && (!cache_hit) && (cachable_addr) && (i_we)) // Cache miss on a write, we write in the pwb, then, write a tag and data, and mark it as dirty, so that it can get evicted properly.
      begin
        if (tag_out[onehot2int(fill_way_select)].valid && tag_out[onehot2int(fill_way_select)].dirty)
        begin
        end
        else
        begin
          mem_state <= WRITE_SINGLE;
          tag_stb <= 1'b1; // Write the tag.
        end
      end
      else if ((i_wb_stb) && (!cache_hit) && !cachable_addr) // An "always" cache miss situation, we shall fetch without flushing our writes
      begin
        mem_state <= UNCACHABLE;
        o_mem_wb_stb <= 1'b1;
      end
    end
    UNCACHABLE:
      if (i_mem_wb_err)
      begin
      end
      else if (i_mem_ack)
      begin
        o_mem_wb_stb <= 1'b0;
        o_wb_ack <= 1'b1;
        mem_state <= IDLE;
      end
    FETCH_SINGLE:
    begin
      if (tag_ack)
        tag_stb <= 1'b0;

      if (i_mem_wb_err)
      begin
        // FIXME: how to deal with memory system errors?
      end
      else if (i_mem_ack)
      begin
        o_mem_wb_stb <= 1'b0;
        data_stb <= 1'b1;
        o_wb_ack <= 1'b1;
        filling <= 1'b0;
        mem_state <= IDLE; // FIXME: really?
      end
    end
    WRITE_SINGLE:
    begin
      if (tag_ack)
        tag_stb <= 1'b0;

      data_stb <= 1'b1;
      o_wb_ack <= 1'b1; // too fast, we should ack later, so that in_writebuffer can give the answer.
      mem_state <= IDLE;
    end
  endcase
// We enter in the REFILL state to refi

wire [IDX_BITS-1:0] data_idx;
reg [BLK_BITS-1:0] data_in;
reg data_we[WAYS-1:0];
reg data_stb;
wire data_stall, data_ack;
wire [BLK_BITS/8-1:0] data_be;
wire [BLK_BITS-1:0] data_out[WAYS-1:0];

wire [BLK_BITS-1:0] way_acc_mux[WAYS-1:0];
wire [DW-1:0] way_acc;

assign data_idx = c_paddr_idx;

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_ways_data
    // Place block RAM for data
    block_ram #(
      .AW(IDX_BITS),
      .DW(BLK_BITS),
      .LGMEMSZ(IDX_BITS)
    ) data_ram(
      .i_clk(i_clk),
      .i_reset(i_reset),
      .i_addr(data_idx),
      .i_wb_we(data_we[way]),
      .i_wb_sel(data_be),
      .i_data(data_in),
      .o_wb_data(data_out[way]),
      .i_wb_stb(data_stb),
      .o_wb_stall(data_stall),
      .o_wb_ack(data_ack)
    );

    if (way == 0)
      assign way_acc_mux[way] = data_out[way] & {BLK_BITS{way_hit[way]}}; // Null the result if it's not the way we hitted.
    else
      assign way_acc_mux[way] = data_out[way] & {BLK_BITS{way_hit[way]}} | way_acc_mux[way - 1]; // Or the last result (which might be the good) with this one which might be the good one.
  end
endgenerate

wire [DATA_OFF_BITS-1:0] pwb_data_offset;
assign pwb_data_offset =  (write_buffer.was_write && i_wb_stb) ? c_data_offset : write_buffer.addr[BLK_OFF_BITS-1 -: DATA_OFF_BITS];

assign data_be = i_mem_ack ? {BLK_BITS/8{1'b1}} : write_buffer.be << (pwb_data_offset * DW/8);
assign way_acc = way_acc_mux[WAYS-1] >> (c_data_offset * DW); // Take the final result over all ways, then extract the value.
assign o_data = in_writebuffer ? be_mux(write_buffer.be, way_acc, write_buffer.data) : way_acc; // FIXME: shortcut this logic by checking if we have the result in a response of the upstream bus.

wire should_buffer_write; // This control write buffer behavior vs write through.
assign should_buffer_write = write_buffer.was_write && cachable_addr; // If it's not a cachable addr, it's not useful to try to cache it.

function automatic integer onehot2int;
  input [WAYS-1:0] a;

  integer i;

  onehot2int = 0;

  for (i=0; i<WAYS; i++)
    if (a[i]) onehot2int = i;
endfunction: onehot2int

function automatic [DW-1:0] be_mux;
  input [DW/8-1:0] be;
  input [DW-1:0] old;
  input [DW-1:0] new_;

  integer i;
  for (i = 0; i < DW/8 ; i++)
    be_mux[i*8 +: 8] = be[i] ? new_[i*8 +: 8] : old[i*8 +: 8];
endfunction: be_mux
endmodule
