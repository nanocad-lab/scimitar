//////////////////////////////////////////////////////////////////////////////
// The MIT License (MIT)
// 
// Copyright (c) 2022 UCLA NanoCAD Laboratory
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
/////////////////////////////////////////////////////////////////////////////
//
// Module name : output_mem
// Created     : Fri 23 Sep 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Output memory for ERIDA SCIM chip (MACLEOD)
//               
/////////////////////////////////////////////////////////////////////////////
// WJR: Macro control signals


`timescale 1ns / 1ps


////////////////////////////////////////
// Includes
////////////////////////////////////////

`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"


////////////////////////////////////////
// Top Module Definition
////////////////////////////////////////

module output_mem(
   input  wire                         clk,     // I: Core clock
   input  wire                         reset_n, // I: Async reset active low
   // Memory interface
   input  wire [`OUT_MEM_BANKS-1:0]    ce,      // I: Chip enable
   input  wire                         we,      // I: Write enable
   input  wire                         jtag_wr, // I: JTAG write source
   input  wire [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] data,    // I: Write data
   input  wire [`OUT_MEM_DATA_WDT-1:0] jtag_data, // I: JTAG write data
   input  wire [`OUT_MEM_ADDR_WDT-1:0] addr,    // I: Address
   output reg  [`OUT_MEM_DATA_WDT-1:0] jtag_q,  // O: Read data (jtag)
   output reg                          rd_done  // O: Read done flag
);

// Registered muxing signals
reg  [`OUT_MEM_BANKS-1:0]  ce_r;
reg                        rd_r;

// Internal write data
reg  [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] data_int;    

// Internal read data
wire [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] q_int;    

// Mux write data between jtag/regular writes
integer k;
always @(*) begin : MUX_JTAG_WR
   data_int =  0;
   if (we == 1'b1) begin
      if (jtag_wr == 1'b1) begin
         for (k = 0; k < `ACT_MEM_BANKS; k = k + 1) begin
            if (ce[k] == 1'b1) begin
               data_int[k*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT] = jtag_data;
            end
         end
      end
      else begin
         data_int = data;
      end
   end
end


// Register muxing signals on a read
always @(posedge clk or negedge reset_n) begin : REG_MUX_SIG
      if (~reset_n) begin
         ce_r    <= {`OUT_MEM_BANKS{1'b0}};
         rd_done <= 1'b0;
      end
      else begin
         ce_r    <= ce;
         rd_done <= |ce && !we;
      end
end

// Generate SRAM modules
genvar i;
generate
   for(i=0; i < `OUT_MEM_BANKS; i=i+1) begin : GEN_OUTPUT_SRAM_BANKS
      // Synthesis configuration
      `ifdef SYNTH
      sram_sp_hse_256_128 sp_sram_out_bank (
         .Q(q_int[i*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT]),
         .CLK(clk),
         .CEN(!ce[i]),
         .GWEN(!we),
         .A(addr),
         .D(data_int[i*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT]),
         .STOV(1'b0),
         .EMA(3'b010),
         .EMAW(2'b01),
         .EMAS(1'b0),
         .RET1N(1'b1)
      );

      // Simulation configuration
      `else
         sp_ram #(
            .DATA_WIDTH(`OUT_MEM_DATA_WDT),
            .RAM_DEPTH(`OUT_MEM_DEPTH)
         ) sp_ram_out_bank
         (
            .clk(clk),
            .we(we),
            .ce(ce[i]),
            .data(data_int[i*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT]),
            .addr(addr),
            .q(q_int[i*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT])
         );
      `endif
   end
endgenerate

// Jtag - only on a jtag read
integer j;
always @(*) begin : MUX_JTAG_RD
   jtag_q =  0;
   for (j = 0; j < `ACT_MEM_BANKS; j = j + 1) begin
      if (ce_r[j] == 1'b1) begin
         jtag_q = q_int[j*`OUT_MEM_DATA_WDT +: `OUT_MEM_DATA_WDT];
      end
   end
end

endmodule // output_mem
