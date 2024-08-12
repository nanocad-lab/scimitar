//////////////////////////////////////////////////////////////////////////////
// The MIT License (MIT)
// 
// Copyright (c) 2020 UCLA NanoCAD Laboratory
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
/////////////////////////////////////////////////////////////////////////////
//
// Module name : TB_SCIM_TOP
// Created     : Fri 30 Sep 2022
// Author      : Wojciech Romaszkan
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : SCIM_TOP Top Test Case to test memory read write using 
//               JTAG interface.
//               
/////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////
// Includes
`include "scotsman_conf.vh"
`include "ERI-DA_HEADERS.vh"
`include "scotsman_jtag.vh"
`include "jtag_master_vf.sv"

module TB_SCIM_TOP();

   localparam TCKP = 5.5;
   localparam CLKP = 2.2;

   reg                  clk;
   reg                  jtag_tck;
   reg                  rstn;
   wire                 jtag_tdo;
   wire                 done;

   // Seed dump
   reg                  mac_en_r;
   integer alcg, alc;

   jtag_driver_if       jtag_driver_if(jtag_tck,rstn,jtag_tdo);
   jtag_drivers         jtag_drivers = new();
   jtag_master_cmd      jtag_master_cmd = new();

   // Files
   int                                       resf;
   string                                    testCase;
   string                                    resFileName;
   string                                    simOutDir;
   string InsMemFile;
   string InsMemFileDump;
   integer NumInsMemWrites;
   string ActMemFile;
   string ActMemFileZero;
   string ActMemFileDump;
   string ActMemFileNo;
   integer NumActMemWrites;
   string WgtMemFile;
   string WgtMemFileDump;
   integer NumWgtMemWrites;
   string tempStr;
   int aSeedFd, wSeedFd;

   SCIM_TOP dut(
      .clk_d(clk),
      .clk_ap(),
      .clk_an(),
      .vbias(),
      .clk_sel(),
      .reset_n(rstn),
      .tck(jtag_tck),
      .tms(jtag_driver_if.TMS),
      .trstn(jtag_driver_if.TRSTN),
      .tdi(jtag_driver_if.TDI),
      .tdo(jtag_tdo),
      .tdo_en(tdo_en),
      .clk_div(),
      .done(done)
   );


   initial begin
      jtag_drivers.vif = jtag_driver_if;
      jtag_drivers.cmd = jtag_master_cmd;
   end

   initial begin
      clk = 1'b0;
      jtag_tck = 1'b0;
      rstn  = 1'b0;
      #(TCKP*2);
      // Get testcase
      void'($value$plusargs("TESTCASE=%s", testCase));
      // Get output folder
      void'($value$plusargs("SIM_OUT_DIR=%s", simOutDir));
      // Set filenames
      case (testCase)
         "default","memtest" : begin
            //InsMemFile = "mem/mnist_lenet_8_8.mem";
            //InsMemFileDump = "sim_output/tb_acoustic_top_ins.mem";
            //NumInsMemWrites = 1024;
            ActMemFile = "mem/memtest_act_";
            ActMemFileDump = "sim_output/TB_SCIM_TOP_memtest_act_dump_";
            NumActMemWrites = 10;
            //WgtMemFile = "mem/wgt_gabor_5x5_";
            //WgtMemFileDump = "sim_output/tb_acoustic_top_wgt_";
            //NumWgtMemWrites = 80;
            // Zero act mem
            ActMemFileZero = "mem/act_zero.mem";
         end
         default : begin
            //InsMemFile = "mem/mnist_lenet_8_8.mem";
            //InsMemFileDump = "sim_output/tb_acoustic_top_ins.mem";
            //NumInsMemWrites = 1024;
            ActMemFile = "mem/memtest_act_";
            ActMemFileDump = "sim_output/TB_SCIM_TOP_memtest_act";
            NumActMemWrites = 10;
            //WgtMemFile = "mem/wgt_gabor_5x5_";
            //WgtMemFileDump = "sim_output/tb_acoustic_top_wgt_";
            //NumWgtMemWrites = 80;
            // Zero act mem
            ActMemFileZero = "mem/act_zero.mem";
         end
      endcase
      #(TCKP*2);
      rstn = 1'b1;
      #(TCKP*2);
      // Write all memories
      //void'(jtag_drivers.write_inst_mem(InsMemFile,NumInsMemWrites));
      //void'(jtag_drivers.read_inst_mem(InsMemFile,NumInsMemWrites));
      //void'(jtag_drivers.dump_inst_mem(InsMemFileDump,NumInsMemWrites));
      // Write input memory
      for (int i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
         ActMemFileNo.itoa(i);
         jtag_drivers.write_act_mem({ActMemFile, ActMemFileNo, ".mem"},NumActMemWrites,i);
      end
      //void'(jtag_drivers.write_act_mem(ActMemFileZero,NumActMemWrites,1));
      //void'(jtag_drivers.read_act_mem(ActMemFile,NumActMemWrites,0));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "0.mem"},NumWgtMemWrites,0));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "1.mem"},NumWgtMemWrites,1));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "2.mem"},NumWgtMemWrites,2));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "3.mem"},NumWgtMemWrites,3));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "4.mem"},NumWgtMemWrites,4));
      //void'(jtag_drivers.write_wgt_mem({WgtMemFile, "5.mem"},NumWgtMemWrites,5));
      while(jtag_master_cmd.num() != 0) #(TCKP*50);
      $display($time,": All Memory writes are done.");
      #(TCKP*50);
      if (testCase == "memtest") begin
         //void'(jtag_drivers.read_inst_mem(InsMemFile,NumInsMemWrites));
         //void'(jtag_drivers.dump_inst_mem(InsMemFileDump,NumInsMemWrites));
         //void'(jtag_drivers.read_act_mem(ActMemFile,NumActMemWrites,0));
         for (int i = 0; i < `ACT_MEM_BANKS; i = i + 1) begin
            ActMemFileNo.itoa(i);
            jtag_drivers.dump_act_mem({ActMemFileDump, ActMemFileNo, ".mem"}, NumActMemWrites,i);
         end
         //void'(jtag_drivers.read_act_mem(ActMemFile,NumActMemWrites,1));
         //void'(jtag_drivers.dump_act_mem(ActMemFileDump2,NumActMemWrites,1));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "0.mem"},NumWgtMemWrites,0));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "1.mem"},NumWgtMemWrites,1));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "2.mem"},NumWgtMemWrites,2));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "3.mem"},NumWgtMemWrites,3));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "4.mem"},NumWgtMemWrites,4));
         //void'(jtag_drivers.read_wgt_mem({WgtMemFile, "5.mem"},NumWgtMemWrites,5));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "0.mem"},NumWgtMemWrites,0));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "1.mem"},NumWgtMemWrites,1));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "2.mem"},NumWgtMemWrites,2));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "3.mem"},NumWgtMemWrites,3));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "4.mem"},NumWgtMemWrites,4));
         //void'(jtag_drivers.dump_wgt_mem({WgtMemFileDump, "5.mem"},NumWgtMemWrites,5));
         //while(jtag_master_cmd.num() != 0) #(TCKP*50);
         $display($time,": All Memory reads are done.");
      end
      else begin
         jtag_drivers.start_compute();
         while(jtag_master_cmd.num() != 0) #(TCKP*50);
         #(TCKP*20);
         wait(done == 1'b1);
         #(TCKP*20);
         //void'(jtag_drivers.dump_act_mem(ActMemFileDump1,NumActMemWrites,0));
         //void'(jtag_drivers.dump_act_mem(ActMemFileDump2,NumActMemWrites,1)); 
      end
      #(TCKP*100000);
      $finish;
   end

   initial begin
      fork
         jtag_drivers.run_jtag_master(); 
      join
   end

   always #(TCKP) jtag_tck <= ~jtag_tck;
   always #(CLKP) clk <= ~clk;


endmodule

