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
// Module name : SCIM_TOP
// Created     : Tue 07 Jun 2022
// Author      : Alexander Graening
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : Top level integration for ERIDA SCIM chip (MACLEOD)
//               
/////////////////////////////////////////////////////////////////////////////
// TODOs:
// - SRAM behavioral model and generated blocks need to be added and verified
//   with control FSM.
// - Add JTAG controls.
// - Add control register for unipolar activations. Second compute phase can be skipped
// - Debug mode preserving all outputs
// - There's a lot of replicated code between LOAD_S, ROT_S and COMP_S. Ideally this
//   should be separated as a different process/module (computation control).
// - Once early termination is factored in, there might be some corner cases
//   that will break state transitions if ET kicks in very quickly. This will need thorough
//   verification
// - WRITE_S needs handling of output writes, also overlap is not handled properly
//   in terms of incrementing output addresses.




`timescale 1ns / 1ps




////////////////////////////////////////
// Includes
////////////////////////////////////////

`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"
`include "scotsman_jtag.vh"
`include "scotsman_isa.vh"

////////////////////////////////////////
// Top Module Definition
////////////////////////////////////////

module SCIM_TOP(
   input  wire clk_d,   // I: Core clock, digital
   input  wire clk_ap,   // I: Core clock, analog positive node
   input  wire clk_an,   // I: Core clock, analog negative node
   input  wire vbias,    // I: Core clock, analog bias voltage
   //input  wire clk,     // I: Core clock, analog
   input  wire clk_sel, // I: Core clock select
   input  wire reset_n, // I: Async reset, active low
   // JTAG Interface
   input  wire tck,     // I: JTAG TCK
   input  wire tms,     // I: JTAG TMS
   input  wire trstn,   // I: JTAG TRSTN
   input  wire tdi,     // I: JTAG TDI
   output wire tdo,     // I: JTAG TDO
   output wire tdo_en,  // I: JTAG TDO_EN
   output wire clk_div, // O: test output of CLK_BUF
   // Control interface
   output wire done     // O: Done flag
);

// Multiplexed clock
wire                                    clk;


// FSM Input Signals
// TODO: Either assign a place for these in input or output memory, or write
// registers directly from JTAG.
wire [`ACT_MEM_ADDR_WDT-1:0]            ctrl_base_addr;
wire [`PAD_WDT-1:0]                     ctrl_y_pad;
wire [`PREC_WDT-1:0]                    ctrl_prec;
wire [`ROI_HGT_WDT-1:0]                 ctrl_roi_hgt;
wire [`SLEN_WDT-1:0]                    ctrl_stream_len;
wire                                    ctrl_overlap;
wire [`ROI_COUNT_WDT-1:0]               ctrl_roi_cnt;
wire ctrl_time_ch_acc;
wire [`GCSP-1:0]                        et_thresh_in;

wire                                    et_full_sat;

// FSM Output Signals
wire                                    compute;
//// Control register read value
//wire [`CFG_REG_WDT-1:0]                 ctrl_reg_out;
//wire                                    ctrl_reg_rd_done;
// FSM - Input memory interface
wire [`ACT_MEM_BANKS-1:0]               ctrl_imem_ce;      
wire                                    ctrl_imem_we;      
wire [`ACT_MEM_RD_INST_WDT-1:0]         ctrl_imem_inst; 
wire [`ACT_MEM_BANKS*`ACT_MEM_ADDR_WDT-1:0] ctrl_imem_base_addr;    
wire [`ACT_MEM_ADDR_WDT-1:0]            ctrl_imem_offset;    
wire                                    imem_ctrl_rd_done;
// FSM - Output memory interface
wire [`OUT_MEM_BANKS-1:0]               ctrl_omem_ce;      
wire                                    ctrl_omem_we;      
wire                                    ctrl_omem_jtag_wr;
wire [`OUT_MEM_ADDR_WDT-1:0]            ctrl_omem_addr;    
wire [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0] write_count; // O: Output write count for addressing from maxpool registers.
wire                                    omem_ctrl_rd_done;


wire [`PREC_WDT-1:0]                    imem_bit;
wire                                    stg_buf_clr;
wire                                    stg_buf_rot;
wire                                    sng_buf_clr;
wire                                    sng_buf_psh;
wire                                    comp_en;
wire                                    comp_pos;
wire                                    dense_en;

