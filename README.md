# prax

用 Haskell 重实现 **Versu**（Richard Evans 与 Emily Short 的模拟主义叙事系统），
自 **Praxish**（Max Kreminski 对 Versu 的 *Praxis* 语言的 JavaScript 重建）向上构建。

引擎把社交世界建模为 **排他逻辑（exclusion logic）** 中的一组句子，配有提供基于角色的
affordance 的 **社会实践（social practices）**，以及按效用选择动作的 **自主 agent**。
见设计文稿：

- `docs/research/versu-notes.md` — Versu 架构，出自 2014 IEEE 论文。
- `docs/research/praxis-praxish-notes.md` — 排他逻辑 + Praxish 参考实现。
- `docs/LEDGER.md` — 完整特性账本（已构建、已计划、以及研究阻塞项）。

## 状态

**v1（忠实引擎核心）完成。** 引擎端到端跑通可玩的酒吧故事世界。

- `Prax.Db` — 排他逻辑 trie：`insert`（带**纠正后的 `!` 语义**，修复 Praxish `db.js` 中的
  数据丢失 bug）、`retract`、`unify`、`ground`。
- `Prax.Query` — 类型化条件语言（match、否定、eq/neq、数值比较、calc、count、子查询）。
- `Prax.Types` / `Prax.Engine` — 实践/动作/结果作为 eDSL；动作发现、执行、实践孵化 + `init`、
  以及守卫函数调用。
- `Prax.Planner` — 基于效用的反应式选择：按角色 wants、apply-and-evaluate、折扣前瞻。
- `Prax.Loop` / `Prax.Worlds.Bar` / CLI — 轮转回合与菜单驱动的酒吧演示。
- `Prax.Core`（v2）— Versu 核心模型：关系（数值、不对称角色评价）。情感（`Prax.Emotion`，v38；
  **v59** `express`/`expressToward` 经普通目击通道向同场者出示感受；**v60** `feelAt` 强度叶）作为多值情节事实共存，并按时钟消退，
  替换原先的单槽情绪。接入酒吧，使互动改变情感、情感经
  定价而非门禁改变行为（温暖门禁的「买酒」affordance；冷落给烦躁定价，使被得罪的酒保不愿倒酒，
  而非不能倒）。
- `Prax.Reactions`（v3）— 反应即实践与规范：动作孵化提供响应（回礼 / 回绝 / 见怪）的反应实践，
  规范违规（赖账酒保）孵化不赞成。NPC 回避违规，因为 planner 对违规→不赞成的未来打分差。
  机制（孵化/消费/违规标记）自身不发布内容；现成的 `disapproval` 反应与其唯一消费者
  `Prax.Worlds.Bar` 同住（**v48** — `Prax.Reactions` 不再持有已发布世界内容）。
- `Prax.Beliefs`（v4）— 可相对共享世界分歧的按 agent 信念。谣言植入可能为假的信念；相信某人
  怨恨自己的角色即使实际温暖很高也不会友善；证据可驱散信念。
- `Prax.Conversation`（v5）— 带选定说话者、轮流与话题的对话。Quips 是对话行，其效果经核心模型
  与信念流动（闲聊、恭维、以及植入信念的闲话）。朋友一旦温暖会自行攀谈。
- **故事管理器（v6）** — 酒吧的 `director` 是 Versu 的 Drama Manager：无身体、只有*元层*欲望的
  自主 agent。它监视房间过于融洽，并在两个朋友间注入失和，然后让自主阵容演完——「DM 只是一种
  特殊类型的实践。」
- `Prax.Arc`（v7）— 角色弧：角色内部高层状态（希望 → 归属 / 孤独），门禁其 wants，因此推进弧
  重塑其追求。逆欲望变换（放弃）向所有人提供但效用 planner 从不采取——因此「真正转变」在实践上
  只属于玩家。
- 一阶查询联结词（v8）— `Prax.Query` 中的 `Or`/`Absent`/`Exists` + `forAll`/`implies`，
  使前置与欲望可为析取/量化。
