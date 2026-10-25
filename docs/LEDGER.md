# 特性账本（Feature Ledger）

我们意图让 `prax` 支持的每一项能力，源自 Versu 论文与 Praxish。状态：
- **v1** — 第一里程碑（忠实引擎核心）。
- **v2** — 核心模型轮（情感与关系），构建为 `Prax.Core`。
- **v3** — 反应即实践与首个规范，构建为 `Prax.Reactions`。
- **v4** — 按 agent 信念（含错误信念），构建为 `Prax.Beliefs`。
- **v5** — 对话（说话者、话题、quips），构建为 `Prax.Conversation`。
- **v6** — 故事管理器（DM）作为元层 agent（酒吧 `director`）。
- **v7** — 角色弧（内部高层状态），构建为 `Prax.Arc`。
- **v8** — 查询语言中的一阶联结词（∀/∃/∨/→）。
- **v9** — 阵容移除 + 戏剧垂直切片（`Prax.Worlds.Intrigue`）。
- **v10** — QA 工具：检查器（`Prax.Inspect`）与压力测试（`Prax.Stress`）。
- **v11** — 持久化：存档/读档会话（`Prax.Persist`），CLI 存档 + 继续。
- **v12** — Prompter-lite 场景创作层（`Prax.Script`），把 CAST + 场景图剧本编译为实践，
  带自动流程图 + 场景覆盖；由 `Prax.Worlds.Play` 演示。剧本经可读 JSON（`Prax.Script.Json`）往返——
  可编辑创作格式，选择它而非定制解析器。
- **v13** — 玩家即 DM：人类占据戏剧管理器槽，用元层轻推引导自主阵容
  （`Prax.Worlds.Bar` 的 `barDirectorWorld`，`prax dm`）。
- **v14** — 一等道义 `should`/义务层（`Prax.Deontic`）：`□φ` 作为事实 `obliged.<who>.<φ>`，
  经 `!` 排他检测冲突，以及违反义务（`□□`）；酒吧结账现为真正义务。
- **v15** — 前向链 **派生层**（`Prax.EL` + `Prax.Derive`）：领域规则经论文的 `m(X)` 闭合到不动点，
  精确 `⊥` 检测，自动 `□`-提升（义务闭包），读路径上的可废止闭合 *视图*；`Prax.Worlds.Feud` 是涌现演示。
- **v16** — 静态 **合式性检查器**（`Prax.TypeCheck`）：对世界创作句子的未绑定变量、排他基数、
  悬空引用检查（`prax check`）。
- **v17** — 完成 #8 的 **ML 风格 sort 推断**：按成员声明 sort，经统一推断每个位置/变量 sort，
  报告冲突（`Prax.TypeCheck`）。
- **v18** — `Prax.Script` 中剩余的 **Prompter 编译特性**：memories（一次性说明）、定时 junction
  （场景时钟）、以及角色速写（关切→wants，特质→事实）。

> **翻译进度（zh-Hans）：** **全文已译。** 标题、版本图例导言（v1–v18）、详细条目 **v19–v54**（v31 起长条目为忠实摘要）、
> 特性表（核心逻辑引擎起）、待关闭的开放研究 / 待调查的未来想法 / 沙箱扩展 backlog 均为简体中文。
> 标识符、模块名、CLI、规格路径、表内 Source 列缩写（如 P§VI）及 Status 列版本号保留原文。

---

- **v19** — **量化结果**（`ForEach`，v8 条件量词的对偶）与 **创作目击**（`Prax.Witness`）：
  共现角色开始相信动作发生了，带 `.seen` 出处（自 v20 起多值——见下）；可观察性是作者陈述的语义属性，
  非自动事件日志。`Prax.Worlds.Village` 播种沙盒弧（`prax village`）。
- **v20** — **有源谣言传播**（`Prax.Rumor` 的 `gossip`/`heard`）：角色告诉共现听者其所持证据，
  以传闻出处种植同一事件信念。出处变为 **多值**（`.seen`/`.heard.<source>`，替换 v19 的排他 `!seen`），
  因此同一事件的目击与传闻共存而非一方覆盖另一方，且佐证（多个命名 `.heard.<source>` 边）可计数。
  `Prax.Worlds.Village` 成长：carol 自行传播偷窃；传闻许可 `eye … with suspicion`，从不 `confront`
  （仅目击）；世界创作的关系门禁让不信任关闭八卦通道。
- **v21** — **派生声誉**（`Prax.Repute` 的 `standing`/`standingUnless`/`regardedAs`/`notoriety`）：
  `regards.<observer>.<subject>.<label>` 从不存储，只从观察者证据（目击或传闻）*派生*——因此免费
  继承信息不对称与可废止性。地位由 **赎罪而非失忆** 击败：`standingUnless` 用 *基事实* 击败者守卫派生，
  一次插入消解每个 regard，而每个信念（事迹记忆）原样持续——且因信念从未消失，**再犯罪撤销击败者**，
  地位与臭名在重复时瞬间弹回。`notoriety` 把佐证变成阈值门禁的全局事实（创作世界参数）。
  `Prax.Worlds.Village` 完成其弧：偷窃 → 目击 → 谣言 → 三个 regards → 臭名把 bob 推向赎罪 → 村子让步——
  且因 planner 能看见弹回，面对补货摊位的已赎罪贼被 *威慑*，再不触碰。
- **v22** — **秘密与欺骗**（`Prax.Deceit` 的 `conceal`/`lie`）：隐瞒 want——无人相信某事迹
  （`Absent [Anyone.believes.<event>]`）——使 agent *经规划* 避免目击者：前瞻已模拟 v19 目击存入，
  因此等待隐私落在普通效用之外，无需潜行系统。谎言是无证据断言：`lie` 镜像 v20 的 `gossip` 并种植
  相同的 `.heard.<liar>` 传闻，因此捏造对除撒谎者外所有人与真相不可区分，且整个谣言/声誉栈（v20/v21）
  未修改地级联——听说自己的谎返回用普通八卦无缝替换谎言动作。`Prax.Worlds.Village` 获得反派：
  bob 隐瞒偷窃，等真正被看守的广场（独自走开不够——carol 守自己的岗；面包恰在 *有人* 照看时安全）；
  eve 出于创作恶意嫁祸 carol，且嫁祸恰如真相般落入 regard、冷落与臭名——结尾有诚实不公：被嫁祸的
  carol 无救济（弥补需要她从未拿过的面包；洗清需要真值事件记录——想法在此储备，后在 **v25 拒绝**：
  词汇拒绝伪造真值是声明承诺，非缺口；见下方 v25 的储备项重写）。
- **v23** — **现实前瞻：对被相信心智的回合漫步**（`Prax.Minds`、`Prax.Sight`、重写的 `Prax.Planner`；
  规格 `docs/specs/2026-07-10-v23-planner-realism-design.md`）。旧前瞻的 `worldValue`（现 **已删除**）
  对每个活角色每个动作取 max，按 *规划行动者自身 wants* 打分——三个已演示失败：推测性（把他人从不选择的
  动作记在其账上，例如 carol 的首选变成无证据指控）、全知（用 mover 的 *真* wants，因此秘密情节任何人
  可预见）、以及组合爆炸（v22 村庄套件：8.7s → 621s）。由回合漫步替换：actor 的 **认知范围**
  （`predictionScope`，v19 共现模板——默认所有人）内每个其他角色，按阵容序从 actor 对他们的
  **被相信** 模型（`predictMove`）得到一次短视、*仅有动机* 的移动，然后 actor 对自己下一选择递归
  （`scoreActions`、`pickAction`）。actor 无信念的心智，或范围外 mover，被建模为静止，从不「帮忙」——
  且模型可以 *错*（预测用 actor 的信念，非 mover 的真 wants）。欲望变得可命名且可相信（`Prax.Minds`：
  所有者参数化的 `Desire` 模板、`charDesires`；动机信念不变复用 v20 出处形状，因此八卦/谎/倾诉/遗忘
  都免费对 `desires.<owner>.<name>` 工作）；「公开」/「秘密」作为派生、可废止共同知识收回
  （`professed`/`conventional` → `.presumed`）而非标志。`Prax.Sight` 添加目击为普通地点信念
  （`believes.at`/`atSince`），由编译的每回合 ticker 维护（`turn!N`，v18 `_clock` 习语）——「谁在周围」
  本身是带创作视界的信息，非全局。Intrigue 的情节现为被相信心智（知情人的 cassia `predictMove` 预见下毒；
  受害者的不；泄露翻转它）。Intrigue 外需要两次世界编辑并诚实记在规格 §6：村庄的 `dana` 获得批准的
  磨坊锚定 want（与 `bob` 的摊位锚同一习语），酒吧的 `LoopSpec` 金标准轨迹回合预算从 20 重导出为 25
  （5 回合 × 因目击 ticker 多一人的阵容）——旁白本身未变。Master 套件：5.5s → 0.8s（重写自身加速）。
  真正裁判——v22 村庄套件一旦落在其上——直接证实：约 19s（`cabal test --test-options='--pattern
  "Prax.Worlds.Village"'`），从 621s 爆炸下降，>30× 恢复，处于 *原先* 爆炸前量级（8.7s）。
