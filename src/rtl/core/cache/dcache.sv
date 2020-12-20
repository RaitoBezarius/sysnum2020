`default_nettype none

module dcache #(
  parameter XLEN = 32,
  parameter SIZE = 64, // kb.
  parameter BLOCK_SIZE = XLEN,
  parameter WAYS = 2 // associativity.
)
(
  i_clk, i_reset, i_clear,
  i_stb, i_op, i_addr, i_data,
  o_busy
);

localparam PAGE_SIZE = 4*1024; // 4kb.
localparam MAX_IDX_BITS = $clog2(PAGE_SIZE) - $clog2(BLOCK_SIZE); // log_2(page_size / block_size)
localparam SETS = (SIZE*1024) / BLOCK_SIZE / WAYS;
localparam BLK_OFF_BITS = $clog2(BLOCK_SIZE); // Number of BlockOffset bits
localparam IDX_BITS = $clog2(SETS); // Number of Index bits

localparam [1:0] DC_IDLE = 2'b00;
localparam [1:0] DC_WRITE = 2'b01;
localparam [1:0] DC_READS = 2'b10; // Read a single value cached
localparam [1:0] DC_READM = 2'b11; // Read a whole cache line

enum logic [1:0] {DC_IDLE, DC_WRITE, DC_READS, DC_REAM} state; // Cache FSM state.

typedef struct {
  logic valid;
  logic dirty;
  logic [TAG_BITS-1:0] tag;
} tag_struct;
localparam TAG_STRUCT_BITS = $bits(tag_struct);

input wire i_clk, i_reset, i_clear;
// CPU interface
input wire [2:0] i_op; // Operations: 0X is a read, 1X is a write.
input wire [(XLEN-1):0] i_addr; // Target address.
input wire [(XLEN-1):0] i_data; // For the cache writes.
// input wire [(NAUX-1):0] i_oreg; // For memory-mapped registers, output register to write to.

output reg o_busy;
output reg o_pipe_stalled;
output reg o_valid, o_err;
// output reg [(NAUX-1):0] o_wreg;
output reg [(XLEN-1):0] o_data;

// Wishbone master interface
output wire o_wb_cyc;
output reg o_wb_stb;
output reg o_wb_we;
output reg [(XLEN-1):0] o_wb_addr;
output reg [(XLEN-1):0] o_wb_data;
output reg [(XLEN/8-1):0] o_wb_sel;

// Wishbone slave interface
input wire i_wb_stall, i_wb_ack, i_wb_err;
input wire [(XLEN-1):0] i_wb_data;

// Cache
tag_struct tag_in[WAYS];
logic cache_hit;


always @(posedge i_clk)
end
