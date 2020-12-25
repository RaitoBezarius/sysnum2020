`default_nettype none

`include "core/memory/block_ram.sv"
// FIXME(Ryan): this is a work of horror
// explicit wires are there for the most easiest debugging possible

// This is basically a Wishbone master bus
// with many slaves.
// It's also itself a slave for caches or CPU.
//
// Bank 1 has 0.512GB: 0x00000000 - 0x20000000
// Bank 2 has 0.128GB: 0x20000000 - 0x28000000
// Bank 3 has 0.128GB: 0x28000000 - 0x30000000
// Bank 4 has 0.128GB: 0x30000000 - 0x38000000
// Bank 5 has 0.128GB: 0x38000000 - 0x40000000
// Bank 1 is generally considered as the RAM controller.
// We still have ~ 2.976GB of address space.

`define BANK_1_BOUNDARY 32'h20000000
`define BANK_2_BOUNDARY 32'h28000000
`define BANK_3_BOUNDARY 32'h30000000
`define BANK_4_BOUNDARY 32'h38000000
`define BANK_5_BOUNDARY 32'h40000000

module memory_system #(
  parameter XLEN = 32,
  parameter AW = XLEN,
  parameter MW = 64,
  parameter N_BUSES = 5,
  parameter BW = MW/8

  ) (i_clk, i_reset,
  i_rw_addr, i_data, i_be, i_we, i_rw_stb,
  o_rw_ack, o_rw_stall, o_rw_err, o_rw_data,
  o_rw_cyc,
  i_ro_addr, i_ro_stb,
  o_ro_ack, o_ro_stall, o_ro_err, o_ro_data,
  o_ro_cyc,
  // Slaves WB interface
  i_wbs1_data, o_wbs1_data, i_wbs1_ack, i_wbs1_stall,
  i_wbs1_err, o_wbs1_be, o_wbs1_stb, o_wbs1_we, o_wbs1_addr,
  i_wbs2_data, o_wbs2_data, i_wbs2_ack, i_wbs2_stall,
  i_wbs2_err, o_wbs2_be, o_wbs2_stb, o_wbs2_we, o_wbs2_addr,
  i_wbs3_data, o_wbs3_data, i_wbs3_ack, i_wbs3_stall,
  i_wbs3_err, o_wbs3_be, o_wbs3_stb, o_wbs3_we, o_wbs3_addr,
  i_wbs4_data, o_wbs4_data, i_wbs4_ack, i_wbs4_stall,
  i_wbs4_err, o_wbs4_be, o_wbs4_stb, o_wbs4_we, o_wbs4_addr,
  i_wbs5_data, o_wbs5_data, i_wbs5_ack, i_wbs5_stall,
  i_wbs5_err, o_wbs5_be, o_wbs5_stb, o_wbs5_we, o_wbs5_addr
);

localparam [AW-1:0] BOUNDARIES [4:0] = '{32'h0, `BANK_1_BOUNDARY, `BANK_2_BOUNDARY, `BANK_3_BOUNDARY, `BANK_4_BOUNDARY};

input wire i_clk, i_reset;

// Read-only ports (for L1i)
input wire i_ro_stb;
input wire [AW-1:0] i_ro_addr;
output wire o_ro_ack, o_ro_stall;
output reg o_ro_err;
output reg [MW-1:0] o_ro_data;
output reg o_ro_cyc;

// Read-write ports (for L1d)
input wire i_we, i_rw_stb;
input wire [MW-1:0] i_data;
input wire [AW-1:0] i_rw_addr;
input wire [BW-1:0] i_be;
output reg [MW-1:0] o_rw_data;
output reg o_rw_cyc;
output wire o_rw_ack, o_rw_stall;
output reg o_rw_err;

// Interfacing with slaves
// 5 sub-buses
input wire [(MW-1):0] i_wbs1_data;
output reg [(MW-1):0] o_wbs1_data;
output wire [(AW-1):0] o_wbs1_addr;
output reg [BW-1:0] o_wbs1_be;
input wire i_wbs1_ack, i_wbs1_stall, i_wbs1_err;
output wire o_wbs1_we;
output reg o_wbs1_stb;

input wire [(MW-1):0] i_wbs2_data;
output reg [(MW-1):0] o_wbs2_data;
output wire [(AW-1):0] o_wbs2_addr;
output reg [BW-1:0] o_wbs2_be;
input wire i_wbs2_ack, i_wbs2_stall, i_wbs2_err;
output wire o_wbs2_we;
output reg o_wbs2_stb;

input wire [(MW-1):0] i_wbs3_data;
output reg [(MW-1):0] o_wbs3_data;
output wire [(AW-1):0] o_wbs3_addr;
output reg [BW-1:0] o_wbs3_be;
input wire i_wbs3_ack, i_wbs3_stall, i_wbs3_err;
output wire o_wbs3_we;
output reg o_wbs3_stb;


input wire [(MW-1):0] i_wbs4_data;
output reg [(MW-1):0] o_wbs4_data;
output wire [(AW-1):0] o_wbs4_addr;
output reg [BW-1:0] o_wbs4_be;
input wire i_wbs4_ack, i_wbs4_stall, i_wbs4_err;
output wire o_wbs4_we;
output reg o_wbs4_stb;


input wire [(MW-1):0] i_wbs5_data;
output reg [(MW-1):0] o_wbs5_data;
output wire [(AW-1):0] o_wbs5_addr;
output reg [BW-1:0] o_wbs5_be;
input wire i_wbs5_ack, i_wbs5_stall, i_wbs5_err;
output wire o_wbs5_we;
output reg o_wbs5_stb;


wire [2:0] paddr_rw_sel, paddr_ro_sel;
wire paddr_rw_invalid, paddr_ro_invalid;

assign paddr_rw_sel = i_rw_addr < `BANK_1_BOUNDARY ? 1 :
  (i_rw_addr < `BANK_2_BOUNDARY ? 2 :
  (i_rw_addr < `BANK_3_BOUNDARY ? 3 :
  (i_rw_addr < `BANK_4_BOUNDARY ? 4 :
  (i_rw_addr < `BANK_5_BOUNDARY ? 5 : 0))));
