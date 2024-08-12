`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"

module WEIGHT_LFSR_BANK_81_ROWS_WITH_DECODER (
   input                               CLK,
   input                               RESET_N,
   input                               lfsr_load,
   input [`N_L_REG-1:0]                lfsr_sel,
   input                               lfsr_en,
   input                               lfsr_option_sel,
   input [`N_L-1:0]                    LFSR_REG_INIT,
   input                               read_en,
   input                               compute_en,
   input [$clog2(`N_R*`FXP)-1:0]       READ_ADDR,

   output reg[(`N_R*`FXP)-1:0]         LFSR
             );

                                 //81 X 6 = 486
    parameter ROWS_WEIGHT_READ = `N_R*`FXP;             

    
    
    
    integer i;
    wire [`N_R*`LFSR_WIDTH-1:0] WLFSR;


always @(*) begin
   if(read_en) begin
      for(i=0;i<ROWS_WEIGHT_READ;i=i+1) begin
         if(i==READ_ADDR) LFSR[i] <= 1'b1;
         else             LFSR[i] <= 1'b0;
      end
   end

   else if(compute_en) begin
            for(i=0;i<`N_R;i=i+1) begin
               LFSR[(`LFSR_WIDTH+1)*i +: (`LFSR_WIDTH+1)] <= {1'b0,WLFSR[`LFSR_WIDTH*i +: `LFSR_WIDTH]};
            end
   end

   else begin
            for(i=0;i<`N_R;i=i+1) begin
               LFSR[(`LFSR_WIDTH+1)*i +: (`LFSR_WIDTH+1)] <= {1'b0,WLFSR[`LFSR_WIDTH*i +: `LFSR_WIDTH]};
            end
   end
end



         WEIGHT_LFSR_BANK_81_ROWS i_WLFSR_81(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_option_sel(lfsr_option_sel),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel),
               .lfsr_en(lfsr_en),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .LFSR(WLFSR)
            );


endmodule
