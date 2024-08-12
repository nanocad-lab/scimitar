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
// Header name : scotsman_isa
// Created     : Wed 21 Sep 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : SCOTSMAN In-Situ SCIM Architecture ISA configuration
//               
/////////////////////////////////////////////////////////////////////////////

`ifndef _SCOTSMAN_ISA_VH_
`define _SCOTSMAN_ISA_VH_

`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"

////////////////////////////////////////
// JTAG Instructions
`define JTAG_INST_WDT 32
// JTAG Instruction Opcode width
`define JTAG_INST_OPC_WDT 4
// JTAG Instruction Data Width
`define JTAG_INST_DAT_WDT (`JTAG_INST_WDT-`JTAG_INST_OPC_WDT)

////////////////////////////////////////
// Bit ranges for the opcode and data
`define JTAG_INST_OPC_MSB (`JTAG_INST_WDT - 1)
`define JTAG_INST_OPC_LSB (`JTAG_INST_OPC_MSB - `JTAG_INST_OPC_WDT + 1)
`define JTAG_INST_DAT_MSB (`JTAG_INST_OPC_LSB - 1)
`define JTAG_INST_DAT_LSB (0)

////////////////////////////////////////
// Opcodes
// Input Store
`define JTAG_INST_ACTST (`JTAG_INST_OPC_WDT'b0000)
// Input Load
`define JTAG_INST_ACTLD (`JTAG_INST_OPC_WDT'b0001)
// Weight Store
`define JTAG_INST_WGTST (`JTAG_INST_OPC_WDT'b0010)
// Weight Load
`define JTAG_INST_WGTLD (`JTAG_INST_OPC_WDT'b0011)
// Output Store
`define JTAG_INST_OUTST (`JTAG_INST_OPC_WDT'b0100)
// Output Load
`define JTAG_INST_OUTLD (`JTAG_INST_OPC_WDT'b0101)
// Seed Store
`define JTAG_INST_SEDST (`JTAG_INST_OPC_WDT'b0110)
// Seed Load
`define JTAG_INST_SEDLD (`JTAG_INST_OPC_WDT'b0111)
// Config Store
`define JTAG_INST_CFGST (`JTAG_INST_OPC_WDT'b1000)
// Config Load
`define JTAG_INST_CFGLD (`JTAG_INST_OPC_WDT'b1001)
// Compute
`define JTAG_INST_RUNEN (`JTAG_INST_OPC_WDT'b1010)

////////////////////////////////////////
// Get/set instruction fields
// Opcode
function [`JTAG_INST_OPC_WDT-1:0] get_opc;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_opc = instruction[`JTAG_INST_OPC_MSB:`JTAG_INST_OPC_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_opc;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_OPC_WDT-1:0] opc;
   begin
      set_opc = {opc, instruction[`JTAG_INST_DAT_MSB:`JTAG_INST_DAT_LSB]};
   end
endfunction
// Data
function [`JTAG_INST_DAT_WDT-1:0] get_dat;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_dat = instruction[`JTAG_INST_DAT_MSB:`JTAG_INST_DAT_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_dat;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_DAT_WDT-1:0] data;
   begin
      set_dat = {instruction[`JTAG_INST_OPC_MSB:`JTAG_INST_OPC_LSB], data};
   end
endfunction
// Check opcode
// ACTST
function is_actst;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_actst = (opcode == `JTAG_INST_ACTST) ? 1'b1 : 1'b0;
   end
endfunction
// ACTLD
function is_actld;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_actld = (opcode == `JTAG_INST_ACTLD) ? 1'b1 : 1'b0;
   end
endfunction
// WGTST
function is_wgtst;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_wgtst = (opcode == `JTAG_INST_WGTST) ? 1'b1 : 1'b0;
   end
endfunction
// WGTLD
function is_wgtld;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_wgtld = (opcode == `JTAG_INST_WGTLD) ? 1'b1 : 1'b0;
   end
endfunction
// OUTST
function is_outst;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_outst = (opcode == `JTAG_INST_OUTST) ? 1'b1 : 1'b0;
   end
endfunction
// OUTLD
function is_outld;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_outld = (opcode == `JTAG_INST_OUTLD) ? 1'b1 : 1'b0;
   end
endfunction
// SEDST
function is_sedst;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_sedst = (opcode == `JTAG_INST_SEDST) ? 1'b1 : 1'b0;
   end
endfunction
// SEDLD
function is_sedld;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_sedld = (opcode == `JTAG_INST_SEDLD) ? 1'b1 : 1'b0;
   end
endfunction
// CFGST
function is_cfgst;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_cfgst = (opcode == `JTAG_INST_CFGST) ? 1'b1 : 1'b0;
   end
endfunction
// CFGLD
function is_cfgld;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_cfgld = (opcode == `JTAG_INST_CFGLD) ? 1'b1 : 1'b0;
   end
endfunction
// RUNEN
function is_runen;
   input [`JTAG_INST_OPC_WDT-1:0] opcode;
   begin
      is_runen = (opcode == `JTAG_INST_RUNEN) ? 1'b1 : 1'b0;
   end
endfunction

////////////////////////////////////////
// Instruction field ranges
////////////////////////////////////////
// ACTST
// Address
`define JTAG_INST_ACTST_ADDR_WDT (`ACT_MEM_ADDR_WDT) 
`define JTAG_INST_ACTST_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_ACTST_ADDR_LSB (`JTAG_INST_ACTST_ADDR_MSB - `JTAG_INST_ACTST_ADDR_WDT + 1)
// Bank
`define JTAG_INST_ACTST_BANK_WDT (`ACT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_ACTST_BANK_MSB (`JTAG_INST_ACTST_ADDR_LSB - 1)
`define JTAG_INST_ACTST_BANK_LSB (`JTAG_INST_ACTST_BANK_MSB - `JTAG_INST_ACTST_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_ACTST_ADDR_WDT-1:0] get_actst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_actst_addr = instruction[`JTAG_INST_ACTST_ADDR_MSB:`JTAG_INST_ACTST_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_actst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_ACTST_ADDR_WDT-1:0] addr;
   begin
      set_actst_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_ACTST_ADDR_MSB+1], addr, instruction[`JTAG_INST_ACTST_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_ACTST_BANK_WDT-1:0] get_actst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_actst_bank = instruction[`JTAG_INST_ACTST_BANK_MSB:`JTAG_INST_ACTST_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_actst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_ACTST_BANK_WDT-1:0] bank;
   begin
      set_actst_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_ACTST_BANK_MSB+1], bank, instruction[`JTAG_INST_ACTST_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// ACTLD
// Address
`define JTAG_INST_ACTLD_ADDR_WDT (`ACT_MEM_ADDR_WDT) 
`define JTAG_INST_ACTLD_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_ACTLD_ADDR_LSB (`JTAG_INST_ACTLD_ADDR_MSB - `JTAG_INST_ACTLD_ADDR_WDT + 1)
// Bank
`define JTAG_INST_ACTLD_BANK_WDT (`ACT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_ACTLD_BANK_MSB (`JTAG_INST_ACTLD_ADDR_LSB - 1)
`define JTAG_INST_ACTLD_BANK_LSB (`JTAG_INST_ACTLD_BANK_MSB - `JTAG_INST_ACTLD_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_ACTLD_ADDR_WDT-1:0] get_actld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_actld_addr = instruction[`JTAG_INST_ACTLD_ADDR_MSB:`JTAG_INST_ACTLD_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_actld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_ACTLD_ADDR_WDT-1:0] addr;
   begin
      set_actld_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_ACTLD_ADDR_MSB+1], addr, instruction[`JTAG_INST_ACTLD_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_ACTLD_BANK_WDT-1:0] get_actld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_actld_bank = instruction[`JTAG_INST_ACTLD_BANK_MSB:`JTAG_INST_ACTLD_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_actld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_ACTLD_BANK_WDT-1:0] bank;
   begin
      set_actld_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_ACTLD_BANK_MSB+1], bank, instruction[`JTAG_INST_ACTLD_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// WGTST
// Address
`define JTAG_INST_WGTST_ADDR_WDT (`WGT_MEM_ADDR_WDT_WR) 
`define JTAG_INST_WGTST_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_WGTST_ADDR_LSB (`JTAG_INST_WGTST_ADDR_MSB - `JTAG_INST_WGTST_ADDR_WDT + 1)
// Bank
`define JTAG_INST_WGTST_BANK_WDT (`WGT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_WGTST_BANK_MSB (`JTAG_INST_WGTST_ADDR_LSB - 1)
`define JTAG_INST_WGTST_BANK_LSB (`JTAG_INST_WGTST_BANK_MSB - `JTAG_INST_WGTST_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_WGTST_ADDR_WDT-1:0] get_wgtst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_wgtst_addr = instruction[`JTAG_INST_WGTST_ADDR_MSB:`JTAG_INST_WGTST_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_wgtst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_WGTST_ADDR_WDT-1:0] addr;
   begin
      set_wgtst_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_WGTST_ADDR_MSB+1], addr, instruction[`JTAG_INST_WGTST_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_WGTST_BANK_WDT-1:0] get_wgtst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_wgtst_bank = instruction[`JTAG_INST_WGTST_BANK_MSB:`JTAG_INST_WGTST_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_wgtst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_WGTST_BANK_WDT-1:0] bank;
   begin
      set_wgtst_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_WGTST_BANK_MSB+1], bank, instruction[`JTAG_INST_WGTST_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// WGTLD
// Address
`define JTAG_INST_WGTLD_ADDR_WDT (`WGT_MEM_ADDR_WDT_RD) 
`define JTAG_INST_WGTLD_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_WGTLD_ADDR_LSB (`JTAG_INST_WGTLD_ADDR_MSB - `JTAG_INST_WGTLD_ADDR_WDT + 1)
// Bank
`define JTAG_INST_WGTLD_BANK_WDT (`WGT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_WGTLD_BANK_MSB (`JTAG_INST_WGTLD_ADDR_LSB - 1)
`define JTAG_INST_WGTLD_BANK_LSB (`JTAG_INST_WGTLD_BANK_MSB - `JTAG_INST_WGTLD_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_WGTLD_ADDR_WDT-1:0] get_wgtld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_wgtld_addr = instruction[`JTAG_INST_WGTLD_ADDR_MSB:`JTAG_INST_WGTLD_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_wgtld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_WGTLD_ADDR_WDT-1:0] addr;
   begin
      set_wgtld_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_WGTLD_ADDR_MSB+1], addr, instruction[`JTAG_INST_WGTLD_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_WGTLD_BANK_WDT-1:0] get_wgtld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_wgtld_bank = instruction[`JTAG_INST_WGTLD_BANK_MSB:`JTAG_INST_WGTLD_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_wgtld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_WGTLD_BANK_WDT-1:0] bank;
   begin
      set_wgtld_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_WGTLD_BANK_MSB+1], bank, instruction[`JTAG_INST_WGTLD_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// OUTST
// Address
`define JTAG_INST_OUTST_ADDR_WDT (`OUT_MEM_ADDR_WDT) 
`define JTAG_INST_OUTST_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_OUTST_ADDR_LSB (`JTAG_INST_OUTST_ADDR_MSB - `JTAG_INST_OUTST_ADDR_WDT + 1)
// Bank
`define JTAG_INST_OUTST_BANK_WDT (`ACT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_OUTST_BANK_MSB (`JTAG_INST_OUTST_ADDR_LSB - 1)
`define JTAG_INST_OUTST_BANK_LSB (`JTAG_INST_OUTST_BANK_MSB - `JTAG_INST_OUTST_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_OUTST_ADDR_WDT-1:0] get_outst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_outst_addr = instruction[`JTAG_INST_OUTST_ADDR_MSB:`JTAG_INST_OUTST_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_outst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_OUTST_ADDR_WDT-1:0] addr;
   begin
      set_outst_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_OUTST_ADDR_MSB+1], addr, instruction[`JTAG_INST_ACTST_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_OUTST_BANK_WDT-1:0] get_outst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_outst_bank = instruction[`JTAG_INST_OUTST_BANK_MSB:`JTAG_INST_OUTST_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_outst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_OUTST_BANK_WDT-1:0] bank;
   begin
      set_outst_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_OUTST_BANK_MSB+1], bank, instruction[`JTAG_INST_ACTST_BANK_LSB-1:0]};
   end
endfunction


////////////////////////////////////////
// OUTLD
// Address
`define JTAG_INST_OUTLD_ADDR_WDT (`OUT_MEM_ADDR_WDT) 
`define JTAG_INST_OUTLD_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_OUTLD_ADDR_LSB (`JTAG_INST_OUTLD_ADDR_MSB - `JTAG_INST_OUTLD_ADDR_WDT + 1)
// Bank
`define JTAG_INST_OUTLD_BANK_WDT (`OUT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_OUTLD_BANK_MSB (`JTAG_INST_OUTLD_ADDR_LSB - 1)
`define JTAG_INST_OUTLD_BANK_LSB (`JTAG_INST_OUTLD_BANK_MSB - `JTAG_INST_OUTLD_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_OUTLD_ADDR_WDT-1:0] get_outld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_outld_addr = instruction[`JTAG_INST_OUTLD_ADDR_MSB:`JTAG_INST_OUTLD_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_outld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_OUTLD_ADDR_WDT-1:0] addr;
   begin
      set_outld_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_OUTLD_ADDR_MSB+1], addr, instruction[`JTAG_INST_OUTLD_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_OUTLD_BANK_WDT-1:0] get_outld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_outld_bank = instruction[`JTAG_INST_OUTLD_BANK_MSB:`JTAG_INST_OUTLD_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_outld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_OUTLD_BANK_WDT-1:0] bank;
   begin
      set_outld_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_OUTLD_BANK_MSB+1], bank, instruction[`JTAG_INST_OUTLD_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// SEDST
// Address
`define JTAG_INST_SEDST_ADDR_WDT (3) 
`define JTAG_INST_SEDST_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_SEDST_ADDR_LSB (`JTAG_INST_SEDST_ADDR_MSB - `JTAG_INST_SEDST_ADDR_WDT + 1)
// Bank
`define JTAG_INST_SEDST_BANK_WDT (`WGT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_SEDST_BANK_MSB (`JTAG_INST_SEDST_ADDR_LSB - 1)
`define JTAG_INST_SEDST_BANK_LSB (`JTAG_INST_SEDST_BANK_MSB - `JTAG_INST_SEDST_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_SEDST_ADDR_WDT-1:0] get_sedst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_sedst_addr = instruction[`JTAG_INST_SEDST_ADDR_MSB:`JTAG_INST_SEDST_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_sedst_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_SEDST_ADDR_WDT-1:0] addr;
   begin
      set_sedst_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_SEDST_ADDR_MSB+1], addr, instruction[`JTAG_INST_SEDST_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_SEDST_BANK_WDT-1:0] get_sedst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_sedst_bank = instruction[`JTAG_INST_SEDST_BANK_MSB:`JTAG_INST_SEDST_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_sedst_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_SEDST_BANK_WDT-1:0] bank;
   begin
      set_sedst_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_SEDST_BANK_MSB+1], bank, instruction[`JTAG_INST_SEDST_BANK_LSB-1:0]};
   end
endfunction

////////////////////////////////////////
// SEDLD
// Address
// WJR: change magic number (also for SEDST)
`define JTAG_INST_SEDLD_ADDR_WDT (3) 
`define JTAG_INST_SEDLD_ADDR_MSB (`JTAG_INST_DAT_MSB)
`define JTAG_INST_SEDLD_ADDR_LSB (`JTAG_INST_SEDLD_ADDR_MSB - `JTAG_INST_SEDLD_ADDR_WDT + 1)
// Bank
`define JTAG_INST_SEDLD_BANK_WDT (`WGT_MEM_BANK_ADDR_WDT)
`define JTAG_INST_SEDLD_BANK_MSB (`JTAG_INST_SEDLD_ADDR_LSB - 1)
`define JTAG_INST_SEDLD_BANK_LSB (`JTAG_INST_SEDLD_BANK_MSB - `JTAG_INST_SEDLD_BANK_WDT + 1)
// Set/Get
// Address
function [`JTAG_INST_SEDLD_ADDR_WDT-1:0] get_sedld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_sedld_addr = instruction[`JTAG_INST_SEDLD_ADDR_MSB:`JTAG_INST_SEDLD_ADDR_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_sedld_addr;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_SEDLD_ADDR_WDT-1:0] addr;
   begin
      set_sedld_addr = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_SEDLD_ADDR_MSB+1], addr, instruction[`JTAG_INST_SEDLD_ADDR_LSB-1:0]};
   end
endfunction
// Bank
function [`JTAG_INST_SEDLD_BANK_WDT-1:0] get_sedld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   begin
      get_sedld_bank = instruction[`JTAG_INST_SEDLD_BANK_MSB:`JTAG_INST_SEDLD_BANK_LSB];
   end
