
`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"



module addr_tree #(
   parameter N_IN = 8,
   parameter PREC = 7
                  )(
   input                                CLK,
   input                                RESET_N,
   `ifdef EWAT_PIPE
   input                                addr_en_m1,
   `endif
   input                                addr_en,
   input [N_IN*PREC-1:0]                in,  
   output reg[(PREC+$clog2(N_IN))-1:0]  out
);



localparam LVLS = $clog2(N_IN);

localparam PREC_OUT = PREC + LVLS;

//address-like a binary tree. left-child = 2*parent+1, right-child = 2*parent+2
reg signed [PREC_OUT-1:0] ps[2*N_IN-2:0];

integer l,n;

always @(*) begin
   //Initialize the leaves as the inputs. N_B-1 to 2*N_B-1 (7 to 14)
   for(l=0;l<N_IN;l=l+1) begin
      ps[l+N_IN-1] = $signed(in[PREC*l +: PREC]);
   end

//Initialize the partial sums as zeros. There would be N_IN-1 partial sums. 
//   for(l=0;l<N_IN-1;l=l+1) begin
//      ps[l] = {PREC_OUT{1'b0}};
//   end
   //0 to N_B-2 (0 to 6)

   `ifndef EWAT_PIPE
   for(n=(N_IN-2);n>=0;n=n-1) begin
      ps[n]=ps[2*n+1]+ps[2*n+2]; 
   end
   `else
   for(n=(N_IN-2);n>=1;n=n-1) begin
      ps[n]=ps[2*n+1]+ps[2*n+2]; 
   end
   `endif

end

`ifdef EWAT_PIPE
   reg signed [(PREC_OUT-1)-1:0] psl1;
   reg signed [(PREC_OUT-1)-1:0] psl2;

//pre-Final-Output is ps[1] and ps[2]
always @(posedge CLK or negedge RESET_N) begin
   if(!RESET_N) begin
      psl1 <={(PREC_OUT-1){1'b0}};
      psl2 <={(PREC_OUT-1){1'b0}};
   end

   else begin
      if(addr_en_m1) begin
         psl1 <= ps[1][(PREC_OUT-1)-1:0];
         psl2 <= ps[2][(PREC_OUT-1)-1:0];
      end

      else begin
         psl1 <= psl1;
         psl2 <= psl2;
      end
   end
end

always @(*) begin
   ps[0] <= psl1 + psl2;
end
`endif


//Final-Output is tree-root
always @(posedge CLK or negedge RESET_N) begin
   if(!RESET_N) begin
      out <=0;
   end

   else begin
      if(addr_en) begin
          out <= ps[0];
      end

      else begin
         out <= out;
      end
   end
end


endmodule
//
//module addr_triv(
//   input                                CLK,
//   input                                RESET_N,
//   input                                addr_en,
//   input [`N_B*`BCP-1:0]                in,  
//   output reg [`GCSP-1:0]               out
//);
//
//integer i;
//reg signed [`BCP-1:0] ins [`N_B-1:0];
//reg signed [`GCSP-1:0] sum;
//
//always @(*) begin
//   for(i=0;i<`N_B;i=i+1) begin
//      ins[i]=in[i*`BCP +: `BCP];
//   end
//end
//
//always @(*) begin
//   sum={`GCSP{1'b0}};
//   for(i=0;i<`N_B;i=i+1) begin
//      sum=sum+$signed(ins[i]);
//   end
//end
//
//always @(posedge CLK or negedge RESET_N) begin
//   if(!RESET_N) begin
//      out <=0;
//   end
//
//   else begin
//      if(addr_en) begin
//          out <= sum;
//      end
//
//      else begin
//         out <= out;
//      end
//   end
//end
//
//endmodule
//
//module addr_tree_orig(
//   input                                CLK,
//   input                                RESET_N,
//   `ifdef EWAT_PIPE
//   input                                addr_en_m1,
//   `endif
//   input                                addr_en,
//   input [`N_B*`BCP-1:0]                in,  
//   output reg [`GCSP-1:0]               out
//);
//
//
//
//
//
//reg signed [`BCP-1:0]    l0_0;
//reg signed [`BCP-1:0]    l0_1;
//reg signed [`BCP-1:0]    l0_2;
//reg signed [`BCP-1:0]    l0_3;
//reg signed [`BCP-1:0]    l0_4;
//reg signed [`BCP-1:0]    l0_5;
//reg signed [`BCP-1:0]    l0_6;
//reg signed [`BCP-1:0]    l0_7;
//
//reg signed [`BCP+1-1:0]  l1_0;
//reg signed [`BCP+1-1:0]  l1_1;
//reg signed [`BCP+1-1:0]  l1_2;
//reg signed [`BCP+1-1:0]  l1_3;
//
//reg signed [`BCP+2-1:0]  l2_0;
//reg signed [`BCP+2-1:0]  l2_1;
//
//reg signed [`BCP+3-1:0]  l3_0;
//
//
//always @(*) begin
//
//   l0_0 <= in[0*`BCP +: `BCP];
//   l0_1 <= in[1*`BCP +: `BCP];
//   l0_2 <= in[2*`BCP +: `BCP];
//   l0_3 <= in[3*`BCP +: `BCP];
//   l0_4 <= in[4*`BCP +: `BCP];
//   l0_5 <= in[5*`BCP +: `BCP];
//   l0_6 <= in[6*`BCP +: `BCP];
//   l0_7 <= in[7*`BCP +: `BCP];
//
//end
//
//
//always @(*) begin
//   l1_0 <= l0_0 + l0_1;
//   l1_1 <= l0_2 + l0_3;
//   l1_2 <= l0_4 + l0_5;
//   l1_3 <= l0_6 + l0_7;
//end
//
//always @(*) begin
//   l2_0 <= l1_0 + l1_1;
//   l2_1 <= l1_2 + l1_3;
//end
//
//`ifndef EWAT_PIPE
//always @(*) begin
//   l3_0 <= l2_0 + l2_1;
//end
//`else
//   reg signed [(`GCSP-1)-1:0] l2_0_l;
//   reg signed [(`GCSP-1)-1:0] l2_1_l;
//
////pre-Final-Output is ps[1] and ps[2]
//always @(posedge CLK or negedge RESET_N) begin
//   if(!RESET_N) begin
//      l2_0_l <={(`GCSP-1){1'b0}};
//      l2_1_l <={(`GCSP-1){1'b0}};
//   end
//
//   else begin
//      if(addr_en_m1) begin
//         l2_0_l <= l2_0[(`GCSP-1)-1:0];
//         l2_1_l <= l2_1[(`GCSP-1)-1:0];
//      end
//
//      else begin
//         l2_0_l <= l2_0_l;
//         l2_1_l <= l2_1_l;
//      end
//   end
//end
//
//always @(*) begin
//   l3_0 <= l2_0_l + l2_1_l;
//end
//`endif
//
//always @(posedge CLK or negedge RESET_N) begin
//   if(~RESET_N)  out <=0;
//   else begin
//      if(addr_en) begin
//         out <= l3_0;
//      end
//      else begin
//         out <= out;
//      end
//   end
//end
//
//endmodule

