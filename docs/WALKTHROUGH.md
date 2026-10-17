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

### 23. Rumor — the news travels (`prax village`) (v20)

`Prax.Rumor` closes the loop §22 left open: a belief someone holds — witnessed or already
secondhand — can now be *told* to a co-present hearer.

The rest of this tour (§§23–24) goes back to following *bob*, not you: v21's reputation arc ends
in an NPC's own remorse and self-deterrence, which only an autonomous character can exhibit, so it
needs an NPC thief. As of v22, getting bob to actually take the loaf in free play stopped
happening on its own (§22, §25): he conceals, and carol — who used to wander off on a tie-break
before her first decision even arrived — now holds her own +1 square-anchor, added in v22 for
exactly this reason (with no theft guaranteed on turn one anymore, her first turns are
zero-utility ties, and an idle character with no anchor drifts on the tie-break, same idiom as
bob's and dana's). The two anchors together mean the square never genuinely empties in autonomous
play. As of v24, bob doesn't even try: from turn one he undertakes `earnBread` instead (§26) — a
strictly better option than waiting out a watched square for a theft he'd have to conceal — so
free play doesn't reach a theft by *any* route anymore, watched square or not.

So what follows is **forced**: bob's theft triggered directly (`doAct`, the exact technique
`Prax.VillageSpec`'s tests use — precisely because free play can no longer reach this state), then
the same production loop the CLI itself runs (`Prax.Loop.advance`/`npcAct`) driven headlessly for
real, additional rounds. This is not `cabal run prax -- village` — it's the identical engine code,
compiled and run directly against `Prax.Worlds.Village` from the scratchpad, real output captured
from a live run, not fabricated or reused from any report:

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

A round is **six** turns now (you, bob, carol, dana, eve, gale — v25 added gale to the cast;
since v44 perception and the clock run at the engine's round boundary, so no ticker character
occupies a turn). carol confronted bob the
instant she witnessed it, same mechanism as §22. eve, independently and for her own reasons (§25 —
not this story), whispers a lie about *carol* to dana in the very same round; the two plots run
concurrently in one world, unprompted by each other. bob, meanwhile, has his own second track
running: v24's `earnBread` doesn't care that he's already holding a stolen loaf, so he undertakes it
in the very same round he's forced to steal:

```
  you: (you wait)
  bob: take up honest work at the stall
  carol: confront bob about the theft
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

Round 2: bob sweeps the square (`earnBread`'s first part, public per §26); carol shuns bob outright
in the square:

```
  you: (you wait)
  bob: sweep the square
  carol: shun bob
  dana: shun carol
  eve: Go to square
  gale: Go to mill
```

— and, a side effect of eve's whisper reaching her the round before, dana shuns *carol* too, for
something carol never did.

Round 3: bob walks to the mill to fetch flour; carol sets off looking for a hearer — she has a want
that others hear the truth about bob's theft *from her* (`Want [carol.believes.stole.bob.loaf,
Other.believes.stole.bob.loaf.heard.carol] 5`) — and the nearest one, eve, has just walked into the
square:

```
  you: (you wait)
  bob: Go to mill
  carol: tell eve that bob stole the loaf
  dana: Go to square
  eve: whisper to you that carol stole the loaf
  gale: Go to square
```

Round 4: with *some* regard already standing against him since turn zero (carol and you both
witnessed the forced theft), bob's own amends outweighs pressing on with the mill trip this round —
he returns the stolen loaf before he's earned his own, and carol relents the same round he does:

```
  you: (you wait)
  bob: return the loaf with apologies
  carol: relent toward bob
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

That last line is the emergent finding this round is built around — §27 covers it in full: eve's
whisper deceives gale too, and gale, now genuinely believing it, passes it straight back to *eve*
by ordinary `tell`.

Round 5 (35 steps in), bob resumes `earnBread` at the mill (fetching flour — atonement didn't cost
him the project) and carol reaches dana specifically and tells her too — a second, independent
source, since `Other` in her want is satisfied by any hearer, not one in particular — and dana,
hearsay in hand, acts on it the same round:

```
  you: (you wait)
  bob: fetch flour from the mill
  carol: tell dana that bob stole the loaf
  dana: Go to mill
  eve: Go to mill
  gale: Go to mill
```

confirmed directly: `dana.believes.stole.bob.loaf.heard.carol` holds true from here on. `gossip`
only requires teller and hearer to be co-present — the mechanism itself doesn't route anyone toward
anyone — but carol's own want reliably puts her wherever an uninformed hearer is, so *she* does the
travelling, exactly as in the pre-v22 village.

