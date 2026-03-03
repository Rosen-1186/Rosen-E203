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

---

## 8. Phase1 结果解读：为什么性能变化较小？

> 说明：以下对比基于同一份 CoreMark（`ITERATIONS=1`）在同一仿真流下做的 A/B。
> 由于 `ITERATIONS=1` 不满足 CoreMark 官方 >=10s 规范，绝对分数仅用于相对比较。

### 8.1 A/B 量化结果（BHT OFF vs ON）

- CoreMark/MHz：`2.154100 -> 2.177890`（约 **+1.10%**）
- 总周期（`cycle_count`）：`678474 -> 670267`（约 **-1.21%**）
- 分支误预测数：`21191 -> 13331`（约 **-37.1%**）
- IFU flush 周期：`22361 -> 14247`（约 **-36.3%**）

### 8.2 为什么误预测降很多，但总性能只小幅提升？

这是典型的 Amdahl 现象：

1. **分支并非唯一瓶颈**：
   即使分支相关代价明显下降，LSU 等待、前端非分支等待、以及其它流水停顿仍占据相当比例。

2. **已优化的是“局部路径”**：
   这次只优化了 `Bxx` 的方向预测；`JALR` 相关等待、访存握手、长尾自旋退出路径都未被改变。

3. **2 级流水的可隐藏空间有限**：
   E203 前后端耦合紧，单点改进很容易被其它结构性等待“吃掉”。

4. **当前 workload 结束方式带来噪声**：
   仿真是通过 `AUTO_FINISH_BY_STUCK_PC` 收敛，说明尾段存在自旋；这会稀释“有效计算区间”内的性能增益观感。

### 8.3 这次修改“为什么要做、目的是什么”

1. **修改原因**：
   原始静态分支策略在复杂分支模式下误预测偏高，导致 flush 频繁，前端吞吐受损。

2. **修改目的**：
   以最小风险方式先显著降低误预测率，验证“前端分支预测”确实是可优化项。

3. **工程目标**：
   建立可复用的 A/B 框架（开关宏 + 统一指标），让后续每一步优化都可量化归因。

### 8.4 下一步改进方法（按性价比排序）

1. **方法A：继续压缩分支代价（低风险）**
   - 在 BHT 之上加入小型 BTB（8/16 项），减少 taken 分支目标重定向开销。
   - 观察指标：`ifu_flush_cycle`、`cycle_count`。

2. **方法B：降低前端/执行等待（中风险）**
   - 针对 `JALR` 相关 `bpu_wait` 路径做优化（高频模式旁路/等待策略优化）。
   - 观察指标：`ifu_bpu_wait_cycle`。

3. **方法C：处理非分支瓶颈（中风险）**
   - 加 1~2 项 IFU 微型预取队列，吸收 ICB 抖动。
   - 并行检查 LSU 握手等待，避免“前端优化被访存瓶颈覆盖”。

4. **方法D：提升评估可信度（低风险，建议立即做）**
   - 增加正式评测组：`ITERATIONS>=10s` + 多轮均值。
   - 分离“有效计算区间”和“尾段自旋区间”统计，减少收敛方式带来的偏差。

### 8.5 实践结论

**本次 BHT 改造是“方向正确、收益真实但受系统级瓶颈限制”的典型案例。**
下一阶段应从“只降误预测”升级为“分支目标 + 前端等待 + 访存等待”协同优化，性能提升会更连续、更可见。

---

## 9. 从初版跑分反推“关键路径”的执行方法

> 这个章节用于回答一个核心问题：**现在到底该往哪里优化**。
> 结论不是靠“感觉”，而是靠“周期归因闭环”。

### 9.1 先做周期守恒分解（必须）

定义：

- `total_cycle = cycle_count`
- `retire_cycle = valid_ir_cycle`
- `non_retire_cycle = total_cycle - retire_cycle`

在当前 CoreMark（BHT ON）日志中：

- `total_cycle = 670267`
- `retire_cycle = 406951`
- `non_retire_cycle = 263316`
- `IPC ~= 406951 / 670267 = 0.607`

这说明优化空间主要在 **non-retire 周期**。

### 9.2 已解释停顿占比（当前仍偏低）

当前已统计的停顿项：

- `ifu_flush_cycle = 14247`
- `ifu_bpu_wait_cycle = 2332`
- `lsu_wait_cycle = 4934`

合计 `21513`，仅占 `non_retire_cycle` 的约 `8.2%`。

> 关键判断：还有约 `91.8%` 的非退休周期尚未归因。
> 这就是“为什么现在不知道往哪优化”的根因：计数器没有覆盖到真正的大头路径。

