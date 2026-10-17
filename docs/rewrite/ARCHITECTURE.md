# Rust 引擎架构 — agent 侧决策记录

非面向用户的文档（程序计划的裁定）；这是实现者、评审者与评审组的共享契约。
此处的决策由程序的设计阶段产出，仅通过阶段评审组修订，修订就地记录。

## 立场

一种表示、一种实现、无全局状态。创作 AST（字符串表面）与运行时类型
（interned、预切分）是不同的类型族；只有安装时编译器做转换。v28 的字符串战
不会重演，因为未编译路径在类型上进不了引擎。字符串恰好活在三个边界：
创作、渲染、持久化。

## Crates（工作区在 rust/）

prax-core（引擎）· prax-vocab（20 个内容组合子模块——纯值构建器）·
prax-script（Prompter 层 + serde 格式）· prax-worlds · prax-cli ·
prax-oracle（比较器）· conformance（跨模块测试，每个 Haskell 规格文件对应一个文件）。
脚本层的引擎规则入口（registerEngineRules，v53 出处）已封死：prax-script 可到达，
公共创作表面不可。

## 核心类型（prax-core）

- `Sym(u32)`，第 0 位 = 是否变量（保留 v29 奇偶技巧）。`Interner` 自有、仅追加；
  id 不可观察——所有输出经 resolve，所有可观察顺序按名称排序。
  [S6 修订，按实现者提案，作为更好设计被接受：interner 每个 State 谱系一个，
  以 `&mut` 贯穿，planner fork 只克隆 `Runtime`——镜像冻结引擎的单一池。
  这完全去掉了每 fork 克隆 interner，并把 S6 评审组发现的跨谱系 Sym 比较风险
  （delta syms vs 读锚点 syms）在构造上收成同谱系比较；fork 安全论证简化为
  单调追加。S9 持久化重载再 intern 风险不受影响，仍标记。]
- `CompiledPath { segs: SmallVec<[Sym;6]>, excl: u32 }` — excl 第 i 位 = seg i 之后的
  分隔符是 `!`。创作边界只有一个分词器（保留尾部运算符拒绝）。
- `Db(Arc<Node>)`，`Node { excl: bool, asserted: bool, kids: SmallVec<[(Sym,
  Db);4]> 按 id 排序 }` — 持久性靠 Arc 路径拷贝（每个触达节点新鲜 `Arc::new`；
  `make_mut` 是针对唯一持有情况的储备微优化）；clone = 引用计数递增（planner 的
  apply-and-discard 依赖此——由 db.rs 测试中的结构共享网守护）。路径上限 32 段
  （excl 位掩码宽度），分词时大声拒绝——是声明的边界，不是分歧（已发布内容
  都不超过 7）。纠正后的 `!` 插入（清兄弟姐妹、保留幸存者子树）与 v39
  asserted-flag 法则（无未断言的无子节点；急切修剪）原文保留。
  确定性枚举契约：unify 的未绑定分支、child_keys、句子枚举、到期触发均按名称序。
- `el`：meet/leq 为有序归并遍历；⊥ = 排他节点被强制成两个孩子；assertedness 做 OR。
- 创作族：`Condition/Outcome/Action/Practice/Axiom/ScheduleRule/Function`，带字符串路径
  + 构建器函数（`matches/not_/eq/insert/...`；`Action::new(label).when([...]).then([...])`）。
  运行时族：`Cond/Effect`，基于 `CompiledPath`/`Sym`。一个求值器（`query`）、一个执行器、
  一个闭包实现。
- `Bindings`：有序 `SmallVec<[(Sym, Val);8]>`；`Val = Sym | Num(i64) | Set(...)`。
  i64 替代 Integer，带检查算术（溢出大声——已记录偏差）。
- `State { defs: Arc<Defs>, rt: Runtime }`。Defs：保留的创作源（类型检查/持久化/诊断）
  + 编译形式 + 派生分析表（footprint、axiom_heads、neg_footprint、cont_monotone、
  improvables、liveness、cares_about）——由每个 setter 调用的单一编译 choke point
  （compilepipe::recompile，retable 继承者）整表重建。
  Runtime：db、view（闭包缓存）、cursor、intentions、schedule_dues、expiries、rng_seed
  ——普通 clone，trie 结构共享。db/view 私有；写者是 engine::perform（三层 delta 路由：
  无关 → apply_direct；单调插入 → 闭包延续；否则全量重闭）和 with_db。view 不变量是结构的。
- 错误：构造守护 `Result<_, WorldError>`（thiserror；大声、#[must_use]、完整诊断——
  世界在构建时 .expect()）；引擎不变量破坏 panic；矛盾 = 可查询事实，永非错误。
- 分数：i32 效用 × f64 0.9/0.5 折扣，累积顺序钉死（镜像 Haskell fold 顺序 → 位精确决策对等；
  顺序是契约，小数永不钉死）。声明边界（S6）：冻结的 `wantUtility` 是 `Int`（64 位）；
  Rust 的是 `i32`。创作权重是小整数（已发布都不超过两位数），求值在 i64 累积，
  收窄在构建器处大声——是 32 段路径上限意义上的边界，不是可观察分歧。记录它是因为
  这使 fold 顺序金丝雀的「大基数」表述不可行（见 S06-design [S-I2]）。
- RNG：MINSTD 在 i64 上位精确。持久化：serde JSON，带版本，事实为标注句子；
  大声拒绝版本不匹配。

## 验证机制（crate 内）

- testkit（feature）：naive_closure oracle（约 60 行，与生产只共享 meet/leq + trie）
  在随机化 + 金标准序列的每次变更后断言 view == naive_closure(axioms_src, db)
  ——ViewInvariant 继承者。
- proptest 法则套件：trie 法则（asserted-flag walker、`!` 取代、insert/retract 往返）、
  EL 格法则、query compiled==fresh-parse、v44 expiry 法则、persist 往返。
- 每个重表达测试带 `// H: <SpecFile> "<label>"`；meta-gate 测试对照这些与 KILLED.md
  审计全部 849 个清单标签。

## 依赖

smallvec、rustc-hash、thiserror、serde(+json)；dev：proptest。无阶段评审组决定，
不加其他。

## 储备杠杆（先测量）

Arena trie + undo log（若 Arc 路径拷贝主导剖析）；定点分数（若出现 f64 平台问题）；
im 风格 map 用于 intentions/expiries（若某世界持有数千个）。
