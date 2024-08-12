`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"

module CONTROL_PIPE_GLOB_ACC(

               input                        CLK,
               input                        RESET_N,
               input                        dense_en,
               input                        et_en_gate,
               input                        simpl_ctrl_glacc,
              
               
               input [5:0]                  ROW_INDEX,
               input [`GCSP-1:0]            ET_THRESHOLD,

               input                        ET_L1_Clr,
               input                        MxPl_Sparse_Clr,
               input                        MxPl_Dense_Clr,
               input                        BnkCtr_Clr,

               input                        BnkCtr_Latch,
               input                        GlbCtr_Latch,
               
               input                        ET_Thr_Latch,
               input                        ET_L1_En,
               input                        ET_L3_En,
               
               input                        RowIndex_Update,
               input                        MxPl_Sparse_Latch,
               input                        MxPl_Dense_Latch,

               output                    MxPl_Dense_Latch_PIPE3,
               output                    MxPl_Dense_Clr_PIPE3,
               output [5:0]              RI_3,
                     `ifndef EWAT_PIPE
                     output                    GlbCtr_Latch_PIPE3,

                     output                    MxPl_Sparse_Latch_PIPE4,
                     output                    MxPl_Sparse_Clr_PIPE4,
                     output [5:0]              RI_4,

                     output                    ET_L1_En_PIPE4,
                     output                    ET_L1_Clr_PIPE0,

                     output  [`GCSP-1:0]       ET_THR_PIPE4,

                     output                    ET_L3_En_PIPE5,

                     `else
                     output                    GlbCtr_Latch_PIPE3,
                     output                    GlbCtr_Latch_PIPE4,

                     output                    MxPl_Sparse_Latch_PIPE5,
                     output                    MxPl_Sparse_Clr_PIPE5,
                     output [5:0]              RI_5,

                     output                    ET_L1_En_PIPE5,
                     output                    ET_L1_Clr_PIPE0,

                     output  [`GCSP-1:0]       ET_THR_PIPE5,

                     output                    ET_L3_En_PIPE6,

                     `endif

               output reg                compute_done

);

wire                   ET_Thr_Latch_PIPE3;
wire                   ET_Thr_Latch_PIPE2;
wire                   ET_Thr_Latch_PIPE1;
wire                   ET_Thr_Latch_PIPE0;
reg                    ET_Thr_Latch_PIPE_M1;

wire                   RowIndex_Update_PIPE3;
wire                   RowIndex_Update_PIPE2;
wire                   RowIndex_Update_PIPE1;
wire                   RowIndex_Update_PIPE0;
reg                    RowIndex_Update_PIPE_M1;

wire                   MxPl_Dense_Latch_PIPE2;
wire                   MxPl_Dense_Latch_PIPE1;
wire                   MxPl_Dense_Latch_PIPE0;
reg                    MxPl_Dense_Latch_PIPE_M1;

wire                   MxPl_Dense_Clr_PIPE2;
wire                   MxPl_Dense_Clr_PIPE1;
wire                   MxPl_Dense_Clr_PIPE0;
reg                    MxPl_Dense_Clr_PIPE_M1;

wire                   GlbCtr_Latch_PIPE2;
wire                   GlbCtr_Latch_PIPE1;
wire                   GlbCtr_Latch_PIPE0;
reg                    GlbCtr_Latch_PIPE_M1;

wire                   MxPl_Sparse_Latch_PIPE3;
wire                   MxPl_Sparse_Latch_PIPE2;
wire                   MxPl_Sparse_Latch_PIPE1;
wire                   MxPl_Sparse_Latch_PIPE0;
reg                    MxPl_Sparse_Latch_PIPE_M1;

wire                   MxPl_Sparse_Clr_PIPE3;
wire                   MxPl_Sparse_Clr_PIPE2;
wire                   MxPl_Sparse_Clr_PIPE1;
wire                   MxPl_Sparse_Clr_PIPE0;
reg                    MxPl_Sparse_Clr_PIPE_M1;

wire [5:0]             RI_2;
wire [5:0]             RI_1;
wire [5:0]             RI_0;
wire [5:0]             RI_M1;

wire                   ET_L1_En_PIPE3;
wire                   ET_L1_En_PIPE2;
wire                   ET_L1_En_PIPE1;
wire                   ET_L1_En_PIPE0;
reg                    ET_L1_En_PIPE_M1;

reg                    ET_L1_Clr_PIPE_M1;


wire [`GCSP-1:0]       ET_THR_PIPE3;
wire [`GCSP-1:0]       ET_THR_PIPE2;
wire [`GCSP-1:0]       ET_THR_PIPE1;
wire [`GCSP-1:0]       ET_THR_PIPE0;
wire [`GCSP-1:0]       ET_THR_PIPE_M1;