- 阵容移除 + `Prax.Worlds.Intrigue`（v9）— 角色可死亡并离开阵容；分支戏剧剧集端到端核实
  Versu 风格戏剧。
- `Prax.Inspect` + `Prax.Stress`（v10）— QA 工具：解释动作为何不可用的检查器（`explain`），
  以及播种的压力测试器，玩许多随机全 AI 局并报告结局、动作覆盖与死胡同
  （`cabal run prax -- stress [world]`）。
- `Prax.Persist`（v11）— 存档/读档会话（世界状态即全部事实）。游玩中按 `s` 存档；
  `cabal run prax -- <world> resume` 从存档继续。
- `Prax.Script` + `Prax.Worlds.Play`（v12）— **Prompter-lite** 场景创作层。戏剧写成剧本——
  `CAST` 加上 `scene` 图，每个带 `beat` 体（对话/affordance）与 `junction`（结束故事或交给
  下一场景的标注路由）——并 `compile` 为普通实践加**一条安静的引擎调度规则**，在回合边界
  触发 junction/结局（**v46**：替换原先每回合假动作的无身体 *narrator* 角色——虚构经角色动作
  呈现，调度不是其一）。`flowChart` 渲染场景图（`cabal run prax -- flow`），压力测试器报告
  场景覆盖。`Prax.Worlds.Play` 是 `Prax.Worlds.Intrigue` 的*忠实*重写——同一阵容、affordance
  （倾诉、下毒、警告、自毒、浪漫）与结局——作为两场景剧本，创作行数少约 25%，*加上*该层免费
  提供的场景转换与流程图。场景层还编译 **定时 junction**（`after`/`timeout`——进入后 N 回合
  的场景转换/结局：进入场景武装**耐心标记**，引擎的到期调度在截止时撤回，耐心耗尽时触发
  junction）以及 **角色速写**（`concernedWith` 把关切变为欲望；`withTraits` 把性格记为可查询
  事实），来自 Prompter 的创作构造（v18）。（Prompter 的 **memories**——触发首次成立时开火的
  一次性说明——也在 v18 构建，但在 v46 **移除**：无说话者的全知旁白是呈现特性而非世界内容，
  因此根本不编译而非迁居。）场景*边界*被场景本地 beat 包含，可读文本剧本有意由 JSON 替换。
  `Prax.Worlds.Audience`（`prax audience`）在一个短场景中行使两个剩余构造：野心公爵对地位的
  *关切*使他不请自来地讨好国王，若你不及时提出请愿（`granted`），观众超时（`dismissed`）。
- `Prax.Script.Json`（v12）— 剧本经**可读 JSON**（`Prax.Script.Json`）往返，即可编辑的创作/
  交换格式（选择它而非维护定制 `.prompter` 语法）。`cabal run prax -- dump-play` 打印内置剧本
  为 JSON；`cabal run prax -- play examples/play.json` 加载并玩编辑后的。见 `examples/play.json`。
- **玩家即 DM（v13）** — 人类可占据 Versu 的戏剧管理器槽而非角色。在 `barDirectorWorld`
  （`prax dm`）中你是 *director*：绑定到元层 `direct` 实践，你的菜单是作者性轻推——煽动竞争、
  点燃温暖、投下阴影——覆盖自主阵容（ada、bex、cai），他们随后经普通社交机制演完后果。
  （绑定实践的玩家只被提供其实践的 affordance，经 `candidateActions`。）
- `Prax.Deontic`（v14）— 一等 **道义「应当」/义务** 层，植根于 Evans 的
  *Exclusion Logic as a Deontic Logic*（DEON 2010；精炼于 `docs/research/deon-notes.md`）。
  义务 `□φ` 只是事实 `obliged.<who>.<φ>`（论文的 `Ob:φ` 糖——无新语义）；规范**冲突**经 `!`
  排他检测（不兼容义务塌缩为 ⊥），由效用 planner *涌现*解决，**违反义务（contrary-to-duty）**
  是迭代 `□□`（违约后的修复义务）。酒吧的「结账」现为真正义务：上酒升起它，小费解除它，
  赖账违约并创建弥补义务。
