# E203 基线性能改进计划（Improve Plan）

> 目标：在**可控风险**下提升 E203 基线性能，并且让改造过程尽可能服务于你对处理器微架构的学习。

---

## 1. 我倾向优先改哪里？

我建议优先从 **IFU 前端路径（LiteBPU + Flush/Replay + 取指气泡）** 入手，而不是先动 LSU 或复杂乱序机制。

### 原因

1. **收益直接**：E203 是 2 级流水，前端一旦停顿，CPI 立刻变差。CoreMark 这种循环与条件分支密集负载对前端很敏感。
2. **改造可小步迭代**：可以从“仅加计数器（零功能风险）→ 小型 BHT → 小型 BTB/预取队列”逐步推进。
3. **学习价值最高**：这条链会穿过 IFU/EXU/commit/flush 等关键接口，是理解整颗核最好的主干路径。
4. **回退简单**：大部分改动可以通过宏开关快速关闭，不会把系统拖入大面积不稳定。

---

## 2. 可行修改方案（按阶段）

## Phase 0：先建立观测与基线（强烈建议先做）

### 0.1 新增轻量性能计数器（功能不变）

建议计数项（最小集合）：

- `total_cycle`
- `retired_inst`（等价于 testbench 里 `i_valid & i_ready` 的累计）
- `branch_total`
- `branch_mispredict`
- `ifu_bpu_wait_cycle`
- `ifu_flush_cycle`
- `lsu_wait_cycle`

### 0.2 建议放置位置

- 快速方案：先放在 `tb/tb_top.v` 做仿真统计（最小侵入）。
- 工程化方案：在 `e203_exu_commit` / `e203_ifu_ifetch` / `e203_lsu_ctrl` 内部生成事件脉冲，再汇总到 CSR 可读寄存器。

### 0.3 为什么必须先做

如果没有这组计数器，后续优化很容易“感觉变快了”，但无法证明瓶颈是否真的移动。

---

## Phase 1：将 Bxx 静态预测升级为小型动态 BHT（优先）

### 1.1 当前问题

当前 `e203_ifu_litebpu.v` 对条件分支采用“后向 taken，前向 not-taken”静态策略，偏置分支与复杂模式下误预测偏高。

### 1.2 建议实现

- 新增 32 或 64 项 BHT（2-bit 饱和计数器）。
- 索引：`PC[6:2]`（32 项）或 `PC[7:2]`（64 项）。
- 预测：计数器高位为 1 则 taken。
- 更新：在 commit 阶段依据 `bjp_rslv`（实际分支结果）更新。
- 与现有 JAL/JALR 路径兼容：只替换 `Bxx` 的 taken 决策。

### 1.3 预期收益

- 降低 `branch_mispredict / branch_total`。
- 减少 `pipe_flush_req` 触发频率。
- CoreMark/MHz 通常会有可见提升（实际幅度取决于程序分支行为）。

---

## Phase 2：增加微型 BTB（可选，收益次于 BHT）

### 2.1 目标

针对 taken 分支/JAL 目标地址，减少重定向延迟。

### 2.2 建议实现

- 8/16 项直接映射 BTB。
- 条目：`valid + tag + target (+可选type)`。
- BHT 决策为 taken 时，优先从 BTB 给 target；miss 时退回原有加法路径。

### 2.3 风险点

- 注意 flush 优先级和时序路径，避免引入组合环。
- 注意 `fencei/mret/dret/exception` 的强制重定向语义不可被 BTB 覆盖。

---

## Phase 3：IFU 微型预取队列（1~2 项）

### 3.1 目标

吸收 ICB 握手抖动，减少前端“等响应”气泡。

### 3.2 建议实现

- 在 `e203_ifu_ifetch` 与 IR 之间加入 1~2 项 FIFO（PC+IR+异常位）。
- flush/replay/halt 发生时，队列需要可清空。
- 保持异常与提交顺序不变。

### 3.3 是否值得

若 Phase 0 显示 IFU 握手等待占比高（而不是误预测主导），此项收益会更明显。

---

## Phase 4（可选）：JALR 特殊路径优化

`e203_ifu_litebpu.v` 中 `jalr` 相关依赖会触发 `bpu_wait`。如果 profile 显示 `bpu_wait` 明显偏高，可针对高频 `jalr` 形态优化旁路与等待策略。

---

## 3. 观测信号与波形清单（可直接挂）

> 建议先在 GTKWave 做 4 组分窗：IFU、EXU/Commit、LSU、TB 汇总。

## A. Testbench 汇总（先看）

来自 `tb/tb_top.v`：

- `cycle_count`
- `valid_ir_cycle`
- `pc_write_to_host_cycle`
- `pc_write_to_host_cnt`
- `x3`（pass/fail）
- `pc` / `pc_vld`

