//////////////////////////////////////////////////////////////////////////////
// The MIT License (MIT)
// 
// Copyright (c) 2019 UCLA NanoCAD Laboratory
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
// Module name : jtag_userreg
// Created     : 12/22/19
// Author      : Rahul Garg
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : JTAG User Registers 
//               
/////////////////////////////////////////////////////////////////////////////

module jtag_userreg #(
   parameter USERREG_WIDTH          = 64,
   parameter SELF_CLEARING          = 0,
   parameter RESET_VALUE            = 0
)(
   input                            TCK,
   input                            TRSTN,
   input                            TDI,
   input       [USERREG_WIDTH-1:0]  DATA_IN,               
   input                            USERREG_CDR, // capture
   input                            USERREG_SDR, // shift
   input                            USERREG_UDR, // update
   input                            USERREG_REN, // read from datain or shadow_reg
   input                            USERREG_SEL, // select
   output wire                      USERREG_TDO, // out
   output wire [USERREG_WIDTH-1:0]  DATA_OUT
);

reg [USERREG_WIDTH-1:0]             USERREG_SHIFT_REG;
reg [USERREG_WIDTH-1:0]             USERREG_SHADOW_REG;

assign DATA_OUT    = USERREG_SHADOW_REG;
assign USERREG_TDO = USERREG_SHIFT_REG[0];

always @(posedge TCK or negedge TRSTN) begin
   if (!TRSTN) begin
      USERREG_SHIFT_REG <= RESET_VALUE;
   end else if (USERREG_SEL) begin
      if (USERREG_CDR) begin
         USERREG_SHIFT_REG <= USERREG_REN ? DATA_IN : USERREG_SHADOW_REG;
      end else if (USERREG_SDR) begin
         USERREG_SHIFT_REG <= {TDI,USERREG_SHIFT_REG[USERREG_WIDTH-1:1]};
      end
   end
end

always @(posedge TCK or negedge TRSTN) begin
   if (!TRSTN) begin
      USERREG_SHADOW_REG   <= RESET_VALUE;
   end else if (USERREG_UDR&&USERREG_SEL) begin
      USERREG_SHADOW_REG   <= USERREG_SHIFT_REG;
   end else if ((SELF_CLEARING==1) && (USERREG_SHADOW_REG!=0)) begin
      USERREG_SHADOW_REG   <= RESET_VALUE;
   end
end

endmodule // jtag_userreg