wire                   ET_L3_En_PIPE4;
wire                   ET_L3_En_PIPE3;
wire                   ET_L3_En_PIPE2;
wire                   ET_L3_En_PIPE1;
wire                   ET_L3_En_PIPE0;
reg                    ET_L3_En_PIPE_M1;

wire MxPl_Dense_Latch_PIPE4;
wire MxPl_Sparse_Latch_PIPE5;

`ifdef EWAT_PIPE

wire                    MxPl_Sparse_Latch_PIPE6;
wire                    MxPl_Sparse_Clr_PIPE4;
wire [5:0]              RI_4;

wire                    ET_L1_En_PIPE4;

wire  [`GCSP-1:0]       ET_THR_PIPE4;

wire                    ET_L3_En_PIPE5;

`endif
assign    RI_M1 =                     ROW_INDEX;
assign    ET_THR_PIPE_M1 =            ET_THRESHOLD;
                            
//assign    ET_L1_Clr_PIPE_M1 =         ET_L1_Clr;
//assign    MxPl_Sparse_Clr_PIPE_M1 =   MxPl_Sparse_Clr;
//assign    MxPl_Dense_Clr_PIPE_M1 =    MxPl_Dense_Clr;
//                            
//assign    GlbCtr_Latch_PIPE_M1 =      GlbCtr_Latch;
//                                 
//assign    ET_Thr_Latch_PIPE_M1 =      ET_Thr_Latch;
//assign    ET_L1_En_PIPE_M1 =          ET_L1_En;
//assign    ET_L3_En_PIPE_M1 =          ET_L3_En;
//                                 
//assign    RowIndex_Update_PIPE_M1 =   RowIndex_Update;
//assign    MxPl_Sparse_Latch_PIPE_M1 = MxPl_Sparse_Latch;
//assign    MxPl_Dense_Latch_PIPE_M1 =  MxPl_Dense_Latch;



always @(*) begin
   if(et_en_gate) begin
      if(simpl_ctrl_glacc) begin
         ET_L1_Clr_PIPE_M1 = BnkCtr_Clr;
      end

      else begin
         ET_L1_Clr_PIPE_M1 = ET_L1_Clr;
      end
   end

   else begin
      ET_L1_Clr_PIPE_M1 = 1'b0;
   end
end

always @(*) begin
   if(dense_en) begin
      MxPl_Sparse_Clr_PIPE_M1 = 1'b0;
   end

   else begin
      MxPl_Sparse_Clr_PIPE_M1 =   MxPl_Sparse_Clr;
   end
end

always @(*) begin
   if(dense_en) begin
      MxPl_Dense_Clr_PIPE_M1 =    MxPl_Dense_Clr;
   end

   else begin
      MxPl_Dense_Clr_PIPE_M1 = 1'b0;
   end
end

always @(*) begin
   if(dense_en) begin
      GlbCtr_Latch_PIPE_M1 = 1'b0;
   end
   else begin
      if(simpl_ctrl_glacc) begin
         GlbCtr_Latch_PIPE_M1 = BnkCtr_Latch;
      end
      else begin
         GlbCtr_Latch_PIPE_M1 = GlbCtr_Latch;
      end
   end
end

always @(*) begin
   if(et_en_gate) begin
      if(simpl_ctrl_glacc) begin
         ET_Thr_Latch_PIPE_M1 = ET_L1_En;
      end

      else begin
         ET_Thr_Latch_PIPE_M1 = ET_Thr_Latch;
      end
   end

   else begin
      ET_Thr_Latch_PIPE_M1 = 1'b0;
   end

end

always @(*) begin
   if(et_en_gate) begin
      ET_L1_En_PIPE_M1 = ET_L1_En;
   end

   else begin
      ET_L1_En_PIPE_M1 = 1'b0;
   end
end

always @(*) begin
   if(et_en_gate) begin
      if(simpl_ctrl_glacc) begin
         ET_L3_En_PIPE_M1 = ET_L1_En;
      end
      else begin
         ET_L3_En_PIPE_M1 = ET_L3_En;
      end
   end

   else begin
      ET_L3_En_PIPE_M1 = 1'b0;
   end
end

always @(*) begin
   RowIndex_Update_PIPE_M1 =   RowIndex_Update;

end

always @(*) begin
   if(dense_en) begin
      MxPl_Sparse_Latch_PIPE_M1 = 1'b0;
   end
   else begin
      MxPl_Sparse_Latch_PIPE_M1 = MxPl_Sparse_Latch;
   end
end

always @(*) begin
   if(dense_en) begin
      MxPl_Dense_Latch_PIPE_M1 =  MxPl_Dense_Latch;
   end

   else begin
      MxPl_Dense_Latch_PIPE_M1 = 1'b0;
   end
end

always @(*) begin
   if(dense_en) compute_done <= MxPl_Dense_Latch_PIPE4;
   `ifndef EWAT_PIPE
   else         compute_done <= MxPl_Sparse_Latch_PIPE5;
   `else
   else         compute_done <= MxPl_Sparse_Latch_PIPE6;
   `endif
