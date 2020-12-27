`default_nettype none

`include "core/cache/is_cachable.sv"

module dcache #(
  parameter XLEN = 32,
  parameter W = XLEN,
  parameter PLEN = XLEN,
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

output reg o_wb_stall;
output reg [DW-1:0] o_data;
output reg o_wb_ack, o_wb_err;

// Memory system interface
input wire i_mem_ack, i_mem_stall, i_mem_wb_err;
output reg [AW-1:0] o_mem_addr;
input wire [MW-1:0] i_mem_data;
output reg [MW-1:0] o_mem_data;
output reg o_mem_wb_stb;
output reg o_mem_wb_we;
output wire [MW/8-1:0] o_mem_wb_be;

localparam PAGE_SIZE = 4*1024; // 4kb.
localparam MAX_IDX_BITS = $clog2(PAGE_SIZE) - $clog2(BLOCK_SIZE); // log_2(page_size / block_size)
localparam SETS = (SIZE*1024) / BLOCK_SIZE / WAYS;
localparam BLK_OFF_BITS = $clog2(BLOCK_SIZE); // Number of BlockOffset bits
localparam IDX_BITS = $clog2(SETS); // Number of Index bits
localparam TAG_BITS = XLEN - IDX_BITS - BLK_OFF_BITS; // Number of tag bits.
localparam BLK_BITS = 8*BLOCK_SIZE; // Number of bits in a block
localparam DATA_OFF_BITS = $clog2(BLK_BITS) - $clog2(DW); // Byte offset in a given block
localparam BURST_SIZE = BLK_BITS / XLEN;
localparam BURST_BITS = $clog2(BURST_SIZE);

/* States */
logic flushing, filling;
enum logic [3:0] {ARMED, FLUSH, FLUSH_WAYS, WAIT_FOR_MEM_SYSTEM, READ_TAG} mem_state;
enum logic [3:0] {IDLE, WAIT_FOR_BUS, BURST} bus_state;
enum logic [3:0] {NOP, DIRECT_READ, DIRECT_WRITE, READ_WAY, WRITE_WAY} bus_cmd;

reg [BLK_BITS-1:0] mem_buffer;
reg [BURST_SIZE-1:0] mem_buffer_valid;
reg [DW-1:0] mem_q, mem_data_dly;
reg [DW/8-1:0] mem_be_dly;
reg mem_we_hold;
reg mem_buffer_ack;
reg [AW-1:0] mem_addr_hold, mem_addr;
reg mem_buffer_dirty;
reg mem_preq_dly, mem_we_dly;
reg [BURST_BITS-1:0] burst_cnt;

always @(posedge i_clk)
  if (i_reset) mem_preq_dly <= 'b0;
  else mem_preq_dly <= (i_wb_stb | mem_preq_dly) & ~o_wb_ack;

always @(posedge i_clk)
  if (i_reset) begin
    mem_we_dly <= 'b0;
    mem_be_dly <= 'hx;
  end
  else if (i_wb_stb) begin
    mem_we_dly <= i_we;
    mem_be_dly <= i_be;
    mem_data_dly <= i_data;
  end

initial mem_state = ARMED;
initial bus_state = IDLE;
initial bus_cmd = NOP;

typedef struct packed {
  logic [IDX_BITS - 1:0] idx;
  logic [AW - 1: 0] addr; // it must be a physical address here.
  logic [DW/8 - 1:0] be; // byte enable.
  logic [DW - 1:0] data;

  // private signals
  logic [WAYS - 1:0] hit;
  logic was_write;
} pipeline_write_buffer_t;

// Eviction buffer for sending back to memory system
typedef struct packed {
  logic [PLEN-1:0] addr;
  logic [BLK_BITS-1:0] data;
} evict_buffer_t;

typedef struct packed {
  logic valid;
  logic dirty;
  logic [TAG_BITS-1:0] tag;
} tag_struct;
localparam TAG_STRUCT_BITS = $bits(tag_struct);

evict_buffer_t evict_buffer;
pipeline_write_buffer_t write_buffer; // To not pay the penalty of a write-through, we implement a write buffer we flush once it's full.
wire in_writebuffer;

assign in_writebuffer = (i_addr == write_buffer.addr) & |write_buffer.hit;

always @(posedge i_clk)
  write_buffer.was_write <= i_wb_stb & i_we;

