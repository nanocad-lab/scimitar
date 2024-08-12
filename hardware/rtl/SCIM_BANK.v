`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"


module SCIM_BANK(
            input                        CLK,
            input                        RESET_N,

            //JTAG Control
            input                        lfsr_load, //JTAG-Signal
            input [5:0]                  lfsr_sel, //JTAG-Signal
            input [1:0]                  lfsr_option_sel, //JTAG-Signal
            input [`N_L-1:0]             LFSR_REG_INIT, //JTAG-Signal
            input [3:0]                  VTHRES, //JTAG-Signal
            input                        dense_en,//JTAG-Signal
            input                        bank_en,//JTAG-Signal
            input                        simpl_ctrl_banks,
            input                        bank_ctr_clr_override,
			
			// Read and Write
			input 						        READ_EN,
			input						           WRITE_EN,
         input [`WGT_MEM_ADDR_WDT_WR-1:0]   WRITE_ADDR, //162
         input [`WGT_MEM_ADDR_WDT_RD-1:0]   READ_ADDR, 
         input [3*`N_S-1:0]    			  DIN,
			output [`N_S-1:0]				     READ_OUT,
         output                          READ_DONE,

			//Bank Buffer
         input [`BB_REG_WIDTH*`FXP-1:0]  BB_IN,
			input					              BB_EN,
			input						           BB_CLR,
          
          //******[10/15/22]VKJ: Removed Zero indicators.
		    //  	input [`MAC_CN_HGT-1:0] 	     BB_ZERO_IN,
          //******[10/15/22]VKJ: Removed Zero indicators.
			
		   //Inputs from FSM
            input                        roi_lb_r,
            input                        comp_positive_phase,
            input                        COMP_EN,
            input                        SA_Latch,
            input                        BnkCtr_En,
            input                        BnkCtr_Latch,
            input                        BnkCtr_Clr,
            input                        BnkCtr_Buffer_Clr,
		            


         //Feed-back inputs from Global Counters
            input [`N_S*`N_C-1:0]        ET_L1_TRIGG,
			
         //Output to Global Counters
            output [`N_S*`N_C*`BCP-1:0]  BANK_CTR_LATCHED



   );



wire [`N_S*`N_C-1:0]       clp;
wire [`N_S*`N_C-1:0]       cln;


wire [`N_R*`FXP-1:0] WLFSR;
wire [`N_R*`N_C-1:0] SC_WL;

wire comp_en_macro;
wire write_en_macro;
wire decoder_en;

wire [2*`N_R-1:0] wl;

//Control-Path Signals at PIPE_M1 Level (Updates along with SNG)      (Input to registers at PIPE0)
wire compute_en_PIPE_M1;
wire comp_positive_phase_PIPE_M1;
wire roi_lb_r_q;

//Control-Path Signals at PIPE0 Level (Updates along with SCIM Macro) (Input to registers at PIPE1)
wire SA_Latch_PIPE0;
//Control-Path Signals at PIPE1 Level (Updates along with Bank Counter Logic) (Inputs to registers at PIPE2)
wire comp_positive_phase_PIPE1;
wire BnkCtr_En_PIPE1;
wire BnkCtr_Clr_PIPE1;
//Control-Path Signals at PIPE2 Level (Inputs to registers at PIPE3)
wire BnkCtr_Latch_PIPE2;
wire BnkCtr_Buffer_Clr_PIPE2;

reg [`N_S-1:0] readin;
integer i;
always @(*) begin
	for (i=0;i<`N_S;i=i+1) begin
		readin[i] = clp[i*`N_C] | cln[i*`N_C];
	end
end

