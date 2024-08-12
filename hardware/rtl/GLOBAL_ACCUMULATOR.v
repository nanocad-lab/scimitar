////////////////***********************/////////////////
//       07/25/2022

`timescale 1ns/10ps
`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"


module GLOBAL_ACCUMULATOR(
   //Global Chip Signals
   input                             CLK,
   input                             RESET_N,
   
   input                             dense_en,
   input                             et_en_gate,
   input                             simpl_ctrl_glacc,

   //********ERI-DA Counters Datapath Inputs********//
   //*****From FSM*********//
   input [`GCSP-1:0]                 ET_THRESHOLD,
   input [5:0]                       ROW_INDEX,

   input [`N_B*`N_S*`N_C*`BCP-1:0]   BNK_CTR_LATCHED, 

   //********ERI-DA Counters Control Inputs from FSM********//

   //FSM Global Control signals
   input                              ET_L1_Clr,
   input                              MxPl_Sparse_Clr,
   input                              MxPl_Dense_Clr,
   input                              BnkCtr_Clr,

   input                              BnkCtr_Latch,
   input                              GlbCtr_Latch,
   
   input                              ET_Thr_Latch,
   input                              ET_L1_En,
   input                              ET_L3_En,
   
   input                              RowIndex_Update,
   input                              MxPl_Sparse_Latch,
   input                              MxPl_Dense_Latch,

   
         //Control Signals for clearing/flushing different registers in the counter pipeline.
         // Assert these only in the clearing cycle and not during the 64 compute cycles.
   
   output  [`N_S*`N_C-1:0]                  ET_L1_TRIGG,
   output                                   ET_L3_TRIGG,
   output                                   compute_done,

   //Moved Output memory de-mux to within global accum
   input [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0] write_count,
   output [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] omem_data

            );

   wire  [`N_S*`N_C*16-1:0]               MxPl_Sparse_Out;
   wire [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] sparse_assignment;
   
   `ifndef DELETE_DENSE
   wire [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0] dense_assignment;
   wire  [`N_B*`N_S*`N_C*16-1:0]          MxPl_Dense_Out;
   `endif

   
out_mem_sparse_mux i_omem_mux_sparse(
            .mxpl_sparse_out_b(MxPl_Sparse_Out),
            .write_count(write_count),
            .sparse_assignment_b(sparse_assignment)
            );


`ifndef DELETE_DENSE
//assign dense_assignment = MxPl_Dense_Out[(`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)*(write_count+1) -: (`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)];
genvar ob;

generate
   for(ob= 0 ; ob < `N_B; ob = ob+1) 
   begin: omem_dense_mux
      out_mem_dense_mux i_omem_mux(
                     .mxpl_dense_out_b(MxPl_Dense_Out[(`N_S*`N_C*16)*ob +: (`N_S*`N_C*16)]),
                     .write_count(write_count),
                     .dense_assignment_b(dense_assignment[`OUT_MEM_DATA_WDT*ob +: `OUT_MEM_DATA_WDT])
                     );
   end
endgenerate
`endif


`ifndef DELETE_DENSE
assign omem_data = (dense_en) ? dense_assignment : sparse_assignment;
`else
assign omem_data = sparse_assignment;
`endif
            wire              MxPl_Dense_Latch_PIPE3;
            wire              MxPl_Dense_Clr_PIPE3;
            wire [5:0]        RI_3;
                     `ifndef EWAT_PIPE
                        wire              GlbCtr_Latch_PIPE3;
                        wire              MxPl_Sparse_Latch_PIPE4;
                        wire              MxPl_Sparse_Clr_PIPE4;
                        wire [5:0]        RI_4;
                        wire              ET_L1_En_PIPE4;
                        wire              ET_L1_Clr_PIPE0;
                        wire [`GCSP-1:0]  ET_THR_PIPE4;
                        wire              ET_L3_En_PIPE5;
                     `else
                        wire	            GlbCtr_Latch_PIPE3;
                        wire	            GlbCtr_Latch_PIPE4;
                        wire	            MxPl_Sparse_Latch_PIPE5;
                        wire	            MxPl_Sparse_Clr_PIPE5;
                        wire	[5:0]       RI_5;
                        wire	            ET_L1_En_PIPE5;
                        wire              ET_L1_Clr_PIPE0;
                        wire	[`GCSP-1:0] ET_THR_PIPE5;
                        wire	            ET_L3_En_PIPE6;
                     `endif


            CONTROL_PIPE_GLOB_ACC i_control_pipe(
               .CLK(CLK),
               .RESET_N(RESET_N),
               .dense_en(dense_en),
               .et_en_gate(et_en_gate),
               .simpl_ctrl_glacc(simpl_ctrl_glacc),
               .ROW_INDEX(ROW_INDEX),
               .ET_THRESHOLD(ET_THRESHOLD),
               .ET_L1_Clr(ET_L1_Clr),
               .MxPl_Sparse_Clr(MxPl_Sparse_Clr),
               .MxPl_Dense_Clr(MxPl_Dense_Clr),
               .BnkCtr_Clr(BnkCtr_Clr),
               .BnkCtr_Latch(BnkCtr_Latch),
               .GlbCtr_Latch(GlbCtr_Latch),
               .ET_Thr_Latch(ET_Thr_Latch),
               .ET_L1_En(ET_L1_En),
               .ET_L3_En(ET_L3_En),
               .RowIndex_Update(RowIndex_Update),
               .MxPl_Sparse_Latch(MxPl_Sparse_Latch),
               .MxPl_Dense_Latch(MxPl_Dense_Latch),
               .MxPl_Dense_Latch_PIPE3(MxPl_Dense_Latch_PIPE3),
               .MxPl_Dense_Clr_PIPE3(MxPl_Dense_Clr_PIPE3),
               .RI_3(RI_3),
                     `ifndef EWAT_PIPE
                     .GlbCtr_Latch_PIPE3(GlbCtr_Latch_PIPE3),
                     .MxPl_Sparse_Latch_PIPE4(MxPl_Sparse_Latch_PIPE4),
                     .MxPl_Sparse_Clr_PIPE4(MxPl_Sparse_Clr_PIPE4),
                     .RI_4(RI_4),
                     .ET_L1_En_PIPE4(ET_L1_En_PIPE4),
                     .ET_L1_Clr_PIPE0(ET_L1_Clr_PIPE0),
                     .ET_THR_PIPE4(ET_THR_PIPE4),
                     .ET_L3_En_PIPE5(ET_L3_En_PIPE5),
                     `else
                     .GlbCtr_Latch_PIPE3(GlbCtr_Latch_PIPE3),
                     .GlbCtr_Latch_PIPE4(GlbCtr_Latch_PIPE4),
                     .MxPl_Sparse_Latch_PIPE5(MxPl_Sparse_Latch_PIPE5),
                     .MxPl_Sparse_Clr_PIPE5(MxPl_Sparse_Clr_PIPE5),
                     .RI_5(RI_5),
                     .ET_L1_En_PIPE5(ET_L1_En_PIPE5),
                     .ET_L1_Clr_PIPE0(ET_L1_Clr_PIPE0),
                     .ET_THR_PIPE5(ET_THR_PIPE5),
                     .ET_L3_En_PIPE6(ET_L3_En_PIPE6),
                     `endif
               .compute_done(compute_done)
                  );


