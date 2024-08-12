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
// Module name : stagebuff
// Created     : Tue 07 Jun 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Staging buffer block to hold values read from memory
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"

module stagebuff (
   clk,        // I: Clock input
   reset_n,    // I: Async reset, active low
   src,        // I: Source (0 - memory, 1 - buffer)
   clr,        // I: Buffer clear
   bit_pos,    // I: Bit position being written
//   zero_in_mem, // I: Zero indicator in, memory
//   zero_in_buf, // I: Zero indicator in, previous buffer
//   zero_out,   // O: Zero indicator out
   val_in_mem, // I: Value to be buffered, memory
   val_in_buf, // I: Value to be buffered, previous buffer
   val_out     // O: Buffer output
);

////////////////////////////////////////
// Parameter

////////////////////////////////////////
// Inputs
// Clock
input                                     clk;
// Async reset active low
// OPT: technically, value registers don't need reset
// Could be non-resetabble, cleared by control, but need to be careful
input                                     reset_n;
// Source (0 - memory, 1 - buffer)
input                                     src;
// Buffer clr 
input                                     clr;
// Bit position
input  [`PREC_WDT-1:0]                    bit_pos;
//// Zero indicator, memory
//input                                     zero_in_mem;
//// Zero indicator, previous buffer
//input                                     zero_in_buf;
// Input value, memory
input  [`ACT_BUF_BLOCK_NO-1:0]            val_in_mem;
// Input value, previous buffer
input  [(`ACT_BUF_BLOCK_NO*`ACT_BUF_DAT)-1:0] val_in_buf;

////////////////////////////////////////
// Outputs
// Output values
output reg [`ACT_BUF_BLOCK_WDT-1:0]       val_out ;
//// Output zero indicator
//output reg                                zero_out;

////////////////////////////////////////
// Wires/registers - each bit position stored individually, 
reg    [`PREC_WDT-1:0]                    bit_pos_delay;

always @ (posedge clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
        bit_pos_delay <= 0;
    end
    else begin
        bit_pos_delay <= bit_pos;
    end
end

////////////////////////////////////////
// Logic  

//// Zero indicator 
//always @ (posedge clk or negedge reset_n) begin : ACTSNG_BUFF_SEQ
//   if (reset_n == 1'b0) begin
//      zero_out <= 1'b1;
//   end
//   else if (clr == 1'b1) begin
//      zero_out <= 1'b1;
//   end
//   else begin
//      // Memory
//      if (src == 1'b0) begin
//         zero_out <=  zero_in_mem;
//      end
//      // Buffer
//      else if (src == 1'b1) begin
//         zero_out <=  zero_in_buf;
//      end
//   end
//end

// Output merge
genvar j,k;
generate
   for (j = 0; j < `ACT_BUF_DAT; j = j + 1) begin : OUTPUT_MERGE_BIT
      for (k = 0; k < `ACT_BUF_BLOCK_NO; k = k + 1) begin : OUTPUT_MERGE_VEC
         always @ (posedge clk or negedge reset_n) begin : BIT_STAGE_BUF
            // Reset
            if (reset_n == 1'b0) begin
               val_out[k*`ACT_BUF_DAT + j] <= 1'b0;
            end
            // Global clear
            else if (clr == 1'b1) begin
               val_out[k*`ACT_BUF_DAT + j] <= 1'b0;
            end
            // Strict checking
            else begin
               // When loading from memory, check for bit position
               if (src == 1'b0 && bit_pos_delay == j) begin
                  val_out[k*`ACT_BUF_DAT + j] <= val_in_mem[k];
               end
               // When loading from previous buffer, always load
               else if (src == 1'b1) begin
                  val_out[k*`ACT_BUF_DAT + j] <= val_in_buf[k*`ACT_BUF_DAT + j];
               end
            end
         end
      end
   end
endgenerate

endmodule // stagebuff