Driving on: bob returns to the square (round 6), bakes and earns his own loaf (round 7 — the same
round dana, hearsay in hand, eyes him with suspicion, and eve, having heard her own lie told back to
her by gale, uses plain `tell` rather than `lie` to reach bob directly with the fabrication about
carol), and the village settles by round 10: `atoned.bob` holds, `regards.carol.bob.thief` and
`notorious.bob.thief` are both false in the closed view, no shun toward bob survives, and
`carol.believes.stole.bob.loaf.seen` is still true throughout — the same "atonement, not amnesia"
shape §24 covers, now carrying gale's laundered lie alongside it as an unrelated, concurrent thread.

**The saw/heard affordance asymmetry.** dana, hearsay-only, gets `eye [Thief] with suspicion` — a
milder trust hit (−5, reason `heardOfTheft`) — but never `confront`, which stays gated on `saw`
(−10, reason `sawTheft`): hearsay doesn't license "I saw you." The asymmetry cuts the other way too:
`VillageSpec`'s "hearsay licenses suspicion, not confrontation" confirms carol, the eyewitness, is
never offered mere suspicion — `eye` is gated on `heard "Actor" "<event>"` **and**
`Absent [Match "Actor.believes.<event>.seen"]`, so seeing subsumes hearing for the milder act.

**Sourced-hearsay vocabulary.** Provenance is no longer the single exclusive value v19 shipped
(`!seen`) — it's multi-valued: `<W>.believes.<event>.seen` for direct witness, one
`<W>.believes.<event>.heard.<source>` edge per teller, coexisting under the same `believes.<event>`
node. A witness who is *also* told keeps their `.seen` edge rather than losing it to an overwriting
`!heard` — the capture bug the v19 review flagged and banked for this round. Each further teller
adds another `.heard.<source>` edge, so corroboration is just counting distinct sources; `heard`
itself is a boolean `Exists` over that subtree, so two sources still yield one row in the menu, not
a duplicate tell.

**The distrust gate.** `gossip`'s world-supplied gate (worlds add their own extra conditions, the
way `Prax.Witness`'s `together` co-presence template is world-supplied) is "you don't gossip with
someone you distrust":

```haskell
Absent [ Match "Actor.relationship.Hearer.trust.score!TrustScore", Cmp Lt "TrustScore" "0" ]
```

The spec sketch named this variable `V`; the shipped code calls it `TrustScore`, because the
village practice's own role is *also* named `V` (`roles = ["V"]` in `Prax.Worlds.Village`) — reusing
`V` here would have silently captured that binding instead of introducing a fresh condition
variable, a real bug caught before it shipped rather than a stylistic choice. With no trust score
recorded, gossip flows freely; once trust drops below zero the tell disappears from the menu, same
as any other gated affordance.

→ code: `Prax.Rumor` (`gossip`/`heard`), `Prax.Worlds.Village`; asserted in `Prax.RumorSpec`,
`Prax.VillageSpec`.

### 24. Reputation — standing, notoriety, atonement, and a thief who learns (`prax village`) (v21)

`Prax.Repute` closes the loop §§22–23 opened: evidence that reached someone — witnessed or only
heard — now *settles into what they think of you*, a derived standing that shapes behaviour
without anyone storing a reputation fact. Continuing straight on from §23's forced session (same
compiled-against-the-library technique, same running world — bob's theft was forced there because
free play no longer reaches this state; see §22/§25):

The instant carol (an eyewitness) believed the theft, she also came to *regard* bob a thief — a
fact nobody wrote, derived from her belief — and standing already had teeth: `shun bob` was
available to carol on the very same gate (`regardedAs "Actor" "T" "thief"`) that would offer the
player `shun bob` too, that same beat (round 1, already shown in §23).

By round 3, carol has told eve, who — hearsay-only — comes to regard bob too: §23's saw/heard
asymmetry (suspicion, not confrontation) carries straight into standing, since hearsay is evidence
enough to *regard* exactly as it's evidence enough to *believe*. With carol (witness), you
(witness), and eve (hearsay from carol) all regarding bob a thief, the third regard tips
`notoriety "thief" 3` — "the whole village knows" — and bob's want against `notorious.bob.thief`
(−15) now outweighs the loaf in his hands (+10). One round later, he returns it, the same round
carol relents (dana never regards *bob* at all in this run — eve's lie reached her first, so her
only regard is the wrongful one, §25):