- `Prax.EL` + `Prax.Derive`（v15）— 用于涌现世界的 **前向链派生层**。领域规则（`body → head`）
  经 DEON 论文的 `m(X)` 构造在忠实 Exclusion-Logic 格（`Prax.EL`：`meet`/`leq`，矛盾时精确 `⊥`）
  上闭合到不动点。读取经 **可废止闭合视图**（`readView`）：派生从基重算，从不持久化，因此撤回前提
  即消解其结论——且是可选加入（`axioms = []` 使世界不受触动）。`□` 下的义务闭包（DEON 性质 1）
  是道义世界选择加入的 **创作声明**（`Prax.Deontic.obligedClose`），不是引擎自动——检查器标记
  能调用义务却忘记声明它的世界。`Prax.Worlds.Feud`（`prax feud`）是演示：从*一个*创作的过错
  与一把规则，整场世仇涌现（从未谋面者经联盟网络怨恨某人）并在弥补时消解。（v31 折入第四条规则——
  见下方 `Prax.Faction`——用派生的家族成员替换演示的手写联盟纽带，未修改测试证明概括成立。）
- `Prax.TypeCheck`（v16–17）— 静态 **类型检查器**（`prax check [world]`），Versu 的隐式类型系统。
  无声明、健全层标记 **未绑定变量**（前置无法绑定的 outcome/公理-头变量——静默空操作）、
  **排他基数冲突**（关系同时断言 `!` 与 `.`）、以及 **悬空引用**（对未定义物的 `Call`/孵化）。
  之上是 **ML 风格 sort 推断**：声明每个基 sort 的成员（世界上的 `sorts`——酒吧声明
  `beverage`/`place`/…），经统一推断每个位置与变量的 sort 并拒绝冲突（性别出现在 agent 处）。
  每个已发布世界检查干净。像任何类型系统它是保守的——你只声明想检查的单型位置。
- `ForEach` + `Prax.Witness`（v19）— **量化结果**：`ForEach [Condition] [Outcome]` 对其条件的
  *每个*绑定应用其子结果（入口时取快照，因此对一个绑定的变更从不改变其他哪些存在）——v8 的对偶，
  v8 量化条件但留下单数结果。`Prax.Witness` 把它编译为 **创作可观察性**：`observable` 声明动作的
  公共外观，每个共现非行动者开始相信它发生了（`<W>.believes.<event>.seen`，`.seen` 边记录直接观察
  出处；从 v20 起多值，见下，因此与同一事件的传闻证据共存）。可观察性是作者陈述的语义属性——
  未声明动作（如移动）不存信念，保留欺骗稍后将利用的看起来/实际差距。`Prax.Worlds.Village`
  演示它：bob 在广场偷面包；carol 与你都在场，开始相信并可对质他；dana 在磨坊，不能。
- `Prax.Rumor`（v20）— **有源谣言传播**：`gossip`（按事件模式创作，像 `observable`）让角色告诉
  共现听者其所持证据，以传闻出处（`.heard.<teller>`，每源一边）种植同一事件信念，旁于任何 `.seen`
  边——出处现为 **多值**，因此同一事件的目击与传闻共存，证据累积而非一方覆盖另一方，且 `heard`
  （对源的布尔 ∃）使佐证可计数。传播是 want 驱动，非自动：爱八卦角色被创作为 want 他人知道它所知道的，
  普通 planner 携带消息。`Prax.Worlds.Village` 成长：carol 目击 bob 偷窃后自行传讯；传闻许可怀疑
  （`eye … with suspicion`，较轻信任打击）但从不对质——那保持仅目击——且世界创作的关系门禁让不信任
  关闭八卦通道。
