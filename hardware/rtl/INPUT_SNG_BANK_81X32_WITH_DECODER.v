`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"

module INPUT_SNG_BANK_81X32_WITH_DECODER(
            input                        CLK,
            input                        RESET_N,

            //LFSR Control
            input                               lfsr_load, //JTAG-Signal
            input [`N_L_REG-1:0]                lfsr_sel, //JTAG-Signal
            input                               lfsr_option_sel, //JTAG-Signal
            input [`N_L-1:0]                    LFSR_REG_INIT, //JTAG-Signal


            input   [`N_R*`N_C*`FXP-1:0] SNGBANKINPUT,//Row-unrolled  first  
            input                        dense_en,
            input                        comp_positive_phase,
            input                        compute_en,
            input                        read_en,
            output reg [`N_R*`N_C-1:0]   SC_WL
   );

   
wire [`N_R*`N_C-1:0]   SC_WL_INTERNAL;

        INPUT_SNG_BANK_81X32_6BIT DUT(
                  .CLK(CLK),
                  .RESET_N(RESET_N),
                  .lfsr_option_sel(lfsr_option_sel),
                  .lfsr_load(lfsr_load),
                  .lfsr_sel(lfsr_sel),
                  .LFSR_REG_INIT(LFSR_REG_INIT),
                  .SNGBANKINPUT(SNGBANKINPUT),
                  .dense_en(dense_en),
                  .comp_positive_phase(comp_positive_phase),//Used in SNG
                  .compute_en(compute_en),//Used-at input of LFSR stage
                  .SC_WL(SC_WL_INTERNAL)
        );

        always @(*) begin
            if(read_en) begin
               SC_WL <={(`N_R*`N_C){1'b1}};
            end

            else begin
               SC_WL <= SC_WL_INTERNAL;
            end

        end
     endmodule


module INPUT_SNG_BANK_81X32_6BIT(
            input                        CLK,
            input                        RESET_N,

            //LFSR Control
            input                               lfsr_load, //JTAG-Signal
            input [`N_L_REG-1:0]                lfsr_sel, //JTAG-Signal
            input                               lfsr_option_sel, //JTAG-Signal
            input [`N_L-1:0]                    LFSR_REG_INIT, //JTAG-Signal


            input   [`N_R*`N_C*`FXP-1:0] SNGBANKINPUT,//Row-unrolled  first  
            input                        dense_en,
            input                        comp_positive_phase,
            input                        compute_en,
            output  [`N_R*`N_C-1:0]      SC_WL
   );


wire LFSR_EN;

assign LFSR_EN = compute_en&dense_en;



//*****************Vector index convention when mapping from 81X32 matrix to 2592X1 vector
//
//         m --> Row index. m : (0 to 80)
//         n --> Col index. n : (0 to 31)
//         k --> Output vector index. k : (0 to 2591)
//
//
//
//                                 --------------------
//                                 --------------------
//                                 |||   k=32*m+n   |||
//                                 --------------------
//                                 --------------------
//      
//                                 --------------------
//                                 --------------------
//                                 |||   m=k%32     |||
//                                 |||   n=k/32     |||
//                                 --------------------
//                                 --------------------
//
//


       
wire [`N_R*`LFSR_WIDTH-1:0] LFSR;

         INPUT_LFSR_BANK_81_ROWS i_LFSR_81(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_option_sel(lfsr_option_sel),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel),
               .lfsr_en(LFSR_EN),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .LFSR(LFSR)
            );
        


        //Generate SNGs: 2192(81X32) distinct SNGs created. Each generating 1 SC sequence. 

        genvar i;
        genvar j;

     generate 
       for(i = 0; i < `N_R; i=i+1)
         begin: generate_traverse_ydim
                  for(j=0; j < `N_C; j=j+1)
                     begin: generate_traverse_xdim
                    
                        INPUT_SNG i_INPUT_SNG(

                              .LFSR(LFSR[(i*`LFSR_WIDTH) +: `LFSR_WIDTH]), //LFSR sequence shared across row
                              .FIXED_PT_IN(SNGBANKINPUT[(`FXP*(`N_C*i+j)) +: `FXP]),
                              .comp_positive_phase(comp_positive_phase),
                              .dense_en(dense_en),
                              .SC_BIT(SC_WL[`N_C*i+j])//Row-First
                                       );
                     end

         end
     endgenerate


endmodule


module INPUT_SNG(
input        [`LFSR_WIDTH-1:0]          LFSR,
input        [`FXP-1:0]                 FIXED_PT_IN,
input                                   comp_positive_phase,
input                                   dense_en,
output reg                              SC_BIT
);


integer i;

wire [`LFSR_WIDTH-1:0] FXP_IN_MAG;
reg [`LFSR_WIDTH-1:0] SNG;
wire FXP_IN_SIGN_BIT;

assign FXP_IN_SIGN_BIT = FIXED_PT_IN[`FXP-1];
assign FXP_IN_MAG = FIXED_PT_IN[`LFSR_WIDTH-1:0];

always @(*) begin
         for(i=0;i<`LFSR_WIDTH;i=i+1) begin //SNG Logic
            if(i>0) begin    //First 4-mux logic. Either choose fixed point input or previous mux result.
               if(LFSR[i]) SNG[i] <= FXP_IN_MAG[i];
               else        SNG[i] <= SNG[i-1];
            end

            else begin     //Last (LSB) mux logic. Either choose FIXED_PT_IN[0] or 0. Check slides for SNG logic diagram.
               if(LFSR[i]) SNG[i] <= FXP_IN_MAG[i];
               else        SNG[i] <= 0;
            end
         end


         if(!FXP_IN_MAG)           SC_BIT<=0; // if magnitude of the FIXED_PT_IN is 0, then SC_BIT is zero. Over-rides all other SNG logic
         else begin
            if(dense_en) begin
               if(comp_positive_phase) begin //Positive-Phase
                     if(~FXP_IN_SIGN_BIT) SC_BIT <= SNG[`LFSR_WIDTH-1];
                     else  SC_BIT <= 0;
               end
            
               else begin//Negative-Phase
                     if(FXP_IN_SIGN_BIT) SC_BIT <= SNG[`LFSR_WIDTH-1];
                     else  SC_BIT <= 0;
               end
            end
          
            else begin
               if(comp_positive_phase) begin //Positive-Phase
                     if(~FXP_IN_SIGN_BIT) SC_BIT <= 1;
                     else  SC_BIT <= 0;
               end
            
               else begin//Negative-Phase
                     if(FXP_IN_SIGN_BIT) SC_BIT <= 1;
                     else  SC_BIT <= 0;
               end
            end
         end
end
endmodule