always @(posedge i_clk)
  if ((i_wb_stb) && (i_we) && (cachable_addr))
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
  else if (data_we_enable)
    write_buffer.hit <= 'h0;

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
wire tag_stb;
wire tag_stall, tag_ack;
reg [IDX_BITS-1:0] tag_idx, tag_idx_dly, tag_idx_hold, tag_dirty_write_idx;
logic [WAYS-1:0] way_hit; // We are forced to pack the array, otherwise we get an error at compilation
reg [WAYS-1:0] way_dirty;
tag_struct tag_out[WAYS-1:0];
tag_struct tag_in[WAYS-1:0];
reg [WAYS-1:0] tag_we, tag_we_dirty;
reg [WAYS-1:0][SETS-1:0] tag_valid;
reg [WAYS-1:0][SETS-1:0] tag_dirty;
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
reg [WAYS-1:0] fill_way_select_hold;
initial way_random = 'h0;
always @(posedge i_clk)
  if (!filling) way_random <= {way_random, way_random[19] ~^ way_random[16]}; // LFSR for apparent randomness.

assign fill_way_select = (WAYS == 1) ? 1 : 1 << way_random[$clog2(WAYS)-1:0];

always @(posedge i_clk)
  unique case (mem_state)
    ARMED: fill_way_select_hold <= fill_way_select;
    default: ;
  endcase

// Extract tag from address.
wire [TAG_BITS-1:0] c_tag;
wire [IDX_BITS-1:0] c_paddr_idx; // Physical index.
reg [IDX_BITS-1:0] c_paddr_idx_dly;
wire [DATA_OFF_BITS-1:0] c_data_offset;

assign c_tag = i_addr[XLEN-1 -: TAG_BITS];
assign c_paddr_idx = i_addr[BLK_OFF_BITS +: IDX_BITS];
assign c_data_offset = i_addr[BLK_OFF_BITS-1 -: DATA_OFF_BITS];

always @(posedge i_clk)
  c_paddr_idx_dly <= c_paddr_idx;

always @(posedge i_clk)
  unique case (mem_state)
    ARMED: if (mem_preq_dly && !cache_hit) tag_idx_hold <= c_paddr_idx_dly;
    READ_TAG: tag_idx_hold <= mem_preq_dly ? c_paddr_idx_dly : c_paddr_idx;
    default: ;
  endcase

always_comb
  unique case (mem_state)
    WAIT_FOR_MEM_SYSTEM: tag_idx = tag_idx_hold;
    READ_TAG: tag_idx = mem_preq_dly ? c_paddr_idx_dly : c_paddr_idx;
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

    assign tag_out[way].valid = tag_valid[way][tag_idx_dly];

    always @(posedge i_clk)
      if (i_reset)
        tag_dirty[way] <= 'h0;
      else if (tag_we_dirty[way])
        tag_dirty[way][tag_dirty_write_idx] <= tag_in[way].dirty;

    assign tag_out[way].dirty = tag_dirty[way][tag_idx_dly];
    assign way_dirty[way] = tag_out[way].dirty;

    // We hit only iff it's valid data *and* the tag is the proper one.
    assign way_hit[way] = tag_out[way].valid & (c_tag == (tag_idx_dly == tag_byp_idx[way] ? tag_byp_tag[way] : tag_out[way].tag));
    //assign way_stall[way] = tag_stall;
  end
endgenerate

// Stalling state of all ways.
//assign cache_ways_stall = & way_stall;

wire data_we_enable;
assign data_we_enable = 1'b1; // Always true. TODO: MMU.

assign tag_stb = 1'b1; // Hardwire the strobe.
assign data_stb = 1'b1; // |data_we; // Hardwire the strobe.

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_data_we
    always_comb
      unique case (mem_state)
        // We write in the DATA Block RAM if we received the complete block
        // from the memory system and have selected this exact way.
        WAIT_FOR_MEM_SYSTEM: begin
          data_we[way] = fill_way_select[way] & mem_buffer_ack;
          if (data_we[way])
            $display("[Memory system] Local data write performed on way: %d", way);
        end
        READ_TAG: begin
          data_we[way] = 1'b0;
        end
        default: begin
          if (mem_preq_dly && mem_we_dly)
          begin
            if (!way_hit[way])
              $display("[%d] Previous cycle was a write, but this way has not been a hit: %d", mem_state, way);
            else
              $display("[%d] Previous cycle was a write and this way has been hit: %d", mem_state, way);
          end
          data_we[way] = data_we_enable &
          ((write_buffer.was_write && i_wb_stb) || (mem_preq_dly && mem_we_dly) ? way_hit[way] : write_buffer.hit[way]);
        end
      endcase
  end