- `Prax.Repute`（v21）— **派生声誉**：无人*存储*地位。`regards.<observer>.<subject>.<label>`
  是公理派生事实，直接读自观察者证据（目击或传闻皆然），因此免费继承信息不对称，并在其支持消解时
  瞬间消解。`standingUnless` 用*基事实*击败者击败它，而非删除信念——是赎罪，非失忆，因此事迹记忆
  幸存，即使它曾支持的地位消失；再犯罪只是撤销击败者，地位从无人丢失的记忆弹回。`notoriety`
  把佐证变成阈值门禁事实——创作的世界参数（`notoriety "thief" 3` 意即「全村皆知」）——且它*驱动*
  行为：bob 的羞耻键于成为村中*臭名昭著*的贼，而非任一人的轻蔑。`Prax.Worlds.Village` 在此收束弧：
  偷窃 → 目击 → 谣言 → 三个 regards → 臭名把 bob 推向还面包 → 村子让步，记忆全程完好——且因为 planner
  能看见重复时地位弹回，已赎罪的 bob 被*威慑*，余下跑程中不动补货摊位。**v56** 补上站队的分数效果反应：
  `scornStanding`/`esteemStanding` 门禁于 `regards`，一次性调整关系分。
- `Prax.Chronicle`（v55）— **编年史家 / 显著性查询**：Tier-3 宿主只读表面。扫描 `.seen`/`.heard.<src>`
  信念与派生 `regards`/`notorious`，产出事件摘要、显著性阈值、任务钩与涌现问答（`askChronicle`）。
  CLI：`prax chronicle [world] [query…]`（含 `feelings of <who>`，v60）。从不写入。**v59** 起 `prax help` 列出世界与工具子命令。
- `Prax.Host`（v66）— 宿主嵌入：`step`/`inject`/`queryFacts`/`available`。
- `Prax.Kin` v61–v62：`divorce`、`birth`/`birthInto`；`Prax.Faction` v65：`affiliate` 多重次级归属；`Prax.Confession` v64：`penance`/`atone`；`Prax.Emotion` v63：`feelAtFor`。
- `Prax.Deceit`（v22）— **秘密与欺骗**：隐瞒是创作，非机制——`conceal` 是 want 无人相信某事迹
  （`Absent [Anyone believes <event>]`）；planner 前瞻已模拟 v19 目击存入，因此珍视秘密的 agent
  *经规划*避免被看见——等房间空落在效用之外，无需也未建潜行系统。谎言（`lie`）是无证据断言：
  它镜像 `gossip`（v20）并种植相同的 `.heard.<liar>` 传闻，因此捏造对除撒谎者外所有人与真相不可区分——
  受骗者持有真证据，若撒谎者听说自己的谎返回，谎言动作消失，普通八卦无缝取而代之。整个谣言/声誉栈
  （v20/v21）对虚假恰如对真相般级联。`Prax.Worlds.Village` 获得反派：bob 隐瞒偷窃，等真正被看守的
  广场（面包恰在*有人*照看时安全——玩家独自走开不够，因为 carol 守自己的岗）；eve 出于创作恶意
  嫁祸 carol，且嫁祸恰如真相般落入 regard、冷落与臭名——结尾有诚实不公：被嫁祸的 carol 无救济
  （弥补需要她从未拿过的面包，洗清需要本词汇有意没有的真值事件记录）。玩家得到与 eve 相同的耳语 affordance。
