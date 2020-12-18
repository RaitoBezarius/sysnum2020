
`default_nettype none

`include "riscv.v"

module testbed();

// Clock

reg clk;

initial clk = 1;

always begin
	#1 clk <= ~clk;
end

// RAM (unused atm)

wire [31:0] ram_read_addr;
wire [31:0] ram_write_addr;
wire        ram_write_enable;
wire [31:0] ram_data_in;
wire [31:0] ram_data_out;

reg [31:0] RAM [31:0];

assign ram_data_out = RAM[ram_read_addr];

always @(posedge clk) begin
    if (ram_write_enable) begin
        RAM[ram_write_addr] <= ram_data_in;
    end
end

// ROM

wire [31:0] rom_addr;
wire [31:0] rom_out;

reg [7:0] ROM [511:0];
wire [31:0] base_addr;

initial $readmemh("test.elf", ROM);

assign base_addr = {rom_addr[31:2], 2'b00};

assign rom_out = {
        ROM[base_addr + 3],
        ROM[base_addr + 2],
        ROM[base_addr + 1],
        ROM[base_addr]
};

always @(posedge clk) begin
    if(rom_addr[1:0] != 2'b00) begin
		$display("Misaligned ROM address !");
		$finish;
	end
end

// Firmware ROM
// TODO: Make it as small as possible !

wire [31:0] fw_rom_addr;
wire [31:0] fw_rom_out;

reg [7:0] FW_ROM [511:0];
wire [31:0] fw_base_addr;

initial $readmemh("firmware.elf", FW_ROM);

assign fw_base_addr = {fw_rom_addr[31:2], 2'b00};

assign fw_rom_out = {
        FW_ROM[fw_base_addr + 3],
        FW_ROM[fw_base_addr + 2],
        FW_ROM[fw_base_addr + 1],
        FW_ROM[fw_base_addr]
};

always @(posedge clk) begin
	if(fw_rom_addr[1:0] != 2'b00) begin
        $display("Misaligned firmware ROM address !");
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

    fw_rom_addr,
    fw_rom_out,
);

// Simulation setup

initial begin
	#300 $finish;
end

endmodule

