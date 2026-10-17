# 导览：通过游玩理解 `prax`

本指南分两部分。

**第一部分 — 酒吧** 带你走完默认演示世界，边玩边点出每件事恰好行使哪个引擎特性。
酒吧行使整个*引擎核心*：排他逻辑数据库、实践、效用 planner、核心模型（情感/关系）、
反应与规范、信念、对话、戏剧管理器、角色弧、一阶查询，以及——直接接入「结账」——
道义义务层。

**第二部分 — 酒吧之外** 是酒吧*没有*展示的能力的较短游览，各在自己的世界或工具中：
带死亡的分支戏剧剧集（`intrigue`）、QA 工具（`stress`）、存档/继续、场景创作戏剧
（`play`、`flow`）、自己扮演戏剧管理器（`dm`）、涌现派生（`feud`）、静态检查器（`check`）、
Prompter 编译特性（`audience`），以及谁看见、谁被告知、以及那落入什么决定人们如何对待你的沙盒——
包括管理已知内容的反派（他自己的秘密与别人捏造的秘密）、一旦威慑遇上赚取他一直想要之物的合法方式
就转而诚实工作的贼，以及气质对照：一个女人的良心给她定价另一人自由说出的谎，而谎仍经她诚实传播
（`village` — 目击、八卦、声誉、欺骗、事业与气质）。

从酒吧开始：

```sh
cabal run prax
```

你控制 **`you`**。另外两个角色每回合自行行动。回合顺序是轮转：`you`，然后 `ada`，然后 `bex`，
重复。在你的回合挑选编号动作，或 `m` 等待（让他人行动）、`s` 存档、或 `q` 退出。

> 菜单**编号会随选项出现与消失而变动**，因此本指南点名动作而非编号它们。选文本匹配的选项。
>
> 注：`m`（跳过你的回合）与世界内「Wait a moment」动作做同样的无事，因此玩家菜单隐藏
> 「Wait a moment」——用 `m`。NPC 仍有它（它们需要「什么都不做」选项，以免空闲 agent 被迫闲逛）。

---

# 第一部分 — 酒吧（引擎核心）

## 世界一览

**地点：** `entrance` ⇄ `bar`（双向连通）。

**阵容：**
- `you` — 玩家。无内建欲望；你决定。
- `ada` — 酒保。Wants：*不要留下未完成订单*（每个效用 −5）与 *留在酒吧*（+1）。
  因此她照看酒吧并招待人，无需被告知。
- `bex` — 顾客。Wants：*点了啤酒*（+4）、*手中有啤酒*（+9）、*在酒吧*（+1）。
  因此 bex 会走进来、点啤酒，并在被招待后安顿。

**实践**（可复用的社交情境）：
- `world` — 地点与移动（`Go to`，外加空闲 NPC 使用的通用 `Wait a moment` 空操作；
  对你的菜单隐藏，因为 `m` 已跳过你的回合）。
- `greet` — 问候同处角色（每个方向一次）。
- `patron` — 标记某人为顾客；创建时播种其饮酒计数器。
- `tendBar` — 点单 → 履行 → 饮用，变醉，外加「忙碌酒吧」铃。

---

## 引导游玩

### 1. 在动手前先看自主性

在你最初几回合，只按 **`m`**（等待）三四次，并看旁白。你会看到类似：

```
  ada: Greet you
  bex: Go to bar
  ...
  bex: Order beer
  ada: Fulfill bex's order
```

**这演示什么：** *带前瞻的基于效用的自主动作选择。* 无人脚本化 bex 走到酒吧并点单——
bex 评估每个动作会产生的世界，并（经自身未来选择向前看两步）看到去酒吧使能点它想要的啤酒。
ada 看到未完成订单（她不喜欢），就履行它。这是 Versu「强自主」的核心：实践只*提供*动作；
agent 选择。
→ 代码：`Prax.Planner`（wants、`scoreActions`/`pickAction` 前瞻——本指南曾在此点名的旧
`worldValue` 已不存在；见下方注记）、`Prax.Loop`（轮流）。

> **前瞻如何对待*其他人*（v23）。** 你刚看到的是特例：酒吧阵容无创作的被相信欲望词汇
> （`Prax.Minds`），因此 bex 的前瞻完全关于其自身未来移动，恰如上所述。一般地，planner 前瞻
> 也想象其他角色一回合的移动——但仅当行动者当前持有关于某人*想要某物*的*信念*（`Prax.Minds`），
> 且仅当行动者当前相信该角色在周围可行动（现在共现，或最近足够被目击——`Prax.Sight`，
> 创作的*预测范围*）。无人告诉你的心智，或你不知下落的人，被想象为站着不动——从不方便地
> 帮你推进计划。`prax village`（下方 §22–24）是这真正咬人处；酒吧从不行使它。

### 2. 四处移动

在你的回合，选 **`you: Go to bar`**。

**这演示什么：** `world` 实践的移动动作。其前置匹配你所在处（`at.you!OtherPlace`）与连接
（`connected.OtherPlace.Place`）；其效果 `Insert practice.world.world.at.you!Place` 移动你。
因为 `at` 是 **排他（`!`）槽**，插入新地点自动移除旧的——无需显式删除。
→ 特性：`Match`、`Insert`、纠正后的 `!` 语义。代码：`Prax.Worlds.Bar` 的 `worldP`、
`Prax.Db.insert`。

### 3. 问候某人

在酒吧与他人同在时，选 **`you: Greet ada`**（或 `bex`）。

**这演示什么：** 双方共处且你尚未问候他们的前置（`Not practice.greet.World.greeted.you.ada`），
外加 `Neq` 阻止你问候自己。问候一次后选项消失（`Not` 现失败）。
→ 特性：`Match`、`Neq`、`Not`、失败即否定。代码：`greetP`。

### 4. 点酒并被招待

选 **`you: Order beer`**。然后再过你的回合（或按 `m`）——在她的回合 **ada 会自行履行你的订单**，
场景会显示 *"you has a beer in hand."*

**这演示什么：**
- **多角色实践**两个角色之间的 **点单 → 履行** 交接（`tendBar` 有角色 `Place` 与 `Bartender`）。
  点单写入 `customer.you!order!beer`；履行删除订单并写入 `customer.you!beverage!beer`。
- ada *无需被告知* 就招待——她的 want *「无未完成订单」*（−5）意味着你的订单消失的世界得分更高，
  因此 `Fulfill` 是她的最佳移动。
- `dataFacts`：四种饮料（`beer`、`cider`、…）来自实践的静态数据，因此你恰好得到那四个点单选项。
→ 特性：多角色实践、`Match`/`Eq`、`Insert`/`Delete`、`dataFacts`、驱动 NPC 的 wants。
代码：`tendBarP`（Order/Fulfill）、`ada` 的 wants。

### 5. 喝掉它——再喝一杯变醉

选 **`you: Drink the beer`**。然后再点一杯啤酒，被招待，再喝。**第二**杯酒精饮料后场景显示
*"you is looking tipsy."*

**这演示什么——最丰富的单一机制：**
- **孵化时的 `init`：** 世界创建时，`Insert practice.patron.you` 孵化顾客实例，实践的 `init`
  播种 `practice.patron.you.drinks!0`。该计数器仅因孵化时初始化而存在。
- **`Call` + 带守卫 case 的函数：** `Drink` 自身不算任何东西；它调用 `recordDrink`。该函数有两个
  case——第一个仅对 `alcoholic` 饮料触发（`Eq Kind alcoholic`），第二个是空操作回退。
- **`Calc`：** 酒精 case 递增计数器（`Calc M add N 1`）并写回。
- **嵌套 `Call` + `Cmp`：** 然后调用 `checkTipsy`，其单一 case 仅在计数器达阈值时触发
  （`Cmp gte M 2`），插入 `person.you.tipsy`。

点一杯 *soda*（非酒精）并喝掉：你的计数器不会动——那是回退 case。
→ 特性：`init`、`Call`、函数、`FnCase` 守卫、`Eq`、`Calc`、`Cmp`。代码：`tendBarP` 的
`Drink` 动作 + `Bar.hs` 的 `recordDrinkFn`/`checkTipsyFn`（经 `defineFunctions` 注册，
非实践字段——自 v47 起函数住在唯一世界级登记册）。

### 6. 让酒吧忙碌——铃

让 **两**人同时成为顾客（你已点单，bex 也点了——bex 通常自行早点）。看 ada 的回合：一旦有两个
或更多顾客，**ada 会响铃**。

> **翻译进度（zh-Hans）：** 开篇、世界一览、以及引导游玩第 1–6 节已译。第 7 节起至第二部分全文
> 仍为英文原文，将在后续轮次继续翻译。

### 7. 情感与关系 — 核心模型（v2）

角色在互动中积累情感与关系内在，且该内在改变他们做什么。看场景的新行
（`… feels … toward …`、`…'s warmth toward …`）。

- **与某人升温。** 在你的回合，**`Greet ada`**，然后**点啤酒**并让 ada 招待你。
  每一项都提升你对 ada 的 `warmth`（问候 +10，被招待 +8）。看场景：
  *"you's warmth toward ada"* 从 10 升到 18。
  → 特性：数值关系评价。代码：`Prax.Core` 的 `adjustScore`；接入 `Prax.Worlds.Bar`
  中的 `greetP`/`tendBarP`。

- **关系创造出新目标。** 一旦你对 ada 的温暖越过 15，全新选项出现：**`Buy ada a drink`**——
  一个在你升温之前字面上不存在的 affordance。这就是核心模型的要点：关系打开行为。
  → 特性：关系门禁前置（`Prax.Core` 的 `scoreAtLeast` = `Match` + `Cmp`）。

- **冷落某人并看他们变冷。** 当 NPC 问候你而你**不回礼**时，稍后他们 *"Take offense at you
  ignoring your greeting."* 场景随后显示他们 *"feel annoyed toward you"*，且对你的温暖变**负**。
  烦躁**不会**扣留他们友好的「请你喝酒」姿态——他们仍**能**请客；情感使他们不**想**要
  （v38 不变量：情感改变决策制定，从不改变哪些决策可被做出——不情愿是定价的，非门禁的）。
  → 特性：共存情感（`Prax.Emotion.feelToward`）、负 `adjustScore`、定价的不情愿（读
  `feelingToward` 的负 `Want`，带新鲜目标变量——v48 删除了自 v39 起的字面别名
  `feelingSomeone`；其携带的按目标定价指引迁到 `feelingToward` 自身 haddock），以及分数门禁
  前置（`scoreAtLeast`）。

- **情感是片刻的；记录持久。** 情感共存（对一个顾客愤怒同时对另一个满意），且各自消退——
  起始声明寿命（`feelTowardFor`，v44），引擎在那么多回合后撤回情感——或更早被行为解除。
  角色冷静后情感消失——但持久的 **grievance** 与降低的 **warmth 分数**仍在。这就是短暂情感
  与耐久关系的差别。

- **情感是不对称的。** 因为温暖是有方向的，你会常规看到一方比另一方更暖（例如
  `bex's warmth toward ada: 38` 而 `ada's warmth toward bex: 30`），且两个 NPC 都对从不回礼的
  玩家冷淡。
  → 特性：不对称角色评价。代码：`Prax.Core`。

*（信念与对话接下来在 §9–§10；经 `setBond` 的公开「纽带」作为 §14 的 `lovers` 浪漫出现。）*

### 8. 反应与规范（v3）

动作现会激起*响应*，且酒吧有一条带牙齿的社交规则。看场景的
`… hasn't returned …'s greeting`、`… owes … a tip`、以及 `… broke a norm …` 行。

- **问候是两部分交换。** 当有人问候你时，场景注明你 *"hasn't returned"* 他们的问候，且你的菜单
  获得片刻前不存在的响应：**`Greet … back`**（相互温暖）或 **`Rebuff …`**（双方变冷）。
  *回*礼是反应在消费自身——不是新的问候。
  → 特性：由动作孵化的反应；消费它的响应。代码：`Prax.Reactions` 的 `spawnReaction`/`endReaction`；
  `Prax.Worlds.Bar` 中的 `respondGreetP`。

- **忽视问候会反噬你。** 若你*不*响应，问候者可——在他们的回合——**因你忽视他们而见怪**，
  留下 grievance 并对你变冷。（在 NPC 重放中，ada 对总是沉默的玩家正是如此。）

- **带后果的规范。** 点酒并被招待：场景显示你现*欠 ada 小费*。选 **`Tip ada`**（她对你升温）
  或 **`Leave ada's tab unpaid`**。赖账则场景标记 *"you broke a norm (stiffedTheBartender)"*；
  在她下一回合 ada **不赞成**，且对你的温暖急剧下降。
  → 特性：`markViolation`；违规孵化 `disapproval` 反应；核心模型后果。代码：`Prax.Reactions`
  （`markViolation`、反应机制）+ `Prax.Worlds.Bar`（`disapprovalP`、`settleUpP`——v48 把现成反应
  移出机制模块进入其唯一消费者；`Prax.Reactions` 现只发布孵化/消费/违规机制，无内容）。

- **NPC 自行尊重规范。** bex 被赋予对赖账的强烈厌恶（`Want [violationOf "bex" "stiffedTheBartender"] (-40)`）
  加上对小费的小偏好，因此被招待时它**付小费**而非走开。这不是预见的未来：「Leave ada's tab unpaid」
  本身插入违规事实，因此 bex 自身的 −40 已在即时、无前瞻评价（`scoreActions 0`）中谴责它——现场确认：
  小费得分 13.0 对赖账的 −30.0，前瞻深度 0，在 planner 前瞻之前。bex 从不需要*预测* ada 的不赞成；
  它对违反规范有自己的强烈意见。那是论文「尊重规范的强烈欲望」从普通效用评价落下，无特殊规则引擎，
  且（自 v23 起）无需预测任何他人反应。
  → 特性：经大负自 `Want` 的规范回避，在深度 0 打分——`Prax.Planner` 的 `evaluate`/`scoreActions`。

- **「欠小费」是真正义务（v14）。** 那小费不只是反应——被招待升起一等 **道义 □**：
  `obliged.you.(you.tipped.ada)`（场景的 *"you owes ada a tip"*）。**付小费** *解除* 义务
  （已履行并关闭）；**赖账** *违约*，且因原义务无法再履行，升起 **修复性 □□**——违反义务的弥补义务。
  planner 追求义务是因为小 `Want` 看重已履行职责；冲突义务在 `!` 排他下塌缩为 ⊥，留给效用解决。
  因此你所见的同一「结账」规范，底层是 Evans 的排他逻辑道义逻辑（DEON 2010）。
  → 特性：`oblige`/`discharge`/`breach`/`obligeReparative`（`Prax.Deontic`）；接入
  `Prax.Worlds.Bar` 的 `settleUpP`。在 `Prax.DeonticSpec` 中断言。

### 9. 信念 — 角色所想未必为真（v4）

