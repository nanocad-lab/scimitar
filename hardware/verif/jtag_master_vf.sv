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
// Module name : jtag_master
// Created     : 01/15/20
// Author      : Rahul Garg
// Affiliation : NanoCAD Laboratory, ECE Department, UCLA
// Description : JTAG Master drivers for controling JTAG Interface
//               
/////////////////////////////////////////////////////////////////////////////

//`include "acoustic_conf.vh"
`include "scotsman_conf.vh"
`include "scotsman_isa.vh"
`include "scotsman_jtag.vh"
`include "ERI-DA_HEADERS.vh"

typedef mailbox #(logic [142:0]) jtag_master_cmd;

interface jtag_driver_if (
   input bit       clock,
   input bit       rstn,
   input bit       TDO
);
   logic           TMS;
   logic           TDI;
   logic           TRSTN;
endinterface

class jtag_drivers;
   virtual jtag_driver_if   vif;
   jtag_master_cmd          cmd;

   bit [31:0]                                data_out;
   string                                    inst_mem_read_file;
   string                                    act_mem_read_file[0:`ACT_MEM_BANKS-1];
   string                                    wgt_mem_read_file;
   string                                    out_mem_read_file[0:`OUT_MEM_BANKS-1];
   bit [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      mem_data_out;
   bit                                       dump_mem;
   bit [2:0]                                 dump_mem_type;
   bit [`WGT_MEM_BANKS-1:0]             dump_mem_banks;
   integer                                   dump_num_words;
   integer                                   dump_num_addr;

   bit [`JTAG_INST_WDT-1:0]              dump_inst_mem_data[0:`ACSTC_INS_MEM_DEPTH-1];          
   bit [`ACT_MEM_DATA_WDT-1:0]         dump_act_mem_data[0:`ACT_MEM_DEPTH-1];          
   bit [`WGT_MEM_DATA_WDT_RD-1:0]      dump_wgt_mem_data[0:`WGT_MEM_DEPTH_RD-1];          
   bit [`OUT_MEM_DATA_WDT_RD-1:0]      dump_out_mem_data[0:`OUT_MEM_DEPTH_RD-1];          

   integer               errors;
   integer               transactions;
   integer               read_word_num;

   function new();
      this.errors = 0;
      this.transactions = 0;
      this.read_word_num = 0;
   endfunction

   //==========================================================
   //                 Tasks for JTAG Master
   //==========================================================
  
   bit [4:0]             jtag_state;
   bit [3:0]             reset_counter;
   bit [9:0]             wait_counter;
   bit [5:0]             shift_counter;
   logic [142:0]         cmd_buffer;
   bit                   idle;

   task rti_to_shift_ir;
   begin
      if (jtag_state == `JTAG_S_RUN_TEST_IDLE) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_SELECT_DR_SCAN;
      end else if (jtag_state == `JTAG_S_SELECT_DR_SCAN) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_SELECT_IR_SCAN;
      end else if (jtag_state == `JTAG_S_SELECT_IR_SCAN) begin
         vif.TMS = 1'b0;
         jtag_state = `JTAG_S_CAPTURE_IR;
      end else if (jtag_state == `JTAG_S_CAPTURE_IR) begin
         vif.TMS = 1'b0;
         shift_counter = 6'b0;
         jtag_state = `JTAG_S_SHIFT_IR;
      end 
   end
   endtask // rti_to_shift_ir
   
   task pause_ir_to_shift_ir;
   begin
      if (jtag_state == `JTAG_S_PAUSE_IR) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_EXIT2_IR;
      end else if (jtag_state == `JTAG_S_EXIT2_IR) begin
         vif.TMS = 1'b0;
         shift_counter = 6'b0;
         jtag_state = `JTAG_S_SHIFT_IR;
      end
   end
   endtask
   
   task shift_ir_to_exit1_ir;
   begin
      if (jtag_state == `JTAG_S_SHIFT_IR) begin
         if (shift_counter != cmd_buffer[36:32]) begin
            vif.TDI = cmd_buffer[shift_counter];
            shift_counter = shift_counter+1;
            vif.TMS = 1'b0;
            jtag_state = `JTAG_S_SHIFT_IR;
         end else begin
            vif.TMS = 1'b1;
            vif.TDI = cmd_buffer[cmd_buffer[36:32]];
            jtag_state = `JTAG_S_EXIT1_IR;         
         end
      end
   end
   endtask
   
   task exit1_ir_to_update_ir;
   begin
      if (jtag_state == `JTAG_S_EXIT1_IR) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_UPDATE_IR;
      end
   end
   endtask
   
   task update_ir_to_select_dr;
   begin
      if (jtag_state == `JTAG_S_UPDATE_IR) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_SELECT_DR_SCAN;
      end 
   end
   endtask
   
   task rti_to_select_dr;
   begin
      if (jtag_state == `JTAG_S_RUN_TEST_IDLE) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_SELECT_DR_SCAN;
      end
   end
   endtask
   
   task select_dr_to_shift_dr;
   begin 
      if (jtag_state == `JTAG_S_SELECT_DR_SCAN) begin
         vif.TMS = 1'b0;
         jtag_state = `JTAG_S_CAPTURE_DR;
      end else if (jtag_state == `JTAG_S_CAPTURE_DR) begin
         vif.TMS = 1'b0;
         shift_counter = 6'b0;
         jtag_state = `JTAG_S_SHIFT_DR;
      end 
   end
   endtask
      
   task shift_dr_to_exit1_dr;
   begin
      if (jtag_state == `JTAG_S_SHIFT_DR) begin
         if (shift_counter != cmd_buffer[73:69]) begin
            vif.TDI = cmd_buffer[37+shift_counter];
            shift_counter = shift_counter+1;
            vif.TMS = 1'b0;
            jtag_state = `JTAG_S_SHIFT_DR;
         end else begin
            shift_counter = shift_counter+1;
            vif.TMS = 1'b1;
            vif.TDI = cmd_buffer[37+cmd_buffer[73:69]];
            jtag_state = `JTAG_S_EXIT1_DR;         
         end
      end
   end
   endtask
   
   task exit1_dr_to_update_dr;
   begin
      if (jtag_state == `JTAG_S_EXIT1_DR) begin
         shift_counter = shift_counter+1;
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_UPDATE_DR;
      end
   end
   endtask
   
   task pause_dr_to_shift_dr;
   begin
      if (jtag_state == `JTAG_S_PAUSE_DR) begin
         vif.TMS = 1'b1;
         jtag_state = `JTAG_S_EXIT2_DR;
      end else if (jtag_state == `JTAG_S_EXIT2_DR) begin
         vif.TMS = 1'b0;
         shift_counter = 6'b0;
         jtag_state = `JTAG_S_SHIFT_DR;
      end
   end
   endtask

   task driver_ne;
      forever begin
         @(negedge vif.clock or negedge vif.rstn) begin
            if (vif.rstn == 1'b0) begin
               jtag_state = `JTAG_S_TEST_LOGIC_RESET;
               vif.TMS = 1'b1;
               wait_counter = 10'b0;
               reset_counter = 3'b0;
               shift_counter = 6'b0;
               vif.TRSTN = 1'b0;
               idle = 1'b1;
               dump_mem = 1'b0;
            end else begin
               vif.TRSTN = 1'b1;
               if( idle == 1 ) begin
                  idle = 1'b0;
                  cmd.get(cmd_buffer);
               end else begin
                  case (cmd_buffer[142:138])
                     `JTAG_OPC_WAIT: begin
                        if (wait_counter == cmd_buffer[9:0]) begin
                           wait_counter = 10'b0;
                           idle = 1'b1;
                        end else begin
                           vif.TMS = 1'b0;
                           wait_counter = wait_counter+1;
                        end
                     end
                     `JTAG_OPC_RESET_TAP: begin
                        if (reset_counter < 6) begin
                           vif.TMS = 1'b1;
                           reset_counter = reset_counter + 1;
                        end else begin
                           vif.TMS = 1'b1;
                           reset_counter = 3'b0;
                           idle = 1'b1;
                           jtag_state = `JTAG_S_TEST_LOGIC_RESET;                  
                        end
                     end
                     `JTAG_OPC_RESET_RTI: begin
                        if (jtag_state == `JTAG_S_TEST_LOGIC_RESET) begin
                           vif.TMS = 1'b0;
                           idle = 1'b1;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;    
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_IR_PAUSE: begin
                        if (jtag_state == `JTAG_S_EXIT1_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_PAUSE_IR;
                           idle = 1'b1;
                        end else begin
                           shift_ir_to_exit1_ir();
                           rti_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_IR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           idle = 1'b1;
                        end else begin
                           exit1_ir_to_update_ir();
                           shift_ir_to_exit1_ir();
                           rti_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_PAUSE: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           cmd_buffer[142:138] = `JTAG_OPC_RTI_SHIFT_DR_PAUSE;
                        end else begin
                           exit1_ir_to_update_ir();
                           shift_ir_to_exit1_ir();
                           rti_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           cmd_buffer[142:138] = `JTAG_OPC_RTI_SHIFT_DR_RTI;
                        end else begin
                           exit1_ir_to_update_ir();
                           shift_ir_to_exit1_ir();
                           rti_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_IR_PAUSE: begin
                        if (jtag_state == `JTAG_S_EXIT1_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_PAUSE_IR;
                           idle = 1'b1;
                        end else begin
                           shift_ir_to_exit1_ir();
                           pause_ir_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_IR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           idle = 1'b1;
                        end else begin
                           exit1_ir_to_update_ir();               
                           shift_ir_to_exit1_ir();
                           pause_ir_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_IR_SHIFT_DR_PAUSE: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           cmd_buffer[142:138] = `JTAG_OPC_RTI_SHIFT_DR_PAUSE;
                        end else begin
                           exit1_ir_to_update_ir();
                           shift_ir_to_exit1_ir();
                           pause_ir_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_IR_SHIFT_DR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_IR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           cmd_buffer[142:138] = `JTAG_OPC_RTI_SHIFT_DR_RTI;
                        end else begin
                           exit1_ir_to_update_ir();  
                           shift_ir_to_exit1_ir();
                           pause_ir_to_shift_ir();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_DR_PAUSE: begin
                        if (jtag_state == `JTAG_S_EXIT1_DR) begin
                           shift_counter = shift_counter+1;
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_PAUSE_DR;
                           idle = 1'b1;
                        end else begin
                           shift_dr_to_exit1_dr();
                           pause_dr_to_shift_dr();
                        end
                     end
                     `JTAG_OPC_PAUSE_SHIFT_DR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_DR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           idle = 1'b1;
                        end else begin
                           exit1_dr_to_update_dr();
                           shift_dr_to_exit1_dr();
                           pause_dr_to_shift_dr();
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_DR_PAUSE: begin
                        if (jtag_state == `JTAG_S_EXIT1_DR) begin
                           shift_counter = shift_counter+1;
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_PAUSE_DR;
                           idle = 1'b1;
                        end else begin
                           shift_dr_to_exit1_dr();
                           select_dr_to_shift_dr();
                           rti_to_select_dr();
                        end
                     end
                     `JTAG_OPC_RTI_SHIFT_DR_RTI: begin
                        if (jtag_state == `JTAG_S_UPDATE_DR) begin
                           vif.TMS = 1'b0;
                           jtag_state = `JTAG_S_RUN_TEST_IDLE;
                           idle = 1'b1;
                        end else begin
                           exit1_dr_to_update_dr();
                           shift_dr_to_exit1_dr();
                           select_dr_to_shift_dr();
                           rti_to_select_dr();
                        end
                     end
                     // WJR this needs fixing for new parameters.
                     `JTAG_OPC_MEM_DUMP_START: begin
                        dump_mem = 1'b1;
                        dump_num_words = `JTAG_UDR_MEM_DATA_REG_WDT/32;
                        dump_num_addr = 0;
                        dump_mem_type = cmd_buffer[2:0];
                        dump_mem_banks = cmd_buffer[`WGT_MEM_BANKS+2:3];
                        idle = 1'b1;
                     end
                     `JTAG_OPC_MEM_DUMP_END: begin
                        if (dump_mem_type == 3'b000 ) begin // INST Memory
                            $writememh(inst_mem_read_file,dump_inst_mem_data,0,cmd_buffer[19:0]);
                        end else if (dump_mem_type == 3'b001) begin
                            //$writememh(act_mem_read_file[dump_mem_banks],dump_act_mem_data,0,cmd_buffer[19:0]);
                            $writememh(act_mem_read_file[dump_mem_banks],dump_act_mem_data);
                        end else if (dump_mem_type == 3'b010) begin
                            $writememb(wgt_mem_read_file,dump_wgt_mem_data);
                            //$writememh(wgt_mem_read_file[dump_mem_banks],dump_wgt_mem_data,0,cmd_buffer[19:0]);
                        end else if (dump_mem_type == 3'b011) begin
                            $writememb(out_mem_read_file[dump_mem_banks],dump_out_mem_data);
                        end
                        dump_mem = 1'b0;
                        idle = 1'b1;
                     end
                     default: jtag_state = jtag_state;
                  endcase
               end
            end
         end
      end
   endtask // driver_ne

   task driver_pe;
      forever begin
         @(posedge vif.clock or negedge vif.rstn) begin
            if (!vif.rstn) begin
               data_out = 32'b0;
            end else begin
               if(jtag_state == `JTAG_S_SHIFT_DR || jtag_state == `JTAG_S_EXIT1_DR || 
				  jtag_state == `JTAG_S_PAUSE_DR || jtag_state == `JTAG_S_UPDATE_DR ) begin
                  if (shift_counter > 0 && shift_counter < 33) begin
                     data_out[shift_counter-1] = vif.TDO;
                  end
               end
            end
         end
      end
   endtask // driver_pe

   task read_comp();
      forever begin
         @(posedge vif.clock) begin
            if ( shift_counter == 33 ) begin
               shift_counter = 6'b0;
               transactions++;
               if ( cmd_buffer[105:74] != 32'b0 ) begin
                  if ( dump_mem == 1'b1 ) begin
                      if ( dump_num_words > 0 ) begin
                          mem_data_out[(((`JTAG_UDR_MEM_DATA_REG_WDT/32)+1-dump_num_words)*32)-1 -: 32] = data_out;
                          dump_num_words--;
                      end
                      if ( dump_num_words == 0 ) begin
                          if (dump_mem_type == 3'b000 ) begin // INST Memory
                             dump_inst_mem_data[dump_num_addr] = mem_data_out[`JTAG_INST_WDT-1:0];
                          end else if (dump_mem_type == 3'b001) begin // Activation Memory
                             dump_act_mem_data[dump_num_addr] = mem_data_out[`ACT_MEM_DATA_WDT-1:0];
                          end else if (dump_mem_type == 3'b010) begin
                             //dump_wgt_mem_data[dump_num_addr] = mem_data_out[`WGT_MEM_DATA_WDT_WR*(dump_mem_banks+1)-1 -: `WGT_MEM_DATA_WDT_WR];
                             dump_wgt_mem_data[dump_num_addr] = mem_data_out[`WGT_MEM_DATA_WDT_RD-1:0];
                          end else if (dump_mem_type == 3'b011) begin
                             dump_out_mem_data[dump_num_addr] = mem_data_out[`OUT_MEM_DATA_WDT_RD-1:0];
                          end
                          dump_num_words = `JTAG_UDR_MEM_DATA_REG_WDT/32;
                          dump_num_addr++;
                      end
                  end else if ( ((cmd_buffer[137:106]&cmd_buffer[105:74]) != data_out&cmd_buffer[105:74]) ) begin
                      $display($time,": JTAG Read Comparison failed: Expected Value = %032b, Mask = %032b, Simulated Value = %032b",cmd_buffer[137:106],cmd_buffer[105:74],data_out);
                     errors++;
                  end else begin
                     // Only for Debug // 
                     // $display($time,": JTAG Read Comparison Passed: Expected Value = %032b, Mask = %032b, Simulated Value = %032b",cmd_buffer[137:106],cmd_buffer[105:74],data_out);                  
                  end
               end
            end
         end
      end
   endtask

   task reset_fsm_to_tlr;
   begin
      cmd.put({`JTAG_OPC_RESET_TAP,138'b0});
   end
   endtask
   
   task fsm_tlr_to_rti;
   begin
      cmd.put({`JTAG_OPC_RESET_RTI,138'b0});
   end
   endtask

   task run_jtag_master;
      $display ($time,": JTAG Master starting.");
      reset_fsm_to_tlr();
      fsm_tlr_to_rti();
      fork
         driver_ne();
         driver_pe();
         read_comp();
      join
   endtask

   //===================================================
   // JTAG User Register Read Write Operations
   // Wrapper tasks over JTAG Master
   //===================================================
   integer DATA_REG_WIDTH[`JTAG_NUM_USER_REG-1:0] = '{`JTAG_UDR_CFG_REG_WDT,0,32,`JTAG_UDR_MEM_DATA_REG_WDT,`JTAG_UDR_INST_REG_WDT};
   logic [142:0]        jtag_master_cmd_wr;

   //function add_delay(input bit [9:0] num_cycles = 10);
   task add_delay(input bit [9:0] num_cycles = 10);
   begin
      cmd.put({`JTAG_OPC_WAIT,128'b0,num_cycles});      
   end
   //endfunction
   endtask

/*    function write_jtag_udr ( */
   task write_jtag_udr(
      input integer                           data_reg_num,
      input [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      data_reg_value // Need to find a way to get max value
   );
   integer                                 data_reg_width;
   integer                                 i;
   begin
      data_reg_width = DATA_REG_WIDTH[data_reg_num];
      if ( data_reg_width > 32 ) begin 
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_PAUSE;
         jtag_master_cmd_wr[137:106]                      = 32'b0;
         jtag_master_cmd_wr[105:74]                       = 32'b0;
         jtag_master_cmd_wr[73:69]                        = 5'h1F;
         jtag_master_cmd_wr[68:37]                        = data_reg_value[31:0];
         jtag_master_cmd_wr[36:32]                        = `JTAG_INST_REG_WIDTH-1;
         jtag_master_cmd_wr[31:`JTAG_USERREG_SEL_WIDTH+5]  = 'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+4]     = 1'b1;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+3:4]   = data_reg_num;
         jtag_master_cmd_wr[3:0]                          = `JTAG_INST_USERREG;
         cmd.put(jtag_master_cmd_wr);
         for (i=0;i<(data_reg_width-32-((data_reg_width%32==0)?32:(data_reg_width%32)))/32;i++) begin
            jtag_master_cmd_wr[142:138]                   = `JTAG_OPC_PAUSE_SHIFT_DR_PAUSE;
            jtag_master_cmd_wr[137:106]                   = 32'b0;
            jtag_master_cmd_wr[105:74]                    = 32'b0;
            jtag_master_cmd_wr[73:69]                     = 5'h1F;
            jtag_master_cmd_wr[68:37]                     = data_reg_value[32*(i+2)-1 -: 32];
            jtag_master_cmd_wr[36:0]                      = 37'b0;
            cmd.put(jtag_master_cmd_wr);
         end
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_PAUSE_SHIFT_DR_RTI;
         jtag_master_cmd_wr[137:106]                      = 32'b0;
         jtag_master_cmd_wr[105:74]                       = 32'b0;
         jtag_master_cmd_wr[73:69]                        = ((data_reg_width%32==0)?32:(data_reg_width%32))-1;
         jtag_master_cmd_wr[68:37]                        = data_reg_value[data_reg_width-1 -: 32 ]; // TODO: FixMe ((data_reg_width%32==0)?32:(data_reg_width%32))];
         jtag_master_cmd_wr[36:0]                         = 37'b0;
         cmd.put(jtag_master_cmd_wr);
      end else begin
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_RTI;
         jtag_master_cmd_wr[137:106]                      = 32'b0;
         jtag_master_cmd_wr[105:74]                       = 32'b0;
         jtag_master_cmd_wr[73:69]                        = data_reg_width-1;
         jtag_master_cmd_wr[68:37]                        = data_reg_value[data_reg_width-1 -: 32 ]; //  TODO: FixMe 0];
         jtag_master_cmd_wr[36:32]                        = `JTAG_INST_REG_WIDTH-1;
         jtag_master_cmd_wr[31:`JTAG_USERREG_SEL_WIDTH+5]  = 'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+4]     = 1'b1;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+3:4]   = data_reg_num;
         jtag_master_cmd_wr[3:0]                          = `JTAG_INST_USERREG;
         cmd.put(jtag_master_cmd_wr);
      end
   end
   //endfunction // write_jtag_udr
   endtask
   
   task read_jtag_udr(
      input integer                               data_reg_num,
      input [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      data_reg_value,
      input [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]      data_reg_mask = {`JTAG_UDR_MEM_DATA_REG_WDT{1'b0}}
   );
   reg [`JTAG_UDR_MEM_DATA_REG_WDT-1:0]        data_reg_value_rd;
   integer                                 data_reg_width;
   integer                                 i;
   begin
      data_reg_width = DATA_REG_WIDTH[data_reg_num];
      if ( data_reg_width > 32 ) begin
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_PAUSE;
         jtag_master_cmd_wr[137:106]                      = data_reg_value[31:0];
         jtag_master_cmd_wr[105:74]                       = data_reg_mask[31:0];
         jtag_master_cmd_wr[73:69]                        = 5'h1F;
         jtag_master_cmd_wr[68:37]                        = 32'b0;
         jtag_master_cmd_wr[36:32]                        = `JTAG_INST_REG_WIDTH-1;
         jtag_master_cmd_wr[31:`JTAG_USERREG_SEL_WIDTH+6]  = 'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+5]     = 1'b1;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+4]     = 1'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+3:4]   = data_reg_num;
         jtag_master_cmd_wr[3:0]                          = `JTAG_INST_USERREG;
         cmd.put(jtag_master_cmd_wr);
         for (i=0;i<(data_reg_width-32-((data_reg_width%32==0)?32:(data_reg_width%32)))/32;i++) begin
            jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_PAUSE_SHIFT_DR_PAUSE;
            jtag_master_cmd_wr[137:106]                      = data_reg_value[32*(i+2)-1 -: 32];
            jtag_master_cmd_wr[105:74]                       = data_reg_mask[32*(i+2)-1 -: 32];
            jtag_master_cmd_wr[73:69]                        = 5'h1F;
            jtag_master_cmd_wr[68:37]                        = 32'b0;
            jtag_master_cmd_wr[36:0]                         = 37'b0;
            cmd.put(jtag_master_cmd_wr);
         end
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_PAUSE_SHIFT_DR_RTI;
         jtag_master_cmd_wr[137:106]                      = data_reg_value[data_reg_width-1 -: 32 ];
         jtag_master_cmd_wr[105:74]                       = data_reg_mask[data_reg_width-1 -: 32 ];
         jtag_master_cmd_wr[73:69]                        = ((data_reg_width%32==0)?32:(data_reg_width%32))-1;
         jtag_master_cmd_wr[68:37]                        = 32'b0; // TODO: FixMe ((data_reg_width%32==0)?32:(data_reg_width%32))];
         jtag_master_cmd_wr[36:0]                         = 37'b0;
         cmd.put(jtag_master_cmd_wr);
      end else begin
         jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_RTI_SHIFT_IR_SHIFT_DR_RTI;
         jtag_master_cmd_wr[137:106]                      = data_reg_value[data_reg_width-1 -: 32 ];
         jtag_master_cmd_wr[105:74]                       = data_reg_mask[data_reg_width-1 -: 32 ];
         jtag_master_cmd_wr[73:69]                        = data_reg_width-1;
         jtag_master_cmd_wr[68:37]                        = 32'b0; //  TODO: FixMe 0];
         jtag_master_cmd_wr[36:32]                        = `JTAG_INST_REG_WIDTH-1;
         jtag_master_cmd_wr[31:`JTAG_USERREG_SEL_WIDTH+6]  = 'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+5]     = 1'b1;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+4]     = 1'b0;
         jtag_master_cmd_wr[`JTAG_USERREG_SEL_WIDTH+3:4]   = data_reg_num;
         jtag_master_cmd_wr[3:0]                          = `JTAG_INST_USERREG;
         cmd.put(jtag_master_cmd_wr);
      end
   end
   endtask // read_jtag_udr

    //=======================================================
   //                Memory Read Write Tasks
   //=======================================================

   reg [`JTAG_INST_WDT-1:0]             jtag_mem_inst;
   reg [`ACT_MEM_DATA_WDT-1:0]          act_mem_data    [0:`ACT_MEM_DEPTH-1];
   reg [`WGT_MEM_DATA_WDT_WR-1:0]       wgt_mem_data_fc [0:`WGT_MEM_DEPTH_WR-1];
   
   reg [`N_L-1:0]                       seed_mem_data   [0:(`N_L_REG*2*`N_B)-1];
   reg [`N_B*`N_S*3-1:0]                     wgts_mem_data   [0:(2*`N_R)-1];

   integer                           mem_addr;
   
   task start_compute(
   );
   begin
      $display ($time,": Starting computation");
      jtag_mem_inst = set_dat(jtag_mem_inst, 0);
      jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_RUNEN);
      write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
      write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
      add_delay(4);
   end
   endtask

   task write_act_mem (
      input string          act_mem_file,
      input integer         num_addresses,
      input logic           act_mem_bank = 1'b0,
      input integer         start_address = 0
   );
   begin
      $display ($time,": Writing Activation Memory Bank %1b from the mem file %s.",act_mem_bank,act_mem_file);
      $readmemh(act_mem_file,act_mem_data);
      $display ($time,": %b.",jtag_mem_inst);
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_ACTST);
         jtag_mem_inst = set_actst_addr(jtag_mem_inst, mem_addr);
         jtag_mem_inst = set_actst_bank(jtag_mem_inst, act_mem_bank);
         //$display ($time,": Inst: %b.",jtag_mem_inst);
         //$display ($time,": Data: %b.",act_mem_data[mem_addr]);
         write_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,act_mem_data[mem_addr]);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
      end
   end
   endtask

   task dump_act_mem (
      input string          act_mem_file,
      input integer         num_addresses,
      input logic           act_mem_bank = 1'b0,
      input integer         start_address = 0
   );
   begin
      $display ($time,": Reading Activation Memory Bank %1b and dumping in the mem file %s.",act_mem_bank,act_mem_file);
      act_mem_read_file[act_mem_bank] = act_mem_file; 
      cmd.put({`JTAG_OPC_MEM_DUMP_START,134'b0,act_mem_bank,3'b001}); 
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_ACTLD);
         jtag_mem_inst = set_actld_addr(jtag_mem_inst, start_address+mem_addr);
         jtag_mem_inst = set_actld_bank(jtag_mem_inst, act_mem_bank);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
         read_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,{`JTAG_UDR_MEM_DATA_REG_WDT{1'b0}},{`JTAG_UDR_MEM_DATA_REG_WDT{1'b1}});
         add_delay(4);
      end
      jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_MEM_DUMP_END;
      jtag_master_cmd_wr[137:20]                       = 118'b0;
      jtag_master_cmd_wr[19:0]                         = start_address+num_addresses-1;
      cmd.put(jtag_master_cmd_wr);
   end
   endtask
   


   task write_seed_mem (
      input string          seed_mem_file,
      input integer         num_addresses
   );
   begin
      $readmemb(seed_mem_file,seed_mem_data);
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_SEDST);
         jtag_mem_inst = set_sedst_addr(jtag_mem_inst, (mem_addr%6));
         jtag_mem_inst = set_sedst_bank(jtag_mem_inst, (mem_addr/6));
        // $display("%b",jtag_mem_inst);
         write_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,seed_mem_data[mem_addr]);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
      end

      
   end
   endtask
   

   task write_wgts_mem (
      input string          wgts_mem_file,
      input integer         num_addresses
   );
   begin
      $readmemb(wgts_mem_file,wgts_mem_data);
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_WGTST);
         jtag_mem_inst = set_wgtst_addr(jtag_mem_inst, mem_addr);
         $display("%b",jtag_mem_inst);
         write_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,wgts_mem_data[mem_addr]);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
      end

      
   end
   endtask



   task dump_wgts_mem (
      input string          wgt_mem_file,
      input integer         num_addresses,
      input integer         start_address = 0
   );
   begin
      $display ($time,": Reading Weight Memory and dumping in the mem file %s.",wgt_mem_file);
      wgt_mem_read_file = wgt_mem_file; 
      cmd.put({`JTAG_OPC_MEM_DUMP_START,132'b0,3'b000,3'b010}); 
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_WGTLD);
         jtag_mem_inst = set_wgtld_addr(jtag_mem_inst, start_address+mem_addr);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
         read_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,{`JTAG_UDR_MEM_DATA_REG_WDT{1'b0}},{`JTAG_UDR_MEM_DATA_REG_WDT{1'b1}});
         add_delay(4);
      end
      jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_MEM_DUMP_END;
      jtag_master_cmd_wr[137:20]                       = 118'b0;
      jtag_master_cmd_wr[19:0]                         = start_address+num_addresses-1;
      cmd.put(jtag_master_cmd_wr);
   end
   endtask

   task dump_out_mem (
      input string          out_mem_file,
      input integer         num_addresses,
      input logic           out_mem_bank = 1'b0,
      input integer         start_address = 0
   );
   begin
      $display ($time,": Reading Output Memory in %1b and dumping in the mem file %s.",out_mem_bank,out_mem_file);
      out_mem_read_file[out_mem_bank] = out_mem_file; 
      cmd.put({`JTAG_OPC_MEM_DUMP_START,134'b0,out_mem_bank,3'b011}); 
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst = set_dat(jtag_mem_inst, 0);
         jtag_mem_inst = set_opc(jtag_mem_inst, `JTAG_INST_OUTLD);
         jtag_mem_inst = set_outld_addr(jtag_mem_inst, start_address+mem_addr);
         jtag_mem_inst = set_outld_bank(jtag_mem_inst, out_mem_bank);
         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
         add_delay(4);
         read_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,{`JTAG_UDR_MEM_DATA_REG_WDT{1'b0}},{`JTAG_UDR_MEM_DATA_REG_WDT{1'b1}});
         add_delay(4);
      end
      jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_MEM_DUMP_END;
      jtag_master_cmd_wr[137:20]                       = 118'b0;
      jtag_master_cmd_wr[19:0]                         = start_address+num_addresses-1;
      cmd.put(jtag_master_cmd_wr);
   end
   endtask 


//   task write_wgt_mem (
//      input string          wgt_mem_file,
//      input integer         num_addresses,
//      input integer         wgt_mem_row = 0,
//      input integer         start_address = 0
//   );
//   begin
//      $display ($time,": Writing Weight Memory Row %d from the mem file %s.",wgt_mem_row,wgt_mem_file);
//      $readmemh(wgt_mem_file,wgt_mem_data_fc);
//      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
//         jtag_mem_inst[2:0]    = `JTAG_INST_WGTST;
//         jtag_mem_inst[31:3]   = start_address+mem_addr;
//         //write_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,wgt_mem_data_fc[mem_addr]<<(`ACSTC_WGT_MEM_DATA_WDT_WR*wgt_mem_row));
//		 write_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,wgt_mem_data_fc[mem_addr]);
//         write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]);
//         write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001);
//         add_delay(4);
//      end
//   end
//   endtask

   /*
   function dump_wgt_mem (
      input string          wgt_mem_file,
      input integer         num_addresses,
      input integer         wgt_mem_row = 0,
      input integer         start_address = 0
   );
   begin
      $display ($time,": Reading Weight Memory Row %d and dumping in the mem file %s.",wgt_mem_row,wgt_mem_file);
      wgt_mem_read_file[wgt_mem_row] = wgt_mem_file; 
      jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_MEM_DUMP_START;
      jtag_master_cmd_wr[137:6]                        = 132'b0;
      jtag_master_cmd_wr[5:3]                          = wgt_mem_row;
      jtag_master_cmd_wr[2:0]                          = 3'b010;
      cmd.put(jtag_master_cmd_wr);
      for (mem_addr=0;mem_addr<num_addresses;mem_addr++) begin
         jtag_mem_inst[31:28]   = `JTAG_INST_WGTLD;
         jtag_mem_inst[27:12]   = start_address+mem_addr;
         jtag_mem_inst[11]      = 1'b1;
         jtag_mem_inst[10:0]    = 11'b0;
         jtag_mem_inst[wgt_mem_row] = 1'b1;
         void'(write_jtag_udr(`JTAG_UDR_INST_REG_NUM,jtag_mem_inst[`JTAG_INST_WDT-1:0]));
         void'(write_jtag_udr(`JTAG_UDR_KICKOFF_REG_NUM,32'h00000001));
         void'(add_delay(4));
         void'(read_jtag_udr(`JTAG_UDR_MEM_DATA_REG_NUM,{`JTAG_UDR_MEM_DATA_REG_WDT{1'b0}},{`JTAG_UDR_MEM_DATA_REG_WDT{1'b1}}));
      end
      jtag_master_cmd_wr[142:138]                      = `JTAG_OPC_MEM_DUMP_END;
      jtag_master_cmd_wr[137:20]                       = 118'b0;
      jtag_master_cmd_wr[19:0]                         = start_address+num_addresses-1;
      cmd.put(jtag_master_cmd_wr);
   end
   endfunction */

endclass

