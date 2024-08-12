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
// Module name : clkmux
// Created     : 01/30/20
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Top level clock multiplexer, glitch free
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"
`include "scotsman_jtag.vh"
`include "scotsman_isa.vh"

module clkmux(
   clk_a,                  // I: Analog clock
   clk_d,                  // I: Digital clock
   clk_sel,                // I: Clock select signal
   clk_int                 // O: Muxed clock
);

////////////////////////////////////////
// Inputs
input                      clk_a;
input                      clk_d;
input                      clk_sel;

////////////////////////////////////////
// Outputs
output                     clk_int;

////////////////////////////////////////
// Logic
// Clock Muxing

`ifdef CLKMUX_GLITCH_FREE

wire            clk_a_sel;
wire            clk_d_sel;
reg [1:0]       clk_a_sel_sync;
reg [1:0]       clk_d_sel_sync;
wire            clk_a_gated;
wire            clk_d_gated;

assign  clk_a_sel     =  ~clk_sel  &  ~clk_d_sel_sync[0];
assign  clk_d_sel     =  clk_sel   &  ~clk_a_sel_sync[0];

always @(posedge clk_a) 
    clk_a_sel_sync[1] <= clk_a_sel;

always @(negedge clk_a) 
    clk_a_sel_sync[0] <= clk_a_sel_sync[1];

always @(posedge clk_d) 
    clk_d_sel_sync[1] <= clk_d_sel;

always @(negedge clk_d) 
    clk_d_sel_sync[0] <= clk_d_sel_sync[1];

assign clk_a_gated = clk_a & clk_a_sel_sync[0];
assign clk_d_gated = clk_d & clk_d_sel_sync[0];
assign clk_int = clk_a_gated | clk_d_gated;
`else
assign   clk_int = (clk_sel) ? clk_d: clk_a;
`endif

endmodule