世界状态是共享的，但角色可对特定议题持有与真相分歧的私人信念——并按信念而非事实行动。
在酒吧这表现为被相信的积怨。

- **植入谣言。** 若你对某人*生气*（例如你回绝了 ada，因此对她烦躁），则——在她**不在房间**时——
  你可以 **`Warn [someone] that ada resents them`**。那在听者中植入信念：场景会读
  *"… believes ada resents them."* 主张不必为真；ada 可能实际喜欢他们。
  → 特性：由告知形成的按 agent 信念。代码：`Prax.Beliefs` 的 `believe`；`Prax.Worlds.Bar` 中的
  「Warn …」动作（门禁于真实烦躁 + 对象缺席，因此无人闲散八卦）。

- **错误信念覆盖真实感受。** 相信某人怨恨自己的角色**不会问候或请那人喝酒**——即使其实际
  `warmth` 很高。对驱动行为而言信念胜过事实（Versu 单独建模信念的全部要点）。
  → 特性：信念门禁前置（`Not …believes.resentedBy…`）。

- **信念是私有的且可分歧。** 谣言只改变听者的想法；他人（与真相）未触动——两个角色可对同一议题
  持有相反信念。

- **证据可改变想法。** 若据称敌对的人实际**问候**信者，他们可以
  **`Realize [they] don't resent you after all`** 并丢掉错误信念。
  → 特性：信念修正（`Prax.Beliefs` 的 `forget`）。

*（v4 不做的，按 `docs/LEDGER.md`：量化/嵌套信念——「X 相信人人都认为…」——Versu 自身也无法表示；
且没有单一「相信否则取真相」查询运算符，因为那需要析取，是更后的条目。）*

### 10. 对话 — quips、话题与轮流（v5）

彼此喜欢的两个角色可以真正*交谈*，且他们说的改变世界。

- **开始聊天。** 一旦你对某人足够温暖（与请客同一阈值），**`Strike up a conversation with [them]`**
  出现。它以*闲聊*打开；场景显示 *"you and ada are chatting (smallTalk)"*。
  → 特性：对话是带*选定说话者*与*话题*的孵化实践。代码：`Prax.Conversation` 的
  `beginConversation`；`Prax.Worlds.Bar` 中的「Strike up …」动作。

- **Quips 是带后果的台词，且你们轮流。** 只有当前**说话者**可 quip，且仅在当前**话题**上；
  说一句 quip 应用其效果并把地板交给对方。在*闲聊*上你可以闲聊（一点相互温暖）；转到*rapport*
  你可以**恭维**他们（提升他们对你的评价）；转到*gossip*，若你对第三方生气，你可以
  **倾诉他们怨恨你的同伴**——植入（可能为假）**信念**的八卦 quip，正是经对话交付的 v4 机制。
  → 特性：`quip`（说话者 + 话题门禁、一次性、交班）、`changeSubject`；效果复用 `Prax.Core` 与
  `Prax.Beliefs`。「响应只是普通动作…同一 planner。」

- **你保持话题直到改变它。** 离题 quips 根本不提供；要说它们你须先把对话转到那里。那在无特殊
  规则下建模对话连贯。

- **它也会自行涌现。** 一旦阵容升温，空闲角色会与朋友开始聊天（每对限一次对话）——因此跑程后期
  你会看到 NPC 交谈、恭维、甚至八卦，无需你。

*（延期，按 `docs/LEDGER.md`：多方对话、更丰富的 quip 库、以及保持参与者投入聊天而非话说到一半走开。）*

### 11. 导演 — 塑造戏剧的故事管理器（v6）

有一个你从未看见的第四个角色：**`director`**，Versu 的 Drama Manager。它无身体
（无地点——不能被问候，从不点酒），只有关于夜晚形状的*元层*欲望。它不操控任何人；它轻推情境
并让自主阵容反应。

- **留意这一拍。** 玩（或按 `m`）直到房间升温——两个真正彼此喜欢的角色。然后，在它的某个回合，
  旁白显示 **`director: turn ada against bex to stir up the evening`**。导演判定夜晚过于融洽，
  并注入 **失和**：它使一方对立另一方（烦躁情感、grievance、以及温暖急剧下降）。
  → 特性：建模为普通 agent 的 DM——元层 `Want` 加元层动作实践——「DM 只是一种特殊类型的实践。」
  代码：`Prax.Worlds.Bar` 中的 `dmPractice` + `director` 角色。

- **戏剧随后自行展开。** 导演不脚本化接下来发生什么。其注入的 grievance 流经你已见的*同一*系统：
  受害一对停止友善（信念、定价情感、温暖阈值），可见怪、彼此八卦，等等。导演点火；自主角色供火。

- **它知道何时停止。** 干预只触发一次（它只能以一种方式满足的元层 want），因此导演不会把房间
  磨成无尽冲突——正是「不喜欢微观管理的高层导演」。

*（你也可以自己占据此槽——见 §18，`prax dm`。仍延期，按 `docs/LEDGER.md`：更丰富的元层剧目与节奏，
以及导演可监视的通用事件流。）*

### 12. 角色弧 — 重塑你所想要的内在生活（v7）

实践给角色*外部*选择；**弧**是角色的*内部*、高层状态——其夜晚的贯穿线。人人以 **`hopeful`**
到达（看场景：*"bex feels hopeful"*）。

- **看 bex 找到自己的位置。** 当 bex 在夜晚对某人升温，一旦真正喜欢（自身温暖越过阈值），
  它采取这一拍 **`bex: settle in, feeling you belong here`**，场景转为 *"bex feels at home here"*。
  其 wants 随阶段移位——归属感的 bex 满足于逗留。
  → 特性：阶段门禁的 `Want`——推进弧改变角色追求什么。代码：`Prax.Arc`；`Prax.Worlds.Bar` 中的
  `arc` 实践 + bex 的弧 wants。

- **弧对戏剧稳健。** 即使导演使 ada 对立 bex，bex 仍安顿到归属——因为 bex *自身*对 ada 的温暖
  保持了。弧反映角色内在，不只是对他们做了什么。

- **真正转变只属于玩家。** 每个希望的顾客都被*提供*下行移动，**`give up on the evening,
  resigning yourself to solitude`**（→ lonely）。但无 NPC 曾采取它：滑入孤独只会断绝他们渴求的
  归属，无归路，因此效用 planner 拒绝它。只有人类——不受 planner 约束——才会选择逆自己欲望改变。
  这是 Versu 的「真正转变…只对玩家可用」，在此直接从架构落下（NPC 最大化效用；玩家从菜单挑选）。

*（延期，按 `docs/LEDGER.md`：更丰富的多阶段弧，以及反馈进导演节奏的弧。）*

### 13. 一阶查询（v8）

以上一切使用「此事实成立」/「此事实不成立」形式的前置。v8 添加了缺失的逻辑联结词，使前置或欲望
可为**析取**（`Or`）、**否定存在**（`Absent`——「不存在使…的 X」）、或**量化**（`Exists`，
外加建于其上的 `forAll`/`implies`）。你已在未点名的情况下见过它们运作：铃的 `Subquery`+`Count`
收集集合，且——在第二部分——每个脚本结局由 `Absent [Match "ending.E"]`（「尚无结局存在」）冻结。
这些是后续世界所倚赖的语法。→ 代码：`Prax.Query`；贯穿 `Prax.QuerySpec` 行使。

---

# 第二部分 — 酒吧之外（系统其余部分）

酒吧有意舒适。剩余能力各有自己的世界或命令，因此你可以孤立地看见它们。每个是一行或两行调用。

### 14. 死亡与分支结局 — `prax intrigue`（v9）

```sh
cabal run prax -- intrigue
```

你是 **Marcus**，罗马阴谋中的共谋者之一。共谋者 **Cassia** 意图毒害你的恩主 **Lucius**。
不作为则情节自行其道（有人死亡）；或警告他、自己动手、或与共谋者恋爱。它到达不同结局，并在同一
引擎上演示 Blood & Laurels 风格戏剧。

- **什么都不做并看死亡。** 反复按 `m`。Cassia 会向 Lucius 倾诉、下毒、等待……Lucius 死亡并离开阵容。
  场景显示结局。→ 特性：阵容移除（死亡）；`Prax.Worlds.Intrigue`。
- **分支。** 试着 **警告 Lucius**、**自己下毒**、或 **追求 Cassia**——不同路径到达不同结局
  （背叛、谋杀、浪漫）。
- **公开纽带。** 浪漫路径经 `setBond` 设定对称的 `lovers` 纽带（§7 预告的公开关系状态）。

→ 代码：`Prax.Worlds.Intrigue`；死亡经从阵容移除角色。

### 15. QA 工具 — `prax stress`（v10）

```sh
cabal run prax -- stress intrigue
cabal run prax -- stress bar
```

压力测试器玩许多播种的全 AI 局，并报告结局、动作覆盖与死胡同。用于在手工游玩前发现卡住与
未达结局。→ 代码：`Prax.Stress`；检查器用 `Prax.Inspect.explain` 解释动作为何不可用。

### 16. 存档与继续（v11）

游玩中按 **`s`** 存档。稍后：

```sh
cabal run prax -- bar resume
```

世界状态是全部事实——存档/读档即序列化事实库。→ 代码：`Prax.Persist`。

### 17. 场景创作戏剧 — `prax play` 与 `prax flow`（v12）

```sh
cabal run prax -- play
cabal run prax -- flow
cabal run prax -- dump-play
cabal run prax -- play examples/play.json
```

同一 Intrigue 戏剧创作成 Prompter-lite 剧本（CAST + 场景图），编译为普通实践。`flow` 打印
Mermaid 场景流图；JSON 是可编辑创作格式。→ 代码：`Prax.Script`、`Prax.Script.Json`、
`Prax.Worlds.Play`。

### 18. 你*作为*戏剧管理器 — `prax dm`（v13）

```sh
cabal run prax -- dm
```

你占据导演槽：菜单是作者性轻推（煽动竞争、点燃温暖、投下阴影），覆盖自主阵容 ada/bex/cai。
他们经普通社交机制演完后果。→ 代码：`barDirectorWorld`；经 `candidateActions` 的实践绑定玩家。

---

> **翻译进度（zh-Hans）：** Part I 全文与 Part II §14–§22 已译；文末「可试之事」「尚未建模」已译。§23–§30 与 Feature coverage map 仍为英文。

### 19. 涌现派生 — `prax feud`（v15）

这是指向涌现社交模拟、越过创作互动小说的沙盒。你创作 **一个** 过错与一把规则；整场世仇自行派生。

```sh
cabal run prax -- feud
```

> *"You are Alice. One wrong, and a feud assembles itself — make amends to dissolve it."*
> ```
>   - bob resents alice
>   - carol resents alice
>   - dave resents alice
> ```

**自 v31 起** setup 不再手写联盟：它断言 `wronged.alice.bob` 与三个 *成员* 事实——bob、carol、dave
都 `join` 同一家族 `kestrel`（`Prax.Faction`，v31 折入——完整重构见 §29）。四条前向链规则做其余，
原三条外加一条把共享成员变成联盟：

```
allied.X.Y                          ⇒ allied.Y.X       -- alliances are mutual
wronged.X.Y                         ⇒ resents.Y.X      -- the wronged resent the wrongdoer
resents.A.B ∧ allied.A.C            ⇒ resents.C.B      -- the enemy of my ally is my enemy
member.X!F ∧ member.Y!F, X≠Y        ⇒ allied.X.Y       -- shared membership is alliance (comrades, v31)
```

因此 **carol 与 dave 开始怨恨 Alice，尽管她只冒犯过 Bob** ——现经一个共享家族而非手写成对链——
并据此行动（*"bob is shunning alice"* 等等）。派生是 **可废止的**：派生事实住在闭合 *视图* 中，
从基重算且从不存储。选 **`make amends with bob`** ——删除单一创作的 `wronged.alice.bob` ——并看
*整场* 世仇一举消失：每个派生 `resents` 与每次冷落消失，因为其唯一支持没了。（缩放的 `bigFeud`
基准保持其原先成对 `allied.*` 链不变——链拓扑是基准自身设计，且基 `allied.*` 事实仍是合法词汇；
并非每个联盟都必须是成员。）
→ 代码：`Prax.EL`（排他逻辑格 + `m(X)`）、`Prax.Derive`（前向链）、`Prax.Faction`（`comrades`，v31）、
`Prax.Worlds.Feud`。

### 20. 静态类型检查 — `prax check`（v16–17）

Versu 有隐式类型系统；`prax check` 使之显式，并在不执行世界的情况下对它运行。

```sh
cabal run prax -- check feud
```
```
well-formed: the feud (emergent sandbox)
```

它标记 **未绑定变量**（前置无法绑定的效果/公理-头变量——静默空操作）、**排他基数冲突**
（关系同时断言 `!` 与 `.`）、以及 **悬空引用**（对未定义物的 `Call`/孵化）。之上它做 **ML 风格
sort 推断**：声明每个基 sort 的成员，经统一推断每个位置的 sort 并拒绝冲突（例如地点出现在 agent
所属处）。每个已发布世界检查干净。→ 代码：`Prax.TypeCheck`；在 `Prax.TypeCheckSpec` 中断言。

### 21. Prompter 编译特性 — `prax audience`（v18）

一个短场景，一次行使场景层在普通 beats 与 junctions 之外编译的创作构造——**定时 junctions** 与
**角色速写**。（第三个构造 **memories**——无身体故事管理器旁白的一次性说明——在 v18 构建并在 v46
**移除**：无说话者的全知旁白结果是穿着世界内容外衣的呈现特性，因此场景层根本不再编译它。观众场景
曾以一个打开；现不再。）

```sh
cabal run prax -- audience
```

> *"You are the envoy. Flatter the king, then petition — before the moment (or the Duke) passes."*

- **角色速写。** **Duke** 无手写欲望——只有对地位的 *关切*（`concernedWith [("favor", …)]`）与特质
  （`ambitious`）。该关切编译为 want，因此他 **不请自来地讨好国王**（*"duke: flatter the king"*）
  恰好一次，然后休息。
- **定时 junction。** 若你 **拖沓**（按 `m`），观众耐心耗尽并在截止后以 **`dismissed`** 结束。
  及时 **恭维，然后提出请愿** 则以 **`granted`** 结束。进入场景武装 **耐心标记**，其寿命即延迟；
  引擎的到期调度在那么多回合后撤回它，junction 在耐心耗尽的瞬间触发——整个计时器是每个已调度效果
  已骑的调度上的一次插入。

→ 代码：`Prax.Script`（编译）、`Prax.Worlds.Audience`；在 `Prax.ScriptSpec` 中断言。

### 22. 目击 — 谁知道什么（`prax village`）（v19）

到目前为止，人人读的是同一共享事实库。`Prax.Witness` 打破这一点：角色开始*相信*什么，
现取决于某事发生时他们站在何处。