```
  you: (you wait)
  bob: return the loaf with apologies
  carol: relent toward bob
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

(dana, eve, and gale's lines here are entirely eve's frame-up of carol, §25 — and, as of v25, its
unexpected sequel: gale's own line is her passing the lie right back to the liar, honestly believed
— §27 has the full account. The two stories are threaded through the same seven-turn rounds, and
all of it is real, unstaged output from the one run.)

**Atonement, not amnesia.** Every line derived from bob's own theft vanishes at once — not because
anyone forgot, but because their only support (the absence of `atoned.bob`) is gone. Checked
directly against the same session: `atoned.bob` holds; `regards.carol.bob.thief` and
`notorious.bob.thief` are both false in the closed view; and — the point of the exercise —
`carol.believes.stole.bob.loaf.seen` is still **true**, exactly as before. Nobody's belief moved;
`standingUnless`'s defeater dissolved the *derivations*, on the same read, while the belief that
supports them (when the defeater is later revoked) sits untouched. This is `VillageSpec`'s
"atonement dissolves standing while memory persists," and it's not something a plain scene render
shows directly (the scene prints derived standing, not raw beliefs) — which is exactly why this
walkthrough checks the underlying facts instead of just the narration, here and below.

**Deterrence: the stall stays stocked — and, as of v24, bob really does end up holding a loaf, the
one he earned.** Driving the same forced session onward — every shun toward bob already relented by
round 4, shown above — out to round 15 (105 steps, seven-turn rounds — the same budget
`VillageSpec`'s "an atoned thief is deterred" test drives), bob's `steal the loaf from the stall` is
still on his own menu, unrefused by any gate, but he spends the early turns of the same window on
`earnBread` instead of waiting on it, and finishes well within the 105:

```
bob's steal-the-loaf option still on the menu, unrefused: True
stall.loaf present: True
bob holds a loaf: True
the loaf he holds is the one he earned: True
bob's atonement still stands: True
```

— he never re-steals, for the whole remaining run. `stall.loaf` really is still there — his own
`steal` action is the only thing that would take it, and he doesn't. `holding.bob.loaf` is true
for a different reason than the pre-v24 story: not a still-unsatisfied theft-linked want lying in
wait for a future re-offense, but `practice.earnBread.bob.done.s3` — the loaf he's holding is the
one he baked, during this same 105-turn window. This is exactly what `VillageSpec`'s "an atoned
thief is deterred" test now asserts directly (amended under v24, spec §3): its old proxy — "bob
holds no loaf" — was falsified by the correctly-implemented redemption, not by a bug, so the test
now pins non-re-offense on its own terms (atonement standing, the stall untouched, and the loaf he
holds traced to the endeavor's own completion fact) rather than a fact the endeavor was always
going to make false.

Re-checked live against the current planner at this same terminal state, `scoreActions` at depth 0
ranks `bob: Wait a moment` at **20.0** against `bob: steal the loaf from the stall`'s **5.0** —
unchanged from v24's own numbers. What *has* changed under v25's cast: `20.0` is no longer bob's
uniquely top score, it's a fourteen-way tie. bob was himself drawn into eve's frame-up of carol
along the way (`eve: tell bob that carol stole the loaf`, round 7, §27 covers the mechanism that
put "evidence" in eve's own hands to tell it plainly) — so his menu now carries a whole family of
zero-marginal-utility options about carol (`eye carol with suspicion`, `shun carol`, `tell` each of
several villagers), every one of them scoring exactly the same baseline as simply waiting. Stealing,
at 5.0, remains far below all fourteen — the deterrence comparison itself is unaffected by how
crowded the top of the ranking gets. Stealing again would instantly flip `notorious.bob.thief` back
to true (the same defeater-deletion mechanism as before: the deed's own outcome deletes
`atoned.Actor`, and the regards nobody ever stopped believing revive on the very next read, no
lookahead required) and forfeit concealment's reward now that the deed would, once again, be
witnessed. This isn't a foreseen future; it's an immediate consequence of the action, exactly like
§8's stiffing aversion. An unatoned bob was tipped into atoning; an atoned bob, seeing that
consequence right in front of him, doesn't re-offend — he has better things to do, and v24 gives him
one. `VillageSpec` pins both facts — "re-offense revokes atonement: standing snaps back from memory"
forces a second theft by hand and asserts the regards return, and "an atoned thief is deterred: the
planner sees the snap-back" drives the same 105 autonomous turns and asserts non-re-offense (the
full arc itself is driven for 70 turns in "the whole arc runs itself").

The shun/relent/tell options never resurface either — with no live regard, the wants that drove
them (carol and dana's shun-want is *conditioned* on `regardedAs`, per the design spec, so it
evaporates with the regard rather than fighting a stale shun to a tie-break) simply have nothing
left to pursue. The full mechanism — `standing`, `standingUnless`, `regardedAs`, `notoriety`, and
the world's choice to key bob's shame on notoriety rather than any one regarder's contempt — is
documented in `docs/specs/2026-07-10-v21-repute-design.md`.

→ code: `Prax.Repute` (`standing`/`standingUnless`/`regardedAs`/`notoriety`), `Prax.Worlds.Village`
(`shun`, `return the loaf with apologies`, `relent`, `villageAxioms`); asserted in
`Prax.ReputeSpec`, `Prax.VillageSpec`.

### 25. Secrets & deception — a villain, and an honest injustice (`prax village`) (v22)

`Prax.Deceit` adds the adversarial layer §§22–24's information stack (witnessing → rumor →
reputation) was always going to need: agents who *manage* what is known, rather than just
carrying it. Two mechanisms, both authored as ordinary wants and an ordinary action — no stealth
system, no lie-detection engine, nothing new in `Prax.Engine`:

- **`conceal`** is a want that nobody believe some deed (`Absent [Anyone.believes.<event>]`). It
  needs no enforcement of its own — the planner's lookahead already simulates the v19 witness
  deposits before choosing an action, so an agent who values the secret simply never scores the
  witnessed version of the theft as highly as the unwitnessed one. Waiting for privacy falls out
  of ordinary utility maximization.
- **`lie`** mirrors v20's `gossip`, inverted twice: the speaker must hold **no** evidence of the
  event (that absence is what makes it a lie, and it's also the action's own undoing — the instant
  the liar hears their own lie told back to them, they acquire evidence, the `lie` action's gate
  closes, and plain `gossip` takes its place, seamlessly), and the fabricated subject is bound from
  a world-supplied *fabrication* condition (whom you could plausibly frame) rather than from a
  belief. The effect it inserts — `<Hearer>.believes.<event>.heard.<Actor>` — is *identical* to
  `gossip`'s. That identity is the whole design: the deceived hold real hearsay, structurally
  indistinguishable from the genuine article, and the entire v20/v21 machinery (retelling,
  corroboration, standing, notoriety, shunning) runs on the falsehood unmodified.

**bob conceals — but no longer by waiting.** `conceal "stole.bob.loaf" 12` — worth more than the
loaf itself (+10) — is exactly the want it was in v22: it rewards a deed nobody comes to believe,
and it still fails the instant anyone would see the theft. What changed in v24 is what a watched
bob *does* about that: earlier, avoiding a witnessed theft meant simply waiting it out; now
`earnBread` is on the table, and industry beats patience, so he takes it instead — §26 tells that
story start to finish, live. Concealment itself hasn't gone anywhere; it still gates the same
choice, just later in the story. Two scripted probes still isolate the mechanism on its own,
unconfounded by the endeavor, and both still pass:

- `Prax.DeceitSpec`'s minimal fixture probes `conceal` in isolation — watched vs. unwatched,
  nothing else in play.
- `VillageSpec`'s "a secret keeps: bob will not steal while the square watches" (28 driven turns
  from a clean `villageWorld` — four seven-turn rounds) and "the perfect crime: alone, bob steals
  and no one ever knows" (carol and you sent to the mill by hand, 14 driven turns — two rounds)
  both hold. "The perfect crime" is
  worth pausing on: even with `earnBread` now available, a *truly* alone bob still steals rather
  than starting the endeavor — opportunism outranks patient industry the moment nobody's
  watching, exactly as sharply as before v24. §26's "the opportunism stays honest" beat is the
  same finding told mid-project instead of at the very first turn: concealment isn't about the
  player, it's about *anyone* watching, wherever in the story the temptation lands.

Free play itself no longer reaches "bob waits" at all — not with the player present, not with the
player gone to the mill. Before v24 free play printed `bob: Wait a moment` on every idle press;
today's identical input prints the redemption from turn one (§26 walks through it). What free play
*does* still show, unprompted, in that very same session, is a second and wholly independent plot
running in its gaps: eve's frame-up of carol.

**eve joins, and frames carol.** eve starts at the mill — placement matters: she must not witness
the scripted thefts v19–21's own tests force, so their two-witness arithmetic stays intact — with
one authored want, now a named vocabulary desire shared with gale (`spites-carol`, v25 — see §27):
`Want [Match "regards.W.carol.thief"] 4`, wanting carol ill-regarded, per head, and not caring how.
`lie` gives her the means. This is the same six-`m`-press, player-present run §26 draws bob's
redemption from; eve's campaign runs alongside it from the first beat:

```
>   bob: take up honest work at the stall
  carol: Wait a moment
  dana: Wait a moment
  eve: whisper to dana that carol stole the loaf
  gale: Go to square