end

rb #(1) i_0(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Latch_PIPE_M1), .Q(MxPl_Dense_Latch_PIPE0));
rb #(1) i_1(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Latch_PIPE0), .Q(MxPl_Dense_Latch_PIPE1));
rb #(1) i_2(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Latch_PIPE1), .Q(MxPl_Dense_Latch_PIPE2));
rb #(1) i_3(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Latch_PIPE2), .Q(MxPl_Dense_Latch_PIPE3));

rb #(1) i_4(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Clr_PIPE_M1), .Q(MxPl_Dense_Clr_PIPE0));
rb #(1) i_5(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Clr_PIPE0), .Q(MxPl_Dense_Clr_PIPE1));
rb #(1) i_6(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Clr_PIPE1), .Q(MxPl_Dense_Clr_PIPE2));
rb #(1) i_7(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Clr_PIPE2), .Q(MxPl_Dense_Clr_PIPE3));

rb #(1) i_8(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(RowIndex_Update_PIPE_M1), .Q(RowIndex_Update_PIPE0));
rb #(1) i_9(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(RowIndex_Update_PIPE0), .Q(RowIndex_Update_PIPE1));
rb #(1) i_10(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(RowIndex_Update_PIPE1), .Q(RowIndex_Update_PIPE2));
rb #(1) i_11(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(RowIndex_Update_PIPE2), .Q(RowIndex_Update_PIPE3));

rb #(1) i_12(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(GlbCtr_Latch_PIPE_M1), .Q(GlbCtr_Latch_PIPE0));
rb #(1) i_13(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(GlbCtr_Latch_PIPE0), .Q(GlbCtr_Latch_PIPE1));
rb #(1) i_14(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(GlbCtr_Latch_PIPE1), .Q(GlbCtr_Latch_PIPE2));
rb #(1) i_15(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(GlbCtr_Latch_PIPE2), .Q(GlbCtr_Latch_PIPE3));

rb #(1) i_16(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE_M1), .Q(MxPl_Sparse_Latch_PIPE0));
rb #(1) i_17(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE0), .Q(MxPl_Sparse_Latch_PIPE1));
rb #(1) i_18(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE1), .Q(MxPl_Sparse_Latch_PIPE2));
rb #(1) i_19(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE2), .Q(MxPl_Sparse_Latch_PIPE3));
rb #(1) i_20(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE3), .Q(MxPl_Sparse_Latch_PIPE4));

rb #(1) i_21(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE_M1), .Q(MxPl_Sparse_Clr_PIPE0));
rb #(1) i_22(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE0), .Q(MxPl_Sparse_Clr_PIPE1));
rb #(1) i_23(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE1), .Q(MxPl_Sparse_Clr_PIPE2));
rb #(1) i_24(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE2), .Q(MxPl_Sparse_Clr_PIPE3));
rb #(1) i_25(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE3), .Q(MxPl_Sparse_Clr_PIPE4));


rb #(6) i_26(.CLK(CLK), .RESET_N(RESET_N), .ctrl(RowIndex_Update_PIPE_M1), .D(RI_M1), .Q(RI_0));
rb #(6) i_27(.CLK(CLK), .RESET_N(RESET_N), .ctrl(RowIndex_Update_PIPE0), .D(RI_0), .Q(RI_1));
rb #(6) i_28(.CLK(CLK), .RESET_N(RESET_N), .ctrl(RowIndex_Update_PIPE1), .D(RI_1), .Q(RI_2));
rb #(6) i_29(.CLK(CLK), .RESET_N(RESET_N), .ctrl(RowIndex_Update_PIPE2), .D(RI_2), .Q(RI_3));
rb #(6) i_30(.CLK(CLK), .RESET_N(RESET_N), .ctrl(RowIndex_Update_PIPE3), .D(RI_3), .Q(RI_4));