```sh
cabal run prax -- village
```

> *"You are a villager. What you see — and what you miss — decides what you can do."*

bob、carol 与你从广场开始；dana、eve，以及（自 v25）gale 在磨坊。dana 整局留在那里——她有自己的
+1 want 留在磨坊（与让 bob 在摊位附近徘徊的同一锚定习语：空闲角色需要它想待的地方，否则在平局
决胜中漂移）。

**动手前的注记。** 在此世界更早一轮（v19–21），诚实演示是等一拍并看想要面包的 bob 拿走它。
自 v22 起那停止了：bob 改为隐瞒偷窃（§25 覆盖机制），按 `m` 只显示他在等被看守的广场。自 v24 起
按 `m` 也不再显示*那个*——bob 现有通往面包的合法路径，并从第一回合不提示地采取它（§26 完整讲述；
非本节主题）。要单独看见目击触发、不被后续弧拉走，最干净的方式仍是自己偷面包——现场捕获，
`cabal run -v0 prax -- village`，`1` 然后 `q`：

```
-------------------- scene --------------------
  - bob is at the square
  - carol is at the square
  - dana is at the mill
  - eve is at the mill
  - gale is at the mill
  - you is at the square
Your move (you):
  1) you: steal the loaf from the stall
  2) you: whisper to carol that bob stole the loaf
  3) you: whisper to bob that carol stole the loaf
  4) you: whisper to bob that dana stole the loaf
  5) you: whisper to carol that dana stole the loaf
  6) you: whisper to bob that eve stole the loaf
  7) you: whisper to carol that eve stole the loaf
  8) you: whisper to bob that gale stole the loaf
  9) you: whisper to carol that gale stole the loaf
  10) you: take up honest work at the stall
  11) you: Go to mill
  m) wait and let others act
  s) save    q) quit
> > you: steal the loaf from the stall
  bob: take up honest work at the stall
  carol: confront you about the theft
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

（若干在 v19 落地时还没有的东西已可见：`whisper to …` 与 `take up honest work` 选项，以及 eve 与
gale 自身移动。耳语选项是 v22 的欺骗层（§25）——比 v22 落地时又多两个，因为 v25 的 gale 是第五个
可捏造主体；`take up honest work` 以及 bob 在你偷窃瞬间选择它是 v24 的救赎（§26）——承担门禁只需
bob 在广场，不需摊位上仍有面包，因此你的偷窃不阻止他追求事业，只是拿掉他自己的偷窃选项。这些都不是
本节主题；暂且忽略。eve 与 gale 整段时间在磨坊，也不是广场任何事的目击者——与 dana 同因。gale 此处
自身移动（走向广场）只是空闲角色的普通平局决胜漂移，尚与其气质无关——§27 覆盖 gale 在场实际添加什么。）

carol 正站在那里，你一拿她就对质你——同一拍，因为目击在行动瞬间检查，非稍后回合——并据此开始
*regard* 你为贼，这是本节尚不论的 *派生声誉* affordance（§24 覆盖）：

```
  - bob regards you as a thief
  - carol regards you as a thief
```

dana 从不得 `confront`——不在本回合，不在被告知二手之后（§23），甚至稍后她站在你旁边的广场时也不
（当时直接对照其自身 `possibleActions` 检查：从不提供）。目击固定在行动瞬间，非由稍后邻近或稍后信念：
`carol.believes.stole.you.loaf.seen` 在你偷窃瞬间断言——并注意谁*也不*得到信念：你不。`observable` 的
`ForEach` 把行动者排除在自身目击存入之外（旧 bob-偷窃演示中 `bob.believes.stole.bob.loaf.seen` 从不成立
的同一原因）——你不是自己之手的目击者，因此结果是你稍后也不能 `tell` 任何人「你看见」什么，因为你也
从未看见。dana 从不持有此类信念——只有 *heard* 的，一旦 carol 到达她（§23）——且 `confront` 门禁于
`saw`，非 `heard`。

偷窃包在 `observable together "stole.Actor.loaf"` 中；同一世界中普通的 `Go to [Place]` / `Wait a moment`
动作则不是——因此 **移动不是新闻**：无人，甚至全程站在你旁边的人，会开始相信 `went.you`，因为无作者
声明它为事件。可观察性是世界作者对动作陈述的属性，非引擎从观看执行推断——同一动作可被创作为*看起来*
完全像别的东西（关于自身事迹的掩饰/误导仍是储备的未来层；§25 覆盖词汇*今天*支持的欺骗——隐瞒真实事迹
与对从未发生之事撒谎）。

底层是 `ForEach [Condition] [Outcome]`，v8 从未给出的结果语言量词：`Insert`/`Delete` 作用于一句，
`Call` 分派到一个函数 case，但「对每个共现角色存入信念」需要一次在整个查询的绑定上取值。`ForEach`
取 **快照**——在应用任何子结果前查询全部绑定——因此存入 carol 的信念不能在 fold 中途改变谁还算目击者。
`Prax.Witness.observable` 是其唯一内建用法：它向动作结果追加
`ForEach (copresence ++ [Neq "Witness" "Actor"]) [Insert <the belief>]`，其中 `copresence` 是
*世界提供的* 模板（村庄的 `together` 关联共享 `at` 事实的两个角色）——引擎自身无地点概念。

→ 代码：`Prax.Engine`（`ForEach`、`performOutcome`）、`Prax.Witness`（`observable`/`saw`）、
`Prax.Worlds.Village`；在 `Prax.WitnessSpec`、`Prax.VillageSpec` 中断言。

### 23. 谣言 — 消息在传播（`prax village`）（v20）

`Prax.Rumor` 合上了 §22 留下的环：某人持有的信念——目击所得或已是二手——现在可以 *告诉* 同场听者。

本游的余下部分（§§23–24）回到跟随 *bob*，而非你：v21 的声誉弧结束于 NPC 自身的悔意与自我威慑，这只有自主角色才能表现，因此需要一名 NPC 小偷。自 v22 起，自由游玩中让 bob 真的拿走面包已不再自行发生（§22、§25）：他隐瞒，而 carol——曾在第一次决策到来前就因平局决胜走开——现在持有自己的 +1 广场锚，正是 v22 为此加入（盗窃不再保证在第一回合发生后，她的前几回合是零效用平局，无锚的闲置角色会在平局决胜上漂移，与 bob、dana 同一惯用语）。两锚合在一起意味着自主游玩中广场从不清空。自 v24 起，bob 甚至不试：从第一回合起他就承接 `earnBread`（§26）——严格优于在被监视的广场上空等一场必须隐瞒的盗窃——因此自由游玩不再能经 *任何* 路径到达盗窃，无论广场是否被监视。

因此下文是 **强制的**：直接触发 bob 的盗窃（`doAct`，恰是 `Prax.VillageSpec` 测试所用的技术——正因为自由游玩再也到不了此状态），然后无头驱动 CLI 自身运行的同一生产循环（`Prax.Loop.advance`/`npcAct`）若干真实额外回合。这不是 `cabal run prax -- village`——是同一引擎代码，从草稿本编译并直接对着 `Prax.Worlds.Village` 跑，实时捕获的真实输出，非伪造、非从任何报告复用：

```
-- forced: bob steals (doAct) --
  - bob is at the square
  - carol is at the square
  - dana is at the mill
  - eve is at the mill
  - gale is at the mill
  - you is at the square
  - carol regards bob as a thief
  - you regards bob as a thief
```

现在一轮是 **六** 个回合（you、bob、carol、dana、eve、gale——v25 把 gale 加入阵容；自 v44 起感知与时钟在引擎回合边界运行，因此无 ticker 角色占回合）。carol 目击的瞬间就质问了 bob，机制与 §22 相同。eve 独立地、出于她自己的理由（§25——不是本故事）在同一轮向 dana 低语关于 *carol* 的谎言；两条情节在同一世界并发，互不提示。与此同时 bob 有自己的第二轨道在跑：v24 的 `earnBread` 不在乎他已拿着偷来的面包，因此他在被强制盗窃的同一轮就承接它：

```
  you: (you wait)
  bob: take up honest work at the stall
  carol: confront bob about the theft
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

第 2 轮：bob 清扫广场（`earnBread` 的第一部分，公开，见 §26）；carol 在广场上直接疏远 bob：

```
  you: (you wait)
  bob: sweep the square
  carol: shun bob
  dana: shun carol
  eve: Go to square
  gale: Go to mill
```

——而且，作为 eve 上一轮低语到达她的副作用，dana 也疏远 *carol*，为 carol 从未做过的事。

第 3 轮：bob 走向磨坊取面粉；carol 出发寻找听者——她有一条 want，希望他人 *从她那里* 听到 bob 盗窃的真相（`Want [carol.believes.stole.bob.loaf, Other.believes.stole.bob.loaf.heard.carol] 5`）——而最近的一人 eve 刚走进广场：

```
  you: (you wait)
  bob: Go to mill
  carol: tell eve that bob stole the loaf
  dana: Go to square
  eve: whisper to you that carol stole the loaf
  gale: Go to square
```

第 4 轮：自第零回合起已有 *一些* 对他不利的 regard（carol 与 you 都目击了强制盗窃），bob 自己的补偿压过本轮继续磨坊之行——他在挣到自己的面包之前归还了偷来的面包，carol 在他归还的同一轮就软化：

```
  you: (you wait)
  bob: return the loaf with apologies
  carol: relent toward bob
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

最后一行是本轮所围绕的涌现发现——§27 完整覆盖：eve 的低语也欺骗了 gale，而 gale 现真正相信后，用普通 `tell` 径直传回给 *eve*。

第 5 轮（35 步时），bob 在磨坊恢复 `earnBread`（取面粉——补偿并未让他失去项目），carol 专门找到 dana 也告诉她——第二个独立来源，因她 want 中的 `Other` 由任意听者满足、非特定一人——而 dana 手里有传闻，同一轮就据此行动：

```
  you: (you wait)
  bob: fetch flour from the mill
  carol: tell dana that bob stole the loaf
  dana: Go to mill
  eve: Go to mill
  gale: Go to mill
```

直接确认：自此 `dana.believes.stole.bob.loaf.heard.carol` 为真。`gossip` 只要求告知者与听者同场——机制本身不把任何人导向任何人——但 carol 自己的 want 可靠地把她放到未知情听者所在之处，因此 *她* 做旅行，恰如 v22 前的村庄。

继续驱动：bob 返回广场（第 6 轮），烘焙并挣得自己的面包（第 7 轮——同一轮 dana 手里有传闻用怀疑看他，而 eve 听过 gale 把她自己的谎言告诉她后，用普通 `tell` 而非 `lie` 把关于 carol 的捏造直接传给 bob），村庄到第 10 轮安顿：`atoned.bob` 成立，`regards.carol.bob.thief` 与 `notorious.bob.thief` 在闭合视图中皆假，对 bob 的疏远无一幸存，且 `carol.believes.stole.bob.loaf.seen` 全程仍真——§24 覆盖的同一「补偿，非失忆」形状，现旁载 gale 漂洗过的谎言作为无关并发线程。

**看见/听说 affordance 不对称。** 仅有传闻的 dana 得到 `eye [Thief] with suspicion`——较轻的信任打击（−5，理由 `heardOfTheft`）——但永无 `confront`，后者仍门禁于 `saw`（−10，理由 `sawTheft`）：传闻不授权「我看见你了」。不对称也反向切割：`VillageSpec` 的「传闻授权怀疑，非质问」确认目击证人 carol 从不被提供单纯怀疑——`eye` 门禁于 `heard "Actor" "<event>"` **且** `Absent [Match "Actor.believes.<event>.seen"]`，因此看见对较轻行为吞没听说。

**带源传闻词汇。** 出处不再是 v19 交付的单一排他值（`!seen`）——它是多值的：直接目击为 `<W>.believes.<event>.seen`，每位告知者一条 `<W>.believes.<event>.heard.<source>` 边，共存于同一 `believes.<event>` 节点下。*也被* 告知的目击证人保留其 `.seen` 边，而非被覆盖的 `!heard` 夺走——v19 评审标出并为本轮存下的捕获 bug。每位后续告知者再加一条 `.heard.<source>` 边，因此印证只是清点不同来源；`heard` 本身是该子树上的布尔 `Exists`，故两个来源仍在菜单中产生一行，而非重复告知。

**不信任门。** `gossip` 的世界供给门（世界加自有额外条件，方式同 `Prax.Witness` 的 `together` 同场模板由世界供给）是「你不与你不信任的人闲聊」：

```haskell
Absent [ Match "Actor.relationship.Hearer.trust.score!TrustScore", Cmp Lt "TrustScore" "0" ]
```

规格草图把此变量名为 `V`；交付代码称之为 `TrustScore`，因为村庄实践自有角色也叫 `V`（`Prax.Worlds.Village` 中 `roles = ["V"]`）——此处复用 `V` 会静默捕获该绑定而非引入新鲜条件变量，是发货前抓住的真 bug 而非风格选择。无信任分记录时，闲聊自由流动；信任一旦降到零以下，告知就从菜单消失，与任何其他门禁 affordance 相同。

→ 代码：`Prax.Rumor`（`gossip`/`heard`）、`Prax.Worlds.Village`；断言于 `Prax.RumorSpec`、`Prax.VillageSpec`。

### 24. 声誉 — 站队、恶名、补偿，以及学会的小偷（`prax village`）（v21）

`Prax.Repute` 合上了 §§22–23 打开的环：到达某人的证据——目击或仅听说——现在 *沉淀为他们对你的看法*，一种塑造行为的派生站队，无需任何人存储声誉事实。直接接续 §23 的强制会话（同一对着库编译的技术、同一运行中的世界——bob 的盗窃在那里被强制，因为自由游玩再也到不了此状态；见 §22/§25）：

carol（目击证人）一相信盗窃，也就开始 *regard* bob 为小偷——无人写入的事实，从她的信念派生——且站队已有牙齿：`shun bob` 在同一拍（第 1 轮，§23 已示）就对 carol 可用，门正是也会向玩家提供 `shun bob` 的同一门（`regardedAs "Actor" "T" "thief"`）。

到第 3 轮，carol 已告诉 eve，后者——仅有传闻——也开始 regard bob：§23 的看见/听说不对称（怀疑，非质问）径直带入站队，因为传闻足以 *regard*，恰如足以 *believe*。随着 carol（目击）、you（目击）与 eve（来自 carol 的传闻）都 regard bob 为小偷，第三条 regard 触发 `notoriety "thief" 3`——「全村都知道」——而 bob 对抗 `notorious.bob.thief` 的 want（−15）现压过手里的面包（+10）。一轮之后他归还，同一轮 carol 软化（本跑程中 dana 从未 regard *bob*——eve 的谎言先到达她，故她唯一的 regard 是冤枉的，§25）：

```
  you: (you wait)
  bob: return the loaf with apologies
  carol: relent toward bob
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

