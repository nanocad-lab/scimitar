
`ifndef _GLOBAL_VH_
`define _GLOBAL_VH_
`define DEBUG_SNG
`define ERIDA_DOT_PRODUCT_WIDTH           (`MAC_CN_HGT*`MAC_CN_HGT)                //=81 Corresponds to 9x9 dot-product window
`define ERIDA_FP_PRECISION                            6                            //=06 Fixed Point Precision of the system
`define ERIDA_WITHIN_SLICE_CL_WIDTH                   32                           //=32 Number of Sliding Windows simultaneosly computed
`define ERIDA_NO_OF_SLICES                            32                           //=32 Number of Filters simultaneously computed
`define LFSR_WIDTH                         (`ERIDA_FP_PRECISION-1)                 //=05 LFSR Width= ERIDA_FP_PRECISION-1
`define SNG_WIDTH                            `ERIDA_FP_PRECISION                   //=06 SNG's process 6-bit precise fixed point numbers                       
`define SC_ACC_WIDTH                                  2                            //=02 Indicates Ternary Nature of dot-product output, +1,0,-1. Needs 2 bits to represent
`define BANK_CTR_WIDTH                                7                            //=07 Bank Counter needs to represent numbers from -64 to +64 in binary. This needs 7-bit

`ifdef MACLEOD
   `define ERIDA_NO_OF_BANKS                          8                            //=08 Number of Banks
`elsif MACIVER
   `define ERIDA_NO_OF_BANKS                          2                            //=02 Number of Banks
`endif
`define GLB_CTR_FSM_STATE_WIDTH                       3                            //=03 Unused

`endif



`define OHE_EN_WEIGHT_LFSR                                                          //=1 One-Hot Encoding Enabled for Weight LFSR
//`define DEBUG_SMALL
`ifdef DEBUG_SMALL                                                                  // Debug Options for Testbench. (Checks functionality at smaller sizes)
`define ERIDA_WITHIN_SLICE_CL_WIDTH  2                                              
`define ERIDA_NO_OF_SLICES           2
`define ERIDA_NO_OF_BANKS            8
`endif


////////////*******************Derived Directives used in block module definitions******************/////////////////


`define FXP                                  `ERIDA_FP_PRECISION                    //=06 Fixed Point Precision of the system
`define N_L                                    (2**`LFSR_WIDTH)                     //=32 Indicates the width of the LFSR register
`define N_R                               `ERIDA_DOT_PRODUCT_WIDTH                  //=81 Corresponds to 9x9 dot-product window
`define N_C                             `ERIDA_WITHIN_SLICE_CL_WIDTH                //=32 Number of sliding windows simultaneously computed
`define N_S                                  `ERIDA_NO_OF_SLICES                    //=32 Number of filters simulteniously computed
`define N_B                                  `ERIDA_NO_OF_BANKS                     //=08 Number of banks
`define BCP                                    `BANK_CTR_WIDTH                      //=07 Bank Counter width
`define GCDP                                        `BCP                            //=07 Max-Pooling Circuit Precision in Dense-Mode= Bank Counter Precision
`define GCSP                                 (`BCP+$clog2(`N_B))                    //=10 Max-Pooling, Global Accumulator Circuit Precisions in Sparse-Mode = BCP + 3
`define BNK_INDEX_CTR_WIDTH                     ($clog2(`N_B))                      //=03 Unused Now
`define ADDER_LVLS                              ($clog2(`N_B))                      //=03 Unused Now

`define BB_PADDING_WIDTH                      (`MAC_CN_HGT/2)                       //=04 Number of Inputs padded on either side of the sliding window = floor(9/2)
`define BB_WIDTH                        (`N_C+2*`BB_PADDING_WIDTH)                  //=40 Bank-Buffer Width for sliding-window creation. includes zero-padding
`define BB_REG_WIDTH                     (`N_C+`BB_PADDING_WIDTH)                   //=36 Bank-Buffer Register Width
`define N_L_REG                  ((`N_R%`N_L) ? (`N_R/`N_L+1) : (`N_R/`N_L))        //=03 

                                                        
////////////**************Directives to use Analog-Macros behavioral model or SPICE model***********/////////////////

`ifdef SYNTH                                                               
   `define MACRO_ANA
`elsif AMS
   `define MACRO_ANA
`endif




