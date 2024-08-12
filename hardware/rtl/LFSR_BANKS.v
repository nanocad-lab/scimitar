`timescale 1ns/1ps

`include "ERI-DA_HEADERS.vh"

module OHE_LOGIC(
   input [`LFSR_WIDTH-1:0]       LFSR_RAW,
   output reg [`LFSR_WIDTH-1:0]  LFSR_OHE
	               );
         

integer i;                 
                                
//always @(*) begin
// //Using utility of verilog blocking statements.
//
//   //Initialize Output to Zero. *********** Default case. 
//   LFSR_OHE = {`LFSR_WIDTH{1'b0}};
//
//   for (i=`LFSR_WIDTH-1;i>=0;i=i-1)
//   begin
//      if(LFSR_RAW[i]) LFSR_OHE[i] = 1'b1; //************If the raw LFSR i-th bit is high, overwrite i-th output bit.
//      //*********copy current bit to lower-bit. This returns a '0' only if all MSB bits prior to it is '0' /
//      LFSR_OHE[i-1] = LFSR_OHE[i];
//      //if (i>0) LFSR_OHE[i-1] = LFSR_OHE[i]; 
//   end
//end

always @(*) begin

   LFSR_OHE[4] <= LFSR_RAW[4];
   LFSR_OHE[3] <= !LFSR_RAW[4] & LFSR_RAW[3];
   LFSR_OHE[2] <= !LFSR_RAW[4] & !LFSR_RAW[3] & LFSR_RAW[2];
   LFSR_OHE[1] <= !LFSR_RAW[4] & !LFSR_RAW[3] & !LFSR_RAW[2] & LFSR_RAW[1];
   LFSR_OHE[0] <= !LFSR_RAW[4] & !LFSR_RAW[3] & !LFSR_RAW[2] & !LFSR_RAW[1] & LFSR_RAW[0];

end

endmodule


module LFSR_REG(
   input                   CLK,
   input                   RESET_N,
   input                   lfsr_load,
   input                   lfsr_sel,
   input                   lfsr_en,
   input  [`N_L-1:0]       LFSR_REG_INIT,
   output [`N_L-1:0]       LFSR_REG_OUT
         );

reg [`N_L-1:0]       FF;

assign LFSR_REG_OUT =FF;

always @(posedge CLK or negedge RESET_N) begin

   if(!RESET_N) begin
      FF<= 32'b0000_0101_0111_0110_0011_1110_0110_1001; 
   end

   else begin
      if(lfsr_load) begin
         if(lfsr_sel) begin
            FF<=LFSR_REG_INIT;
         end

         else begin
            FF<=FF; //CLK-gate
         end
      end

      else begin
         if(lfsr_en) begin
            FF[`N_L-1:1] <= FF[`N_L-2:0];
            FF[0]        <= FF[`N_L-1];
         end

         else begin
            FF<=FF; //CLK-gate
         end
      end
   end

end

endmodule