- **v24** — **事业：带休眠追求的分段实践**（`Prax.Project` 的 `endeavor`/`Stage`；规格
  `docs/specs/2026-07-11-v24-project-design.md`）。项目 *类型* 是创作词汇，像实践或欲望；
  `endeavor pid weight undertakeLabel gate stages` 把它编译为世界接入的三样东西：承担 `Action`、
  分段 `Practice`（每所有者一实例——承担两次再不提供）、以及按 `+weight` 计数完成阶段
  （`practice.<pid>.Owner.done.S`）的命名追求 `Desire`。进展本身是回报，因此视界长度不再重要——
  每个下一阶段对普通 planner 局部可见，无需前瞻变更；这是最终 **以已做模式关闭 #21 的运行时-want-注入
  问题** 的具体情形，非仅主张（见下方 #21 更新注记）：追求欲望 *休眠*——对尚无实例的已处置角色零绑定、
  零效用，而承担（普通 planner 选择）恰是「经插入事实注入 want」。因为追求是命名、可命名的欲望，
  事业自动是心智理论内容（`Prax.Minds`）：谁开始相信角色追求一个，就直接喂进 `predictMove`。
  `Prax.Witness` 的 `witnessed` 结果构建器提取为一等导出组合子（先前只折在 `observable` 内），
  以便生成阶段可在自身效果中携带公共可观察性——`Prax.Project` 需要这个，非新原语。
  `Prax.Worlds.Village` 在此收束自身道德弧：bob——自 v21 被威慑、自 v22 隐瞒——从干净 t=0 自由游玩
  起点从事 `earnBread`：在摊位承担、公开打扫广场、走到磨坊、取面粉、返回，并烘焙他不能再安全偷窃的面包，
  在每个更早轮次使用的同一运行世界第 32 回合完成。看着他打扫足以让村子了解其目的（一行推断公理对相信
  打扫者假定追求），且一旦他站在磨坊，`predictMove` 为持有该信念者具体预期面粉之行——短视地（在尚无阶段
  可用的广场无预测）且相对信念（共现、不信的 dana 预测无物，证明预测读预测者信念，非 mover 真状态）。
  机会主义保持诚实：项目中途，广场真正空时，偷窃（71.18）仍击败推进到下一阶段（50.46）——选择勤劳是因为
  被看着且安全，非因为诱惑停止得分。一次批准的测试修订（规格 §3）：「已赎罪的贼被威慑」把它陈旧的
  「bob 无面包」代理换成直接非再犯罪断言（`practice.earnBread.bob.done.s3`），因为事业现给 bob 合法面包，
  原代理无法预期。
- **v25** — **persona：特质即行为评价**（`Prax.Persona`；规格
  `docs/specs/2026-07-11-v25-persona-design.md`）。首稿（目标包特质——特质安装欲望）被 **拒绝**：
  施压下它不加真实物，因为承载者行为与直接赋欲望的角色相同。已发布模型改为评价 **行为**：`Trait`
  是承载者 *自身* 行为标记上的命名欲望包（`Trait "honest" [Desire "clean-conscience" (Want [Match "Owner.lied.…"] (-6))]`）——
  `personaVocabulary`/`bearing`/`cast` 把阵容特质接入欲望与事实，且 `transparent` 派生人人（可废止地，
  从 t=0）假定承载者评价。特质给逆行定价而非禁止——软 planner 的通常习语，无新强制。行为需要可评价之物，
  因此 `Prax.Deceit.lie` 获得一个结果：`Insert "Actor.lied.Hearer.<pat>"`，撒谎者对事迹的自身记忆，
  像所有心智状态一样根于其名下——**在撒谎者上的标记**，永非世界根真值记录（下方拒绝的储备洗清想法）。
  `Prax.Worlds.Village` 获得 **gale**，eve 的气质对照：两者携带相同命名 `spites-carol` 欲望，但 gale
  承载 `honest`，因此其良心（−6/谎）出价高于任何单次耳语买入（+4/头）——eve 耳语，gale 从不，且被告知
  两者恶意的预测者预测差异（`predictMove`）。**本轮标志性发现，在实现中浮现，非规格首稿预测**：
  eve 的耳语也欺骗 gale，且诚实信者结果是完美载体——gale 经普通 `gossip` 传播她现真心持有的虚假，
  无谎、无标记、无良心代价，甚至带回给 eve，把「证据」交给撒谎者自己的捏造。*诚实村民洗白谎言。*
  一旦现场观察到，规格就地修订（§4「洗白」），且 `VillageSpec` 钉死纠正主张。套件：292 测试
  （`PersonaSpec`、`DeceitSpec` 增补、`VillageSpec` 增补）。

-- **v26** — **planner 工作消除**（规格 `docs/specs/2026-07-11-v26-planner-work.md`）。
  带精确性契约的性能轮：planner 决策位对位同一，由金标准决策序列测试钉死（`Prax.GoldenDriveSpec`，
  变更前现场捕获，全程字节同一）。四处变更：闭合视图变为缓存在 `Prax.Engine.withDb`/`setAxioms`/`setDesires`
  后的按状态字段（每状态一次闭包，而非每村庄回合约 15k 次重算）；`Prax.Relevance` 跳过无创作动作可激励的预测
  （带极性的保守结果↔want 模式分析，建立在一条声明不变量上——实体名永不与谓词名字面碰撞；仅词汇的
  「它是否曾重要」检查——v33 后来在旁加入缺失的状态维度「它现在能否重要」——见 v33 图例行）；模式解析
  提升出绑定循环，配 token 级闭包循环（分词曾占运行时约 48%）；村庄测试共享两条确定性驱动轨迹，而非
  重模拟重叠前缀。无争用测量：完整套件约 726s（292 测试）→ **约 114s（301 测试）**，`Prax.VillageSpec`
  组约 580–660s → **约 116s**，一次剖析自由游玩回合 7.07s → 2.83s。残余 planner 代价是搜索访问的每个
  *不同* 状态一次公理闭包（回合后剖析的 71.8%）——v27 的目标（下方）。
- **v27** — **增量视图维护**（#17；规格 `docs/specs/2026-07-11-v27-incremental-view.md`）。精确性契约延续，
  带用户指定为本轮核心的更强网：`Prax.ViewInvariantSpec` 在真实驱动的每一回合后断言缓存的 `readView`
  等于从零闭包（标签忠实），并用篡改视图测试证明检查器能失败。现三层构建视图：公理看不见的 delta
  （`relevantDelta` vs 预分词 `axiomFootprint`，含驱逐阴影）锁步应用到基与视图，完全无派生；不击败任何物的
  无 `!` 插入（`monotoneInsert`：无否定体统一，`monotoneAxioms` 安全世界）经 `closureFrom` 增长
  *已闭合* 视图——在旧不动点再进入 `closure` 自身半朴素循环；其余全量重闭。评审在能触发前关闭真实分类器空洞：
  聚合绑定变量上的 `Eq`/`Neq` 是反单调的（恰好-k 随计数增长而熄火）——由探针证明，由 `aggVars` 跟踪拒绝。
  测量：从零闭包 11,840 → 每剖析回合约 330；回合 2.83s → **1.32s**（v26 起点 7.07s）；完整套件约 50–60s
  （本轮记录跑程的机器方差范围）。DRed 风格真值维护记为 **无必要**：从零闭包约占回合 5%，且延续正是
  DRed 会计算的 delta 派生。