- `Prax.Minds` + `Prax.Sight` + 重写的 `Prax.Planner`（v23）。旧前瞻的 `worldValue` ——对每个活角色
  每个动作取 max，按*规划行动者自身 wants* 打分——被**删除**：结果是推测性的（把他人从不采取的动作
  记在其账上——carol 的首选变成她无证据的指控）、全知的（用 mover 的*真* wants，因此秘密策划的谋杀
  任何人可预见）、以及组合爆炸（村庄压力套件从 8.7s 退化到 621s）。由回合漫步替换：actor 认知
  *范围*内（`predictionScope`，世界创作，默认所有人）的每个其他角色，按阵容序得到一次短视、有动机的
  移动，从 actor 对它们的*相信*模型（`predictMove`）预测——从不从真模型——然后 actor 对自己下一选择
  递归。actor 无信念的心智，或当前无法定位的 mover，静止，从不「帮忙」。欲望现可命名且可相信：
  `Prax.Minds` 给世界所有者参数化的 `Desire` 词汇（`charDesires`），动机信念不变复用 v20 出处形状——
  八卦、撒谎、倾诉与遗忘都对 `desires.<owner>.<name>` 工作，零新机制；「公开」与「秘密」作为*派生*、
  可废止共同知识（表白的欲望，或约定假设的）落下，而非标志。`Prax.Sight` 使位置本身成为信念：
  周期-1 调度规则，由引擎在每回合边界运行（v44），对照引擎时钟刷新共现目击，因此预测已离开房间者
  意味着从你上次看见他们处预测，带创作的猜测时效视界。`Prax.Worlds.Intrigue` 的情节现为被相信的心智：
  知情人的 cassia 预测预见下毒；不知情受害者的不；泄露其动机的谣言翻转这一点。Master 自身测试套件
  作为重设计副作用从 5.5s 降到 0.8s。真正的裁判——v22 的村庄套件，落在其上——证实：约 19s
  （从 621s 爆炸下降，>30× 恢复，回到原先爆炸前量级）。
- `Prax.Project`（v24）— **事业（endeavors）**：创作的项目*类型*（`endeavor`/`Part`）编译为
  承担动作、每所有者一实例且部件为*集合*的实践，以及直接奖励每个完成部件的命名追求欲望，
  因此长项目无需 planner 变更——每个可用部件是普通局部效用，欲望对任何已处置角色*休眠*
  （零绑定、零效用）直到承担打开它，这是「门禁在事实上的 want 可由插入事实注入」的已做实例。
  计划是部件集合，非线性链：部件独立并行完成，成功不必全完成，因此完成部件事实集即状态，无进度光标——
  拓扑是创作的，`partAfter` 命名必须先完成的兄弟部件（经验证的结构边），`partNeeds` 携带世界资源与
  阈值门禁。因为追求是命名、可相信的欲望，被目击的部件免费成为心智理论内容。bob 的救赎在此收束村庄弧：
  自 v21 被威慑、自 v22 隐瞒，他不提示地从事诚实工作，公开打扫广场，赚——而非偷——自己的面包，
  而村子只靠看着他工作就了解其目的。
- `Prax.Persona`（v25）— **气质即行为评价**：`Trait` 捆绑承载者*自身*行为标记上的欲望，而非目标——
  `honest` 给撒谎标记定价而非禁止撒谎，因此若算术曾有利，承载者仍可撒谎。行为需要可评价之物，
  因此 `Prax.Deceit.lie` 获得一个结果：撒谎者对事迹的自身记忆（`Actor.lied.Hearer.<pat>`）——
  在撒谎者上的标记，永非世界根真值记录。`transparent` 派生人人从一开始就假定承载者的评价，
  因此被相信的气质在预测中与被相信的动机对冲。`Prax.Worlds.Village` 获得 gale，eve 的对照：
  相同命名恶意，但 gale 的良心出价更高，因此 eve 耳语而 gale 从不——且，现场发现而非创作，
  eve 的耳语也欺骗 gale，后者随后经普通八卦传播她真心相信的虚假，无谎、无标记，作为「证据」
  带回给 eve 自己的捏造。诚实村民洗白谎言。
