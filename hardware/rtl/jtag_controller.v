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
// Module name : jtag_controller
// Created     : 12/22/19
// Author      : Rahul Garg
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : JTAG TAP Controller 
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_jtag.vh"

module jtag_controller(
   input                                 TCK,
   input                                 TMS,
   input                                 TRSTN,
   input                                 TDI,
   output reg                            TDO,
   output reg                            TDO_en,
   output wire                           USERREG_REN,
   output reg [`JTAG_NUM_USER_REG-1:0]   USERREG_SEL,
   input      [`JTAG_NUM_USER_REG-1:0]   USERREG_TDO,
   output                                USERREG_CDR, // capture
   output                                USERREG_SDR, // shift 
   output                                USERREG_UDR  // update
);

// JTAG Registers
reg [4:0]                              JTAG_STATE;
reg [`JTAG_INST_REG_WIDTH-1:0]         INST_SHIFT_REG;
reg [`JTAG_INST_REG_WIDTH-1:0]         INST_SHADOW_REG;
reg                                    BYPASS_REG;
reg [31:0]                             DEVICE_ID_REG;
reg                                    TDO_mux;

wire [`JTAG_USERREG_SEL_WIDTH-1:0]     userreg_sel_w;
wire								   USERREG_WEN;

//  User Reg Signals
assign userreg_sel_w = INST_SHADOW_REG[`JTAG_USERREG_SEL_WIDTH+3:4]; // select which user reg to read/write
assign USERREG_REN   = INST_SHADOW_REG[`JTAG_INST_REG_WIDTH-1];        // read enable
assign USERREG_WEN   = INST_SHADOW_REG[`JTAG_INST_REG_WIDTH-1:`JTAG_INST_REG_WIDTH-2]; // write enable
assign USERREG_CDR   = (JTAG_STATE == `JTAG_S_CAPTURE_DR);  // capture          
assign USERREG_SDR   = (JTAG_STATE == `JTAG_S_SHIFT_DR);    // shift
assign USERREG_UDR   = (JTAG_STATE == `JTAG_S_UPDATE_DR)&USERREG_WEN; //update

// Various Shift Registers
always @(posedge TCK or negedge TRSTN) begin
   if (!TRSTN) begin
      INST_SHIFT_REG    <= 'b0;
      DEVICE_ID_REG     <= `JTAG_DEVICE_ID_VAL;
      BYPASS_REG        <= 1'b0;
      TDO_en            <= 1'b0;
   end else begin
      TDO_en            <= (JTAG_STATE == `JTAG_S_SHIFT_IR || JTAG_STATE == `JTAG_S_SHIFT_DR);      
      case (JTAG_STATE) 
         `JTAG_S_TEST_LOGIC_RESET: begin
            INST_SHIFT_REG    <= 'b0;
            DEVICE_ID_REG     <= `JTAG_DEVICE_ID_VAL;
            BYPASS_REG        <= 1'b0;
         end
         `JTAG_S_CAPTURE_IR: begin
            INST_SHIFT_REG    <= INST_SHADOW_REG;
         end
         `JTAG_S_SHIFT_IR: begin
            INST_SHIFT_REG    <= {TDI,INST_SHIFT_REG[`JTAG_INST_REG_WIDTH-1:1]};
         end
         `JTAG_S_CAPTURE_DR: begin
            case(INST_SHADOW_REG[3:0])
               `JTAG_INST_IDCODE: DEVICE_ID_REG <= `JTAG_DEVICE_ID_VAL;
               `JTAG_INST_BYPASS: BYPASS_REG    <= 1'b0;
            endcase
         end
         `JTAG_S_SHIFT_DR: begin
            case(INST_SHADOW_REG[3:0])
               `JTAG_INST_IDCODE: DEVICE_ID_REG <= {TDI,DEVICE_ID_REG[31:1]};               
               `JTAG_INST_BYPASS: BYPASS_REG    <= TDI;
            endcase
         end
         default: begin
            INST_SHIFT_REG    <= INST_SHIFT_REG;
            DEVICE_ID_REG     <= DEVICE_ID_REG;
            BYPASS_REG        <= BYPASS_REG;
         end
      endcase
   end
end

// JTAG Instruction Register
always @(posedge TCK or negedge TRSTN) begin
   if (!TRSTN) begin
      INST_SHADOW_REG   <= {{(`JTAG_INST_REG_WIDTH-4){1'b0}},`JTAG_INST_IDCODE};
   end else begin
      case (JTAG_STATE) 
         `JTAG_S_TEST_LOGIC_RESET: begin
            INST_SHADOW_REG   <= {{(`JTAG_INST_REG_WIDTH-4){1'b0}},`JTAG_INST_IDCODE};
         end
         // Done on Neg-Edge to get hold benefit from this register.
         `JTAG_S_UPDATE_IR: begin
            INST_SHADOW_REG   <= INST_SHIFT_REG;             
         end
         default: INST_SHADOW_REG   <= INST_SHADOW_REG;
      endcase
   end
end

// TDO Muxing
always @(*) begin
   TDO_mux = 1'b0;
   USERREG_SEL = 'b0;
   if (JTAG_STATE == `JTAG_S_SHIFT_IR) begin
      TDO_mux = INST_SHIFT_REG[0];
   end else begin
      case(INST_SHADOW_REG[3:0])
         `JTAG_INST_IDCODE:  TDO_mux = DEVICE_ID_REG[0];
         `JTAG_INST_BYPASS:  TDO_mux = BYPASS_REG;
         `JTAG_INST_USERREG: TDO_mux = USERREG_TDO[userreg_sel_w];
         default:      TDO_mux = BYPASS_REG;
      endcase
   end
   if(INST_SHADOW_REG[3:0]==`JTAG_INST_USERREG)
      USERREG_SEL[userreg_sel_w] = 1'b1;