endfunction
function [`JTAG_INST_WDT-1:0] set_sedld_bank;
   input    [`JTAG_INST_WDT-1:0] instruction;
   input    [`JTAG_INST_SEDLD_BANK_WDT-1:0] bank;
   begin
      set_sedld_bank = {instruction[`JTAG_INST_WDT-1:`JTAG_INST_SEDLD_BANK_MSB+1], bank, instruction[`JTAG_INST_SEDLD_BANK_LSB-1:0]};
   end
endfunction




////////////////////////////////////////
// Configuration Registers
// Note: Define the width of fields in the top section, so these propagate properly into the full register and MSB/LSB definitions.
////////////////////////////////////////
// Base Address Width           `ACT_MEM_ADDR_WDT
`define CFG_REG_BASE_ADDR_WDT    (`ACT_MEM_ADDR_WDT)
// Y-Padding Width              `PAD_WDT
`define CFG_REG_Y_PAD_WDT        (`PAD_WDT)
// Precision Width              `PREC_WDT
`define CFG_REG_PREC_WDT         (`PREC_WDT)
// ROI Height Width             `ROI_HGT_WDT
`define CFG_REG_ROI_HGT_WDT      (`ROI_HGT_WDT)
// Stream Length Width          `SLEN_WDT
`define CFG_REG_SLEN_WDT         (`SLEN_WDT)
//// Overlap Control Width        1
//`define CFG_REG_OVLP_WDT         (1)
// ROI Count Width              `ROI_COUNT_WDT
`define CFG_REG_ROI_COUNT_WDT    (`ROI_COUNT_WDT)
// Dense Mode Control Width     1
`define CFG_REG_DNS_MODE_WDT     (1)
// Time Channel Stride Width    `BANK_IDX_WDT
`define CFG_REG_CHNL_STR_WDT     (`BANK_IDX_WDT)
// ET Threshold Width           `BANK_CTR_WIDTH+`SC_ACC_WIDTH   // From ERI-DA_HEADERS.vh
`define CFG_REG_ET_THOLD_WDT     (`GCSP)
// LFSR_option_sel
`define CFG_REG_LFSR_OPTION_WDT  (2)
// vthres
`define CFG_REG_VTHRES_WDT       (`N_B*4)
// bank_en
`define CFG_REG_BANK_EN_WDT      (`N_B)
// Simplify Controls Banks
`define CFG_REG_SIMPL_CTRL_BANKS_WDT     (1)
// ET_en_gate
`define CFG_REG_ET_EN_GATE_WDT     (1)
// Simplify Controls Global Counters
`define CFG_REG_SIMPL_CTRL_GLACC_WDT     (1)
// Over-ride clearing operation of Bank-Counter Latched registers. Clearing is needed for ET, Else not needed.
`define CFG_REG_BANK_CTR_CLR_OVERRIDE_WDT     (1)

//// Global Accum Config Widths    1 (Simplify Control Signals internally for Global Accumulator) + 1 (Disable ET functionality Internally)
//`define CFG_REG_GLACC_WDT        (1 + 1) 



///////////////////////////////////////
// Full Configuration Register Block Definitions
// This should include the widths of each value defined in the above section.
`define CFG_REG_WDT_RAW             (`CFG_REG_BASE_ADDR_WDT + `CFG_REG_Y_PAD_WDT + `CFG_REG_PREC_WDT + `CFG_REG_ROI_HGT_WDT + `CFG_REG_SLEN_WDT + `CFG_REG_ROI_COUNT_WDT + `CFG_REG_DNS_MODE_WDT + `CFG_REG_CHNL_STR_WDT + `CFG_REG_ET_THOLD_WDT + `CFG_REG_LFSR_OPTION_WDT + `CFG_REG_VTHRES_WDT + `CFG_REG_BANK_EN_WDT + `CFG_REG_SIMPL_CTRL_BANKS_WDT + `CFG_REG_ET_EN_GATE_WDT + `CFG_REG_SIMPL_CTRL_GLACC_WDT + `CFG_REG_BANK_CTR_CLR_OVERRIDE_WDT)

//VKJ: Making the bit-width of the register a neareset multiple of 32
`define CFG_REG_WDT_TEMP         ((`CFG_REG_WDT_RAW%32) ? (`CFG_REG_WDT_RAW/32+1) : (`CFG_REG_WDT_RAW/32))
`define CFG_REG_WDT              (`CFG_REG_WDT_TEMP*32)

///////////////////////////////////////
// Define MSB/LSB for Each Configuration Field

// MSB of the Full Configuration Register Block  (No LSB defined, since LSB is 0.)
`define CFG_REG_MSB              (`CFG_REG_WDT_RAW - 1)

// Addresses are assigned from MSB down.

// Base address
`define CFG_REG_BASE_ADDR_MSB    (`CFG_REG_MSB)
`define CFG_REG_BASE_ADDR_LSB    (`CFG_REG_BASE_ADDR_MSB - `CFG_REG_BASE_ADDR_WDT + 1)

// Y padding size
`define CFG_REG_Y_PAD_MSB        (`CFG_REG_BASE_ADDR_LSB - 1)
`define CFG_REG_Y_PAD_LSB        (`CFG_REG_Y_PAD_MSB - `CFG_REG_Y_PAD_WDT + 1)

// Precision
`define CFG_REG_PREC_MSB         (`CFG_REG_Y_PAD_LSB - 1)
`define CFG_REG_PREC_LSB         (`CFG_REG_PREC_MSB - `CFG_REG_PREC_WDT + 1)

// ROI Height
`define CFG_REG_ROI_HGT_MSB      (`CFG_REG_PREC_LSB - 1)
`define CFG_REG_ROI_HGT_LSB      (`CFG_REG_ROI_HGT_MSB - `CFG_REG_ROI_HGT_WDT + 1)

// Stream length
`define CFG_REG_SLEN_MSB         (`CFG_REG_ROI_HGT_LSB - 1)
`define CFG_REG_SLEN_LSB         (`CFG_REG_SLEN_MSB - `CFG_REG_SLEN_WDT + 1)

//// Overlap
//`define CFG_REG_OVLP_MSB         (`CFG_REG_SLEN_LSB - 1)
//`define CFG_REG_OVLP_LSB         (`CFG_REG_OVLP_MSB - `CFG_REG_OVLP_WDT + 1)

// ROI Count
`define CFG_REG_ROI_COUNT_MSB    (`CFG_REG_SLEN_LSB - 1)
`define CFG_REG_ROI_COUNT_LSB    (`CFG_REG_ROI_COUNT_MSB - `CFG_REG_ROI_COUNT_WDT + 1)

// Dense mode control
`define CFG_REG_DNS_MODE_MSB     (`CFG_REG_ROI_COUNT_LSB - 1)
`define CFG_REG_DNS_MODE_LSB     (`CFG_REG_DNS_MODE_MSB - `CFG_REG_DNS_MODE_WDT + 1)

// Time channel stride width
`define CFG_REG_CHNL_STR_MSB     (`CFG_REG_DNS_MODE_LSB - 1)
`define CFG_REG_CHNL_STR_LSB     (`CFG_REG_CHNL_STR_MSB - `CFG_REG_CHNL_STR_WDT + 1)

// ET Threshold
`define CFG_REG_ET_THOLD_MSB     (`CFG_REG_CHNL_STR_LSB - 1)
`define CFG_REG_ET_THOLD_LSB     (`CFG_REG_ET_THOLD_MSB - `CFG_REG_ET_THOLD_WDT + 1)

// LFSR_option_sel
`define CFG_REG_LFSR_OPTION_MSB  (`CFG_REG_ET_THOLD_LSB - 1)
`define CFG_REG_LFSR_OPTION_LSB  (`CFG_REG_LFSR_OPTION_MSB - `CFG_REG_LFSR_OPTION_WDT + 1)

// vthres
`define CFG_REG_VTHRES_MSB       (`CFG_REG_LFSR_OPTION_LSB - 1)
`define CFG_REG_VTHRES_LSB       (`CFG_REG_VTHRES_MSB - `CFG_REG_VTHRES_WDT + 1)

// bank_en
`define CFG_REG_BANK_EN_MSB      (`CFG_REG_VTHRES_LSB - 1)
`define CFG_REG_BANK_EN_LSB      (`CFG_REG_BANK_EN_MSB - `CFG_REG_BANK_EN_WDT + 1)

// ET_en_gate
`define CFG_REG_ET_EN_GATE_MSB     (`CFG_REG_BANK_EN_LSB - 1)
`define CFG_REG_ET_EN_GATE_LSB     (`CFG_REG_ET_EN_GATE_MSB   - `CFG_REG_ET_EN_GATE_WDT + 1)

// Simplify Controls Banks
`define CFG_REG_SIMPL_CTRL_BANKS_MSB     (`CFG_REG_ET_EN_GATE_LSB - 1)
`define CFG_REG_SIMPL_CTRL_BANKS_LSB     (`CFG_REG_SIMPL_CTRL_BANKS_MSB   - `CFG_REG_SIMPL_CTRL_BANKS_WDT + 1)

// Simplify Controls Global Counters
`define CFG_REG_SIMPL_CTRL_GLACC_MSB     (`CFG_REG_SIMPL_CTRL_BANKS_LSB - 1)
`define CFG_REG_SIMPL_CTRL_GLACC_LSB     (`CFG_REG_SIMPL_CTRL_GLACC_MSB   - `CFG_REG_SIMPL_CTRL_GLACC_WDT + 1)

// Over-ride clearing operation of Bank-Counter Latched registers. Clearing is needed for ET, Else not needed.
`define CFG_REG_BANK_CTR_CLR_OVERRIDE_MSB     (`CFG_REG_SIMPL_CTRL_GLACC_LSB - 1)
`define CFG_REG_BANK_CTR_CLR_OVERRIDE_LSB     (`CFG_REG_BANK_CTR_CLR_OVERRIDE_MSB   - `CFG_REG_BANK_CTR_CLR_OVERRIDE_WDT + 1)



// Set/Get
// Base Address
function [`CFG_REG_BASE_ADDR_WDT-1:0] get_cfg_addr;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_addr = cfg_reg[`CFG_REG_BASE_ADDR_MSB:`CFG_REG_BASE_ADDR_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_addr;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_BASE_ADDR_WDT-1:0] addr;
   begin
      set_cfg_addr = {addr, cfg_reg[`CFG_REG_BASE_ADDR_LSB-1:0]};
   end
endfunction
// Y padding
function [`CFG_REG_Y_PAD_WDT-1:0] get_cfg_ypad;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_ypad = cfg_reg[`CFG_REG_Y_PAD_MSB:`CFG_REG_Y_PAD_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_ypad;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_Y_PAD_WDT-1:0] ypad;
   begin
      set_cfg_ypad = {cfg_reg[`CFG_REG_MSB:`CFG_REG_Y_PAD_MSB+1], ypad, cfg_reg[`CFG_REG_Y_PAD_LSB-1:0]};
   end
endfunction
// Precision
function [`CFG_REG_PREC_WDT-1:0] get_cfg_prec;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_prec = cfg_reg[`CFG_REG_PREC_MSB:`CFG_REG_PREC_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_prec;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_PREC_WDT-1:0] prec;
   begin
      set_cfg_prec = {cfg_reg[`CFG_REG_MSB:`CFG_REG_PREC_MSB+1], prec, cfg_reg[`CFG_REG_PREC_LSB-1:0]};
   end
endfunction
// ROI Height
function [`CFG_REG_ROI_HGT_WDT-1:0] get_cfg_roih;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_roih = cfg_reg[`CFG_REG_ROI_HGT_MSB:`CFG_REG_ROI_HGT_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_roih;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_ROI_HGT_WDT-1:0] roih;
   begin
      set_cfg_roih = {cfg_reg[`CFG_REG_MSB:`CFG_REG_ROI_HGT_MSB+1], roih, cfg_reg[`CFG_REG_ROI_HGT_LSB-1:0]};
   end
endfunction
// Stream length
function [`CFG_REG_SLEN_WDT-1:0] get_cfg_slen;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_slen = cfg_reg[`CFG_REG_SLEN_MSB:`CFG_REG_SLEN_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_slen;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_SLEN_WDT-1:0] slen;
   begin
      set_cfg_slen = {cfg_reg[`CFG_REG_MSB:`CFG_REG_SLEN_MSB+1], slen, cfg_reg[`CFG_REG_SLEN_LSB-1:0]};
   end
endfunction
//// Overlap control
//function get_cfg_ovlp;
//   input    [`CFG_REG_WDT-1:0] cfg_reg;
//   begin
//      get_cfg_ovlp = cfg_reg[`CFG_REG_SLEN_MSB];
//   end
//endfunction
//function [`CFG_REG_WDT-1:0] set_cfg_ovlp;
//   input    [`CFG_REG_WDT-1:0] cfg_reg;
//   input    ovlp;
//   begin
//      set_cfg_ovlp = {cfg_reg[`CFG_REG_MSB:`CFG_REG_OVLP_MSB+1], ovlp, cfg_reg[`CFG_REG_OVLP_LSB-1:0]};
//   end
//endfunction
// ROI Count
function [`CFG_REG_ROI_COUNT_WDT-1:0] get_cfg_roic;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_roic = cfg_reg[`CFG_REG_ROI_COUNT_MSB:`CFG_REG_ROI_COUNT_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_roic;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_ROI_COUNT_WDT-1:0] roic;
   begin
      set_cfg_roic = {cfg_reg[`CFG_REG_MSB:`CFG_REG_ROI_COUNT_MSB+1], roic, cfg_reg[`CFG_REG_ROI_COUNT_LSB-1:0]};
   end
endfunction
// Dense mode
function get_cfg_dnsm;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_dnsm = cfg_reg[`CFG_REG_DNS_MODE_MSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_dnsm;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    dnsm;
   begin
      set_cfg_dnsm = {cfg_reg[`CFG_REG_MSB:`CFG_REG_DNS_MODE_MSB+1], dnsm, cfg_reg[`CFG_REG_DNS_MODE_LSB-1:0]};
   end
endfunction
// Time channel stride
function [`CFG_REG_CHNL_STR_WDT-1:0] get_cfg_chns;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_chns = cfg_reg[`CFG_REG_CHNL_STR_MSB:`CFG_REG_CHNL_STR_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_chns;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_CHNL_STR_WDT-1:0] chns;
   begin
      set_cfg_chns = {cfg_reg[`CFG_REG_MSB:`CFG_REG_CHNL_STR_MSB+1], chns, cfg_reg[`CFG_REG_CHNL_STR_LSB-1:0]};
   end
endfunction
// ET Threshold
function [`CFG_REG_ET_THOLD_WDT-1:0] get_cfg_etth;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_etth = cfg_reg[`CFG_REG_ET_THOLD_MSB:`CFG_REG_ET_THOLD_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_etth;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_ET_THOLD_WDT-1:0] etth;
   begin
      set_cfg_etth = {cfg_reg[`CFG_REG_MSB:`CFG_REG_ET_THOLD_MSB+1], etth, cfg_reg[`CFG_REG_ET_THOLD_LSB-1:0]};
   end
endfunction


// LFSR_OPTION_SEL
function [`CFG_REG_LFSR_OPTION_WDT-1:0] get_cfg_lfsroptsel;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_lfsroptsel = cfg_reg[`CFG_REG_LFSR_OPTION_MSB:`CFG_REG_LFSR_OPTION_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_lfsroptsel;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_LFSR_OPTION_WDT-1:0] lfsroptsel;
   begin
      set_cfg_lfsroptsel = {cfg_reg[`CFG_REG_MSB:`CFG_REG_LFSR_OPTION_MSB+1], lfsroptsel, cfg_reg[`CFG_REG_LFSR_OPTION_LSB-1:0]};
   end
endfunction



// VTHRES
function [`CFG_REG_VTHRES_WDT-1:0] get_cfg_vthres;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_vthres = cfg_reg[`CFG_REG_VTHRES_MSB:`CFG_REG_VTHRES_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_vthres;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_VTHRES_WDT-1:0] vthres;
   begin
      set_cfg_vthres = {cfg_reg[`CFG_REG_MSB:`CFG_REG_VTHRES_MSB+1], vthres, cfg_reg[`CFG_REG_VTHRES_LSB-1:0]};
   end
endfunction


// BANK_EN
function [`CFG_REG_BANK_EN_WDT-1:0] get_cfg_bank_en;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_bank_en = cfg_reg[`CFG_REG_BANK_EN_MSB:`CFG_REG_BANK_EN_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_bank_en;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_BANK_EN_WDT-1:0] bank_en;
   begin
      set_cfg_bank_en = {cfg_reg[`CFG_REG_MSB:`CFG_REG_BANK_EN_MSB+1], bank_en, cfg_reg[`CFG_REG_BANK_EN_LSB-1:0]};
   end
endfunction

// ET_EN_GATE
function [`CFG_REG_ET_EN_GATE_WDT-1:0] get_cfg_et_en_gate;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_et_en_gate = cfg_reg[`CFG_REG_ET_EN_GATE_MSB:`CFG_REG_ET_EN_GATE_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_et_en_gate;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_ET_EN_GATE_WDT-1:0] et_en_gate;
   begin
      set_cfg_et_en_gate = {cfg_reg[`CFG_REG_MSB:`CFG_REG_ET_EN_GATE_MSB+1], et_en_gate, cfg_reg[`CFG_REG_ET_EN_GATE_LSB-1:0]};
   end
endfunction

// SIMPL_CTRL_BANKS
function [`CFG_REG_SIMPL_CTRL_BANKS_WDT-1:0] get_cfg_simpl_ctrl_banks;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_simpl_ctrl_banks = cfg_reg[`CFG_REG_SIMPL_CTRL_BANKS_MSB:`CFG_REG_SIMPL_CTRL_BANKS_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_simpl_ctrl_banks;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_SIMPL_CTRL_BANKS_WDT-1:0] simpl_ctrl_banks;
   begin
      set_cfg_simpl_ctrl_banks = {cfg_reg[`CFG_REG_MSB:`CFG_REG_SIMPL_CTRL_BANKS_MSB+1], simpl_ctrl_banks, cfg_reg[`CFG_REG_SIMPL_CTRL_BANKS_LSB-1:0]};
   end
endfunction

// SIMPL_CTRL_GLACC
function [`CFG_REG_SIMPL_CTRL_GLACC_WDT-1:0] get_cfg_simpl_ctrl_glacc;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_simpl_ctrl_glacc = cfg_reg[`CFG_REG_SIMPL_CTRL_GLACC_MSB:`CFG_REG_SIMPL_CTRL_GLACC_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_simpl_ctrl_glacc;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_SIMPL_CTRL_GLACC_WDT-1:0] simpl_ctrl_glacc;
   begin
      set_cfg_simpl_ctrl_glacc = {cfg_reg[`CFG_REG_MSB:`CFG_REG_SIMPL_CTRL_GLACC_MSB+1], simpl_ctrl_glacc, cfg_reg[`CFG_REG_SIMPL_CTRL_GLACC_LSB-1:0]};
   end
endfunction

// BANK_CTR_CLR_OVERRIDE
function [`CFG_REG_BANK_CTR_CLR_OVERRIDE_WDT-1:0] get_cfg_bank_ctr_clr_override;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   begin
      get_cfg_bank_ctr_clr_override = cfg_reg[`CFG_REG_BANK_CTR_CLR_OVERRIDE_MSB:`CFG_REG_BANK_CTR_CLR_OVERRIDE_LSB];
   end
endfunction
function [`CFG_REG_WDT-1:0] set_cfg_bank_ctr_clr_override;
   input    [`CFG_REG_WDT-1:0] cfg_reg;
   input    [`CFG_REG_BANK_CTR_CLR_OVERRIDE_WDT-1:0] bank_ctr_clr_override;
   begin
      set_cfg_bank_ctr_clr_override = {cfg_reg[`CFG_REG_MSB:`CFG_REG_BANK_CTR_CLR_OVERRIDE_MSB+1], bank_ctr_clr_override}; //, cfg_reg[`CFG_REG_BANK_CTR_CLR_OVERRIDE_LSB-1:0]};
   end
endfunction


`endif
 