```

— and `dana regards carol as a thief` derives on the very same beat, a fact nobody wrote, from a
claim nobody witnessed. The very next round, dana acts on it, while bob is mid-sweep:

```
>   bob: sweep the square
  carol: Wait a moment
  dana: shun carol
  eve: Go to square
  gale: Go to mill
```

eve keeps moving to wherever an untold villager is and keeps whispering — dana first, while both are
still at the mill, then you once she's walked to the square (press 3). gale, meanwhile, has been
drifting on her own idle tie-break (mill → square → mill → square) and by press 4 is standing right
beside eve in the square, untold — the same coincidence of place that made carol and you eyewitness
bob's theft in §22. eve reaches her, and this is where the story changes shape from every earlier
round of this world: eve's fabrication doesn't just add a fourth *believer*; it adds a *bystander
who honestly spreads what she now believes*:

```
>   bob: fetch flour from the mill
  carol: Wait a moment
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

gale, deceived like everyone else eve reaches, comes to regard carol a thief on the strength of it
— and, in the very same round, passes the belief on by ordinary `tell`, straight back to eve. That
one round adds *two* regards at once: gale's own (from believing the lie) and eve's own (from
gale's honest corroboration of her own fabrication — the liar now holds real hearsay for a claim
she invented). Two regards land in the same round that only ever added one before, and it's enough:
notoriety over *carol* tips on **press 4**, two presses earlier than the shape of every prior round
of this world (§27 has the full account of why):

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

