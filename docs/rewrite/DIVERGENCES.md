# 已裁定分歧 — Rust 正确而 Haskell 不正确之处

按程序裁定（docs/rewrite/PLAN.md）：分歧对照**规格**裁定；Haskell bug 永不复现、永不打补丁；
此处条目携带规格权威、虚构后果、以及比较器姿态。

## DIV-1 (S3)：冻结的半朴素闭包在跨谓词聚合体上不完整

**是什么**：`Prax.Derive.deltaJoin`（Derive.hs:120-128，`run` 与 `runCooked` 两者）只从 delta
播种顶层 `Match` 位置。一条规则若其 Exists/Subquery/Count/Or 条件读的是与其 Match 种子
**不相交**的派生谓词，则在 Match 事实离开 delta 后不再触发——闭包静默欠派生。由现场探针证明
（记为 conformance/fixtures/ 中的负 fixture）：`[Match p.X, Exists[Match q.Y]] → r.X`
配 `[Match trigger] → q.thing`：冻结省略 `r.a`；闭包含有它。

**规格权威**：view「是基在公理下的闭包」（ViewInvariantSpec 声明的不变量）；冻结代码把半朴素
记为优化（「已知者不再重派生」）——改变结果的优化与自身契约矛盾。Rust 实现朴素等价闭包
（静态快路径/全求值规则分裂；naive==production 法则是旗舰性质）。

**虚构后果**：任何已发布世界中无——其聚合条件读与 Match 同一谓词（形状运气，现已记录）。
未来带跨谓词聚合公理的世界在 Rust 上正确派生、在冻结 Haskell 上不正确。

**比较器姿态**：无需抑制——已发布轨迹一致。负 fixture 钉死两侧输出，使分歧成为提交的产物。

## DIV-2 (S6)：含分隔符的角色名被冻结引擎接受，却被其自身 planner 以三种方式解读

**是什么**：冻结引擎中无任何东西禁止角色名含路径分隔符（`.` 或 `!`）——`Prax.Types.character`
是裸记录构建，`setCharacters` 无守护。提供一个，冻结 planner 就与**自身**对名字含义意见不一，
因为同一名字经三个不同表面到达三个位点：

- `Prax.Relevance.moverReadAnchors` 的死亡锚点（Relevance.hs:284）是
  `map intern (pathNames (deadSentence (charName m)))` —— `pathNames` **切分**，因此
  名为 `hall.keeper` 的 mover 产生 3 段锚点 `[dead, hall, keeper]`。
- 同一函数的 `scopeReads`（Relevance.hs:281）在 SYM 层落地（`groundCookedCondition`），
  用一个 Sym 替换一段——名字保持单段。
- `Prax.Planner.inScope`（Planner.hs:74）经 `groundCondition` → `Prax.Db.ground` =
  `tokensToSentence (groundTokens …)` 落地，重建字符串，然后 `query` 的 `Match s -> pathNames s`
  （Query.hs:133）再**切分**——因此此处名字再次被切分。

后果是行为性的，不是表面的。`mayUnifySyms` 截断到较短路径并逐段比较，因此 2 段 delta 锚点
`[dead, "hall.keeper"]` 匹配 2 段读锚点但对抗 3 段失败——重用门禁在一种解读上触发、在另一种上错过，
对同一世界给出相反的重用决策。同样，预测范围 `[Match "near.Actor"]` 在 `inScope` 下变成
`[near, hall, keeper]`，在 sym 层路径下变成 `[near, "hall.keeper"]`：mover 被纳入或从想象回合中丢弃，
移动分数并可能改变选择。**渲染**名在每种情况下相同，因此无 dump 能看出差异。

**Rust 做什么**：`State::set_characters` **拒绝**任何含 `.` 或 `!` 的名字，带
`WorldError::MultiSegmentCharacterName`，点名角色与理由。该类变得不可达而非静默分歧。
无论守护如何，移植也被做成自洽：`mover_read_anchors` 用 `tokenize(interner, "dead.<m>")` 构建
死亡锚点，与 `candidate_actions` 和 `living_characters` 已用的同一分词器，因此三个 Rust 位点
对名字如何分段一致（由 `the_death_read_anchor_is_tokenized_like_every_other_death_sentence` 钉死，
它因守护使差异经 `State` 不可观察，而直接用 `hall.keeper` 调用 `mover_read_anchors`）。

