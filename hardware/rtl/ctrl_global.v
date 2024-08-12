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
// Module name : ctrl_global
// Created     : Tue 07 Jun 2022
// Authors     : Wojciech Romaszkan, Alexander Graening
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Global control FSM
//               
/////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////
// TODOs:
// - Add control register for unipolar activations. Second compute phase can be skipped
// - Debug mode preserving all outputs
// - There's a lot of replicated code between LOAD_S, ROT_S and COMP_S. Ideally this
//   should be separated as a different process/module (computation control).
// - Once early termination is factored in, there might be some corner cases
//   that will break state transitions if ET kicks in very quickly. This will need thorough
//   verification
// - WRITE_S needs handling of output writes, also overlap is not handled properly
//   in terms of incrementing output addresses.
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"
`include "scotsman_jtag.vh"
`include "scotsman_isa.vh"
`include "ERI-DA_HEADERS.vh"

module ctrl_global (
    clk,                // I: Clock input
    reset_n,            // I: Async reset, active low
    done,               // O: Done flag
    // JTAG Control Interface
    jtag_tck,           // I: JTAG clock
    jtag_kickoff,       // I: JTAG instruction kickoff (synchronized)
    jtag_inst,          // I: JTAG instruction
    jtag_wr_data,       // I: JTAG write data
    // Control register output
    ctrl_reg,           // I: Control register value
//    ctrl_reg_out,       // O: Control register output value
//    ctrl_reg_rd_done,   // O: Control register read done
    // Output control signals
    // Input memory
    imem_ce,            // O: Input memory chip enable
    imem_we,            // O: Input memory write enable
    imem_inst,          // O: Input memory instruction
    imem_base_addr,     // O: Input memory base address
    imem_offset,        // O: Input memory row
    imem_rd_done,       // I: Input memory read done
    imem_bit,           // O: Input memory bit position
    // Output memory 
    omem_ce,            // O: Output memory chip enable
    omem_we,            // O: Output memory write enable
    omem_jtag_wr,       // O: Output memory jtag write 
    omem_addr,          // O: Output memory address
    write_count_r,      // O: Output write count for addressing from maxpool registers.
    omem_rd_done,       // I: Output memory read done
    // SCIM Macro memory
    macro_read_en,      // O: macro memory read en
    macro_read_done,    // I: macro read is done
    macro_write_en,     // O: macro memory write en
    seed_reg_push,      // O: LFSR seed push
    roi_lb_r,           // O: Set to 0 for left half of ROI, 1 for right half.
    // Staging buffers
    stg_buf_clr,        // O: Clear staging buffers
    stg_buf_rot,        // O: Staging buffer rotation
    // SNG buffers
    sng_buf_clr,        // O: Clear SNG buffers
    sng_buf_psh,        // O: SNG buffer push
    // Compute
    comp_en,            // O: Compute enable
    comp_pos,           // O: Positive phase
    // Counter Control Signals
    BnkCtr_Clr,         // O: 
    BnkCtr_Buffer_Clr,  // O: 
    ET_L1_Clr,          // O: Clears Early Termination Level 1 Signals
    MxPl_Sparse_Clr,    // O: Clear before next ROI
    MxPl_Dense_Clr,     // O: Clear before next ROI
    BnkCtr_En,          // O: 
    BnkCtr_Latch,       // O: 
    GlbCtr_Latch,       // O: Latch second counter stage
    ET_Thr_Latch,       // O: Latch ET threshold with second counter stage
    ET_L1_En,           // O: Enable level 1 ET (Set for same cycle as ET valid)
    ET_L3_En,           // O: Enable level 3 ET (Enable 1 cycle after level 1)
    RowIndex_Update,    // O: Update Row Index (Load from global FSM)
    MxPl_Sparse_Latch,  // O: Latch third counter stage and compute maxpool for sparse case,
    MxPl_Dense_Latch,   // O: Latch third counter stage and compute maxpool for dense case
    compute_done,       // I: Indicator that maxpool latch is done, this will be high for a single cycle after each maxpool. Wait for this before writing in the write state.
    // Early Termination
    et_sat,              // I: If the ET threshold is satisfied for level 3, this will be high and computation will be cut short.
    et_thresh,           // O: ET threshold for counters
    // Output memory
    row_index           // O: Row Index for Maxpool
);

////////////////////////////////////////
// Parameter
///////////////////////
// State machine states
localparam FSM_ST_WDT                     = 4;
// Gray encoded, shouldn't matter though.
// Synthesis will remap states anyway.

////////////////////////////////////////
// Memory States
//////////////////
// JTAG State
localparam JTAG_MEM_S                     = 4'b0000;
// Idle State (waiting for compute signal)
localparam IDLE_MEM_S                     = 4'b0001;
// Initialize State (load first rows of ROI)
localparam L_INIT_MEM_S                     = 4'b0011;
// Rotate Rows from Initialize State
localparam L_INIT_ROT_MEM_S                 = 4'b0010;
// Pre-Load Additional Row
localparam L_LOAD_MEM_S                     = 4'b0110;
// Rotate After Load
localparam L_LOAD_ROT_MEM_S                 = 4'b0111;
// Wait for Compute to Finish
localparam L_WAIT_MEM_S                     = 4'b0101;
// Push Pre-Loaded Row
localparam L_PUSH_MEM_S                     = 4'b0100;
// Write to Output Memory
localparam L_WRITE_MEM_S                    = 4'b1100;
// Initialize State (load first rows of ROI)
localparam R_INIT_MEM_S                     = 4'b1101;
// Rotate Rows from Initialize State
localparam R_INIT_ROT_MEM_S                 = 4'b1111;
// Pre-Load Additional Row
localparam R_LOAD_MEM_S                     = 4'b1011;
// Rotate After Load
localparam R_LOAD_ROT_MEM_S                 = 4'b1001;
// Wait for Compute to Finish
localparam R_WAIT_MEM_S                     = 4'b1000;
// Push Pre-Loaded Row
localparam R_PUSH_MEM_S                     = 4'b1010;
// Write to Output Memory
localparam R_WRITE_MEM_S                    = 4'b1110;

////////////////////////////////////////
// Compute States
///////////////////
// Idle State (waiting for memory init to finish)
localparam IDLE_COMP_S                    = 4'b0000;
// Run Compute State
localparam RUN_COMP_S                     = 4'b0001;
// End Row State (set maxpool and clear signals for end of row, wait for done signal)
localparam END_ROW_COMP_S                 = 4'b0011;
// End ROI State (set maxpool and wait for WRITE to finish, clear signals for end of ROI)
localparam END_ROI_COMP_S                 = 4'b0010;
//// Early Termination Satisfied (set clear signals for row or ROI
//localparam TERM_COMP_S                    = 4'b0110;


////////////////////////////////////////
// Global Inputs Both FSMs
//////////////////
// Clock
input wire                                          clk;
// Async reset active low
input wire                                          reset_n;

////////////////////////////////////////
// Inputs Memory State
//////////////////

// JTAG Control Interface
// Clock
input wire                                          jtag_tck;
// Instruction kickoff
input wire                                          jtag_kickoff;
// Instruction
input wire [`JTAG_UDR_INST_REG_WDT-1:0]             jtag_inst;
// Write data
input wire [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]         jtag_wr_data;

// Input Memory
input wire                                          imem_rd_done;

// Output Memory
input wire                                          omem_rd_done;

//SCIM Macro Memory
input wire                                          macro_read_done;

// Compute Finished and Propagated through Maxpool
input wire                                          compute_done;


////////////////////////////////////////
// Outputs Memory State
//////////////////

// Done flag
output reg                                          done;

// Staging buffers
// Clear
output reg                                          stg_buf_clr;
// Rotate
output reg                                          stg_buf_rot;

// SNG buffers
// Clear
output reg                                          sng_buf_clr;
// Push
output reg                                          sng_buf_psh;