assign paddr_ro_sel = i_ro_addr < `BANK_1_BOUNDARY ? 1 :
  (i_ro_addr < `BANK_2_BOUNDARY ? 2 :
  (i_ro_addr < `BANK_3_BOUNDARY ? 3 :
  (i_ro_addr < `BANK_4_BOUNDARY ? 4 :
  (i_ro_addr < `BANK_5_BOUNDARY ? 5 : 0))));

assign paddr_rw_invalid = paddr_rw_sel == 0;
assign paddr_ro_invalid = paddr_ro_sel == 0;

assign o_rw_stall = (paddr_rw_sel == 1 ? i_wbs1_stall :
  (paddr_rw_sel == 2 ? i_wbs2_stall :
  (paddr_rw_sel == 3 ? i_wbs3_stall :
  (paddr_rw_sel == 4 ? i_wbs4_stall :
  (paddr_rw_sel == 5 ? i_wbs5_stall : 1'b1))))); // We cannot accept requests, until the bus is known.

assign o_rw_err = (paddr_rw_sel == 1 ? i_wbs1_err :
  (paddr_rw_sel == 2 ? i_wbs2_err :
  (paddr_rw_sel == 3 ? i_wbs3_err :
  (paddr_rw_sel == 4 ? i_wbs4_err :
  (paddr_rw_sel == 5 ? i_wbs5_err : 1'b1)))));

assign o_ro_err = (paddr_ro_sel == 1 ? i_wbs1_err :
  (paddr_ro_sel == 2 ? i_wbs2_err :
  (paddr_ro_sel == 3 ? i_wbs3_err :
  (paddr_ro_sel == 4 ? i_wbs4_err :
  (paddr_ro_sel == 5 ? i_wbs5_err : 1'b1)))));

assign o_rw_ack = (paddr_rw_sel == 1 ? i_wbs1_ack :
  (paddr_rw_sel == 2 ? i_wbs2_ack :
  (paddr_rw_sel == 3 ? i_wbs3_ack :
  (paddr_rw_sel == 4 ? i_wbs4_ack :
  (paddr_rw_sel == 5 ? i_wbs5_ack : 1'b0)))));

assign o_ro_ack = (paddr_ro_sel == 1 ? i_wbs1_ack :
  (paddr_ro_sel == 2 ? i_wbs2_ack :
  (paddr_ro_sel == 3 ? i_wbs3_ack :
  (paddr_ro_sel == 4 ? i_wbs4_ack :
  (paddr_ro_sel == 5 ? i_wbs5_ack : 1'b0)))));


// There can only be rw who can write data.
assign o_wbs1_data = (paddr_rw_sel == 1) ? i_data : 'hx;
assign o_wbs2_data = (paddr_rw_sel == 2) ? i_data : 'hx;
assign o_wbs3_data = (paddr_rw_sel == 3) ? i_data : 'hx;
assign o_wbs4_data = (paddr_rw_sel == 4) ? i_data : 'hx;
assign o_wbs5_data = (paddr_rw_sel == 5) ? i_data : 'hx;

assign o_wbs1_we = (paddr_rw_sel == 'd1) ? i_we : 1'hx;
assign o_wbs2_we = (paddr_rw_sel == 'd2) ? i_we : 1'hx;
assign o_wbs3_we = (paddr_rw_sel == 'd3) ? i_we : 1'hx;
assign o_wbs4_we = (paddr_rw_sel == 'd4) ? i_we : 1'hx;
assign o_wbs5_we = (paddr_rw_sel == 'd5) ? i_we : 1'hx;

assign o_wbs1_be = (paddr_rw_sel == 'd1) ? i_be : 0;
assign o_wbs2_be = (paddr_rw_sel == 'd2) ? i_be : 0;
assign o_wbs3_be = (paddr_rw_sel == 'd3) ? i_be : 0;
assign o_wbs4_be = (paddr_rw_sel == 'd4) ? i_be : 0;
assign o_wbs5_be = (paddr_rw_sel == 'd5) ? i_be : 0;

// Arbiter: RW has a priority on RO.
// In case, D-cache and I-cache are flushed at the same time.
// We want that D-cache has priority over I-cache so that instructions can be
// modified if required.
assign o_wbs1_addr = get_addr(1);
assign o_wbs2_addr = get_addr(2);
assign o_wbs3_addr = get_addr(3);
assign o_wbs4_addr = get_addr(4);
assign o_wbs5_addr = get_addr(5);

wire sel_conflict;
assign sel_conflict = i_we && (paddr_rw_sel == paddr_ro_sel);

assign o_rw_data = (paddr_rw_sel == 1 ? i_wbs1_data :
  (paddr_rw_sel == 2 ? i_wbs2_data :
  (paddr_rw_sel == 3 ? i_wbs3_data :
  (paddr_rw_sel == 4 ? i_wbs4_data :
  (paddr_rw_sel == 5 ? i_wbs5_data : 'b0)))));

assign o_ro_data = (paddr_ro_sel == 1 ? i_wbs1_data :
  (paddr_ro_sel == 2 ? i_wbs2_data :
  (paddr_ro_sel == 3 ? i_wbs3_data :
  (paddr_ro_sel == 4 ? i_wbs4_data :
  (paddr_ro_sel == 5 ? i_wbs5_data : 'b0)))));

// FIXME(Ryan): formal verify this reasoning.
// basically, rw is working on bus 1
// then, ro wants to read bus 1, but it's already in progress (o_cyc ?)
// so, it has to wait and we signal it through stalling, we are not accepting
// a strobe.
// but also, we stall if our bus target is stalling itself.
wire target_ro_bus_stalling;
assign target_ro_bus_stalling = (paddr_ro_sel == 1 ? i_wbs1_stall :
  (paddr_ro_sel == 2 ? i_wbs2_stall :
  (paddr_ro_sel == 3 ? i_wbs3_stall :
  (paddr_ro_sel == 4 ? i_wbs4_stall :
  (paddr_ro_sel == 5 ? i_wbs5_stall : 1'b1))))); // We cannot accept requests, until the bus is known.

assign o_ro_stall = o_rw_cyc ? (sel_conflict && target_ro_bus_stalling) : target_ro_bus_stalling;

always @(posedge i_clk)
if ((o_rw_ack))
  o_rw_cyc <= 1'b0;

always @(posedge i_clk)
if ((o_ro_ack))
  o_ro_cyc <= 1'b0;

always @(posedge i_clk)
if ((i_rw_stb)&&(!o_rw_stall))
begin
  o_rw_cyc <= 1'b1;
  case (paddr_rw_sel)
    1:
      o_wbs1_stb <= i_rw_stb;
    2:
      o_wbs2_stb <= i_rw_stb;
    3:
      o_wbs3_stb <= i_rw_stb;
    4:
      o_wbs4_stb <= i_rw_stb;
    5:
      o_wbs5_stb <= i_rw_stb;
    default:
      o_rw_cyc <= 1'b0; // Cancel the assignment.
  endcase
end

always @(posedge i_clk)
if ((i_ro_stb)&&(!o_ro_stall))
begin
  o_ro_cyc <= 1'b1;
  case (paddr_ro_sel)
    1:
      o_wbs1_stb <= i_ro_stb;
    2:
      o_wbs2_stb <= i_ro_stb;
    3:
      o_wbs3_stb <= i_ro_stb;
    4:
      o_wbs4_stb <= i_ro_stb;
    5:
      o_wbs5_stb <= i_ro_stb;
    default:
      o_ro_cyc <= 1'b0;
  endcase
end

function automatic [(AW-1):0] get_addr;
  input [2:0] index;

  if (paddr_rw_sel == paddr_ro_sel && paddr_rw_sel == index)
    get_addr = i_rw_addr - BOUNDARIES[index];
  else
  begin
    if (paddr_rw_sel == index)
      get_addr = i_rw_addr - BOUNDARIES[index];
    else if (paddr_ro_sel == index)
      get_addr = i_ro_addr - BOUNDARIES[index];
    else
      get_addr = 'hx;
  end
endfunction: get_addr
endmodule