// Input Memory - Staging Buffers/JTAG
wire [`ACT_MEM_BANKS*`ACT_MEM_DATA_WDT_RD-1:0] imem_q; 
wire [`ACT_MEM_DATA_WDT-1:0]            imem_jtag_q;


// This sets the location of zero padding. (0->left, 1->right)
wire roi_lb_r;


// SCIM
wire [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] omem_data; 
wire [`OUT_MEM_DATA_WDT-1:0]            omem_jtag_q;

wire [5:0] ROW_INDEX;
wire [`GCSP-1:0] ET_THRESHOLD;
//Counter control signals from FSM
wire BnkCtr_Clr;
wire BnkCtr_Buffer_Clr;
wire ET_L1_Clr;
wire MxPl_Sparse_Clr;
wire MxPl_Dense_Clr;
wire BnkCtr_En;
wire BnkCtr_Latch;
wire GlbCtr_Latch;
wire ET_Thr_Latch;
wire ET_L1_En;
wire ET_L3_En;
wire RowIndex_Update;
wire MxPl_Sparse_Latch;
wire MxPl_Dense_Latch;
wire compute_done;

// JTAG registers
// Instruction
wire [`JTAG_UDR_INST_REG_WDT-1:0]          jtag_inst;
// Write data
wire [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      jtag_mem_data_wr;
// Read data
wire [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      jtag_mem_data_rd;
// Config Register
wire [`JTAG_UDR_CFG_REG_WDT-1:0]           jtag_cfg_reg;
// Kickoff register
wire                                       jtag_inst_kickoff;


//WMEM Read and Write Control Signals from JTAG
wire                                           wmem_read_en;            //From:FSM           To:All Banks
wire                                           wmem_write_en;           //From:FSM           To:All Banks
wire [$clog2(`N_R*2)-1:0]                      wmem_wraddr;             //From:JTAG-InstReg  To:All Banks   Assigned at this level
wire [$clog2(`N_R*`FXP)-1:0]                   wmem_rdaddr;             //From:JTAG-InstReg  To:All Banks   Assigned at this level
wire [`N_B*(`N_S*3)-1:0]                       wmem_wr_data;            //From:JTAG-DataReg  To:All Banks   Assigned at this level
wire [`N_B-1:0]                                wmem_rddone;             //From:Bank          To:FSM         (Only Bit[0] is used) 

wire [`N_L-1:0]                                sed_wr_data;             //From:JTAG-DataReg  To:All Banks   Assigned at this level
wire [`JTAG_INST_SEDST_BANK_WDT-1:0]           sed_wr_bank_addr;        //From:JTAG-Inst     To:Seed Decoder at this level Assigned at this level 
wire [`JTAG_INST_SEDST_ADDR_WDT-1:0]           sed_wr_reg_addr;         //From:JTAG-Inst     To:Seed Decoder at this level Assigned at this level 

wire [1:0]                                     lfsr_option_sel;         //From:jtag_cfg_reg  To: All Banks  Assigned at this level
wire                                           lfsr_load;               //From:FSM           To:All Banks   

wire [`N_B*4-1:0]                              vthres;                  //From:jtag_cfg_reg  To: All Banks  Assigned at this level
wire [`N_B-1:0]                                bank_en;                 //From:jtag_cfg_reg  To: All Banks  Assigned at this level
wire                                           et_en_gate;              //From:jtag_cfg_reg  To: Global Counter. Assigned at this level
wire                                           simpl_ctrl_banks;        //From:jtag_cfg_reg  To: All Banks. Assigned at this level
wire                                           simpl_ctrl_glacc;        //From:jtag_cfg_reg  To: Global Counter. Assigned at this level
wire                                           bank_ctr_clr_override;   //From:jtag_cfg_reg  To: All Banks. Assigned at this level


