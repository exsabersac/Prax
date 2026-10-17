# Rust 重写（R 系列）— 正式程序

已批准的程序计划（gate 原文）管辖；本文件是活状态表面。设计是契约——五条语义
不变量、规格、LEDGER——不是 Haskell。Rust 必须正确：分歧对照规格裁定；Haskell bug
永不复现（用户裁定）；真正模糊的分叉交给用户。

Haskell 树（标签 `haskell-freeze` 处的 `src/ app/ test/`）不再编辑。允许的 diff 表面：
`oracle/` + `prax.cabal` 中一条加法 stanza。由 `scripts/freeze-check.sh` 与比较器机械强制。

## 状态

| 阶段 | 范围 | 状态 | 报告 |
|---|---|---|---|
| S0 | 冻结标签、oracle exe、fixtures、工作区脚手架、verify 脚本 | DONE | [S00](reports/S00-harness.md) |
| S1 | Sym + Db + EL | DONE | [S01](reports/S01-sym-db-el.md) |
| S2 | Query（一条编译路径） | DONE | [S02](reports/S02-query.md) |
| S3 | Derive + view（设计重） | DONE | [S03](reports/S03-derive.md) |
| S4 | Types + Engine + 构建器 API（设计重） | DONE | [S04](reports/S04-engine.md) |
| S5 | Loop + Schedule + Rng（流在 S4 落地） | DONE | [S05](reports/S05-loop-schedule.md) |
| S6 | Planner + Minds + Relevance + Sight（设计重；保真高峰） | DONE | [S06](reports/S06-planner.md) |
| S7 | 垂直世界切片：Feud → Intrigue → Bar → Village（Audience → S8，[A1]） | 切片 1-4 已落地，切片 4 修复波已应用；切片 4 证据报告未出 | [S07-1](reports/S07-slice1-feud.md) [S07-2](reports/S07-slice2-intrigue.md) [S07-3](reports/S07-slice3-bar.md) |
| S8 | Script + Play + Audience（[A1]） | DONE | [S08](reports/S08-script-play-audience.md) |
| S9 | TypeCheck + AnalysisTable + Stress + Persist + Inspect + CLI | DONE（owed:S9==0，整账本无欠项；评审 APPROVE-WITH-MINORS） | [S09](reports/S09-tools-and-cutover-audit.md) |
| S10 | 硬化 + 切换 | 硬化完成 — 等待演示（唯一用户门禁）：500 种子矩阵干净，性能修复已合并（评审 APPROVE，DIV-1 被证伪），[P2] 幸存基线网绿，soak/零 unsafe/金标准/type_check 全绿（980 测试）；village-stress/trace 处于边际对等 = 演示时用户的性能判断。在「go」之前不删除任何东西。 | [S10](reports/S10-hardening.md) |

## S10 契约 — 继承义务（来自 S9 切换审计；有约束力）

S10 交接时账本无欠项（owed==0）。其切换标准是 PLAN 的（conformance 绿 · meta-gate 绿 ·
差分矩阵在每世界 500 种子 × cap 50、状态模式下干净 · check/stress/flow/dump-play 相等 ·
clippy -D warnings · 零 unsafe · proptest soak · 性能表 Rust ≥ Haskell · 用户在 Rust 上玩
village+bar 并说 go），加上 S9 审计写下的这些契约，使任何与冻结比较的网不致变成静默死重：

- **[P4] prax-oracle 改瞄**（工具在删除时失去对手方）：切换时，把干净的 500 种子矩阵跑的
  Rust 侧 JSONL 捕获为 `conformance/oracle-baselines/` 下提交的基线语料；删除 `drive_frozen.rs`
  及其 `freeze_check`/`freeze_rev` 门禁（不是 stub）；增加 `compare --baseline` 模式，把
  当前 Rust 与提交语料 diff；把 `die-seed-sweep.sh`/`verify.sh` 改瞄到它。**[P3]**
  `die-seed-sweep.sh` 并入同一次改瞄。
- **freeze-check.sh** 在删除提交中移除（其对象已不存在）。
- **golden-check.sh** 改瞄到 `conformance/goldens/SHA256SUMS`；meta-gate 读已提交的
  `HASKELL_PINS.txt` 快照（[P2] 反空虚地板已就位，守护被清空的清单）。
- **六个已发布世界的 `type_check == []`** 是声明的切换标准（站立的 S9 网，带入矩阵）。
- 整个程序中唯一的用户门禁是演示（在 Rust `prax play` 上玩 village + bar，含 save/resume）；
  删除提交仅在「go」之后。

## 登记册

- `docs/rewrite/DIVERGENCES.md` — Rust 修复的已裁定 Haskell bug（是什么、为何规格裁定 Rust、
  虚构后果、比较器抑制）。在存在之前为空。
- `docs/rewrite/FORKS.md` — 向用户提出的语义分叉问题。在存在之前为空。
- `conformance/KILLED.md` — 未重表达的 Haskell 钉死，各带类别（decimal | implementation |
  haskell-only）与理由；由 meta-gate 测试审计。
- 证据报告：`docs/rewrite/reports/S<NN>-<name>.md`，各一屏。

## 携带缺口（CARRIED GAPS）