- **v28** — **世界编译一次**（规格 `docs/specs/2026-07-12-v28-cooked-world.md`）。创作条件与结果每世界
  煮成 token 形式一次（`Prax.Query` 中的 `CookedCondition` 与 `queryCooked`——字符串求值器的逐 case 转写，
  由每个构造器上的等价性质钉死；`Prax.Cooked` 中的 `CookedOutcome`/`CookedPractice` 转换；容器在
  `Prax.Types`，像每个派生字段一样由 Engine 助手维护，`setCharacters` 加入助手族与 grep 门禁）。热路径
  端到端跑在名字上：`possibleActions`/`performCooked`（字符串 `performOutcome` 委托——一引擎两门）、
  planner 打分（煮熟 wants 上的 `evaluateCooked`）、以及闭包循环（预煮规则上的 `runCooked`）——而字符串
  `closure` 路径有意保留为 `Prax.ViewInvariantSpec` 每回合对照重算的独立参考。途中整合：驱逐阴影唯一归宿、
  杀死 applyGrow 字符串桥、`cpFns` 先胜修复潜伏的重复函数名查找不对称。测量：剖析回合 1.32s → **0.69s**
  （分配 2.2GB → 0.75GB）；完整套件约 55s → **约 22–30s**（320 测试）。回合后剖析顶部中心现为段 *比较*
  （`mayUnifyNames` 约 25%，`unifyNames` 约 25%）——intern 判据满足，指定 v29。
- **v29** — **段 intern**（规格 `docs/specs/2026-07-12-v29-interning.md`），以及诚实的持平。`Prax.Sym`
  （FastString 风格全局池；变量性打包进 id 奇偶；三个池门各带承重 bang，在实现发现两次惰性参数竞态、
  评审发现第三次之后）；`Db` trie 在 `IntMap` 上重键，每个 String 签名不变，并在旧 `Map String` 免费给出
  平局决胜名称序处显式恢复；`Val`/`Bindings`/煮熟管线端到端符号化。精确性保持（金标准字节同一，
  ViewInvariant 全程绿；DbSpec/ELSpec/QuerySpec 未触通过）。**测量结果：最好约 10%，在机器噪声内**
  （未剖析 A/B 回合 0.19–0.33s vs v28 的 0.22–0.36s；套件持平约 24–26s，329 测试）。v28 剖析的
  「段比较约 50%」归因有误导：代价是比较周围的列表遍历与分配——短段在首字符失败，几乎与 Int 测试一样便宜。
  记为本轮教训：成本中心份额把时间归因到函数，而非优化所瞄准的指令。保留（正确、经评审、略正，且是 v28
  「字符串停止成为计算」设计的一致终点）；下一真正杠杆是架构性的——delta 打分/undo-log 搜索，或最终嵌入移植——
  非表示。