（此处 dana、eve 与 gale 的行完全是 eve 对 carol 的构陷，§25——且自 v25 起，其意外续集：gale 自己的行是把谎言径直传回说谎者，诚实相信——§27 有完整记述。两故事穿在同一七回合轮中，全部是一次跑程的真实、未编排输出。）

**补偿，非失忆。** 从 bob 自己盗窃派生的每一行立刻消失——不是因为有人忘记，而是因为它们唯一的支撑（`atoned.bob` 的缺失）已去。对照同一会话直接检查：`atoned.bob` 成立；`regards.carol.bob.thief` 与 `notorious.bob.thief` 在闭合视图中皆假；而——练习的要点——`carol.believes.stole.bob.loaf.seen` 仍为 **真**，恰如先前。无人的信念移动；`standingUnless` 的击败者在同一读取上溶解了 *派生*，而支撑它们的信念（当击败者后来被撤销时）原封不动。这是 `VillageSpec` 的「补偿溶解站队而记忆持久」，不是普通场景渲染直接显示的东西（场景打印派生站队，非原始信念）——正因如此本导览在此及下文检查底层事实而非仅旁白。

**威慑：摊位仍有货——且自 v24 起，bob 最终真的拿着一块面包，他自己挣的。** 把同一强制会话继续驱动——到第 4 轮时对 bob 的疏远已全部软化，如上所示——直到第 15 轮（105 步，七回合轮——同一预算 `VillageSpec` 的「已补偿小偷被威慑」测试所驱动），bob 的 `steal the loaf from the stall` 仍在他自己的菜单上，无任何门拒绝，但他在同一窗口的早回合花在 `earnBread` 上而非空等，并在 105 内完成：

```
bob's steal-the-loaf option still on the menu, unrefused: True
stall.loaf present: True
bob holds a loaf: True
the loaf he holds is the one he earned: True
bob's atonement still stands: True
```

——整个余下跑程他再不偷。`stall.loaf` 确实仍在——他自己的 `steal` 动作是唯一会拿走它的东西，而他没有。`holding.bob.loaf` 为真的理由与 v24 前的故事不同：不是仍未满足、等待未来再犯的盗窃关联 want，而是 `practice.earnBread.bob.done.s3`——他拿着的面包是他在此同一 105 回合窗口内烘焙的。这正是 `VillageSpec`「已补偿小偷被威慑」测试现直接断言的（v24 下修正，规格 §3）：其旧代理——「bob 不持有面包」——被正确实现的救赎证伪，而非 bug，因此测试现按自身条款钉死不再犯（补偿仍立、摊位未动、所持面包追溯到事业自身完成事实），而非事业总会使其为假的事实。

在此同一终端状态对照当前 planner 现场重检，深度 0 的 `scoreActions` 把 `bob: Wait a moment` 排在 **20.0**，对照 `bob: steal the loaf from the stall` 的 **5.0**——与 v24 自身数字不变。v25 阵容下 *已* 变的是：`20.0` 不再是 bob 的唯一顶尖分，而是十四方平局。bob 一路上自己被拖进 eve 对 carol 的构陷（`eve: tell bob that carol stole the loaf`，第 7 轮，§27 覆盖把「证据」放进 eve 自己手里以便明文告知的机制）——因此他的菜单现携带一整族关于 carol 的零边际效用选项（`eye carol with suspicion`、`shun carol`、向几位村民各自 `tell`），每一个恰与单纯等待同一基线分。盗窃以 5.0 仍远低于全部十四——威慑比较本身不受排名顶部多么拥挤影响。再偷会立刻把 `notorious.bob.thief` 翻回真（与先前同一击败者删除机制：行为自身结果删除 `atoned.Actor`，无人曾停止相信的 regards 在下一次读取就复活，无需前瞻）并在行为将再度被目击时放弃隐瞒的回报。这不是预见的未来；是动作的直接后果，恰如 §8 的逃单厌恶。未补偿的 bob 被推去补偿；已补偿的 bob 看见眼前的后果，不再犯——他有更好的事做，而 v24 给了他一件。`VillageSpec` 钉死两事实——「再犯撤销补偿：站队从记忆弹回」用手强制第二次盗窃并断言 regards 返回，而「已补偿小偷被威慑：planner 看见弹回」驱动同一 105 自主回合并断言不再犯（完整弧本身在「整条弧自行运转」中驱动 70 回合）。

疏远/软化/告知选项也不再浮现——无存活 regard 时，驱动它们的 want（carol 与 dana 的疏远 want *条件于* `regardedAs`，按设计规格，故随 regard 蒸发而非与陈旧疏远打到平局决胜）只剩无可追求。完整机制——`standing`、`standingUnless`、`regardedAs`、`notoriety`，以及世界选择把 bob 的羞耻键在恶名而非任一 regard 者的轻蔑上——记于 `docs/specs/2026-07-10-v21-repute-design.md`。

→ 代码：`Prax.Repute`（`standing`/`standingUnless`/`regardedAs`/`notoriety`）、`Prax.Worlds.Village`
（`shun`、`return the loaf with apologies`、`relent`、`villageAxioms`）；断言于
`Prax.ReputeSpec`、`Prax.VillageSpec`。

### 25. 秘密与欺骗 — 反派，与诚实的不公（`prax village`）（v22）

`Prax.Deceit` 加上 §§22–24 信息栈（目击 → 谣言 → 声誉）终将需要的对抗层：*管理* 已知内容的代理人，而非仅携带。两机制，皆创作为普通 want 与普通动作——无隐身系统、无测谎引擎、`Prax.Engine` 无新物：

- **`conceal`** 是无人相信某行为的 want（`Absent [Anyone.believes.<event>]`）。它无需自有强制——planner 的前瞻在选择动作前已模拟 v19 目击存款，因此看重秘密的代理人只是从不把被目击版盗窃打得与未被目击版一样高。等待隐私从普通效用最大化中自然落下。
- **`lie`** 镜像 v20 的 `gossip`，双重倒置：说话者必须对事件持有 **无** 证据（该缺失使它成为谎言，也是动作自身的瓦解——说谎者一听到自己的谎言被传回，就获得证据，`lie` 的门关闭，普通 `gossip` 无缝接替），且捏造主体从世界供给的 *捏造* 条件绑定（你可看似合理构陷谁）而非从信念。它插入的效果——`<Hearer>.believes.<event>.heard.<Actor>`——与 `gossip` *完全相同*。该同一性是整个设计：受骗者持有真实传闻，结构上与真货不可区分，整套 v20/v21 机械（复述、印证、站队、恶名、疏远）在虚假上未修改地运行。

**bob 隐瞒——但不再靠等待。** `conceal "stole.bob.loaf" 12`——比面包本身（+10）更值钱——恰是 v22 时的 want：它奖励无人开始相信的行为，且任何人会看见盗窃的瞬间它仍失败。v24 改变的是被监视的 bob *对此做什么*：早先，避开被目击盗窃意味着单纯等过去；现在 `earnBread` 在桌上，勤劳压过耐心，于是他改取它——§26 从头到尾现场讲述。隐瞒本身并未消失；它仍门控同一选择，只是更晚。两个脚本探针仍单独隔离该机制，不受事业混淆，且两者仍通过：

- `Prax.DeceitSpec` 的最小夹具单独探测 `conceal`——被监视 vs 未被监视，无其他在场。
- `VillageSpec` 的「秘密保持：广场有人看时 bob 不偷」（从干净 `villageWorld` 驱动 28 回合——四个七回合轮）与「完美犯罪：独处时 bob 偷且永无人知」（用手把 carol 与 you 送到磨坊，驱动 14 回合——两轮）皆成立。「完美犯罪」值得停顿：即使现有 `earnBread`，*真正* 独处的 bob 仍偷而非开始事业——一无人监视，机会主义就压过耐心勤劳，锋利一如 v24 前。§26 的「机会主义保持诚实」拍是同一发现，讲在项目中途而非第一回合：隐瞒不关玩家，关 *任何人* 在看，无论诱惑落在故事何处。

自由游玩本身再也到不了「bob 等待」——无论玩家在场，还是玩家去了磨坊。v24 前自由游玩每个空闲按键打印 `bob: Wait a moment`；今日同一输入从第一回合打印救赎（§26 走完）。自由游玩在同一会话空隙中 *仍* 无提示展示的，是第二条完全独立的情节：eve 对 carol 的构陷。

**eve 加入，并构陷 carol。** eve 从磨坊起步——位置重要：她绝不可目击 v19–21 自有测试强制的脚本盗窃，以便其两目击算术保持完整——带一条创作 want，现为与 gale 共享的具名词汇欲望（`spites-carol`，v25——见 §27）：`Want [Match "regards.W.carol.thief"] 4`，希望 carol 被恶视，按头计，且不在乎如何。`lie` 给她手段。这是 §26 抽取 bob 救赎的同一六次 `m` 按键、玩家在场跑程；eve 的战役从第一拍并行：

```
>   bob: take up honest work at the stall
  carol: Wait a moment
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

——且 `dana regards carol as a thief` 在同一拍派生，无人写入的事实，来自无人目击的声称。下一轮，dana 据此行动，而 bob 仍在清扫中：

```
>   bob: sweep the square
  carol: Wait a moment
  dana: shun carol
  eve: Go to square
  gale: Go to mill
```

eve 继续移向未告知村民所在并继续低语——先 dana，两人仍在磨坊时，然后一旦她走到广场就到 you（按键 3）。同时 gale 一直在自有空闲平局决胜上漂移（磨坊 → 广场 → 磨坊 → 广场），到按键 4 正站在广场 eve 身旁、未被告知——正是使 carol 与 you 成为 §22 中 bob 盗窃目击证人的同一地点巧合。eve 够到她，故事形状相对本世界每一先前轮次在此改变：eve 的捏造不只加第四个 *信徒*；它加一个 *诚实传播她现所信之物的旁观者*：

```
>   bob: fetch flour from the mill
  carol: Wait a moment
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

gale 像 eve 够到的其他所有人一样受骗，据此开始 regard carol 为小偷——并在同一轮用普通 `tell` 把信念传回给 eve。那一轮一次加 *两条* regard：gale 自己的（因相信谎言）与 eve 自己的（因 gale 对她自有捏造的诚实印证——说谎者现为她发明的声称持有真实传闻）。两条 regard 落在先前每轮只加一条的同一轮，且够了：对 *carol* 的恶名在 **按键 4** 触发，比本世界每一先前轮次的形状早两按（§27 有完整原由）：

```
-------------------- scene --------------------
  - bob is at the mill
  - carol is at the square
  - dana is at the square
  - eve is at the square
  - gale is at the square
  - you is at the square
  - dana is shunning carol
  - dana regards carol as a thief
  - eve regards carol as a thief
  - gale regards carol as a thief
  - you regards carol as a thief
  - carol is notorious as a thief
```

bob 自己再晚一轮仍被卷入（按键 5：`eve: tell bob that carol stole the loaf`——普通 `tell`，非 `lie`，因 eve 现持 gale 的传闻为自有证据），并在再下一轮完成烘焙自己的面包（按键 6，§26）。bob 自有救赎与 carol 的构陷在同一六按窗口跑完，两故事皆未编排、互不提示：

```
-------------------- scene --------------------
  - bob is at the square
  - carol is at the square
  - dana is at the mill
  - eve is at the mill
  - gale is at the mill
  - you is at the square
  - dana is shunning carol
  - bob regards carol as a thief
  - dana regards carol as a thief
  - eve regards carol as a thief
  - gale regards carol as a thief
  - you regards carol as a thief
  - carol is notorious as a thief
```

**更新 — v30。** 整条级联——eve 在按键 3 够到「you」，再在按键 4 够到 gale，gale 的诚实印证使 carol 恶名早两按——仅在 v25 时为真。一旦 `Prax.Blackmail` 落地（v30，§28），同一输入不再复现：阈值恐惧使 eve 一持有两名 regard 者就谨慎，而这发生在她 *第一次* 低语（她构陷 carol 时 dana 与 gale 都在磨坊同场，一次低语同时存入两条 regard，低语 *行为本身* 现可被目击）。此后任何低语都有第三人 regard 与直接恶名的风险，故她再不冒险。今日驱动同一跑程，直接检查：eve 终其一生只低语一次；只有 dana 开始 regard carol 为小偷；carol 仅被 dana 疏远；无人——非「you」、非 gale、非 bob——曾从 eve 听到该声称，且自由游玩中 `notorious.carol.thief` 永不派生。上方两场景块保留为历史（v30 前）捕获，因它们展示本节真正在教的机制——一旦被相信，捏造结构上与真相不可区分，诚实信徒传播它与说谎者一样有效——这仍恰为真；§28 按需复现它，强制而非偶遇，旁载改变 *此特定自由游玩结果*、而非其下机制的阈值恐惧故事。

上方捕获场景中除 eve 外无人做错——以及无意的 gale，其唯一过错是相信被告知之物并做诚实村民对信念所做之事：分享它。carol 从未靠近摊位。然而 regard、疏远与恶名皆为真实派生事实，对 `Prax.Repute` 及除 eve 外每个村民而言，与 bob 在 §24 诚实挣得的那些不可区分。那是规格的中心主张，现场应验：*捏造种下普通 `.heard.<liar>` 传闻……谎言作为真相传播，因为除说谎者外传闻与捏造对所有人不可区分*——且自 v25 起，这包括经永不自己说谎之人传播。

**不公是诚实的：carol 无救济。** eve 的构陷完全不依赖 bob——此处从新鲜、*未强制* 的 `villageWorld` 驱动（恰 `VillageSpec` 自有设置：`driveIdle "you" 40 villageWorld`）；到 v25，上方所示同一级联自行运转，无需任何人强制任何物（自 v30 起，未强制最远只到 dana 自有 regard——见上方更新）。完全不依赖级联完成的是：在该点直接检查 carol 自有 `possibleActions`（从草稿本对着库编译，现场，技术同 §23–24）：

```
-- carol's menu after the frame-up cascade (40 driven turns) --
carol: steal the loaf from the stall
carol: whisper to gale that bob stole the loaf
carol: whisper to you that bob stole the loaf
carol: whisper to bob that dana stole the loaf
carol: whisper to gale that dana stole the loaf
carol: whisper to you that dana stole the loaf
carol: whisper to bob that eve stole the loaf
carol: whisper to gale that eve stole the loaf
carol: whisper to you that eve stole the loaf
carol: whisper to bob that gale stole the loaf
carol: whisper to you that gale stole the loaf
carol: whisper to bob that you stole the loaf
carol: whisper to gale that you stole the loaf
carol: take up honest work at the stall
carol: Go to mill
carol: Wait a moment
```

