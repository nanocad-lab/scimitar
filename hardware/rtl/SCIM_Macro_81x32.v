`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"


module SCIM_Macro_81x32(
         CLK, COMP_EN, DIN, DOUTN, DOUTP, I, RESET, RN,
         `ifdef MACRO_ANA
         VDDA, VSS,
         `endif
         VTHRES, WL, WRITE_EN
         );

//module SCIM_Macro_81x32_behav(I, RN, WL, DIN, WRITE_EN, COMP_EN, CLK, RESET, DOUTP, DOUTN, VTHRES);
input   [`N_R*`N_C-1:0]   I;   // input values
input   [`N_R*`FXP-1:0]    RN;  // random number
input   [`N_R*2-1:0]    WL;  // word lines
input   [`N_S*3-1:0]     DIN; // write inputs
input   [3:0]      VTHRES; // threshold voltage control bits for sense amp

input              CLK; 			
input              WRITE_EN;
input              COMP_EN;
input		       RESET;

`ifdef MACRO_ANA
inout VDDA;
inout VSS;
`endif

output reg [`N_S*`N_C-1:0] DOUTP;
output reg [`N_S*`N_C-1:0] DOUTN;

`ifdef MACRO_ANA

`else
	integer i;
	integer j;
	integer p;
	reg [`N_S*3-1:0]  mem [0:`N_R*2-1];  // 162 x 96 memory
	reg [`N_R-1:0]  in_sng_p [`N_S-1:0]; //positive in-situ sng result (transposed)
	reg [`N_R-1:0]  in_sng_n [`N_S-1:0]; //negative in-situ sng result (transposed)
   reg [`N_S*`FXP-1:0] mem_flat [`N_R-1:0]; //flattened 81 x 192 memory
	reg [`N_R-1:0]  in_flat  [`N_C-1:0];  //flattened input (transposed) 32x81
	reg 		COMPEN_REG;
	reg 		WRITEEN_REG;

   initial begin
			for(i=0; i<2*`N_R; i=i+1) begin //162
            mem[i] = {(`N_S*3){1'b0}};
			end
   end
	// Sequential Logic: Write and Compute Operation
	always@(posedge CLK or posedge RESET) begin
		if(RESET) begin
			DOUTP <= 0;
			DOUTN <= 0;
		end else begin
			COMPEN_REG  <= COMP_EN;
			WRITEEN_REG <= WRITE_EN;
		end
	end 
	
	always@(negedge CLK) begin
		if(WRITEEN_REG) begin
			for(i=0; i<2*`N_R; i=i+1) begin //162
				if(WL[i]) begin
					mem[i] <= DIN;
				end
			end
		end
	
		if(COMPEN_REG) begin
			for (j=0; j<`N_S;j=j+1) begin // 32 slices
				for (p=0; p<`N_C; p=p+1) begin // 32 compute lines
					DOUTP[j*`N_C + p] <= |(in_flat[p] & in_sng_p[j]);
					DOUTN[j*`N_C + p] <= |(in_flat[p] & in_sng_n[j]);
				end
			end		
		end
	end
	

	integer k;
	integer m;
	integer l;
	integer h;
	//Combinational Logic: flatten the memory and in-situ SNG
	always @(*) begin
		for(l=0; l<`N_R; l=l+1) begin // row-81
			for(h=0; h<`N_S; h=h+1) begin //slices-32
             mem_flat[l][h*6 +: 3]     <= mem[l*2][h*3 +: 3];   // memflat[0][2:0] <= mem[0][2:0]
			    mem_flat[l][(h*6+3) +: 3] <= mem[l*2+1][h*3 +: 3]; // memflat[0][5:3] <= mem[1][2:0]
			   
             in_sng_p[h][l]               <= (|(mem_flat[l][h*`FXP +: (`FXP)] & RN[l*`FXP +: (`FXP)])) && (!mem_flat[l][h*`FXP+`FXP-1]);
             in_sng_n[h][l]               <= (|(mem_flat[l][h*`FXP +: (`FXP)] & RN[l*`FXP +: (`FXP)])) && ( mem_flat[l][h*`FXP+`FXP-1]);
			    // (|(memflat[0][5:0] & RN[5:0])) & (mem_flat[0][5])
			    in_flat[h][l]                <= I[l*`N_C+h];
			end
		end
		
	end

	always @(*) begin
		for(l=0; l<`N_R; l=l+1) begin // row-81
			for(h=0; h<`N_C; h=h+1) begin //input-lines-32
			    in_flat[h][l]                <= I[l*`N_C+h];
			end
		end
		
	end


`endif

endmodule