**规格权威**：单段命名是其他每个面向引擎名字的既定约定——调度规则名在冻结引擎自身带显式
构造守护（`Prax.Engine.addScheduleRules`：「调度规则名必须是单段」），且 `ScheduleRule` 的
`srName` 文档写「单段；持久化再关联键」(Types.hs:213)。角色名被拼接到引擎构建的句子中，
恰如规则名被拼接到其 due 键：`dead.<name>`、`<p>.believes.desires.<name>.…`、
`practice.<pid>.<role>.<name>`。其中的分隔符把角色的事实族嵌套在彼此之下，并跨段边界切分
其死亡标记与范围锚点。那是路径注入，不是名字——因此守护是冻结引擎已陈述的规则，
应用于原先缺失它的门口。

替代方案——把 Rust `in_scope` 绕回字符串表面以匹配 `inScope`——被拒绝：它会复现实现事故
（冻结自己的 `moverReadAnchors` **不**这样做），且程序裁定是 Haskell bug 永不复现。

**虚构后果**：无。无已发布世界使用含分隔符的角色名。尝试使用的世界得到大声的构造时错误，
而非两个引擎对同一阵容安静地讲不同故事。

**比较器姿态**：无抑制。冻结轨迹从不含此类名字，因此无 fixture、语料行或重放受影响——
planner 与 npc 语料跨此变更字节同一地再生。分歧纯粹关于两个引擎**接受**什么：冻结接受且
Rust 也接受的一切，两者位对位一致。

## DIV-3 (S7)：vocab 组合子的名字守护是急切的，而冻结的仅在构建的句子被强制时触发

**是什么**：`Prax.Faction.memberPath` 用 `error` 守护其两个名字，而
`Prax.Faction.joins who faction = Insert (memberPath who faction)` 把该守护放在惰性强制的
`String` 内。因此冻结守护在某个消费者强制路径时触发——对只强制列表脊骨的消费者则**永不**。
`Prax.Kin.wed` 完全继承此：它自己检查 `joiner` 与 `spouse`，把 `faction` 留给它构建的 `joins`。
两个观察在冻结引擎上以同一输入核实：

```
HASKELL length (wed "ana" "b.ad" "cass") -> 2
HASKELL show   (wed "ana" "b.ad" "cass") -> ERROR: Faction: names must be nonempty
        single path segments (no '.' or '!'): ("ana","b.ad")
```

冻结的 `Prax.KinSpec`（KinSpec.hs:122-127）恰好含有这种仅脊骨观察者：它断言 `length (wed …)`。

**Rust 做什么**：`member_path`、`joins` 与 `wed` 返回 `Result<_, WorldError>`，因此拒绝发生在
**构造时**——`wed("ana", "b.ad", "cass")` 是 `Err(NotASinglePathSegment)`，无强制参与。

**规格权威**：守护存在是为阻止畸形名字被拼接到构建路径（`member.<who>!<faction>`），这是
创作数据的构造时属性；程序既定姿态是此类守护在门口触发（DIV-2 对角色名做同一论证，且冻结引擎
自身在构造时守护调度规则名）。其触发依赖哪个观察者碰巧强制该值的守护，不是对数据的守护——
是对消费者的守护。Rust 也没有惰性 `String` 可把 `error` 挂在内：替代将是 panic 访问器，
重写 outright 禁止。

**虚构后果**：无。每个真实消费者都强制路径（那正是执行 outcome 所做的），对每个此类消费者
两个引擎相同：同一守护、同一输入、同一拒绝。差异仅由从不查看其所守护值的观察者可观察。

**比较器姿态**：无抑制。偏差不能出现在轨迹中——到达某回合的世界已强制每个 setup outcome，
因此 `wed` 带坏 faction 的世界在任一侧都到不了比较器；一侧构建失败，另一侧在首次强制时失败。
由 `kin::tests::wed_rejects_a_bad_faction_at_construction` 本地钉死，在冻结规格仅脊骨观察的
精确输入上断言 Rust 行为。

## 已记录姿态（非 DIV）：⊥ 见证按名称序选择

当闭包回合把两个或更多不同值强制进一个排他槽时，**两侧**引擎都报告单一 ⊥ 见证——但选择方式不同。
Rust 按渲染名排序该回合的新鲜头并按该序 fold meet，因此报告的见证是名称最小的冲突头
（`derive.rs` `run`，设计 I4）。冻结引擎按 `nub`（生成）序 fold `foldM meetOne`，因此报告
生成序中第一个冲突头。DeriveSpec 钉死声明为集合上（「命名一个冒犯头」，DeriveSpec:75），
旗舰 `naive == production` 法则内部一致（两个闭包共享同一 sort+fold），因此此选择对照 naive
oracle 核实，而非对照冻结的 `nub` 序。