程序未能按原打算规模网住的法则，带到此处以免阶段间蒸发。缺口不是分歧——Rust 是对的——
所以 `DIVERGENCES.md` 不是归宿。每条写明法则、什么覆盖了它、什么没有、以及何时到期。
**S10 时仍开放的缺口必须作为覆盖范围声明限制出现在切换标准中。**

**开放缺口：无。** CG-1 是唯一一条，S8 已关闭。

### CG-1 — v44 SUPERSESSION 法则在世界规模无 AUTHORED-DATA 网 — **S8 已关闭**

**法则。** 对已携带待到期路径的裸插入会取消该到期，使事实永久站立
（`prax-core/src/engine.rs`，`Effect::Insert`）。同一路径上的再 `InsertFor` 走同一分支然后重武装：
是刷新，不是取代。

**缺口曾是什么。** 法则从 S5 起有引擎规模网
（`schedule_spec::law_3_bare_re_insert_cancels_the_timer` 与
`engine_replay::engine_scenarios_replay_byte_for_byte`，都在裸 `State::new()` 上），以及
S7 修复波的世界规模网（`supersession_world`，同一法则覆盖真实编译的 `village_world()`，
旁有对照与刷新陷阱）。但在两者中，裸插入都由测试执行。没有已发布世界通过自身创作数据
到达该情形，因此仅经创作才显现的 supersession bug 无网——逐切片测量：bar/dm/village 经
恰好两条路线写 `*.feels.*`：`feel_toward_for`（`InsertFor`）与 `unfeel_toward`（`Delete`），
42 回合 village 轨迹命中 `expiries.remove` 100 次，全是刷新，零次裸 supersession。

**什么关闭了它。** S8 的 `conformance::script_supersession`，驱动
`conformance/fixtures/cg1_supersession.json`——真实创作的 play-script，其场景 setup 武装
自己的计时器（`{"insertFor":{"rounds":3,"sentence":"lantern.lit"}}`），其一个 beat 对该路径
做裸插入。放任不管时灯笼在边界 3 熄灭，读其缺席的 junction 结束故事；被屏蔽时，待到期被取消，
事实在八个边界后仍站立——超过创作寿命两倍——结局永不到来。Supersession，来自创作数据，
世界规模，经 JSON 门，对照与刷新陷阱钉在旁边。

**必须先打破的主张。** 本文件与 S8 设计都曾断言缺口不能在 S8 关闭：*「`Prax.Script.compile`
在构造时拒绝任何以 `scenePatience` 开头的创作条件或结果——因此对活脚本计时器的裸插入
不仅在 S8 世界中缺席，在脚本中也不可表达。」* **这是错的。** 拒绝只覆盖编译器拥有的
`scenePatience` 族。`InsertFor` 在创作 `Outcome` 表面上：`sceneSetup` 接受它（`Script.hs:105`），
`beatEffects` 接受它（`Script.hs:120`），`Prax.Script.Json` 直接拼写它（`Json.hs:139-140`）。
脚本可在任意路径上武装计时器然后取消它，`compile` 从不查看。S8 健全性评审组发现了这一点，
并在写任何 Rust 之前，在冻结引擎上对同一提交文件独立重测：

```
compile ACCEPTED the authored InsertFor + a bare Insert of the same path
control    (i, lantern.lit, ending) = [(0,True,Nothing),(1,True,Nothing),(2,True,Nothing),
                                       (3,False,Just "darkness"),(4,False,Just "darkness"), …]
supersede  expiries after the beat  = []
supersede  (i, lantern.lit, ending) = [(0,True,Nothing) … (8,True,Nothing)]
```

**变异证据。** 从 `prax-core` 的 `Effect::Insert` 臂删除 `rt.expiries.remove(path)` 后，
`cargo test --workspace --no-fail-fast` 恰好给出四个 RED，别无其他：

```
schedule_spec::tests::law_3_bare_re_insert_cancels_the_timer                        (S5, 引擎规模)
engine_replay::replay::engine_scenarios_replay_byte_for_byte                        (S5, 引擎规模)
supersession_world::tests::a_bare_insert_onto_a_live_village_timer_supersedes_it    (S7, 世界规模，外部驱动)
script_supersession::tests::a_beats_bare_insert_supersedes_the_scripts_own_authored_timer   (S8, 创作侧)
```

第四个是新的，正是缺口所关切的。对照
（`the_authored_timer_fires_on_schedule_when_nothing_touches_it`）在该删除下保持 GREEN，
必须如此——删除取消不会阻止到期触发——这使该对成为测量而非巧合。

**差分。** 同一提交文件是两侧引擎上的 `cg1` 世界——冻结 oracle 在
`oracle/TraceMain.hs` 的 `cg1ScriptPath` 读它，Rust 登记在
`prax_oracle::worlds::CG1_SCRIPT_JSON` 嵌入它——因此两者不能由不同脚本驱动。它是
fixture，不是已发布内容，因此与 `probe`、`bigfeud` 一样不在 `allWorldNames` 中。

**刷新半边** 在 S8 覆盖两遍：由创作的重武装
（`re_arming_the_authored_timer_refreshes_rather_than_supersedes`）以及经编译器场景入口 fold
的场景再进入重武装耐心标记，由创作的 `goto` 到达
（`conformance::script_spec::re_entry_resets_a_timed_junction`）。

**处置。** 已关闭。无携带到 S10。