//SCIM Bank Controller
SCIM_BANK_CONTROLLER bk_ctrl(
	.CLK(CLK),                                                  //I:     Clock
	.RESET_N(RESET_N),                                          //I:     Active Low Asynchronous Reset
   
   .bank_en(bank_en),                                          //I:     JTAG Config input. Bank Gating Signal
   .simpl_ctrl_banks(simpl_ctrl_banks),                        //I:     JTAG Config input. Simplify Control Signals
   .bank_ctr_clr_override(bank_ctr_clr_override),              //I:     JTAG Config input. Over-rides clearing of Bank Counter Shadow
   
   .READ_EN(READ_EN),                                          //I:     Weight SRAM Read enable. JTAG Control 
	.WRITE_EN(WRITE_EN),                                        //I:     Weight SRAM Write enable. JTAG Control
   
   .DECODER_EN(decoder_en),                                    //O:     Weight SRAM Write decoder Enable.  Retimed to CLK edge
   .COMP_EN_MACRO(comp_en_macro),                              //O:     Compute Enable. (Or of compute_en and READ_EN)
	.READ_IN(readin),                                           //I:[32] Weight SRAM Sense-Amp result
	.READ_OUT(READ_OUT),                                        //I:[32] Weight SRAM Sense-Amp result Latched. To JTAG
	//Pipe-In: -2
   .COMP_EN(COMP_EN),                                          //I:     Compute Enable from global FSM. Ungated Version
   .roi_lb_r(roi_lb_r),                                        //I:     ROI Indicator. 

   //Pipe-In: -1
   .comp_positive_phase(comp_positive_phase),                  //I:     Indicates pos/neg SC compute.          At PIPE_M1. From FSM
   .SA_Latch(SA_Latch),                                        //I:     Latching control for Sense-Amp Output. At PIPE_M1. From FSM
   .BnkCtr_En(BnkCtr_En),                                      //I:     Bank Counter Operation Enable.         At PIPE_M1. From FSM
   .BnkCtr_Latch(BnkCtr_Latch),                                //I:     Bank Counter Latch Enable(16/32/48/64).At PIPE_M1. From FSM
   .BnkCtr_Clr(BnkCtr_Clr),                                    //I:     Bank Counter Reg Clear                .At PIPE_M1. From FSM
   .BnkCtr_Buffer_Clr(BnkCtr_Buffer_Clr),                      //I:     Bank Counter Buffer Clear             .At PIPE_M1. From FSM


    //Pipe-Out:-1                          
   .compute_en_PIPE_M1(compute_en_PIPE_M1),                    //O:     Compute-En Gated Version 
   .comp_positive_phase_PIPE_M1(comp_positive_phase_PIPE_M1),  //O:     Indicates pos/neg SC compute.          At PIPE_M1. To SNGs and LFSRs
   .roi_lb_r_q(roi_lb_r_q),                                    //O:     Latched version of ROI. [10/19/22]VKJ: Added for timing closure.
   
   //Pipe-Out:0
   .SA_Latch_PIPE0(SA_Latch_PIPE0),                            //O:     Latching control for Sense-Amp Output.    At PIPE0. To Bank Counter Module 
   //Pipe-Out:1
   .comp_positive_phase_PIPE1(comp_positive_phase_PIPE1),      //O:     controls up/dn operation of Bank-Counter. At PIPE1. To Bank Counter Module
   .BnkCtr_En_PIPE1(BnkCtr_En_PIPE1),                          //O:     Bank Counter Operation Enable.            At PIPE1. To Bank Counter Module
   .BnkCtr_Clr_PIPE1(BnkCtr_Clr_PIPE1),                        //O:     Bank Counter  Reg Clear.                  At PIPE1. To Bank Counter Module
   //Pipe-Out:2
   .BnkCtr_Latch_PIPE2(BnkCtr_Latch_PIPE2),                    //O:     Bank Counter Latch Enable(16/32/48/64).   At PIPE2. To Bank Counter Module
   .BnkCtr_Buffer_Clr_PIPE2(BnkCtr_Buffer_Clr_PIPE2),          //O:     Bank Counter Buffer Clear                 At PIPE2. To Bank Counter Module 
   .READ_DONE(READ_DONE)                                       //O:     WGT Memory read-done signal to controller 
   );

