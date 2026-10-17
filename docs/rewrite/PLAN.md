# 计划：Rust 重写（R 系列）

## 背景

用 Rust 完全替换 Haskell Prax 实现。设计是契约（五条语义不变量、规格、LEDGER），
不是 Haskell：只有承重语义保留；Haskell 事故消亡。按用户流程裁定：不为人审写架构文档——
语义保真由机械验证（相对冻结 Haskell 的差分测试 + 1:1 审计的重表达钉死语料），
工程质量由 agent 在对抗评审下自有，用户只看到一屏证据报告（信息性）、具体语义分叉问题、
以及最终可玩演示（程序中唯一的批准点）。

## 已定决策（用户）

- Haskell 在树内冻结直到对等，然后一次提交删除。
- Rust 构建器 DSL 是创作表面。
- 每阶段完整严格（评审组/审查），但门禁按上述裁定由机械验证替换。

## 用户会看到什么（整个表面）

1. `docs/rewrite/PROGRAM.md` — 活状态表（阶段 | 状态 | 报告）。
2. 每阶段一屏证据报告（`docs/rewrite/reports/S*.md`）：钉死绿 / killed 计数、差分矩阵行、
   clippy/proptest、性能、开放分叉。无批准语义。
3. FORK 问题（少见）：每个真正模糊情形一段——规格对可观察行为沉默或自相矛盾。
   选项写明虚构层后果；默认取规格意图最支持的（Haskell 行为是证据，从不以在位资格为默认）；
   在得到答复前按默认推进。
4. 切换演示：在 Rust `prax play` 上玩 village 与 bar（含 save/resume）并说 go。

## 架构（agent 自有；浓缩决策记录）

Cargo 工作区，edition 2024：`prax-core`（引擎）、`prax-vocab`（20 个内容组合子模块——
纯值构建器，耐久社交词汇）、`prax-script`（Prompter 层 + serde 格式）、`prax-worlds`
（6 个世界）、`prax-cli`、`prax-oracle`（差分比较器）、`conformance`（跨模块 + 世界测试，
每个 Haskell 规格文件一个文件）。

核心决策：一种编译表示——创作 AST（字符串表面的 `Condition`/`Outcome`/... 构建器）是与
运行时类型（`Cond`/`Effect`/`CompiledPath`，带 interned `Sym`）不同的类型族，仅在安装时由
单一编译 choke point（retable 继承者）转换；整个 raw/cooked 镜像二元、双份实现、以及全局
`unsafePerformIO` intern 池消亡（interner 变为 state 中的 `Arc<Interner>`；保留 var-bit 奇偶技巧）。
Db：排他 trie，为 `Arc` 路径拷贝持久节点（有序 `SmallVec` 孩子），保留 planner 的
apply-and-discard clone 模型；纠正后的 `!` 语义 + v39 asserted-flag 法则原文保留；
确定性契约写明（每个枚举点按名称序）。错误：构造守护变为 `Result<_, WorldError>`（thiserror；大声），
引擎不变量破坏 panic，矛盾仍为可查询事实。分数：i32 效用 × f64 0.9/0.5 折扣，累积顺序钉死
（跨语言位精确；顺序是契约，小数钉死消亡）。`i64` 替代 `Integer`，带检查算术（已记录偏差）。
MINSTD RNG 位精确。依赖：smallvec、rustc-hash、thiserror、serde(+json)、proptest（dev）。
ViewInvariant 双路径网的继承者：仅测试用的 naive 闭包 oracle（约 60 行，与生产循环无共享）
在随机化+金标准序列的每次变更后断言，加上 proptest 法则套件（trie/EL/query/expiry/persist 法则）。

## 验证（替换用户门禁）

- **冻结，精确含义**：`src/ app/ test/` 打标签 `haskell-freeze`，不再编辑——机械强制
  （若 `git diff --quiet haskell-freeze -- src app test` 失败，比较器拒绝运行）。一个加法表面：
  新的 `oracle/` cabal 可执行文件（约 250 LOC）导入冻结库——trace/randtrace/check/fixtures
  子命令发出规范 JSONL（每回合：actor、action、boundary、cursor、rng、dues、expiries、
  经 dbToLabeledSentences 排序的事实列表）。零库编辑。