- `Prax.Debt` + `Prax.Blackmail`（v30）— **杠杆，已定价**：债务是带受益人的义务（`owe`/`settle`），
  违约是信念门禁的赖账地位，威胁是动机信念存入（`shakedown` 的威胁/服从/违抗/揭露），受害者自身
  回合漫步定价——勒索者可信是因为威胁表白的惩罚欲望被真正持有，而非因为它预测服从。
  `Prax.Worlds.Village` 的 carol 在阈值恐惧（镜像 bob 的 `notorious.bob.thief` 的非线性 want）使单次
  被目击耳语落地臭名所需三个 regards 中的两个时勒索 eve；同一恐惧使 eve 成为一次性撒谎者，
  在自由游玩 alone 再也达不到时，在强制续写下重述 v25「诚实村民洗白谎言」发现。由 planner 自身前瞻
  发现，非为设计：无守卫的重复威胁可无限再榨取沉默，一旦守卫关闭，把连环勒索作为真实未来机制储备。
  v49 再奠基：`shakedown` 成为 `Prax.Coerce` 的薄实例，内容无关的威胁/服从/违抗/惩罚原语，证据可选
  （烧谷仓的保护费是另一实例）——上述算术仍字节对字节复现，但测试契约现为设计性质
  （拖延永不主导、重复榨取保持不可能、…），非那些小数。
- `Prax.Faction` + `Prax.Kin`（v31）— **一条成员脊骨，两个生成器**：两个 backlog 行因共享一个原语而折叠。
  `member.<who>!<faction>` 是基、单槽事实——加入、叛逃、婚入都是同一 `!` 排他覆盖。`comrades`
  从共享成员派生 `allied.X.Y`，保留 `allied` 名使每个既有消费者无需变更——经把 `Prax.Worlds.Feud`
  重构其上证明：两个手写成对 `allied.*` setup 事实消失，替换为三个家族成员，`FeudSpec` 的 5 个原测试
  字节未修改地通过。`kinAxioms` 是纯派生（婚姻对称、兄弟姐妹、祖父母、单向姻亲），撤回安全且带
  设计的不对称：解散婚姻取消派生其姻亲，但成员本身不，因为 `wed` 的转移是基移动，非派生。
  `wed joiner faction spouse` 把婚礼编译为婚姻事实加一次成员覆盖；继承对职位复用同一排他习语，
  已故持有者的任何子女可主张单槽。`Prax.Worlds.Feud` 的婚礼 beat：esme，在自身单成员家族中惰性，
  婚入世仇的 `kestrel` 家族并继承其对 alice 的怨恨——planner 第一次就让她不提示地冷落 alice。
  本轮村庄未触（金标准字节同一）；`factionStanding`（经派系同伴的信念门禁 regard）规格测试发布但
  未接入任何世界，是声明且延期的决定。
- `Prax.Confession`（v32）— **归路真实，且变窄**：撒谎标记转换为坦白标记（永不删除，因此特质仍可
  给残余定价；解除动词自 **v48** 起是创作参数——已发布世界传 `"confessed"`，但否认/吹嘘/承认适配
  同一机制），坦白经八卦已骑的同源传闻通道自我牵连，赦免是单独、可拒绝的第二方行为，插入世界自身
  地位击败者。赦免者的耐心（`incorrigible`）把 `Prax.Repute.notoriety` 自身计数习语指向内——
  受够是她所*相信*的，非记账 tally。`Prax.Worlds.Village` 的 eve 向 gale 坦白，gale 已因直接目击耳语
  把她看作诽谤者，且无成本；向真正受害方 carol 坦白经探测与测量在任何创作慷慨下从不击败 eve 的基线——
  planner 自身对*预测*赦免的折扣封顶可达成救济。归路关闭撒谎者自身良心与地位，从不关闭第三方嫁祸：
  carol 仍无救济。**v58** 加 `confessPublic`：一对多，转换一桩标记并向每位同场听者存款。
- **v26 — planner 工作消除**：精确性契约性能轮（金标准决策序列测试钉死每个 planner 选择，前后字节同一）。
  缓存的按状态闭合视图、跳过无创作动作可激励的预测的保守相关性预过滤（`Prax.Relevance`）、一次分词的
  查询/闭包内部、以及共享测试轨迹：完整套件从约 726s 降到约 114s，零行为变更。
