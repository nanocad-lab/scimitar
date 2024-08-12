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
// Module name : input_mem
// Created     : Thu 22 Sep 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Input memory for ERIDA SCIM chip (MACLEOD)
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

module input_mem(
   input  wire                         clk,     // I: Core clock
   input  wire                         reset_n, // I: Async reset active low
   // Memory interface
   input  wire [`ACT_MEM_BANKS-1:0]    ce,      // I: Chip enable
   input  wire                         we,      // I: Write enable
   input  wire [`ACT_MEM_RD_INST_WDT-1:0] inst, // I: Read instruction
   input  wire [`ACT_MEM_DATA_WDT-1:0] data,    // I: Write data
   input  wire [`ACT_MEM_BANKS*`ACT_MEM_ADDR_WDT-1:0] base_addr,    // I: Address
   input  wire [`ACT_MEM_ADDR_WDT-1:0] offset,  // I: Address offset
   output reg  [`ACT_MEM_BANKS*`ACT_MEM_DATA_WDT_RD-1:0] q, // O: Read data
   output reg  [`ACT_MEM_DATA_WDT-1:0] jtag_q,  // O: Read data (jtag)
   output reg                          rd_done  // O: Read done flag
);

// Expanded chip enables
wire [`ACT_MEM_BANKS-1:0]  ce_left;
wire [`ACT_MEM_BANKS-1:0]  ce_right;

// Converted addresses
reg  [`ACT_MEM_ADDR_WDT-1:0] addr [`ACT_MEM_BANKS-1:0];

// Registered muxing signals
reg  [`ACT_MEM_BANKS-1:0]  ce_r;
reg  [`ACT_MEM_RD_INST_WDT-1:0] inst_r;
reg                        rd_r;
wire                       jtag_rd; 
wire                       left_rd; 
wire                       rgth_rd; 

// Read data
// Left
wire [`ACT_MEM_DATA_WDT_HALF-1:0] rd_data_left [`ACT_MEM_BANKS-1:0];
// Overlap
wire [`ACT_MEM_DATA_WDT_OVLP-1:0] rd_data_ovlp [`ACT_MEM_BANKS-1:0];
// Right
wire [`ACT_MEM_DATA_WDT_HALF-1:0] rd_data_right [`ACT_MEM_BANKS-1:0];

// Expand chip enables
// Left - always enabled on a write, disabled on a read-right
assign ce_left = (we == 1'b1) ? ce : (inst != `ACT_MEM_RD_INST_RGTH) ? ce : {`ACT_MEM_BANKS{1'b0}};
// Right - always enabled on a write, disabled on a read-left
assign ce_right = (we == 1'b1) ? ce : (inst != `ACT_MEM_RD_INST_LEFT) ? ce : {`ACT_MEM_BANKS{1'b0}};

// Convert addresses
integer l;
always @(*) begin : ADDR_CONVERT
   for (l = 0; l < `ACT_MEM_BANKS; l = l + 1) begin
      addr[l] = base_addr[l*`ACT_MEM_ADDR_WDT +: `ACT_MEM_ADDR_WDT] + offset;
   end
end

// Register muxing signals on a read
always @(posedge clk or negedge reset_n) begin : REG_MUX_SIG
      if (~reset_n) begin
         ce_r    <= {`ACT_MEM_BANKS{1'b0}};
         inst_r  <= {`ACT_MEM_RD_INST_WDT{1'b0}};
         rd_done <= 1'b0;
      end
      else begin 
         ce_r    <= ce;
         inst_r  <= inst;
         rd_done <= |ce && !we;
      end
end

// WJR: setting assists to default. We ideally want to have control over thos
//  o Default EMA and Assist settings are as follows for various voltage domains:
//
//      -----------------------------------------------------
//      VDDPE:      0.6v   0.6V  0.7v  0.7v  0.8v  0.8v  0.9v   
//      VDDCE:      0.7v   0.8v  0.7V  0.8v  0.8v  0.9v  0.9v  
//      -----------------------------------------------------
//      EMA[2:0]    100    010   100   010   010   010   010 
//      EMAW[1:0]   01     01    01    01    01    01    01  
//      EMAS        0      0     0     0     0     0     0   
//      -----------------------------------------------------
//      WA          on     off   on    off   off   off   off 
//      WAWL        1      0     1     0     0     0     0   
//      WAWLM[1:0]  00     00    00    00   00     00    00  
//      -----------------------------------------------------


// Generate SRAM modules
genvar i;
generate
   for(i=0; i < `ACT_MEM_BANKS; i=i+1) begin : GEN_INPUT_SRAM_BANKS
      // Synthesis configuration
      `ifdef SYNTH
      // Left
      sram_sp_hse_512_28 sp_sram_left (
         .Q(rd_data_left[i]),
         .CLK(clk),
         .CEN(!ce_left[i]),
         .GWEN(!we),
         .A(addr[i]),
         .D(data[`ACT_MEM_DATA_WDT-1:`ACT_MEM_DATA_WDT-`ACT_MEM_DATA_WDT_HALF]),
         .STOV(1'b0),
         .EMA(3'b010),
         .EMAW(2'b01),
         .EMAS(1'b0),
         .RET1N(1'b1)
      );
      // Overlap
      sram_sp_hse_512_8 sp_sram_ovlp (
         .Q(rd_data_ovlp[i]),
         .CLK(clk),
         .CEN(!ce[i]),
         .GWEN(!we),
         .A(addr[i]),
         .D(data[`ACT_MEM_DATA_WDT-`ACT_MEM_DATA_WDT_HALF-1 -: `ACT_MEM_DATA_WDT_OVLP]),
         .STOV(1'b0),
         .EMA(3'b010),
         .EMAW(2'b01),
         .EMAS(1'b0),
         .RET1N(1'b1)
      );
      // Right
      sram_sp_hse_512_28 sp_sram_right (
         .Q(rd_data_right[i]),
         .CLK(clk),
         .CEN(!ce_right[i]),
         .GWEN(!we),
         .A(addr[i]),
         .D(data[`ACT_MEM_DATA_WDT_HALF-1 : 0]),
         .STOV(1'b0),
         .EMA(3'b010),
         .EMAW(2'b01),
         .EMAS(1'b0),
         .RET1N(1'b1)
      );

      // Simulation configuration
      `else
         // Left
         sp_ram #(
            .DATA_WIDTH(`ACT_MEM_DATA_WDT_HALF),
            .RAM_DEPTH(`ACT_MEM_DEPTH)
         ) sp_ram_left
         (
            .clk(clk),
            .we(we),
            .ce(ce_left[i]),
            .data(data[`ACT_MEM_DATA_WDT-1 -: `ACT_MEM_DATA_WDT_HALF]),
            .addr(addr[i]),
            .q(rd_data_left[i])
         );
         // Overlap
         sp_ram #(
            .DATA_WIDTH(`ACT_MEM_DATA_WDT_OVLP),
            .RAM_DEPTH(`ACT_MEM_DEPTH)
         ) sp_ram_ovlp
         (
            .clk(clk),
            .we(we),
            .ce(ce[i]),
            .data(data[`ACT_MEM_DATA_WDT-`ACT_MEM_DATA_WDT_HALF-1 -: `ACT_MEM_DATA_WDT_OVLP]),
            .addr(addr[i]),
            .q(rd_data_ovlp[i])
         );
         // Overlap
         sp_ram #(
            .DATA_WIDTH(`ACT_MEM_DATA_WDT_HALF),
            .RAM_DEPTH(`ACT_MEM_DEPTH)
         ) sp_ram_right
         (
            .clk(clk),
            .we(we),
            .ce(ce_right[i]),
            .data(data[`ACT_MEM_DATA_WDT_HALF-1 : 0]),
            .addr(addr[i]),
            .q(rd_data_right[i])
         );
      `endif
   end
endgenerate

// Mux/demux output data
// Check for reads in previous cycle
assign jtag_rd = (|ce_r == 1'b1) && (inst_r == `ACT_MEM_RD_INST_JTAG);
assign left_rd = (|ce_r == 1'b1) && (inst_r == `ACT_MEM_RD_INST_LEFT);
assign rgth_rd = (|ce_r == 1'b1) && (inst_r == `ACT_MEM_RD_INST_RGTH);
// Jtag - only on a jtag read
integer j;
always @(*) begin : MUX_JTAG_RD
   jtag_q =  0;
   for (j = 0; j < `ACT_MEM_BANKS; j = j + 1) begin
      if (jtag_rd == 1'b1 && ce_r[j] == 1'b1) begin
         jtag_q =  {rd_data_left[j], rd_data_ovlp[j], rd_data_right[j]}; 
      end
   end
end
// Left/Right read
integer k;
always @(*) begin : MUX_RD
   q =  0;
   if (left_rd == 1'b1) begin
      for (k = 0; k < `ACT_MEM_BANKS; k = k + 1) begin
         q[k*`ACT_MEM_DATA_WDT_RD +: `ACT_MEM_DATA_WDT_RD] =  {rd_data_left[k], rd_data_ovlp[k]};
      end
   end
   else if (rgth_rd == 1'b1) begin
      for (k = 0; k < `ACT_MEM_BANKS; k = k + 1) begin
         q[k*`ACT_MEM_DATA_WDT_RD +: `ACT_MEM_DATA_WDT_RD] =  {rd_data_ovlp[k], rd_data_right[k]};
      end
   end
end


endmodule // input_mem
