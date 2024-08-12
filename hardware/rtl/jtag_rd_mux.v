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
// Module name : jtag_rd_mux
// Created     : Fri 30 Sep 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : JTAG Read Multiplexer
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"
`include "scotsman_jtag.vh"
`include "scotsman_isa.vh"
`include "ERI-DA_HEADERS.vh"

module jtag_rd_mux (
   input  wire                         clk,     // I: Core clock
   input  wire                         reset_n, // I: Async reset, active low
   // Input memory
   input  wire [`ACT_MEM_DATA_WDT-1:0] imem_rd_data,
   input  wire                         imem_rd_done,
   // Output memory
   input  wire [`OUT_MEM_DATA_WDT-1:0] omem_rd_data,
   input  wire                         omem_rd_done,
   // Weight memory
   input  wire [`WGT_MEM_DATA_WDT_RD-1:0] wmem_rd_data,
   input  wire                         wmem_rd_done,
   
   //******* Config register [10/14/22]VKJ: Config reg moved to JTAG. No need for readout through JTAG data reg.
            //   input  wire [`CFG_REG_WDT-1:0]      ctrl_rd_data,
            //   input  wire                         ctrl_rd_done,
   //*******

   // Seed values
   // WJR: Fix hardcoded values
   input  wire [`N_L-1:0]              seed_rd_data,
   input  wire                         seed_rd_done,
   // Output to JTAG
   output reg  [`JTAG_UDR_MEM_DATA_REG_WDT-1:0] jtag_rd_data
);
// Aliasing to bypass compiler complaining about using expressions in always blocks
localparam JTAG_RD_REG_WDT = `JTAG_UDR_MEM_DATA_REG_WDT;

reg  [JTAG_RD_REG_WDT-1:0] jtag_rd_data_mux;
// Or'd read enable signals
wire                       rd_en;

// Muxing process
always @(*) begin : JTAG_RD_MUX
   jtag_rd_data_mux = {JTAG_RD_REG_WDT{1'b0}};
   // Input memory read
   if (imem_rd_done == 1'b1) begin
      jtag_rd_data_mux[`ACT_MEM_DATA_WDT-1:0] = imem_rd_data;
   end
   // Output memory read
   else if (omem_rd_done == 1'b1) begin
      jtag_rd_data_mux[`OUT_MEM_DATA_WDT-1:0] = omem_rd_data;
   end
   // Weight memory read
   else if (wmem_rd_done == 1'b1) begin
      jtag_rd_data_mux[`WGT_MEM_DATA_WDT_RD-1:0] = wmem_rd_data;
   end

   //******* Config register read [10/14/22]VKJ: Config reg moved to JTAG. No need for readout through JTAG data reg.
         //   else if (ctrl_rd_done == 1'b1) begin
         //      jtag_rd_data_mux[`CFG_REG_WDT-1:0] = ctrl_rd_data;
         //   end
   //*******

   // Seed read
   else if (seed_rd_done == 1'b1) begin
      jtag_rd_data_mux[`N_L-1:0] = seed_rd_data;
   end
end

//******* Config register read [10/14/22]VKJ: Config reg moved to JTAG. No need for readout through JTAG data reg.
         //assign rd_en = |{imem_rd_done, omem_rd_done, wmem_rd_done, ctrl_rd_done, seed_rd_done};
//******

assign rd_en = |{imem_rd_done, omem_rd_done, wmem_rd_done, seed_rd_done};

// Register for timing
// WJR: consider clock gating, might not be worth it.
always @(posedge clk or negedge reset_n) begin : JTAG_RD_REG
   if (~reset_n) begin
      jtag_rd_data <= {JTAG_RD_REG_WDT{1'b0}};
   end
   else begin
      if (rd_en == 1'b1) begin
         jtag_rd_data <= jtag_rd_data_mux;
      end
   end
end

endmodule // jtag_rd_mux
