//
// Copyright 2020 OpenHW Group
// Copyright 2020 Datum Technology Corporation
// Copyright 2020 Silicon Labs, Inc.
// 
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     https://solderpad.org/licenses/
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
///////////////////////////////////////////////////////////////////////////////
//
// Modified version of the wrapper for a RI5CY testbench, containing RI5CY,
// plus Memory and stdout virtual peripherals.
// Contributor: Robert Balas <balasr@student.ethz.ch>
// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//


`ifndef __UVMT_CV32E40P_DUT_WRAP_SV__
`define __UVMT_CV32E40P_DUT_WRAP_SV__


/**
 * Module wrapper for CV32E40P RTL DUT.
 */
module uvmt_cv32e40p_dut_wrap 
  #(
                            // CV32E40P parameters.  See User Manual.
                            parameter PULP_XPULP          =  0,
                                      PULP_CLUSTER        =  0,
                                      FPU                 =  0,
                                      FPU_ADDMUL_LAT      =  0,
                                      FPU_OTHERS_LAT      =  0,
                                      ZFINX               =  0,
                                      NUM_MHPMCOUNTERS    =  1,
                            // Remaining parameters are used by TB components only
                                      INSTR_ADDR_WIDTH    =  32,
                                      INSTR_RDATA_WIDTH   =  32,
                                      RAM_ADDR_WIDTH      =  22
   )
  (
    uvma_clknrst_if              clknrst_if,
    uvma_interrupt_if            interrupt_if,    // Interrupts sourced by both UVM Agent and Virtual Peripherals
    //uvma_interrupt_if            agt_interrupt_if,    // Interrupts sourced by UVM Agent
    //uvma_interrupt_if            vp_interrupt_if,     // Interrupts sourced by Virtual Peripherals
    uvme_cv32e40p_core_cntrl_if  core_cntrl_if,
    uvmt_cv32e40p_core_status_if core_status_if,
    uvma_obi_memory_if           obi_memory_instr_if, // Instruction fetch bus
    uvma_obi_memory_if           obi_memory_data_if   // Load/Store bus
  );

    import uvm_pkg::*; // needed for the UVM messaging service (`uvm_info(), etc.)

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [INSTR_ADDR_WIDTH-1 :0] instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    logic [31:0]                  irq_vp;
    logic [31:0]                  irq_agt;
    logic [31:0]                  irq;
    logic                         irq_ack;
    logic [ 4:0]                  irq_id;

    logic                         debug_req_vp;
    logic                         debug_req_uvma;
    logic                         debug_req;
    logic                         debug_havereset;
    logic                         debug_running;
    logic                         debug_halted;

    assign debug_if.clk      = clknrst_if.clk;
    assign debug_if.reset_n  = clknrst_if.reset_n;
    assign debug_req_uvma    = debug_if.debug_req;

    assign debug_req = debug_req_vp | debug_req_uvma;

        

    // --------------------------------------------
    // Instruction bus is read-only, OBI v1.0
    assign obi_memory_instr_if.we        = 'b0;
    assign obi_memory_instr_if.be        = '1;
    // Data bus is read/write, OBI v1.0

    // --------------------------------------------
    // Connect to interrupt interfaces
    assign interrupt_if.clk     = clknrst_if.clk;
    assign interrupt_if.reset_n = clknrst_if.reset_n;
    assign interrupt_if.irq_id  = irq_id;
    assign interrupt_if.irq_ack = irq_ack;
    //assign agt_interrupt_if.clk     = clknrst_if.clk;
    //assign agt_interrupt_if.reset_n = clknrst_if.reset_n;
    //assign agt_interrupt_if.irq_id  = irq_id;
    //assign agt_interrupt_if.irq_ack = irq_ack;
    //assign vp_interrupt_if.clk      = clknrst_if.clk;
    //assign vp_interrupt_if.reset_n  = clknrst_if.reset_n;
    //assign vp_interrupt_if.irq_id   = irq_id;
    //assign vp_interrupt_if.irq_ack  = irq_ack;

    //assign irq_vp  = vp_interrupt_if.irq;
    //assign irq_agt = agt_interrupt_if.irq;
    //always @(irq_vp)  $display("%m: @%0t; irq_vp  = %8x", $time, irq_vp);
    //always @(irq_agt) $display("%m: @%0t; irq_agt = %8x", $time, irq_agt);

    assign irq = interrupt_if.irq_drv;
    always @(irq) $display("%m: @%0t; irq = %8x", $time, irq);

    // -------------------------------------------------------------
    // Instantiate the Core and optional FPU plus logger and tracers
    cv32e40p_tb_wrapper #(
                 .PULP_XPULP       (PULP_XPULP),
                 .PULP_CLUSTER     (PULP_CLUSTER),
                 .FPU              (FPU),
                 .FPU_ADDMUL_LAT   (FPU_ADDMUL_LAT),
                 .FPU_OTHERS_LAT   (FPU_OTHERS_LAT),
                 .ZFINX            (ZFINX),
                 .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS)
                )
    cv32e40p_tb_wrapper_i
        (
         .clk_i                  ( clknrst_if.clk                 ),
         .rst_ni                 ( clknrst_if.reset_n             ),

         .pulp_clock_en_i        ( '0),//core_cntrl_if.pulp_clock_en    ),
         .scan_cg_en_i           ( core_cntrl_if.scan_cg_en       ),

         .boot_addr_i            ( core_cntrl_if.boot_addr        ),
         .mtvec_addr_i           ( core_cntrl_if.mtvec_addr       ),
         .dm_halt_addr_i         ( core_cntrl_if.dm_halt_addr     ),
         .hart_id_i              ( core_cntrl_if.mhartid          ),
         .dm_exception_addr_i    ( core_cntrl_if.dm_exception_addr),

         .instr_req_o            ( obi_memory_instr_if.req        ), // core to agent
         .instr_gnt_i            ( obi_memory_instr_if.gnt        ), // agent to core
         .instr_rvalid_i         ( obi_memory_instr_if.rvalid     ),
         .instr_addr_o           ( obi_memory_instr_if.addr       ),
         .instr_rdata_i          ( obi_memory_instr_if.rdata      ),

         .data_req_o             ( obi_memory_data_if.req         ),
         .data_gnt_i             ( obi_memory_data_if.gnt         ),
         .data_rvalid_i          ( obi_memory_data_if.rvalid      ),
         .data_we_o              ( obi_memory_data_if.we          ),
         .data_be_o              ( obi_memory_data_if.be          ),
         .data_addr_o            ( obi_memory_data_if.addr        ),
         .data_wdata_o           ( obi_memory_data_if.wdata       ),
         .data_rdata_i           ( obi_memory_data_if.rdata       ),

         .irq_i                  ( irq                            ),
         .irq_ack_o              ( irq_ack                        ),
         .irq_id_o               ( irq_id                         ),

         .debug_req_i            ( debug_req_uvma                 ),
         .debug_havereset_o      ( debug_havereset                ),
         .debug_running_o        ( debug_running                  ),
         .debug_halted_o         ( debug_halted                   ),

         .fetch_enable_i         ( core_cntrl_if.fetch_en         ),
         .core_sleep_o           ( core_status_if.core_busy       )
        ); // cv32e40p_tb_wrapper_i


endmodule : uvmt_cv32e40p_dut_wrap

`endif // __UVMT_CV32E40P_DUT_WRAP_SV__