wire [`N_B*`N_S-1:0] 		                    wmem_rdout;              //From:All Banks     To: JTAG Read Mux.  


assign wmem_wraddr            = get_wgtst_addr(jtag_inst);
assign wmem_rdaddr            = get_wgtld_addr(jtag_inst);
assign wmem_wr_data           = jtag_mem_data_wr[`N_B*(`N_S*3)-1:0];

assign sed_wr_data            = jtag_mem_data_wr[`N_L-1:0];
assign sed_wr_bank_addr       = get_sedst_bank(jtag_inst);
assign sed_wr_reg_addr        = get_sedst_addr(jtag_inst);

assign lfsr_option_sel        = get_cfg_lfsroptsel(jtag_cfg_reg);

assign dense_en               = get_cfg_dnsm(jtag_cfg_reg);

assign vthres                 = get_cfg_vthres(jtag_cfg_reg);
assign bank_en                = get_cfg_bank_en(jtag_cfg_reg);
assign et_en_gate             = get_cfg_et_en_gate(jtag_cfg_reg);
assign simpl_ctrl_banks       = get_cfg_simpl_ctrl_banks(jtag_cfg_reg);
assign simpl_ctrl_glacc       = get_cfg_simpl_ctrl_glacc(jtag_cfg_reg);
assign bank_ctr_clr_override  = get_cfg_bank_ctr_clr_override(jtag_cfg_reg);

integer sb;
integer sr;

reg [`N_B*6-1:0] lfsr_sel;
//LFSR-seed Load address-decoding
always @(*) begin
   lfsr_sel = 0;
   for (sb=0;sb<`N_B;sb=sb+1) begin
      for (sr=0; sr< 6; sr=sr+1) begin
         if(sed_wr_bank_addr == sb) begin
            if(sed_wr_reg_addr == sr) begin
               lfsr_sel[sb*6+sr]=1'b1;
            end
         end
      end
   end
end

//***********TODO Floating wires*********Connections yet to be made at staging Buffer***//
wire [`N_B*`ACT_BUF_BLOCK_WDT-1:0] bb_in;

wire clk_a_buf;
CLK_BUF clk_buf (
   .CLKINP(clk_ap),
   .CLKINN(clk_an), 
   .CLKD(clk_a_buf), 
   .CLK_DIV(clk_div),
	`ifdef MACRO_ANA
			.VDD_CLK(), 
         .VSS(),
	`endif
   .VBIAS(vbias)
);


clkmux clkmux_i(
   .clk_a(clk_a_buf),
   .clk_d(clk_d),
   .clk_sel(clk_sel),
   .clk_int(clk)
);


// JTAG susbsystem
jtag_subsystem jtag_subsystem_i(
    .clk(clk),
    .reset_n(reset_n),
    // Chip level JTAG Interface
    .tck(tck),
    .tms(tms),
    .trstn(trstn),
    .tdi(tdi),
    .tdo(tdo),
    .tdo_en(tdo_en),

    .mbist_en(),
    .mbist_tdo(),

    .jtag_inst(jtag_inst),
    .jtag_mem_data_wr(jtag_mem_data_wr),
    .jtag_mem_data_rd(jtag_mem_data_rd),
    .jtag_cfg_reg(jtag_cfg_reg),
    .jtag_inst_kickoff(jtag_inst_kickoff)

);

// JTAG read multiplexer
jtag_rd_mux jtag_rd_mux_i(
   .clk(clk),     
   .reset_n(reset_n), 
   .imem_rd_data(imem_jtag_q),
   .imem_rd_done(imem_ctrl_rd_done),
   .omem_rd_data(omem_jtag_q),
   .omem_rd_done(omem_ctrl_rd_done),
   .wmem_rd_data(wmem_rdout),
   .wmem_rd_done(wmem_rddone[0]),
  
   //*****[10/14/22]VKJ: Config reg moved to JTAG. No need to readout through JTAG data-reg
      //   .ctrl_rd_data(ctrl_reg_out),
      //   .ctrl_rd_done(ctrl_reg_rd_done),
   //*****[10/14/22]VKJ: Config reg moved to JTAG. No need to readout through JTAG data-reg
   
   .seed_rd_data(),
   .seed_rd_done(1'b0),
   .jtag_rd_data(jtag_mem_data_rd[`JTAG_UDR_MEM_DATA_REG_WDT-1:0])
);



