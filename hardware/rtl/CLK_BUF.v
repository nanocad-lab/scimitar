`timescale 1ns/1ps
`include "ERI-DA_HEADERS.vh"


module CLK_BUF(CLKINP, CLKINN, CLKD, CLK_DIV,
			    `ifdef MACRO_ANA
					VDD_CLK, VSS,
				`endif
				VBIAS
				);

input CLKINP;
input CLKINN;
output CLKD;
output CLK_DIV;
input VBIAS;

`ifdef MACRO_ANA
	inout VDD_CLK;
	inout VSS;
`endif				
				
				
`ifdef MACRO_ANA


`else
	assign CLKD = CLKINP;
	reg [4:0] counter;
	reg CLK_DIV;
	
	initial begin
		counter = 5'd0;
		CLK_DIV = 1'b0;
	end

	always @(posedge CLKINP) begin
		if(counter == 5'd8) begin
			counter <= 5'd1;
			CLK_DIV <= ! CLK_DIV;
		end else begin
			counter <= counter + 1'b1;
		end
	
	end

`endif	



endmodule