// JTAG Control Interface
// Control register read value
input wire [`CFG_REG_WDT-1:0]                       ctrl_reg;
//output reg [`CFG_REG_WDT-1:0]                       ctrl_reg_out;
//output reg                                          ctrl_reg_rd_done;

// Input Memory
output reg [`ACT_MEM_BANKS-1:0]                     imem_ce;      
output reg                                          imem_we;      
output reg [`ACT_MEM_RD_INST_WDT-1:0]               imem_inst; 

output reg [`ACT_MEM_BANKS*`ACT_MEM_ADDR_WDT-1:0]   imem_base_addr;    
output reg [`ACT_MEM_ADDR_WDT-1:0]                  imem_offset;    

// Current bit
output reg [`PREC_WDT-1:0]                          imem_bit;

// Output Memory
output reg [`OUT_MEM_BANKS-1:0]                     omem_ce;
output reg                                          omem_we;
output reg                                          omem_jtag_wr;
output reg [`OUT_MEM_ADDR_WDT-1:0]                  omem_addr;
output reg [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0] write_count_r;

//SCIM Macro Memory
output reg                                          macro_read_en;
output reg                                          macro_write_en;
output reg                                          seed_reg_push;
output reg                                          roi_lb_r;

////////////////////////////////////////
// Inputs Compute State
//////////////////

// Early Termination
input wire                                          et_sat;


////////////////////////////////////////
// Outputs Compute State
//////////////////

// Early Termination Threshold Output
// Input set in configuration register. This is a shifted version.
output reg [`GCSP-1:0]                              et_thresh;

// Row Index for Column Max Pooling
output reg [`ROI_HGT_WDT-1:0]                       row_index;

// Comput enable
output reg                                          comp_en;
// Comput positive phase
output reg                                          comp_pos;

// Counter Controls
output reg                                          BnkCtr_Clr;
output reg                                          BnkCtr_Buffer_Clr;
output reg                                          ET_L1_Clr;
output reg                                          MxPl_Sparse_Clr;
output reg                                          MxPl_Dense_Clr;
output reg                                          BnkCtr_En;
output reg                                          BnkCtr_Latch;
output reg                                          GlbCtr_Latch;
output reg                                          ET_Thr_Latch;
output reg                                          ET_L1_En;
output reg                                          ET_L3_En;
output reg                                          RowIndex_Update;
output reg                                          MxPl_Sparse_Latch;
output reg                                          MxPl_Dense_Latch;

////////////////////////////////////////
// End Input and Output Declatarion
////////////////////////////////////////



////////////////////////////////////////
// Internal Wires/Registers 
////////////////////////////////////////

// Note: Each output register set by the FSM  is given a register with _n 
// appended to the name to store the next value.
// Registers that are not output registers are declared with a _r and a _n
// version where _r is the current value and _n stores the next value.

////////////////////////////////////////
// Memory FSM
// Memory FSM State
reg  [FSM_ST_WDT-1:0]                     mem_state_r, mem_state_n;

// Done flag
reg                                       done_n;

//// Control signals
//reg  [`CFG_REG_WDT-1:0]                   ctrl_reg_local_n;     //TODO: Alex, may not be necessary.
//reg                                       ctrl_reg_rd_done_n;   //TODO: Alex, may not be necessary.

// Input Memory
reg [`ACT_MEM_BANKS-1:0]                  imem_ce_n;
reg                                       imem_we_n;
reg [`ACT_MEM_RD_INST_WDT-1:0]            imem_inst_n;
reg [`ACT_MEM_ADDR_WDT-1:0]               imem_base_addr_n [`ACT_MEM_BANKS-1:0];
reg [`ACT_MEM_ADDR_WDT-1:0]               imem_offset_n;
reg [`PREC_WDT-1:0]                       imem_bit_n;

// Output Memory
reg [`OUT_MEM_BANKS-1:0]                  omem_ce_n;      
reg                                       omem_we_n;      
reg                                       omem_jtag_wr_n;      
reg [`OUT_MEM_ADDR_WDT-1:0]               omem_addr_n;    

// Staging and Bank (SNG) Buffers
reg                                       stg_buf_clr_n;
reg                                       stg_buf_rot_n;
reg                                       sng_buf_clr_n;
reg                                       sng_buf_psh_n;

// Macro
reg                                       macro_read_en_n;
reg                                       macro_write_en_n; 
reg                                       seed_reg_push_n;
reg                                       roi_lb_n;


////////////////////////////////////////
// Compute FSM
// Compute FSM State
reg  [FSM_ST_WDT-1:0]                     comp_state_r, comp_state_n;

// Compute Control Signals
reg                                       comp_en_n;
reg                                       comp_pos_n;

reg                                       BnkCtr_Clr_n;
reg                                       BnkCtr_Buffer_Clr_n;
reg                                       ET_L1_Clr_n;
reg                                       MxPl_Sparse_Clr_n;
reg                                       MxPl_Dense_Clr_n;  
reg                                       BnkCtr_En_n; 
reg                                       BnkCtr_Latch_n;     
reg                                       GlbCtr_Latch_n;     
reg                                       ET_Thr_Latch_n;     
reg                                       ET_L1_En_n;
reg                                       ET_L3_En_n;        
reg                                       RowIndex_Update_n;
reg                                       MxPl_Sparse_Latch_n;
reg                                       MxPl_Dense_Latch_n;

reg [`GCSP-1:0]                           et_thresh_n;

reg [`ROI_HGT_WDT-1:0]                    row_index_n;




// Config values
// Local configuration register (Note that each of the other registers is set
// from this register at the end of the idle state.)
//reg  [`CFG_REG_WDT-1:0]                     ctrl_reg_local;
// Base address
wire [`ACT_MEM_ADDR_WDT-1:0]                ctrl_base_addr;
// Y padding required
wire [`PAD_WDT-1:0]                         ctrl_y_pad;
wire [`PAD_WDT-1:0]                         ctrl_y_pad_inc;
// Input precision
wire [`PREC_WDT-1:0]                        ctrl_prec;
wire [`PREC_WDT:0]                          ctrl_prec_inc;
// Number of ROI rows 
wire [`ROI_HGT_WDT-1:0]                     ctrl_roi_hgt;
wire [`ROI_HGT_WDT:0]                       ctrl_roi_hgt_inc;
// Stream length
wire [`SLEN_WDT-1:0]                        ctrl_stream_len;
wire [`SLEN_WDT:0]                          ctrl_stream_len_inc;
// Number of ROIs to process
wire [`ROI_COUNT_WDT-1:0]                   ctrl_roi_cnt;
wire [`ROI_COUNT_WDT:0]                     ctrl_roi_cnt_inc;
// Time Channel Global Accumulator Enable
wire                                        ctrl_time_ch_acc;
// Stride for Time Channel Rotations. 0->1,1->2,..., and 7->8 which
// corresponds to no sliding time channel.
wire [`BANK_IDX_WDT-1:0]                    ctrl_time_ch_stride;
wire [`BANK_IDX_WDT:0]                      ctrl_time_ch_stride_inc;
// Starting early termination threshold. This is the value for cycle 16, for
// cycle 32, left shift by 1.
wire signed [`GCSP-1:0]                     ctrl_et_thresh_in;
wire signed [`GCSP-1:0]                     ctrl_et_thresh_in_2x;


assign ctrl_base_addr = get_cfg_addr(ctrl_reg);

assign ctrl_y_pad = get_cfg_ypad(ctrl_reg);
assign ctrl_y_pad_inc = get_cfg_ypad(ctrl_reg) + 1;

assign ctrl_prec = get_cfg_prec(ctrl_reg);
assign ctrl_prec_inc = get_cfg_prec(ctrl_reg) + 1;

assign ctrl_roi_hgt = get_cfg_roih(ctrl_reg);
assign ctrl_roi_hgt_inc = get_cfg_roih(ctrl_reg) + 1;

assign ctrl_stream_len = get_cfg_slen(ctrl_reg);
assign ctrl_stream_len_inc = get_cfg_slen(ctrl_reg) + 1;

assign ctrl_roi_cnt = get_cfg_roic(ctrl_reg);
assign ctrl_roi_cnt_inc = get_cfg_roic(ctrl_reg) + 1;

assign ctrl_time_ch_acc = ~get_cfg_dnsm(ctrl_reg);

assign ctrl_time_ch_stride = get_cfg_chns(ctrl_reg);
assign ctrl_time_ch_stride_inc = get_cfg_chns(ctrl_reg) + 1;

assign ctrl_et_thresh_in = get_cfg_etth(ctrl_reg);
assign ctrl_et_thresh_in_2x = 2*get_cfg_etth(ctrl_reg);


// Control registers
// Input memory base address
// Separate because it can be locally incremented
// Keep track of input row
reg [`ROI_HGT_WDT+1-1:0]                    imem_row_r, imem_row_n;
// Number of initially loaded rows
reg [`PAD_WDT-1:0]                          init_rows_r, init_rows_n;
// Remaining stream length
reg [`SLEN_WDT-1:0]                         rem_slen_r, rem_slen_n;

