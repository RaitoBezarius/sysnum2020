
`default_nettype none

`include "riscv.v"

module testbed();

// Clock

reg clk;

initial clk = 1;

always begin
	#1 clk <= ~clk;
end

// RAM

wire [31:0] ram_read_addr;
wire [31:0] ram_write_addr;
wire        ram_write_enable;
wire [31:0] ram_data_in;
wire [31:0] ram_data_out;

reg [31:0] RAM [31:0];

assign ram_data_out = RAM[ram_read_addr];

always @(posedge clk) begin
	if (ram_write_enable)
		RAM[ram_write_addr] <= ram_data_in;
end

wire [31:0] rom_addr;
wire [31:0] rom_out;

// ROM

reg [31:0] ROM [29:0];

initial $readmemb("rom.txt", ROM, 0, 3);

assign rom_out = ROM[rom_addr[31:2]];

always @(posedge clk) begin
	if(rom_addr[1:0] != 2'b00) begin
		$display("Misaligned ROM address !");
		$finish;
	end
end

// Processor

riscv soc(
	clk,

	ram_read_addr,
	ram_write_addr,
	ram_write_enable,
	ram_data_in,
	ram_data_out,

	rom_addr,
	rom_out,
);

// Simulation setup

initial begin
	#30 $finish;
end

endmodule

