module romctlr(adress_out, data_in, clk);
  parameter integer ROM_SIZE = 128; //128 32-bit words
  parameter ROM_FILE = "rom02";

  input [31:0] adress_out;

  output reg [31:0] data_in = 21'b0;

  input clk;

  reg [31:0] ROM [0:ROM_SIZE - 1];

  initial
    begin
      $readmemb(ROM_FILE, ROM);
    end

  always @(posedge clk)
    begin
      data_in <= ROM[adress_out];
    end
endmodule
