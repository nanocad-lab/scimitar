

`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"

module BANK_COUNTER_32X32(
   input                                     CLK,
   input                                     RESET_N,

   input                                     comp_positive_phase,
   input                                     SA_Latch,
   input                                     BnkCtr_En,
   input                                     BnkCtr_Clr,
   input                                     BnkCtr_Latch,
   input                                     BnkCtr_Buffer_Clr, 
   

   input [`N_S*`N_C-1:0]                     ET_L1_TRIGG,
   
   input [`N_S*`N_C-1:0]                     clp,
   input [`N_S*`N_C-1:0]                     cln,

   //****************Outputs*******************************//
   output [`N_S*`N_C*`BCP-1:0]               BANK_CTR_LATCHED
	               );

genvar i,j;


   generate 
         for(i=0; i<`N_S;i=i+1)
            begin : generate_CTRS_MULTI_SLICE
               for(j=0; j<`N_C;j=j+1)
               begin: generate_CTRS_WITHIN_SLICE
                     BANK_COUNTER_V01 i_BNK_CTR(
                        .CLK(CLK),
                        .RESET_N(RESET_N),
                        .SA_Latch(SA_Latch),
                        .comp_positive_phase(comp_positive_phase),
                        .BnkCtr_En(BnkCtr_En),
                        .BnkCtr_Clr(BnkCtr_Clr),
                        .BnkCtr_Latch(BnkCtr_Latch),
                        .BnkCtr_Buffer_Clr(BnkCtr_Buffer_Clr),
                        .ET_L1_TRIGG(ET_L1_TRIGG[i*`N_C+j]),
                        .clp(clp[i*`N_C+j]),
                        .cln(cln[i*`N_C+j]),
                        .BANK_CTR_LATCHED(BANK_CTR_LATCHED[(i*`N_C+j)*`BCP +: `BCP])
                        );
                end
            end
   endgenerate



endmodule                  


module BANK_COUNTER_V01(
   input                                     CLK,
   input                                     RESET_N,

   input                                     comp_positive_phase,
   input                                     SA_Latch,
   input                                     BnkCtr_En,
   input                                     BnkCtr_Clr,
   input                                     BnkCtr_Latch,
   input                                     BnkCtr_Buffer_Clr, 
   

   input                                     ET_L1_TRIGG,
   
   input                                     clp,
   input                                     cln,

   //****************Outputs*******************************//
   output reg signed [`BCP-1:0]              BANK_CTR_LATCHED
	               );
         


reg signed [`SC_ACC_WIDTH-1:0]            acc;
reg signed [`BCP-1:0]                     BANK_CTR;

reg   clp_latched;
reg   cln_latched;

//PIPE-STAGE:1 Register: Latching clp and cln from analog
always @(posedge CLK or negedge RESET_N) begin
   if(~RESET_N) begin
         clp_latched <= 0; //Clear-on-reset         
         cln_latched <= 0; //Clear-on-reset
   end

   else begin
      if(ET_L1_TRIGG) begin
         clp_latched <= clp_latched;
         cln_latched <= cln_latched;
      end
      
      else if(SA_Latch) begin
         clp_latched <= clp;
         cln_latched <= cln;
      end

      else begin
         clp_latched <= clp_latched;
         cln_latched <= cln_latched;
      end
   end
end

//PIPE-STAGE:2 Register: Bank Counter Op
always @(posedge CLK or negedge RESET_N) begin
   if(~RESET_N) begin
         BANK_CTR <= 0; //Clear-on-reset         

   end

   else begin
      if(BnkCtr_Clr) begin
            BANK_CTR <= 0;
      end

      else if(ET_L1_TRIGG) begin
            BANK_CTR <= BANK_CTR;
      end
      
      else if(BnkCtr_En) begin
            BANK_CTR <= BANK_CTR + acc;
      end

      else begin
            BANK_CTR <= BANK_CTR; 
      end
   end

end

always @(*) begin
      if(comp_positive_phase) acc <= clp_latched-cln_latched;
      else                    acc <= cln_latched-clp_latched;
end

//PIPE-STAGE:3 Register: Bank Counter Latch
always @(posedge CLK or negedge RESET_N) begin
   if(~RESET_N) begin
         BANK_CTR_LATCHED <= 0; //Clear-on-reset         

   end

   else begin
      if(BnkCtr_Buffer_Clr) begin
         BANK_CTR_LATCHED <= 0;
      end

      else if(ET_L1_TRIGG) begin
         BANK_CTR_LATCHED <= BANK_CTR_LATCHED;
      end
      else if(BnkCtr_Latch) begin
         BANK_CTR_LATCHED <= BANK_CTR;
      end

      else begin
         BANK_CTR_LATCHED <= BANK_CTR_LATCHED;
      end
   end
end

endmodule

