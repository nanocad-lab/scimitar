`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"


module SCIM_BANK_CONTROLLER(

	input 				CLK,
	input 				RESET_N,
   //JTAG-Config Bits
   input             bank_en,
   input             simpl_ctrl_banks,
   input             bank_ctr_clr_override,

   //FSM Control Bits
   input 				READ_EN,
	input 				WRITE_EN,
	input 				COMP_EN,
   input             roi_lb_r,
   
   
   //Weights Rd/Wr Interface
   output reg			DECODER_EN,
   output reg        COMP_EN_MACRO,
  
   input      [`N_S-1:0]	READ_IN,
	output reg [`N_S-1:0]	READ_OUT,
   
   input             comp_positive_phase,
   input             SA_Latch,
   input             BnkCtr_En,
   input             BnkCtr_Latch,
   input             BnkCtr_Clr,
   input             BnkCtr_Buffer_Clr,


   //Control Signal Outputs
   output            compute_en_PIPE_M1,
   output            comp_positive_phase_PIPE_M1,
   output            roi_lb_r_q,

   output            SA_Latch_PIPE0, 

   output            comp_positive_phase_PIPE1,
   output            BnkCtr_En_PIPE1,
   output            BnkCtr_Clr_PIPE1,

   output            BnkCtr_Latch_PIPE2,
   output            BnkCtr_Buffer_Clr_PIPE2,
   output reg        READ_DONE


);


reg  SA_Latch_PIPE_M1           ;
reg  BnkCtr_En_PIPE_M1          ;
wire BnkCtr_Latch_PIPE_M1       ;
wire BnkCtr_Clr_PIPE_M1         ;
reg  BnkCtr_Buffer_Clr_PIPE_M1  ;
wire compute_en_PIPE_M1_UG      ; //Compute-Enable ungated version at M1 level. 1-CLK delayed version from FSM.  


//**************Gating with Bank-En*******************//
assign compute_en_PIPE_M1           = (bank_en & compute_en_PIPE_M1_UG); //Gated with bank-en
assign comp_positive_phase_PIPE_M1  = comp_positive_phase;

//*************Bare-Min Control Signals needed from FSM ***********//
assign BnkCtr_Latch_PIPE_M1         = BnkCtr_Latch;                                 
assign BnkCtr_Clr_PIPE_M1           = BnkCtr_Clr;


//***************Logic for Debug-options***************//

always @(*) begin
   if(simpl_ctrl_banks) SA_Latch_PIPE_M1 <= compute_en_PIPE_M1;
   else                 SA_Latch_PIPE_M1 <= SA_Latch;
end

always @(*) begin
   if(simpl_ctrl_banks) BnkCtr_En_PIPE_M1 <= compute_en_PIPE_M1;
   else                 BnkCtr_En_PIPE_M1 <= BnkCtr_En;
end

always @(*) begin
   if(bank_ctr_clr_override) begin
      BnkCtr_Buffer_Clr_PIPE_M1 <= 1'b0;
   end

   else begin
      if(simpl_ctrl_banks) begin
         BnkCtr_Buffer_Clr_PIPE_M1 <= BnkCtr_Clr;
      end

      else begin
         BnkCtr_Buffer_Clr_PIPE_M1 <= BnkCtr_Buffer_Clr;
      end
   end

end


//**************Weight SRAM Read-Write Control Interface************//
always @(*) begin
	COMP_EN_MACRO <= compute_en_PIPE_M1 | READ_EN;
end 

reg readen_buf;

always @(posedge CLK or negedge RESET_N ) begin
	if(!RESET_N)begin
      DECODER_EN = 1'b0;
   end

   else begin
      DECODER_EN = WRITE_EN;
   end
end


always @(posedge CLK or negedge RESET_N ) begin
	if(!RESET_N)begin
		READ_OUT       <= 0;
      READ_DONE      <= 0;
      readen_buf     <= 0;
	end else begin 
	//READ Operation:
      readen_buf     <= READ_EN; // 1 cycle later the macro starts to read
      READ_DONE      <= readen_buf; // 2 cycle later the macro latched the read output in the boundary registers
		if(readen_buf) begin
			READ_OUT <= READ_IN;
		end	
	end

end 


//************Control Path Pipeline**************//
 CONTROL_PIPE_BANK i_CONTROL_PIPE(

         .CLK(CLK),
         .RESET_N(RESET_N),
         .compute_en_PIPE_M2(COMP_EN),
         .comp_positive_phase_PIPE_M1(comp_positive_phase_PIPE_M1),
         .roi_lb_r(roi_lb_r),
         .SA_Latch_PIPE_M1(SA_Latch_PIPE_M1),
         .BnkCtr_En_PIPE_M1(BnkCtr_En_PIPE_M1),
         .BnkCtr_Latch_PIPE_M1(BnkCtr_Latch_PIPE_M1),
         .BnkCtr_Clr_PIPE_M1(BnkCtr_Clr_PIPE_M1),
         .BnkCtr_Buffer_Clr_PIPE_M1(BnkCtr_Buffer_Clr_PIPE_M1),

         .compute_en_PIPE_M1(compute_en_PIPE_M1_UG),
         .roi_lb_r_q(roi_lb_r_q),

         .SA_Latch_PIPE0(SA_Latch_PIPE0),

         .comp_positive_phase_PIPE1(comp_positive_phase_PIPE1),
         .BnkCtr_En_PIPE1(BnkCtr_En_PIPE1),
         .BnkCtr_Clr_PIPE1(BnkCtr_Clr_PIPE1),

         .BnkCtr_Latch_PIPE2(BnkCtr_Latch_PIPE2),
         .BnkCtr_Buffer_Clr_PIPE2(BnkCtr_Buffer_Clr_PIPE2)
         );

endmodule



module CONTROL_PIPE_BANK(

   input CLK,
   input RESET_N,
   input compute_en_PIPE_M2,
   input comp_positive_phase_PIPE_M1, //y
   input roi_lb_r,

   input SA_Latch_PIPE_M1,
   input BnkCtr_En_PIPE_M1,
   input BnkCtr_Latch_PIPE_M1,
   input BnkCtr_Clr_PIPE_M1,
   input BnkCtr_Buffer_Clr_PIPE_M1,

   output reg compute_en_PIPE_M1,
   output reg roi_lb_r_q,

   output reg SA_Latch_PIPE0, //y

   output reg comp_positive_phase_PIPE1, //y
   output reg BnkCtr_En_PIPE1, //y
   output reg BnkCtr_Clr_PIPE1, //y

   output reg BnkCtr_Latch_PIPE2, //y
   output reg BnkCtr_Buffer_Clr_PIPE2 //y

);


   //Terminates at PIPE1
   reg comp_positive_phase_PIPE0;
   reg BnkCtr_En_PIPE0;
   reg BnkCtr_Clr_PIPE0;
 

   //Terminates at PIPE2
   reg BnkCtr_Latch_PIPE0;
   reg BnkCtr_Latch_PIPE1;
   
   
   reg BnkCtr_Buffer_Clr_PIPE0;
   reg BnkCtr_Buffer_Clr_PIPE1;

//PIPE-M1 Control Signals
always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin
      compute_en_PIPE_M1 <= 1'b0;
      roi_lb_r_q         <= 1'b0;
   end

   else begin
      compute_en_PIPE_M1 <= compute_en_PIPE_M2;
      roi_lb_r_q         <= roi_lb_r;
   end
end

      
//PIPE0 Control Signals
always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin
      comp_positive_phase_PIPE0 <= 0;
      BnkCtr_En_PIPE0           <= 0;
      SA_Latch_PIPE0            <= 0;
      BnkCtr_Latch_PIPE0        <= 0;
      BnkCtr_Clr_PIPE0          <= 0;
      BnkCtr_Buffer_Clr_PIPE0   <= 0;


   end

   else begin

      comp_positive_phase_PIPE0 <= comp_positive_phase_PIPE_M1;
      BnkCtr_En_PIPE0           <= BnkCtr_En_PIPE_M1        ;
      SA_Latch_PIPE0            <= SA_Latch_PIPE_M1         ;
      BnkCtr_Latch_PIPE0        <= BnkCtr_Latch_PIPE_M1     ;
      BnkCtr_Clr_PIPE0          <= BnkCtr_Clr_PIPE_M1       ;
      BnkCtr_Buffer_Clr_PIPE0   <= BnkCtr_Buffer_Clr_PIPE_M1;

   end

end

//PIPE1 Control Signals
always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin
      comp_positive_phase_PIPE1 <= 0;
      BnkCtr_En_PIPE1           <= 0;
      BnkCtr_Latch_PIPE1        <= 0;
      BnkCtr_Clr_PIPE1          <= 0;
      BnkCtr_Buffer_Clr_PIPE1   <= 0;
   end

   else begin

      comp_positive_phase_PIPE1 <= comp_positive_phase_PIPE0;
      BnkCtr_En_PIPE1           <= BnkCtr_En_PIPE0        ;
      BnkCtr_Latch_PIPE1        <= BnkCtr_Latch_PIPE0     ;
      BnkCtr_Clr_PIPE1          <= BnkCtr_Clr_PIPE0       ;
      BnkCtr_Buffer_Clr_PIPE1   <= BnkCtr_Buffer_Clr_PIPE0;
   end

end
//PIPE2 Control Signals
always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin
      BnkCtr_Latch_PIPE2        <= 0;
      BnkCtr_Buffer_Clr_PIPE2   <= 0;
   end

   else begin

      BnkCtr_Latch_PIPE2        <= BnkCtr_Latch_PIPE1     ;
      BnkCtr_Buffer_Clr_PIPE2   <= BnkCtr_Buffer_Clr_PIPE1;
   end

end

endmodule






