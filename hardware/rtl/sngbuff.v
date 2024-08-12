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
// Module name : sngbuff
// Created     : Mon 06 Jun 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : SNG buffer block to hold values to be converted
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"

module sngbuff (
   clk,        // I: Clock input
   en,         // I: Buffer enable
   clr,        // I: Buffer clear

   //******[10/15/22]VKJ: Removed Zero indicators.
            //zero_in,    // I: Zero indicator in
            //zero_out,   // O: Zero indicator out
    //******[10/15/22]VKJ: Removed Zero indicators.
   
   val_in,     // I: Value to be buffered 
   val_out     // O: Buffer output
);

////////////////////////////////////////
// Parameter
// Buffer data width
// Default width is 64 (values) x 6 (bits) = 384
parameter                                 BUF_WDT = 384;

////////////////////////////////////////
// Inputs
// Clock
input                                     clk;
// Buffer enable
input                                     en;
// Buffer clr 
// OPT: if area is an issue, clr can be removed, but then control
// is responsible for explicitly writing zeros to buffers.
input                                     clr;
// Zero indicator
// OPT: if this is made resettable, and resets to zero, then clear might
// not be needed at all. Although need to be careful with leftoever values.
// Staging buffers should clear those on every new iteration.
    
//******[10/15/22]VKJ: Removed Zero indicators.
      //input                                     zero_in;
//******[10/15/22]VKJ: Removed Zero indicators.

// Input value
input  [BUF_WDT-1:0]                      val_in;

////////////////////////////////////////
// Outputs
output reg [BUF_WDT-1:0]                  val_out;
//******[10/15/22]VKJ: Removed Zero indicators.
      //output reg                                zero_out;
//******[10/15/22]VKJ: Removed Zero indicators.

////////////////////////////////////////
// Logic  
always @ (posedge clk) begin : ACTSNG_BUFF_SEQ
   if (clr == 1'b1) begin
      val_out <= {BUF_WDT{1'b0}};
//******[10/15/22]VKJ: Removed Zero indicators.
      //zero_out <= 1'b1;
//******[10/15/22]VKJ: Removed Zero indicators.
   end
   else if (en == 1'b1) begin
      val_out <= val_in;
//******[10/15/22]VKJ: Removed Zero indicators.
      //zero_out <=  zero_in;
//******[10/15/22]VKJ: Removed Zero indicators.
   end
end

endmodule // sngbuff 
