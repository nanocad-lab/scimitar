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
// Header name : scotsman_conf
// Created     : Mon 06 Jun 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : SCOTSMAN In-Situ SCIM Architecture configuration
//               
/////////////////////////////////////////////////////////////////////////////

`ifndef _SCOTSMAN_CONF_VH_
`define _SCOTSMAN_CONF_VH_

////////////////////////////////////////
// Includes
//`include "scotsman_isa.vh"
//`define FPGA

////////////////////////////////////////
// Check if configuration is specified
// Generic 8 bank config
`ifdef MACLEOD
   `define CONF_VALID
// Reduced 2 bank config
`elsif MACIVER
   `define CONF_VALID
`endif

// If not, use default (MACLEOD)
`ifndef CONF_VALID
   `define MACLEOD
`endif

////////////////////////////////////////
// Use ideal RNG
// Non-synthesisable
`ifdef RNG
   `define IDEAL_RNG             1'b1
`endif

////////////////////////////////////////
// Use binary accumulation 
`ifdef BIN_ACC
   `define BIN_ACC               1'b1
`endif

////////////////////////////////////////
// Glitch-free clock mux
`define CLKMUX_GLITCH_FREE       1

////////////////////////////////////////
// Pipelined adder trees
`ifdef MACLEOD
   `define EWAT_PIPE                1
`endif