用途：快速判断“有无性能变化、是否跑完”。

## B. IFU 前端（本次优化主观测）

主要在 `e203_ifu_ifetch.v`：

- 握手：`ifu_req_valid/ready`，`ifu_rsp_valid/ready`
- 前端停顿：`bpu_wait`，`ifu_halt_req/ack`
- 重定向：`pipe_flush_req`，`pipe_flush_ack`，`pipe_flush_req_real`
- 预测：`prdt_taken`，`ifu_o_prdt_taken`
- 取指控制：`ifu_req_seq`，`ifu_new_req`，`ifu_req_valid_pre`

建议层级路径（以 testbench 宏为根）：

- `u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.u_e203_cpu_top.u_e203_cpu.u_e203_core.u_e203_ifu.u_e203_ifu_ifetch.*`

## C. EXU/Commit（判断误预测与 flush 触发源）

主要在 `e203_exu_commit.v` 与 `e203_exu_branchslv.v`：

- `alu_cmt_i_valid`
- `alu_cmt_i_bjp` / `alu_cmt_i_bjp_prdt` / `alu_cmt_i_bjp_rslv`
- `alu_brchmis_flush_req`
- `pipe_flush_req` / `pipe_flush_ack`
- `cmt_i_ready`

建议路径：

- `...u_e203_core.u_e203_exu.u_e203_exu_commit.*`
- `...u_e203_core.u_e203_exu.u_e203_exu_commit.u_e203_exu_branchslv.*`

## D. LSU（排除“其实瓶颈在访存”）

主要在 `e203_lsu_ctrl.v`：

- `agu_icb_cmd_valid/ready`
- `pre_agu_icb_rsp_valid/ready`
- `lsu_o_valid`
- `agu_icb_rsp_valid`
- `lsu_o_cmt_buserr`（用于异常排查）

建议路径：

- `...u_e203_core.u_e203_lsu.u_e203_lsu_ctrl.*`

---

## 4. CoreMark 定位方法（实战版）

> 目的：把“性能变化”定位到前端、分支、还是访存，而不是只看一个分数。

## Step 1：固定基线条件

- 固定编译选项与迭代次数（当前 `Makefile` 默认 `ITERATIONS=20`）。
- 固定下载模式（如 `DOWNLOAD=ilm`）。
- 固定时钟假设（日志中会打印 `CPU Frequency`）。

建议关注文件：

- `software/hbird-sdk/application/baremetal/benchmark/coremark/Makefile`
- `vsim/run/coremark/coremark.log`

## Step 2：记录三类指标

1. **结果指标**：`CoreMark/MHz`（主指标）
2. **吞吐指标**：
   - 指令吞吐近似：`IPC ~= valid_ir_cycle / cycle_count`
3. **结构性指标**（你新增的计数器）：
   - 误预测率：`branch_mispredict / branch_total`
   - IFU 阻塞占比：`ifu_bpu_wait_cycle / total_cycle`
   - LSU 阻塞占比：`lsu_wait_cycle / total_cycle`

## Step 3：二分定位（推荐流程）

- 先只开 Phase 0（计数器），跑 baseline。
- 只开 BHT（Phase 1），看：
  - 若 `mispredict` 明显下降且 `CoreMark/MHz` 提升，说明方向正确。
- 再开 BTB（Phase 2），看 `flush` 与吞吐是否继续改善。
- 若收益不明显，检查 LSU 阻塞占比是否高，避免“前端过度优化”。

## Step 4：定位到代码行

结合 `coremark.dump`：

- 先定位热点循环与分支密集段。
- 在波形中对齐对应 PC 区间，观察该区间的 `prdt_taken`、`bpu_wait`、`pipe_flush_req`。
- 若同一段 PC 反复 flush，可优先针对该类分支模式调参（如 BHT 项数/索引）。

---

## 5. 实施优先级与里程碑

### Milestone A（1~2 天）

- 完成 Phase 0 计数器
- 建立 baseline 报告（含波形截图与 3 组指标）

### Milestone B（2~4 天）

- 上线 BHT（32 项）
- 跑回归（rv32ui + hello + coremark）
- 输出“是否提升 + 提升来源”

### Milestone C（可选）

- 试 BTB（8 项）与 IFU 队列（1 项）
- 对比性价比（收益/复杂度/风险）

---

## 6. 风险与回退策略

- 每个 Phase 都加宏开关（如 `E203_CFG_BHT_EN`），便于 A/B 对比与快速回退。
- 若出现功能风险，先关掉新特性，仅保留计数器继续定位。
- 不要同时引入多个结构改动，否则难以归因。

---

## 7. 一句话结论

**优先改 IFU 前端（先观测、再 BHT、后 BTB/预取）是这颗 E203 上最稳妥、最有学习价值、也最有概率拿到可验证性能收益的路径。**