module LFSR_32(
   input                               CLK,
   input                               RESET_N,
   input                               lfsr_load,
   input                               lfsr_sel,
   input                               lfsr_en,
   input  [`N_L-1:0]                   LFSR_REG_INIT,
   output reg [`N_L*`LFSR_WIDTH-1:0]   LFSR_SEQ_OPTION0,
   output reg [`N_L*`LFSR_WIDTH-1:0]   LFSR_SEQ_OPTION1
   );




   wire [`N_L-1:0]                    LFSR_REG_OUT;
   reg [(`N_L+`LFSR_WIDTH-1)-1:0]     LFSR_REG_EXTENDED;
   
   
   always @(*) begin
       LFSR_REG_EXTENDED = {LFSR_REG_OUT[`LFSR_WIDTH-1-1:0],LFSR_REG_OUT};
   end
  
   integer i;
   always @(*) begin
      for(i=0;i<`N_L;i=i+1) begin
         LFSR_SEQ_OPTION0[`LFSR_WIDTH*i +: `LFSR_WIDTH] <= LFSR_REG_EXTENDED[((i+8)%`N_L) +: `LFSR_WIDTH];//Option-0 Mapping
         LFSR_SEQ_OPTION1[`LFSR_WIDTH*i +: `LFSR_WIDTH] <= LFSR_REG_EXTENDED[((7*i)%`N_L) +: `LFSR_WIDTH];//Option-1 Mapping
     end
   end

   LFSR_REG i_LFSR_REG(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel),
               .lfsr_en(lfsr_en),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .LFSR_REG_OUT(LFSR_REG_OUT)
            );

endmodule


module WEIGHT_LFSR_BANK_81_ROWS (
   input                               CLK,
   input                               RESET_N,
   input                               lfsr_load,
   input [`N_L_REG-1:0]                lfsr_sel,
   input                               lfsr_en,
   input                               lfsr_option_sel,
   input [`N_L-1:0]                    LFSR_REG_INIT,
   output [`N_R*`LFSR_WIDTH-1:0]       LFSR
             );

parameter N_RR = `N_L_REG*`N_L;
  
wire [N_RR*`LFSR_WIDTH-1:0] LFSR_EXTENDED_OPTION0;
wire [N_RR*`LFSR_WIDTH-1:0] LFSR_EXTENDED_OPTION1;
reg [`N_R*`LFSR_WIDTH-1:0]   LFSR_RAW;

//Mux which selects among LFSR-ROW mapping options
always @(*) begin
   case(lfsr_option_sel)
      0:        LFSR_RAW <= LFSR_EXTENDED_OPTION0[`N_R*`LFSR_WIDTH-1:0];
      1:        LFSR_RAW <= LFSR_EXTENDED_OPTION1[`N_R*`LFSR_WIDTH-1:0];
      default:  LFSR_RAW <= LFSR_EXTENDED_OPTION0[`N_R*`LFSR_WIDTH-1:0];
   endcase
end
   
`ifdef OHE_EN_WEIGHT_LFSR
      genvar j;
      generate
         for(j=0;j<`N_R;j=j+1) 
         begin: gen_OHE
            OHE_LOGIC i_OHE_LOGIC(
                  .LFSR_RAW(LFSR_RAW[j*`LFSR_WIDTH +: `LFSR_WIDTH]),
                  .LFSR_OHE(LFSR[j*`LFSR_WIDTH +: `LFSR_WIDTH])

            );
         end
      endgenerate
`endif

`ifndef OHE_EN_WEIGHT_LFSR
      assign LFSR = LFSR_RAW;
`endif


 genvar i;

 generate
    for(i=0;i<`N_L_REG;i=i+1)
    begin: gen_LFSR
        LFSR_32 i_LFSR_32(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel[i]),
               .lfsr_en(lfsr_en),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .LFSR_SEQ_OPTION0(LFSR_EXTENDED_OPTION0[(`LFSR_WIDTH*`N_L*i) +: (`LFSR_WIDTH*`N_L)]),
               .LFSR_SEQ_OPTION1(LFSR_EXTENDED_OPTION1[(`LFSR_WIDTH*`N_L*i) +: (`LFSR_WIDTH*`N_L)])
            );
    
    end
 endgenerate

 endmodule

 
 module INPUT_LFSR_BANK_81_ROWS (
   input                               CLK,
   input                               RESET_N,
   input                               lfsr_load,
   input [`N_L_REG-1:0]                lfsr_sel,
   input                               lfsr_en,
   input                               lfsr_option_sel,
   input [`N_L-1:0]                    LFSR_REG_INIT,
   output [`N_R*`LFSR_WIDTH-1:0]       LFSR
             );

parameter N_RR = `N_L_REG*`N_L;
//parameter N_RR = (`N_R%`N_L) ? (`N_R+(`N_R%`N_L)) : `N_R;      //Effective Number of Rows, although last ones are unused
  
wire [N_RR*`LFSR_WIDTH-1:0] LFSR_EXTENDED_OPTION0;
wire [N_RR*`LFSR_WIDTH-1:0] LFSR_EXTENDED_OPTION1;
reg [`N_R*`LFSR_WIDTH-1:0]   LFSR_RAW;

//Mux which selects among LFSR-ROW mapping options
always @(*) begin
   case(lfsr_option_sel)
      0:        LFSR_RAW <= LFSR_EXTENDED_OPTION0[`N_R*`LFSR_WIDTH-1:0];
      1:        LFSR_RAW <= LFSR_EXTENDED_OPTION1[`N_R*`LFSR_WIDTH-1:0];
      default:  LFSR_RAW <= LFSR_EXTENDED_OPTION0[`N_R*`LFSR_WIDTH-1:0];
   endcase
end
   
`ifdef OHE_EN_INPUT_LFSR
      genvar j;
      generate
         for(j=0;j<`N_R;j=j+1) begin
            OHE_LOGIC i_OHE_LOGIC(
                  .LFSR_RAW(LFSR_RAW[j*`LFSR_WIDTH +: `LFSR_WIDTH]),
                  .LFSR_OHE(LFSR[j*`LFSR_WIDTH +: `LFSR_WIDTH])

            );
         end
      endgenerate
`endif

`ifndef OHE_EN_INPUT_LFSR
      assign LFSR = LFSR_RAW;
`endif


 genvar i;

 generate
    for(i=0;i<`N_L_REG;i=i+1)
    begin: gen_LFSR
        LFSR_32 i_LFSR_32(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .lfsr_load(lfsr_load),
               .lfsr_sel(lfsr_sel[i]),
               .lfsr_en(lfsr_en),
               .LFSR_REG_INIT(LFSR_REG_INIT),
               .LFSR_SEQ_OPTION0(LFSR_EXTENDED_OPTION0[(`LFSR_WIDTH*`N_L*i) +: (`LFSR_WIDTH*`N_L)]),
               .LFSR_SEQ_OPTION1(LFSR_EXTENDED_OPTION1[(`LFSR_WIDTH*`N_L*i) +: (`LFSR_WIDTH*`N_L)])
            );
    
    end
 endgenerate

 endmodule