////////////////////////////////////////
// Activation Memory 
// Memory depth
`define ACT_MEM_DEPTH            512 
// Address width
`define ACT_MEM_ADDR_WDT         ($clog2(`ACT_MEM_DEPTH))
// Banks
`ifdef MACLEOD
   `define ACT_MEM_BANKS            8
`elsif MACIVER
   `define ACT_MEM_BANKS            2
`endif
// Bank Address width
`define ACT_MEM_BANK_ADDR_WDT    ($clog2(`ACT_MEM_BANKS))
// Data width in memory
`define ACT_MEM_DAT              1
// Number of values in a word
`define ACT_MEM_DAT_NO           64
// Activation memory word width (write)
`define ACT_MEM_DATA_WDT         (`ACT_MEM_DAT * `ACT_MEM_DAT_NO)
// Read sizes
`define ACT_MEM_DAT_NO_HALF      28
`define ACT_MEM_DAT_NO_OVLP      8
// Read port width
`define ACT_MEM_DATA_WDT_HALF    (`ACT_MEM_DAT * `ACT_MEM_DAT_NO_HALF)
`define ACT_MEM_DATA_WDT_OVLP    (`ACT_MEM_DAT * `ACT_MEM_DAT_NO_OVLP)
`define ACT_MEM_DATA_WDT_RD      (`ACT_MEM_DAT * (`ACT_MEM_DAT_NO_HALF + `ACT_MEM_DAT_NO_OVLP))
// Max ROI size
`define MAX_ROI_HEIGHT           64
// ROI size port width
`define ROI_HGT_WDT              ($clog2(`MAX_ROI_HEIGHT))
// Maximum ROI count
`define MAX_ROI_COUNT            128
// ROI count width
`define ROI_COUNT_WDT            ($clog2(`MAX_ROI_COUNT))

////////////////////////////////////////
// Activation memory read instructions
`define ACT_MEM_RD_INST_WDT      2
// JTAG read
`define ACT_MEM_RD_INST_JTAG     (`ACT_MEM_RD_INST_WDT'b00)
// Left read
`define ACT_MEM_RD_INST_LEFT     (`ACT_MEM_RD_INST_WDT'b01)
// Right read
`define ACT_MEM_RD_INST_RGTH     (`ACT_MEM_RD_INST_WDT'b10)

////////////////////////////////////////
// Weight Memory 
// Banks
`ifdef MACLEOD
   `define WGT_MEM_BANKS            8
`elsif MACIVER
   `define WGT_MEM_BANKS            2
`endif
// Bank Address width
`define WGT_MEM_BANK_ADDR_WDT    ($clog2(`WGT_MEM_BANKS))
// Write configuration
// Memory depth 
`define WGT_MEM_DEPTH_WR         162 
// Address width
`ifndef AMS
`define WGT_MEM_ADDR_WDT_WR      ($clog2(`WGT_MEM_DEPTH_WR))
`else
`define WGT_MEM_ADDR_WDT_WR      8
`endif

// Data width in memory
`define WGT_MEM_DAT_WR           3
// Number of values in a word 
`define WGT_MEM_DAT_NO_WR        (`WGT_MEM_BANKS * 32)
// Weight memory word width 
`define WGT_MEM_DATA_WDT_WR      (`WGT_MEM_DAT_WR * `WGT_MEM_DAT_NO_WR)
// Read configuration
// Memory depth 
`define WGT_MEM_DEPTH_RD         486 
// Address width
`ifndef AMS
`define WGT_MEM_ADDR_WDT_RD      ($clog2(`WGT_MEM_DEPTH_RD))
`else
`define WGT_MEM_ADDR_WDT_RD      9
`endif

// Data width in memory
`define WGT_MEM_DAT_RD           1
// Number of values in a word 
`define WGT_MEM_DAT_NO_RD        (`WGT_MEM_BANKS * 32)
// Weight memory word width 
`define WGT_MEM_DATA_WDT_RD      (`WGT_MEM_DAT_RD * `WGT_MEM_DAT_NO_RD)


// Legacy JTAG support, should be removed (WJR)
`define ACSTC_INS_MEM_DEPTH            1024

////////////////////////////////////////
// Output Memory
// Memory depth
`define OUT_MEM_DEPTH           256
// Address width
`define OUT_MEM_ADDR_WDT        ($clog2(`OUT_MEM_DEPTH))
// Banks
`ifdef MACLEOD
   `define OUT_MEM_BANKS           8
`elsif MACIVER
   `define OUT_MEM_BANKS           2
`endif
// Bank Address width
`define OUT_MEM_BANK_ADDR_WDT   ($clog2(`OUT_MEM_BANKS))
// Number of filters
`define OUT_FLT_NO              32
// Output Memory Width (Single Output Memory Width Due to SRAM Compiler Constraints. Must be <= 160)
`define OUT_MEM_DATA_WDT        128
`define OUT_MEM_DATA_WDT_RD     `OUT_MEM_DATA_WDT
`define OUT_MEM_DEPTH_RD        `OUT_MEM_DEPTH

////////////////////////////////////////
// Activation data
// Unrolled maximum width
`define ACT_BUF_DAT              6
// Precision port 
`define PREC_WDT                 ($clog2(`ACT_BUF_DAT))

////////////////////////////////////////
// Activation Read Buffer
//`define ACT_BUF_BLOCKS           1
// Number of activations in the buffer block
//`define ACT_BUF_BLOCK_NO         64       //TODO: If we are going to use 64-wide blocks, need to change this constant.
`define ACT_BUF_BLOCK_NO         36
// Block width
`define ACT_BUF_BLOCK_WDT        (`ACT_BUF_BLOCK_NO*`ACT_BUF_DAT)
//`define ACT_BUF_BLOCK_ADDR_WDT   ($clog2(`ACT_BUF_BLOCKS))   //1

////////////////////////////////////////
// Activation SNGs
// Number of input values to the mux
`define ACT_SNG_MUX_VAL_IN       (`ACT_BUF_BLOCK_NO)
// Number of output values (not including overlap - this matches the number of array outputs)
`define ACT_SNG_MUX_VAL_OUT      16
// Number of MUX output values/SNGs per block, with overlap
`define ACT_SNG_BLOCK_COUNT      (`ACT_SNG_MUX_VAL_OUT+`MAC_CN_WDT-1)
// Activation SNG RNG data width
`define ACT_SNG_RNG_DAT          (`ACT_BUF_DAT-1)
// Activation SNG stream lenght width
`define ACT_SNG_SLN_WDT          3

////////////////////////////////////////
// Weight data
// Data width 
`define WGT_DAT                  6

////////////////////////////////////////
// Output data
// Internal bitwidth in converstion modules
`define OUT_DAT_INT              6 

////////////////////////////////////////
// MAC Array 
// Filter width
`define MAC_CN_WDT               9
// Padding in X dimension
`define MAC_CN_X_PAD             (`MAC_CN_WDT/2)
// Filter height
`define MAC_CN_HGT               9
// Padding port size
`define PAD_WDT                  ($clog2(`MAC_CN_HGT))
// Max stream length
`define MAX_SLEN                 32
// Stream length port width
`define SLEN_WDT                 ($clog2(`MAX_SLEN))
// Early Termination Stream Length Granularity
// This number should be larger than or equal to 8 to avoid issues with timing bubbles that are not implemented in the state machine.
`define SLEN_GRAN                8
// Early Termination Stream Length Granularity Width
`define SLEN_GRAN_WDT            ($clog2(`SLEN_GRAN))
// Stream length granularity for Early Termination
// Set granularity shift as 0 1 2 3 4  5  ...
// This corresponds to      1 2 4 8 16 32 ...
//`define SLEN_GRAN_SHIFT_WDT      ($clog2(`SLEN_WDT))


//////////////////////////////////////
// Banks 
// Bank count
`ifdef MACLEOD
   `define BANK_NO                  8
`elsif MACIVER
   `define BANK_NO                  2
`endif
// Bank idx width
`define BANK_IDX_WDT             ($clog2(`BANK_NO))
// Blocks per bank
`define BANK_BLOCK_NO            (`MAC_CN_HGT)

//// Number of column groups
//// Basic ACOUSTIC configurations
//`ifndef TROMBONE
//    `define MAC_COL_GRP              5
//    // Number of coluns within a group
//    `define MAC_COL                  4
//    // Number of MAC groups
//    `define MAC_GRP                  2
//    // MAC Group size
//    `define MAC_GRP_NO               16
//    // MAC Width (CN row)
//    `define MAC_CN_WDT               5
//    // MAC Width (FC row)
//    `define MAC_FC_WDT               6
//    // Padding size supported 
//    // WJR: Want to make that configurable
//    `define MAC_PAD_SIZE             2
//// ERI-DA Conv Tracker configuration
//`else
//    `ifndef WAVELET
//        `define MAC_COL_GRP          9
//    `else
//        `define MAC_COL_GRP          9    //63 
//    `endif
//    // Number of coluns within a group
//    `define MAC_COL                  16  //1
//    // Number of MAC groups
//    `define MAC_GRP                  1
//    // MAC Group size
//    `define MAC_GRP_NO               56   //32
//    // MAC Width (CN row)
//    `define MAC_CN_WDT               9   //9
//    // MAC Width (FC row)
//    `define MAC_FC_WDT               9   //9
//    // Padding size supported 
//    // WJR: Want to make that configurable
//    `define MAC_PAD_SIZE             0
//`endif
//// Shift between MACs
//`define MAC_SHIFT                1
//
//////////////////////////////////////////
//// Output counters
//// Number of columns per row
//`ifndef TROMBONE
//    `define OUT_ARR_COL              32
//    // Number of rows
//    `define OUT_ARR_ROW              3
//`else
//    `define OUT_ARR_COL              56   //64
//    // Number of rows
//    `ifndef WAVELET
//        `define OUT_ARR_ROW              20   //4
//    `else
//        `define OUT_ARR_ROW              3    //20   //4
//    `endif
//`endif
//// Enable internal registers
//`define OUT_SUBT_REG             0
//`define OUT_RELU_REG             0
//`define OUT_SHFT_REG             0
//// Memory write buffer shift width
//`define OUT_MEM_SHIFT_WDT        2
//// FC layer configuration
//// Rows per kernel
//`define FC_ROWS_P_KERN           3
//// Number of outputs computed 
//`define FC_NO_OUT                2
//// Number of parallel outputs
//`ifndef TROMBONE
//   `define FC_NO_OUT_PAR         32
//`else
//   `define FC_NO_OUT_PAR         56
//`endif
//
//// Data width
//`define ACT_MEM_DATA_WDT         (`ACT_MEM_DAT*`ACT_MEM_DATA_NO)
//
//////////////////////////////////////////
//// Activation Read Buffer
//`ifndef TROMBONE
//    // Number of blocks
//    `define ACT_BUF_BLOCKS           4
//    // Number of activations in the buffer block
//    `define ACT_BUF_BLOCK_NO         32
//        // Block address width
//    `define ACT_BUF_BLOCK_ADDR_WDT   ($clog2(`ACT_BUF_BLOCKS))
//`else
//    // Number of blocks
//    `define ACT_BUF_BLOCKS           4   //1
//    // Number of activations in the buffer block
//    `define ACT_BUF_BLOCK_NO         128  //64
//    // Block address width
//    `define ACT_BUF_BLOCK_ADDR_WDT   ($clog2(`ACT_BUF_BLOCKS))   //1
//    //`define ACT_BUF_BLOCKS_EQUALS_ONE    //There is an issue where the address being set to the above constant - 1 which is -1 for the log definition. This constant is used to not toggle the address.
//`endif
//
//// Buffer width
//`define ACT_BUF_BLOCK_WDT        (`ACT_BUF_BLOCK_NO*`ACT_CMP_DAT)
//// Number of activations in the buffer
//`define ACT_BUF_DATA_NO          (`ACT_BUF_BLOCK_NO*`ACT_BUF_BLOCKS)
//// Block width
//`define ACT_BUF_DATA_WDT         (`ACT_BUF_BLOCK_WDT*`ACT_BUF_BLOCKS)
//
//////////////////////////////////////////
//// Activation SNGs
//// Number of streams out of a single column - before padding
//`ifndef TROMBONE
//   `define ACT_SNG_COL_OUT_WDT_INT  (`ACT_BUF_BLOCK_NO)
//`else
//   `define ACT_SNG_COL_OUT_WDT_INT  (2*`ACT_BUF_DATA_NO/`MAC_COL)
//`endif
//// Number of streams out of a single column - after padding
//`ifndef TROMBONE
//   `define ACT_SNG_COL_OUT_WDT      (`ACT_BUF_BLOCK_NO + `MAC_GRP*`MAC_PAD_SIZE*2)
//`else
//   `define ACT_SNG_COL_OUT_WDT      (2*`ACT_BUF_DATA_NO/`MAC_COL + `MAC_GRP*`MAC_PAD_SIZE*2)
//`endif
//// Number of streams coming out of a column group
//`define ACT_SNG_COL_GRP_OUT_WDT  (`ACT_SNG_COL_OUT_WDT*`MAC_COL)
//// Number of streams coming out of all column groups
//`define ACT_SNG_OUT_WDT          (`ACT_SNG_COL_GRP_OUT_WDT*`MAC_COL_GRP)
//
//////////////////////////////////////////
//// Weight Memory 
//// Number of rows 
//`ifdef VIOLIN
//    `define WGT_MEM_ROWS             6
//    `define WGT_CN_ROWS              4
//    `define WGT_FC_ROWS              2
//`elsif VIOLA
//    `define WGT_MEM_ROWS             6
//    `define WGT_CN_ROWS              4
//    `define WGT_FC_ROWS              2
//`elsif CELLO
//// WJR !!!!!!!!!!!
//    `define WGT_MEM_ROWS             6
//    `define WGT_CN_ROWS              4
//    `define WGT_FC_ROWS              2
//`elsif TROMBONE
//    `ifndef WAVELET
//        `define WGT_MEM_ROWS             20   //8
//        `define WGT_CN_ROWS              20   //8
//    `else
//        `define WGT_MEM_ROWS             3    //5    //8
//        `define WGT_CN_ROWS              3    //5    //8
//    `endif
//    `define WGT_FC_ROWS              0   //0
//`else
//    `define WGT_MEM_ROWS             6
//    `define WGT_CN_ROWS              4
//    `define WGT_FC_ROWS              2
//`endif
//// Memory depth
//`ifdef VIOLIN
//    `define WGT_MEM_DEPTH            4096
//`elsif VIOLA
//    `define WGT_MEM_DEPTH            4096
//`elsif CELLO
//    `define WGT_MEM_DEPTH            4096
//`elsif TROMBONE
//    `define WGT_MEM_DEPTH            880
//`else
//    `define WGT_MEM_DEPTH            4096
//`endif
//// Address width
//`define WGT_MEM_ADDR_WDT         ($clog2(`WGT_MEM_DEPTH))
//`ifndef TROMBONE
//    // Number of weights per word
//    `define WGT_MEM_DATA_CN_NO       5
//    // Number of weights per word (FC row)
//    `define WGT_MEM_DATA_FC_NO       6
//`else
//    // Number of weights per word
//    `define WGT_MEM_DATA_CN_NO       9   //9
//    // Number of weights per word (FC row)
//    `define WGT_MEM_DATA_FC_NO       9   //9
//`endif
//// Data width
//`define WGT_MEM_DATA_CN_WDT      (`WGT_MEM_DATA_CN_NO*`WGT_DAT)
//// Data width (FC row)
//`define WGT_MEM_DATA_FC_WDT      (`WGT_MEM_DATA_FC_NO*`WGT_DAT)
//
//////////////////////////////////////////
//// Weight Read Buffer
//// Number of weights in the buffer
//`ifndef TROMBONE
//    `define WGT_BUF_DATA_CN_NO       5 
//    // Number of weights in the buffer (FC rows)
//    `define WGT_BUF_DATA_FC_NO       6 
//`else
//    `define WGT_BUF_DATA_CN_NO       9   //9 
//    // Number of weights in the buffer (FC rows)
//    `define WGT_BUF_DATA_FC_NO       9   //9 
//`endif
//// Buffer width
//`define WGT_BUF_DATA_CN_WDT      (`WGT_BUF_DATA_CN_NO*`WGT_DAT)
//// Buffer width (FC rows)
//`define WGT_BUF_DATA_FC_WDT      (`WGT_BUF_DATA_FC_NO*`WGT_DAT)
//
//
//////////////////////////////////////////
//// Instruction Memory 
//// Memory depth
//`ifndef TROMBONE
//`define INS_MEM_DEPTH            1024
//`else
//`define INS_MEM_DEPTH            256 
//`endif
//// Address width
//`define INS_MEM_ADDR_WDT         ($clog2(`INS_MEM_DEPTH))
//// Data width
//`define INS_MEM_DATA_WDT         (`ISA_WRD_WDT)
//
//// Uncomment following line to use HSE type SRAM
//// Otherwise HDF SRAMs are used.
////`define SRAM_HSE_EN              1
//// Uncomment following line to use LVT for SRAM
//// Otherwise RVT type SRAMs are used.
////`define SRAM_LVT_EN              1
//
//// MEM Control Values
//`define SRAM_CTRL_EMA            3'b010
//`define SRAM_CTRL_EMAW           2'b01
//`define SRAM_CTRL_EMAS           1'b0
//`define SRAM_CTRL_WABL           1'b1
//`define SRAM_CTRL_WABLM          2'b01
//`define SRAM_CTRL_RAWL           1'b1
//`define SRAM_CTRL_RAWLM          2'b00
//

`endif

