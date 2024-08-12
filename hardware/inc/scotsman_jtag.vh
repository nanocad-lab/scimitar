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
// Header name : scotsman_jtag
// Created     : Mon 19 Sep 2022 
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : ERIDA JTAG configuration 
//               
/////////////////////////////////////////////////////////////////////////////

`ifndef _SCOTSMAN_JTAG_VH_
`define _SCOTSMAN_JTAG_VH_

`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"
`include "scotsman_isa.vh"

////////////////////////////////////////
// JTAG Generic  Configurations
//let max(a,b) = (a > b) ? a : b;

// Opcode width
`define JTAG_OPC_WDT                            5
// State machine state width
`define JTAG_FSM_WDT                            5

////////////////////////////////////////          
// JTAG Opcodes                                   
`define JTAG_OPC_RESET_TAP                      `JTAG_OPC_WDT'b00000
`define JTAG_OPC_RESET_RTI                      `JTAG_OPC_WDT'b00001
`define JTAG_OPC_RTI_SHIFT_IR_PAUSE             `JTAG_OPC_WDT'b00010
`define JTAG_OPC_RTI_SHIFT_IR_RTI               `JTAG_OPC_WDT'b00011
`define JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_PAUSE    `JTAG_OPC_WDT'b00100
`define JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_RTI      `JTAG_OPC_WDT'b00101
`define JTAG_OPC_PAUSE_SHIFT_IR_PAUSE           `JTAG_OPC_WDT'b00110
`define JTAG_OPC_PAUSE_SHIFT_IR_RTI             `JTAG_OPC_WDT'b00111
`define JTAG_OPC_PAUSE_SHIFT_IR_SHIFT_DR_PAUSE  `JTAG_OPC_WDT'b01000
`define JTAG_OPC_PAUSE_SHIFT_IR_SHIFT_DR_RTI    `JTAG_OPC_WDT'b01001
`define JTAG_OPC_PAUSE_SHIFT_DR_PAUSE           `JTAG_OPC_WDT'b01010
`define JTAG_OPC_PAUSE_SHIFT_DR_RTI             `JTAG_OPC_WDT'b01011
`define JTAG_OPC_RTI_SHIFT_DR_PAUSE             `JTAG_OPC_WDT'b01100
`define JTAG_OPC_RTI_SHIFT_DR_RTI               `JTAG_OPC_WDT'b01101
`define JTAG_OPC_WAIT                           `JTAG_OPC_WDT'b01111
`define JTAG_OPC_MEM_DUMP_START                 `JTAG_OPC_WDT'b10000
`define JTAG_OPC_MEM_DUMP_END                   `JTAG_OPC_WDT'b10001

// TAP FSM State values
`define JTAG_S_TEST_LOGIC_RESET                 `JTAG_FSM_WDT'b00000
`define JTAG_S_RUN_TEST_IDLE                    `JTAG_FSM_WDT'b00001
`define JTAG_S_SELECT_DR_SCAN                   `JTAG_FSM_WDT'b00010
`define JTAG_S_CAPTURE_DR                       `JTAG_FSM_WDT'b00011
`define JTAG_S_SHIFT_DR                         `JTAG_FSM_WDT'b00100
`define JTAG_S_EXIT1_DR                         `JTAG_FSM_WDT'b00101
`define JTAG_S_PAUSE_DR                         `JTAG_FSM_WDT'b00110
`define JTAG_S_EXIT2_DR                         `JTAG_FSM_WDT'b00111
`define JTAG_S_UPDATE_DR                        `JTAG_FSM_WDT'b01000
`define JTAG_S_SELECT_IR_SCAN                   `JTAG_FSM_WDT'b10010
`define JTAG_S_CAPTURE_IR                       `JTAG_FSM_WDT'b10011
`define JTAG_S_SHIFT_IR                         `JTAG_FSM_WDT'b10100
`define JTAG_S_EXIT1_IR                         `JTAG_FSM_WDT'b10101
`define JTAG_S_PAUSE_IR                         `JTAG_FSM_WDT'b10110
`define JTAG_S_EXIT2_IR                         `JTAG_FSM_WDT'b10111
`define JTAG_S_UPDATE_IR                        `JTAG_FSM_WDT'b11000

// JTAG Instructions
`define JTAG_INST_EXTEST                        4'b0000
`define JTAG_INST_SAMPLE_PRELOAD                4'b0001
`define JTAG_INST_IDCODE                        4'b0010
`define JTAG_INST_USERREG                       4'b1000
`define JTAG_INST_BYPASS                        4'b1111

////////////////////////////////////////
// JTAG Chip Specific

`ifdef MACLEOD
`define JTAG_DEV_VERSION                        4'b0001
`else
`define JTAG_DEV_VERSION                        4'b0000
`endif
`define JTAG_DEV_PART_NUM                       16'b1
`define JTAG_DEV_MFG_ID                         11'b00101001001  // Manufacturer's ID = 0x55(U) + 0x43(C) + 0x4C(L) + 0x65(A)

`define JTAG_DEVICE_ID_VAL                      {`JTAG_DEV_VERSION,`JTAG_DEV_PART_NUM,`JTAG_DEV_MFG_ID,1'b1}
`define JTAG_NUM_USER_REG                       5       //[10/14/22]VKJ: 4 + 1 (config-reg)
`define JTAG_USERREG_SEL_WIDTH                  $clog2(`JTAG_NUM_USER_REG)
`define JTAG_INST_REG_WIDTH                     6+`JTAG_USERREG_SEL_WIDTH

// JTAG User Register Numbers
`define JTAG_UDR_INST_REG_NUM                   0
`define JTAG_UDR_MEM_DATA_REG_NUM               1
`define JTAG_UDR_KICKOFF_REG_NUM                2
`define JTAG_UDR_MBIST_EN_REG_NUM               3
`define JTAG_UDR_CFG_REG_NUM                    4        //[10/14/22]VKJ: Moving config reg to JTAG

// JTAG User Register Widths
`define JTAG_UDR_INST_REG_WDT                   32
// WJR: need to figure out how to parametrize this using max()
//`define JTAG_UDR_MEM_DATA_REG_WDT               {max(max(max(`ACT_MEM_DATA_WDT, `OUT_MEM_DATA_WDT), max(`WGT_MEM_DATA_WDT_WR, `WGT_MEM_DATA_WDT_RD)), max(`CFG_REG_WDT, `N_L))}
`define JTAG_UDR_MEM_DATA_REG_WDT               768
`define JTAG_UDR_KICKOFF_REG_WDT                32
`define JTAG_UDR_CFG_REG_WDT                    `CFG_REG_WDT  //[10/14/22]VKJ: Moving config reg to JTAG 
//`define JTAG_UDR_MEM_CTRL_REG_WDT               32

// JTAG User Register Reset Values
//`define JTAG_UDR_MEM_CTRL_REG_RST_VAL           {`ACSTC_SRAM_CTRL_RAWLM,`ACSTC_SRAM_CTRL_RAWL,`ACSTC_SRAM_CTRL_WABLM,`ACSTC_SRAM_CTRL_WABL,`ACSTC_SRAM_CTRL_EMAS,`ACSTC_SRAM_CTRL_EMAW,`ACSTC_SRAM_CTRL_EMA}

`endif