bob himself is caught up a round later still (press 5: `eve: tell bob that carol stole the loaf` —
plain `tell`, not `lie`, since eve now holds gale's hearsay as her own evidence), and finishes
baking his own loaf the round after that (press 6, §26). bob's own redemption and carol's frame-up
run to completion in the same six-press window, unstaged and unprompted by either story:

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

**Update — v30.** This entire cascade — eve reaching "you" at press 3, then gale at press 4, gale's
honest corroboration tipping carol into notoriety two presses early — was true through v25 alone. It
no longer reproduces from the identical input once `Prax.Blackmail` lands (v30, §28): threshold fear
makes eve prudent the instant she holds two regarders, which happens on her very *first* whisper
(dana and gale are both co-present at the mill when she frames carol, so one whisper deposits two
regards at once, the whispering ACT itself now being witnessable). Any whisper after that risks a
third regarder and notoriety outright, so she never risks it. Driving the identical run today,
checked directly: eve whispers exactly once, ever; only dana ever comes to regard carol a thief;
carol is shunned by dana alone; nobody else — not "you", not gale, not bob — ever hears the claim
from eve, and `notorious.carol.thief` never derives in free play. The two scene blocks above are
kept as a historical (pre-v30) capture, because they show the mechanism this section is really
teaching — a fabrication is structurally indistinguishable from truth once believed, and an honest
believer can spread it just as effectively as the liar — which is still exactly true; §28 reproduces
it on demand, forced rather than stumbled into, alongside the threshold-fear story that changed
*this particular free-play outcome*, not the mechanism underneath it.

Nobody in the scene captured above did anything wrong except eve — and, unwittingly, gale, whose only
fault was believing what she was told and doing exactly what an honest villager does with a belief:
sharing it. carol never went near the stall. And yet the regard, the shunning, and the notoriety were
all real, derived facts, indistinguishable — to `Prax.Repute`, and to every villager but eve — from
the ones bob earned honestly in §24. That's the design's central claim from the spec, borne out live:
*fabrication planted ordinary `.heard.<liar>` hearsay ... the lie propagates as truth because
hearsay and fabrication are indistinguishable to everyone but the liar* — and, as of v25, that
includes propagating through someone who would never lie herself.

**The injustice is honest: carol has no recourse.** eve's frame-up doesn't depend on bob at all —
it's driven here from a fresh, *unforced* `villageWorld` (exactly `VillageSpec`'s own setup:
`driveIdle "you" 40 villageWorld`); through v25, the same cascade shown above ran on its own from
there, without anyone needing to force anything (as of v30, dana's own regard is as far as it gets
unforced — the update above). What doesn't depend on the cascade completing at all: checking carol's
own `possibleActions` directly at that point
(compiled directly against the library from the scratchpad, live, same technique as §23–24):

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

