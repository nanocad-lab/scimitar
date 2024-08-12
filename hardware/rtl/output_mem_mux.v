`include "ERI-DA_HEADERS.vh"
`include "scotsman_conf.vh"

module out_mem_dense_mux(
   input [`N_S*`N_C*16-1:0]                                                   mxpl_dense_out_b,
   input [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0]   write_count,
   output reg [`OUT_MEM_DATA_WDT-1:0]                                         dense_assignment_b
               );

wire [$clog2((`N_S*`N_C*16)/`OUT_MEM_DATA_WDT)-1:0] write_count_valid;              
assign write_count_valid = write_count[$clog2((`N_S*`N_C*16)/`OUT_MEM_DATA_WDT)-1:0];
               
//               assign dense_assignment_b = mxpl_dense_out_b[(`OUT_MEM_DATA_WDT)*(write_count+1) -: (`OUT_MEM_DATA_WDT)];
          integer i;
          always @(*) begin
             dense_assignment_b = mxpl_dense_out_b[0 +: (`OUT_MEM_DATA_WDT)];
             //dense_assignment_b = {`OUT_MEM_DATA_WDT{1'b0}};
             for (i=0;i<(`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT);i=i+1) begin
               if(write_count_valid==i) begin
                  dense_assignment_b = mxpl_dense_out_b[(`OUT_MEM_DATA_WDT)*i +: (`OUT_MEM_DATA_WDT)];
               end
             end
          end

endmodule

module out_mem_sparse_mux(
   input [`N_S*`N_C*16-1:0]                                                   mxpl_sparse_out_b,
   input [$clog2((`N_B*`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS)):0]   write_count,
   output reg [`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT-1:0]                          sparse_assignment_b
               );

wire [$clog2((`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS))-1:0] write_count_valid;              
assign write_count_valid = write_count[$clog2((`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS))-1:0];

//assign sparse_assignment = MxPl_Sparse_Out[(`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)*(write_count+1) -: (`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)];
         integer i;
          always @(*) begin
//             sparse_assignment_b = {(`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT){1'b0}};
             sparse_assignment_b = mxpl_sparse_out_b[0 +: (`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)];//{(`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT){1'b0}};
             for (i=0;i<(`N_S*`N_C*16)/(`OUT_MEM_DATA_WDT*`OUT_MEM_BANKS);i=i+1) begin
               if(write_count_valid==i) begin
                  sparse_assignment_b = mxpl_sparse_out_b[(`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)*i +: (`OUT_MEM_BANKS*`OUT_MEM_DATA_WDT)];
               end
             end
          end
endmodule

