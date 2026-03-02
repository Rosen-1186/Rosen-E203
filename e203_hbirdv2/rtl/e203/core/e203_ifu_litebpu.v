 /*                                                                      
 Copyright 2018-2020 Nuclei System Technology, Inc.                
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
  Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */                                                                      
                                                                         
                                                                         
                                                                         
//=====================================================================
// Designer   : Bob Hu
//
// Description:
//  The Lite-BPU module to handle very simple branch predication at IFU
//
// ====================================================================
`include "e203_defines.v"

module e203_ifu_litebpu(

  // Current PC
  input  [`E203_PC_SIZE-1:0] pc,

  // The mini-decoded info 
  input  dec_jal,
  input  dec_jalr,
  input  dec_bxx,
  input  [`E203_XLEN-1:0] dec_bjp_imm,
  input  [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,

  // The IR index and OITF status to be used for checking dependency
  input  oitf_empty,
  input  ir_empty,
  input  ir_rs1en,
  input  jalr_rs1idx_cam_irrdidx,
  
  // The add op to next-pc adder
  output bpu_wait,  
  output prdt_taken,  
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,  
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,

  input  dec_i_valid,

  // The RS1 to read regfile
  output bpu2rf_rs1_ena,
  input  ir_valid_clr,
  input  [`E203_XLEN-1:0] rf2bpu_x1,
  input  [`E203_XLEN-1:0] rf2bpu_rs1,

  // Phase1(BHT): 来自 commit 的训练信息
  input  bht_upd_valid,
  input  [`E203_PC_SIZE-1:0] bht_upd_pc,
  input  bht_upd_taken,

  input  clk,
  input  rst_n
  );


  // BPU of E201 utilize very simple static branch prediction logics
  //   * JAL: The target address of JAL is calculated based on current PC value
  //          and offset, and JAL is unconditionally always jump
  //   * JALR with rs1 == x0: The target address of JALR is calculated based on
  //          x0+offset, and JALR is unconditionally always jump
  //   * JALR with rs1 = x1: The x1 register value is directly wired from regfile
  //          when the x1 have no dependency with ongoing instructions by checking
  //          two conditions:
  //            ** (1) The OTIF in EXU must be empty 
  //            ** (2) The instruction in IR have no x1 as destination register
  //          * If there is dependency, then hold up IFU until the dependency is cleared
  //   * JALR with rs1 != x0 or x1: The target address of JALR need to be resolved
  //          at EXU stage, hence have to be forced halted, wait the EXU to be
  //          empty and then read the regfile to grab the value of xN.
  //          This will exert 1 cycle performance lost for JALR instruction
  //   * Bxxx: Conditional branch is always predicted as taken if it is backward
  //          jump, and not-taken if it is forward jump. The target address of JAL
  //          is calculated based on current PC value and offset

  // ----------------------------------------------------------------------
  // 原项目静态预测路径（保留）:
  //   JAL/JALR 一律预测跳转；Bxx 采用“后向taken、前向not-taken”。
  // 下面的 dynamic(BHT) 逻辑会在 dec_bxx 场景替换该静态决策。
  // ----------------------------------------------------------------------
  wire static_prdt_taken = (dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN-1]));

`ifdef E203_BPU_USE_BHT
  // ----------------------------------------------------------------------
  // Phase1: 小型 BHT（2-bit 饱和计数器）
  // 功能目标：
  //   1) 在 Bxx 上使用动态预测，降低误预测率；
  //   2) 保持 JAL/JALR 语义不变，确保与原项目兼容；
  //   3) 可通过 config 宏回退到原静态策略。
  // 索引策略：默认 PC[7:2]（64项），由 E203_CFG_BHT_IDX_W 配置。
  // ----------------------------------------------------------------------
  localparam E203_BHT_IDX_MSB = (`E203_BHT_IDX_W + 1);
  reg [1:0] bht_cnt_r [0:`E203_BHT_ENTRIES-1];

  wire [`E203_BHT_IDX_W-1:0] bht_rd_idx = pc[E203_BHT_IDX_MSB:2];
  wire [`E203_BHT_IDX_W-1:0] bht_wr_idx = bht_upd_pc[E203_BHT_IDX_MSB:2];
  wire bht_prdt_taken = bht_cnt_r[bht_rd_idx][1];

  integer bht_i;
  reg [1:0] bht_wr_val;
  always @(*) begin
    bht_wr_val = bht_cnt_r[bht_wr_idx];
    if (bht_upd_taken) begin
      if (bht_cnt_r[bht_wr_idx] != 2'b11) begin
        bht_wr_val = bht_cnt_r[bht_wr_idx] + 2'b01;
      end
    end
    else begin
      if (bht_cnt_r[bht_wr_idx] != 2'b00) begin
        bht_wr_val = bht_cnt_r[bht_wr_idx] - 2'b01;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
      // 初始化为弱 not-taken(01)，避免上电后强偏置。
      for (bht_i = 0; bht_i < `E203_BHT_ENTRIES; bht_i = bht_i + 1) begin
        bht_cnt_r[bht_i] <= 2'b01;
      end
    end
    else if (bht_upd_valid) begin
      bht_cnt_r[bht_wr_idx] <= bht_wr_val;
    end
  end

  // 兼容策略：只在 Bxx 上启用 BHT；JAL/JALR 保持原行为。
  assign prdt_taken = dec_jal | dec_jalr | (dec_bxx & bht_prdt_taken);
`else
  // 回退路径：沿用原项目静态预测。
  assign prdt_taken = static_prdt_taken;
`endif
  // The JALR with rs1 == x1 have dependency or xN have dependency
  wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd0);
  wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd1);
  wire dec_jalr_rs1xn = (~dec_jalr_rs1x0) & (~dec_jalr_rs1x1);

  wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & ((~oitf_empty) | (jalr_rs1idx_cam_irrdidx));
  wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~oitf_empty) | (~ir_empty));

                      // If only depend to IR stage (OITF is empty), then if IR is under clearing, or
                          // it does not use RS1 index, then we can also treat it as non-dependency
  wire jalr_rs1xn_dep_ir_clr = (jalr_rs1xn_dep & oitf_empty & (~ir_empty)) & (ir_valid_clr | (~ir_rs1en));

  wire rs1xn_rdrf_r;
  wire rs1xn_rdrf_set = (~rs1xn_rdrf_r) & dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~jalr_rs1xn_dep) | jalr_rs1xn_dep_ir_clr);
  wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
  wire rs1xn_rdrf_ena = rs1xn_rdrf_set |   rs1xn_rdrf_clr;
  wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | (~rs1xn_rdrf_clr);

  sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena, rs1xn_rdrf_nxt, rs1xn_rdrf_r, clk, rst_n);

  assign bpu2rf_rs1_ena = rs1xn_rdrf_set;

  assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;

  assign prdt_pc_add_op1 = (dec_bxx | dec_jal) ? pc[`E203_PC_SIZE-1:0]
                         : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'b0
                         : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
                         : rf2bpu_rs1[`E203_PC_SIZE-1:0];  

  assign prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];  

endmodule