`take up honest work at the stall` 自 v24 起在此为新——承接动作提供给站在广场的 *任何人*，不仅 bob（`Prax.Project.endeavor` 门禁于地点，非身份），故也在 carol 菜单上。她自有 want 中无物激励她去取（只有 bob 携带 `charDesires = ["pursues-earnBread"]`），故它闲置未选——无动机的 affordance，非存活追求；§26 自有机会主义拍恰建立在此不对称上：选项可用并不意味着有人想要它。

无 `return the loaf with apologies`——也永不会有。该动作自有前置条件是 `Match "holding.Actor.loaf"`，而 carol 从未持有；补偿要求她从未拿过的东西。这不是缺失特性——词汇无 *事实真相* 可供指控对照检查的概念，故无人（含 carol）可指向任何能洗清其名之物。`Prax.VillageSpec` 的「被构陷者无补偿：carol 不被提供归还」恰钉此点。洗清需要事件记录——动作可对照检查之物——存入未来轮次（`docs/LEDGER.md` 的 backlog），而非在此用捷径伪造使不公听来虚假。玩家拥有与 eve 相同的 `whisper`/`lie` affordance（本节每个菜单可见）——无物阻止 *你* 也构陷某人，或靠单纯不相信 eve 的谎言来洗清 carol 的名，而这改变不了其他所有人现所信之物。

**更新 — v32。** 中心主张仍真，直接检查，非仅仍看似合理：`Prax.Confession`（§30）给 *说谎者* 一条归路——eve 可告白并获赦免——但告白只转换告白者自有标记并清除告白者自有站队。其中无物让任何人 *代表 carol* 告白，也无 affordance 撤回 eve 的谎言已种在 dana、gale 及任何它够到之人中的假信念。现场重检而非假定不变，carol 在同一 40 回合驱动后的自有菜单与上方转储有一处不同——不是要紧的那处：eve 在未强制游玩中从不告白（她的秘密仍昂贵，恰如 §30 自有自由游玩钉所示），到第 40 回合碰巧站在广场而非磨坊，故出现四个新的 `whisper to eve` 选项（她现为可及听者，仅此而已）：

```
carol: steal the loaf from the stall
carol: whisper to eve that bob stole the loaf
carol: whisper to gale that bob stole the loaf
carol: whisper to you that bob stole the loaf
carol: whisper to bob that dana stole the loaf
carol: whisper to eve that dana stole the loaf
carol: whisper to gale that dana stole the loaf
carol: whisper to you that dana stole the loaf
carol: whisper to bob that eve stole the loaf
carol: whisper to gale that eve stole the loaf
carol: whisper to you that eve stole the loaf
carol: whisper to bob that gale stole the loaf
carol: whisper to eve that gale stole the loaf
carol: whisper to you that gale stole the loaf
carol: whisper to bob that you stole the loaf
carol: whisper to eve that you stole the loaf
carol: whisper to gale that you stole the loaf
carol: take up honest work at the stall
carol: Go to mill
carol: Wait a moment
```

行动者到第 40 回合落在何处，对每个中间回合整阵容的候选集敏感（此轨迹从非 `VillageSpec` 自有钉死轨迹之一——只有 `freePlayAt`/`whisperArcAt`/`redemptionArcSetup` 是——故套件无物依赖它字节同一），且本轮即使未采取也会向若干角色的回合加候选动作。要紧的不受影响：仍无 `return the loaf with apologies`，仍无任何洗清 affordance，无论 carol 或任何代表她告白之人。本轮建造的归路收窄不公空间——说谎者现可与她直接伤害之人把事做对——而完全不触及此一桩。

→ 代码：`Prax.Deceit`（`conceal`/`lie`）、`Prax.Worlds.Village`；断言于 `Prax.DeceitSpec`、`Prax.VillageSpec`。

### 26. 勤劳 — 事业、从旁观读出的目的、诚实的机会主义（`prax village`）（v24）

`Prax.Project` 给村庄道德弧以收束。创作的事业 *类型*（`endeavor pid weight undertakeLabel gate parts`，由 `Part` 建成）编译为世界接线一次的三物：一个承接 `Action`、一个各部分为 *集合* 的 `Practice`（每所有者一实例——再承接永不提供）、以及一个具名追求 `Desire`，每完成一部分付 `+weight`。进度 *就是* 回报，因此长项目无需 planner 变更：每个可用部分在门满足的瞬间就是普通局部效用，从非前瞻必须规划趋向的预见终点。计划是集合，非线性链——部分独立并行完成，并非全部成功所必需，故已完成部分事实之集即状态，无进度光标；部分的 `partAfter` 命名必须先完成的兄弟部分（经验证的结构边），`partNeeds` 携带世界资源与阈值门。追求欲望对尚无实例的已配置角色是 **休眠的**——零绑定、零效用；承接（普通 planner 选择）将其打开。bob 从一开始就携带倾向（`charDesires = ["pursues-earnBread"]`），直到他据此行动前沉默。`Prax.Worlds.Village` 的 `earnBread` 是链上三部分——清扫广场（公开——`witnessed together "swept.Actor"`，`Prax.Witness` 的存款构建器现作为一等组合子导出正为此）、再在磨坊取面粉（`after ["sweep"]`）、再在广场烘焙（`after ["fetch"]`）得到他否则必须去偷的面包。

**救赎，现场捕获。** 完全干净开局，只按 `m`：

```sh
cabal run prax -- village
```

```
-------------------- scene --------------------
  - bob is at the square
  - carol is at the square
  - dana is at the mill
  - eve is at the mill
  - gale is at the mill
  - you is at the square
Your move (you):
  1) you: steal the loaf from the stall
  2) you: whisper to carol that bob stole the loaf
  3) you: whisper to bob that carol stole the loaf
  4) you: whisper to bob that dana stole the loaf
  5) you: whisper to carol that dana stole the loaf
  6) you: whisper to bob that eve stole the loaf
  7) you: whisper to carol that eve stole the loaf
  8) you: whisper to bob that gale stole the loaf
  9) you: whisper to carol that gale stole the loaf
  10) you: take up honest work at the stall
  11) you: Go to mill
  m) wait and let others act
  s) save    q) quit
>   bob: take up honest work at the stall
  carol: Wait a moment
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

——并且，一次一按，事业余下部分完全自行展开。bob 自己的行，真实逐字，接下来五按下每轮一行：

```
  bob: sweep the square
  bob: Go to mill
  bob: fetch flour from the mill
  bob: Go to square
  bob: bake and earn the loaf
```

六按，从被威慑的 bob 到吃饱的 bob，无处强制——恰是 `VillageSpec`「威慑加机会产生勤劳：被监视的 bob 挣面包」无头驱动的同一技术（`driveIdle "you" 49 villageWorld`——现为七回合轮，故六个完整轮是 42 回合，测试自有预算含第七轮余量），钉死完成回合：该计数下 `s3`（烘焙）在 **第 37 回合** 后首次为真，`holding.bob.loaf` 为真，`stall.loaf` 未动（他从未靠近），无处有关于 bob 的盗窃信念——这是他 *烘焙* 的面包，非任何人须目击他拿走的。 （同一六按也是 carol 构陷并行展开之处——仅到 v25 时触发恶名；自 v30 起不再，§25 自有更新解释为何，§28 讲述该故事余下。）

**看着他工作教会村庄他的目的。** 清扫是公开的，故看见者开始相信 `swept.bob`——且 `villageAxioms` 恰为此加一条推理规则：凡相信 bob 清扫过的人，假定他在追求 `earnBread`，同一「旁观沉淀为关于某人心智的信念」模式 v21 已用于声誉，现瞄准欲望而非行为。因该假定追求是普通被信念的 `Desire`（`Prax.Minds`），它直接喂给 `predictMove`——带现场测试翻出的真实细微差别，直接检查（对着库编译，真实输出）：

```
carol saw the sweep: True
carol presumes the pursuit: True
carol's predicted move for bob, still at the square: Nothing
carol's predicted move for bob, now at the mill: Just "bob: fetch flour from the mill"
dana's predicted move for bob, co-present at the mill but never told: Nothing
```

预测者读的是他们 *相信* 的欲望，非行动者真状态或预测者的眼睛——恰是 v23 建造 `predictMove` 所具有的性质，现由欲望而非情节行使。

**机会主义保持诚实。** 威慑与勤劳皆仅因 bob 被监视而成立；若他一有体面去处隐瞒就悄悄不再重要，故事会听来虚假。项目中途——已承接、清扫已做——广场真正空（`carol` 与 `you` 皆用手送到磨坊，同 §25 脚本测试的强制技术），bob 自有顶尖动作翻转：

```
bob's top pick, square empty mid-project: Just "bob: steal the loaf from the stall"
  71.18  bob: steal the loaf from the stall
  60.46  bob: Wait a moment
  50.46  bob: Go to mill
```

盗窃（71.18——现无人监视，隐瞒的 +12 重回场，叠在面包本身上）大幅压过继续走向下一部分（`Go to mill`，50.46——导向事业相对谦逊的平坦 `+3` 的一步）——同一比较形状 §25「完美犯罪」拍在第零回合展示，此处在项目中途复现。bob 诚实是因为诚实 *当前* 是更高分路径、被监视时；一停止被监视，排名恰如 v24 存在前那样回退。`VillageSpec` 的「机会主义保持诚实：项目中途空广场仍诱惑」钉死此精确比较。

→ 代码：`Prax.Project`（`endeavor`/`Part`）、`Prax.Witness`（`witnessed`，现导出）、
`Prax.Worlds.Village`（`earnBreadTake`/`earnBreadP`/`earnBreadPursuit`，推理公理）；断言于
`Prax.ProjectSpec`、`Prax.VillageSpec`。

### 27. 性情：诚实村民（`prax village`）（v25）

`Prax.Persona` 给村庄第一个从 *行为* 而非仅 want 建成的角色。gale 经 `cast` 加入阵容，是 eve 的对照对：两名女性携带同一具名欲望 `spites-carol`（`Want [Match "regards.W.carol.thief"] 4`——eve 在 §25 的旧无名恶意，现入词汇以便可被 *相信*），但 gale 还带着 `honest`，一种以自有 `lied` 标记为代价（各 −6）而非直接禁止说谎的 `Trait`。无物阻止她低语——算术会。

**(a) 自 t=0 起可读。** `transparent` 派生每个角色假定持有者的行为估值，可击败地，在单回合开玩前。直接对照 `readView villageWorld` 检查：

```
carol presumes gale's conscience: True
dana presumes gale's conscience: True
carol presumes gale's spite (unheralded, so no one presumes it): False
carol presumes eve's conscience (eve bears no trait): False
```

性情写在袖口；恶意不是——怨恨在有人实际被告知前恰如 eve 旧无名 want（§25）一样不可读（如下 (c) 种植）。

**(b) 驱动跑程：eve 的构陷落地，gale 的心智保持无标记——而谎言仍经她漂洗。** 这是 §25 与 §26 皆抽取的同一六按、玩家空闲跑程（`driveIdle "you" 49 villageWorld`，或同一 CLI 会话按六次 `m`）。eve 向 dana 低语，再向 you，再在按键 4 够到 gale：

```
>   bob: fetch flour from the mill
  carol: Wait a moment
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

gale 恰如 eve 够到的其他所有人一样受骗——她无法知道声称为假——而诚实信徒原来是 *完美* 载体：在同一轮她用普通 `tell` 而非 `lie` 传出她现真正持有之物。直接对照驱动状态检查：

```
eve's frame-up went ahead (dana.believes.stole.carol.loaf.heard.eve): True
eve carries the mark of it (eve.lied.dana.stole.carol.loaf): True
gale's psyche unmarked (no gale.lied fact anywhere): True
edges heard "...heard.gale": [("eve","carol")]
everything gale passed on, she honestly believes (gale.believes.stole.carol.loaf): True
eve now holds evidence heard from gale — the lie laundered back to its own author: True
```

gale 从不说谎——可证明该标记在整个数据库中缺失——然而捏造照样经她旅行，在她一端与真相不可区分，因为对 gale 而言它 *就是* 真相。她甚至把它带回 eve（`eve.believes.stole.carol.loaf.heard.gale`），把真实「证据」交到说谎者手里以支撑其自有发明：下一轮 eve 用普通 `tell` 而非 `lie` 够到 bob——她获得该证据的瞬间门就关了，恰如听到自己的谎言被传回（§25）。**诚实村民漂洗谎言。** 这在实现中发现，非规格初稿所预测（初稿错误猜测 gale 会不留任何痕迹）；一旦观察此跑程，规格就地修正（`docs/specs/2026-07-11-v25-persona-design.md` §4，「漂洗」），这也是 carol 的恶名比本世界任何先前轮次早两按触发的原因——§25 有该计数。

**更新 — v30。** 上方转录——eve 在自由游玩按键 4 直接够到 gale——同一输入不再复现。`Prax.Blackmail` 的阈值恐惧解析（§28）使 eve 在第一次低语后就谨慎（她构陷 carol 的瞬间 dana 与 gale 都 regard 她，因两人同场目睹该行为）：再低语就有第三人 regard 与直接恶名的风险，故自由游玩中她再不向 gale 或任何人发送。更锋利、当前的自由游玩事实是「终其一生恰一次低语」（`Prax.VillageSpec` 对同一 49 回合轨迹的自有断言），非上方所示三次低语级联。漂洗 *机制* 本身——诚实信徒传播她被诚实欺骗而相信的谎言——仍真实；只是不再是 eve 自有 planner 选择演示之物。§28 强制恰是她的审慎现拒绝的低语，并现场展示 gale 恰如上复述，故发现保持钉死而非悄悄失去唯一测试。

**(c) 预测对照。** 在 dana 头脑中种下关于两名女性的同一动机信念——`dana.believes.desires.eve.spites-carol.heard.you` 与对 gale 的相同——并分别问 `predictMove`，gale 的良心自 t=0 (a) 起已被假定：

```
predictMove dana eve  = Just "eve: whisper to dana that carol stole the loaf"
predictMove dana gale = Nothing
```

仅被信念的恶意预测低语；被信念的恶意对上被信念的良心（+4 − 6）预测无物。被信念的性情改变他人期望你做什么，不只是你实际做什么——v23 为情节建造的同一信念心智机械现携带性格。

→ 代码：`Prax.Persona`（`Trait`/`personaVocabulary`/`bearing`/`transparent`/`cast`）、`Prax.Deceit`
（`lie` 的新标记结果）、`Prax.Worlds.Village`（`honest`、`spitesCarol`、gale）；断言于
`Prax.PersonaSpec`、`Prax.DeceitSpec`、`Prax.VillageSpec`。

### 28. Leverage: blackmail & debt, priced (`prax village`) (v30)

The backlog's oldest named commitment (parked since v22 for its own design round) lands as two thin
modules over shipped machinery: `Prax.Debt` (an obligation with a beneficiary) and `Prax.Blackmail`
(`shakedown`, the threaten/comply/defy/expose protocol). Both were probe-verified live before the
spec was written — every step in the mechanism is individually motivated, no scripted "villain AI."