// Current rotation 
reg [`BANK_IDX_WDT-1:0]                     cur_rot_r, cur_rot_n;
// Remaining rotation
reg [`BANK_IDX_WDT-1:0]                     rem_rot_r, rem_rot_n;
// Remaining ROI
reg [`ROI_COUNT_WDT-1:0]                    rem_roi_r, rem_roi_n;

// Helper Registers to Break Long Compute Path
reg [`ROI_COUNT_WDT+`ACT_MEM_BANK_ADDR_WDT-1:0] base_addr_intermediate, base_addr_intermediate_n; //= (ctrl_roi_cnt_inc - rem_roi_r)*(ctrl_time_ch_stride_inc)+(`ACT_MEM_BANKS-(i+1));
reg [`ROI_COUNT_WDT+`ACT_MEM_BANK_ADDR_WDT-1:0] base_addr_intermediate_const [`ACT_MEM_BANKS-1:0];
reg [`ROI_COUNT_WDT+`ACT_MEM_BANK_ADDR_WDT-1:0] base_addr_intermediate_const_n [`ACT_MEM_BANKS-1:0];
reg [`PREC_WDT+`ROI_HGT_WDT-1:0] base_addr_step_size, base_addr_step_size_n; //= (ctrl_prec_inc)*(ctrl_roi_hgt_inc);

// Synchronization
// Load Ready for Compute
reg                                         start_compute_fsm_r, start_compute_fsm_n;
reg                                         terminated_r, terminated_n;
// Iteration done flag
reg                                         iter_done_r, iter_done_n;

// Keep track of write to output memory
reg [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0] write_count_n;
reg [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0] final_write_count_r, final_write_count_n;





//// Assign control register output
//assign ctrl_reg_out = ctrl_reg_local;

////////////////////////////////////////
// Loop indices
integer                                   i;

////////////////////////////////////////
// Logic  

