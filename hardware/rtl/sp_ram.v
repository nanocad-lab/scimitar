`timescale 1ns / 1ps

module sp_ram
(
   clk,
   we,
   ce,
   data,
   addr,
   q
);

////////////////////////////////////////
// Params
parameter DATA_WIDTH = 8 ;
parameter RAM_DEPTH  = 2 ;
// This will break if RAM_DEPTH==1
parameter ADDR_WIDTH = $clog2(RAM_DEPTH);

////////////////////////////////////////
// Inputs
input                   clk;
input                   we;
input                   ce;
input [DATA_WIDTH-1:0]  data;
input [ADDR_WIDTH-1:0] addr;
////////////////////////////////////////
// Outputs
output [DATA_WIDTH-1:0] q;

////////////////////////////////////////
// Wires/registers 
// SRAM array
reg [DATA_WIDTH-1:0] ram_arr[RAM_DEPTH-1:0];
//  
reg [ADDR_WIDTH-1:0] addr_reg;
reg                  ce_reg;

////////////////////////////////////////
// Logic 
// Write/address register
always @ (posedge clk)
begin : RAM_BEHAV
   // Write
   if (ce) begin
      if (we) begin
         ram_arr[addr] <= data;
      end
      addr_reg <= addr;
   end
   ce_reg   <= ce;
end

// Read logic
assign q = ce_reg ? ram_arr[addr_reg] : 0;

endmodule