////////////////////////////////////////
// Global FSM Instantiation

ctrl_global s_globalfsm (
    .clk(clk),                              // I: Clock input
    .reset_n(reset_n),                      // I: Async reset, active low
    .done(done),                            // O: Done flag
    // JTAG Control Interface
    .jtag_tck(tck),                         // I: JTAG clock
    .jtag_kickoff(jtag_inst_kickoff),       // I: JTAG instruction kickoff
    .jtag_inst(jtag_inst),                  // I: JTAG instruction
    .jtag_wr_data(jtag_mem_data_wr),        // I: JTAG write data
    .ctrl_reg(jtag_cfg_reg),                // I: JTAG configuration register data
//    .ctrl_reg_out(ctrl_reg_out),            // O: Control register value
//    .ctrl_reg_rd_done(ctrl_reg_rd_done),    // O: Control register read done
    // Input memory
    .imem_ce(ctrl_imem_ce),                 // O: Input memory chip enable
    .imem_we(ctrl_imem_we),                 // O: Input memory write enable
    .imem_inst(ctrl_imem_inst),             // O: Input memory instruction
    .imem_base_addr(ctrl_imem_base_addr),   // O: Input memory base address
    .imem_offset(ctrl_imem_offset),         // O: Input memory offset
    .imem_rd_done(imem_ctrl_rd_done),       // I: Input memory read done
    .imem_bit(imem_bit),                    // O: Input memory bit position
    // Output memory
    .omem_ce(ctrl_omem_ce),                 // O: Output memory chip enable
    .omem_we(ctrl_omem_we),                 // O: Output memory write enable
    .omem_jtag_wr(ctrl_omem_jtag_wr),       // O: Output memory jtag write enable
    .omem_addr(ctrl_omem_addr),             // O: Output memory address
    .write_count_r(write_count),           // O: Output write count for addressing from maxpool registers.
    .omem_rd_done(omem_ctrl_rd_done),       // I: Output memory read done
    // SCIM_Macro memory
    .macro_read_en(wmem_read_en),
    .macro_read_done(wmem_rddone[0]),
    .macro_write_en(wmem_write_en),
    //SCIM Bank LFSR Seed register Initializing
    .seed_reg_push(lfsr_load),              // O: Trigger signal to load LFSR seeds
    .roi_lb_r(roi_lb_r),                    // O: Set Left/Right Half of ROI
    // Staging buffers
    .stg_buf_clr(stg_buf_clr),              // O: Clear staging buffers
    .stg_buf_rot(stg_buf_rot),              // O: Staging buffer rotation
    // SNG buffers
    .sng_buf_clr(sng_buf_clr),              // O: Clear SNG buffers
    .sng_buf_psh(sng_buf_psh),              // O: SNG buffer push
    // Compute
    .comp_en(comp_en),                      // O: Compute enable
    .comp_pos(comp_pos),                    // O: Positive phase
    // Counter Control Signals
    .BnkCtr_Clr(BnkCtr_Clr),                // O: 
    .BnkCtr_Buffer_Clr(BnkCtr_Buffer_Clr),  // O:
    .ET_L1_Clr(ET_L1_Clr),                  // O:
    .MxPl_Sparse_Clr(MxPl_Sparse_Clr),      // O:
    .MxPl_Dense_Clr(MxPl_Dense_Clr),        // O:
    .BnkCtr_En(BnkCtr_En),                  // O:
    .BnkCtr_Latch(BnkCtr_Latch),            // O:
    .GlbCtr_Latch(GlbCtr_Latch),            // O:
    .ET_Thr_Latch(ET_Thr_Latch),            // O:
    .ET_L1_En(ET_L1_En),                    // O:
    .ET_L3_En(ET_L3_En),                    // O:
    .RowIndex_Update(RowIndex_Update),      // O:
    .MxPl_Sparse_Latch(MxPl_Sparse_Latch),  // O:
    .MxPl_Dense_Latch(MxPl_Dense_Latch),    // O:
    .compute_done(compute_done),            // I:
    // Early Termination
    .et_sat(et_full_sat),                   // I: If the ET threshold is satisfied for level 3, this will be high and computation will be cut short.
    .et_thresh(ET_THRESHOLD),               // O: ET threshold for counters
    // Output memory
    .row_index(ROW_INDEX)                   // O: Row Index for Maxpool
);