endgenerate

// Tag updates
generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_way_we
    always_comb
      unique case (mem_state)
        // In general, we write in the TAG Block RAM if we are
        // - filling
        // - want to write into this particular way
        // - have received all the data from our memory system
        default:
          begin
            tag_we[way] = filling & fill_way_select[way] & mem_buffer_ack;
          end
      endcase

    always_comb
      unique case (mem_state)
        // We mark our tag as dirty if we hitted it *and* we have written to
        // it. Basically, modifying an existing element of the cache.
        ARMED: tag_we_dirty[way] = way_hit[way] & (i_wb_stb & i_we);
        default: tag_we_dirty[way] = (filling & fill_way_select[way] & mem_buffer_ack);
      endcase
  end
endgenerate

generate
  for (way = 0 ; way < WAYS ; way++)
  begin: gen_tag
    assign tag_in[way].valid = 1'b1;

    always_comb
    unique case (mem_buffer_ack)
      1: tag_in[way].dirty = mem_buffer_dirty | (mem_we_dly & mem_addr_eq_cache_addr_dly);
      0: tag_in[way].dirty = ~flushing & mem_we_dly;
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

assign o_wb_err = i_mem_wb_err; // Memory system errors becomes data cache errors
// FIXME: handle the case when we are doing the load ourself and want to get
// more data directly.
assign o_mem_wb_be = 4'b1111;

always_comb
  unique case (mem_buffer_ack)
  1: begin
    data_in = mem_buffer; // Write the buffer at the right place.
  end
  0: begin
    data_in = {BURST_SIZE{write_buffer.data}};
  end
  endcase

always @(posedge i_clk)
  unique case (mem_state)
    ARMED:
      if ((i_flush) && !(i_wb_stb && i_we))
      begin
        mem_state <= FLUSH;
        flushing <= 1'b1;
      end
      else if ((i_wb_stb) && (!cache_hit) && (cachable_addr)) // Cache miss: let us fetch something from the main memory, even if it is a write.
      begin
        mem_state <= WAIT_FOR_MEM_SYSTEM;
        filling <= 1'b1;
        bus_cmd <= READ_WAY;
      end
      else if ((i_wb_stb) && (!cache_hit) && (!cachable_addr)) // An "always" cache miss situation, we shall fetch without flushing our writes
      begin
        mem_state <= WAIT_FOR_MEM_SYSTEM;
        bus_cmd <= i_we ? DIRECT_WRITE : DIRECT_READ;
      end
      else
        bus_cmd <= NOP;
    WAIT_FOR_MEM_SYSTEM:
      if (i_mem_wb_err)
      begin
        // FIXME: how to deal with memory system errors?
      end
      else if (mem_buffer_ack)
      begin
        filling <= 1'b0;
        mem_state <= (mem_preq_dly && mem_we_dly) ? READ_TAG : ARMED;
        // Selected way was valid *and* dirty, we should write back to memory system
        if (tag_out[onehot2int(fill_way_select_hold)].valid && tag_out[onehot2int(fill_way_select_hold)].dirty) 
          bus_cmd <= WRITE_WAY;
        else
          bus_cmd <= NOP;
      end
    READ_TAG:
    begin
      mem_state <= ARMED;
      bus_cmd <= NOP;
      filling <= 1'b0;
    end
  endcase


reg [IDX_BITS-1:0] data_idx;
reg [BLK_BITS-1:0] data_in;
reg data_we[WAYS-1:0];
wire data_stb;
wire data_stall, data_ack;
wire [BLK_BITS/8-1:0] data_be;
wire [BLK_BITS-1:0] data_out[WAYS-1:0];

wire [BLK_BITS-1:0] way_acc_mux[WAYS-1:0];
wire [DW-1:0] way_acc;

always_comb
  unique case (mem_state)
    ARMED: data_idx = data_we_enable ? write_buffer.idx : c_paddr_idx;
    READ_TAG: data_idx = mem_preq_dly ? c_paddr_idx_dly : c_paddr_idx;
    default: data_idx = tag_idx_hold;
  endcase

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
assign pwb_data_offset =  (write_buffer.was_write && i_wb_stb) ? i_addr[BLK_OFF_BITS-1-:DATA_OFF_BITS] : write_buffer.addr[BLK_OFF_BITS-1 -: DATA_OFF_BITS];