这**不是**分歧，因为无已发布世界在闭包期间产生 ⊥：`derive.json` 零矛盾用例，kin/div1 从不强制
冲突排他槽，因此 `check_closure_case` 的精确见证比较从不对照冻结行使，无轨迹可不同。在此
**预先**记录，使未来带 ⊥ 的 fixture 若其 Rust 见证不同于冻结，被读作此已知的名称序 vs nub 序
选择差异（仍集合上正确），而非误认为新鲜正确性分歧。若此类世界终有发布，此姿态升级为编号 DIV，
并对见证字段做比较器抑制。

## DIV-4 (S7)：`asRole` 通过重命名而非落地来重定向共现模板

**是什么**：`Prax.Witness.asRole` 是
`map (groundCondition (Map.singleton (intern "Witness") (VSym (intern v))))` ——
它经 `Prax.Query.groundCondition` 替换，其 token 往返经 `Prax.Db.tokens`，因此对畸形模板
**抛出**。Rust `prax_vocab::witness::as_role` 改为经 S4 的 `prax_core::types::rename_vars` 替换：
纯、无失败、保留运算符。

**为何**：`ground_condition` 需要 `&mut Interner` 并返回 `Result`。`as_role` 的每个调用者都是
`prax-vocab` 中的纯值构建器（`Rumor.gossip`、`Deceit.lie`、`Confession.confess`，以及
`Blackmail` 的 trigger 与 punish 条件），因此把 interner 与拒绝串过它会感染五个组合子签名——
及其调用者——为了无已发布模板能到达的可失败性。S7 设计 [S-I6] 裁定用 `rename_vars`，代价是
本条目、WitnessSpec 相等钉死、以及声明的契约。

**它们一致之处，经核实而非论证**：在冻结引擎上对已发布模板，以及对 [S-I6] 点名为要检查的
Subquery 绑定器形状——

```
HASKELL asRole "Hearer" [Match "…at.Actor!P", Match "…at.Witness!P"]
     -> [Match "…at.Actor!P", Match "…at.Hearer!P"]
HASKELL asRole "Hearer" [Subquery {subSet="Witness", subFind=["C"], subWhere=[Match "at.C!P"]}]
     -> [Subquery {subSet="Hearer", subFind=["C"], subWhere=[Match "at.C!P"]}]
```

两者由 `prax_vocab::witness::tests::as_role_agrees_with_ground_condition_on_every_shipped_template`
值对值复现，该测试把冻结实现（`Witness → VSym v` 绑定下的 `ground_condition`）建为 ORACLE，
并对照每个已发布 `CoPresence` 与每个已发布调用位点重定向到的角色上的 `as_role` 比较。

**它们不同之处，以及关闭它的契约**：

1. *可失败性。* `groundCondition` 拒绝以运算符结尾的模板句子；`rename_vars` 渲染畸形句子并继续。
   在冻结引擎上观察到：
   `asRole "Hearer" [Match "at.Witness!"] -> ERROR -> Prax.Db.tokens: trailing
   operator '!' in "at.Witness!"`。由 `the_two_implementations_differ_off_the_shipped_shape`
   双向钉死。无已发布模板畸形，且 `worldshape` 的 bodies 比较使每个世界的模板与冻结相同，
   因此畸形模板不能在无人注意下到达。
2. *替换规则。* `groundTokens` 只替换分词器分类为变量的段；`rename_sentence` 替换任何名称匹配的段。
   这些重合是因为被替换键是固定、大写的 `Witness`，总是变量——这就是为何键不是 `as_role` 的参数。

**声明契约**：替换 `v` **必须**是变量名。冻结函数替换 `VSym`，因此非变量替换产生不再量化的模板——
在任一实现下都是创作错误，但只有本实现会静默携带它。由
`as_roles_contract_the_replacement_is_a_variable` 断言，而非仅写下。

**虚构后果**：无。五个已发布调用位点都替换变量（`Hearer`，或受害者自身绑定变量），无已发布模板畸形，
且无已发布模板携带 Subquery 绑定器。

**比较器姿态**：无抑制。`as_role` 不被任何切片 3 世界到达（Bar 创作 `CoPresence` 但从不重定向）；
切片 4 的 Village 世界行使全部五个调用位点，其轨迹无裁定地比较。

## 已记录姿态（非 DIV）：到期到期按渲染名序触发

在回合边界（`roundBoundary`，规格 v44）引擎在任何到期规则**之前**触发每个到期。冻结引擎按
`Map [(Sym, Maybe Char)]` `Ord` 序迭代到期集——即 INTERN-ID 序，按每个标注路径首次被 intern
的时间交错——并在其上 fold 守卫的 `CDelete`。Rust 按**渲染名**序触发同一到期集
（`engine.rs` `round_boundary_impl` 在 `fire_due_expiries_in` 前按标注句子排序到期路径），
因为运行时用 `FxHashMap` 中的 `CompiledPath` 键 `expiries`，其迭代序按设计是偶然的
（S4 [S-panel I1]）；确定性契约于是把名称序命名为唯一可观察枚举序。