rb #(1) i_31(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE_M1), .Q(ET_L1_En_PIPE0));
rb #(1) i_32(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE0), .Q(ET_L1_En_PIPE1));
rb #(1) i_33(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE1), .Q(ET_L1_En_PIPE2));
rb #(1) i_34(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE2), .Q(ET_L1_En_PIPE3));
rb #(1) i_35(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE3), .Q(ET_L1_En_PIPE4));

rb #(1) i_36(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_Clr_PIPE_M1), .Q(ET_L1_Clr_PIPE0));

rb #(`GCSP) i_37(.CLK(CLK), .RESET_N(RESET_N), .ctrl(ET_Thr_Latch_PIPE_M1), .D(ET_THR_PIPE_M1), .Q(ET_THR_PIPE0));
rb #(`GCSP) i_38(.CLK(CLK), .RESET_N(RESET_N), .ctrl(ET_Thr_Latch_PIPE0), .D(ET_THR_PIPE0), .Q(ET_THR_PIPE1));
rb #(`GCSP) i_39(.CLK(CLK), .RESET_N(RESET_N), .ctrl(ET_Thr_Latch_PIPE1), .D(ET_THR_PIPE1), .Q(ET_THR_PIPE2));
rb #(`GCSP) i_40(.CLK(CLK), .RESET_N(RESET_N), .ctrl(ET_Thr_Latch_PIPE2), .D(ET_THR_PIPE2), .Q(ET_THR_PIPE3));
rb #(`GCSP) i_41(.CLK(CLK), .RESET_N(RESET_N), .ctrl(ET_Thr_Latch_PIPE3), .D(ET_THR_PIPE3), .Q(ET_THR_PIPE4));

rb #(1) i_42(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE_M1), .Q(ET_L3_En_PIPE0));
rb #(1) i_43(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE0), .Q(ET_L3_En_PIPE1));
rb #(1) i_44(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE1), .Q(ET_L3_En_PIPE2));
rb #(1) i_45(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE2), .Q(ET_L3_En_PIPE3));
rb #(1) i_46(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE3), .Q(ET_L3_En_PIPE4));
rb #(1) i_47(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE4), .Q(ET_L3_En_PIPE5));

rb #(1) i_48(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_Thr_Latch_PIPE_M1), .Q(ET_Thr_Latch_PIPE0));
rb #(1) i_49(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_Thr_Latch_PIPE0), .Q(ET_Thr_Latch_PIPE1));
rb #(1) i_50(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_Thr_Latch_PIPE1), .Q(ET_Thr_Latch_PIPE2));
rb #(1) i_51(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_Thr_Latch_PIPE2), .Q(ET_Thr_Latch_PIPE3));



`ifdef EWAT_PIPE
rb #(1) i_e1(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(GlbCtr_Latch_PIPE3), .Q(GlbCtr_Latch_PIPE4));
rb #(1) i_e2(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE5), .Q(MxPl_Sparse_Latch_PIPE6));
rb #(1) i_e3(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Clr_PIPE4), .Q(MxPl_Sparse_Clr_PIPE5));
rb #(6) i_e4(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(RI_4), .Q(RI_5));
rb #(1) i_e5(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L1_En_PIPE4), .Q(ET_L1_En_PIPE5));
rb #(`GCSP) i_e6(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_THR_PIPE4), .Q(ET_THR_PIPE5));
rb #(1) i_e7(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(ET_L3_En_PIPE5), .Q(ET_L3_En_PIPE6));
`endif

rb #(1) i_f1(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Dense_Latch_PIPE3), .Q(MxPl_Dense_Latch_PIPE4));
rb #(1) i_f2(.CLK(CLK), .RESET_N(RESET_N), .ctrl(1'b1), .D(MxPl_Sparse_Latch_PIPE4), .Q(MxPl_Sparse_Latch_PIPE5));

endmodule

module rb #(
   parameter REG_WIDTH          = 1
)(
   input                       CLK,
   input                       RESET_N,
   input                       ctrl,
   input      [REG_WIDTH-1:0]  D,               
   output reg [REG_WIDTH-1:0]  Q
);

always @(posedge CLK or negedge RESET_N) begin
   if(~RESET_N) begin
         Q <= 0;
   end

   else begin
      if(ctrl) begin
         Q <= D;
      end

      else begin
         Q <= Q;
      end
   end
end

endmodule