////////////////////////////////////////
// FSM State Registers
always @ (posedge clk or negedge reset_n) begin : FSM_SEQ
    if (reset_n == 1'b0) begin  // Set Reset Values
        /////////////////////////////
        // Memory FSM Registers

        // Internal Registers
        mem_state_r          <= IDLE_MEM_S;

        imem_row_r           <= {`ROI_HGT_WDT{1'b0}};
        init_rows_r          <= {`PAD_WDT{1'b0}};
        cur_rot_r            <= {`BANK_IDX_WDT{1'b0}};
        rem_rot_r            <= {`BANK_IDX_WDT{1'b0}};
        rem_roi_r            <= {`ROI_COUNT_WDT{1'b0}};

        start_compute_fsm_r  <= 1'b0;

        // Output Registers
        done                 <= 1'b0;
//        ctrl_reg_local       <= {`CFG_REG_WDT{1'b0}};
//        ctrl_reg_rd_done     <= 1'b0;
        for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
            imem_base_addr[i*`ACT_MEM_ADDR_WDT +: `ACT_MEM_ADDR_WDT] <= {`ACT_MEM_ADDR_WDT{1'b0}};
        end

        base_addr_intermediate  <= {(`ROI_COUNT_WDT+`ACT_MEM_BANK_ADDR_WDT){1'b0}};
        for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
            base_addr_intermediate_const[i] <= {(`ROI_COUNT_WDT+`ACT_MEM_BANK_ADDR_WDT){1'b0}};
        end
        base_addr_step_size     <= {(`PREC_WDT+`ROI_HGT_WDT){1'b0}};
        
        imem_offset          <= {`ACT_MEM_ADDR_WDT{1'b0}};
        imem_bit             <= {`PREC_WDT{1'b0}};
        imem_ce              <= {`ACT_MEM_BANKS{1'b0}};
        imem_we              <= 1'b0;
        imem_inst            <= {`ACT_MEM_RD_INST_WDT{1'b0}};
        
        omem_ce              <= {`OUT_MEM_BANKS{1'b0}};
        omem_we              <= 1'b0;
        omem_jtag_wr         <= 1'b0;
        omem_addr            <= {`OUT_MEM_ADDR_WDT{1'b0}};

        stg_buf_clr          <= 1'b0;
        stg_buf_rot          <= 1'b0;
        sng_buf_clr          <= 1'b0;
        sng_buf_psh          <= 1'b0;

        macro_read_en        <= 1'b0;
        macro_write_en       <= 1'b0;
        seed_reg_push        <= 1'b0;

        roi_lb_r             <= 1'b0;

        /////////////////////////////
        // Compute FSM Registers

        // Internal registers
        comp_state_r         <= IDLE_COMP_S;

        rem_slen_r           <= {`SLEN_WDT{1'b0}};
        iter_done_r          <= 1'b1;

        terminated_r         <= 1'b0;

        write_count_r        <= 0;
        final_write_count_r  <= 0;

        // Output Registers
        comp_en              <= 1'b0;
        comp_pos             <= 1'b0;
        
        BnkCtr_Clr           <= 1'b0;
        BnkCtr_Buffer_Clr    <= 1'b0;
        ET_L1_Clr            <= 1'b0;
        MxPl_Sparse_Clr      <= 1'b0;
        MxPl_Dense_Clr       <= 1'b0;
        BnkCtr_En            <= 1'b0;
        BnkCtr_Latch         <= 1'b0;
        GlbCtr_Latch         <= 1'b0;
        ET_Thr_Latch         <= 1'b0;
        ET_L1_En             <= 1'b0;
        ET_L3_En             <= 1'b0;
        RowIndex_Update      <= 1'b0;
        MxPl_Sparse_Latch    <= 1'b0;
        MxPl_Dense_Latch     <= 1'b0;
        
        et_thresh            <= {{1'b1},{(`GCSP-2){1'b0}},{1'b1}};    //This should be the most negative number possible.
        row_index            <= 0;
        
    end
    else begin  // Set Typical State Variable Update Logic
        /////////////////////////////
        // Memory FSM

        // Internal Registers
        mem_state_r          <= mem_state_n;

        imem_row_r           <= imem_row_n;
        init_rows_r          <= init_rows_n;
        cur_rot_r            <= cur_rot_n;
        rem_rot_r            <= rem_rot_n;
        rem_roi_r            <= rem_roi_n;

        start_compute_fsm_r  <= start_compute_fsm_n;
        
        // Output Registers
        done                 <= done_n;
//        ctrl_reg_local       <= ctrl_reg_local_n;
//        ctrl_reg_rd_done     <= ctrl_reg_rd_done_n;
        for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
           imem_base_addr[i*`ACT_MEM_ADDR_WDT +: `ACT_MEM_ADDR_WDT] <= imem_base_addr_n[i];
        end

        base_addr_intermediate  <= base_addr_intermediate_n;
        for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
            base_addr_intermediate_const[i] <= base_addr_intermediate_const_n[i];
        end
        base_addr_step_size     <= base_addr_step_size_n;

        imem_offset          <= imem_offset_n;
        imem_bit             <= imem_bit_n;
        imem_ce              <= imem_ce_n;
        imem_we              <= imem_we_n;
        imem_inst            <= imem_inst_n;

        omem_ce              <= omem_ce_n;
        omem_we              <= omem_we_n;
        omem_jtag_wr         <= omem_jtag_wr_n;
        omem_addr            <= omem_addr_n;

        macro_read_en        <= macro_read_en_n;
        macro_write_en       <= macro_write_en_n;
        seed_reg_push        <= seed_reg_push_n;

        roi_lb_r             <= roi_lb_n;

        stg_buf_clr          <= stg_buf_clr_n;
        stg_buf_rot          <= stg_buf_rot_n;
        sng_buf_clr          <= sng_buf_clr_n;
        sng_buf_psh          <= sng_buf_psh_n;

        /////////////////////////////
        // Compute FSM

        // Internal Registers
        comp_state_r         <= comp_state_n;

        rem_slen_r           <= rem_slen_n;
        iter_done_r          <= iter_done_n;

        terminated_r         <= terminated_n;

        write_count_r        <= write_count_n;
        final_write_count_r  <= final_write_count_n;

        // Output Registers
        comp_en              <= comp_en_n;
        comp_pos             <= comp_pos_n;

        BnkCtr_Clr           <= BnkCtr_Clr_n;
        BnkCtr_Buffer_Clr    <= BnkCtr_Buffer_Clr_n;
        ET_L1_Clr            <= ET_L1_Clr_n;
        MxPl_Sparse_Clr      <= MxPl_Sparse_Clr_n;
        MxPl_Dense_Clr       <= MxPl_Dense_Clr_n;
        BnkCtr_En            <= BnkCtr_En_n;
        BnkCtr_Latch         <= BnkCtr_Latch_n;
        GlbCtr_Latch         <= GlbCtr_Latch_n;
        ET_Thr_Latch         <= ET_Thr_Latch_n;
        ET_L1_En             <= ET_L1_En_n;
        ET_L3_En             <= ET_L3_En_n;
        RowIndex_Update      <= RowIndex_Update_n;
        MxPl_Sparse_Latch    <= MxPl_Sparse_Latch_n;
        MxPl_Dense_Latch     <= MxPl_Dense_Latch_n;
        
        row_index            <= row_index_n;
        et_thresh            <= et_thresh_n;

    end
end

////////////////////////////////////////
// Memory FSM Logic
always @ (*) begin : MEM_FSM_COMB
    // Internal
    mem_state_n             = mem_state_r;

    imem_row_n              = imem_row_r;

    init_rows_n             = init_rows_r;
    cur_rot_n               = cur_rot_r;
    rem_rot_n               = rem_rot_r;
    rem_roi_n               = rem_roi_r;

    write_count_n           = write_count_r;
    final_write_count_n     = final_write_count_r;

    start_compute_fsm_n     = start_compute_fsm_r;

    // External
    done_n                  = done;
    
//    ctrl_reg_local_n        = ctrl_reg_local;
//    ctrl_reg_rd_done_n      = ctrl_reg_rd_done;

    imem_ce_n               = imem_ce;
    imem_we_n               = imem_we;
    imem_inst_n             = imem_inst;
    for (i = 0; i < `BANK_NO; i = i + 1) begin
       imem_base_addr_n[i]  = imem_base_addr[i*`ACT_MEM_ADDR_WDT +: `ACT_MEM_ADDR_WDT];
    end
    base_addr_intermediate_n  = base_addr_intermediate;
    for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
        base_addr_intermediate_const_n[i] = base_addr_intermediate_const[i];
    end
    base_addr_step_size_n     = base_addr_step_size;

    imem_offset_n           = imem_offset;

    imem_bit_n              = imem_bit;

    omem_ce_n               = omem_ce;
    omem_we_n               = omem_we;
    omem_jtag_wr_n          = omem_jtag_wr;
    omem_addr_n             = omem_addr;
    
    macro_read_en_n         = macro_read_en;
    macro_write_en_n        = macro_write_en;
    seed_reg_push_n         = seed_reg_push;

    roi_lb_n                = roi_lb_r;
    
    stg_buf_clr_n           = stg_buf_clr;
    stg_buf_rot_n           = stg_buf_rot;
    sng_buf_clr_n           = sng_buf_clr;
    sng_buf_psh_n           = sng_buf_psh;

    MxPl_Dense_Clr_n        = 1'b0;
    MxPl_Sparse_Clr_n       = 1'b0;
    
    case (mem_state_r)
        // Idle State (waiting for compute signal)
        IDLE_MEM_S : begin
            imem_ce_n           = {`ACT_MEM_BANKS{1'b0}};
            imem_we_n           = 1'b0;
            imem_inst_n         = {`ACT_MEM_RD_INST_WDT{1'b0}};
            for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                imem_base_addr_n[i] = {`ACT_MEM_ADDR_WDT{1'b0}};
            end
            imem_offset_n       = {`ACT_MEM_ADDR_WDT{1'b0}};
            imem_row_n          = 0;
            omem_ce_n           = {`OUT_MEM_BANKS{1'b0}};
            omem_we_n           = 1'b0;
            omem_jtag_wr_n      = 1'b0;
            omem_addr_n         = {`OUT_MEM_ADDR_WDT{1'b0}};
//            ctrl_reg_rd_done_n  = 1'b0;

            stg_buf_clr_n       = 1'b1;
            stg_buf_rot_n       = 1'b0;
            sng_buf_clr_n       = 1'b1;
            sng_buf_psh_n       = 1'b0;

            MxPl_Dense_Clr_n    = 1'b1;
            MxPl_Sparse_Clr_n   = 1'b1;

            roi_lb_n            = 1'b0;
            
            // JTAG Instruction
            if (jtag_kickoff == 1'b1) begin
                // Check for input/output/config reads or writes
                // Input store
                if (is_actst(get_opc(jtag_inst))) begin
                    imem_ce_n[get_actst_bank(jtag_inst)] = 1'b1;
                    imem_we_n            = 1'b1;
                    imem_offset_n        = get_actst_addr(jtag_inst);
                    mem_state_n          = JTAG_MEM_S;
                end
                // Input load
                else if (is_actld(get_opc(jtag_inst))) begin
                    imem_ce_n[get_actld_bank(jtag_inst)] = 1'b1;
                    imem_we_n            = 1'b0;
                    imem_offset_n        = get_actld_addr(jtag_inst);
                    imem_inst_n          = `ACT_MEM_RD_INST_JTAG;
                    mem_state_n          = JTAG_MEM_S;
                end
                // Output store
                else if (is_outst(get_opc(jtag_inst))) begin
                    omem_ce_n[get_actst_bank(jtag_inst)] = 1'b1;
                    omem_we_n            = 1'b1;
                    omem_jtag_wr_n       = 1'b1;
                    omem_addr_n          = get_outst_addr(jtag_inst);
                    mem_state_n          = JTAG_MEM_S;
                end
                // Output load
                else if (is_outld(get_opc(jtag_inst))) begin
                    omem_ce_n[get_outst_bank(jtag_inst)] = 1'b1;
                    omem_we_n           = 1'b0;
                    omem_addr_n         = get_outld_addr(jtag_inst);
                    mem_state_n         = JTAG_MEM_S;
                end
                //macro memory store
                else if (is_wgtst(get_opc(jtag_inst))) begin
                    macro_read_en_n     = 1'b0;
                    macro_write_en_n    = 1'b1;
                    mem_state_n         = JTAG_MEM_S;
                end           
                //macro memory load         
                else if (is_wgtld(get_opc(jtag_inst))) begin
                    macro_read_en_n     = 1'b1;
                    macro_write_en_n    = 1'b0;
                    mem_state_n         = JTAG_MEM_S;
                end   
               
                //macro LFSR seed store			
                else if (is_sedst(get_opc(jtag_inst))) begin
                    seed_reg_push_n      = 1'b1; 
                    mem_state_n          = JTAG_MEM_S;
                end	

//                // Config store
//                else if (is_cfgst(get_opc(jtag_inst))) begin
//                    ctrl_reg_local_n    = jtag_wr_data[`CFG_REG_WDT-1:0];
//                end
//                // Config store
//                else if (is_cfgld(get_opc(jtag_inst))) begin
//                    ctrl_reg_rd_done_n  = 1'b1;
//                end
                // Check for compute kickoff
                else if (is_runen(get_opc(jtag_inst))) begin
                    // Clear done flag
                    done_n              = 1'b0;
                    // Save configuration values
                    // Remaining ROIs
                    rem_roi_n           = ctrl_roi_cnt;
                    // Replicate base address - at the beginning
                    // all banks start from the same address
                    for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                        imem_base_addr_n[i] = ctrl_base_addr;
                    end
                    // Set initial row
                    imem_offset_n       = 0;
                    // Set initial bit
                    imem_bit_n          = 0;
                    // Start reading
                    imem_ce_n           = {`ACT_MEM_BANKS{1'b1}};
                    // Calculate the last rows to load in initial phase
                    // E.g. if padding is 4, there will be 9-4 = 5 rows to load, row[4] is the last one
                    init_rows_n         = `MAC_CN_HGT - ctrl_y_pad - 1;  //TODO_ALEX: Verify this is meant to include the -1.
                    // Move to the next state
                    mem_state_n         = L_INIT_MEM_S;
                    // Set the Rotations Necessary for This Iteration
                    cur_rot_n = 0;   // First ROI always has zero rotations.

                    stg_buf_clr_n = 1'b0;
                    sng_buf_clr_n = 1'b0;
                    MxPl_Dense_Clr_n = 1'b0;
                    MxPl_Sparse_Clr_n = 1'b0;
                    
                    if (ctrl_time_ch_acc == 1'b0) begin
                        final_write_count_n = ((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS))-1;
                    end
                    else begin
                        final_write_count_n = ((`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS))-1;
                    end
                    imem_inst_n = `ACT_MEM_RD_INST_LEFT;
                end
            end
        end // IDLE_MEM_S
        JTAG_MEM_S : begin
            // WJR: check how aggressive I need to be with cleaning those registers
            // Check for input/output/config reads or writes
            // Input store
            if (is_actst(get_opc(jtag_inst))) begin
                imem_ce_n           = {`ACT_MEM_BANKS{1'b0}};
                imem_we_n           = 1'b0;
                imem_inst_n         = {`ACT_MEM_RD_INST_WDT{1'b0}};
                for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                    imem_base_addr_n[i] = {`ACT_MEM_ADDR_WDT{1'b0}};
                end
                imem_offset_n       = {`ACT_MEM_ADDR_WDT{1'b0}};
                mem_state_n             = IDLE_MEM_S;
            end
            else if (is_actld(get_opc(jtag_inst)) && imem_rd_done == 1'b1) begin
                imem_ce_n           = {`ACT_MEM_BANKS{1'b0}};
                imem_we_n           = 1'b0;
                imem_inst_n         = {`ACT_MEM_RD_INST_WDT{1'b0}};
                for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                    imem_base_addr_n[i] = {`ACT_MEM_ADDR_WDT{1'b0}};
                end
                imem_offset_n       = {`ACT_MEM_ADDR_WDT{1'b0}};
                mem_state_n             = IDLE_MEM_S;
            end
            else if (is_outst(get_opc(jtag_inst))) begin
                omem_ce_n           = {`OUT_MEM_BANKS{1'b0}};
                omem_we_n           = 1'b0;
                omem_addr_n         = {`OUT_MEM_ADDR_WDT{1'b0}};
                omem_jtag_wr_n      = 1'b0;
                mem_state_n             = IDLE_MEM_S;
            end
            else if (is_outld(get_opc(jtag_inst))) begin
                omem_ce_n           = {`OUT_MEM_BANKS{1'b0}};
                omem_we_n           = 1'b0;
                omem_addr_n         = {`OUT_MEM_ADDR_WDT{1'b0}};
                mem_state_n             = IDLE_MEM_S;
            end
            //macro memory store
            else if (is_wgtst(get_opc(jtag_inst))) begin
                macro_read_en_n     = 0;
                macro_write_en_n    = 0;
                mem_state_n             = IDLE_MEM_S;
            end            
            //macro memory load            
            else if (is_wgtld(get_opc(jtag_inst))) begin
                macro_read_en_n     = 0;
                macro_write_en_n    = 0;
                if(macro_read_done) begin
                    mem_state_n         = IDLE_MEM_S;          
                end else begin
                    mem_state_n         = JTAG_MEM_S;  
                end
            end

            //macro LFSR seed store			
            else if (is_sedst(get_opc(jtag_inst))) begin
                seed_reg_push_n      = 1'b0; 
                mem_state_n          = IDLE_MEM_S;
            end	


        end // JTAG_MEM_S
        // Initialize State (load first rows of ROI)
        L_INIT_MEM_S : begin
            write_count_n = 0;
            roi_lb_n            = 1'b0;
            MxPl_Dense_Clr_n = 1'b0;
            MxPl_Sparse_Clr_n = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            // Done loading a row from SRAM
            if (imem_bit == ctrl_prec) begin
                // Return to Loading First Bit of Next Row
                imem_bit_n = 1'b0;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                // Row Finished, Move Counter to Next Row
                imem_row_n = imem_row_r + 1;
                // Do we need to rotate?
                if (rem_rot_r > 0) begin
                    // Stop Reading While Rotating
                    imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                    mem_state_n = L_INIT_ROT_MEM_S;
                    stg_buf_rot_n = 1'b1;
                    rem_rot_n = rem_rot_r - 1;
                end
                // No rotation necessary
                else begin
                    // Push Row
                    sng_buf_psh_n = 1'b1; 
                    // Keep Reading (Next State is Load or Another Init Row)
                    imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                    // If done with the loading the initialization rows from SRAM
                    if (imem_row_r == init_rows_r) begin
                        start_compute_fsm_n = 1'b1;
                        if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin
                            mem_state_n = L_WAIT_MEM_S;
                        end
                        else begin
                            mem_state_n = L_LOAD_MEM_S;
                        end
                    end
                end
            end
            else begin
                rem_rot_n = cur_rot_r;
                // Keep Reading
                imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                // Do not push
                sng_buf_psh_n = 1'b0;
                // Increment bit position
                imem_bit_n = imem_bit + 1;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
            end
        end
        // Rotate Rows from Initialize State
        L_INIT_ROT_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            if (rem_rot_r > 0) begin
                rem_rot_n = rem_rot_r - 1;
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                sng_buf_psh_n = 1'b0;
                stg_buf_rot_n = 1'b1;
            end
            else begin
                // Push Row
                sng_buf_psh_n = 1'b1; 
                // Keep Reading (Next State is Load or Another Init Row)
                imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                stg_buf_rot_n = 1'b0;
                if (imem_row_r > init_rows_r) begin
                    mem_state_n = L_LOAD_MEM_S;
                    start_compute_fsm_n = 1'b1;
                end
                else begin
                    mem_state_n = L_INIT_MEM_S;
                end
            end
        end
        // Pre-Load Additional Row
        L_LOAD_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            // Do not push
            sng_buf_psh_n = 1'b0;
            // Start Compute FSM is only high one cycle
            start_compute_fsm_n = 1'b0;
            if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                mem_state_n = L_WAIT_MEM_S;
            end
            else begin
                // Done loading a row from SRAM
                if (imem_bit == ctrl_prec) begin
                    // Stop Reading
                    imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                    // Return to Loading First Bit of Next Row
                    imem_bit_n = 1'b0;
                    imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                    // Row Finished, Move Counter to Next Row
                    imem_row_n = imem_row_r + 1;
                    // Do we need to rotate?
                    if (rem_rot_r > 0) begin
                        mem_state_n = L_LOAD_ROT_MEM_S;
                        stg_buf_rot_n = 1'b1;
                        rem_rot_n = rem_rot_r - 1;
                    end
                    // No rotation necessary
                    else begin
                        // If done with the loading the rows from SRAM
                        mem_state_n = L_WAIT_MEM_S;
                    end
                end
                else begin
                    rem_rot_n = cur_rot_r;
                    // Keep Reading
                    imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                    if (imem_ce == {`ACT_MEM_BANKS{1'b1}}) begin
                        // Increment bit position
                        imem_bit_n = imem_bit + 1;
                        imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                    end
                end
            end
        end
        // Rotate After Load
        L_LOAD_ROT_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            if (rem_rot_r > 0) begin
                rem_rot_n = rem_rot_r - 1;
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                stg_buf_rot_n = 1'b1;
            end
            else begin
                // Stop Reading (Next State is Wait for Compute)
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                stg_buf_rot_n = 1'b0;
                imem_bit_n = 1'b0;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                mem_state_n = L_WAIT_MEM_S;
            end
        end
        // Wait for Compute to Finish
        L_WAIT_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            start_compute_fsm_n = 1'b0;
            if (iter_done_r == 1'b1 && start_compute_fsm_r == 1'b0) begin
                if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin
                    mem_state_n = L_WRITE_MEM_S;
                    write_count_n = 0;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;
                end
                else begin
                    sng_buf_psh_n = 1'b1;
                    mem_state_n = L_PUSH_MEM_S;
                end
            end
        end
        // Push Pre-Loaded Row
        L_PUSH_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;
            sng_buf_psh_n = 1'b0;
            mem_state_n = L_LOAD_MEM_S;
            imem_bit_n = 0;
        end
        // Write to Output Memory
        L_WRITE_MEM_S : begin
            roi_lb_n            = 1'b0;
            imem_inst_n = `ACT_MEM_RD_INST_LEFT;

            if (compute_done == 1'b1 || terminated_r == 1'b1 || write_count_r > 0) begin
                omem_addr_n = omem_addr + 1;
                if (write_count_r == final_write_count_r) begin
                    // Set this when returning to the init state for a new ROI.
                    mem_state_n = R_INIT_MEM_S;
                    MxPl_Dense_Clr_n = 1'b1;
                    MxPl_Sparse_Clr_n = 1'b1;
                    imem_row_n = 0;
                    stg_buf_clr_n = 1'b0;
                    sng_buf_clr_n = 1'b0;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b0}};
                    omem_we_n = 1'b0;
                end
                else if (write_count_r == final_write_count_r - 1) begin
                    write_count_n = write_count_r + 1;
                    stg_buf_clr_n = 1'b1;
                    sng_buf_clr_n = 1'b1;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;
                end
                else begin
                    write_count_n = write_count_r + 1;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;
                end 
            end
        end
        // Initialize State (load first rows of ROI)
        R_INIT_MEM_S : begin
            write_count_n = 0;
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            MxPl_Dense_Clr_n    = 1'b0;
            MxPl_Sparse_Clr_n   = 1'b0;
            // Done loading a row from SRAM
            if (imem_bit == ctrl_prec) begin
                // Return to Loading First Bit of Next Row
                imem_bit_n = 1'b0;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                // Row Finished, Move Counter to Next Row
                imem_row_n = imem_row_r + 1;
                // Do we need to rotate?
                if (rem_rot_r > 0) begin
                    // Stop Reading While Rotating
                    imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                    mem_state_n = R_INIT_ROT_MEM_S;
                    stg_buf_rot_n = 1'b1;
                    rem_rot_n = rem_rot_r - 1;
                end
                // No rotation necessary
                else begin
                    // Push Row
                    sng_buf_psh_n = 1'b1; 
                    // Keep Reading (Next State is Load or Another Init Row)
                    imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                    // If done with the loading the initialization rows from SRAM
                    if (imem_row_r == init_rows_r) begin
                        mem_state_n = R_LOAD_MEM_S;
                        start_compute_fsm_n = 1'b1;
                    end
                end
            end
            else begin
                rem_rot_n = cur_rot_r;
                // Keep Reading
                imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                // Do not push
                sng_buf_psh_n = 1'b0;
                // Increment bit position
                imem_bit_n = imem_bit + 1;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
            end
        end
        // Rotate Rows from Initialize State
        R_INIT_ROT_MEM_S : begin
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            if (rem_rot_r > 0) begin
                rem_rot_n = rem_rot_r - 1;
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                sng_buf_psh_n = 1'b0;
                stg_buf_rot_n = 1'b1;
            end
            else begin
                // Push Row
                sng_buf_psh_n = 1'b1; 
                // Keep Reading (Next State is Load or Another Init Row)
                imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                stg_buf_rot_n = 1'b0;
                if (imem_row_r > init_rows_r) begin
                    mem_state_n = R_LOAD_MEM_S;
                    start_compute_fsm_n = 1'b1;
                end
                else begin
                    mem_state_n = R_INIT_MEM_S;
                end
            end
        end
        // Pre-Load Additional Row
        R_LOAD_MEM_S : begin
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            // Do not push
            sng_buf_psh_n = 1'b0;
            // Start Compute FSM is only high one cycle
            start_compute_fsm_n = 1'b0;
            if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                mem_state_n = R_WAIT_MEM_S;
            end
            else begin
                // Done loading a row from SRAM
                if (imem_bit == ctrl_prec) begin
                    // Stop Reading
                    imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                    // Return to Loading First Bit of Next Row
                    imem_bit_n = 1'b0;
                    imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                    // Row Finished, Move Counter to Next Row
                    imem_row_n = imem_row_r + 1;
                    // Do we need to rotate?
                    if (rem_rot_r > 0) begin
                        mem_state_n = R_LOAD_ROT_MEM_S;
                        stg_buf_rot_n = 1'b1;
                        rem_rot_n = rem_rot_r - 1;
                    end
                    // No rotation necessary
                    else begin
                        // If done with the loading the rows from SRAM
                        mem_state_n = R_WAIT_MEM_S;
                    end
                end
                else begin
                    rem_rot_n = cur_rot_r;
                    // Keep Reading
                    imem_ce_n = {`ACT_MEM_BANKS{1'b1}};
                    if (imem_ce == {`ACT_MEM_BANKS{1'b1}}) begin
                        // Increment bit position
                        imem_bit_n = imem_bit + 1;
                        imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                    end
                end
            end
        end
        // Rotate After Load
        R_LOAD_ROT_MEM_S : begin
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            if (rem_rot_r > 0) begin
                rem_rot_n = rem_rot_r - 1;
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                stg_buf_rot_n = 1'b1;
            end
            else begin
                // Stop Reading (Next State is Wait for Compute)
                imem_ce_n = {`ACT_MEM_BANKS{1'b0}};
                stg_buf_rot_n = 1'b0;
                imem_bit_n = 1'b0;
                imem_offset_n = imem_bit + 1 + imem_row_r*(ctrl_prec_inc);
                mem_state_n = R_WAIT_MEM_S;
            end
        end
        // Wait for Compute to Finish
        R_WAIT_MEM_S : begin
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            start_compute_fsm_n = 1'b0;
            if (iter_done_r == 1'b1 && start_compute_fsm_r == 1'b0) begin
                if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin
                    mem_state_n = R_WRITE_MEM_S;
                    write_count_n = 0;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;
                end
                else begin
                    sng_buf_psh_n = 1'b1;
                    mem_state_n = R_PUSH_MEM_S;
                end
            end
        end
        // Push Pre-Loaded Row
        R_PUSH_MEM_S : begin
            roi_lb_n            = 1'b1;
            imem_inst_n = `ACT_MEM_RD_INST_RGTH;
            sng_buf_psh_n = 1'b0;
            mem_state_n = R_LOAD_MEM_S;
            imem_bit_n = 0;
        end
        // Write to Output Memory
        
        R_WRITE_MEM_S : begin
            
            if (compute_done == 1 || terminated_r == 1'b1 || write_count_r > 0) begin
                omem_addr_n = omem_addr + 1;
                if (write_count_r == final_write_count_r) begin
                    // Set this when returning to the init state for a new ROI.
                    // cur_rot_n is 3-bits so this will truncate for an effective modulo 8.
                    // TODO: Make this robust to changing the number of banks to a number that is not a power of 2.
                    cur_rot_n = (ctrl_time_ch_stride_inc)*(ctrl_roi_cnt_inc - rem_roi_r);

                    if (rem_roi_r > 0) begin
                        mem_state_n = L_INIT_MEM_S;
                        stg_buf_clr_n = 1'b0;
                        sng_buf_clr_n = 1'b0;
                        rem_roi_n = rem_roi_r - 1;
                        MxPl_Dense_Clr_n = 1'b1;
                        MxPl_Sparse_Clr_n = 1'b1;
                        for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                            //imem_base_addr_n[i] = ctrl_base_addr + (((ctrl_roi_cnt_inc - rem_roi_r)*(ctrl_time_ch_stride_inc)+(`ACT_MEM_BANKS-(i+1)))/(`ACT_MEM_BANKS)) * (ctrl_prec_inc)*(ctrl_roi_hgt_inc);
                            //imem_base_addr_n[i] = ctrl_base_addr + ((base_addr_intermediate+`ACT_MEM_BANKS-i-1) >> (`ACT_MEM_BANK_ADDR_WDT)) * base_addr_step_size;
                            imem_base_addr_n[i] = ctrl_base_addr + base_addr_intermediate_const[i] * base_addr_step_size;
                            //imem_base_addr_n[i] = ctrl_base_addr + ((base_addr_intermediate+`ACT_MEM_BANKS-i-1)/(`ACT_MEM_BANKS)) * base_addr_step_size;
                            //imem_base_addr_n[i] = ctrl_base_addr + (base_addr_intermediate >> `ACT_MEM_BANK_ADDR_WDT) * base_addr_step_size;
                        end
                        imem_row_n = 0;
                    end
                    else begin
                        mem_state_n = IDLE_MEM_S;
                        stg_buf_clr_n = 1'b1;
                        sng_buf_clr_n = 1'b1;
                        done_n = 1'b1;
                    end
                    omem_ce_n = {`OUT_MEM_BANKS{1'b0}};
                    omem_we_n = 1'b0;
                end
                else if (write_count_r == final_write_count_r - 1) begin
                    write_count_n = write_count_r + 1;
                    stg_buf_clr_n = 1'b1;
                    sng_buf_clr_n = 1'b1;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;

                    for (i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
                        base_addr_intermediate_const_n[i] = ((base_addr_intermediate+`ACT_MEM_BANKS-i-1)/(`ACT_MEM_BANKS));
                    end

                end
                else if (write_count_r == final_write_count_r - 2) begin
                    write_count_n = write_count_r + 1;

                    base_addr_intermediate_n = (ctrl_roi_cnt_inc - rem_roi_r)*(ctrl_time_ch_stride_inc);
                    base_addr_step_size_n = (ctrl_prec_inc)*(ctrl_roi_hgt_inc);
                end
                else begin
                    write_count_n = write_count_r + 1;
                    omem_ce_n = {`OUT_MEM_BANKS{1'b1}};
                    omem_we_n = 1'b1;
                end
            end
        end
        default : begin
            mem_state_n = IDLE_MEM_S;
        end
    endcase
end


////////////////////////////////////////
// Compute FSM Logic
always @ (*) begin : COMP_FSM_COMB
    // Set default values to avoid latches
    comp_state_n                  = comp_state_r;
 
    comp_en_n                     = comp_en;
    comp_pos_n                    = comp_pos;
  
    BnkCtr_Clr_n                  = BnkCtr_Clr;
    BnkCtr_Buffer_Clr_n           = BnkCtr_Buffer_Clr;
    ET_L1_Clr_n                   = ET_L1_Clr;
    //MxPl_Sparse_Clr_n             = MxPl_Sparse_Clr;
    //MxPl_Dense_Clr_n              = MxPl_Dense_Clr;
    BnkCtr_En_n                   = BnkCtr_En;
    BnkCtr_Latch_n                = BnkCtr_Latch;
    GlbCtr_Latch_n                = GlbCtr_Latch;
    ET_Thr_Latch_n                = ET_Thr_Latch;
    ET_L1_En_n                    = ET_L1_En;
    ET_L3_En_n                    = ET_L3_En;
    RowIndex_Update_n             = RowIndex_Update;
    MxPl_Sparse_Latch_n           = MxPl_Sparse_Latch;
    MxPl_Dense_Latch_n            = MxPl_Dense_Latch;
 
    row_index_n                   = row_index;

    rem_slen_n                    = rem_slen_r;
    iter_done_n                   = iter_done_r;
    
    et_thresh_n                   = et_thresh;

    terminated_n                  = terminated_r;
    // State dependent logic
    case (comp_state_r)
        IDLE_COMP_S : begin
            row_index_n = 0;
            terminated_n = 1'b0;
            if (start_compute_fsm_r == 1'b1) begin
                comp_en_n           = 1'b1;

                BnkCtr_Clr_n        = 1'b1;
                BnkCtr_Buffer_Clr_n = 1'b1;
                ET_L1_Clr_n         = 1'b1;
                RowIndex_Update_n   = 1'b1;

                iter_done_n = 1'b0;

            end
            else if (iter_done_r == 1'b0) begin
                BnkCtr_En_n = 1'b1;
                comp_pos_n          = 1'b1;
                rem_slen_n          = ctrl_stream_len;
                
                BnkCtr_Clr_n        = 1'b0;
                BnkCtr_Buffer_Clr_n = 1'b0;
                ET_L1_Clr_n         = 1'b0;

                comp_state_n = RUN_COMP_S;
            end
        end
        // Run Compute State
        RUN_COMP_S : begin
            comp_en_n = 1'b1;
            rem_slen_n = rem_slen_r - 1;
            BnkCtr_En_n = 1'b1;
                        
            // Computation control

            if (et_sat == 1'b1) begin
                comp_en_n = 1'b0;
                BnkCtr_En_n = 1'b0;

                terminated_n = 1'b1;
                //comp_state_n = TERM_COMP_S;
                //iter_done_n = 1'b1;

                //comp_en_n = 1'b0;

                //BnkCtr_Clr_n        = 1'b1;
                //BnkCtr_Buffer_Clr_n = 1'b1;
                //ET_L1_Clr_n         = 1'b1;



                RowIndex_Update_n    = 1'b0;
                //comp_en_n = 1'b0;

                // Flag computation done
                iter_done_n       = 1'b1;
                
                // Set Latch Signals
                BnkCtr_Latch_n = 1'b0;
                GlbCtr_Latch_n = 1'b0;
                MxPl_Sparse_Latch_n = 1'b0;
                MxPl_Dense_Latch_n = 1'b0;
                
                comp_state_n = END_ROW_COMP_S;

                BnkCtr_Buffer_Clr_n = 1'b1;
                BnkCtr_Clr_n = 1'b1;
                ET_L1_Clr_n = 1'b1;
            end
            else begin
                terminated_n = 1'b0;
                //if (iter_done_r == 1'b0) begin
                    // Check for final cycle of negative computation if the stream length
                    // is less than 16, or positive if it is greater than 16.
                    //if (rem_slen_r == 1 && ((comp_pos == 1'b0 && ctrl_stream_len <= `MAX_SLEN/2) || (comp_pos == 1'b1 && ctrl_stream_len > `MAX_SLEN/2))) begin
                    if (rem_slen_r == 2) begin
                        // Decrement counter
                        rem_slen_n           = rem_slen_r - 1;
                        row_index_n = imem_row_r - init_rows_r - 1;
                        if ((comp_pos == 1'b0 && ctrl_stream_len >= `MAX_SLEN/2) || (comp_pos == 1'b1 && ctrl_stream_len < `MAX_SLEN/2)) begin
                            // Flag computation done
                            iter_done_n       = 1'b1;    
                        end
                    end
                    else if (rem_slen_r == 1) begin
                        // Decrement counter
                        rem_slen_n           = rem_slen_r - 1;
                        if ((comp_pos == 1'b0 && ctrl_stream_len >= `MAX_SLEN/2) || (comp_pos == 1'b1 && ctrl_stream_len < `MAX_SLEN/2)) begin
                            comp_en_n = 1'b0;
                            RowIndex_Update_n    = 1'b0;
                            // Set Latch Signals
                            BnkCtr_Latch_n = 1'b1;
                            GlbCtr_Latch_n = 1'b1;
                            MxPl_Sparse_Latch_n = 1'b1;
                            MxPl_Dense_Latch_n = 1'b1;
                        end
                    end
                    // Check if negative compute is done
                    else if (rem_slen_r == 0 && ((comp_pos == 1'b0 && ctrl_stream_len >= `MAX_SLEN/2) || (comp_pos == 1'b1 && ctrl_stream_len < `MAX_SLEN/2))) begin
                        BnkCtr_En_n = 1'b0;
                        if (imem_row_r > ctrl_roi_hgt + ctrl_y_pad_inc) begin
                            comp_en_n = 1'b0;
                        end
                        RowIndex_Update_n    = 1'b1;
                        //comp_en_n = 1'b0;

                        iter_done_n = 1'b0;

                        // Set Latch Signals
                        BnkCtr_Latch_n = 1'b0;
                        GlbCtr_Latch_n = 1'b0;
                        MxPl_Sparse_Latch_n = 1'b0;
                        MxPl_Dense_Latch_n = 1'b0;
                        
                        comp_state_n = END_ROW_COMP_S;

                        BnkCtr_Buffer_Clr_n = 1'b1;
                        BnkCtr_Clr_n = 1'b1;
                        ET_L1_Clr_n = 1'b1;
                    end
                    // Switch back and forth from positive to negative and back every 8 cycles.
                    else if (rem_slen_r[`SLEN_GRAN_WDT-1:0] == 0) begin
                        if ((comp_pos == 1'b1 && rem_slen_r == 24) || (comp_pos == 1'b0 && rem_slen_r == 16) || (comp_pos == 1'b0 && rem_slen_r == 8) || (comp_pos == 1'b1 && rem_slen_r == 0)) begin
                            rem_slen_n        = rem_slen_r + `SLEN_GRAN - 1;
                        end
                        else begin
                            rem_slen_n        = rem_slen_r - 1;
                        end
                        // After 32 cycles, reverse the order of positive and negative
                        if ((rem_slen_r == 24 && comp_pos == 1'b0) || (rem_slen_r == 8 && comp_pos == 1'b1)) begin
                            comp_pos_n           = comp_pos;
                        end
                        else begin
                            comp_pos_n           = ~comp_pos;
                        end
                    end
                    // Typical Case: Decrement Counter and Continue
                    else begin
                       // Continue compute
                       comp_en_n            = 1'b1;
                       // Decrement counter
                       rem_slen_n           = rem_slen_r - 1;
                       RowIndex_Update_n    = 1'b0;
                    end

                    if ((comp_pos == 1'b0 && rem_slen_r == 25) || (comp_pos == 1'b1 && rem_slen_r == 17)) begin
                        if (rem_slen_r == 25) begin
                            et_thresh_n = ctrl_et_thresh_in;
                        end
                        else begin
                            et_thresh_n = ctrl_et_thresh_in_2x;
                            //et_thresh_n = {ctrl_et_thresh_in[`GCSP-1],ctrl_et_thresh_in[`GCSP-2:0]<<1};
                        end
                    end

                    // Trigger ET Check
                    if (rem_slen_r >= 2) begin
                        if ((comp_pos == 1'b0 && rem_slen_r == 24) || (comp_pos == 1'b1 && rem_slen_r == 16)) begin
                            BnkCtr_Latch_n = 1'b1;
                            GlbCtr_Latch_n = 1'b1;
                            ET_Thr_Latch_n = 1'b1;

                            ET_L1_En_n = 1'b1;
                            ET_L3_En_n = 1'b1;

                            //comp_state_n = ET_CHECK_COMP_S;
                        end
                        else begin
                            BnkCtr_Latch_n = 1'b0;
                            GlbCtr_Latch_n = 1'b0;
                            ET_Thr_Latch_n = 1'b0;
                            ET_L1_En_n = 1'b0;
                            ET_L3_En_n = 1'b0;
                        end
                    end
                //end
            end
        end
        // End Row State (set maxpool and clear signals for end of row, wait for done signal)
        END_ROW_COMP_S : begin
            RowIndex_Update_n    = 1'b0;
 
            // Set Latch Signals
            BnkCtr_Latch_n = 1'b0;
            GlbCtr_Latch_n = 1'b0;
            MxPl_Sparse_Latch_n = 1'b0;
            MxPl_Dense_Latch_n = 1'b0;
            
            BnkCtr_Buffer_Clr_n = 1'b0;
            BnkCtr_Clr_n = 1'b0;
            ET_L1_Clr_n = 1'b0;

            if (imem_row_r <= ctrl_roi_hgt + ctrl_y_pad_inc) begin 
                comp_en_n = 1'b1;
                BnkCtr_En_n = 1'b1;
                // Continue running with the next row.
                comp_state_n    = RUN_COMP_S;
                comp_pos_n      = 1'b1;
                rem_slen_n      = ctrl_stream_len;

                iter_done_n     = 1'b0;
            end
            else begin
                // Return and wait for the start signal.
                comp_state_n = END_ROI_COMP_S;
                comp_en_n = 1'b0;
                iter_done_n     = 1'b1;
            end
        end
        // End ROI State (set maxpool and wait for WRITE to finish, clear signals for end of ROI)
        END_ROI_COMP_S : begin  // NOTE: Compute FSM does not know there are two half-ROIs. This state
            RowIndex_Update_n    = 1'b0;
            comp_en_n = 1'b0;
            if (mem_state_r == L_INIT_MEM_S || mem_state_r == R_INIT_MEM_S || mem_state_r == IDLE_MEM_S) begin
                //MxPl_Sparse_Clr_n   = 1'b1;
                //MxPl_Dense_Clr_n    = 1'b1;
                comp_state_n        = IDLE_COMP_S;
            end
        end
//        // Early Termination Satisfied (set clear signals for row or ROI
//        TERM_COMP_S : begin
//            iter_done_n = 1'b1;
//
//            comp_en_n = 1'b0;
//
//            BnkCtr_Clr_n        = 1'b1;
//            BnkCtr_Buffer_Clr_n = 1'b1;
//            ET_L1_Clr_n         = 1'b1;
//    
//            comp_state_n = RUN_COMP_S;
//
//        end
        default : begin
            comp_state_n = IDLE_COMP_S;
        end
    endcase
end

endmodule // ctrl_global
