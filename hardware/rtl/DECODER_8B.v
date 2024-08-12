`timescale 1ns/1ps

// 7 bit decoder
module DECODER_8B( ADD8, WL, EN );
input      [7:0]   ADD8;
input 			   EN;
output reg [161:0] WL;

reg [255:0] DOUT256;
wire [15:0] s1_out;

integer i;

DECODER_4B decode4(.Din4(ADD8[3:0]), .Dout16(s1_out));

always @(*) begin
	WL <= DOUT256[161:0] & {(162){EN}};
	for (i=0; i<16; i=i+1) begin
		if( ADD8[7:4] == i) begin
			DOUT256[i*16 +: 16] <= s1_out;
		end else begin
			DOUT256[i*16 +: 16] <= 0;
		end
	end
end
endmodule


// 4 bit Decoder
module DECODER_4B(Din4, Dout16);

input  [3:0] Din4;// address might come asynchronously 
output [15:0] Dout16;

wire [7:0] s1_out;

assign Dout16[7:0]  = {(8){(!Din4[3])}} & s1_out;
assign Dout16[15:8] = {(8){( Din4[3])}} & s1_out;

DECODER_3B decode3(.Din3(Din4[2:0]), .Dout8(s1_out));

endmodule

//3 bit Decoder
module DECODER_3B(Din3, Dout8);

input [2:0] Din3;// address might come asynchronously 
output [7:0] Dout8;

assign Dout8[0] =  (~Din3[0])&(~Din3[1])&(~Din3[2]) ;
assign Dout8[1] =  (Din3[0])&(~Din3[1])&(~Din3[2]) ;
assign Dout8[2] =  (~Din3[0])&(Din3[1])&(~Din3[2]) ;
assign Dout8[3] =  (Din3[0])&(Din3[1])&(~Din3[2]) ;
assign Dout8[4] =  (~Din3[0])&(~Din3[1])&(Din3[2]) ;
assign Dout8[5] =  (Din3[0])&(~Din3[1])&(Din3[2]) ;
assign Dout8[6] =  (~Din3[0])&(Din3[1])&(Din3[2]) ;
assign Dout8[7] =  (Din3[0])&(Din3[1])&(Din3[2]) ;

endmodule