`take up honest work at the stall` is new here as of v24 — the undertake action is offered to
*anyone* standing at the square, not just bob (`Prax.Project.endeavor` gates on place, not
identity), so it's on carol's menu too. Nothing in her own wants motivates her to take it (only
bob carries `charDesires = ["pursues-earnBread"]`), so it sits unchosen — an unmotivated
affordance, not a live pursuit; §26's own opportunism beat rests on exactly this asymmetry: the
option's availability doesn't imply anyone wants it.

No `return the loaf with apologies` — and there never will be. That action's own precondition is
`Match "holding.Actor.loaf"`, and carol never held one; amends requires the thing she never took.
This isn't a missing feature — the vocabulary has no notion of *ground truth* an accusation could
be checked against, so there is nothing for anyone (carol included) to point to that would clear
her name. `Prax.VillageSpec`'s "the framed have no amends: carol is offered no return" pins exactly
this. Exculpation would need an event record — something actions could be checked against — banked
for a future round (`docs/LEDGER.md`'s backlog), not faked here with a shortcut that would make the
injustice ring false. The player has the identical `whisper`/`lie` affordance eve does (visible in
every menu throughout this section) — nothing stops *you* from framing someone too, or from
clearing carol's name by simply not believing eve's lie, which changes nothing about what everyone
else now believes.

**Update — v32.** The central claim is still true, checked directly, not merely still-plausible:
`Prax.Confession` (§30) gives the *liar* a road back — eve can confess and be absolved — but
confession only converts the confessor's own mark and clears the confessor's own standing. Nothing
in it lets anyone confess *on carol's behalf*, and no affordance retracts the false belief eve's lie
already planted in dana, gale, and anyone else it reached. Re-checked live rather than assumed
unchanged, carol's own menu after the identical 40-turn drive does differ from the dump above in
one respect — not the one that would matter: eve, who never confesses in unforced play (her secret
stays expensive, exactly as §30's own free-play pin shows), happens to be standing in the square
by turn 40 rather than the mill, so four new `whisper to eve` options appear (she's now a reachable
hearer, nothing more):

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

Where a mover ends up by turn 40 is sensitive to the whole cast's candidate sets on every
intervening turn (this trace was never one of `VillageSpec`'s own pinned trajectories — only
`freePlayAt`/`whisperArcAt`/`redemptionArcSetup` are — so nothing in the suite depends on it
holding byte-for-byte), and this round adds candidate actions to several characters' turns even
when never taken. What matters is unaffected: still no `return the loaf with apologies`, still no
exculpation affordance of any kind, for carol or anyone confessing on her behalf. The road back this
round builds narrows the space of injustice — a liar can now make it right with the people she
wronged directly — without touching this one at all.

→ code: `Prax.Deceit` (`conceal`/`lie`), `Prax.Worlds.Village`; asserted in `Prax.DeceitSpec`,
`Prax.VillageSpec`.

### 26. Industry — endeavors, purpose read from watching, honest opportunism (`prax village`) (v24)

`Prax.Project` gives the village's moral arc its resolution. An authored endeavor *type*
(`endeavor pid weight undertakeLabel gate parts`, built from `Part`s) compiles to three things a
world wires in once: an undertake `Action`, a `Practice` whose parts are a *set* (one instance per
owner — undertaking twice is never offered again), and a named pursuit `Desire` that pays
`+weight` for every completed part. Progress *is* the reward, so a long project needs no planner
change: every available part is ordinary local utility the moment its gates are met, never a
foreseen end the lookahead has to plan toward. A plan is a set, not a linear chain — parts complete
independently and in parallel, not all required for success, so the set of completed-part facts is
the state and there is no progress cursor; a part's `partAfter` names the sibling parts that must
finish first (a validated, structural edge), and `partNeeds` carries world resources and threshold
gates. The pursuit desire is **dormant** — zero bindings, zero utility — for any disposed character
with no instance yet; undertaking (an ordinary planner choice) is what switches it on. bob carries
the disposition from the start (`charDesires = ["pursues-earnBread"]`), silent until he acts on it.
`Prax.Worlds.Village`'s `earnBread` is three parts in a chain — sweep the square (public —
`witnessed together "swept.Actor"`, `Prax.Witness`'s deposit-builder now exported as a first-class
combinator for exactly this), then fetch flour at the mill (`after ["sweep"]`), then bake at the
square (`after ["fetch"]`) for the loaf he'd otherwise have to steal.

**The redemption, captured live.** A completely clean start, pressing only `m`:

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

— and, one press at a time, the rest of the endeavor plays out entirely on its own. bob's own line,
real and verbatim, one per round for the next five presses:

```
  bob: sweep the square
  bob: Go to mill
  bob: fetch flour from the mill
  bob: Go to square
  bob: bake and earn the loaf
```

Six presses, deterred bob to fed bob, no forcing anywhere — the identical technique `VillageSpec`'s
"deterrence plus opportunity yields industry: watched bob earns his loaf" drives headlessly
(`driveIdle "you" 49 villageWorld` — seven-turn rounds now, so six full rounds is 42 turns, with a
seventh round's margin in the test's own budget), which pins the turn this completes on: `s3`
(baking) is first true after **turn 37** of that count, `holding.bob.loaf` true, `stall.loaf`
untouched (he never went near it), and no theft belief about bob anywhere — this is a loaf he
*baked*, not one anyone had to witness him take. (The very same six presses are also where carol's
frame-up, running in parallel, plays out — through v25 alone it tipped into notoriety; as of v30 it
no longer does, §25's own update explains why, and §28 tells the rest of that story.)

**Watching him work teaches the village his purpose.** Sweeping is public, so anyone who saw it
comes to believe `swept.bob` — and `villageAxioms` adds one inference rule for exactly this:
whoever believes bob swept presumes he's pursuing `earnBread`, the same "watching settles into a
belief about someone's mind" pattern v21 already used for reputation, now aimed at a desire instead
of a deed. Because that presumed pursuit is an ordinary believed `Desire` (`Prax.Minds`), it feeds
`predictMove` directly — with a genuine nuance live testing turned up, checked directly (compiled
directly against the library, real output):

```
carol saw the sweep: True
carol presumes the pursuit: True
carol's predicted move for bob, still at the square: Nothing
carol's predicted move for bob, now at the mill: Just "bob: fetch flour from the mill"
dana's predicted move for bob, co-present at the mill but never told: Nothing
```

`predictMove` is **myopic**: even carol, who both saw the sweep and holds the presumed-pursuit
belief, predicts *nothing* while bob's still standing at the square — the model only pays off once
the next part is an available move (the sweep is done, the mill trip is next, and predicting
"stand still" would gain nothing over the model's baseline). The instant bob reaches the mill, the
same belief resolves to the exact next part. And prediction is **belief-relative, not
proximity-relative**: dana, standing right next to bob at the mill the whole time, never saw the
sweep and was never told — she predicts nothing either, even though she's more physically
co-present with bob than carol is at that moment. The model reads the predictor's beliefs, not the
mover's true state or the predictor's eyes — exactly the property v23 built `predictMove` to have,
now exercised by a desire instead of a plot.

**The opportunism stays honest.** Deterrence and industry both hold only because bob is being
watched; the story would ring false if concealment quietly stopped mattering once he had somewhere
respectable to be. Mid-project — undertaken, sweep already done — with the square genuinely
empty (`carol` and `you` both sent to the mill by hand, the same forcing technique §25's scripted
tests use), bob's own top-ranked move flips:

```
bob's top pick, square empty mid-project: Just "bob: steal the loaf from the stall"
  71.18  bob: steal the loaf from the stall
  60.46  bob: Wait a moment
  50.46  bob: Go to mill
```

Stealing (71.18 — concealment's +12 back in play now that nobody's watching, on top of the loaf
itself) beats continuing toward the next part (`Go to mill`, 50.46 — the step that leads to the
endeavor's comparatively modest flat `+3`) by a wide margin — the same shape of comparison the
"perfect crime" beat of §25 shows at turn zero, here reproduced mid-project. bob is honest because
honesty is *currently* the higher-scoring path, watched; the instant it stops being watched, the
ranking reverts exactly as it would have before v24 existed. `VillageSpec`'s "the opportunism stays
honest: an empty square mid-project still tempts" pins this precise comparison.

→ code: `Prax.Project` (`endeavor`/`Part`), `Prax.Witness` (`witnessed`, now exported),
`Prax.Worlds.Village` (`earnBreadTake`/`earnBreadP`/`earnBreadPursuit`, the inference axiom);
asserted in `Prax.ProjectSpec`, `Prax.VillageSpec`.

### 27. Temperament: the honest villager (`prax village`) (v25)

`Prax.Persona` gives the village its first character built from *conduct*, not just wants. gale
joins the cast (via `cast`), eve's contrast pair: both women carry the identical named desire
`spites-carol` (`Want [Match "regards.W.carol.thief"] 4` — eve's old, unnamed malice from §25, now
vocabulary so it can be *believed*), but gale also bears `honest`, a `Trait` that costs her own
`lied` marks (−6 each) rather than forbidding the lie outright. Nothing stops her from whispering —
the arithmetic does.

**(a) Legible from t=0.** `transparent` derives that every character presumes a bearer's
conduct-valuations, defeasibly, before a single turn is played. Checked directly against
`readView villageWorld`:

```
carol presumes gale's conscience: True
dana presumes gale's conscience: True
carol presumes gale's spite (unheralded, so no one presumes it): False
carol presumes eve's conscience (eve bears no trait): False
```

Temperament is worn on the sleeve; malice is not — spite stays exactly as unreadable as eve's old
unnamed want (§25) until someone is actually told (as (c) below plants).

**(b) A driven run: eve's frame-up lands, gale's psyche stays unmarked — and the lie launders
through her anyway.** This is the same six-press, player-idle run §25 and §26 both draw from
(`driveIdle "you" 49 villageWorld`, or the identical CLI session pressing `m` six times). eve
whispers to dana, then you, then reaches gale on press 4:

```
>   bob: fetch flour from the mill
  carol: Wait a moment
  dana: eye carol with suspicion
  eve: whisper to gale that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

gale is deceived exactly like everyone else eve reaches — she has no way to know the claim is
false — and an honest believer turns out to be the *perfect* vector: in the very same round she
passes on what she now genuinely holds, by ordinary `tell`, not `lie`. Checked directly against the
driven state:

```
eve's frame-up went ahead (dana.believes.stole.carol.loaf.heard.eve): True
eve carries the mark of it (eve.lied.dana.stole.carol.loaf): True
gale's psyche unmarked (no gale.lied fact anywhere): True
edges heard "...heard.gale": [("eve","carol")]
everything gale passed on, she honestly believes (gale.believes.stole.carol.loaf): True
eve now holds evidence heard from gale — the lie laundered back to its own author: True
```

gale never lies — the mark that would prove it is provably absent from the whole database — and yet
the fabrication travels through her all the same, indistinguishable from truth on her end because,
to gale, it *is* truth. She even carries it back to eve (`eve.believes.stole.carol.loaf.heard.gale`),
handing the liar real "evidence" for her own invention: the very next round, eve reaches bob with a
plain `tell`, not a `lie` — the gate closed the instant she acquired that evidence, exactly as
hearing your own lie told back does (§25). **The honest villager launders the lie.** This was found
in implementation, not predicted by the spec's first draft (which wrongly guessed gale would leave
no trace at all); the spec was corrected in place once this run was observed
(`docs/specs/2026-07-11-v25-persona-design.md` §4, "The laundering"), and it's also why carol's
notoriety tips two presses earlier than any prior round of this world managed — §25 has that count.

**Update — v30.** The transcript above — eve reaching gale directly, in free play, at press 4 — no
longer reproduces from the identical input. `Prax.Blackmail`'s threshold-fear resolution (§28) makes
eve prudent after her very first whisper (dana and gale both regard her the instant she frames
carol, since both are co-present for the act): any further whisper risks the third regarder and
notoriety outright, so in free play she never sends one, to gale or anyone else. The sharper,
current free-play fact is "exactly one whisper, ever" (`Prax.VillageSpec`'s own assertion on the
identical 49-turn trace), not the three-whisper cascade shown above. The laundering *mechanism*
itself — an honest believer spreading a lie she was honestly deceived by — is still real; it just
isn't something eve's own planner chooses to demonstrate anymore. §28 forces exactly the whisper her
prudence now declines and shows gale relay it precisely as she does above, live, so the finding stays
pinned rather than quietly losing its only test.

**(c) The prediction contrast.** Planting the identical motive-belief about both women in dana's
head — `dana.believes.desires.eve.spites-carol.heard.you` and the same for gale — and asking
`predictMove` for each, with gale's conscience already presumed since t=0 (a):

```
predictMove dana eve  = Just "eve: whisper to dana that carol stole the loaf"
predictMove dana gale = Nothing
```

Believed malice alone predicts a whisper; believed malice netted against a believed conscience
(+4 − 6) predicts nothing. A believed temperament changes what others expect you to do, not just
what you actually do — the same believed-mind machinery v23 built for plots now carries character.

→ code: `Prax.Persona` (`Trait`/`personaVocabulary`/`bearing`/`transparent`/`cast`), `Prax.Deceit`
(`lie`'s new mark outcome), `Prax.Worlds.Village` (`honest`, `spitesCarol`, gale); asserted in
`Prax.PersonaSpec`, `Prax.DeceitSpec`, `Prax.VillageSpec`.

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