- **v27 — 增量视图维护**：缓存的世界视图可证明地自我保持——每回合不变量套件把 `readView` 钉到从零闭包，
  同时三层构建它（公理看不见的 delta 锁步应用、对不击败任何物的插入就地增长闭合视图、其余全量重派生）。
  剖析的村庄回合跨 v26+v27 从 7.07s 降到 1.32s，全程位对位同一决策。
- **v28 — 世界编译一次**：创作条件与结果在世界构建时煮成 token 形式，热路径（候选枚举、结果应用、
  want 打分、闭包循环）端到端跑在名字上，字符串求值器保留为独立核实的参考。剖析回合 1.32s → 0.69s；
  套件约 22–30s。
- **v29 — 段 intern**：路径段 intern 为机器整数（变量性在奇偶位），引擎端到端以符号计算，字符串仅在
  创作/显示边界。诚实报告：墙时大致持平（约 10% 在噪声内）——作为 v28 设计的一致终点保留，
  归因教训已记录。
- **v33 — 状态条件相关性**：v26 的相关性跳过只问词汇（「是否有任何动作能改善此 want 类？」）；
  本轮加入「它现在能否重要」，与之并咨的按状态地板/门禁检查。31 测试村庄 A/B 收回约 39s 先前轮的退化
  （171.64s → 132.75s）——真实但部分收回，非回到该轮自身退化前的 31.11s，残余是世界自身累积丰富性，
  非过滤器。

见 `docs/LEDGER.md` 了解接下来的内容（角色散文速写、定时 junction、玩家即 DM、…）。

## 构建、测试、游玩

需要 GHC 9.x + Cabal。

```sh
cabal build       # 编译一切
cabal test        # 跑测试套件（tasty）
cabal run prax             # 玩酒吧演示 — 你是 'you'，从菜单挑选
cabal run prax -- intrigue  # 玩戏剧剧集（罗马阴谋）
cabal run prax -- play      # 玩同一戏剧，以 Prompter-lite 剧本创作
cabal run prax -- dm        # 你是戏剧管理器 — 引导自主阵容
cabal run prax -- feud      # 涌现沙盒：从一过错 + 一把规则派生的世仇
cabal run prax -- audience  # Prompter 演示：一个场景中的定时 junction + 角色速写
cabal run prax -- village   # 目击 + 谣言 + 声誉 + 欺骗 + 事业：你所见或所闻落入地位，已赎罪的贼被威慑不再偷，隐瞒的秘密在值得保持时保持，未经证实的耳语恰如真相般级联成声誉，且——给定赚取他一直想要之物的合法方式——贼转而从事诚实工作
cabal run prax -- flow      # 打印剧本的场景流图（Mermaid）
cabal run prax -- check feud   # 世界的静态合式性检查
```

```sh
cabal run prax -- dump-play         # 打印剧本为 JSON
cabal run prax -- play examples/play.json  # 从 JSON 加载并玩剧本
```

在酒吧演示中，NPC 自主行动：点酒，酒保（ada）会招待你，而顾客（bex）追求自己的啤酒。在
**Intrigue** 中你是 Marcus：共谋者意图毒害你的恩主——什么都不做则情节自行其道（角色死亡），
或警告他、自己动手、或与共谋者恋爱。它到达不同结局，并在同一引擎上演示 Blood & Laurels 风格戏剧
（谋杀、死亡、背叛、分支）。

**初次来此？读 `docs/WALKTHROUGH.md`** —— 引导游玩，点名每件可试之事并解释它演示哪个特性。
第一部分通过玩酒吧游览整个引擎核心；第二部分走其余（intrigue、stress、save/resume、play/flow、
dm、feud、check、audience、village）。

## 参考文献

一手源材料（Versu 论文、Praxish 检出等）下载到 `references/`，该目录被 git-ignore——
本地保留，从不分发。
