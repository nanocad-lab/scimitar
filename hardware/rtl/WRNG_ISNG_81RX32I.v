`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"

module WRNG_ISNG_81RX32I(
            input                        CLK,
            input                        RESET_N,

            //LFSR Control
            input                        lfsr_load, //JTAG-Signal
            input [2*`N_L_REG-1:0]       lfsr_sel, //JTAG-Signal
            input [1:0]                  lfsr_option_sel, //JTAG-Signal
            input [`N_L-1:0]             LFSR_REG_INIT, //JTAG-Signal
            input                        dense_en, //JTAG-Signal

            //Datapath Input
            input   [`N_R*`N_C*`FXP-1:0] FXPIN81X32,//Row-unrolled  first 

            //Control Path Inputs

            
            input                         comp_positive_phase,
            input                         compute_en,
            input                         read_en,
            input [$clog2(`N_R*`FXP)-1:0] READ_ADDR,
            

           
            //Datapath Output
            output reg [`N_R*`N_C-1:0]       SC_WL,
            output reg [`N_R*`FXP-1:0]       WLFSR

         
         );


wire [`N_R*`N_C-1:0]            SC_WL_INTERNAL;
wire [`N_R*`FXP-1:0]            WLFSR_INTERNAL;

//Weight Random Number Generator
         WEIGHT_LFSR_BANK_81_ROWS_WITH_DECODER i_WLFSR_81(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_option_sel(lfsr_option_sel[1]),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel[1*`N_L_REG +: `N_L_REG]),
               .lfsr_en(compute_en),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .read_en(read_en),
               .compute_en(compute_en),
               .READ_ADDR(READ_ADDR),
               .LFSR(WLFSR_INTERNAL)
               
            );

//Input Random Number Generator + SNGs

        INPUT_SNG_BANK_81X32_WITH_DECODER i_INPUT_SNG_LFSR(
                  .CLK(CLK),
                  .RESET_N(RESET_N),
                  .lfsr_option_sel(lfsr_option_sel[0]),
                  .lfsr_load(lfsr_load),
                  .lfsr_sel(lfsr_sel[0*`N_L_REG +: `N_L_REG]),
                  .LFSR_REG_INIT(LFSR_REG_INIT),
                  .SNGBANKINPUT(FXPIN81X32),
                  .dense_en(dense_en),
                  .comp_positive_phase(comp_positive_phase),//Used in SNG
                  .compute_en(compute_en),//Used-at input of LFSR stage
                  .read_en(read_en),
                  .SC_WL(SC_WL_INTERNAL)
        );


//Flip-Flops at D2A Boundary            
always @(posedge CLK or negedge RESET_N) begin
   if(~RESET_N) begin
      WLFSR <=0;
      SC_WL <=0;
   end

   else begin
      if(compute_en || read_en) begin
         WLFSR <= WLFSR_INTERNAL;
         SC_WL <= SC_WL_INTERNAL;
      end

      else begin
         WLFSR <= WLFSR;
         SC_WL <= SC_WL;
      end
   end
end

endmodule