### 9.3 必须补齐的“关键路径计数器”

建议在 `tb/tb_top.v` 继续新增以下事件（只观测，不改功能）：

1. **前端请求受阻**
   - `ifu_req_block_cycle = ifu_req_valid & ~ifu_req_ready`
   - 定位 ICB/下游握手背压。

2. **前端响应受阻**
   - `ifu_rsp_block_cycle = ifu_rsp_valid & ~ifu_rsp_ready`
   - 区分“返回了但进不了 IR/流水”的情况。

3. **IR 满导致前端停顿**
   - `ir_busy_cycle = ifu_o_valid & ~ifu_o_ready`
   - 直接衡量 IFU→EXU 交界是否成为瓶颈。

4. **OITF 背压周期**
   - 统计 dispatch 因 OITF 满/相关冲突无法前推的周期。
   - 可从 `e203_exu_oitf` 的 `dis_ready` 相关信号引出观测。

5. **分支重定向有效损失周期**
   - 保留 `ifu_flush_cycle`，并新增“flush 后 N 周期无退休”计数，衡量每次误预测真实代价。

6. **长流水/写回仲裁影响**
   - 统计 ALU 写回因 longp 占用而等待的周期。
   - 可参考 `e203_exu_wbck.v` 中 `wbck_ready4alu`。

### 9.4 有了这些计数后，优化优先级如何判定

按贡献从大到小排序（Top-N）：

- 若 `ifu_req_block_cycle`/`ifu_rsp_block_cycle` 高：优先 IFU 请求/响应路径（预取队列、握手策略）。
- 若 `ir_busy_cycle` 高：优先 IFU→EXU 接口与 dispatch 背压。
- 若 OITF 相关高：优先解耦长流水与 dispatch（结构冲突优化）。
- 若 flush 相关仍高：继续做 BTB/目标预测与分支代价压缩。
- 若 LSU 等待高：转向访存路径（而不是继续堆前端预测）。

### 9.5 下一步最小执行清单（建议）

1. 先补 4~6 个计数器（半天内可完成）。
2. 只跑 baseline（不开新优化），拿首版“停顿贡献排行榜”。
3. 选 Top1 瓶颈做单点改动，再 A/B。

这样就能把“感觉不知道往哪优化”转成“有证据地按占比优化”。

---

## 10. 2026-03 基线复盘：关键瓶颈已经变化

> 基于 `vsim/run/coremark/coremark.log` 的当前基线（`ITERATIONS=1`）统计。

### 10.1 当前基线关键数值

- `CoreMark/MHz = 2.154100`
- `total_cycle = 678474`
- `valid_ir_cycle = 406748`，故 `non_retire_cycle = 271726`
- `branch_total = 130419`，`branch_mispredict = 21191`（误预测率约 `16.25%`）
- `ifu_flush_cycle = 22361`（约占总周期 `3.30%`）
- `ifu_bpu_wait_cycle = 2332`（约占总周期 `0.34%`）
- `lsu_wait_cycle = 4938`（约占总周期 `0.73%`）
- `ifu_rsp_block_cycle = 236367`（约占总周期 `34.84%`）
- `ir_busy_cycle = 231235`（约占总周期 `34.08%`）

### 10.2 结论：主瓶颈不再是分支，而是 IFU→EXU 背压

从占比看，`ifu_rsp_block/ir_busy` 远大于 `flush`、`bpu_wait` 与 `lsu_wait`。这说明性能损失主要来自 **取指响应回来了，但 IR/EXU 暂时吃不下**，而不是单纯的分支预测问题。

结合 RTL 可见：

- `e203_ifu_ifetch.v` 中 `ifu_rsp_ready = ifu_ir_i_ready & ifu_req_ready & (~bpu_wait)`。
- `ifu_ir_i_ready` 对应 EXU 的 `i_ready`。
- `i_ready` 来自 `e203_exu_disp.v` 的 `disp_i_ready`，其受 RAW/WAW、`disp_oitf_ready`、CSR/FENCE/OITF 条件约束。

因此当前最优先应转向 **Dispatch/OITF 背压分解与缓解**。

### 10.3 下一阶段改进计划（按优先级）

#### P1：先把背压拆清楚（只观测）

在 `tb/tb_top.v` 新增分项计数：

- `disp_block_dep_cycle`：`dep` 导致的阻塞（RAW/WAW）。
- `disp_block_oitf_cycle`：`disp_alu_longp_prdt & ~disp_oitf_ready`。
- `disp_block_csrfence_cycle`：CSR/FENCE 等待 `oitf_empty`。
- `disp_block_wfi_cycle`：`wfi_halt_exu_req`。