assign data_be = mem_buffer_ack ? {BLK_BITS/8{1'b1}} : write_buffer.be << (pwb_data_offset * DW/8);
assign way_acc = way_acc_mux[WAYS-1] >> (c_data_offset * DW); // Take the final result over all ways, then extract the value.
wire [DW-1:0] cache_data;
assign cache_data = in_writebuffer ? be_mux(write_buffer.be, way_acc, write_buffer.data) : way_acc; // FIXME: shortcut this logic by checking if we have the result in a response of the upstream bus.

always_comb
  unique case (mem_state)
    WAIT_FOR_MEM_SYSTEM: o_data = i_mem_data;
    default: o_data = cache_data;
  endcase

wire should_buffer_write; // This control write buffer behavior vs write through.
assign should_buffer_write = write_buffer.was_write && cachable_addr; // If it's not a cachable addr, it's not useful to try to cache it.

always_comb
  unique case (mem_state)
  ARMED: o_wb_ack = cache_hit & (i_wb_stb | mem_preq_dly);
  WAIT_FOR_MEM_SYSTEM: o_wb_ack = i_mem_ack & mem_addr_eq_cache_addr_dly;
  default: o_wb_ack = 1'b0;
endcase

always @(posedge i_clk)
  if (i_reset)
    bus_state <= IDLE;
  else
  begin
    unique case (bus_state)
    IDLE: unique case (bus_cmd)
      NOP: ; // Do nothing
      READ_WAY: begin
        if (!i_mem_ack)
          o_wb_stall <= 1'b1;
        else if ((!i_mem_stall)&&(i_mem_ack))
          bus_state <= BURST;
        else if (i_mem_stall)
          bus_state <= WAIT_FOR_BUS;
      end
      WRITE_WAY: begin
        if (!i_mem_ack)
          o_wb_stall <= 1'b1;
        else if ((!i_mem_stall)&&(i_mem_ack))
          bus_state <= BURST;
        else if (i_mem_stall)
          bus_state <= WAIT_FOR_BUS;
      end
    endcase
    WAIT_FOR_BUS:
      if (!i_mem_stall)
        bus_state <= BURST;
      else if (i_mem_stall)
        o_wb_stall <= 1'b1;
    BURST:
      if (i_mem_wb_err || (~|burst_cnt && i_mem_ack))
      begin
        o_wb_stall <= 1'b0;
        bus_state <= IDLE;
      end
    endcase
  end

always_comb
  unique case (bus_state)
  IDLE: unique case (bus_cmd)
    NOP: begin
      o_mem_wb_stb = 1'b0;
      o_mem_wb_we = 1'bx;
      o_mem_addr = 'hx;
      o_mem_data = 'hx;
    end

    READ_WAY: begin
      o_mem_wb_stb = 1'b1;
      o_mem_wb_we = 1'b0;
      o_mem_addr = mem_addr;
      o_mem_data = 'hx;
    end

    DIRECT_READ: begin
      o_mem_wb_stb = 1'b1;
      o_mem_wb_we = 1'b0;
      o_mem_addr = i_addr;
      o_mem_data = 'hx;
    end

    DIRECT_WRITE: begin
      o_mem_wb_stb = 1'b1;
      o_mem_wb_we = 1'b1;
      o_mem_addr = i_addr;
      o_mem_data = i_data;
    end

    WRITE_WAY: begin
      o_mem_wb_stb = 1'b1;
      o_mem_wb_we = 1'b1;
      o_mem_addr = evict_buffer.addr;
      o_mem_data = evict_buffer.data[XLEN-1:0]; // Send XLEN chunks.
    end
  endcase
  WAIT_FOR_BUS: begin
    o_mem_wb_stb = 1'b1;
    o_mem_wb_we = mem_we_hold;
    o_mem_addr = mem_addr_hold;
    o_mem_data = evict_buffer.data[XLEN-1:0];
  end
  BURST: begin
    o_mem_wb_stb = 1'b1;
    o_mem_wb_we = mem_we_hold;
    o_mem_addr = mem_addr;
    o_mem_data = mem_buffer[0 +: XLEN]; // Provide the whole buffer.
    if (mem_we_hold)
      $display("Material burst *WRITE*: %h (%d) → %d", o_mem_addr, ~burst_cnt, o_mem_data);
    else
      $display("Material burst *READ*: %h (%d)", o_mem_addr, ~burst_cnt);
  end
  default: begin
    o_mem_wb_stb = 1'b0;
    o_mem_wb_we = 1'bx;
    o_mem_addr = 'hx;
    o_mem_data = 'hx;
  end
endcase

// Mix the data we were supposed to write *AND* the data we are getting to
// ensure coherence.
assign mem_q = mem_we_dly && mem_addr_eq_cache_addr_dly ? be_mux(mem_be_dly, i_mem_data, mem_data_dly)
                                                        : i_mem_data;
always @(posedge i_clk)
  unique case (bus_state)
    IDLE: begin
      if (bus_cmd == WRITE_WAY)
        mem_buffer <= evict_buffer.data >> XLEN;

      mem_buffer_valid <= 'h0;
      mem_buffer_dirty <= 1'b0;
    end
    READ_WAY:
      if (i_mem_ack)
      begin
        $display("Reading a chunk of way (original addr: %h) -> %h", mem_addr, mem_q);
        mem_buffer[mem_addr[BLK_OFF_BITS - 1 -: DATA_OFF_BITS] * XLEN +: XLEN] <= mem_q;
        mem_buffer_valid[mem_addr[BLK_OFF_BITS-1-:DATA_OFF_BITS]] <= 1'b1;
        mem_buffer_dirty <= mem_buffer_dirty | (mem_we_dly & mem_addr_eq_cache_addr_dly);
      end
    WRITE_WAY:
      if (i_mem_ack)
      begin
        $display("Way flushed back: %h -> %h", mem_addr, mem_q);
      end
    BURST: begin
      if (!mem_we_hold)
      begin
        if (i_mem_ack)
        begin
          $display("Read ack (%h / %h) <- %h", mem_addr, mem_addr[BLK_OFF_BITS-1 -: DATA_OFF_BITS] * XLEN, mem_q);
          mem_buffer[mem_addr[BLK_OFF_BITS - 1 -: DATA_OFF_BITS] * XLEN +: XLEN] <= mem_q;
          mem_buffer_valid[mem_addr[BLK_OFF_BITS - 1 -: DATA_OFF_BITS]] <= 1'b1;
          mem_buffer_dirty <= mem_buffer_dirty | (mem_we_dly & mem_addr_eq_cache_addr_dly);
        end
      end
      else
      begin
        $display("We are writing data.");
        if (i_mem_ack)
        begin
          $display("Write ack.");
          mem_buffer <= mem_buffer >> XLEN;
          mem_buffer_valid <= 'h0;
          mem_buffer_dirty <= 1'b0;
        end
      end
    end
    default: ;
  endcase

always_comb
  unique case (bus_state)
    READ_WAY: mem_buffer_ack = i_mem_ack;
    BURST: mem_buffer_ack = (~|burst_cnt & i_mem_ack & (~mem_we_hold | flushing)) | i_mem_wb_err;
    default: mem_buffer_ack = 1'b0;
  endcase

always @(posedge i_clk)
  unique case (bus_state)
    IDLE: case (bus_cmd)
      READ_WAY: burst_cnt <= {BURST_BITS{1'b1}};
      WRITE_WAY: burst_cnt <= {BURST_BITS{1'b1}};
    endcase
    BURST: if (i_mem_ack) burst_cnt <= burst_cnt - 1;
  endcase

always @(posedge i_clk)
  if (bus_state == IDLE)
  begin
    mem_we_hold <= i_we;
    mem_addr_hold <= i_addr;
    mem_addr <= i_addr;
  end
  else if (bus_state == BURST)
    mem_addr <= mem_addr + 4; // Move forward the memory address

wire mem_addr_eq_cache_addr_dly;
assign mem_addr_eq_cache_addr_dly = (o_mem_addr == mem_addr);

// Eviction requests mechanisms
reg prepare_evict, prepare_evict_dly;
always @(posedge i_clk)
  prepare_evict <= (bus_cmd == READ_WAY);
always @(posedge i_clk)
  prepare_evict_dly <= prepare_evict;

wire write_in_evict_buf;
assign write_in_evict_buf = prepare_evict & ~prepare_evict_dly;

always @(posedge i_clk)
if (write_in_evict_buf)
begin
  evict_buffer.addr <= {tag_out[onehot2int(fill_way_select_hold)].tag, c_paddr_idx_dly, {BLK_OFF_BITS{1'b0}}};
  evict_buffer.data <= data_out[onehot2int(fill_way_select_hold)];
end



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