// TODO: Decide on Output SRAM Structure and Complete SRAM Portion
// TODO: Add Behavioral SRAM Models

////////////////////////////////////////
// Input SRAM Instantiation

//wire [`ACT_BUF_BLOCK_NO*`BANK_NO-1:0] imemq;
//wire imem_ce;
//reg imem_we;
//wire [`ACT_BUF_BLOCK_NO*`BANK_NO-1:0] imemdata;
//wire [`ACT_MEM_ADDR_WDT*`BANK_NO-1:0] imemaddr;
input_mem input_mem_i(
   .clk(clk),
   .reset_n(reset_n),
   .ce(ctrl_imem_ce),
   .we(ctrl_imem_we),
   .inst(ctrl_imem_inst),
   .data(jtag_mem_data_wr[`ACT_MEM_DATA_WDT-1:0]),
   .base_addr(ctrl_imem_base_addr),
   .offset(ctrl_imem_offset),
   .q(imem_q),
   .jtag_q(imem_jtag_q),
   .rd_done(imem_ctrl_rd_done)
);



genvar i;
//generate
//    for(i=0; i < `BANK_NO; i=i+1)
//    begin : generate_SRAM_IN
//    sp_ram #(.DATA_WIDTH(`ACT_BUF_BLOCK_NO), .RAM_DEPTH(`ACT_MEM_DEPTH)) sp_ramin (
//        .clk(clk), 
//        .we(imem_we),
//        .ce(imem_ce),
//        .data(imemdata[`ACT_BUF_BLOCK_NO*(i+1)-1:`ACT_BUF_BLOCK_NO*i]),
//        .addr(imemaddr[`ACT_MEM_ADDR_WDT*(i+1)-1:`ACT_MEM_ADDR_WDT*i]),
//        .q(imemq[`ACT_BUFF_BLOCK_NO*(i+1)-1:`ACT_BUFF_BLOCK_NO*i])
//    );
////        sram_in_sp_hdf sram_in(
////            .Q(imemq[`ACT_BUF_BLOCK_WDT*(i+1)-1:`ACT_BUF_BLOCK_WDT*i]),
////            .CLK(clk),
////            .CEN(imem_ce),
////            .GWEN(imem_we),
////            .A(imemaddr[`ACT_MEM_ADDR_WDT*(i+1)-1:`ACT_MEM_ADDR_WDT*i]),
////            .D(imemdata[`ACT_BUF_BLOCK_NO*(i+1)-1:`ACT_BUF_BLOCK_NO*i]),
////            .STOV(),
////            .EMA(),
////            .EMAW(),
////            .EMAS(),
////            .RET1N(),
////            .WABL(),
////            .WABLM(),
////            .RAWL(), 
////            .RAWLM()
////        );
//    end
//endgenerate

wire omem_ce;
wire omem_we;
wire [`ACT_BUF_BLOCK_NO*`OUT_FLT_NO-1:0] omemdata;
wire [`OUT_MEM_ADDR_WDT-1:0] omemaddr;
wire [`ACT_BUF_BLOCK_NO*`OUT_FLT_NO-1:0] omemq;



//generate
//    for(i=0; i < `ACT_BUF_BLOCK_NO*`OUT_FLT_NO/`OUT_MEM_WDT; i=i+1)
//    begin : generate_SRAM_OUT
//    sp_ram #(.DATA_WIDTH(`OUT_MEM_WDT), .RAM_DEPTH(`OUT_MEM_DEPTH)) sp_ramout (
//        .clk(clk),
//        .we(omem_we),
//        .ce(omem_ce),
//        .data(omemdata[`OUT_MEM_WDT*(i+1)-1:`OUT_MEM_WDT*i]),
//        .addr(omemaddr),
//        .q(omemq[`OUT_MEM_WDT*(i+1)-1:`OUT_MEM_WDT*i])
//    );
////sram_out_sp_hdf sram_out(
////    .Q(omemq[`OUT_MEM_WDT*(i+1)-1:`OUT_MEM_WDT*i]),
////    .CLK(clk),
////    .CEN(omem_ce),
////    .GWEN(omem_we),
////    .A(omemaddr),
////    .D(omemdata[`OUT_MEM_WDT*(i+1)-1:`OUT_MEM_WDT*i]),
////    .STOV(),
////    .EMA(),
////    .EMAW(),
////    .EMAS(),
////    .RET1N(),
////    .WABL(),
////    .WABLM(),
////    .RAWL(),
////    .RAWLM()
////);
//    end
//endgenerate


////////////////////////////////////////
// Staging Buffer Instantiation

wire [(`ACT_BUF_BLOCK_NO*`ACT_BUF_DAT*`BANK_NO)-1:0] ibufq;
//wire [(`ACT_BUF_BLOCK_WDT*`BANK_NO)-1:0] stgbuf_out;
//wire [`BANK_NO-1:0] zero_in_mem;
//wire [`BANK_NO-1:0] zero_in_buf;
//wire [`BANK_NO-1:0] zero_out;

generate
    for(i=0; i < `BANK_NO; i=i+1)
    begin : STAGEBUFF
        stagebuff s_stgbuff(
            .clk(clk),                                                                                              // I: Clock input
            .reset_n(reset_n),                                                                                      // I: Async reset, active low
            .src(stg_buf_rot),                                                                                      // I: Source (0 - memory, 1 - buffer)
            .clr(sng_buf_clr),                                                                                      // I: Buffer clear
            .bit_pos(imem_bit),                                                                                     // I: Bit position being written
//            .zero_in_mem(zero_in_mem[i]),                                                                           // I: Zero indicator in, memory
//            .zero_in_buf(zero_in_buf[(i+1)%`BANK_NO]),                                                              // I: Zero indicator in, previous buffer
//            .zero_out(zero_out[i]),                                                                                 // O: Zero indicator out
            .val_in_mem(imem_q[`ACT_BUF_BLOCK_NO*(i+1)-1:`ACT_BUF_BLOCK_NO*i]),                                     // I: Value to be buffered, memory
            .val_in_buf(bb_in[`ACT_BUF_BLOCK_WDT*((i+1)%`BANK_NO+1)-1:`ACT_BUF_BLOCK_WDT*((i+1)%`BANK_NO)]),   // I: Value to be buffered, previous buffer
            .val_out(bb_in[`ACT_BUF_BLOCK_WDT*(i+1)-1:`ACT_BUF_BLOCK_WDT*i])                                   // O: Buffer output
        );
    end