目标：把 `ir_busy_cycle` 分解为可行动作的 Top-N 子项。

#### P2：低风险结构优化（先做）

1. **IFU 响应侧 1-entry skid buffer（优先）**
   - 位置：`e203_ifu_ifetch` 的响应→IR 交界。
   - 目标：降低瞬时 `i_ready` 抖动导致的 `ifu_rsp_block`。

2. **Dispatch 细化旁路（仅针对高频依赖）**
   - 当 P1 证明 `dep` 是主导项时，再定点放宽或旁路。
   - 原则：先做“可证明不改语义”的窄改动。

#### P3：中风险优化（按数据决定）

- 若 `disp_block_oitf_cycle` 高：评估 OITF 深度/仲裁策略。
- 若 `disp_block_csrfence_cycle` 高：评估 CSR/FENCE 保守条件细化。
- 若 `flush` 重新升高：再回到 BTB/JALR 路径优化。

### 10.4 验证规则（保持可归因）

每次仅改 1 个点，统一输出以下指标：

- `CoreMark/MHz`
- `valid_ir_cycle / cycle_count`（IPC 近似）
- `ir_busy_cycle / cycle_count`
- `ifu_rsp_block_cycle / cycle_count`
- `branch_mispredict / branch_total`

并固定：同一 testcase、同一编译选项、同一退出条件。

---

## 11. 面向学习的“处理器实战路径”

建议你按下面顺序学习，每一步都配 1 个可观测任务：

1. **系统层**：`rtl/e203/soc`、`rtl/e203/subsys`
   - 任务：画出中断路径（PLIC/CLINT → CPU）。

2. **前端层**：`e203_ifu_ifetch.v`、`e203_ifu_litebpu.v`
   - 任务：追踪一次分支误预测从预测到 flush 的完整时序。

3. **执行层**：`e203_exu_disp.v`、`e203_exu_commit.v`、`e203_exu_oitf.v`
   - 任务：解释 `i_ready` 在一个 RAW 依赖场景下为何拉低。

4. **访存层**：`e203_lsu_ctrl.v`
   - 任务：区分“命令发不出”和“响应回不来”的等待差异。

5. **验证层**：`tb/tb_top.v` + `vsim/Makefile`
   - 任务：做一次 A/B（开关宏）并产出 1 页性能归因表。

这个路径的核心是：**每读一层代码，就马上用计数器/波形做一次闭环验证**。

---

## 12. 2026-03-04 新日志复盘（P1 细分计数已生效）

基于最新 `vsim/run/coremark/coremark.log`：

- `CoreMark/MHz = 2.177890`
- `total_cycle = 670267`
- `valid_ir_cycle = 406951`，`IPC ~= 0.607`
- `branch_total = 130453`，`branch_mispredict = 13331`（约 `10.22%`）
- `ifu_rsp_block_cycle = 236029`（约 `35.21%`）
- `ir_busy_cycle = 230990`（约 `34.46%`）

新增的 dispatch 细分：

- `disp_block_dep_cycle = 44685`
- `disp_block_oitf_cycle = 0`
- `disp_block_csrfence_cycle = 270`
- `disp_block_wfi_cycle = 0`
- `disp_block_other_cycle = 186035`

### 12.1 关键结论

1. `dep` 是显著子瓶颈，但不是最大头。
2. `OITF`、`CSR/FENCE`、`WFI` 基本可排除为当前主矛盾。
3. **`disp_block_other_cycle` 成为 Top1（远高于 dep）**，下一阶段需要继续拆解 `OTHER`。

### 12.2 下一步（P1.5）

在 testbench 继续把 `OTHER` 分解为：

- `disp_i_ready_pos` 导致的阻塞（`disp_o_alu_ready` 拉低）
- `alu 子通道 ready` 拉低（`alu_i_ready/agu_i_ready/bjp_i_ready/csr_i_ready/...`）
- 写回仲裁相关（例如 longp 占用导致普通 ALU 让路）

目标：把 `disp_block_other_cycle` 再拆到可直接改 RTL 的粒度，然后再决定是先做旁路、握手缓冲，还是写回仲裁改造。

---

## 13. 2026-03-04 深拆结论：`OTHER` 的主因是 MULDIV 执行时长，而非下游背压

基于最新 `vsim/run/coremark/coremark.log`（已包含 MDV 细分项）：

- `total_cycle = 670267`
- `DISP block by OTHER = 186035`（约 `27.75%` 总周期）
- `OTHER: MDV not-ready = 165103`（约占 OTHER 的 `88.75%`，约占总周期 `24.63%`）

MDV 内部再拆：