wire [`N_S*`N_C*`GCSP-1:0]              SPARSE_ACC;
reg [`BCP*`N_S*`N_C*`N_B-1:0]           BANK_CTR_REARRANGED;


//Instantiate 8X32X32 Bank-Counter Modules.

//Contains registers in PIPE-STAGE:0, PIPE-STAGE:1, PIPE-STAGE:2
`ifndef DELETE_DENSE
genvar b,s,c;
generate 
   for(b=0; b<`N_B;b=b+1)
      begin : generate_ctrs_across_banks
         for(s=0; s<`N_S;s=s+1)
            begin : generate_ctrs_across_slices
               for(c=0; c<`N_C;c=c+1)
                  begin: generate_ctrs_across_columns

                        //Contains registers in PIPE-STAGE:3
                        MXPL_DENSE i_MXPL_DENSE(
                               .CLK(CLK),
                               .RESET_N(RESET_N),
                               .MxPl_Dense_Latch(MxPl_Dense_Latch_PIPE3),
                               .MxPl_Dense_Clr(MxPl_Dense_Clr_PIPE3),
                               .BANK_CTR_ij(BNK_CTR_LATCHED[`BCP*(b*`N_S*`N_C+s*`N_C+c) +: `BCP]),
                               .ROW_INDEX(RI_3),
                               .MxPl_Dense_Out(MxPl_Dense_Out[16*(b*`N_S*`N_C+s*`N_C+c) +: 16])
                            );

                  end
            end
      end
endgenerate
`endif


integer bb,ss,cc;
always @(*) begin
   
   for(bb=0;bb<`N_B;bb=bb+1) begin
      for(ss=0;ss<`N_S;ss=ss+1) begin
         for(cc=0;cc<`N_C;cc=cc+1) begin
            BANK_CTR_REARRANGED[`BCP*(ss*`N_C*`N_B + cc*`N_B + bb ) +: `BCP] <= BNK_CTR_LATCHED[`BCP*(bb*`N_S*`N_C+ss*`N_C+cc) +: `BCP];
         end
      end
   end


end


genvar s_0,c_0;

generate
      for(s_0=0;s_0<`N_S;s_0=s_0+1)
         begin: generate_gl_acc_sp_slices
            for(c_0=0;c_0<`N_C;c_0=c_0+1)
               begin: generate_gl_ac_0_sp_columns

                  //Contains registers in PIPE-STAGE:3
                  addr_tree #(.N_IN(`N_B),
                              .PREC(`BCP)
                             ) i_addr_tree(
                                 .CLK(CLK),
                                 .RESET_N(RESET_N),
                                 `ifdef EWAT_PIPE
                                 .addr_en_m1(GlbCtr_Latch_PIPE3),
                                 .addr_en(GlbCtr_Latch_PIPE4),
                                 `else
                                 .addr_en(GlbCtr_Latch_PIPE3),
                                 `endif
                                 .in(BANK_CTR_REARRANGED[`BCP*`N_B*(s_0*`N_C+c_0) +: `BCP*`N_B]),
                                 .out(SPARSE_ACC[`GCSP*(s_0*`N_C+c_0) +: `GCSP])
                              );
//
//                  //Contains registers in PIPE-STAGE:3
//                  EIGHT_WAY_ADDER_TREE i_EWAT(
//                              .CLK(CLK),
//                              .RESET_N(RESET_N),
//                                    `ifndef EWAT_PIPE
//                                    .GlbCtr_Latch(GlbCtr_Latch_PIPE3),     
//                                    `else
//                                    .GlbCtr_Latch_pipe_M1(GlbCtr_Latch_PIPE3),
//                                    .GlbCtr_Latch(GlbCtr_Latch_PIPE4),
//                                    `endif
//                              .BANK_CTR_IN_LATCHED(BANK_CTR_REARRANGED[`BCP*`N_B*(s_0*`N_C+c_0) +: `BCP*`N_B]),
//                              .SPARSE_ACC_ij(SPARSE_ACC[`GCSP*(s_0*`N_C+c_0) +: `GCSP])
//                           );
                  //Contains registers in PIPE-STAGE:4
                  MXPL_SPARSE i_MXPL_SPARSE(
                               .CLK(CLK),
                               .RESET_N(RESET_N),
                                     `ifndef EWAT_PIPE
                                     .MxPl_Sparse_Latch(MxPl_Sparse_Latch_PIPE4),
                                     .MxPl_Sparse_Clr(MxPl_Sparse_Clr_PIPE4),
                                     .ROW_INDEX(RI_4),

                                     `else
                                     .MxPl_Sparse_Latch(MxPl_Sparse_Latch_PIPE5),
                                     .MxPl_Sparse_Clr(MxPl_Sparse_Clr_PIPE5),
                                     .ROW_INDEX(RI_5),
                                     `endif
                               .SPARSE_ACC_ij(SPARSE_ACC[`GCSP*(s_0*`N_C+c_0) +: `GCSP]),
                               .MxPl_Sparse_Out(MxPl_Sparse_Out[16*(s_0*`N_C+c_0) +: 16])
                            );
                  //Contains registers in PIPE-STAGE:4/0 
                  EARLY_TERM_COMPARATORS i_ETC(
                               .CLK(CLK),
                               .RESET_N(RESET_N),
                               .SPARSE_ACC_ij(SPARSE_ACC[`GCSP*(s_0*`N_C+c_0) +: `GCSP]),
                                     `ifndef EWAT_PIPE
                                     .ET_THR(ET_THR_PIPE4),
                                     .ET_L1_En(ET_L1_En_PIPE4),
                                     `else
                                     .ET_THR(ET_THR_PIPE5),
                                     .ET_L1_En(ET_L1_En_PIPE5),
                                     `endif
                               .ET_L1_Clr(ET_L1_Clr_PIPE0),
                               .ET_L1_TRIGG_ij(ET_L1_TRIGG[(s_0*`N_C+c_0)])
                            );

               end
         end

      endgenerate
                  
      EARLY_TERM3_GEN    i_ET3(
                               .CLK(CLK),
                               .RESET_N(RESET_N),
                               .ET_L1_TRIGG(ET_L1_TRIGG),
                                     `ifndef EWAT_PIPE
                                     .ET_L3_En(ET_L3_En_PIPE5),
                                     `else
                                     .ET_L3_En(ET_L3_En_PIPE6),
                                     `endif
                               .ET_L3_TRIGG(ET_L3_TRIGG)
                            );



endmodule


//Module Definition for Early Termination Logic

module EARLY_TERM3_GEN(
   input                               CLK,
   input                               RESET_N,
   input [`N_S*`N_C-1:0]               ET_L1_TRIGG,
   input                               ET_L3_En,
   output reg                          ET_L3_TRIGG
);


always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N)  ET_L3_TRIGG  <= 1'b0;

   else begin

      if(ET_L3_TRIGG) begin //Clear-on-write
         ET_L3_TRIGG <= 1'b0;
      end

      else if(ET_L3_En) begin
         if(ET_L1_TRIGG=={(`N_S*`N_C){1'b1}})  ET_L3_TRIGG <= 1'b1;
         else                 ET_L3_TRIGG <= 1'b0;   
      end

      else ET_L3_TRIGG <= ET_L3_TRIGG;
      
   end
end
endmodule
//Module Definition for Early Termination Logic

module EARLY_TERM_COMPARATORS(
   input                               CLK,
   input                               RESET_N,
   input signed [`GCSP-1:0]            SPARSE_ACC_ij,
   input signed [`GCSP-1:0]            ET_THR,
   input                               ET_L1_En,
   input                               ET_L1_Clr,
   output reg                          ET_L1_TRIGG_ij
);


always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N)  ET_L1_TRIGG_ij <=0;

   else begin
      if(ET_L1_Clr) begin
            ET_L1_TRIGG_ij <=0;
      end

      else if(ET_L1_En) begin
         if(SPARSE_ACC_ij < ET_THR) ET_L1_TRIGG_ij <=1; 
         else                       ET_L1_TRIGG_ij <=0;   
      end

      else ET_L1_TRIGG_ij <= ET_L1_TRIGG_ij;

   end

end
endmodule

//Module Definition for Sparse Mode accumulator
//module EIGHT_WAY_ADDER_TREE(
//   input                                CLK,
//   input                                RESET_N,
//`ifdef EWAT_PIPE
//   input                                GlbCtr_Latch_pipe_M1,
//`endif
//   input                                GlbCtr_Latch,
//   input [`N_B*`BCP-1:0]                BANK_CTR_IN_LATCHED,  
//   output reg [`GCSP-1:0]               SPARSE_ACC_ij
//);
//
//
//
//reg [`GCSP-1:0] SPARSE_ACC_ij_CALCULATED;
//always @(posedge CLK or negedge RESET_N) begin
//
//   if(~RESET_N)  SPARSE_ACC_ij <=0;
//   else          SPARSE_ACC_ij <= SPARSE_ACC_ij_CALCULATED;
//
//end
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
//`ifdef EWAT_PIPE
//reg signed [`BCP+2-1:0]  l2_0_l;
//reg signed [`BCP+2-1:0]  l2_1_l;
//`endif
//reg signed [`BCP+3-1:0]  l3_0;
//
//
//always @(*) begin
//
//   l0_0 <= BANK_CTR_IN_LATCHED[0*`BCP +: `BCP];
//   l0_1 <= BANK_CTR_IN_LATCHED[1*`BCP +: `BCP];
//   l0_2 <= BANK_CTR_IN_LATCHED[2*`BCP +: `BCP];
//   l0_3 <= BANK_CTR_IN_LATCHED[3*`BCP +: `BCP];
//   l0_4 <= BANK_CTR_IN_LATCHED[4*`BCP +: `BCP];
//   l0_5 <= BANK_CTR_IN_LATCHED[5*`BCP +: `BCP];
//   l0_6 <= BANK_CTR_IN_LATCHED[6*`BCP +: `BCP];
//   l0_7 <= BANK_CTR_IN_LATCHED[7*`BCP +: `BCP];
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
//`ifdef EWAT_PIPE
//always @(posedge CLK or negedge RESET_N) begin
//   if(~RESET_N)  begin
//      l2_0_l <= 0;
//      l2_1_l <= 0;
//   end
//   else begin
//      if(GlbCtr_Latch_pipe_M1) begin
//         l2_0_l <= l2_0;
//         l2_1_l <= l2_1;
//      end
//
//      else begin
//         l2_0_l <= l2_0_l;
//         l2_1_l <= l2_1_l;
//      end
//   end
//end
//`endif
//
//always @(*) begin
//`ifndef EWAT_PIPE
//   l3_0 <= l2_0 + l2_1;
//`else
//   l3_0 <= l2_0_l + l2_1_l;
//`endif
//end
//
//always @(*) begin
//      
//   if(GlbCtr_Latch) SPARSE_ACC_ij_CALCULATED <= l3_0;
//   else             SPARSE_ACC_ij_CALCULATED <= SPARSE_ACC_ij; 
//
//end
//endmodule


//Module Definition for Max Pool circuit for sparse mode
module MXPL_SPARSE(
   input                                       CLK,
   input                                       RESET_N,
   input                                       MxPl_Sparse_Latch,
   input                                       MxPl_Sparse_Clr,
   input signed [`GCSP-1:0]                    SPARSE_ACC_ij,
   input [5:0]                                 ROW_INDEX,
   output reg [15:0]                           MxPl_Sparse_Out

);


reg [5:0]                            ROW_INDEX_LATCHED;
reg signed [`GCSP-1:0]               GLB_CTR_SPARSE_ij;

//assign MxPl_Sparse_Out = {ROW_INDEX_LATCHED,{(16-`GCSP-6){1'b0}},GLB_CTR_SPARSE_ij};

always @(*) begin
   MxPl_Sparse_Out = {16{1'b0}};
   MxPl_Sparse_Out[15 -: 6] = ROW_INDEX_LATCHED;
   MxPl_Sparse_Out[`GCSP-1:0] = GLB_CTR_SPARSE_ij;
end
always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin 
      GLB_CTR_SPARSE_ij <=-1*2**(`GCSP-1);
      ROW_INDEX_LATCHED <= 0;
   end
   else begin
         if(MxPl_Sparse_Clr) begin  //FSM is trying to clear
                 GLB_CTR_SPARSE_ij <=-1*2**(`GCSP-1);
                 ROW_INDEX_LATCHED <= 0;
              end
         
         
         else begin 
               if(MxPl_Sparse_Latch) begin //Compare Now
                        if(SPARSE_ACC_ij > GLB_CTR_SPARSE_ij) begin 
                           GLB_CTR_SPARSE_ij <= SPARSE_ACC_ij;
                           ROW_INDEX_LATCHED <= ROW_INDEX;
                        end
                        else begin
                           GLB_CTR_SPARSE_ij <= GLB_CTR_SPARSE_ij;
                           ROW_INDEX_LATCHED <= ROW_INDEX_LATCHED;
                        end
               end

               else begin 
                  GLB_CTR_SPARSE_ij <= GLB_CTR_SPARSE_ij;
                  ROW_INDEX_LATCHED <= ROW_INDEX_LATCHED;
               end
         end
   end

end

endmodule



//Module Definition for Max Pool circuit for dense mode
module MXPL_DENSE(
   input                                       CLK,
   input                                       RESET_N,
   input                                       MxPl_Dense_Latch,
   input                                       MxPl_Dense_Clr,
   input signed [`BCP-1:0]                     BANK_CTR_ij,
   input [5:0]                                 ROW_INDEX,
   output [15:0]                               MxPl_Dense_Out

);


reg [5:0]                            ROW_INDEX_LATCHED;
reg signed [`GCDP-1:0]               GLB_CTR_DENSE_ij;

assign MxPl_Dense_Out = {ROW_INDEX_LATCHED,{(16-`GCDP-6){1'b0}},GLB_CTR_DENSE_ij};

always @(posedge CLK or negedge RESET_N) begin

   if(~RESET_N) begin 
      GLB_CTR_DENSE_ij <=-1*2**(`GCDP-1);
      ROW_INDEX_LATCHED <= 0;
   end

   else begin
         if(MxPl_Dense_Clr) begin  //FSM is trying to clear
                 GLB_CTR_DENSE_ij <=-1*2**(`GCDP-1);
                 ROW_INDEX_LATCHED <= 0;
              end
         
         
         else begin 
             if(MxPl_Dense_Latch) begin //Compare Now
                  if(BANK_CTR_ij > GLB_CTR_DENSE_ij) begin 
                     GLB_CTR_DENSE_ij <= BANK_CTR_ij;
                     ROW_INDEX_LATCHED <= ROW_INDEX;
                  end
                  else begin
                     GLB_CTR_DENSE_ij <= GLB_CTR_DENSE_ij;
                     ROW_INDEX_LATCHED <= ROW_INDEX_LATCHED;
                  end
             end

             else begin 
                  GLB_CTR_DENSE_ij <= GLB_CTR_DENSE_ij;
                  ROW_INDEX_LATCHED <= ROW_INDEX_LATCHED;
             end
         end
   end

end

endmodule

