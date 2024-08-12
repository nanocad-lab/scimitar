`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"

module INPUT_MUX (
	input [`MAC_CN_HGT*`BB_WIDTH*`FXP-1:0]	BB_OUT,
   output reg [`N_C*`N_R*`FXP-1:0]			MACRO_IN
);

integer i,j;

reg [`N_C*`N_R*`FXP-1:0] INPUT_VECTOR;			


//Step-1: Create 32x81 matrix from 9x40 matrix: sliding window mapping
//        Row-traversed first. Then 9-rows are appended to create 1x81 row.
//Step-2: Next sliding window taken (i=i+1) and step 1 repeated to create next 1x81 row
//Step-3: Repeat steps 1 & 2 till all 32 sliding windows (SW) are created.

//Result: This results in INPUT_VECTOR[(SW-31 1x81) ...........(SW-02 1x81), (SW-01 1x81), (SW-00 1x81)]

always @(*) begin

   for(i=0;i<`N_C;i=i+1) begin
      for(j=0;j<`MAC_CN_HGT;j=j+1) begin
               INPUT_VECTOR[(i*`MAC_CN_HGT*`MAC_CN_HGT+j*`MAC_CN_HGT)*`FXP +: `MAC_CN_HGT*`FXP] <= BB_OUT[(j*`BB_WIDTH+i)*`FXP +: `MAC_CN_HGT*`FXP];
		end
	end
end

//Now for convolution operation and 32-way parallelism, we need to group 0th input from all 32 sliding windows together to be multiplied by the 0th weight
//Similarly k'th input from all 32 sliding windows grouped together to be multiplied by the k'th weight
//This is repeated for all 81 inputs.
integer k;

always @(*) begin
  for(k=0;k<`N_R;k=k+1) begin
      for(i=0;i<`N_C;i=i+1) begin
         MACRO_IN[(k*`N_C+i)*`FXP +: `FXP] <= INPUT_VECTOR[ (i*`N_R+k)*`FXP +: `FXP];  
		end
	end
end

endmodule