两种触发序到达**同一**状态，因此这是姿态注记，不是编号 DIV。到期触发**交换**：每个 `CDelete`
仅在其精确事实仍 `exists` 时触发（存在守卫），且子树撤回包含其后代——因此对任意两个到期路径，
无论不相交还是祖先/后代关系，任一序都恰好移除相同节点并留下相同队列。v50 时代的健全性注记
记录所有到期在任何规则读状态前触发，因此无规则能观察部分触发序。交换性钉为法则
（`engine.rs` `boundary_props::expiry_firing_commutes`：任意两触发序 → 同一
`labeled_facts`/`labeled_view`），且边界对 HashMap 偶然布局的不敏感端到端钉死
（`conformance/schedule_spec.rs` `round_boundary_is_insertion_order_insensitive`）。

这不同于同一边界的**规则**触发序，后者**是**可观察的且**是**契约：到期规则按**声明**序触发
（冻结 `cookedSchedule` 序；Rust `compiled.schedule` 序），由 ScheduleSpec 法则 8b
（`law_8b_due_rules_fire_in_declaration_order`）钉死。规则不交换——效果被同边界稍后规则读取的
周期-1 opener 必须先触发——因此名称序在那里会是**错的**；只有交换的到期撤回被重排。

保留条目用例被显式覆盖：祖先触发清除尚未到期后代的队列条目；因为到期条目在任何触发前离开队列，
无论到期集以何序触发，清除集相同——幸存队列，不仅幸存事实，是序无关的
（由混合寿命交换 proptest 钉死）。

## DIV-5 (S8)：`"memories"` 守护——其全部目的是大声——对显式 `null` 却沉默

**是什么**：`Prax.Script.Json` 的 `FromJSON Scene` **大声**拒绝携带预-v46 `"memories"` 键的场景对象，
因为否则解码器忽略未知键，针对已删除 memory 特性创作的脚本会在其内容被安静丢弃的情况下解码——
与 `Prax.Persist` 对存档的 v3 格式提升采取的同一「相同字节、不同含义」姿态。守护是
`hasMemories <- isJust <$> (o .:? "memories" :: Parser (Maybe Value))`
（`Json.hs:207`）。

aeson 的 `.:?` 把显式 JSON `null` 映射为 `Nothing`，恰如映射缺失键。因此守护对
`"memories": null` 不触发。在冻结解码器上测得：

```
{"id":"a","memories":[]}    -> Left "… Scene's \"memories\" field is no longer supported …"
{"id":"a","memories":null}  -> Right (Script {…, sceneId = "a", sceneOpening = "", …})
```

空洞恰好坐落在作者半删字段时最可能留下的 JSON 拼写上。

**Rust 做什么**：`prax_script::json` 的 `check_no_memories` 在**键存在**时触发，含 `null`。
Rust 拒绝冻结拒绝的严格超集，朝向守护所写的方向。

**规格权威**：守护自身声明的目的。其文档说它存在是为使预-v46 脚本不能「在该内容被安静丢弃的情况下」
解码——对抗静默丢键却自身对一种拼写沉默的守护，没有完成它所声明的工作。这是大声机制中的实现 bug，
不是契约：程序「Haskell bug 永不复现」的裁定干净地适用。

它在此远比相邻的忽略未知键行为更干净地适用，且两者不可融合。容忍未知键**是**冻结契约——
`deny_unknown_fields` 移植会拒绝冻结接受的前向兼容文件，那是严格性**分叉**问题（若有人的，是 S10 的），
不是卫生。Rust 精确复现忽略未知键（`prax_script::json::tests::unknown_keys_are_ignored_except_memories`）
并只加强那个声明工作是大声的守护。

**虚构后果**：无。无已发布文件以任何拼写携带该键（`grep -rn "emor" src/ app/ test/ examples/`
只找到守护及其自身测试），且若有，在任一引擎下都已是破损内容——差异是作者是否被告知。

**比较器姿态**：无抑制。分歧从任何轨迹不可达：它是解码时拒绝，且无已发布世界从携带该键的文件加载。
由 `conformance::script_json_spec::a_scene_json_carrying_a_removed_memories_field_is_rejected_loudly`
双向钉死，并排断言数组拼写（两侧引擎一致）与 `null` 拼写（两侧不一致）。