end

// TDO NegEdge Pipeline
always @(negedge TCK)
   TDO <= TDO_mux;

// JTAG State Machine.
always @(posedge TCK or negedge TRSTN) begin
   if (!TRSTN) begin
      JTAG_STATE <= `JTAG_S_TEST_LOGIC_RESET;
   end else begin
      case (JTAG_STATE) 
         `JTAG_S_TEST_LOGIC_RESET: if (TMS == 1'b0) JTAG_STATE <= `JTAG_S_RUN_TEST_IDLE;
         `JTAG_S_RUN_TEST_IDLE: if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_SELECT_DR_SCAN;
         `JTAG_S_SELECT_DR_SCAN: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_SELECT_IR_SCAN;
            else JTAG_STATE <= `JTAG_S_CAPTURE_DR;
         end
         `JTAG_S_CAPTURE_DR: begin
            if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT1_DR;
            else JTAG_STATE <= `JTAG_S_SHIFT_DR;
         end
         `JTAG_S_SHIFT_DR: if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT1_DR;
         `JTAG_S_EXIT1_DR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_UPDATE_DR;
            else JTAG_STATE <= `JTAG_S_PAUSE_DR;            
         end
         `JTAG_S_PAUSE_DR: if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT2_DR;
         `JTAG_S_EXIT2_DR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_UPDATE_DR;
            else JTAG_STATE <= `JTAG_S_SHIFT_DR;            
         end
         `JTAG_S_UPDATE_DR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_SELECT_DR_SCAN;
            else JTAG_STATE <= `JTAG_S_RUN_TEST_IDLE;              
         end
         `JTAG_S_SELECT_IR_SCAN: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_TEST_LOGIC_RESET;
            else JTAG_STATE <= `JTAG_S_CAPTURE_IR;
         end
         `JTAG_S_CAPTURE_IR: begin
            if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT1_IR;
            else JTAG_STATE <= `JTAG_S_SHIFT_IR;
         end
         `JTAG_S_SHIFT_IR: if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT1_IR;
         `JTAG_S_EXIT1_IR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_UPDATE_IR;
            else JTAG_STATE <= `JTAG_S_PAUSE_IR;            
         end
         `JTAG_S_PAUSE_IR: if (TMS == 1'b1) JTAG_STATE <= `JTAG_S_EXIT2_IR;
         `JTAG_S_EXIT2_IR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_UPDATE_IR;
            else JTAG_STATE <= `JTAG_S_SHIFT_IR;            
         end
         `JTAG_S_UPDATE_IR: begin
            if (TMS ==1'b1) JTAG_STATE <= `JTAG_S_SELECT_DR_SCAN;
            else JTAG_STATE <= `JTAG_S_RUN_TEST_IDLE;              
         end
         default: JTAG_STATE <= `JTAG_S_RUN_TEST_IDLE;
      endcase
   end
end

endmodule // jtag_controller