- **v30** — **杠杆：敲诈与债务，已标价**（`Prax.Debt`、`Prax.Blackmail`；规格
  `docs/specs/2026-07-12-v30-blackmail-debt.md`，三轮内修正）。backlog 中最老的具名承诺（自 v22 起为独立设计轮而搁置），
  按用户指示与债务合并，规格写前现场探针验证（会话探针，深度 2）。**杠杆模型**：威胁是动机信念存款——`threaten`
  插入 `victim.believes.desires.<extorter>.<punitive-desire>.heard.<extorter>`，与倾诉/说谎已骑乘的同一信道（v20/v22），
  因此受害者自身的 round-walk 预测并标价曝光，无需新认知。**可信度为自我动机**（探针发现）：敲诈者的惩罚性欲望
  （`punishes-<id>`）是激励 *威胁本身* 的东西——若惩罚性欲望是真实的、敲诈者自己持有，受害者就相信它；否则威胁是空壳。
  不引入「恐惧」原语。**债务是对称杠杆**：`owes.A.B.thing` 是有向事实；`callIn`/`forgive` 是其两个出口；`Prax.Debt`
  用与敲诈相同的 `threaten` 形状，但惩罚性欲望由债务内容生成（「若不还则拿走 X」）。**定价**：受害者的 planner 在
  服从 vs 反抗上跑标准效用；服从插入 `pays`/`confesses` 等结果并清除威胁；反抗让威胁到期（或敲诈者兑现惩罚）。
  **会话形状**：`Prax.Blackmail.shakedown` 是一条实践，把威胁、支付、报复绑成一条动作链；村庄世界加入一条制裁复述弧。
  **保留变量守卫**：评审发现 `W`/`F` 与实践体变量碰撞会静默空操作公理——以响亮的 `reservedClash` 风格守卫钉死，
  与后续 v31 同类洞同一模式。**v25 搁置的「被抓说谎」项（规格 §6）部分落地**：不是测谎或内容暴露——仅低语 *行为本身*
  变为可观察（同场村民开始相信 *发生过* 低语，`witnessed together "whispered.Actor.Hearer"`），而 *说了什么*
  仍与先前一样秘密。这给敲诈以杠杆（carol 只需行为，永不需内容），但不是搁置项的完整形态——尚无人能抓住谎言实际声称了什么，
  只能抓住发生过低语。精确记下，以免被误认为更完整机制。

  套件：339（`Prax.Debt`）→ 354（`Prax.Blackmail`，含评审发现的保留变量守卫修复）→ 360（`Prax.Worlds.Village`
  的敲诈弧 + 一条制裁复述），全程绿；零警告；hlint 干净；全部 7 世界 `prax c- **v31** — **一条脊骨，两台生成器：派系与亲属**（`Prax.Faction`、`Prax.Kin`；规格
  `docs/specs/2026-07-12-v31-faction-kin.md`）。两 backlog 行按用户指示折叠，因共享一原语：**成员**。
  它是基、单槽事实 `member.<who>!<faction>`——加入、叛逃与嫁入皆同一 `!` 排他覆盖，非三机制。
  `comrades` 从共享成员派生 `allied.X.Y` 并 **保留名 `allied`**，故下游一切未修改地消费。**概括的证明**：
  `Prax.Worlds.Feud` 两手写 `allied.*` setup 换为三条户-`joins`，`FeudSpec` 五原测试字节未修改通过。
  `factionStanding` 扩展 v21 `standingUnless` 形状（信念门禁）但本轮未接线进世界；评审抓住保留变量碰撞，
  以响亮守卫修复，钉弑亲与受害者自我信念。`Prax.Kin`：`kinAxioms` 纯派生；`wed` = 婚姻 + 成员 `!`；
  `succession` 排他职衔。婚礼拍：esme 嫁入 `kestrel`，派生同志与恩怨，驱动疏远。所存：多重归属、
  持有继承、出生、离婚动作、`factionStanding` 村庄接线。套件绿；村庄金标准未搅动。

- **v32** — **告白与赦免：归路真实，且变窄**（`Prax.Confession`；规格
  `docs/specs/2026-07-12-v32-confession.md`）。标记告白时转换价而非删除（v48 清偿动词成参数）。
  告白经带源传闻自证其罪；赦免可拒绝；`incorrigible` 把 notoriety Count 指向内。形状问题：标记内容形 vs
  站队行为形——`confess` 取两模式参数。村庄：eve 向 gale 无代价告白；赦免溶解站队信念持久；再犯弹回过阈值；
  向 carol 告白弧测量后未发货（结构天花板）。自由游玩 100 回合 eve 从不告白；§25 被构陷者不公未触及。

- **v33** — **状态条件相关性**（规格 `docs/specs/2026-07-13-v33-live-relevance.md`）。
  v26 的相关性预过滤仅从词汇推理——「是否曾有任何动作能改善此类 want？」——v32 的 `confess` 使该问题对每个
  良心欲望永久为真，即使在几乎每个实际状态仍可靠也全世界花费跳过。本轮加入缺失维度：**它现在能否重要？**
  两活性配方，由 `Prax.Relevance.livenessOf` 每世界分类一次，planner 按状态跳过已死 want。与 v26 词汇检查并立。
  精确性保持；村庄自由游玩测量加速。

- **v34** — **预测复用——及其诚实限度**（规格 `docs/specs/2026-07-13-v34-prediction-reuse.md`）。
  用户从测量分支统计导向：70 村庄自由游玩回合（深度 2 的 60 次 NPC 选取）同选取代价
  **深度 0 为 89ms，深度 1 为 2.3s，深度 2 为 44.5s**——每前瞻层约 20–26×，纯递归分支。闲聊低语模板占树大部。
  同选取内兄弟后状态预测常相等——复用缓存。诚实限度：效果不透明（`groundedDeltaAnchors` 为 `Nothing`）时
  不复用。精确性金标准保持。

- **v35** — **意图：再考虑语义替换总是深思**（`Prax.Types` `Intention` + `PraxState` 上 `intentions`
  运行时字段；`Prax.Planner.motiveSignature`；`Prax.Loop.npcAct`；规格
  `docs/specs/2026-07-13-v35-intentions.md`）。**自 v26 精确性时代开始以来本轮首次接受的语义变更**——用户导向：
  「代理人不会每几秒规划潜在低语秘密——每步总考虑每种可能不现实且很浪费。」三探针奠基再设计。代理人持有意图；
  仅当动机签名变化时再考虑。测量：深度 2 村庄自由游玩大幅加速，决策仍忠实。

- **v36** — **衰减与漂移：时钟上的情节状态**（`Prax.Drift`；规格
  `docs/specs/2026-07-14-v36-drift.md`）。用户导向，评审在一行代码前锐化范围，两拒绝。原「分数冷却向基线」
  （**恩怨冷却**）被拒绝：倾向（恩怨、行为标记、信任、站队）永不衰减——只经行为改变（告白、赦免、补偿、
  已建 v20–v21 机械）——因定时器抹去会破坏补偿非失忆。本轮建造的是情节状态漂移：场景耐心、情绪寿命等已在
  调度上；漂移把可创作衰减规则接到同一时钟。精确性对非漂移世界保持。

- **v37** — **日历与集会：时钟召集，全镇到场**（`Prax.Drift` `gathering`；`Prax.Relevance` 重分类；规格
  `docs/specs/2026-07-14-v37-gatherings.md`）。用户导向（所存项：周期时钟门禁场景孵化——使闲聊渗滤的混合动力学），
  现场探针后落地。集会是调度规则孵出的同场事件：到点时世界在地点断言集会事实，角色 want 被吸引到场。
  与 v36 漂移同骑引擎时钟。相关性重分类使集会相关 want 仅在集会活着时存活。村庄演示：定期市集/铃召。
  精确性对无集会世界保持。

- **v38** — **机遇与感受：戏剧骰，及使用它的情绪**（`Prax.Rng`；`Prax.Emotion`；`CalcOp` 的 `Mod`；规格
  `docs/specs/2026-07-15-v38-chance-feelings.md`）。用户导向，设计评审时重框：情绪多复用既有机械（情节事实 +
  欲望标价、v36 脉冲消退、Reactions 事件上下文），故本轮真正新物是 **戏剧骰**——`Roll`/`draw`，冻结骰法则
  （每次抽取花费一步，无论命中与否），未播种世界响亮错误。`Mod` 补全整数算子。情绪获得有寿命感受助手
  （`feelFor`/`feelTowardFor`）。种子是创作世界参数。

- **v39** — **断言端点：trie 学会哪些节点是事实**（`Prax.Db`；`Prax.EL`；`Prax.Persist`；规格
  `docs/specs/2026-07-15-v39-asserted-endpoints.md`）。用户导向，作 BUG 类优先于新内容：`Db` trie 无法区分
  作为事实断言的内部节点与仅作更深事实脚手架的节点，双侧剪枝/序列化因此漂移。节点获断言标志；`insert` 断言端点；
  `retract` 急切剪无断言无孩子祖先。`leq`/`meet` 按断言性扩展。`dbToLabeledSentences` 往返保留端点与脚手架。
  Persist 切到标签忠实格式。

- **v40** — **卫生机械变量：一命名空间，一守卫**（`Prax.Types`；`Prax.Drift`；`Prax.Rng`；`Prax.Sight`；
  `Prax.Faction`；`Prax.Confession`；`Prax.Blackmail`；`Prax.Relevance`；`Prax.Repute`；规格
  `docs/specs/2026-07-15-v40-hygienic-variables.md`）。用户导向四奠基通行之首——严格改进（优雅/可用性升、
  bug 面缩）。引擎拼接作者片段时的变量碰撞曾静默空操作公理。统一：`Prax` 命名空间保留给机械；
  `authoredVarClash`/`authoredPatClash` 在消费点响亮拒绝。各创作组合子迁入该守卫。

- **v41** — **一个分析表面：世界模型分析读煮熟形式**（`Prax.Derive`；`Prax.Relevance`；`Prax.Engine`；
  `Prax.Query`；规格 `docs/specs/2026-07-15-v41-one-analysis-surface.md`）。四奠基通行之二。缺陷：静态分析
  分裂在平行行走器上（字符串侧与煮熟侧），漂移风险。统一：footprint/活性/可改善欲望/可产生原子等皆读
  `cookedRules`/`CookedCondition`。字符串 `closure` 保留为 ViewInvariant 独立参考。

- **v42** — **死条件 lint：标记世界永不能满足之物**（`Prax.Relevance`；`Prax.TypeCheck`；规格
  `docs/specs/2026-07-15-v42-dead-condition-lint.md`）。四奠基通行之三。`producibleAtoms` 限界世界终可包含的一切；
  类型检查器旗标条件/欲望中永不可满足的匹配。无法限界时保守沉默。与 v33 活性（状态）互补：本轮是词汇/可达性。

- **v43** — **卫生捆：六个小洞，响亮关闭**（`Prax.Engine`；`Prax.Db`；`Prax.Cooked`；`Prax.Persist`；
  `Prax.Drift`；`Prax.Sight`；`Prax.Rumor`；`Prax.Deceit`；`Prax.Clock`（新）；`Prax.TypeCheck`；规格
  `docs/specs/2026-07-15-v43-hygiene-bundle.md`）。四奠基通行之末。六洞含：重复函数名、尾随运算符插入、
  时钟缺失沉默、漂移规则卫生、目击/闲聊/说谎边界等——各以响亮构建时或检查时错误关闭，而非静默。
  `Prax.Clock` 抽出回合时钟助手。套件与 `prax check` 全绿。

- **v44** — **调度：时间属于引擎，不属于世界**（`Prax.Types`；`Prax.Engine`；`Prax.Schedule`（新）；
  `Prax.Loop`；`Prax.Script`；`Prax.Persist`；规格 `docs/specs/2026-07-16-v44-the-schedule.md`）。范式轮：
  周期规则与一次性寿命从世界 ticker 角色迁入引擎 `roundBoundary`——推进时钟、先触发失效再触发调度规则、
  从现在重装周期。`InsertFor` 寿命；`setSchedule` 创作门；剧本故事规则经编译器门。开局已饱约定。
  感知/漂移/集会改骑调度。阵容不再含 ticker。Persist 序列化 dues。精确性金标准重捕获一漂移行（世界变更）。

- **v45** — **受保护族：一守卫，一表，非 `turn` 白名单**（`Prax.TypeCheck`；`Prax.Types`；`Prax.Script`；规格
  `docs/specs/2026-07-16-v45-protected-families.md`）。保留命名空间写入族统一表驱动：仅机械可写
  `turn`/编译器族等；创作表面经类型检查响亮拒绝。威胁模型：作者 vs 机械。为 v46/v53 编译器自有族铺路。

- **v46** — **叙述者死去，并带走旁白**（`Prax.Engine`；`Prax.Script`；`Prax.Script.Json`；`Prax.Persist`；
  `Prax.Stress`；规格 `docs/specs/2026-07-16-v46-the-narrator-dies.md`，经面板重写两次）。故事管理不再是
  阵容中的叙述者角色：场景转移与结局编译为安静的引擎调度规则（`registerEngineRules`），无 actor、无旁白堆积。
  世界自身动力学安静触发；只有角色动作作为虚构呈现。`memories` 呈现层移除（非世界内容）。Stress/flow 仍报告场景覆盖。

- **v47** — **函数注册表：函数得真实归宿，Practice 失去虚假归宿**（`Prax.Types`；`Prax.Engine`；`Prax.Cooked`；
  `Prax.Relevance`；`Prax.TypeCheck`；`Prax.Core`；`Prax.Script`；`Prax.Worlds.Bar`；规格相关）。自本轮起
  `Practice` 不再携带函数——实践局部性是虚构，解析始终全局。`defineFunctions`/`cookedFns` 为唯一归宿；
  重复 `fnName` 响亮。相关性/类型检查读注册表。Bar 世界迁移。

- **v48** — **无辜者不课税；杠杆晋级**（`Prax.Derive`；`Prax.Engine`；`Prax.Relevance`；`Prax.Types`；
  `Prax.Confession`；`Prax.Stress`；`Prax.Reactions`；`Prax.Worlds.Bar`；`Prax.Emotion`；`Prax.Worlds.Village`；
  规格 `docs/specs/2026-07-17-v48-generality-bundle.md`）。捆束：无辜路径不再付分析税；告白清偿动词成创作参数；
  杠杆相关一般性清理为 v49 胁迫原语铺路。多模块卫生与村庄/酒吧回归保持绿。

- **v49** — **胁迫：杠杆骨架成原语；敲诈为其薄实例**（`Prax.Coerce` 新；`Prax.Blackmail`；新 `CoerceSpec`；规格相关）。
  四动作协议、动机信念存款与惩罚性欲望升为内容无关的 `Coercion`/`coerce`（证据可选——保护勒索是无证据实例）。
  `shakedown` 保持 v30 签名并组合一 `Coercion`。测试契约从精确分数转向六设计性质（拖延永不主导、观众放大恐惧、
  重复榨取不可能等）。旧小数仅作比较基线。

- **v50** — **机械状态离开 db：骰进引擎，场景戳进虚无**（`Prax.Rng`；`Prax.Types`；`Prax.Engine`；`Prax.Cooked`；
  `Prax.Relevance`；`Prax.TypeCheck`；`Prax.Persist`；`Prax.Script`；`Prax.Query`；`Prax.Script.Json`；
  `Prax.Worlds.Village`；规格 `docs/specs/2026-07-18-v50-machinery-state.md`）。RNG 流位置（`rngSeed`）与
  场景耐心等机械不再伪装成可查询世界事实；骰是引擎状态，`SeedlessDraw` 静态捕获。场景耐心仍经寿命事实但编译器族保留。
  Persist 知引擎字段。

- **v51** — **提升离开引擎：□-提升是内容，普查是检查器的网**（`Prax.Deontic`；`Prax.Derive`；`Prax.Engine`；
  `Prax.Relevance`；`Prax.TypeCheck`；`Prax.Types`；`Prax.Worlds.Village`；`app/Main.hs`；规格相关）。
  `obligedClose`/`obligedLift` 留在道义内容层；引擎 `retable` 不再决定提升——已展开公理列表煮入 `cookedRules`。
  类型检查器普查负责捕获遗漏提升。威胁模型：内容 vs 引擎机械。

- **v52** — **计划即部分集：事业失去光标，完成账本成状态**（`Prax.Project`；`Prax.Worlds.Village`；
  `Prax.ProjectSpec`；`Prax.RelevanceSpec`；`Prax.VillageSpec`；规格
  `docs/specs/2026-07-19-v52-plans-as-part-sets.md`）。事业部分独立并行完成，非线性链；无进度光标——
  已完成部分事实之集即状态。`partAfter`/`partNeeds` 为结构边与资源门。追求欲望休眠至承接。村庄 `earnBread`
  与测试契约迁移到部分集语义。

- **v53** — **引擎规则出处：混合层门关闭，编译器自有族加入保留表**（`Prax.Types`；`Prax.Engine`；`Prax.Script`；
  `Prax.TypeCheck`；`app/Main.hs`；`Prax.TypeCheckSpec`；`Prax.ScheduleRuleSpec`；规格
  `docs/specs/2026-07-19-v53-engine-rule-provenance.md`）。`registerEngineRules` 记录所装名到 `engineRuleNames`；
  类型检查查阅出处，使机械可写保留编译器族（如 `currentScene`、耐心标记）。创作门与编译器门分离最终钉死。

- **v54** — **胁迫加入调度范式：两标记永久变成创作寿命，可信度成三可检查世界状态**（`Prax.Coerce`；
  `Prax.Blackmail`；`Prax.TypeCheck`；`app/Main.hs`；`Prax.CoerceSpec`；`Prax.TypeCheckSpec`；规格
  `docs/specs/2026-07-19-v54-coercion-time.md`）。`complied`/`threatened` 等标记经 `InsertFor` 风格寿命创作；
  `Nothing` 为永久。重复敲诈周期（购买期到期后勒索再榨取）无新逻辑——清偿 v30 所存连环敲诈项。
  可信度暴露为可检查状态而非仅打分形状。

- **v55** — **编年史家 / 显著性查询：宿主只读表面**（`Prax.Chronicle`；`app/Main.hs`；`Prax.ChronicleSpec`）。
  从不写入——扫描基库 `.seen`/`.heard.<src>` 信念与闭合视图 `regards`/`notorious`，产出事件记录、显著性阈值、
  任务钩（`RegardHook`/`NotoriousHook`）与涌现问答（`askChronicle`）。CLI：`prax chronicle [world] [query…]`。
  清偿 Tier-3 ⤷K 编年史家；嵌入 API（`step/inject/query`）仍等宿主。

- **v56** — **站队的分数效果反应**（`Prax.Repute`；`Prax.ReputeSpec`）。`scornStanding`/`esteemStanding`
  把派生 `regards` 门禁为一次性关系分调整（`adjustScore`），`scorned`/`esteemed` 一次守卫防反复；`scornDesire`
  给 NPC 自动取 scorn 的命名欲望。与 `Prax.Reactions` 同风格——普通实践动作，世界须已注册 `coreFns`。
  清偿 v21 / Tier-1 声誉所存「站队的分数效果反应仍未建」。

- **v57** — **事业放弃：拆卸成创作动作**（`Prax.Project`；`Prax.ProjectSpec`）。`abandon pid label`
  子树删除 `practice.<pid>.Actor`（账本一并清除），重新打开承接——与既有拆卸／进食周期契约相同，现为可创作组合子。
  清偿 Project 所存「放弃」残余；合作项目与类型综合仍存。

- **v58** — **公开告白：一对多**（`Prax.Confession`；`Prax.ConfessionSpec`）。`confessPublic` 转换 *一桩*
  标记，并向每位同场听者经普通传闻通道存款（`ForEach` + `asRole`）；独自告白仍转换标记、无存款。
  与 `confess` 同形守卫。清偿 Confession 所存「公开告白」；累犯入性格、祭司角色、补赎义务仍存。

- **v59** — **对他心可见：出示情感**（`Prax.Emotion`；`Prax.EmotionSpec`；`app/Main.hs`）。`express`/
  `expressToward` 在感受成立时提供沟通 affordance，经 `Prax.Witness.witnessed` 把 `Actor.feels.<emotion>`
  （或带 `.toward.Target`）存为同场者的普通 `.seen` 信念——自愿出示，非自动广播；别处角色无信念。
  不收缩其他实践的决策空间（模块不变量仍钉死）。附带：`esteemStanding` 缺口测试；CLI `prax help`
  列出世界与 `chronicle`/`check`/`stress` 等工具。清偿情感所存「对他心可见」。

- **v60** — **情感强度 + esteem 欲望 + 编年史感受查询**（`Prax.Emotion`；`Prax.Repute`；`Prax.Chronicle`）。
  `feelAt`/`feelTowardAt` 在感受下挂排他 `intensity!N` 叶；`intensityAtLeast`/`intensityTowardAtLeast`
  供定价门禁（仍不收缩其他实践决策空间）。`esteemDesire` 对称 `scornDesire`。`askChronicle "feelings of <who>"`
  列出基库情节情感（只读）。清偿情感所存「强度等级」；每感受消退戳、每情绪周期仍存。

- **v61** — **离婚动作**（`Prax.Kin` `divorce`）。把既有「撤回婚姻」契约暴露为可创作动作；双边删除，成员不变。

- **v62** — **出生**（`Prax.Kin` `birth`/`birthInto`）。亲子基事实；`birthInto` 一并 `joins` 家庭派系。

- **v63** — **带寿命强度**（`Prax.Emotion` `feelAtFor`/`feelTowardAtFor`）。`InsertFor` 断言感受，强度叶随子树撤回清除。

- **v64** — **补赎义务**（`Prax.Confession` `penance`/`atone`）。薄骑 `Prax.Deontic.oblige`/`discharge`；清偿告白所存「忏悔者侧补赎义务」。

- **v65** — **多重次级归属**（`Prax.Faction` `affiliate`/`unaffiliate`/`affiliateComrades`）。多值 `affiliate.who.faction` 与排他主效忠并列；清偿「多重归属」。

- **v66** — **宿主嵌入 API**（`Prax.Host` `step`/`inject`/`queryFacts`/`available`）。薄封装既有引擎入口；清偿 Tier-3「嵌入 API」最小表面。

- **v67** — **持有物继承**（`Prax.Kin` `bequeath`）。镜像 `succession`：死亡 + 亲子门禁，作用于 `holds.<thing>!<holder>`。

- **v68** — **情绪默认寿命**（`Prax.Emotion` `defaultLifetime`/`feelDefault`/`feelTowardDefault`）。按情绪词创作默认消退戳。

- **v69** — **派系领导**（`Prax.Faction` `appointLeader`/`deposeLeader`/`isLeader`）。排他 `leads.<faction>!<who>`；职衔以外领导。

- **v70** — **地点作用域义务**（`Prax.Deontic` `obligeWhenAt`/`isObligedWhenAt`/`dischargeWhenAt`）。`obliged.<who>.whenAt.<place>.<content>`。

- **v71** — **宿主嵌入增强**（`Prax.Host` `stepExact`/`availableActions`/`queryView`）。精确标签、完整落地动作、闭合视图只读。

- **v72** — **合作事业**（`Prax.Project` `endeavorCrew`/`enlist`）。crew 门禁使合伙人推进同一 Owner 账本；清偿「合作项目」。

## 核心逻辑引擎

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 1 | Trie 世界状态 DB（全部状态 = 句子） | v1 | P§VI | `newtype Db = Db (Map String Db)` |
| 2 | `.` 多值下降 | v1 | P§VII | |
| 3 | `!` 排他（单值，清除兄弟） | v1 | P§VII | **修复 Praxish bug** — 清除兄弟，保留孩子子树 |
| 4 | 前缀 = 对象；按前缀删除子树 | v1 | P§VII | `retract` |
| 5 | 统一 / 模式匹配（变量 = 大写） | v1 | Praxish `db.js` | 绑定上的列表单子 |
| 6 | 查询算子：not / eq(赋值) / neq / lt·lte·gt·gte / calc / subquery | v1 | Praxish `praxish.js` | 类型化 `Condition` ADT |
| 7 | 完整 FOL 查询：∀, ∃, ∨, → | v8 | P§VII | `Prax.Query` `Or`/`Absent`/`Exists` + `forAll`/`implies`；可自由嵌套 |
| 8 | 静态类型推断 / 检查器（ML 风格） | v16–17 | P§VII p.120 | `Prax.TypeCheck` `typeCheck`。**v16**（无声明、可靠）：未绑定变量、排他基数一致性、悬空 `Call`/孵化引用。**v17**（ML 风格 *排序* 推断）：排序由成员声明（`PraxState` 上的 `sorts`），每位/变量排序经 union-find 推断并报告冲突（agent-vs-gender）。每个已交付世界检查干净；酒吧声明 `beverage`/`place`/…；`prax check`。排序检查是保守类型系统（可能拒绝真正多态位；仅声明单形态） |

## 实践与动作

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 9 | 实践作为一等可实例化对象 | v1 | P§VIII | `process.<id>.<roles>` |
| 10 | 角色无关实践（任意阵容填角色） | v1 | P§VIII | 可重玩性关键 |
| 11 | 动作：条件 + 结果（insert/delete/call） | v1 | Praxish | |
| 12 | 实践 `data`、孵化时 `init`、`functions`/`cases` | v1 | Praxish | （v47 起函数迁出 Practice） |
| 13 | 并发实践；选项 = affordance 并集 | v1 | P§V | 从循环自然落下 |
| 14 | 构成性 affordance（仅实践内可用） | v1 | P§VIII | |
| 15 | 规范：违规标记后置条件 + 规范欲望 | v3 | P§VIII-D | `Prax.Reactions` `markViolation`/`violationOf`；强负 want ⇒ planner 避开 |
| 16 | 反应作为实践（由动作结果孵化） | v3 | P§X | `Prax.Reactions` `spawnReaction`/`endReaction`；`disapprovalP`；回应链 |
| 17 | 动作语言中的条件效果 / 域公理 | v15 | P§VIII | `Prax.Derive`：域规则 `body → head` 前向链至不动点（论文的 `m(X)`），在 `Prax.EL` 上，**半朴素**求值（仅对新派生事实触发——规模上约比朴素快 8×）；读取见闭合 **视图**（`readView`），可击败（派生从基重算）且可选（`axioms=[]` ⇒ 不变）。义务闭合（DEON 性质 1）是创作声明，非引擎自动提升：道义世界把 `Prax.Deontic.obligedClose axs` 传给 `setAxioms`，引擎像其他规则一样前向链所声明的 □-提升孪生——引擎不持有道义词汇（v51 把提升移出 `Prax.Derive`；可产生世界省略闭合时由 #8 的 `DeonticUnclosed` 旗标）。精确 `⊥` 检测。演示：`Prax.Worlds.Feud`（`bigFeud n` 放大） |

## 代理人与动作选择

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 18 | 基于效用的反应式选择（应用-求值-撤销） | v1 | P§IX | 不可变性 ⇒ 无显式撤销 |
| 19 | 每角色 want；效用 = Σ 修饰 × #绑定 | v1 | P§IX-A | Versu 忠实；取代 Praxish 全局目标 |
| 20 | 对照信念心智的 round-walk 前瞻，带折扣（自身 0.9 / 他人 0.5） | v1, v23 | Praxish `planner.js`（v1）；重设计（v23） | `Prax.Planner`。**v1** 的 `worldValue`——对每个存活角色每个可用动作取最大，按 *规划行动者* 自有 want 打分——**已删除**：它是投机的（把他人永不选择的动作记功）、全知的（用行动者 *真实* want）、组合爆炸。**v23**：`scoreActions` 在行动者认知 `predictionScope`（默认所有人）内对每个其他角色恰预测一次，短视地，从行动者对其的 **信念** 模型（`predictMove`，`Prax.Minds`）——仅当该移动严格改善该信念相对无所作为（不预测无动机移动）——在行动者之后按阵容轮转序，在行动者递推自有下一选择之前。`depth` 仍只计行动者自有未来 ply；CLI/循环保持深度 2 |
| 21 | Want 作为任意逻辑句子（∃/∀ 欲望） | v8\* | P§IX-A | 由 #7 解锁——want 现为任意 FOL 公式；运行时 want 注入无需独立机制（门禁于事实的 want 可通过插入事实注入）。**v24 工作模式关闭**：`Prax.Project` 的追求 `Desire` 对尚无项目实例的已配置角色休眠（零绑定、零效用），承接——普通 planner 选择——插入打开它的事实；bob 的 `charDesires = ["pursues-earnBread"]` 永久携带倾向，仅在他据此行动后存活 |
| 22 | 角色弧 / 内在性（高层内部选择） | v7 | P§X | `Prax.Arc`；bex 的希望→归属/孤独弧门禁其 want；逆欲望转变仅玩家 |
| 23 | Swaygent 风格意志/影响选择 | 需研究 | Praxish `swaygent.js` | Ensemble 启发的替代选择器 |

## 核心模型（情感 / 关系 / 信念）

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 24 | 情感（Ekman，单槽，记住目标+原因+先前） | v2 | P§X | `Prax.Core` `setMood`；情绪 `!`-覆盖 + `priorMood` |
| 25 | 角色求值关系（多重、非对称、带理由） | v2 | P§X | `Prax.Core` `adjustScore`；`A.relationship.B.role.score!N`/`reason!Why` |
| 26 | 公开对称关系状态 | v2 | P§X | `Prax.Core` `setBond` 写两侧序 |
| 27 | 信念：共享世界 + 按议题分歧 | v4 | P§X | `Prax.Beliefs` `believe`/`believesThat`/`forget`；`X.believes.<issue>!V` |
| 28 | 量化 / 嵌套信念 | 需研究 | P§XI | Versu 自身也做不到 |
| 29 | 对话：说话者、话题、quips（模板 + 效果） | v5 | P§X / ES blog | `Prax.Conversation` `quip`/`changeSubject`；说话者轮流；quips 移动核心模型与信念 |

## 故事管理与创作

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 30 | DM / 故事管理器作为特殊实践 | v6 | P§VI, XI | 酒吧 `director`：绑定元层 agent，带故事级 want；注入对立 |
| 31 | 玩家即 DM | v13 | P§XI | `Prax.Worlds.Bar` `barDirectorWorld`：人类绑定到元层 `direct` 实践；CLI 经 `candidateActions` 仅提供其实践 affordance。`prax dm` |
| 32 | 剧本可读序列化（JSON） | v12 | P§VII-VIII | `Prax.Script.Json`：`Script` 与 JSON 往返；`prax play <file.json>`、`prax dump-play`、`examples/play.json`。（相对定制 `.prompter` 解析器的选择。） |
| 33 | Prompter 风格剧本前端（scene/beat/junction → 实践） | v12,18 | P§XII | `Prax.Script`：CAST + 场景图 eDSL、`compile`、自动 `flowChart`；无体叙述者触发 junction。**v18** 加入延期编译特性：**memories**（v46 移除呈现）、**定时 junction**（`after`/`timeout`）、**角色素描**（`concernedWith`/`withTraits`）。可读文本表面有意省略——JSON（#32）顶替 |
| 34 | 道义 `should` / 义务算子；规范冲突解析 | v14 | DEON 2010 | `Prax.Deontic`：`□φ` = 事实 `obliged.<who>.<φ>`；经 `!` 排他塌缩检测冲突（性质 2）；违约复用 `violated.…`；违反义务（`□□`）经嵌套义务；行为耦合靠 Want，planner 不变。解析是 *涌现*（效用）。蕴涵闭合（性质 1）现为 Deontic 自有（v51）：`obligedClose`/`obligedLift`。剩余缺口：无自有 `m(X)`/LRT 机械（那是 #8）。依据：`docs/research/deon-notes.md` |

## 运行时、工具、UX

| # | 特性 | 状态 | 来源 | 备注 |
|---|---------|--------|--------|-------|
| 35 | CLI 菜单循环（act / more）、旁白 | v1 | P§V UI | |
| 36 | 轮转回合循环 | v1 | Praxish `app.js` | |
| 37 | 确定性回放 / 重放 | v10 | P§VI | 纯循环 ⇒ 可复现轨迹（金标准重放）；会话中存档/继续经 `Prax.Persist`（v11） |
| 38 | 运行时检查器（「为何 X 为真 / 前置为何失败」） | v10 | P§VI | `Prax.Inspect` `explain`/`firstFailing`（复活 `killsPerStep`） |
| 39 | 压力测试线束（多次自动游玩） | v10 | P§VI | `Prax.Stress`——播种随机全 AI 跑程；结局 + 动作覆盖 + 死胡同；**场景覆盖**（v12）；CLI `prax stress` |
| 40 | 可序列化世界状态（存档/加载） | v11 | P§VI | `Prax.Persist`（事实 + cursor）；精确往返；游戏内 `s` 存档 + `resume` |
| 41 | 丰富分支多角色剧集（内容） | v9 | P§XII | `Prax.Worlds.Intrigue`：谋杀、角色死亡（阵容移除）、背叛/忠诚/共谋结局、恋情。`Prax.Worlds.Play`（v12）重铸为 2 场景剧本 |
| 43 | 阵容移除（死亡 / 驱逐） | v9 | P§VIII-D | `dead.<name>` 事实；`Prax.Types.livingCharacters`；循环/planner 跳过死者 |
| 44 | 编年史家 / 显著性查询（宿主只读） | v55 | 沙箱 Tier-3 | `Prax.Chronicle`：从信念出处与派生站队生成事件摘要、显著性阈值、任务钩与 `askChronicle` 问答；CLI `prax chronicle`。只读——永不写入 DB |
| 45 | 宿主嵌入 API（step/inject/query） | v66–v71 | 沙箱 Tier-3 | `Prax.Host`：`step`/`stepExact`/`inject`/`queryFacts`/`queryView`/`available`/`availableActions` |
| 46 | 持有物继承（bequeath） | v67 | 沙箱 | `Prax.Kin.bequeath`：死亡+亲子门禁，`holds.<thing>!<holder>` |
| 47 | 合作事业（endeavorCrew） | v72 | 沙箱 | `endeavorCrew`/`enlist`：共享 Owner 账本 |
| 42 | 基于嵌入的 PWIM 自由文本玩家输入 | 需研究 | arXiv 2406.00942 | 外部模型依赖 |

## 待关闭的开放研究
- 仅 **#42**（PWIM 自由文本输入）仍需研究，且是外部模型依赖，非待获取论文。
- **DEON 2010 论文**（`references/papers/EVAIEL.pdf`，精炼于 `docs/research/deon-notes.md`）已获取并完全应用：它奠基道义层 #34（v14）与 `m(X)` 派生闭合 #17（v15）。#8 的类型检查器（v16–17）结果只需句子结构分析，非完整 LRT 判定过程。

## 待调查的未来想法
- **派生层的增量视图维护（#17）** *（完成 — v27：无关 delta 快路径 + 单调插入延续；见图例行）*。有意未建者：非单调残余的 DRed 风格真值维护——测量后无必要（v27 后从零闭包约占剖析回合 5%；延续已计算支持跟踪会做的 delta 派生）。仅当未来世界公理混合把 reclose 份额推回时再访——ViewInvariant 网使任何此类尝试可安全尝试。
- **阵容增长下的 planner 运行时（v25）— 大体由 v26 解决。** v25 回归经 v26 剖析为决策无关工作主导；v26 精确消除后套件约 114s。残余是现实主义忠实代价 × 每不同前瞻状态一次闭包——增量视图项（#17，指定 v27）是剩余杠杆。
- **动作选择的硬优先级层（出自 Praxish `swaygent.js`）。** Ensemble/CiF 风格标签 `forbidden`/`required`/`normal`，排序 *高于* 数值效用。我们的 planner 与规范皆 *软*。借入层级会给道义层（#34，v14）**硬** 规范强制。等有演示的软规范失败再定。
- **运行时 want 注入（#21）** — *非* 奠基：门禁于事实的 want 可通过插入事实注入（v24 工作模式）。
- **局部性作用域动作发现 / 细节层次** — 在有大世界可剖析前过早。

## 沙箱扩展 backlog（头脑风暴 2026-07-10）

目标框架：**大阵容、长时间沙箱**，玩家是众代理之一；**仅符号**（无外部模型——PWIM #42 保持搁置）。这些皆 *超越 Versu*。除非标为奠基，各编译到既有层，可孤立取舍。**K 是拱**：Tier 1–3 多叠其上（标 ⤷K）。

**K. 目击 / 事件存款**（`Prax.Witness`）*（完成 — v19：引擎中 `ForEach` 量化结果；`Prax.Witness` 创作可观察性；`Prax.Worlds.Village` 种子，CLI `prax village`）*。动作执行时，同场角色获得持久 *它发生了的信念*；别处角色没有。

Tier 1 — 社会事实，叠在 K 上：
- **⤷K 谣言 / 带源传闻**（`Prax.Rumor`）*（完成 — v20）*：`gossip`/`heard`；多值 `.seen`/`.heard.<source>` 出处；不信任门。目击后又听说者边并存而非覆盖。
- **⤷K 声誉**（`Prax.Repute`）*（完成 — v21；v56 分数效果）*：`standing`/`standingUnless`/`regardedAs`/`notoriety`——补偿非失忆；再犯从记忆弹回。`incorrigible`（v32）把 Count 惯用语指向内。`scornStanding`/`esteemStanding`/`scornDesire`（v56）把站队接到关系分。
- **派系与成员**（`Prax.Faction`）*（完成 — v31；v65 次级归属）*。所存：地点作用域道义规范集（v70 已给通用 `obligeWhenAt`）、`factionStanding` 村庄接线。职衔以外领导于 v69 清偿。
- **债务与人情**（`Prax.Debt`）*（完成 — v30）*：`owe`/`settle` 薄骑 `Prax.Deontic`；目击违约 → 老赖站队；债务人自有不可避免自我 regard。
- **亲属与家庭**（`Prax.Kin`）*（完成 — v31；v61 离婚；v62 出生）*：`kinAxioms`、`wed`、`divorce`、`birth`/`birthInto`、`succession`。年龄于 v73、长子继承于 v78 `primogeniture` 清偿；持有继承于 v67 `bequeath` 清偿。

Tier 2 — 长时间跨度的代理内在性：
- **项目 / 事业**（`Prax.Project`）*（完成 — v24；v52 部分集重构；v57 放弃）*。所存残余：类型综合。合作项目于 v72 `endeavorCrew`/`enlist` 清偿。
- **性格 → 意志**（`Prax.Persona`）*（完成 — v25）*：特质即行为估值；gale/eve 对照。
- **⤷K 秘密与欺骗**（`Prax.Deceit`）*（完成 — v22）*：`conceal`/`lie`；构陷级联；被构陷者无救济。
- **事实真相事件记录与洗清** *（拒绝，v25）*：历史仅经其留下的标记持久；真理恢复须经标记持有者——告白、证词——从不经咨询。告白半在 v32 到达；carol 仍无救济。
- **告白与赦免**（`Prax.Confession`）*（完成 — v32；v58 公开告白；v64 补赎）*。累犯入性格于 v74 `bearFromRegard`、解除欺骗于 v80 `liftDeceit` 清偿；祭司/族长薄门禁于 v86 `absolveAsLeader` 清偿。
- **敲诈**（`Prax.Blackmail`）*（完成 — v30；v49 升为 `Prax.Coerce` 实例；v54 寿命/连环）*。虚张/威胁到期/反敲诈于 v54 清偿。
- **重复 / 连环敲诈** *（v30 存；v54 完成）*：`coComplianceLasts`。
- **反事实放置（按 agent 世界观）** *（v23 存，诚实残余）*：预测仍在真实位置模拟，非预测者所信位置——完整按 agent 世界观整批延期。
- **目击新近显著性** *（设计拒绝 — 用户决定）*：硬窗口即意图模型；勿再提案。
- **衰减与漂移** *（完成 — v36）*。
- **情感** *（完成 — v38；v59 对他心可见；v60 强度；v63 带寿命强度）*。基线心境于 v79 `setMood` 清偿；情绪周期/心境一致启动仍存。每情绪默认寿命于 v68 清偿。
- **日历与集会** *（完成 — v37）*。节庆内容与多同时集会仍出范围。

Tier 3 — 宿主游戏边界：
- **⤷K 编年史家 / 显著性查询**（`Prax.Chronicle`）*（完成 — v55）*：事件流上的派生摘要——任务钩生成，以及无人能见的涌现之答；CLI `prax chronicle`。
- **嵌入 API**（`Prax.Host`）*（完成 — v66；v71 增强）*：`step`/`stepExact`/`inject`/`queryFacts`/`queryView`/`available`/`availableActions`。

奠基观察名单（高门槛；当前皆不紧急）：硬优先级层（上方）——等演示的软规范失败；增量视图维护（上方）——Tier 1 放大公理 × 阵容，故先测量再决定；局部性动作发现 / 细节层次——在有大世界可剖析前过早。明显 *非* 奠基：运行时 want 注入（#21）——门禁于事实的 want 可通过插入事实注入。

## v73 — Kin 年龄叶（setAge / ageAtLeast）

- **做了什么**：排他 `@age.<who>!<n>@`；条件 `ageAtLeast who n`（Match+Cmp Gte）供成年门禁。
- **测**：KinSpec setAge exclusive / rejects。

## v74 — Persona bearFromRegard

- **做了什么**：公理：任何人将 O 视为 `label` → 派生 `trait.O.<traitName>`（累犯入性格）。
- **测**：PersonaSpec derives / rejects dotted。

## v75 — Rumor gossipPublic

- **做了什么**：一对多告知（ForEach 听者），镜像 confessPublic；跳过主体与 Actor。
- **测**：RumorSpec deposits heard for every co-present hearer。

## v76 — Debt forgive

- **做了什么**：债权人动作：门禁 `debt.Actor.Debtor.<content>`，Delete 债务 + discharge 债务人。
- **测**：DebtSpec forgive clears debt and obligation。

## v77 — Chronicle leads-of / affiliates-of

- **做了什么**：`askChronicle` 查询首领与次级归属（`dbToSentences` 展平 `!`→`.`）。
- **测**：ChronicleSpec leads-of and affiliates-of。

## v78 — Kin primogeniture

- **做了什么**：长子继承 office——死亡持有者的存活子女中，无更年长者时 Actor 取得持有（需 `setAge`）。
- **测**：KinSpec primogeniture awards office to eldest living child。

## v79 — Emotion mood 基线心境

- **做了什么**：排他 `@mood.<who>!<emotion>@`；`setMood`/`clearMood`/`inMood`。与情节 feels 并存，不收缩决策空间。
- **测**：EmotionSpec setMood exclusive baseline。

## v80 — Confession liftDeceit

- **做了什么**：门禁于 `Actor.<kind>.H.<mark>`，Delete 听者对虚构事件的信念子树（解除欺骗；标记本身保留，可与 confess 搭配）。
- **测**：ConfessionSpec liftDeceit retracts hearer's fabricated belief。

## v81 — Chronicle debts-of

- **做了什么**：`askChronicle "debts of <who>"` 列出涉及 who 的债务事实（债权人或债务人）。
- **测**：ChronicleSpec debts-of。

## v82 — Debt callIn

- **做了什么**：债权人催债——`demanded.Actor.Debtor.<content>` + `breach Debtor breachLabel`。
- **测**：DebtSpec callIn marks demanded and breaches debtor。

## v83 — Project unenlist

- **做了什么**：Owner 将 Partner 移出 `@practice.<pid>.Actor.crew.Partner@`。
- **测**：ProjectSpec unenlist removes partner from crew。

## v84 — Faction transferLeadership

- **做了什么**：现任首领禅让给同派 Heir（排他 `leads` 覆盖）。
- **测**：FactionSpec transferLeadership。

## v85 — Host queryChronicle / explainActor / livingCast

- **做了什么**：薄封编年史查询、Inspect.explain、存活阵容名列表。
- **测**：HostSpec queryChronicle and livingCast and explainActor。

## v86 — Confession absolveAsLeader

- **做了什么**：赦免另需 `@leads.<faction>!Actor@`（祭司/族长薄角色）。
- **测**：ConfessionSpec absolveAsLeader requires faction leadership。

## v87 — Kin 关系条件

- **做了什么**：`isChildOf` / `isSiblingOf` / `isMarriedTo`。
- **测**：KinSpec relation conditions。