- `MDV block total = 165103`
- `MDV block not wbck_condi = 165103`
- `MDV block wait o_ready = 0`
- `MDV wait cmt_o_ready low = 0`
- `MDV wait wbck_o_ready low = 0`

状态机贡献：

- `state exec = 154782`（其中 `exec not-last = 154641`，`exec last = 141`）
- `state 0th = 10159`
- `state remd_chck = 81`
- `state quot_corr = 81`

### 13.1 结论

1. 当前主瓶颈不是写回端/提交端 ready，而是 **MULDIV 自身多周期执行窗口**。
2. 也就是说，`mdv_i_ready` 拉低的原因几乎全部来自 `wbck_condi` 尚未满足（算法阶段未完成），不是下游仲裁阻塞。
3. 因此继续优化 IFU/dispatch 握手，短期收益会被该结构性长延迟上限压制。

### 13.2 下一步优化优先级（按性价比）

1. **软件编译策略先行（低风险）**
   - 针对 CoreMark 单独做一组“减 DIV/REM 压力”编译实验（对比 `-O2` 与偏向乘加/移位的选项组合）。
   - 目标：先验证 workload 是否被 `DIV/REM` 主导。

2. **微架构中风险方案：缩短 MULDIV 关键路径**
   - 优先看 DIV 状态机循环次数与可提前结束条件。
   - 若实现复杂，先做“仅统计每类指令（mul/div/rem）占比 + 平均阻塞周期”再决定是否改 RTL。

3. **结构方案（高风险）**
   - 若确认长期要提 CoreMark，可评估“非阻塞 MULDIV 接口”或“更激进旁路/并行化”。
   - 该类改造需更强验证，建议放在前两项后。

---

## 14. 2026-03-04 继续深拆：`mul/div/rem` 哪个最贵

本轮新增了 MULDIV 按操作类型统计（同一日志）：

- `MDV req MUL cycles = 170307`
- `MDV req DIV cycles = 2566`
- `MDV req REM cycles = 2391`
- `MDV req MULH* cycles = 17`

对应阻塞周期：

- `MDV block MUL cycles = 160288`
- `MDV block DIV cycles = 2493`
- `MDV block REM cycles = 2322`
- `MDV block MULH* cycles = 16`

### 14.1 结论

1. **MULDIV 阻塞主因是 MUL 族（尤其普通 MUL）而不是 DIV/REM**。
2. DIV/REM 确实慢，但在当前 CoreMark 路径中的占比远小于 MUL 调用频度带来的总阻塞。
3. 因为前面已证明 `wait_o_ready` 近似 0，所以关键矛盾仍是 **MULDIV 计算窗口本身**。

### 14.2 可执行下一步（建议顺序）

1. **先做“算法/实现级”小实验（低风险）**
   - 目标：缩短 MUL 执行窗口（例如减少固定迭代数或加入更激进早停条件）。
   - 要求：保持指令结果与异常语义不变。

2. **并行做编译侧 A/B（低风险）**
   - 尝试不同优化组合，观察 `MDV req MUL cycles` 是否可下降。
   - 若请求次数明显下降，说明软件侧有可观收益。

3. **再考虑结构级升级（中高风险）**
   - 包括更宽乘法路径或不同乘法实现。
   - 需配套更完整回归与时序评估。

---

## 15. 2026-03-04 继续插针结果：按“每条指令平均阻塞周期”评估

新增统计项（issue/complete）显示：

- `MDV issue total = 10161`，`MDV complete total = 10161`
- `issue MUL = 10019`
- `issue DIV = 73`
- `issue REM = 69`

结合阻塞周期可得：

- MUL 平均阻塞约 `160288 / 10019 ≈ 15.998` cycles/inst
- DIV 平均阻塞约 `2493 / 73 ≈ 34.151` cycles/inst
- REM 平均阻塞约 `2322 / 69 ≈ 33.652` cycles/inst

### 15.1 结论（两层）

1. **单条代价层面**：DIV/REM 明显比 MUL 更贵（约 34 vs 16 cycles/inst）。
2. **总量贡献层面**：MUL 数量远高于 DIV/REM（10019 vs 73/69），因此总阻塞仍由 MUL 主导。

### 15.2 优化策略建议（基于数据）

- 若目标是 **CoreMark 总周期最大化下降**：优先优化 MUL 路径（因为贡献体量最大）。
- 若目标是 **最坏时延/单条指令延迟**：优先优化 DIV/REM 路径。

对当前 workload（CoreMark）建议优先顺序：

1. 先做 MUL 路径减周期实验（小步、可回退）。
2. 再看 DIV/REM 代价优化是否有额外收益。