wire [(`MAC_CN_HGT*`BB_WIDTH*`FXP-1):0] BB_OUT;

bankbuff_new i_bb(
    .clk(CLK),                      // I:         Clock input
    .en(BB_EN),                     // I:         Buffer enable 
    .clr(BB_CLR),                   // I:         Buffer clear
    
    //******[10/15/22]VKJ: Removed Zero indicators.
         //    .zero_in(BB_ZERO_IN),           // I:         Zero indicator in
         //    .zero_out(),                    // O:         Zero indicator out
    //******[10/15/22]VKJ: Removed Zero indicators.

    .val_in(BB_IN),                 // I:[(32+4)x6] 4 extras from right for roi_l and 4 extras from left for roi_r
    .roi_lb_r(roi_lb_r_q),          // I:         Indicates left (0) or right (1) roi to the bank_buffer to decide location of zero-padding
    .val_out(BB_OUT)                // O:[9x40x6] Bank-Buffer output- Zero Padded appropriately
);

wire [`N_C*`N_R*`FXP-1:0] fp_in;

INPUT_MUX in_mx(
	.BB_OUT(BB_OUT),                //I:[9x40x6]  Bank-Buffer output
	.MACRO_IN(fp_in)                //O:[81x32x6] Fixed point input to SNGs
   );
			
// Decoder
DECODER_8B dec8 ( 
      .ADD8(WRITE_ADDR),           //I:[8]   8-bit Weight SRAM write address to 162 wordlines
      .WL(wl),                     //O:[162] Weight SRAM Write Wordlines
      .EN(decoder_en)              //I:      Decoder enable from Write Controller
      );


//SCIM Macro Digital Input Side
 WRNG_ISNG_81RX32I i_DIG(
		.CLK(CLK),                                            //I:         Clock
		.RESET_N(RESET_N),                                    //I:         Active Low Asynch Reset 
		.lfsr_load(lfsr_load),                                //I:         LFSR Init Mode. JTAG static control
		.lfsr_sel(lfsr_sel),                                  //I:[6]      LFSR Register select line for initializing. JTAG static control 
		.lfsr_option_sel(lfsr_option_sel),                    //I:[2]      LFSR mapping option select. B0 for Input LFSR, B1 for Weight LFSR. JTAG static control
		.LFSR_REG_INIT(LFSR_REG_INIT),                        //I:         LFSR Register initialization. JTAG static control.
		.dense_en(dense_en),                                  //I:         Dense Mode indicator. JTAG static control
		.FXPIN81X32(fp_in),                                   //I:[81x32x6]Fixed Point Inputs from Bank Buffer Mux
		.comp_positive_phase(comp_positive_phase_PIPE_M1),    //I:         Indicates Pos/Neg SNG from FSM. At PIPE_M1
		.compute_en(compute_en_PIPE_M1),                      //I:         Compute Enable from FSM.        At PIPE_M1
		.read_en(READ_EN),                                    //I:         Read Enable
      .READ_ADDR(READ_ADDR),                                //I:[9]      Weight SRAM Read Address. JTAG static control
		.SC_WL(SC_WL),                                        //I:[81x32]  SC Bit from SNG during compute. all 1's during read
      .WLFSR(WLFSR)                                         //I:[81x6]   81x{0,5'bRN} Weight Random Numbers during compute. Weight SRAM decoder output during read 
		);
			


//SCIM Macro Analog
 SCIM_Macro_81x32 scim_macro(
      .I(SC_WL),                                          //I:[81x32]  SC Bit from SNG during compute. all 1's during read                                        
      .RN(WLFSR),                                         //I:[81x6]   81x{0,5'bRN} Weight Random Numbers during compute. Weight SRAM decoder output during read
      .WL(wl),                                            //I:[162]    Weight SRAM Wordline: From Write controller
      .DIN(DIN),                                          //I:[96]     Weight SRAM Write Data: From Write controller
      .WRITE_EN(WRITE_EN),                                //I:         Weight SRAM Write control: From Write controller
      .COMP_EN(comp_en_macro),                            //I:         SCIM Macro Compute Enable: Should be high for compute and read modes
      .CLK(CLK),                                          //I:         Clock
      .RESET(~RESET_N),                                   //I:         Active High Asynch Reset
      .DOUTP(clp),                                        //I:[32x32]  Sense-Amp Result 'p' to counter interface
      .DOUTN(cln),                                        //I:[32x32]  Sense-Amp Result 'n' to counter interface
`ifdef MACRO_ANA
      .VDDA(),
      .VSS(),
`endif
      .VTHRES(VTHRES)                                     //I:[4]      Sense-Amp Threshold programmability: JTAG static control

      );


//Bank Counters 32 slices, 32 compute lines		 
      BANK_COUNTER_32X32 i_BNK_CTR(
         .CLK(CLK),                                      //I:          Clock
         .RESET_N(RESET_N),                              //I:          Active-Low Asynch Reset
         .SA_Latch(SA_Latch_PIPE0),                      //I:          Sense-Amp result Latching control. Inserted to meet timing for analog Macro. At PIPE0
         .comp_positive_phase(comp_positive_phase_PIPE1),//I:          Up/Dn Control of Bank Counter from FSM. At PIPE1
         .BnkCtr_En(BnkCtr_En_PIPE1),                    //I:          Bank Counter Register Enable Acc.       At PIPE1
         .BnkCtr_Clr(BnkCtr_Clr_PIPE1),                  //I:          Clearing signal to Bank Ctr Register.   At PIPE1
         .BnkCtr_Latch(BnkCtr_Latch_PIPE2),              //I:          Latching signal to Bank Ctr Latch.      At PIPE2
         .BnkCtr_Buffer_Clr(BnkCtr_Buffer_Clr_PIPE2),    //I:          Clearing signal to Bank Ctr Latch.      At PIPE2
         .ET_L1_TRIGG(ET_L1_TRIGG),                      //I:[32x32]   Early Termination Result from Global Counters
         .clp(clp),                                      //I:[32x32]   Sense-Amp Result 'p' from SCIM Macro Analog
         .cln(cln),                                      //I:[32x32]   Sense-Amp Result 'n' from SCIM Macro Analog
         .BANK_CTR_LATCHED(BANK_CTR_LATCHED)             //O:[32x32x7] Output of Bank-Counter to global counter
         );
            

endmodule
