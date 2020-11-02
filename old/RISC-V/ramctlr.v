module ramctlr(adress_out, data_in, enable_write, data_out, clk);
  parameter integer RAM_SIZE = 64; //64 32-bit words
  parameter RAM_FILE = "ram01";

  input [31:0] adress_out;
  input [31:0] data_out;

  output reg [31:0] data_in = 21'b0; //le in est du pdv du core

  input enable_write;
  input clk;

  reg [31:0] RAM [0:RAM_SIZE - 1];

  initial
    begin
      $readmemb(RAM_FILE, RAM);
    end

  always @(posedge clk)
    begin
      if(enable_write)
        begin
          RAM[adress_out] = data_out;
        end
      data_in <= RAM[adress_out];
    end
endmodule
