`timescale 1ns/1ps
///////////////////////////////
// Includes
`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"

module bankbuff_new (
    clk,        // I: Clock input
    en,         // I: Buffer enable
    clr,        // I: Buffer clear
    
    //******[10/15/22]VKJ: Removed Zero indicators.
             //zero_in,    // I: Zero indicator in
             //zero_out,   // O: Zero indicator out
    //******[10/15/22]VKJ: Removed Zero indicators.
    
    val_in,     // I: Value to be buffered
    roi_lb_r,   // I: Selects left(0) or right(1)
    val_out     // O: Buffer output
);


input  wire                                 clk;
input  wire                                 en;
input  wire                                 clr;
    //******[10/15/22]VKJ: Removed Zero indicators.
         //input  wire [`MAC_CN_HGT-1:0]               zero_in;
         //output wire [`MAC_CN_HGT-1:0]               zero_out;
    //******[10/15/22]VKJ: Removed Zero indicators.
input  wire [`BB_REG_WIDTH*`FXP-1:0]        val_in; //(32+4)x6. 4 extras from right for roi_l and 4 extras from left for roi_r
input  wire                                 roi_lb_r;
output reg [`MAC_CN_HGT*`BB_WIDTH*`FXP-1:0] val_out;



wire [`MAC_CN_HGT*`BB_REG_WIDTH*`FXP-1:0] bb_reg_out;
sngbuff #(.BUF_WDT(`BB_REG_WIDTH*`FXP)) s_sngbuff_1st(
    .clk(clk),
    .en(en),
    .clr(clr),        // I: Buffer clear
    //******[10/15/22]VKJ: Removed Zero indicators.
         //.zero_in(zero_in[0]),    // I: Zero indicator in
         //.zero_out(zero_out[0]),   // O: Zero indicator out
    //******[10/15/22]VKJ: Removed Zero indicators.
    .val_in(val_in[`BB_REG_WIDTH*`FXP-1:0]),     // I: Value to be buffered
    .val_out(bb_reg_out[`BB_REG_WIDTH*`FXP-1:0])     // O: Buffer output
);

genvar j;
generate
    for (j=1; j < `MAC_CN_HGT; j=j+1)
    begin : FILTER_HEIGHT
       sngbuff #(.BUF_WDT(`BB_REG_WIDTH*`FXP)) s_sngbuff(              
            .clk(clk),        // I: Clock input
            .en(en),         // I: Buffer enable
            .clr(clr),        // I: Buffer clear
            //******[10/15/22]VKJ: Removed Zero indicators.
               // .zero_in(zero_in[j]),    // I: Zero indicator in
               // .zero_out(zero_out[j]),   // O: Zero indicator out
            //******[10/15/22]VKJ: Removed Zero indicators.
            .val_in(bb_reg_out[(j-1)*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP]),     // I: Value to be buffered
            .val_out(bb_reg_out[j*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP])     // I: Value to be buffered
        );
    end
endgenerate

integer i;

//[09/28/22]Reordering bus placement to allign with image.
reg [`MAC_CN_HGT*`BB_REG_WIDTH*`FXP-1:0] bb_reg_out_flipped;
 
always @(*) begin

     for(i=0;i<`MAC_CN_HGT;i=i+1) begin
        bb_reg_out_flipped[(`MAC_CN_HGT-i-1)*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP] <= bb_reg_out[i*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP];
      end


end


always @(*) begin

   if(roi_lb_r==1'b1) begin //Zero-Padding on the right-side of image. Left-side for verilog bit indexing
      for(i=0;i<`MAC_CN_HGT;i=i+1) begin
         val_out[i*`BB_WIDTH*`FXP +: `BB_WIDTH*`FXP] <= {{((`BB_WIDTH-`BB_REG_WIDTH)*`FXP){1'b0}},bb_reg_out_flipped[i*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP]};
      end
   end

   else begin           //Zero-Padding on the left-side of image. Right-side for verilog bit indexing
      for(i=0;i<`MAC_CN_HGT;i=i+1) begin
         val_out[i*`BB_WIDTH*`FXP +: `BB_WIDTH*`FXP] <= {bb_reg_out_flipped[i*`BB_REG_WIDTH*`FXP +: `BB_REG_WIDTH*`FXP],{((`BB_WIDTH-`BB_REG_WIDTH)*`FXP){1'b0}}};
      end
   end


end
endmodule