- **分歧裁定（用户裁定——Rust 必须正确，不是 Haskell 相等）**：分歧是信号，不是自动失败。
  每个对照规格裁定（权威；Haskell 是证据，从非先例）：(a) Rust bug → 修 Rust；(b) Haskell bug——
  行为与其自身规格/LEDGER 记录矛盾——→ Rust 保留正确行为，Haskell 永不打补丁，修复记入
  `docs/rewrite/DIVERGENCES.md`（是什么、为何规格说 Rust 对、虚构后果）并向比较器登记为
  已裁定分歧（精确抑制：世界/类/路径模式），使矩阵读作「干净 modulo 已裁定修复」，
  新信号永不被淹没；(c) 真正模糊（规格沉默或自相矛盾）→ 向用户提分叉问题。
  实现 bug 永不复现。
- **比较器**（`prax-oracle` Rust bin）：逐记录状态比较；分歧时自动以候选列表重跑并分类
  （ENUMERATION | DECISION | STATE | SCHEDULE | RNG）+ 事实级路径 diff；查阅已裁定分歧登记。
  矩阵模式：每（世界，种子）一行，`clean | clean-mod-adjudicated | DIVERGENT`。
- **meta-gate**：每个重表达 Rust 测试带 `// H: <SpecFile> "<label>"`；conformance 测试解析
  Haskell 规格标签（现从树，删除后从提交的清单）并断言约 760 个标签各自出现在恰好一个
  `// H:` 注释或一行 KILLED.md（类别：decimal | implementation | haskell-only + 一行理由）。
  钉死记账是红/绿测试，不是口头主张。
- 金标准决策轨迹：作为 Rust 基线提交并差分交叉核对；从不改成匹配新行为。

## 阶段（每个 = 编号 R 系列回合，房屋节奏，各有 LEDGER 行）

S0 脚手架（冻结标签、oracle/ exe、fixture dump、工作区脚手架、CI 双套件）— 5%
S1 Sym+Db+EL（DbSpec/ELSpec/SymSpec 语义；fixture 重放）— 10%
S2 Query，一条编译路径（QuerySpec + CookedSpec 可观察半边）— 8%
S3 Derive + view，保留增量（v27/v33 性能历史），ViewInvariant 重生为 incremental==naive
   proptest — 设计重 — 8%
S4 Types+Engine+构建器 API（决定成败的创作表面；EngineSpec、RngSpec 完整——MINSTD 流随
   CRoll 执行，从 S5 前移 [S4 评审组 I2]——GateSpec 卫生半边）— 设计重 — 15%
S5 Loop+Schedule+Rng（LoopSpec advance、Schedule*；Rng 缩为循环集成流 fixture——流本身在 S4）— 5%
S6 Planner+Minds+Relevance+Sight（折扣顺序钉死、平局、v34 重用带 reuse==live proptest、
   v35 intentions；小数→顺序钉死）— 设计重，保真高峰 — 15%
S7 垂直世界切片 Feud→Intrigue→Bar→Village（Audience 移至 S8——它是 Script 编译的；
   S7 设计 [A1]），每切片 = 所需 vocab 模块 + 世界 + 差分开启（trace + randtrace ≥100
   种子 × cap 50，状态模式）— 20%
S8 Script+Play（JSON 往返；examples/play.json 加载不变）— 5%
S9 TypeCheck+AnalysisTable+Stress+Persist（新 serde 格式，无跨引擎存档兼容）+Inspect+CLI；
   GateSpec 扫描器改瞄 .rs — 6%
S10 硬化 + 切换（矩阵 6 世界 × 500 种子、性能表、演示）— 3%

设计重阶段（S3/S4/S6）在依赖者开始前做对抗评审组。

## 切换（除演示外全机械）

Conformance 绿 + meta-gate 绿；差分矩阵干净（每世界 500 种子 × cap 50，状态模式；
check/stress/flow/dump-play 输出相等）；clippy -D warnings、零 unsafe、proptest soak；
性能表 Rust ≥ Haskell；用户在 Rust 上玩 village+bar 并说 go。删除提交（标签
`haskell-final` 之后）：src/、test/、app/、oracle/、prax.cabal、cabal.project、
Haskell CI 消亡；cargo 工作区升到仓库根；docs/ + references/ + examples/play.json
完整保留；trace/replay 工具作为 Rust-vs-自身金标准 QA 保留。

## 第一步可执行动作

S0：打标签 `haskell-freeze`；写 `oracle/TraceMain.hs` + 一条 cabal stanza；dump + 提交
单元 fixture 语料（db/EL/query/derive 表）；脚手架 cargo 工作区；接线 CI 跑双套件 + 冻结检查。

---
