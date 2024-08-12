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
// Module name : acoustic_jtag_subsystem
// Created     : 01/29/20
// Author      : Rahul Garg
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : JTAG Subsystem for Acoustic.
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_jtag.vh"

module jtag_subsystem(
    // Top level clock
    input                                        clk,
    input                                        reset_n,
    // Chip level JTAG Interface
    input                                        tck,
    input                                        tms,
    input                                        trstn,
    input                                        tdi,
    output                                       tdo,
    output                                       tdo_en,

    output                                       mbist_en,
    input                                        mbist_tdo,

    output [`JTAG_UDR_INST_REG_WDT-1:0]          jtag_inst,
    output [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      jtag_mem_data_wr,
    input  [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      jtag_mem_data_rd,

    output [`JTAG_UDR_CFG_REG_WDT-1:0]           jtag_cfg_reg,
    
    output                                       jtag_inst_kickoff

);

wire                                             userreg_ren;
wire [`JTAG_NUM_USER_REG-1:0]                    userreg_sel;
wire [`JTAG_NUM_USER_REG-1:0]                    userreg_tdo;
wire                                             userreg_cdr;
wire                                             userreg_sdr;
wire                                             userreg_udr;

//instruction start
wire [`JTAG_UDR_KICKOFF_REG_WDT-1:0]             kickoff_bits;
wire                                             jtag_inst_kickoff_int;
// Jtag kickoff synchronization
reg                                              jtag_inst_kickoff_r;
reg                                              jtag_inst_kickoff_rr;


assign mbist_en = userreg_sel[`JTAG_UDR_MBIST_EN_REG_NUM];
assign userreg_tdo[`JTAG_UDR_MBIST_EN_REG_NUM] = mbist_tdo;
jtag_controller TAP (
      .TCK(tck),
      .TMS(tms),
      .TDI(tdi),
      .TDO(tdo),
      .TRSTN(trstn),
      .TDO_en(tdo_en),
      .USERREG_REN(userreg_ren), 
      .USERREG_SEL(userreg_sel),
      .USERREG_TDO(userreg_tdo),
      .USERREG_CDR(userreg_cdr),
      .USERREG_SDR(userreg_sdr),
      .USERREG_UDR(userreg_udr)
);


//instruction register 32 bits
jtag_userreg #(
   .USERREG_WIDTH(`JTAG_UDR_INST_REG_WDT)
) i_jtag_mem_inst (
      .TCK(tck),
      .TDI(tdi),
      .TRSTN(trstn),
      .USERREG_REN(userreg_ren), 
      .USERREG_SEL(userreg_sel[`JTAG_UDR_INST_REG_NUM]),
      .USERREG_TDO(userreg_tdo[`JTAG_UDR_INST_REG_NUM]),
      .USERREG_CDR(userreg_cdr),
      .USERREG_SDR(userreg_sdr),
      .USERREG_UDR(userreg_udr),
      .DATA_IN(jtag_inst),  // TODO: Update  
      .DATA_OUT(jtag_inst)
);

//memory data 2048 bit
jtag_userreg #(
   .USERREG_WIDTH(`JTAG_UDR_MEM_DATA_REG_WDT)
) i_jtag_mem_data (
      .TCK(tck),
      .TDI(tdi),
      .TRSTN(trstn),
      .USERREG_REN(userreg_ren), 
      .USERREG_SEL(userreg_sel[`JTAG_UDR_MEM_DATA_REG_NUM]),
      .USERREG_TDO(userreg_tdo[`JTAG_UDR_MEM_DATA_REG_NUM]),
      .USERREG_CDR(userreg_cdr),
      .USERREG_SDR(userreg_sdr),
      .USERREG_UDR(userreg_udr),
      .DATA_IN(jtag_mem_data_rd),    
      .DATA_OUT(jtag_mem_data_wr)
);

//config reg 91 bit
jtag_userreg #(
   .USERREG_WIDTH(`JTAG_UDR_CFG_REG_WDT)
) i_jtag_cfg_reg (
      .TCK(tck),
      .TDI(tdi),
      .TRSTN(trstn),
      .USERREG_REN(userreg_ren), 
      .USERREG_SEL(userreg_sel[`JTAG_UDR_CFG_REG_NUM]),
      .USERREG_TDO(userreg_tdo[`JTAG_UDR_CFG_REG_NUM]),
      .USERREG_CDR(userreg_cdr),
      .USERREG_SDR(userreg_sdr),
      .USERREG_UDR(userreg_udr),
      .DATA_IN(jtag_cfg_reg),    
      .DATA_OUT(jtag_cfg_reg)
);



jtag_userreg #(
   .USERREG_WIDTH(`JTAG_UDR_KICKOFF_REG_WDT),
   .SELF_CLEARING(1)
) i_jtag_kickoff_bits (
      .TCK(tck),
      .TDI(tdi),
      .TRSTN(trstn),
      .USERREG_REN(userreg_ren), 
      .USERREG_SEL(userreg_sel[`JTAG_UDR_KICKOFF_REG_NUM]),
      .USERREG_TDO(userreg_tdo[`JTAG_UDR_KICKOFF_REG_NUM]),
      .USERREG_CDR(userreg_cdr),
      .USERREG_SDR(userreg_sdr),
      .USERREG_UDR(userreg_udr),
      .DATA_IN(kickoff_bits),    
      .DATA_OUT(kickoff_bits)
);

assign jtag_inst_kickoff_int = kickoff_bits[0];

// Kickoff synchronization
// WJR: need to check for CDC here
always @(posedge clk or negedge reset_n) begin : JTAG_KICKOFF_SYNC
      if (!reset_n) begin
         jtag_inst_kickoff_r  <= 1'b0;
         jtag_inst_kickoff_rr <= 1'b0;
      end
      else begin
         jtag_inst_kickoff_r  <= jtag_inst_kickoff_int;
         jtag_inst_kickoff_rr <= jtag_inst_kickoff_r;
      end
end

// Pulse kickoff bit
assign jtag_inst_kickoff = (jtag_inst_kickoff_rr == 1'b0) && (jtag_inst_kickoff_r == 1'b1);

endmodule
