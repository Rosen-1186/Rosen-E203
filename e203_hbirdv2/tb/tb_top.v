
`include "e203_defines.v"

module tb_top();

  reg  clk;
  reg  lfextclk;
  reg  rst_n;

  wire hfclk = clk;

  `define CPU_TOP u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.u_e203_cpu_top
  `define EXU `CPU_TOP.u_e203_cpu.u_e203_core.u_e203_exu
  `define EXU_DISP `EXU.u_e203_exu_disp
  `define EXU_ALU `EXU.u_e203_exu_alu
  `define EXU_MDV `EXU_ALU.u_e203_exu_alu_muldiv
  `define IFU_IFTCH `CPU_TOP.u_e203_cpu.u_e203_core.u_e203_ifu.u_e203_ifu_ifetch
  `define LSU_CTRL `CPU_TOP.u_e203_cpu.u_e203_core.u_e203_lsu.u_e203_lsu_ctrl
  `define BRCHSLV `EXU.u_e203_exu_commit.u_e203_exu_branchslv
  `define ITCM `CPU_TOP.u_e203_srams.u_e203_itcm_ram.u_e203_itcm_gnrl_ram.u_sirv_sim_ram

  `define PC_WRITE_TOHOST       `E203_PC_SIZE'h80000086
  `define PC_EXT_IRQ_BEFOR_MRET `E203_PC_SIZE'h800000a6
  `define PC_SFT_IRQ_BEFOR_MRET `E203_PC_SIZE'h800000be
  `define PC_TMR_IRQ_BEFOR_MRET `E203_PC_SIZE'h800000d6
  `define PC_AFTER_SETMTVEC     `E203_PC_SIZE'h8000015C

  wire [`E203_XLEN-1:0] x3 = `EXU.u_e203_exu_regfile.rf_r[3];
  wire [`E203_PC_SIZE-1:0] pc = `EXU.u_e203_exu_commit.alu_cmt_i_pc;
  wire [`E203_PC_SIZE-1:0] pc_vld = `EXU.u_e203_exu_commit.alu_cmt_i_valid;

  reg [31:0] pc_write_to_host_cnt;
  reg [31:0] pc_write_to_host_cycle;
  reg [31:0] valid_ir_cycle;
  reg [31:0] cycle_count;
  reg [31:0] branch_total;
  reg [31:0] branch_mispredict;
  reg [31:0] ifu_wait_cycle;
  reg [31:0] ifu_flush_cycle;
  reg [31:0] lsu_wait_cycle;
  reg [31:0] ifu_req_block_cycle;
  reg [31:0] ifu_rsp_block_cycle;
  reg [31:0] ir_busy_cycle;
  reg [31:0] disp_block_dep_cycle;
  reg [31:0] disp_block_raw_dep_cycle;
  reg [31:0] disp_block_waw_dep_cycle;
  reg [31:0] disp_block_dep_raw_only_cycle;
  reg [31:0] disp_block_dep_waw_only_cycle;
  reg [31:0] disp_block_dep_raw_waw_cycle;
  reg [31:0] disp_dep_cons_alu_cycle;
  reg [31:0] disp_dep_cons_agu_cycle;
  reg [31:0] disp_dep_cons_bjp_cycle;
  reg [31:0] disp_dep_cons_csr_cycle;
  reg [31:0] disp_dep_cons_muldiv_cycle;
  reg [31:0] disp_dep_cons_unknown_cycle;
  reg [31:0] disp_dep_when_longp_prdt_cycle;
  reg [31:0] disp_dep_raw_rs1en_cycle;
  reg [31:0] disp_dep_raw_rs2en_cycle;
  reg [31:0] disp_dep_raw_rs1rs2en_cycle;
  reg [31:0] disp_dep_raw_rdwen_cycle;
  reg [31:0] disp_block_raw_rs1_cycle;
  reg [31:0] disp_block_raw_rs2_cycle;
  reg [31:0] disp_block_raw_rs3_cycle;
  reg [31:0] disp_block_raw_single_src_cycle;
  reg [31:0] disp_block_raw_multi_src_cycle;
  reg [31:0] disp_block_raw_rs12_cycle;
  reg [31:0] disp_block_raw_rs13_cycle;
  reg [31:0] disp_block_raw_rs23_cycle;
  reg [31:0] disp_block_raw_rs123_cycle;
  reg [31:0] disp_block_oitf_cycle;
  reg [31:0] disp_block_csrfence_cycle;
  reg [31:0] disp_block_wfi_cycle;
  reg [31:0] disp_block_other_cycle;
  reg [31:0] disp_other_readypos_low_cycle;
  reg [31:0] disp_other_readypos_high_cycle;
  reg [31:0] disp_other_alu_notready_cycle;
  reg [31:0] disp_other_agu_notready_cycle;
  reg [31:0] disp_other_bjp_notready_cycle;
  reg [31:0] disp_other_csr_notready_cycle;
  reg [31:0] disp_other_ifu_excp_notready_cycle;
  reg [31:0] disp_other_mdv_notready_cycle;
  reg [31:0] disp_other_nice_notready_cycle;
  reg [31:0] disp_other_ready_unknown_cycle;
  reg [31:0] mdv_block_total_cycle;
  reg [31:0] mdv_block_not_wbck_condi_cycle;
  reg [31:0] mdv_block_wait_o_ready_cycle;
  reg [31:0] mdv_block_wait_cmt_ready_cycle;
  reg [31:0] mdv_block_wait_wbck_ready_cycle;
  reg [31:0] mdv_block_wait_ready_unknown_cycle;
  reg [31:0] mdv_block_sta_0th_cycle;
  reg [31:0] mdv_block_sta_exec_cycle;
  reg [31:0] mdv_block_sta_remd_chck_cycle;
  reg [31:0] mdv_block_sta_quot_corr_cycle;
  reg [31:0] mdv_block_sta_remd_corr_cycle;
  reg [31:0] mdv_block_sta_unknown_cycle;
  reg [31:0] mdv_block_exec_not_last_cycle;
  reg [31:0] mdv_block_exec_last_cycle;
  reg [31:0] mdv_block_remd_chck_need_corr_cycle;
  reg [31:0] mdv_block_remd_chck_no_corr_cycle;
  reg [31:0] mdv_block_b2b_or_special_cycle;
  reg [31:0] mdv_req_mul_cycle;
  reg [31:0] mdv_req_div_cycle;
  reg [31:0] mdv_req_rem_cycle;
  reg [31:0] mdv_req_divu_cycle;
  reg [31:0] mdv_req_remu_cycle;
  reg [31:0] mdv_req_mulh_family_cycle;
  reg [31:0] mdv_issue_total_cnt;
  reg [31:0] mdv_issue_mul_cnt;
  reg [31:0] mdv_issue_div_cnt;
  reg [31:0] mdv_issue_rem_cnt;
  reg [31:0] mdv_issue_divu_cnt;
  reg [31:0] mdv_issue_remu_cnt;
  reg [31:0] mdv_issue_mulh_family_cnt;
  reg [31:0] mdv_complete_total_cnt;
  reg [31:0] mdv_complete_mul_cnt;
  reg [31:0] mdv_complete_div_cnt;
  reg [31:0] mdv_complete_rem_cnt;
  reg [31:0] mdv_block_mul_cycle;
  reg [31:0] mdv_block_div_cycle;
  reg [31:0] mdv_block_rem_cycle;
  reg [31:0] mdv_block_divu_cycle;
  reg [31:0] mdv_block_remu_cycle;
  reg [31:0] mdv_block_mulh_family_cycle;
  reg [31:0] same_pc_streak;
  reg [`E203_PC_SIZE-1:0] last_commit_pc;
  reg auto_finish_by_stuck_pc;
  reg pc_write_to_host_flag;

  wire brch_cmt_valid = `BRCHSLV.cmt_i_valid;
  wire brch_is_bxx = `BRCHSLV.cmt_i_bjp;
  wire brch_prdt_taken = `BRCHSLV.cmt_i_bjp_prdt;
  wire brch_real_taken = `BRCHSLV.cmt_i_bjp_rslv;

  wire ifu_bpu_wait = `IFU_IFTCH.bpu_wait;
  wire ifu_pipe_flush_req = `IFU_IFTCH.pipe_flush_req_real;
  wire ifu_req_block = `IFU_IFTCH.ifu_req_valid & (~`IFU_IFTCH.ifu_req_ready);
  wire ifu_rsp_block = `IFU_IFTCH.ifu_rsp_valid & (~`IFU_IFTCH.ifu_rsp_ready);
  wire ifu_ir_busy = `IFU_IFTCH.ifu_o_valid & (~`IFU_IFTCH.ifu_o_ready);

  wire disp_i_block = `EXU_DISP.disp_i_valid & (~`EXU_DISP.disp_i_ready);
  wire disp_block_dep = `EXU_DISP.dep;
  wire [`E203_DECINFO_GRP_WIDTH-1:0] disp_grp = `EXU_DISP.disp_i_info_grp;
  wire disp_block_raw_dep = disp_i_block & `EXU_DISP.raw_dep;
  wire disp_block_waw_dep = disp_i_block & `EXU_DISP.waw_dep;
  wire disp_dep_raw_only = disp_block_raw_dep & (~disp_block_waw_dep);
  wire disp_dep_waw_only = disp_block_waw_dep & (~disp_block_raw_dep);
  wire disp_dep_raw_waw = disp_block_raw_dep & disp_block_waw_dep;
  wire disp_dep_cons_alu = disp_i_block & disp_block_dep & (disp_grp == `E203_DECINFO_GRP_ALU);
  wire disp_dep_cons_agu = disp_i_block & disp_block_dep & (disp_grp == `E203_DECINFO_GRP_AGU);
  wire disp_dep_cons_bjp = disp_i_block & disp_block_dep & (disp_grp == `E203_DECINFO_GRP_BJP);
  wire disp_dep_cons_csr = disp_i_block & disp_block_dep & (disp_grp == `E203_DECINFO_GRP_CSR);
`ifdef E203_SUPPORT_SHARE_MULDIV
  wire disp_dep_cons_muldiv = disp_i_block & disp_block_dep & (disp_grp == `E203_DECINFO_GRP_MULDIV);
`else
  wire disp_dep_cons_muldiv = 1'b0;
`endif
  wire disp_dep_cons_unknown = disp_i_block & disp_block_dep
                             & (~disp_dep_cons_alu)
                             & (~disp_dep_cons_agu)
                             & (~disp_dep_cons_bjp)
                             & (~disp_dep_cons_csr)
                             & (~disp_dep_cons_muldiv);
  wire disp_dep_when_longp_prdt = disp_i_block & disp_block_dep & `EXU_DISP.disp_alu_longp_prdt;

  wire disp_dep_raw_rs1en = disp_block_raw_dep & `EXU_DISP.disp_i_rs1en;
  wire disp_dep_raw_rs2en = disp_block_raw_dep & `EXU_DISP.disp_i_rs2en;
  wire disp_dep_raw_rs1rs2en = disp_block_raw_dep & `EXU_DISP.disp_i_rs1en & `EXU_DISP.disp_i_rs2en;
  wire disp_dep_raw_rdwen = disp_block_raw_dep & `EXU_DISP.disp_i_rdwen;

  wire disp_raw_match_rs1 = `EXU_DISP.oitfrd_match_disprs1;
  wire disp_raw_match_rs2 = `EXU_DISP.oitfrd_match_disprs2;
  wire disp_raw_match_rs3 = `EXU_DISP.oitfrd_match_disprs3;
  wire disp_raw_match_one = disp_raw_match_rs1 ^ disp_raw_match_rs2 ^ disp_raw_match_rs3;
  wire disp_raw_match_two = (disp_raw_match_rs1 & disp_raw_match_rs2 & (~disp_raw_match_rs3))
                          | (disp_raw_match_rs1 & disp_raw_match_rs3 & (~disp_raw_match_rs2))
                          | (disp_raw_match_rs2 & disp_raw_match_rs3 & (~disp_raw_match_rs1));
  wire disp_raw_match_three = disp_raw_match_rs1 & disp_raw_match_rs2 & disp_raw_match_rs3;

  wire disp_raw_match_rs12 = disp_raw_match_rs1 & disp_raw_match_rs2 & (~disp_raw_match_rs3);
  wire disp_raw_match_rs13 = disp_raw_match_rs1 & disp_raw_match_rs3 & (~disp_raw_match_rs2);
  wire disp_raw_match_rs23 = disp_raw_match_rs2 & disp_raw_match_rs3 & (~disp_raw_match_rs1);
  wire disp_block_csrfence = (`EXU_DISP.disp_csr | `EXU_DISP.disp_fence_fencei) & (~`EXU_DISP.oitf_empty);
  wire disp_block_wfi = `EXU_DISP.wfi_halt_exu_req;
  wire disp_block_oitf = `EXU_DISP.disp_alu_longp_prdt & (~`EXU_DISP.disp_oitf_ready);
  wire disp_block_other = disp_i_block & (~disp_block_dep) & (~disp_block_csrfence) & (~disp_block_wfi) & (~disp_block_oitf);

  wire disp_other_readypos_low = disp_block_other & (~`EXU_DISP.disp_i_ready_pos);
  wire disp_other_readypos_high = disp_block_other & `EXU_DISP.disp_i_ready_pos;

  wire disp_other_alu_notready = disp_other_readypos_low & `EXU_ALU.alu_op & (~`EXU_ALU.alu_i_ready);
  wire disp_other_agu_notready = disp_other_readypos_low & `EXU_ALU.agu_op & (~`EXU_ALU.agu_i_ready);
  wire disp_other_bjp_notready = disp_other_readypos_low & `EXU_ALU.bjp_op & (~`EXU_ALU.bjp_i_ready);
  wire disp_other_csr_notready = disp_other_readypos_low & `EXU_ALU.csr_op & (~`EXU_ALU.csr_i_ready);
  wire disp_other_ifu_excp_notready = disp_other_readypos_low & `EXU_ALU.ifu_excp_op & (~`EXU_ALU.ifu_excp_i_ready);
`ifdef E203_SUPPORT_SHARE_MULDIV
  wire disp_other_mdv_notready = disp_other_readypos_low & `EXU_ALU.mdv_op & (~`EXU_ALU.mdv_i_ready);
`else
  wire disp_other_mdv_notready = 1'b0;
`endif
`ifdef E203_HAS_NICE
  wire disp_other_nice_notready = disp_other_readypos_low & `EXU_ALU.nice_op & (~`EXU_ALU.nice_i_ready);
`else
  wire disp_other_nice_notready = 1'b0;
`endif
  wire disp_other_ready_unknown = disp_other_readypos_low
                                  & (~disp_other_alu_notready)
                                  & (~disp_other_agu_notready)
                                  & (~disp_other_bjp_notready)
                                  & (~disp_other_csr_notready)
                                  & (~disp_other_ifu_excp_notready)
                                  & (~disp_other_mdv_notready)
                                  & (~disp_other_nice_notready);

  wire mdv_block = `EXU_ALU.mdv_i_valid & (~`EXU_ALU.mdv_i_ready);
  wire mdv_block_not_wbck_condi = mdv_block & (~`EXU_MDV.wbck_condi);
  wire mdv_block_wait_o_ready = mdv_block & `EXU_MDV.wbck_condi & (~`EXU_ALU.mdv_o_ready);
  wire mdv_block_wait_cmt_ready = mdv_block_wait_o_ready & (~`EXU_ALU.cmt_o_ready);
  wire mdv_block_wait_wbck_ready = mdv_block_wait_o_ready & `EXU_ALU.cmt_o_ready & (~`EXU_ALU.wbck_o_ready);
  wire mdv_block_wait_ready_unknown = mdv_block_wait_o_ready & `EXU_ALU.cmt_o_ready & `EXU_ALU.wbck_o_ready;
  wire mdv_block_sta_0th = mdv_block_not_wbck_condi & `EXU_MDV.muldiv_sta_is_0th;
  wire mdv_block_sta_exec = mdv_block_not_wbck_condi & `EXU_MDV.muldiv_sta_is_exec;
  wire mdv_block_sta_remd_chck = mdv_block_not_wbck_condi & `EXU_MDV.muldiv_sta_is_remd_chck;
  wire mdv_block_sta_quot_corr = mdv_block_not_wbck_condi & `EXU_MDV.muldiv_sta_is_quot_corr;
  wire mdv_block_sta_remd_corr = mdv_block_not_wbck_condi & `EXU_MDV.muldiv_sta_is_remd_corr;
  wire mdv_block_sta_unknown = mdv_block_not_wbck_condi
                               & (~`EXU_MDV.muldiv_sta_is_0th)
                               & (~`EXU_MDV.muldiv_sta_is_exec)
                               & (~`EXU_MDV.muldiv_sta_is_remd_chck)
                               & (~`EXU_MDV.muldiv_sta_is_quot_corr)
                               & (~`EXU_MDV.muldiv_sta_is_remd_corr);
  wire mdv_block_exec_not_last = mdv_block_sta_exec & (~`EXU_MDV.exec_last_cycle);
  wire mdv_block_exec_last = mdv_block_sta_exec & `EXU_MDV.exec_last_cycle;
  wire mdv_block_remd_chck_need_corr = mdv_block_sta_remd_chck & `EXU_MDV.div_need_corrct;
  wire mdv_block_remd_chck_no_corr = mdv_block_sta_remd_chck & (~`EXU_MDV.div_need_corrct);
  wire mdv_block_b2b_or_special = mdv_block & (`EXU_MDV.back2back_seq | `EXU_MDV.special_cases);

  wire mdv_req_mul = `EXU_ALU.mdv_i_valid & `EXU_MDV.i_op_mul;
  wire mdv_req_div = `EXU_ALU.mdv_i_valid & (`EXU_MDV.i_div | `EXU_MDV.i_divu);
  wire mdv_req_rem = `EXU_ALU.mdv_i_valid & (`EXU_MDV.i_rem | `EXU_MDV.i_remu);
  wire mdv_req_divu = `EXU_ALU.mdv_i_valid & `EXU_MDV.i_divu;
  wire mdv_req_remu = `EXU_ALU.mdv_i_valid & `EXU_MDV.i_remu;
  wire mdv_req_mulh_family = `EXU_ALU.mdv_i_valid & (`EXU_MDV.i_mulh | `EXU_MDV.i_mulhsu | `EXU_MDV.i_mulhu);

  wire mdv_issue_hsked = `EXU_MDV.muldiv_i_hsked;
  wire mdv_issue_mul = mdv_issue_hsked & `EXU_MDV.i_op_mul;
  wire mdv_issue_div = mdv_issue_hsked & (`EXU_MDV.i_div | `EXU_MDV.i_divu);
  wire mdv_issue_rem = mdv_issue_hsked & (`EXU_MDV.i_rem | `EXU_MDV.i_remu);
  wire mdv_issue_divu = mdv_issue_hsked & `EXU_MDV.i_divu;
  wire mdv_issue_remu = mdv_issue_hsked & `EXU_MDV.i_remu;
  wire mdv_issue_mulh_family = mdv_issue_hsked & (`EXU_MDV.i_mulh | `EXU_MDV.i_mulhsu | `EXU_MDV.i_mulhu);

  wire mdv_complete_hsked = `EXU_MDV.muldiv_o_hsked;
  wire mdv_complete_mul = mdv_complete_hsked & `EXU_MDV.i_op_mul;
  wire mdv_complete_div = mdv_complete_hsked & (`EXU_MDV.i_div | `EXU_MDV.i_divu);
  wire mdv_complete_rem = mdv_complete_hsked & (`EXU_MDV.i_rem | `EXU_MDV.i_remu);

  wire mdv_block_mul = mdv_block & `EXU_MDV.i_op_mul;
  wire mdv_block_div = mdv_block & (`EXU_MDV.i_div | `EXU_MDV.i_divu);
  wire mdv_block_rem = mdv_block & (`EXU_MDV.i_rem | `EXU_MDV.i_remu);
  wire mdv_block_divu = mdv_block & `EXU_MDV.i_divu;
  wire mdv_block_remu = mdv_block & `EXU_MDV.i_remu;
  wire mdv_block_mulh_family = mdv_block & (`EXU_MDV.i_mulh | `EXU_MDV.i_mulhsu | `EXU_MDV.i_mulhu);

  wire lsu_cmd_wait = `LSU_CTRL.agu_icb_cmd_valid & (~`LSU_CTRL.agu_icb_cmd_ready);

  // CoreMark 等场景可能不走 tohost 退出路径，这里增加保守的自动结束条件
  // 当 commit PC 长时间保持不变时，认为程序进入尾部自旋，触发 summary 输出。
  localparam [31:0] SAME_PC_AUTO_FINISH_TH = 32'd50000;

  always @(posedge hfclk or negedge rst_n)
  begin 
    if(rst_n == 1'b0) begin
        pc_write_to_host_cnt <= 32'b0;
        pc_write_to_host_flag <= 1'b0;
        pc_write_to_host_cycle <= 32'b0;
    end
    else if (pc_vld & (pc == `PC_WRITE_TOHOST)) begin
        pc_write_to_host_cnt <= pc_write_to_host_cnt + 1'b1;
        pc_write_to_host_flag <= 1'b1;
        if (pc_write_to_host_flag == 1'b0) begin
            pc_write_to_host_cycle <= cycle_count;
        end
    end
  end

  always @(posedge hfclk or negedge rst_n)
  begin 
    if(rst_n == 1'b0) begin
        cycle_count <= 32'b0;
    end
    else begin
        cycle_count <= cycle_count + 1'b1;
    end
  end

  wire i_valid = `EXU.i_valid;
  wire i_ready = `EXU.i_ready;

  always @(posedge hfclk or negedge rst_n)
  begin 
    if(rst_n == 1'b0) begin
        valid_ir_cycle <= 32'b0;
    end
    else if(i_valid & i_ready & (pc_write_to_host_flag == 1'b0)) begin
        valid_ir_cycle <= valid_ir_cycle + 1'b1;
    end
  end

  always @(posedge hfclk or negedge rst_n)
  begin
    if(rst_n == 1'b0) begin
      branch_total <= 32'b0;
      branch_mispredict <= 32'b0;
      ifu_wait_cycle <= 32'b0;
      ifu_flush_cycle <= 32'b0;
      lsu_wait_cycle <= 32'b0;
      ifu_req_block_cycle <= 32'b0;
      ifu_rsp_block_cycle <= 32'b0;
      ir_busy_cycle <= 32'b0;
      disp_block_dep_cycle <= 32'b0;
      disp_block_raw_dep_cycle <= 32'b0;
      disp_block_waw_dep_cycle <= 32'b0;
      disp_block_dep_raw_only_cycle <= 32'b0;
      disp_block_dep_waw_only_cycle <= 32'b0;
      disp_block_dep_raw_waw_cycle <= 32'b0;
      disp_dep_cons_alu_cycle <= 32'b0;
      disp_dep_cons_agu_cycle <= 32'b0;
      disp_dep_cons_bjp_cycle <= 32'b0;
      disp_dep_cons_csr_cycle <= 32'b0;
      disp_dep_cons_muldiv_cycle <= 32'b0;
      disp_dep_cons_unknown_cycle <= 32'b0;
      disp_dep_when_longp_prdt_cycle <= 32'b0;
      disp_dep_raw_rs1en_cycle <= 32'b0;
      disp_dep_raw_rs2en_cycle <= 32'b0;
      disp_dep_raw_rs1rs2en_cycle <= 32'b0;
      disp_dep_raw_rdwen_cycle <= 32'b0;
      disp_block_raw_rs1_cycle <= 32'b0;
      disp_block_raw_rs2_cycle <= 32'b0;
      disp_block_raw_rs3_cycle <= 32'b0;
      disp_block_raw_single_src_cycle <= 32'b0;
      disp_block_raw_multi_src_cycle <= 32'b0;
      disp_block_raw_rs12_cycle <= 32'b0;
      disp_block_raw_rs13_cycle <= 32'b0;
      disp_block_raw_rs23_cycle <= 32'b0;
      disp_block_raw_rs123_cycle <= 32'b0;
      disp_block_oitf_cycle <= 32'b0;
      disp_block_csrfence_cycle <= 32'b0;
      disp_block_wfi_cycle <= 32'b0;
      disp_block_other_cycle <= 32'b0;
      disp_other_readypos_low_cycle <= 32'b0;
      disp_other_readypos_high_cycle <= 32'b0;
      disp_other_alu_notready_cycle <= 32'b0;
      disp_other_agu_notready_cycle <= 32'b0;
      disp_other_bjp_notready_cycle <= 32'b0;
      disp_other_csr_notready_cycle <= 32'b0;
      disp_other_ifu_excp_notready_cycle <= 32'b0;
      disp_other_mdv_notready_cycle <= 32'b0;
      disp_other_nice_notready_cycle <= 32'b0;
      disp_other_ready_unknown_cycle <= 32'b0;
      mdv_block_total_cycle <= 32'b0;
      mdv_block_not_wbck_condi_cycle <= 32'b0;
      mdv_block_wait_o_ready_cycle <= 32'b0;
      mdv_block_wait_cmt_ready_cycle <= 32'b0;
      mdv_block_wait_wbck_ready_cycle <= 32'b0;
      mdv_block_wait_ready_unknown_cycle <= 32'b0;
      mdv_block_sta_0th_cycle <= 32'b0;
      mdv_block_sta_exec_cycle <= 32'b0;
      mdv_block_sta_remd_chck_cycle <= 32'b0;
      mdv_block_sta_quot_corr_cycle <= 32'b0;
      mdv_block_sta_remd_corr_cycle <= 32'b0;
      mdv_block_sta_unknown_cycle <= 32'b0;
      mdv_block_exec_not_last_cycle <= 32'b0;
      mdv_block_exec_last_cycle <= 32'b0;
      mdv_block_remd_chck_need_corr_cycle <= 32'b0;
      mdv_block_remd_chck_no_corr_cycle <= 32'b0;
      mdv_block_b2b_or_special_cycle <= 32'b0;
      mdv_req_mul_cycle <= 32'b0;
      mdv_req_div_cycle <= 32'b0;
      mdv_req_rem_cycle <= 32'b0;
      mdv_req_divu_cycle <= 32'b0;
      mdv_req_remu_cycle <= 32'b0;
      mdv_req_mulh_family_cycle <= 32'b0;
      mdv_issue_total_cnt <= 32'b0;
      mdv_issue_mul_cnt <= 32'b0;
      mdv_issue_div_cnt <= 32'b0;
      mdv_issue_rem_cnt <= 32'b0;
      mdv_issue_divu_cnt <= 32'b0;
      mdv_issue_remu_cnt <= 32'b0;
      mdv_issue_mulh_family_cnt <= 32'b0;
      mdv_complete_total_cnt <= 32'b0;
      mdv_complete_mul_cnt <= 32'b0;
      mdv_complete_div_cnt <= 32'b0;
      mdv_complete_rem_cnt <= 32'b0;
      mdv_block_mul_cycle <= 32'b0;
      mdv_block_div_cycle <= 32'b0;
      mdv_block_rem_cycle <= 32'b0;
      mdv_block_divu_cycle <= 32'b0;
      mdv_block_remu_cycle <= 32'b0;
      mdv_block_mulh_family_cycle <= 32'b0;
    end
    else if (pc_write_to_host_flag == 1'b0) begin
      if (brch_cmt_valid & brch_is_bxx) begin
        branch_total <= branch_total + 1'b1;
        if (brch_prdt_taken ^ brch_real_taken) begin
          branch_mispredict <= branch_mispredict + 1'b1;
        end
      end

      if (ifu_bpu_wait) begin
        ifu_wait_cycle <= ifu_wait_cycle + 1'b1;
      end

      if (ifu_pipe_flush_req) begin
        ifu_flush_cycle <= ifu_flush_cycle + 1'b1;
      end

      if (lsu_cmd_wait) begin
        lsu_wait_cycle <= lsu_wait_cycle + 1'b1;
      end

      if (ifu_req_block) begin
        ifu_req_block_cycle <= ifu_req_block_cycle + 1'b1;
      end

      if (ifu_rsp_block) begin
        ifu_rsp_block_cycle <= ifu_rsp_block_cycle + 1'b1;
      end

      if (ifu_ir_busy) begin
        ir_busy_cycle <= ir_busy_cycle + 1'b1;
      end

      if (disp_i_block) begin
        if (disp_block_dep) begin
          disp_block_dep_cycle <= disp_block_dep_cycle + 1'b1;

          if (disp_block_raw_dep) begin
            disp_block_raw_dep_cycle <= disp_block_raw_dep_cycle + 1'b1;

            if (disp_dep_raw_rs1en) begin
              disp_dep_raw_rs1en_cycle <= disp_dep_raw_rs1en_cycle + 1'b1;
            end
            if (disp_dep_raw_rs2en) begin
              disp_dep_raw_rs2en_cycle <= disp_dep_raw_rs2en_cycle + 1'b1;
            end
            if (disp_dep_raw_rs1rs2en) begin
              disp_dep_raw_rs1rs2en_cycle <= disp_dep_raw_rs1rs2en_cycle + 1'b1;
            end
            if (disp_dep_raw_rdwen) begin
              disp_dep_raw_rdwen_cycle <= disp_dep_raw_rdwen_cycle + 1'b1;
            end

            if (disp_raw_match_rs1) begin
              disp_block_raw_rs1_cycle <= disp_block_raw_rs1_cycle + 1'b1;
            end
            if (disp_raw_match_rs2) begin
              disp_block_raw_rs2_cycle <= disp_block_raw_rs2_cycle + 1'b1;
            end
            if (disp_raw_match_rs3) begin
              disp_block_raw_rs3_cycle <= disp_block_raw_rs3_cycle + 1'b1;
            end

            if (disp_raw_match_one) begin
              disp_block_raw_single_src_cycle <= disp_block_raw_single_src_cycle + 1'b1;
            end
            if (disp_raw_match_two | disp_raw_match_three) begin
              disp_block_raw_multi_src_cycle <= disp_block_raw_multi_src_cycle + 1'b1;
            end

            if (disp_raw_match_rs12) begin
              disp_block_raw_rs12_cycle <= disp_block_raw_rs12_cycle + 1'b1;
            end
            if (disp_raw_match_rs13) begin
              disp_block_raw_rs13_cycle <= disp_block_raw_rs13_cycle + 1'b1;
            end
            if (disp_raw_match_rs23) begin
              disp_block_raw_rs23_cycle <= disp_block_raw_rs23_cycle + 1'b1;
            end
            if (disp_raw_match_three) begin
              disp_block_raw_rs123_cycle <= disp_block_raw_rs123_cycle + 1'b1;
            end
          end

          if (disp_block_waw_dep) begin
            disp_block_waw_dep_cycle <= disp_block_waw_dep_cycle + 1'b1;
          end
          if (disp_dep_raw_only) begin
            disp_block_dep_raw_only_cycle <= disp_block_dep_raw_only_cycle + 1'b1;
          end
          if (disp_dep_waw_only) begin
            disp_block_dep_waw_only_cycle <= disp_block_dep_waw_only_cycle + 1'b1;
          end
          if (disp_dep_raw_waw) begin
            disp_block_dep_raw_waw_cycle <= disp_block_dep_raw_waw_cycle + 1'b1;
          end
          if (disp_dep_cons_alu) begin
            disp_dep_cons_alu_cycle <= disp_dep_cons_alu_cycle + 1'b1;
          end
          if (disp_dep_cons_agu) begin
            disp_dep_cons_agu_cycle <= disp_dep_cons_agu_cycle + 1'b1;
          end
          if (disp_dep_cons_bjp) begin
            disp_dep_cons_bjp_cycle <= disp_dep_cons_bjp_cycle + 1'b1;
          end
          if (disp_dep_cons_csr) begin
            disp_dep_cons_csr_cycle <= disp_dep_cons_csr_cycle + 1'b1;
          end
          if (disp_dep_cons_muldiv) begin
            disp_dep_cons_muldiv_cycle <= disp_dep_cons_muldiv_cycle + 1'b1;
          end
          if (disp_dep_cons_unknown) begin
            disp_dep_cons_unknown_cycle <= disp_dep_cons_unknown_cycle + 1'b1;
          end
          if (disp_dep_when_longp_prdt) begin
            disp_dep_when_longp_prdt_cycle <= disp_dep_when_longp_prdt_cycle + 1'b1;
          end
        end
        else if (disp_block_csrfence) begin
          disp_block_csrfence_cycle <= disp_block_csrfence_cycle + 1'b1;
        end
        else if (disp_block_wfi) begin
          disp_block_wfi_cycle <= disp_block_wfi_cycle + 1'b1;
        end
        else if (disp_block_oitf) begin
          disp_block_oitf_cycle <= disp_block_oitf_cycle + 1'b1;
        end
        else begin
          disp_block_other_cycle <= disp_block_other_cycle + 1'b1;
        end
      end

      if (disp_other_readypos_low) begin
        disp_other_readypos_low_cycle <= disp_other_readypos_low_cycle + 1'b1;
      end

      if (disp_other_readypos_high) begin
        disp_other_readypos_high_cycle <= disp_other_readypos_high_cycle + 1'b1;
      end

      if (disp_other_alu_notready) begin
        disp_other_alu_notready_cycle <= disp_other_alu_notready_cycle + 1'b1;
      end

      if (disp_other_agu_notready) begin
        disp_other_agu_notready_cycle <= disp_other_agu_notready_cycle + 1'b1;
      end

      if (disp_other_bjp_notready) begin
        disp_other_bjp_notready_cycle <= disp_other_bjp_notready_cycle + 1'b1;
      end

      if (disp_other_csr_notready) begin
        disp_other_csr_notready_cycle <= disp_other_csr_notready_cycle + 1'b1;
      end

      if (disp_other_ifu_excp_notready) begin
        disp_other_ifu_excp_notready_cycle <= disp_other_ifu_excp_notready_cycle + 1'b1;
      end

      if (disp_other_mdv_notready) begin
        disp_other_mdv_notready_cycle <= disp_other_mdv_notready_cycle + 1'b1;
      end

      if (disp_other_nice_notready) begin
        disp_other_nice_notready_cycle <= disp_other_nice_notready_cycle + 1'b1;
      end

      if (disp_other_ready_unknown) begin
        disp_other_ready_unknown_cycle <= disp_other_ready_unknown_cycle + 1'b1;
      end

      if (mdv_block) begin
        mdv_block_total_cycle <= mdv_block_total_cycle + 1'b1;
      end

      if (mdv_block_not_wbck_condi) begin
        mdv_block_not_wbck_condi_cycle <= mdv_block_not_wbck_condi_cycle + 1'b1;
      end

      if (mdv_block_wait_o_ready) begin
        mdv_block_wait_o_ready_cycle <= mdv_block_wait_o_ready_cycle + 1'b1;
      end

      if (mdv_block_wait_cmt_ready) begin
        mdv_block_wait_cmt_ready_cycle <= mdv_block_wait_cmt_ready_cycle + 1'b1;
      end

      if (mdv_block_wait_wbck_ready) begin
        mdv_block_wait_wbck_ready_cycle <= mdv_block_wait_wbck_ready_cycle + 1'b1;
      end

      if (mdv_block_wait_ready_unknown) begin
        mdv_block_wait_ready_unknown_cycle <= mdv_block_wait_ready_unknown_cycle + 1'b1;
      end

      if (mdv_block_sta_0th) begin
        mdv_block_sta_0th_cycle <= mdv_block_sta_0th_cycle + 1'b1;
      end

      if (mdv_block_sta_exec) begin
        mdv_block_sta_exec_cycle <= mdv_block_sta_exec_cycle + 1'b1;
      end

      if (mdv_block_sta_remd_chck) begin
        mdv_block_sta_remd_chck_cycle <= mdv_block_sta_remd_chck_cycle + 1'b1;
      end

      if (mdv_block_sta_quot_corr) begin
        mdv_block_sta_quot_corr_cycle <= mdv_block_sta_quot_corr_cycle + 1'b1;
      end

      if (mdv_block_sta_remd_corr) begin
        mdv_block_sta_remd_corr_cycle <= mdv_block_sta_remd_corr_cycle + 1'b1;
      end

      if (mdv_block_sta_unknown) begin
        mdv_block_sta_unknown_cycle <= mdv_block_sta_unknown_cycle + 1'b1;
      end

      if (mdv_block_exec_not_last) begin
        mdv_block_exec_not_last_cycle <= mdv_block_exec_not_last_cycle + 1'b1;
      end

      if (mdv_block_exec_last) begin
        mdv_block_exec_last_cycle <= mdv_block_exec_last_cycle + 1'b1;
      end

      if (mdv_block_remd_chck_need_corr) begin
        mdv_block_remd_chck_need_corr_cycle <= mdv_block_remd_chck_need_corr_cycle + 1'b1;
      end

      if (mdv_block_remd_chck_no_corr) begin
        mdv_block_remd_chck_no_corr_cycle <= mdv_block_remd_chck_no_corr_cycle + 1'b1;
      end

      if (mdv_block_b2b_or_special) begin
        mdv_block_b2b_or_special_cycle <= mdv_block_b2b_or_special_cycle + 1'b1;
      end

      if (mdv_req_mul) begin
        mdv_req_mul_cycle <= mdv_req_mul_cycle + 1'b1;
      end

      if (mdv_req_div) begin
        mdv_req_div_cycle <= mdv_req_div_cycle + 1'b1;
      end

      if (mdv_req_rem) begin
        mdv_req_rem_cycle <= mdv_req_rem_cycle + 1'b1;
      end

      if (mdv_req_divu) begin
        mdv_req_divu_cycle <= mdv_req_divu_cycle + 1'b1;
      end

      if (mdv_req_remu) begin
        mdv_req_remu_cycle <= mdv_req_remu_cycle + 1'b1;
      end

      if (mdv_req_mulh_family) begin
        mdv_req_mulh_family_cycle <= mdv_req_mulh_family_cycle + 1'b1;
      end

      if (mdv_issue_hsked) begin
        mdv_issue_total_cnt <= mdv_issue_total_cnt + 1'b1;
      end

      if (mdv_issue_mul) begin
        mdv_issue_mul_cnt <= mdv_issue_mul_cnt + 1'b1;
      end

      if (mdv_issue_div) begin
        mdv_issue_div_cnt <= mdv_issue_div_cnt + 1'b1;
      end

      if (mdv_issue_rem) begin
        mdv_issue_rem_cnt <= mdv_issue_rem_cnt + 1'b1;
      end

      if (mdv_issue_divu) begin
        mdv_issue_divu_cnt <= mdv_issue_divu_cnt + 1'b1;
      end

      if (mdv_issue_remu) begin
        mdv_issue_remu_cnt <= mdv_issue_remu_cnt + 1'b1;
      end

      if (mdv_issue_mulh_family) begin
        mdv_issue_mulh_family_cnt <= mdv_issue_mulh_family_cnt + 1'b1;
      end

      if (mdv_complete_hsked) begin
        mdv_complete_total_cnt <= mdv_complete_total_cnt + 1'b1;
      end

      if (mdv_complete_mul) begin
        mdv_complete_mul_cnt <= mdv_complete_mul_cnt + 1'b1;
      end

      if (mdv_complete_div) begin
        mdv_complete_div_cnt <= mdv_complete_div_cnt + 1'b1;
      end

      if (mdv_complete_rem) begin
        mdv_complete_rem_cnt <= mdv_complete_rem_cnt + 1'b1;
      end

      if (mdv_block_mul) begin
        mdv_block_mul_cycle <= mdv_block_mul_cycle + 1'b1;
      end

      if (mdv_block_div) begin
        mdv_block_div_cycle <= mdv_block_div_cycle + 1'b1;
      end

      if (mdv_block_rem) begin
        mdv_block_rem_cycle <= mdv_block_rem_cycle + 1'b1;
      end

      if (mdv_block_divu) begin
        mdv_block_divu_cycle <= mdv_block_divu_cycle + 1'b1;
      end

      if (mdv_block_remu) begin
        mdv_block_remu_cycle <= mdv_block_remu_cycle + 1'b1;
      end

      if (mdv_block_mulh_family) begin
        mdv_block_mulh_family_cycle <= mdv_block_mulh_family_cycle + 1'b1;
      end
    end
  end

  always @(posedge hfclk or negedge rst_n)
  begin
    if(rst_n == 1'b0) begin
      same_pc_streak <= 32'b0;
      last_commit_pc <= {`E203_PC_SIZE{1'b0}};
      auto_finish_by_stuck_pc <= 1'b0;
    end
    else if ((pc_write_to_host_flag == 1'b0) && (auto_finish_by_stuck_pc == 1'b0)) begin
      if (pc_vld) begin
        if (pc == last_commit_pc) begin
          same_pc_streak <= same_pc_streak + 1'b1;
          if (same_pc_streak >= SAME_PC_AUTO_FINISH_TH) begin
            auto_finish_by_stuck_pc <= 1'b1;
          end
        end
        else begin
          last_commit_pc <= pc;
          same_pc_streak <= 32'b0;
        end
      end
    end
  end


  // Randomly force the external interrupt
  `define EXT_IRQ u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.plic_ext_irq
  `define SFT_IRQ u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.clint_sft_irq
  `define TMR_IRQ u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.clint_tmr_irq

  `define U_CPU u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.u_e203_cpu_top.u_e203_cpu
  `define ITCM_BUS_ERR `U_CPU.u_e203_itcm_ctrl.sram_icb_rsp_err
  `define ITCM_BUS_READ `U_CPU.u_e203_itcm_ctrl.sram_icb_rsp_read
  `define STATUS_MIE   `U_CPU.u_e203_core.u_e203_exu.u_e203_exu_commit.u_e203_exu_excp.status_mie_r

  wire stop_assert_irq = (pc_write_to_host_cnt > 32);

  reg tb_itcm_bus_err;

  reg tb_ext_irq;
  reg tb_tmr_irq;
  reg tb_sft_irq;
  initial begin
    tb_ext_irq = 1'b0;
    tb_tmr_irq = 1'b0;
    tb_sft_irq = 1'b0;
  end

`ifdef ENABLE_TB_FORCE
  initial begin
    tb_itcm_bus_err = 1'b0;
    #100
    @(pc == `PC_AFTER_SETMTVEC ) // Wait the program goes out the reset_vector program
    forever begin
      repeat ($urandom_range(1, 20)) @(posedge clk) tb_itcm_bus_err = 1'b0; // Wait random times
      repeat ($urandom_range(1, 200)) @(posedge clk) tb_itcm_bus_err = 1'b1; // Wait random times
      if(stop_assert_irq) begin
          break;
      end
    end
  end


  initial begin
    force `EXT_IRQ = tb_ext_irq;
    force `SFT_IRQ = tb_sft_irq;
    force `TMR_IRQ = tb_tmr_irq;
       // We force the bus-error only when:
       //   It is in common code, not in exception code, by checking MIE bit
       //   It is in read operation, not write, otherwise the test cannot recover
    force `ITCM_BUS_ERR = tb_itcm_bus_err
                        & `STATUS_MIE 
                        & `ITCM_BUS_READ
                        ;
  end


  initial begin
    #100
    @(pc == `PC_AFTER_SETMTVEC ) // Wait the program goes out the reset_vector program
    forever begin
      repeat ($urandom_range(1, 1000)) @(posedge clk) tb_ext_irq = 1'b0; // Wait random times
      tb_ext_irq = 1'b1; // assert the irq
      @((pc == `PC_EXT_IRQ_BEFOR_MRET)) // Wait the program run into the IRQ handler by check PC values
      tb_ext_irq = 1'b0;
      if(stop_assert_irq) begin
          break;
      end
    end
  end

  initial begin
    #100
    @(pc == `PC_AFTER_SETMTVEC ) // Wait the program goes out the reset_vector program
    forever begin
      repeat ($urandom_range(1, 1000)) @(posedge clk) tb_sft_irq = 1'b0; // Wait random times
      tb_sft_irq = 1'b1; // assert the irq
      @((pc == `PC_SFT_IRQ_BEFOR_MRET)) // Wait the program run into the IRQ handler by check PC values
      tb_sft_irq = 1'b0;
      if(stop_assert_irq) begin
          break;
      end
    end
  end

  initial begin
    #100
    @(pc == `PC_AFTER_SETMTVEC ) // Wait the program goes out the reset_vector program
    forever begin
      repeat ($urandom_range(1, 1000)) @(posedge clk) tb_tmr_irq = 1'b0; // Wait random times
      tb_tmr_irq = 1'b1; // assert the irq
      @((pc == `PC_TMR_IRQ_BEFOR_MRET)) // Wait the program run into the IRQ handler by check PC values
      tb_tmr_irq = 1'b0;
      if(stop_assert_irq) begin
          break;
      end
    end
  end
`endif

  reg[8*300:1] testcase;
  integer dumpwave;

  initial begin
    $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");  
    if($value$plusargs("TESTCASE=%s",testcase))begin
      $display("TESTCASE=%s",testcase);
    end

    pc_write_to_host_flag <=0;
    clk   <=0;
    lfextclk   <=0;
    rst_n <=0;
    #120 rst_n <=1;

    @((pc_write_to_host_cnt == 32'd8) || (auto_finish_by_stuck_pc == 1'b1)) #10 rst_n <=1;
`ifdef ENABLE_TB_FORCE
    @((~tb_tmr_irq) & (~tb_sft_irq) & (~tb_ext_irq)) #10 rst_n <=1;// Wait the interrupt to complete
`endif

        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~ Test Result Summary ~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~TESTCASE: %s ~~~~~~~~~~~~~", testcase);
        $display("~~~~~~~~~~~~~~Total cycle_count value: %d ~~~~~~~~~~~~~", cycle_count);
        $display("~~~~~~~~~~The valid Instruction Count: %d ~~~~~~~~~~~~~", valid_ir_cycle);
        $display("~~~~~The test ending reached at cycle: %d ~~~~~~~~~~~~~", pc_write_to_host_cycle);
        $display("~~~~~~~~~~~~~~~The final x3 Reg value: %d ~~~~~~~~~~~~~", x3);
        $display("~~~~~~~~~~Branch total (Bxx commit): %d ~~~~~~~~~~~~~~~", branch_total);
        $display("~~~~~~~~~~Branch mispredict count: %d ~~~~~~~~~~~~~~~~~", branch_mispredict);
        $display("~~~~~~~~~~~~~~~IFU bpu_wait cycles: %d ~~~~~~~~~~~~~~~~~", ifu_wait_cycle);
        $display("~~~~~~~~~~~~~~IFU flush req cycles: %d ~~~~~~~~~~~~~~~~~", ifu_flush_cycle);
        $display("~~~~~~~~~~~~~~~LSU cmd wait cycles: %d ~~~~~~~~~~~~~~~~~", lsu_wait_cycle);
        $display("~~~~~~~~~~~~~IFU req block cycles: %d ~~~~~~~~~~~~~~~~~~", ifu_req_block_cycle);
        $display("~~~~~~~~~~~~~IFU rsp block cycles: %d ~~~~~~~~~~~~~~~~~~", ifu_rsp_block_cycle);
        $display("~~~~~~~~~~~~~~~~~IR busy cycles: %d ~~~~~~~~~~~~~~~~~~~~~", ir_busy_cycle);
        $display("~~~~~~~~~DISP block by dep cycles: %d ~~~~~~~~~~~~~~~~~~~", disp_block_dep_cycle);
        $display("~~~~~~~DEP: raw_dep block cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_raw_dep_cycle);
        $display("~~~~~~~DEP: waw_dep block cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_waw_dep_cycle);
        $display("~~~~~~DEP: raw-only block cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_dep_raw_only_cycle);
        $display("~~~~~~DEP: waw-only block cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_dep_waw_only_cycle);
        $display("~~~~~DEP: raw+waw block cycles: %d ~~~~~~~~~~~~~~~~~~~~~~", disp_block_dep_raw_waw_cycle);
        $display("~~~~~DEP by consumer ALU cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_alu_cycle);
        $display("~~~~~DEP by consumer AGU cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_agu_cycle);
        $display("~~~~~DEP by consumer BJP cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_bjp_cycle);
        $display("~~~~~DEP by consumer CSR cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_csr_cycle);
        $display("~~DEP by consumer MULDIV cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_muldiv_cycle);
        $display("~DEP by consumer UNKNOWN cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_cons_unknown_cycle);
        $display("~~~~~~DEP with longp_prdt cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_dep_when_longp_prdt_cycle);
        $display("~~~~~~~DEP RAW with rs1en cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_dep_raw_rs1en_cycle);
        $display("~~~~~~~DEP RAW with rs2en cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_dep_raw_rs2en_cycle);
        $display("~~~DEP RAW with rs1en&rs2en cycles: %d ~~~~~~~~~~~~~~~~~~", disp_dep_raw_rs1rs2en_cycle);
        $display("~~~~~~DEP RAW with rdwen cycles: %d ~~~~~~~~~~~~~~~~~~~~~", disp_dep_raw_rdwen_cycle);
        $display("~~~~DEP RAW src rs1-match cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs1_cycle);
        $display("~~~~DEP RAW src rs2-match cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs2_cycle);
        $display("~~~~DEP RAW src rs3-match cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs3_cycle);
        $display("~~~DEP RAW single-src cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_single_src_cycle);
        $display("~~~~DEP RAW multi-src cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_multi_src_cycle);
        $display("~~~~~DEP RAW rs1+rs2 cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs12_cycle);
        $display("~~~~~DEP RAW rs1+rs3 cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs13_cycle);
        $display("~~~~~DEP RAW rs2+rs3 cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs23_cycle);
        $display("~~~DEP RAW rs1+rs2+rs3 cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~", disp_block_raw_rs123_cycle);
        $display("~~~~~~~~DISP block by OITF cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_oitf_cycle);
        $display("~~~~~DISP block by CSR/FENCE cycles: %d ~~~~~~~~~~~~~~~~~~", disp_block_csrfence_cycle);
        $display("~~~~~~~~~DISP block by WFI cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_block_wfi_cycle);
        $display("~~~~~~~~DISP block by OTHER cycles: %d ~~~~~~~~~~~~~~~~~~~", disp_block_other_cycle);
        $display("~~~~~~OTHER: disp_i_ready_pos low: %d ~~~~~~~~~~~~~~~~~~~~~", disp_other_readypos_low_cycle);
        $display("~~~~~OTHER: disp_i_ready_pos high: %d ~~~~~~~~~~~~~~~~~~~~~", disp_other_readypos_high_cycle);
        $display("~~~~~~~~OTHER: ALU not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_alu_notready_cycle);
        $display("~~~~~~~~OTHER: AGU not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_agu_notready_cycle);
        $display("~~~~~~~~OTHER: BJP not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_bjp_notready_cycle);
        $display("~~~~~~~~OTHER: CSR not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_csr_notready_cycle);
        $display("~~~OTHER: IFU-EXCP not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_ifu_excp_notready_cycle);
        $display("~~~~~~~~OTHER: MDV not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_mdv_notready_cycle);
        $display("~~~~~~~OTHER: NICE not-ready cycles: %d ~~~~~~~~~~~~~~~~~~~~", disp_other_nice_notready_cycle);
        $display("~~~~OTHER: READY unknown cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", disp_other_ready_unknown_cycle);
        $display("~~~~~~~~~MDV block total cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_total_cycle);
        $display("~~~~~~MDV block not wbck_condi: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_not_wbck_condi_cycle);
        $display("~~~~~~~~MDV block wait o_ready: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_wait_o_ready_cycle);
        $display("~~~~~~MDV wait cmt_o_ready low: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_wait_cmt_ready_cycle);
        $display("~~~~~MDV wait wbck_o_ready low: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_wait_wbck_ready_cycle);
        $display("~~~~~~MDV wait ready unknown: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_wait_ready_unknown_cycle);
        $display("~~~~~~~~~~~MDV block in state 0th: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_0th_cycle);
        $display("~~~~~~~~~~MDV block in state exec: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_exec_cycle);
        $display("~~~~~MDV block in state remd_chck: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_remd_chck_cycle);
        $display("~~~~~MDV block in state quot_corr: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_quot_corr_cycle);
        $display("~~~~~MDV block in state remd_corr: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_remd_corr_cycle);
        $display("~~~~~~MDV block in state unknown: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_sta_unknown_cycle);
        $display("~~~~~~~~MDV exec not-last cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_exec_not_last_cycle);
        $display("~~~~~~~~~~~MDV exec last cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_exec_last_cycle);
        $display("~~~MDV remd_chck need-corr cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_remd_chck_need_corr_cycle);
        $display("~~~~MDV remd_chck no-corr cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_remd_chck_no_corr_cycle);
        $display("~~~~~~~~MDV b2b/special cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_b2b_or_special_cycle);
        $display("~~~~~~~~~~~~MDV req MUL cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_mul_cycle);
        $display("~~~~~~~~~~~~MDV req DIV cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_div_cycle);
        $display("~~~~~~~~~~~~MDV req REM cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_rem_cycle);
        $display("~~~~~~~~~~~MDV req DIVU cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_divu_cycle);
        $display("~~~~~~~~~~~MDV req REMU cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_remu_cycle);
        $display("~~~~~~~MDV req MULH* cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_req_mulh_family_cycle);
        $display("~~~~~~~~~~~~~~MDV issue total cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_total_cnt);
        $display("~~~~~~~~~~~~~~~~MDV issue MUL cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_mul_cnt);
        $display("~~~~~~~~~~~~~~~~MDV issue DIV cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_div_cnt);
        $display("~~~~~~~~~~~~~~~~MDV issue REM cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_rem_cnt);
        $display("~~~~~~~~~~~~~~~MDV issue DIVU cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_divu_cnt);
        $display("~~~~~~~~~~~~~~~MDV issue REMU cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_remu_cnt);
        $display("~~~~~~~~~~~MDV issue MULH* cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_issue_mulh_family_cnt);
        $display("~~~~~~~~~~~MDV complete total cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_complete_total_cnt);
        $display("~~~~~~~~~~~~~MDV complete MUL cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_complete_mul_cnt);
        $display("~~~~~~~~~~~~~MDV complete DIV cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_complete_div_cnt);
        $display("~~~~~~~~~~~~~MDV complete REM cnt: %d ~~~~~~~~~~~~~~~~~~~~~~~~", mdv_complete_rem_cnt);
        $display("~~~~~~~~~~MDV block MUL cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_mul_cycle);
        $display("~~~~~~~~~~MDV block DIV cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_div_cycle);
        $display("~~~~~~~~~~MDV block REM cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_rem_cycle);
        $display("~~~~~~~~~MDV block DIVU cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_divu_cycle);
        $display("~~~~~~~~~MDV block REMU cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_remu_cycle);
        $display("~~~~~~MDV block MULH* cycles: %d ~~~~~~~~~~~~~~~~~~~~~~~~~~~", mdv_block_mulh_family_cycle);
        $display("~~~~~~~~~~~~~Same PC streak cycles: %d ~~~~~~~~~~~~~~~~~~", same_pc_streak);
        $display("~~~~~~~Auto finish by stuck PC flag: %d ~~~~~~~~~~~~~~~~~", auto_finish_by_stuck_pc);
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
      if (auto_finish_by_stuck_pc == 1'b1) begin
        $display("~~~~~~~~~~~~ AUTO_FINISH_BY_STUCK_PC ~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
      end
      else if (x3 == 1) begin
        $display("~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    end
    else begin
        $display("~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    end
    #10
     $finish;
  end

  initial begin
    #40000000
        $display("Time Out !!!");
     $finish;
  end

  always
  begin 
     #2 clk <= ~clk;
  end

  always
  begin 
     #33 lfextclk <= ~lfextclk;
  end



  
  
  initial begin
    if($value$plusargs("DUMPWAVE=%d",dumpwave)) begin
      if(dumpwave != 0) begin

	 `ifdef vcs
            $display("VCS used");
            $fsdbDumpfile("tb_top.fsdb");
            $fsdbDumpvars(0, tb_top, "+mda");
         `endif

	 `ifdef iverilog
            $display("iverlog used");
	    $dumpfile("tb_top.vcd");
            $dumpvars(0, tb_top);
         `endif
      end
    end
  end




  integer i;

    reg [7:0] itcm_mem [0:(`E203_ITCM_RAM_DP*8)-1];
    initial begin
      $readmemh({testcase, ".verilog"}, itcm_mem);

      for (i=0;i<(`E203_ITCM_RAM_DP);i=i+1) begin
          `ITCM.mem_r[i][00+7:00] = itcm_mem[i*8+0];
          `ITCM.mem_r[i][08+7:08] = itcm_mem[i*8+1];
          `ITCM.mem_r[i][16+7:16] = itcm_mem[i*8+2];
          `ITCM.mem_r[i][24+7:24] = itcm_mem[i*8+3];
          `ITCM.mem_r[i][32+7:32] = itcm_mem[i*8+4];
          `ITCM.mem_r[i][40+7:40] = itcm_mem[i*8+5];
          `ITCM.mem_r[i][48+7:48] = itcm_mem[i*8+6];
          `ITCM.mem_r[i][56+7:56] = itcm_mem[i*8+7];
      end

        $display("ITCM 0x00: %h", `ITCM.mem_r[8'h00]);
        $display("ITCM 0x01: %h", `ITCM.mem_r[8'h01]);
        $display("ITCM 0x02: %h", `ITCM.mem_r[8'h02]);
        $display("ITCM 0x03: %h", `ITCM.mem_r[8'h03]);
        $display("ITCM 0x04: %h", `ITCM.mem_r[8'h04]);
        $display("ITCM 0x05: %h", `ITCM.mem_r[8'h05]);
        $display("ITCM 0x06: %h", `ITCM.mem_r[8'h06]);
        $display("ITCM 0x07: %h", `ITCM.mem_r[8'h07]);
        $display("ITCM 0x16: %h", `ITCM.mem_r[8'h16]);
        $display("ITCM 0x20: %h", `ITCM.mem_r[8'h20]);

    end 



  wire jtag_TDI = 1'b0;
  wire jtag_TDO;
  wire jtag_TCK = 1'b0;
  wire jtag_TMS = 1'b0;
  wire jtag_TRST = 1'b0;

  wire jtag_DRV_TDO = 1'b0;


e203_soc_top u_e203_soc_top(
   
   .hfextclk(hfclk),
   .hfxoscen(),

   .lfextclk(lfextclk),
   .lfxoscen(),

   .io_pads_jtag_TCK_i_ival (jtag_TCK),
   .io_pads_jtag_TMS_i_ival (jtag_TMS),
   .io_pads_jtag_TDI_i_ival (jtag_TDI),
   .io_pads_jtag_TDO_o_oval (jtag_TDO),
   .io_pads_jtag_TDO_o_oe (),

   .io_pads_gpioA_i_ival(32'b0),
   .io_pads_gpioA_o_oval(),
   .io_pads_gpioA_o_oe  (),

   .io_pads_gpioB_i_ival(32'b0),
   .io_pads_gpioB_o_oval(),
   .io_pads_gpioB_o_oe  (),

   .io_pads_qspi0_sck_o_oval (),
   .io_pads_qspi0_cs_0_o_oval(),
   .io_pads_qspi0_dq_0_i_ival(1'b1),
   .io_pads_qspi0_dq_0_o_oval(),
   .io_pads_qspi0_dq_0_o_oe  (),
   .io_pads_qspi0_dq_1_i_ival(1'b1),
   .io_pads_qspi0_dq_1_o_oval(),
   .io_pads_qspi0_dq_1_o_oe  (),
   .io_pads_qspi0_dq_2_i_ival(1'b1),
   .io_pads_qspi0_dq_2_o_oval(),
   .io_pads_qspi0_dq_2_o_oe  (),
   .io_pads_qspi0_dq_3_i_ival(1'b1),
   .io_pads_qspi0_dq_3_o_oval(),
   .io_pads_qspi0_dq_3_o_oe  (),

   .io_pads_aon_erst_n_i_ival (rst_n),//This is the real reset, active low
   .io_pads_aon_pmu_dwakeup_n_i_ival (1'b1),

   .io_pads_aon_pmu_vddpaden_o_oval (),
    .io_pads_aon_pmu_padrst_o_oval    (),

    .io_pads_bootrom_n_i_ival       (1'b0),// In Simulation we boot from ROM
    .io_pads_dbgmode0_n_i_ival       (1'b1),
    .io_pads_dbgmode1_n_i_ival       (1'b1),
    .io_pads_dbgmode2_n_i_ival       (1'b1) 
);


endmodule