endgenerate

wire [`N_S*`N_C-1:0]        ET_L1_TRIGG;
			
wire [`N_B*`N_S*`N_C*`BCP-1:0]  BANK_CTR_LATCHED;

wire SA_Latch;
assign SA_Latch= BnkCtr_En;

////////////////////////////////////////
// One SCIM Bank with LFSR

//Instantiate 8 SCIM Macros
genvar b;
generate 
    for(b=0; b<`N_B;b=b+1)
    begin : generate_multiple_banks

        SCIM_BANK i_SCIM_BANK(
               .CLK(clk),                                            //I:        Clock
               .RESET_N(reset_n),                                    //I:        Active-Low Asynch Reset
               .lfsr_load(lfsr_load),                                //I:        From FSM: LFSR register initializing Mode trigger signal
               .lfsr_sel(lfsr_sel[6*b +: 6]),                        //I:[8x6]   From LFSR address decoder: Select line. Each Macro contains 6 32-bit LFSR registers
               .lfsr_option_sel(lfsr_option_sel),                    //I:[2]     From JTAG ConfigReg: LFSR-to-row mapping strategy selection. BIT0 for Input LFSR, BIT1 for Weight LFSR
               .LFSR_REG_INIT(sed_wr_data),                          //I:[32]    From JTAG DataReg  : 32 Bit initializing value for LFSR register
               .VTHRES(vthres[4*b +: 4]),                            //I:[8x4]   From JTAG ConfigReg: 4-bit Sense-Amp Threshold setting. Individual control for each Macro
               .bank_en(bank_en[b]),                                 //I:[8]     From JTAG ConfigReg: Disables Banks selectively 
               .dense_en(dense_en),                                  //I:        From JTAG ConfigReg: Indicates Dense Mode to Macro
               .READ_EN(wmem_read_en),                               //I:        From FSM: Weight SRAM Read Trigger
               .WRITE_EN(wmem_write_en),                             //I:        From FSM: Weight SRAM Write Trigger
               .READ_DONE(wmem_rddone[b]),                           //O:        To   FSM: Indicates Weight-Memory read is done
               .WRITE_ADDR(wmem_wraddr),                             //I:[8]     From JTAG InstrReg: Address-Port for Weight SRAM Write 
               .READ_ADDR(wmem_rdaddr),                              //I:[9]     From JTAG InstrReg: Address-Port for Weight SRAM Read
               .DIN(wmem_wr_data[(`N_S*3)*b +: (`N_S*3)]),           //I:[8x96]  From JTAG DataReg : Data-Port for Weight SRAM Write
               .READ_OUT(wmem_rdout[`N_S*b +: `N_S]),                //O:[8x32]  To JTAG Read Mux: Sense-Amp Read-Out For Weight SRAM Read
               .BB_IN(bb_in[`ACT_BUF_BLOCK_WDT*b +:`ACT_BUF_BLOCK_WDT]),//I:[8x(32+4)x6)] From Staging Buffer: input to bank-buffer. 4 extra values from right for left roi and vice versa
               .BB_EN(sng_buf_psh),                                  //I:        From FSM: Bank Buffer Enable.
               .BB_CLR(sng_buf_clr),                                 //I:        From FSM: Bank Buffer Clear
               //******[10/15/22]VKJ: Removed Zero indicators.
                     //.BB_ZERO_IN(),                                //<deleted> From FSM: Bank Buffer Zero in.
               //******[10/15/22]VKJ: Removed Zero indicators.
               .roi_lb_r(roi_lb_r),                                  //I:        From FSM: Indicates Left or Right ROI to bank buffer to decide location of zero padding should be from FSM
               .simpl_ctrl_banks(simpl_ctrl_banks),                  //I:        From JTAG ConfigReg: Debug option. Simplify Control Signals internally
               .bank_ctr_clr_override(bank_ctr_clr_override),        //I:        From JTAG ConfigReg: Debug option. Disables clearing operation of Bank_Ctr shadow. Clearing needed only in ET Scenario.
               .comp_positive_phase(comp_pos),                       //I:        From FSM: Indicates positive SC cycle to SCIM Macro. Timing to be aligned to comp_en
               .COMP_EN(comp_en),                                    //I:        From FSM: compute enable
               .SA_Latch(SA_Latch),                                  //I:        From FSM: Bank Counter Module Control Signal: Logically same as BnkCtr_En
               .BnkCtr_En(BnkCtr_En),                                //I:        From FSM: Bank Counter Module Control Signal. 
               .BnkCtr_Latch(BnkCtr_Latch),                          //I:        From FSM: Bank Counter Sample Trigger.Expected to be asserted at compute cycles(16/32/48/64)
               .BnkCtr_Clr(BnkCtr_Clr),                              //I:        From FSM: Bank Counter Register Clear. Expected to be asserted before every new row. to flush previous result
               .BnkCtr_Buffer_Clr(BnkCtr_Buffer_Clr),                //I:        From FSM: Bank Counter Buffer Clear. (Clearing signal for shadow register) Logically equivalent to BankCtr_Clr
               .ET_L1_TRIGG(ET_L1_TRIGG),                            //I:[32x32] From Global_accumulator: Level-1 Early Termination Trigger signal Fed-back from Global Counter to Bank-Counters        
               .BANK_CTR_LATCHED(BANK_CTR_LATCHED[`N_S*`N_C*`BCP*b +: `N_S*`N_C*`BCP]) //O:[8x(32x32x7)] To Global accumulator: Bank Counter Result to Global Counter
         );
    end
endgenerate


GLOBAL_ACCUMULATOR i_global_accumulator(
    .CLK(clk),                              // I: Clock input
    .RESET_N(reset_n),                      // I: Reset active low
    .dense_en(dense_en),                    // I: Indicates Dense-Mode
    .et_en_gate(et_en_gate),                // I: Gates ET functionality of internal blocks
    .simpl_ctrl_glacc(simpl_ctrl_glacc),    // I: Simplify Control Signals
    .ET_THRESHOLD(ET_THRESHOLD),            // I: Early termination threshold set by fsm                
    .ROW_INDEX(ROW_INDEX),                  // I: Row index from FSM to be added to the counter output.
    .BNK_CTR_LATCHED(BANK_CTR_LATCHED),     // I: [8x(32x32x7)] Bank Counter Result to Global Counter 
    .ET_L1_Clr(ET_L1_Clr),                  // I: Clears Early Termination Level 1 Signals 
    .MxPl_Sparse_Clr(MxPl_Sparse_Clr),      // I: Clear before next ROI
    .MxPl_Dense_Clr(MxPl_Dense_Clr),        // I: Clear before next ROI
    .BnkCtr_Clr(BnkCtr_Clr),                // I: Used in debug mode only.
    .BnkCtr_Latch(BnkCtr_Latch),            // I: Used in debug mode only.
    .GlbCtr_Latch(GlbCtr_Latch),            // I: Latch second counter stage                                    
    .ET_Thr_Latch(ET_Thr_Latch),            // I: Latch ET threshold with second counter stage
    .ET_L1_En(ET_L1_En),                    // I: Enable level 1 ET (Set for same cycle as ET valid)
    .ET_L3_En(ET_L3_En),                    // I: Enable level 3 ET (Enable 1 cycle after level 1)
    .RowIndex_Update(RowIndex_Update),      // I: Update Row Index (Load from global FSM)
    .MxPl_Sparse_Latch(MxPl_Sparse_Latch),  // I: Latch third counter stage and compute maxpool for sparse case,
    .MxPl_Dense_Latch(MxPl_Dense_Latch),    // I: Latch third counter stage and compute maxpool for dense case
    .write_count(write_count),              // I: Output memory mux select
    .omem_data(omem_data),                  // O: Output memory data
    .ET_L1_TRIGG(ET_L1_TRIGG),              // O: Level 1 Early Termination Signal. Feedback to Bank Counters
    .ET_L3_TRIGG(et_full_sat),              // O: Early termination signal. 1 if full, level 3 early termination.
    .compute_done(compute_done)             // O: Compute Done Signal.
);


////////////////////////////////////////
// Output Memory
output_mem output_mem_i(
   .clk(clk), 
   .reset_n(reset_n),
   .ce(ctrl_omem_ce),
   .we(ctrl_omem_we),
   .jtag_wr(ctrl_omem_jtag_wr),
   .data(omem_data),
   .jtag_data(jtag_mem_data_wr[`OUT_MEM_DATA_WDT-1:0]),
   .addr(ctrl_omem_addr),
   .jtag_q(omem_jtag_q),
   .rd_done(omem_ctrl_rd_done)
);


endmodule                                       // SCIM_TOP