**A debt is an obligation, priced.** `owe creditor debtor content` inserts
`debt.<creditor>.<debtor>.<content>` *and* `oblige debtor content` in one call — a debt *is* an
obligation, not merely coupled to one. `settle` reverses both. Default becomes reputational the same
way theft did in v21: a `demand` action wraps `Deontic.breach` in `Prax.Witness.observable`, so a
*witnessed* default deposits a belief, and `standingUnless` derives `regards.<W>.<debtor>.deadbeat`
from that belief alone — an unwitnessed default derives no regard for anyone who wasn't there.
Except one: the debtor himself. He's unavoidably co-present at his own default
(`Witness.observable`'s `Neq Witness Actor` only excludes the *creditor*, never the debtor), so he
always regards himself a deadbeat, witnessed by anyone else or not — a self-regard/third-party-spread
distinction review found underspecified in the first draft, and the shipped test now asserts it
directly. Repayment defeats the standing by inserting `atoned.<who>` — the identical positive-fact
defeater idiom v21's thief already uses — while the belief that he once defaulted persists untouched:
reputation flows from belief, never the raw fact, unchanged since v21.

**A threat is a motive-belief deposit.** `shakedown` compiles four actions around one evidence
pattern and one price. `threaten` inserts `threatened.<extorter>.<victim>` and plants the identical
kind of belief confiding and lying already ride (v20/v22): the victim comes to believe the
extorter's own punitive desire, sourced (`.heard.<extorter>`) — no mind-reading, just the same
channel every other belief in this engine uses. The victim's own round-walk then does the pricing
work: it predicts the extorter might *act* on that professed desire, same as it would predict any
other believed motive.

**Why the threat is credible: self-motivation, not omniscience.** The probe's central finding —
stated honestly because it wasn't obvious going in — is that the extortionist doesn't need to
predict compliance to make threatening rational. The punitive desire the threat professes
(`punishes-<id>`, `+w` per believer once threatened or defied) is genuinely held, and exposing pays
off from it one lookahead ply away — so `threaten` scores on its own terms, myopic and
unmotivated-move-blind exactly like every other `predictMove`. A pure bluffer (a deposit without the
desire) is expressible in the vocabulary but wouldn't be self-motivating to send — banked with the
script layer, not attempted this round.

**A standing threat is exposable too.** The probe found the classic hole first: gating exposure on
defiance alone makes stalling free forever — a victim who simply never acts is never punished.
`expose` fires on *either* `threatened` or `defied`, so waiting ties with defiance rather than
beating it.

**The compliance arithmetic, pinned both sides.** `BlackmailSpec` ports the session probe's own
fixture through `shakedown`, asserting the exact numbers, not just the direction: with two
onlookers, buying silence scores −63.84 against waiting's −71.84 and defying's −75.80 — comply wins.
Strip it to one onlooker and defy and wait score identically, −54.2 exactly (the stall-tie, asserted
as an equality, not an inequality) — buy is still −63.84, now the *worst* option. Audience size alone
flips the decision; the spec states the arithmetic so world authors price threats deliberately, not
by feel.

**A real bug, found by the planner's own lookahead — and a backlog item banked from it.** Porting
the probe surfaced a genuine divergence: an early draft of `comply` had no guard against being
bought twice, and the recursive lookahead discovered it could — a renewed threat after paying once
re-extracts, and the *prospect* of repeat extraction inflated the very first buy decision's own
score to −51.24, against the guarded, canonical −63.84. The fix mirrors the probe exactly (`comply`
now requires no debt already standing); the finding — the planner discovering repeat extortion on
its own before anyone designed for it — banked **escalating / serial extortion** as a real future
mechanic in `docs/LEDGER.md`, not a hypothetical one. **That bank is now discharged at v54**: a
`coComplianceLasts = Just n` lifetime expires the `complied` marker and the racket cycles — one
purchase per bought period, then the extorter extracts again — with no new logic, the permanence
here becoming the `Nothing` case. Buying protects the purse, never the person (the no-fiat ruling):
betrayal-vs-wait is emergent `pickAction` scoring, enforced by no marker.

**The village demo blocked twice before it shipped.** Both drafted arcs failed on measured traces:
per-head fear can't be low enough to let eve keep whispering before a guaranteed witness *and* high
enough to compel compliance — one weight, two irreconcilable jobs. And a theft-evidence shakedown
catches the framed exactly as readily as the guilty (v22's whole point, still true here), which
would have displaced dana's already-shipped bread arc rather than added to it. dana/bob is retired
as an arc outright, recorded as a faithful result rather than a gap: in this village, bob's crimes
are either fully witnessed (v21's arc already tells that story) or perfectly secret (v22's
concealment already tells that story) — there's no room left for a *partially*-witnessed crime a
blackmailer could threaten to expose.

**The resolution: threshold fear, bob's own idiom generalized.** Nonlinear fear serves both masters
because its marginal price is zero below the brink and catastrophic at it. eve gains
`Want [Match "notorious.eve.slanderer"] (−15)` — the identical shape and magnitude as bob's own
`notorious.bob.thief`, wired by `standingUnless … "slanderer"` and `notoriety "slanderer" 3`. The
whispering *act* itself becomes observable (`witnessed together "whispered.Actor.Hearer"` — the
content stays exactly as secret as before; only the fact that a whisper happened is witnessable).
That single change means a witnessed whisper lands *two* regards in one action — the addressee and
any co-present bystander both come to believe it happened — putting eve one witness from the brink
the instant anyone catches her in the act.

**Carol's shakedown, captured live.** `VillageSpec`'s own forced trajectory: gale steps out of the
mill first (otherwise she'd be a third simultaneous witness, tripping notoriety at the instant of
catching eve rather than leaving her "one exposure from the brink"); carol arrives and witnesses
directly; both return to the square, where real bystanders (bob, "you") make the exposure threat
credible rather than empty (`scoreActions`-measured before the arc was built: at the mill, with only
gale and dana already in on it, buying silence merely *ties* waiting — the threat has no teeth
without someone new to expose to).
Verbatim, from a clean `villageWorld` (a co-presence tick, `VillageSpec`'s own "out of sight, out of
mind" idiom, fires silently between moves):

```
  gale: Go to square
  carol: Go to mill
  eve: whisper to dana that bob stole the loaf
  carol: Go to square
  eve: Go to square
```

Note who gets framed: **bob**, not carol — a different character than every earlier round of this
world. That's not a scripting mistake; it's the honest consequence of `shakedown`'s evidence pattern
being *content-blind* (`"whispered.V.H"` — a whisper happened, full stop, no matter what it claimed).
Carol's leverage over eve never depended on knowing or caring what was said, only that it was said in
front of her — the same "content stays secret" property the `observable` wrapper states directly,
visible here in the transcript itself: bob, two lines below having just taken up honest work at the
stall, gets shunned by dana in the very same round over a slander he had nothing to do with, purely
because this run's victim-binding happened to land on him.

Free play resumes from there, "you" idling, driven the identical way every other section's headless
traces are:

```
  bob: take up honest work at the stall
  carol: threaten eve with what you know
  dana: shun bob
  eve: buy carol's silence
  gale: Go to mill
```

Checked directly against the driven state after carol's threat (turn 3):

```
threatened.whisper.carol.eve: True
eve's motive-belief deposit (eve.believes.desires.carol.punishes-whisper.heard.carol): True
notorious.eve.slanderer: False -- still under the brink, only carol and dana regard her
```

And after eve complies (turn 5):

```
debt.carol.eve.favor: True
obliged.eve.favor: True
threatened.whisper.carol.eve: False -- the threat is bought off
defied.whisper.eve.carol: False -- she never defied
notorious.eve.slanderer: False -- real silence bought, not a forced exposure
```

Eve pays because the arithmetic above says to: one credible witness already in hand (carol), one
more exposure away from the brink, against a debt she can walk back later. Nobody scripted the
decision — `pickAction` made it, the same planner every other section in this document exercises.

**Threshold fear's second consequence: eve becomes a one-shot liar.** This is structural, not a
side-effect of the arc above — it shows up in ordinary, *unforced* free play too. A single witnessed
whisper lands two regards at once (the addressee and any co-present bystander); with the notoriety
threshold at three, any *further* whisper to someone new is an instant trip, and no atonement path
for slander is authored this round. Driving the identical 49-turn free-play trace §25–§27 all draw
from, checked directly:

```
eve.lied.* marks across the whole 49-turn trace: ["eve.lied.dana.stole.carol.loaf"]
regards.dana.eve.slanderer: True    regards.gale.eve.slanderer: True   (both from the ONE whisper)
notorious.eve.slanderer: False
regards.dana.carol.thief: True      -- the only regarder carol's own frame-up ever gets
notorious.carol.thief: False        -- unlike every pre-v30 round of this world
```

Before v30, that same trace had eve whisper three separate times (turns matching presses 1, 3, and
4 — to dana, "you", and gale in turn), and carol's frame-up reached notoriety on the strength of it
(§25). Post-v30, eve whispers exactly once, ever, and carol's frame-up never gets past its first
believer in free play — both are the same finding from two angles. `Prax.GoldenDriveSpec`'s
re-capture shows it from a third: of 21 turns, exactly one line drifted — turn 19 (eve's second
free-play decision) was `"whisper to you that carol stole the loaf"`, is now `"Go to mill"` —
because by then she already sits at two regarders and a third would tip her over. Bar and intrigue's
goldens are byte-identical; nothing else in the village moved.

**The laundering mechanism, reproduced on demand.** §27(b) found — live, unpredicted by the spec's
first draft — that an honest believer is the perfect vector for a lie: gale, deceived like anyone
else, spreads what she genuinely believes by ordinary `tell`, no `lie`, no mark, no conscience cost,
and even hands the falsehood back to eve as "evidence" for her own fabrication. Threshold fear means
eve's own planner no longer walks into that scene voluntarily — so it has to be forced to show it
still works. Driving 49 turns, then 5 more idle turns to reach a moment eve and gale are actually
co-present (free play has them drift in and out of sync), then forcing exactly the whisper eve's own
prudence now declines (still legal — one-shot-per-hearer permits it, since gale's never heard this
specific claim from anyone), then driving on:

```
  eve: whisper to gale that carol stole the loaf     -- forced; eve's own planner declines this
  gale: tell bob that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

Checked directly:

```
heardFromGale (who heard what, from gale): [("bob","carol"), ("eve","carol")]
everything gale relayed, she honestly believes herself: True
gale.lied anywhere in the whole run: False
eve now holds hearsay heard from gale -- the lie laundered back to its own author: True
```

Exactly the v25 finding, reproduced on demand rather than stumbled into: gale never lies, and the
falsehood travels through her anyway, indistinguishable from truth on her end because to her it *is*
truth — including carrying it straight back to the woman who invented it. (An incidental find while
probing this, outside anything pinned or asserted: carol, once she regains eyewitness evidence of a
*second* whisper this way, independently rediscovers grounds to shake eve down again — a live,
unscripted echo of the repeat-extortion question banked above, now BUILT as a first-class mechanic
at v54 via `coComplianceLasts`, though this village instance stays free-play, not a claim this round
builds on or tests.) `Prax.VillageSpec`'s "same spite, different temperaments" test carries exactly this
retelling: the free-play assertions that still hold (the frame-up, eve's own mark, gale never lying)
are kept and sharpened with "exactly one whisper, ever"; the laundering assertion moves to the forced
continuation above, so v25's mechanism stays pinned rather than silently going untested.

**v25's parked "getting-caught-lying" item, partially landed.** Not lie-detection, and not
content-exposure — the whisper *act* alone became witnessable this round (`witnessed together
"whispered.Actor.Hearer"`), so co-present villagers now come to believe *that* a whisper happened,
while *what was said* stays exactly as secret as it always was. That's enough to give blackmail its
leverage (carol never needed to know or care what eve whispered, only that she did), but it isn't the
fuller mechanic v25 parked — nobody can yet catch what a lie actually claimed, only that a
lying-shaped act occurred.

**Re-founded on a general primitive (v49).** The four-action protocol, the motive-belief deposit,
and the punitive `Desire` described above are no longer blackmail's own — they belong to
`Prax.Coerce`'s `Coercion`/`coerce`, a content-agnostic leverage skeleton with evidence made
optional (a protection racket burning a barn is the primitive's other instance, evidence-free).
`Prax.Blackmail.shakedown` keeps its exact v30 signature and composes one `Coercion`: the evidence
trigger, the debt demand, the exposure punishment, and a believers-of-the-evidence kernel are all it
supplies; threaten/comply/defy/punish, the markers, and the punitive want are the primitive's. The
compliance arithmetic above still reproduces byte-for-byte, but is no longer what's pinned — the
re-founding's own test contract is six design properties (stalling never dominates, audience scales
fear, repeat extraction stays impossible, …), with the old decimals kept only as comparison
baselines, a shift from asserting exact scores to asserting the shape of the decision they produce.

→ code: `Prax.Debt` (`owe`/`settle`/`owes`), `Prax.Blackmail` (`shakedown`, v49: an instance of
`Prax.Coerce`), `Prax.Coerce` (`Coercion`/`coerce`, v49), `Prax.Worlds.Village` (`villageP`'s `Scene`
role, `whisperShakedown`, eve's threshold-fear want, the `slanderer` standing); asserted in
`Prax.DebtSpec`, `Prax.BlackmailSpec`, `Prax.CoerceSpec`, `Prax.VillageSpec`, `Prax.GoldenDriveSpec`.

---

### 29. One membership spine, two generators — factions, kinship, and a wedding across the feud (`prax feud`) (v31)

Two backlog rows (`Factions & membership`, `Kinship & households`) fold into one round because they
share exactly one primitive: **membership**. A household is a small faction; kinship *generates*
memberships (marriage moves them); faction axioms turn membership into solidarity. `Prax.Faction`
and `Prax.Kin` ship as two thin modules over that one spine, and §19's feud is refactored onto it —
not left as a second, parallel design — as the round's own proof that the generalization holds.

**Membership is a base, single-slot fact.** `member.<who>!<faction>` — one primary allegiance, and
the `!` is the whole semantics: joining a house, defecting from one, and marrying into one are all
the same exclusion overwrite, not three different mechanisms. `comrades` derives `allied.X.Y` from
`member.X!F ∧ member.Y!F ∧ X≠Y` — and it **keeps the name `allied`**, so everything already built on
that name (the mutuality axiom, "the enemy of my ally is my enemy", `societyP`'s shun affordance)
consumes it unmodified. A third axiom, `factionStanding`, extends v21's belief-gated reputation
(`standingUnless`'s shape) with a membership join — an offense against my faction-mate, *that I
believe happened*, makes me regard the offender — and ships spec-tested (`Prax.FactionSpec`), but
isn't wired into any world this round: it's `FactionSpec`-pinned only, the village-wiring decision
stated and deferred rather than built speculatively (see the ledger's Tier 1 row for the same
banked line).

**`Prax.Kin` is pure derivation on top.** Base vocabulary is `parent.<parent>.<child>` and
`married.<a>.<b>` (asserted once; symmetry is derived, not asserted twice); `kinAxioms` closes
marriage symmetry, `sibling`, `grandparent`, and two `inLaw` rules (spouse's parent; sibling's
spouse) — stated **one-directional** (acquired-relative-first, ego-second: `inLaw.P.B` reads "P is
B's in-law"), with no symmetric `inLaw.B.P` derived. Because it's pure derivation, retraction-safety
is free: dissolving a marriage (retracting the `married` fact) un-derives every in-law it supported
— but **membership itself does not un-derive**, because `wed`'s membership transfer is a base `!`
overwrite, not a derivation from the marriage fact. That asymmetry is the point, not an oversight:
whoever moved households stays moved even after a divorce, exactly as a real defection would.
`wed joiner faction spouse` compiles a wedding to exactly two things: the marriage base fact, and
one `!` overwrite moving the joiner's membership into the named faction — the fold's whole payoff in
one line. *Which* party moves is the author's choice per wedding (world content, not module policy).
Offices generalize the same exclusion idiom to succession: `office.<name>!<holder>` plus
`succession`, a claim action gated on the holder's death and the claimant being a child of the
holder — any child may claim, the single slot takes the first motivated one, which is honest
exclusion semantics rather than an invented age-based primogeniture (age doesn't exist in this
model; inventing "eldest" would be an unprincipled fact).

**The feud, refactored — and `FeudSpec` unmodified is the proof.** §19's two hand-authored
`Insert "allied.bob.carol"` / `Insert "allied.carol.dave"` setup facts are gone, replaced by three
`joins "X" "kestrel"` facts; `comrades` now derives what those two facts used to assert directly.
The five original `FeudSpec` tests were run against the refactored world **before anything else was
touched**, and pass byte-for-byte unmodified — no test edit, because no existing assertion mentions
`allied.*` at all (every one is phrased in `resents.*`/`shunned.*`/`wronged.*`, exactly the derived
vocabulary the refactor preserves). One semantic wrinkle was checked, not assumed: the old pairwise
chain derived `resents.dave.alice` in two hops (through `allied.carol.dave`); the house derives it
in one hop (`comrades` ties everyone sharing `kestrel` to everyone else directly) — invisible to
every existing test, since none of them count derivation depth.

**The wedding beat, live.** Esme starts in her own single-member house, `wren` — inert to the feud
by construction: `comrades` needs *two* members of a house to derive anything, and she has no
housemate yet, so her pre-wedding facts are exactly this, checked directly against `feudWorld`
(base and derived view identical — nothing else touches her name):

```
member.esme.wren
```

(no `allied.esme.*`, no `resents.esme.*` — `dbToSentences` prints the `!` exclusion as `.`, so this
is the base fact `member.esme!wren`.)

Then the wedding — `wed "esme" "kestrel" "dave"` (the bride moves; an authored choice for this
world, not a module default) — and the derived world flips. Base facts change by exactly the two
things `wed` compiles to:

```
married.esme.dave
member.esme.kestrel        -- the ! overwrite: member.esme!wren is gone
```

and the closed view derives everything downstream in one pass — she is now a comrade of the whole
house she married into, and inherits the grudge she had no part in creating:

```
allied.bob.esme      allied.esme.bob        -- comrades: shared kestrel membership
allied.carol.esme    allied.esme.carol
allied.dave.esme     allied.esme.dave
married.dave.esme    married.esme.dave      -- marriage symmetry (kinAxioms)
resents.esme.alice                          -- her in-laws' grudge, inherited through the chain
```

Driving 12 ticks with Alice passive (the same `advance`/`npcAct` idiom every other section's
headless traces use) shows the planner picking the newly-derived enmity up on the very first try —
no BLOCK, no tuning:

```
bob: shun alice
carol: shun alice
dave: shun alice
esme: shun alice
bob: (idle)
carol: (idle)
dave: (idle)
esme: (idle)
bob: (idle)
```

Every member of `kestrel` — including the bride who joined that morning — shuns Alice on their very
first opportunity, then idles: nothing else is left for any of them to want.

**What's banked, not built.** Multi-affiliation (one character, several factions at once);
inheritance of holdings beyond bare offices; births (a `parent.*` fact currently has to be asserted,
never generated by play); divorce as a driven *action* (dissolution is tested via raw retraction of
the `married` fact, not a practice a character can choose); and `factionStanding`'s wiring into a
world (stated and deferred above) — all recorded in the ledger's Tier 1 row rather than attempted
this round. The village itself is untouched: no golden churn, because nothing in `Prax.Worlds.Village`
imports `Prax.Faction` or `Prax.Kin` this round.

→ code: `Prax.Faction` (`member`/`joins`/`comrades`/`factionStanding`), `Prax.Kin` (`kinAxioms`/
`wed`/`succession`), `Prax.Worlds.Feud`; asserted in `Prax.FactionSpec`, `Prax.KinSpec`,
`Prax.FeudSpec`.

---

### 30. Confession & absolution — the road back is real, and it narrows (`prax village`) (v32)

`Prax.Confession` gives the village its first way back from a lie. A mark doesn't delete when
confessed — it *converts*: `<who>.lied.<hearer>.<event>` becomes `<who>.confessed.<hearer>.<event>`,
the same memory, a changed valence, so a trait can still price what's left of it. (**v48**: the
discharge verb is an authored parameter, not the hardcoded word `confessed` — the village passes
`"confessed"` and nothing here changes, but recant/boast/admit ride the identical machinery.)
Confessing is self-incriminating by design: it deposits the deed into the hearer's beliefs through
the identical sourced-hearsay channel gossip and lying already ride (v20), so everything §24's
reputation stack does with a belief, it does with a confession too. Absolution is a separate act,
and a refusable one: confessing clears your own conscience; only a second party's *grant* clears
your standing, by
inserting the world's defeater fact. You can confess and be refused — conscience clean, standing
still dirty. And an absolver's patience is not a counter someone increments; it's knowledge —
`incorrigible` points §24's `notoriety` Count idiom inward, so "I've forgiven you enough" derives
from what an absolver *believes*, the same way notoriety itself derives from what a village
believes.

**The shape problem confession almost couldn't solve.** eve's conscience-mark from §25/§28 is
content-shaped — `eve.lied.dana.stole.carol.loaf`, naming *carol*, the person she framed. Her
slanderer standing (§28) derives from something else entirely — the act, `whispered.eve.dana`,
naming *eve*. A confession that converts the mark has to deposit belief in the *act* (what actually
gets eve in trouble) — not a re-assertion of the fabricated content (which would just plant the
frame-up on a new believer). One pattern can't be both the mark's own shape and the deposit's shape
at once; this was flagged as a risk before implementation started, hit for real once the village
wiring was attempted (both naive wirings were built and probed live against the engine; `absolve`
was never offered to anyone under either), and resolved by amending `confess` to take the mark
pattern and the deposit pattern as two separate arguments — grounded only from what the mark itself
binds (the confessor, the original hearer, the mark's own event variables), checked and loudly
erroring on anything else.

**Live, from a clean `villageWorld`.** eve whispers to dana; gale, still at the mill, witnesses the
whisper directly — she already regards eve a slanderer before anyone confesses anything:

```
eve.lied.dana.stole.carol.loaf: True
dana.believes.whispered.eve.dana.seen: True
gale.believes.whispered.eve.dana.seen: True
```

Confessing to gale costs eve nothing — gale already held the regard, so there's no new believer to
spook, and the notoriety threshold doesn't move:

```
eve.confessed.dana.stole.carol.loaf: True
eve.lied.dana.stole.carol.loaf (the lied form, converted away): False
gale.believes.whispered.eve.dana.heard.eve: True
gale.believes.stole.carol.loaf.heard.eve (a re-assertion of the fabricated content): False
```

Note what gale does *not* come to believe: not a re-assertion of "carol stole the loaf" (the
content eve fabricated), only the act and its falsity, sourced from eve herself. That's the
deposit-pattern amendment doing its job — confessing implicates eve directly while leaving carol's situation exactly as §25 left it (untouched, not helped).

gale grants absolution — the defeater lands, both her own and dana's slanderer regards dissolve
from the derived view, and nothing is forgotten:

```
recanted.eve: True
regards.dana.eve.slanderer (derived view): False
regards.gale.eve.slanderer (derived view): False
dana.believes.whispered.eve.dana.seen (memory persists): True
gale.believes.whispered.eve.dana.heard.eve (memory persists): True
```

**Re-offense snaps it back, and this time it's worse.** eve and gale return to the square — where
bob, carol, and "you" already are — and eve whispers again, to bob. The defeater she was just
granted disappears (the same re-steal idiom §24's thief lives under), and because this whisper
happens in a crowded square rather than an empty mill, every bystander there regards her at once —
crossing the notoriety threshold in a single action, something the original mill-side whisper never
did:

```
recanted.eve (snapped away): False
regards.you.eve.slanderer: True
regards.bob.eve.slanderer: True
regards.carol.eve.slanderer: True
notorious.eve.slanderer: True
```

**Fed-up-ness, and its limit.** gale now believes two distinct whispered-lie instances from eve —
the original and the re-offense — and her patience (`incorrigible "whispered.V.H" 2 "incorrigible"`,
a two-strikes threshold authored into `villageAxioms`) is spent:

```
regards.gale.eve.incorrigible: True
gale's own "absolve eve" affordance gone from her menu: True
regards.dana.eve.incorrigible (dana witnessed only the original instance): False
```

dana, who only ever witnessed the first instance, is not yet fed up — patience is per-absolver,
exactly like every other regard in this engine.

**The arc that didn't ship: confessing to the person actually wronged.** The natural redemption
would run through carol, not gale — she's the one eve framed, and forgiving your actual victim
means more than forgiving a bystander. It was built and measured, not just imagined: give carol a
professed `merciful` desire (so eve's own depth-2 lookahead can see through confess→absolve via a
believed model of her), and sweep its magnitude from 0 to 50. At every positive value the result is
identical — confessing to carol scores far below eve's ordinary baseline, never crossing it no
matter how generous the authored mercy (measured live via `scoreActions`, verbatim):

```
mercifulValue=0:      confess to carol about framing carol  ->  -19.73   (worst option)
mercifulValue=5..50:  confess to carol about framing carol  ->    7.92   (FLAT -- value plateaus)
                       eve's routine baseline (Go to mill / Wait / steal / honest work) -> 14.08-17.68
```

The mechanism is structural, not a tuning shortfall. Confessing to carol makes her a *new* believer
of the whispered act — carol wasn't yet a regarder — so the confession itself eats the full,
immediate notoriety-threshold hit, on top of which the planner's own `othersScore` term applies only
a fixed 0.5 discount to the value of a *predicted* third-party absolution. That 0.5 ceiling caps the
achievable relief regardless of how large the authored desire gets; carol's own choice to absolve,
once profitable to her, is a discrete switch, not something that scales continuously with how
merciful she's said to be. Documented here rather than shipped — the "threshold drama" the round set
out to measure, measured, and found insufficient to drive an unforced arc.

**Free play: the secret stays expensive.** Left alone, eve never confesses and gale never absolves —
her lie is not cheap enough, nor is there a believed merciful absolver at depth 2, for the arithmetic
to favor spending it. Driven 100 turns past the original free-play trace §25/§27/§28 all draw from
(double the longest precedent so far), pinned in `VillageSpec` and confirmed green in this round's
own full-suite run:

```
eve.lied.dana.stole.carol.loaf (still unconfessed after 100 turns): True
eve.confessed.dana.stole.carol.loaf: False
recanted.eve: False
```

**Falsification sweep: does the road back reach carol's own injustice?** No — §25 covers this
directly (its own "Update — v32" paragraph, re-checked live rather than assumed): confession clears
the *confessor's* mark and the *confessor's* standing; nothing in this round retracts a belief
already planted in someone else, and nothing lets a third party confess on the framed victim's
behalf. The road back this round builds is real, but it narrows to exactly the people a liar can
face directly — it does not extend to the people her lie reached secondhand, and it does nothing at
all for the people she framed.

→ code: `Prax.Confession` (`confess`/`absolve`/`incorrigible`), `Prax.Worlds.Village`
(`confessWhisper`/`absolveWhisper`, the `honest` trait's second desire, `villageAxioms`'s
`incorrigible` wiring); asserted in `Prax.ConfessionSpec`, `Prax.VillageSpec`.

---

## Feature coverage map

Everything implemented, where it lives, and how to see it. The first block is the engine core (the
bar, Part I); the second is Part II, one row per world/tool.

| Feature | Code | Seen when you… |
|---|---|---|
| Trie DB, `.` descent | `Prax.Db` | (everywhere — all state) |
| Exclusion `!` (corrected) | `Prax.Db.insert` | move (`at!Place` replaces old), order/serve |
| Unify / pattern match | `Prax.Db.unify` | every action precondition |
| `Match` | `Prax.Query` | any action being available |
| `Not` (negation as failure) | `Prax.Query` | greet vanishing after greeting |
| `Eq` (also assignment) | `Prax.Query` | Fulfill (`Eq Actor Bartender`) |
| `Neq` | `Prax.Query` | greet (can't greet yourself) |
| `Cmp` (`lt/lte/gt/gte`) | `Prax.Query` | tipsy threshold; the bell |
| `Calc` (`add/sub/mul`) | `Prax.Query` | drink counter incrementing |
| `Count` | `Prax.Query` | the bell (counting customers) |
| `Subquery` | `Prax.Query` | the bell (gathering the crowd) |
| `Insert` / `Delete` | `Prax.Engine` | ordering, serving, moving |
| `Call` + functions + `FnCase` | `Prax.Engine` | getting tipsy (`recordDrink`→`checkTipsy`) |
| Practice spawning + `init` | `Prax.Engine` | patron drink counters seeded at start |
| Single- & multi-role practices | `Prax.Types`/`Bar` | `world` (1 role), `tendBar` (2 roles) |
| `dataFacts` | `Prax.Engine` | the four beverage choices |
| Wants / utility / lookahead | `Prax.Planner` | bex walking in to order; ada serving |
| Round-robin loop + CLI menu | `Prax.Loop` / `app/Main` | the whole session |
| Emotions (coexisting, targeted, fading) | `Prax.Emotion` `feelToward` | "feels annoyed toward you" after a snub |
| Relationship evaluation (numeric, asymmetric) | `Prax.Core` `adjustScore` | "warmth toward …" climbing/cooling |
| Relationship-gated affordance | `Prax.Core` `scoreAtLeast` | "Buy … a drink" appearing once warm |
| Reactions (spawned practices + response chains) | `Prax.Reactions` | greet → "Greet back"/"Rebuff"; take-offense |
| Norms (violation-marking + disapproval) | `Prax.Reactions` | stiff the tab → "broke a norm" → ada disapproves |
| Norm avoidance in the planner | `Prax.Planner` + a `Want` | NPCs tip rather than stiff |
| Beliefs (per-agent, can be false) | `Prax.Beliefs` | a rumour → "… believes ada resents them" |
| Belief-gated behaviour / revision | `Prax.Beliefs` | a false belief suppresses friendliness; evidence dispels it |
| Conversation (speaker turns, topics, quips) | `Prax.Conversation` | "… are chatting (rapport)"; compliment / gossip quips |
| Story manager (DM) as a metalevel agent | `dmPractice` / `director` | "director: turn ada against bex to stir up the evening" |
| Character arcs (stage-gated wants) | `Prax.Arc` | "bex feels hopeful" → "at home here"; belonging beat |
| Player-only transformation (against desires) | `arc` practice | "give up …" offered but never taken by an NPC |
| First-order connectives (`Or`/`Absent`/`Exists`, `forAll`/`implies`) | `Prax.Query` | endings frozen by `Absent [ending.E]` |
| Deontic obligation (□), discharge/breach, contrary-to-duty (□□) | `Prax.Deontic` | bar: "owes ada a tip" → tip discharges / stiff breaches |
| Cast removal (a character dies and leaves) | `Prax.Engine` / `Intrigue` | `prax intrigue`: do nothing → Artus dies (betrayal) |
| Branching dramatic episode | `Prax.Worlds.Intrigue` | `prax intrigue`: warn/poison/romance → distinct endings |
| Stress-tester + inspector (`explain`) | `Prax.Stress` / `Prax.Inspect` | `prax stress intrigue` (endings, coverage, dead ends) |
| Save / resume (state = the fact DB) | `Prax.Persist` | press `s`; then `prax intrigue resume` |
| Scene-authoring layer (CAST + scenes/beats/junctions) | `Prax.Script` / `Worlds.Play` | `prax play`; `prax flow` prints the scene graph |
| Play-scripts round-trip through JSON | `Prax.Script.Json` | `prax dump-play`; `prax play examples/play.json` |
| Player as drama manager | `Bar.barDirectorWorld` / `candidateActions` | `prax dm`: your menu is authorial nudges |
| Forward-chaining derivation (defeasible) | `Prax.EL` / `Prax.Derive` | `prax feud`: 1 wrong + 4 rules (v31 folds membership in) → a feud; amends dissolves it |
| Static type checker + sort inference | `Prax.TypeCheck` | `prax check <world>` |
| Timed junctions, character sketches (memories: built v18, removed v46 — presentation, not world content) | `Prax.Script` / `Worlds.Audience` | `prax audience` |
| Quantified outcomes (`ForEach`) + authored witnessing | `Prax.Engine` / `Prax.Witness` | `prax village`: carol (co-present) believes bob's theft and can confront him; dana (elsewhere) doesn't |
| Gossip / sourced hearsay (`gossip`/`heard`, multi-valued `.seen`/`.heard.<source>` provenance) | `Prax.Rumor` | `prax village`: carol tells dana what she saw; hearsay licenses suspicion, not confrontation |
| `standing`/`standingUnless`/`regardedAs`/`notoriety` (derived reputation, base-fact atonement defeater) | `Prax.Repute` | `prax village`: three regards tip `notorious.bob.thief`; atonement dissolves every regard while the belief persists; re-offense revokes it and an atoned bob is deterred from a restocked stall |
| Secrets & deception (`conceal`/`lie`) | `Prax.Deceit` | `prax village`: bob's concealment want still gates a watched theft (mid-project opportunism, §26; the scripted "secret keeps"/"perfect crime" tests); eve frames carol, and the lie cascades into real shunning and notoriety with no recourse for the framed |
| Endeavors: part-set practices, dormant pursuits (`endeavor`/`Part`) | `Prax.Project` | `prax village`: bob undertakes `earnBread` unprompted at t=0, sweeps the square in public, and bakes the loaf he'd otherwise have to steal; watching him sweep is enough for the village to presume his purpose and predict his next part |
| Temperament as conduct-valuations (`Trait`/`personaVocabulary`/`bearing`/`transparent`/`cast`); a lie marks the liar (`Actor.lied.Hearer.<event>`) | `Prax.Persona`, `Prax.Deceit` | `prax village`: gale bears `honest` and never lies despite sharing eve's exact spite; everyone presumes her conscience from t=0; a believed conscience nets against a believed motive in `predictMove`; eve's whisper deceives gale too, and (forced, since v30's threshold fear stops her reaching gale unprompted) gale spreads it onward by ordinary gossip, no mark, carrying it back to eve as "evidence" for her own fabrication |
| Debt as a beneficiary'd obligation (`owe`/`settle`), belief-gated deadbeat standing | `Prax.Debt` | `prax village`: a witnessed default derives `regards.<W>.<debtor>.deadbeat`; the debtor himself, unavoidably co-present at his own default, always regards himself one even when no one else does; repayment defeats it by the same base-fact-defeater idiom as v21's thief |
| Blackmail (`shakedown`: threaten/comply/defy/expose), threshold fear | `Prax.Blackmail`, `Prax.Worlds.Village` | `prax village`: a threat is a motive-belief deposit the victim's own round-walk prices; a standing threat is exposable, so stalling ties defiance; carol, holding eyewitness evidence of eve's whisper, shakes her down and buys real silence; eve's own fear of the notoriety brink also makes her a one-shot liar in free play, retelling §27's laundering under a forced continuation |
| Membership as one spine (`member.<who>!<faction>`, `comrades`, belief-gated `factionStanding`); kin derivation (`kinAxioms`: marriage symmetry, sibling, grandparent, one-directional in-laws) and `wed`'s marriage-fact-plus-membership-overwrite; succession as single-slot exclusion | `Prax.Faction`, `Prax.Kin` | `prax feud`: bob/carol/dave share house `kestrel` (`comrades` derives their alliance, replacing the old hand-authored pairwise ties — §19/§29); esme weds into it (`wed "esme" "kestrel" "dave"`), inherits the grudge, and shuns alice unprompted on her first turn |
| Confession & absolution (`confess`/`absolve`/`incorrigible`): a mark converts rather than deletes, confessing self-incriminates through sourced hearsay, absolution is a refusable second-party grant, and an absolver's patience is `notoriety`'s Count idiom pointed inward | `Prax.Confession` | `prax village`: eve confesses her frame-up to gale (already a believer — costless) and gale absolves; a fresh whisper snaps the absolution away; a second absolver, now knowing two instances, refuses further absolution — and confessing to carol, the party actually wronged, never rationally beats eve's baseline at any authored generosity |

If the tables and scene lines don't convince you a feature is really doing what's claimed, the
same behaviours are asserted in the test suite (`cabal test`, 431 tests). Part I: `Prax.QuerySpec`,
`Prax.EngineSpec`, `Prax.PlannerSpec` + `Prax.MindsSpec` (wants/utility/lookahead, now a round-walk
over believed minds — `predictMove`, `charDesires`, `professed`/`conventional`), `Prax.CoreSpec`
(emotions/relationships), `Prax.ReactionsSpec` (reactions, norms, norm-avoidance), `Prax.BeliefsSpec`
(per-agent & false beliefs), `Prax.ConversationSpec` (speaker turns, topics, one-shot quips),
`Prax.ArcSpec` (arc stages), `Prax.DeonticSpec` (□, discharge, breach, contrary-to-duty),
`Prax.DebtSpec` (`owe`/`settle`, the demand→deadbeat-standing lifecycle, belief-gated visibility and
the debtor's own unavoidable self-regard), `Prax.ConfessionSpec` (mark conversion and its priced
residue, the deposit landing as sourced hearsay, absolution's grant/refusal gate, `incorrigible`'s
Count idiom pinned at threshold and per-absolver, re-offense snapping a defeater, and both sides of
the spontaneous-confession and blackmail-defense arithmetic measured live before being pinned),
`Prax.DbSpec` (the trie's exact `!`/`.`/retract semantics, incl. the reverted ghost-pruning
attempt's own regression net — an asserted instance fact must survive its transient children
draining to zero), `Prax.BarSpec`, and `Prax.LoopSpec` (a deterministic
25-turn replay — since v44 the round boundary, not a ticker in the cast, runs the schedule). Part II: `Prax.IntrigueSpec` (death + branching endings, incl. the
confidant/victim `predictMove` split), `Prax.StressSpec`, `Prax.PersistSpec` (save/resume),
`Prax.ScriptSpec` + `Prax.Script.JsonSpec` (scene layer + JSON, incl. the one-boundary story-rule
law, timed junctions/sketches, and the `audience`), `Prax.DirectorSpec` (player-as-DM), `Prax.ELSpec` + `Prax.DeriveSpec` (the
exclusion-logic lattice and forward chaining), `Prax.TypeCheckSpec`, `Prax.WitnessSpec` +
`Prax.VillageSpec` + `Prax.RumorSpec` + `Prax.SightSpec` (`ForEach` witnessing, co-presence, the
confront affordance, sourced hearsay and the gossip gate, and the sighting schedule rule whose
stamps gate whose moves get predicted), `Prax.ReputeSpec` (derived standing, the base-fact
atonement defeater, and notoriety at threshold — `VillageSpec`'s later cases carry the same
mechanisms through the full autonomous arc, the re-offense snap-back, and the resulting
deterrence), `Prax.DeceitSpec` (`conceal`'s shape and its watched/unwatched planner probe,
`lie`'s no-evidence gate, self-framing and subject-is-hearer exclusions, one-shot-per-hearer,
hearing-your-own-lie-back replacing `lie` with `gossip`, and — v25 — the liar's own mark
(`<liar>.lied.<hearer>.<event>`), forgettable and additive, with truthful `gossip` leaving none —
`VillageSpec`'s later cases carry the same mechanisms into the full village: a watched theft still
fails, the perfect crime still needs a genuinely empty square, and eve's frame-up still cascades to
shunning with no recourse), `Prax.ProjectSpec` (`endeavor`'s undertake/part-gating/yield shape on a
standalone oven-building fixture, the pursuit desire's exact shape and its dormant-vs-undertaken
believability, and the horizon regression driving four parts to completion at planner depth 2 —
`VillageSpec`'s later cases carry the same mechanism into the full village: bob's unforced
redemption, the watching-teaches-purpose inference feeding a belief-relative, myopic `predictMove`,
and the mid-project opportunism beat that keeps concealment honest), and `Prax.PersonaSpec`
(`bearing`/`personaVocabulary`/`cast` mechanics and their loud-error guards, `transparent`'s
defeasible presumption, the conduct-valuation core split via `pickAction` on a temptation-bearing
twin pair, the marginal-lie property, and believed-conscience prediction — `VillageSpec`'s later
cases carry the same mechanism into the full village: gale's temperament legible from t=0, the
free-play drive where eve's frame-up proceeds and gale never lies unprompted, and the told-about-spite
prediction contrast between eve and gale), and `Prax.BlackmailSpec` (`shakedown`'s motive-belief
deposit, self-motivated credibility, standing-threat exposure, and the compliance arithmetic pinned
on both sides — two onlookers comply, one rationally defies, an exact stall-tie between defy and
wait — plus the reserved-variable collision guards found in review) — `VillageSpec`'s shakedown-arc
cases carry the same mechanism into the full village: carol's threat lands once she holds eyewitness
evidence, eve complies and the reputation stack stays undisturbed for everyone uninvolved, and
threshold fear leaves eve's below-the-brink free-play whispering exactly as rational as it always
was while retelling, under a forced continuation, the one free-play consequence (§27's laundering)
it structurally forecloses), `Prax.FactionSpec` (`comrades`'s shared-membership derivation and its
`X≠Y`/cross-faction negatives, defection's retraction-safety, `factionStanding`'s belief-gating —
including the fratricide and victim-self-belief pins — and its reserved-variable guards), and
`Prax.KinSpec` (each `kinAxioms` rule positive and negative, `wed`'s two facts and both parties'
name guards, dissolution un-deriving in-laws while membership persists, and the succession
lifecycle's death-gating, child-only claims, and single-slot race resolution) — `Prax.FeudSpec`
carries both into the emergent sandbox unmodified: the five original assertions untouched by the
refactor, plus the wedding beat's derivation flip and driven shunning — `VillageSpec`'s own later
cases carry `Prax.Confession` into the full village: eve's costless confession to gale (the
deposit self-sourced, not a re-assertion of the framed content), absolution dissolving standing
while every belief persists, a fresh whisper snapping the defeater away and landing every square
bystander at once, gale's patience running out at the second instance while dana's (one instance)
doesn't, and eve's frame-up surviving unconfessed through 100 turns of unforced free play.

---

## 可试之事以建立直觉

- **从不自己招待：** 点啤酒，然后持续按 `m`。ada 招待你是因为*她*不想有未完成订单——你从未要求。
- **非酒精 vs 酒精：** 整晚喝汽水；你从不醉（守卫函数 case）。改喝啤酒/苹果酒则计数器上升。
- **点单中途离开：** 点啤酒，然后在 ada 招待前 `Go to entrance`。她无法履行（其 `Fulfill` 要求你们同处）直到你返回。
- **看 bex 的弧结束：** 一旦 bex 有了啤酒，它停止追逐，只在酒吧等待——其最高 want（`beer in hand`）已满足，因此无动作胜过等待。

## 尚未建模的

就现有来源所能评估的范围，**Versu、Praxis 与 Prompter** 的特性现已复现——上方各节即是游览。
剩余（见 `docs/LEDGER.md`）简短且诚实：

- **Prompter 的可读文本剧本表面** *有意* 不复现：可编辑脚本经 JSON 往返（§17），而非定制
  `.prompter` 语法。这是选择的替代，非缺口。
- **自由文本玩家输入（#42，「Play What I Mean」）。** 键入句子并经嵌入模型匹配到 affordance——
  *超出 Versu* 的能力，需要外部模型，因此是要添加的依赖，非要研读的论文。
- **超出 Versu 的扩展** 记为稍后：派生层的增量视图维护、硬优先级层（Swaygent/Ensemble 风格的
  `forbidden`/`required` 高于效用）用于 *范畴性* 规范强制，以及量化/嵌套信念（Versu 自身也无法表示）。
  这些延伸超过 Versu 所做；LEDGER 的「Future ideas」节跟踪它们。（运行时 want 注入无需单独机制——
  门禁在事实上的 want 可通过插入事实注入——且 `Prax.Minds`，v23，在本文 Part I 覆盖的普通 `Want`
  之上给命名欲望可相信、可告知的形式。）

更大的弧，按 LEDGER，是把这从忠实复现长成可嵌入其他游戏（沙盒、roguelike）的涌现社交模拟基底——
`feud` 沙盒（§19）是该方向的第一步。
