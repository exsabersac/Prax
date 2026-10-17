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

### 28. 杠杆：敲诈与债务，已标价（`prax village`）（v30）

backlog 中最老的具名承诺（自 v22 起为独立设计轮搁置）落为两薄模块，骑乘已交付机械：`Prax.Debt`（带受益人的义务）与 `Prax.Blackmail`（`shakedown`，威胁/服从/违抗/曝光协议）。两者皆在规格写前现场探针验证——机制每步各自有动机，无脚本「反派 AI」。

**债务是义务，已标价。** `owe creditor debtor content` 一次调用插入 `debt.<creditor>.<debtor>.<content>` *与* `oblige debtor content`——债务 *就是* 义务，非仅耦合。`settle` 逆转两者。违约变声誉的方式与 v21 盗窃相同：`demand` 动作把 `Deontic.breach` 包在 `Prax.Witness.observable` 中，故 *被目击的* 违约存入信念，且 `standingUnless` 仅从该信念派生 `regards.<W>.<debtor>.deadbeat`——未被目击的违约对不在场者派生无 regard。例外一：债务人自己。他在自有违约时不可避免同场（`Witness.observable` 的 `Neq Witness Actor` 只排除 *债权人*，从不排除债务人），故他总 regard 自己为老赖，无论是否有他人目击——评审在初稿发现自 regard/第三方传播区分未充分规格化，交付测试现直接断言。偿还经插入 `atoned.<who>` 击败站队——与 v21 小偷已用的同一正事实击败者惯用语——而他一度违约的信念原封不动：声誉从信念流出，从不从原始事实，自 v21 未变。

**威胁是动机信念存款。** `shakedown` 围绕一证据模式与一价格编译四个动作。`threaten` 插入 `threatened.<extorter>.<victim>` 并种下倾诉与说谎已骑乘的同一类信念（v20/v22）：受害者开始相信敲诈者自有惩罚性欲望，有源（`.heard.<extorter>`）——无读心，只是本引擎其他每个信念使用的同一信道。受害者自有 round-walk 然后做标价工作：它预测敲诈者可能对该公开欲望 *行动*，如同预测任何其他被信念动机。

**威胁为何可信：自我动机，非全知。** 探针的中心发现——诚实陈述因进入时并不显然——是敲诈者无需预测服从即可使威胁理性。威胁所公开的惩罚性欲望（`punishes-<id>`，一旦被威胁或违抗每信徒 `+w`）是真正持有的，且曝光在一前瞻 ply 外从其获益——故 `threaten` 按自身条款得分，短视且对无动机动作盲目，恰如其他每个 `predictMove`。纯虚张声势（无欲望的存款）在词汇可表达，但不会自我激励去发送——与剧本层一并存下，本轮未尝试。

**站立威胁也可曝光。** 探针先发现经典空洞：仅把门禁于违抗使拖延永远免费——从不行动的受害者永不被罚。`expose` 在 `threatened` *或* `defied` 上触发，故等待与违抗打平而非压过它。

**服从算术，两边钉死。** `BlackmailSpec` 经 `shakedown` 移植会话探针自有夹具，断言精确数字而非仅方向：两名旁观者时，买沉默得分 −63.84，对照等待 −71.84 与违抗 −75.80——服从胜。剥到一名旁观者，违抗与等待得分完全相同，恰 −54.2（拖延平局，断言为相等而非不等）——买仍为 −63.84，现为 *最差* 选项。仅观众规模翻转决策；规格陈述算术以便世界作者有意标价威胁，而非凭感觉。

**真 bug，由 planner 自有前瞻发现——并由此存下一 backlog 项。** 移植探针浮现真实分歧：`comply` 早期草稿无守卫防止被买两次，递归前瞻发现可以——付过一次后的更新威胁再榨取，且 *重复榨取的前景* 把第一次购买决策自身分数膨胀到 −51.24，对照有守卫的规范 −63.84。修复恰镜像探针（`comply` 现要求无已站立债务）；发现——planner 在任何人设计前自行发现重复敲诈——把 **升级/连环敲诈** 存为 `docs/LEDGER.md` 中真实未来机制，非假想。**该存款现于 v54 清偿**：`coComplianceLasts = Just n` 寿命使 `complied` 标记到期，勒索循环——每购买周期一次购买，然后敲诈者再榨取——无新逻辑，此处的永久成为 `Nothing` 情形。购买保护钱包，从不保护人（无 fiat 裁定）：背叛 vs 等待是涌现的 `pickAction` 打分，无标记强制。

**村庄演示发货前被挡两次。** 两草稿弧皆在测量轨迹上失败：按头恐惧无法低到让 eve 在保证目击证人前继续低语，又高到迫使服从——一权重，两不可调和工作。且盗窃证据敲诈抓被构陷者与抓有罪者一样容易（v22 的全部要点，此处仍真），会置换 dana 已交付的面包弧而非加于其上。dana/bob 作为弧彻底退役，记为忠实结果而非缺口：在此村庄，bob 的罪要么完全被目击（v21 弧已讲述），要么完美秘密（v22 隐瞒已讲述）——不留空间给敲诈者可威胁曝光的 *部分* 被目击之罪。

**解析：阈值恐惧，bob 自有惯用语的一般化。** 非线性恐惧服务两主，因其边际价格在悬崖下为零、在悬崖上为灾难。eve 获得 `Want [Match "notorious.eve.slanderer"] (−15)`——与 bob 自有 `notorious.bob.thief` 同形同量，由 `standingUnless … "slanderer"` 与 `notoriety "slanderer" 3` 接线。低语 *行为本身* 变为可观察（`witnessed together "whispered.Actor.Hearer"`——内容仍与先前一样秘密；仅低语发生的事实可被目击）。那一变更意味着被目击的低语在一个动作中落地 *两条* regard——收件人与任何同场旁观者都开始相信它发生了——使 eve 在任何人当场抓住她的瞬间距悬崖只差一名目击证人。

**Carol 的敲诈，现场捕获。** `VillageSpec` 自有强制轨迹：gale 先离开磨坊（否则她会是第三同时目击证人，在抓住 eve 的瞬间触发恶名，而非留她「距悬崖一次曝光」）；carol 到达并直接目击；两人返回广场，那里真实旁观者（bob、「you」）使曝光威胁可信而非空洞（建弧前 `scoreActions` 测量：在磨坊，仅 gale 与 dana 已知情时，买沉默仅与等待 *打平*——无新人可曝光则威胁无牙）。
逐字，从干净 `villageWorld`（同场 tick，`VillageSpec` 自有「眼不见心不烦」惯用语，在移动间静默触发）：

```
  gale: Go to square
  carol: Go to mill
  eve: whisper to dana that bob stole the loaf
  carol: Go to square
  eve: Go to square
```

注意谁被构陷：**bob**，非 carol——与本世界每一先前轮次不同的角色。那不是脚本错误；是 `shakedown` 证据模式 *内容盲目* 的诚实后果（`"whispered.V.H"`——发生过低语，句号，无论声称什么）。Carol 对 eve 的杠杆从不依赖知道或在乎说了什么，只依赖当着她的面说了——`observable` 包装器直接陈述的同一「内容保持秘密」性质，在转录本身可见：bob 两行下刚承接摊位正经工作，同一轮就被 dana 疏远，为与他无关的诽谤，纯粹因为本跑程受害者绑定碰巧落在他身上。

自由游玩从那里恢复，「you」空闲，驱动方式与其他每节无头轨迹相同：

```
  bob: take up honest work at the stall
  carol: threaten eve with what you know
  dana: shun bob
  eve: buy carol's silence
  gale: Go to mill
```

威胁后对照驱动状态直接检查（第 3 回合）：

```
threatened.whisper.carol.eve: True
eve's motive-belief deposit (eve.believes.desires.carol.punishes-whisper.heard.carol): True
notorious.eve.slanderer: False -- still under the brink, only carol and dana regard her
```

eve 服从后（第 5 回合）：

```
debt.carol.eve.favor: True
obliged.eve.favor: True
threatened.whisper.carol.eve: False -- the threat is bought off
defied.whisper.eve.carol: False -- she never defied
notorious.eve.slanderer: False -- real silence bought, not a forced exposure
```

Eve 支付因上方算术如此说：一名可信目击证人已在手（carol），再一次曝光就到悬崖，对照她以后可走回的债务。无人脚本该决策——`pickAction` 做出，与本文其他每节行使的同一 planner。

**阈值恐惧的第二后果：eve 成为一次性说谎者。** 这是结构的，非上方弧的副作用——也出现在普通、*未强制* 自由游玩中。单次被目击低语一次落地两条 regard（收件人与任何同场旁观者）；恶名阈值为三时，向新人的 *再* 低语是瞬间触发，且本轮未创作诽谤补偿路径。驱动 §25–§27 皆抽取的同一 49 回合自由游玩轨迹，直接检查：

```
eve.lied.* marks across the whole 49-turn trace: ["eve.lied.dana.stole.carol.loaf"]
regards.dana.eve.slanderer: True    regards.gale.eve.slanderer: True   (both from the ONE whisper)
notorious.eve.slanderer: False
regards.dana.carol.thief: True      -- the only regarder carol's own frame-up ever gets
notorious.carol.thief: False        -- unlike every pre-v30 round of this world
```

v30 前，同一轨迹 eve 低语三次（对应按键 1、3、4 的回合——依次向 dana、「you」、gale），carol 的构陷据此达恶名（§25）。v30 后，eve 终其一生恰低语一次，carol 的构陷在自由游玩中永不过第一信徒——两者是同一发现的两个角度。`Prax.GoldenDriveSpec` 的重捕获从第三角展示：21 回合中恰一行漂移——第 19 回合（eve 的第二次自由游玩决策）曾是 `"whisper to you that carol stole the loaf"`，现为 `"Go to mill"`——因届时她已坐在两名 regard 者上，第三人会推她过崖。酒吧与阴谋金标准字节同一；村庄其余未动。

**漂洗机制，按需复现。** §27(b) 发现——现场，规格初稿未预测——诚实信徒是谎言的完美载体：gale 像其他人一样受骗，用普通 `tell` 传播她真正相信之物，无 `lie`、无标记、无良心代价，甚至把虚假作为「证据」交回 eve 以支撑其自有捏造。阈值恐惧意味着 eve 自有 planner 不再自愿走进该场景——故须强制以展示它仍工作。驱动 49 回合，再 5 空闲回合到达 eve 与 gale 实际同场的时刻（自由游玩使他们进出会不同步），然后强制恰是 eve 自有审慎现拒绝的低语（仍合法——每听者一次允许它，因 gale 从未从任何人听过此特定声称），再继续驱动：

```
  eve: whisper to gale that carol stole the loaf     -- forced; eve's own planner declines this
  gale: tell bob that carol stole the loaf
  gale: tell eve that carol stole the loaf
```

直接检查：

```
heardFromGale (who heard what, from gale): [("bob","carol"), ("eve","carol")]
everything gale relayed, she honestly believes herself: True
gale.lied anywhere in the whole run: False
eve now holds hearsay heard from gale -- the lie laundered back to its own author: True
```

恰是 v25 发现，按需复现而非偶遇：gale 从不说谎，虚假仍经她旅行，在她一端与真相不可区分因对她它 *就是* 真相——包括径直带回发明它的女人。（探测此点时的附带发现，在任何钉死或断言之外：carol 一旦以此方式重获对 *第二次* 低语的目击证据，独立重新发现再敲 eve 的理由——上方所存重复敲诈问题的现场、未脚本回声，现经 `coComplianceLasts` 在 v54 建为一等机制，虽本村庄实例保持自由游玩，非本轮建立或测试的主张。）`Prax.VillageSpec` 的「同一怨恨，不同性情」测试恰携带此复述：仍成立的自由游玩断言（构陷、eve 自有标记、gale 从不说谎）保留并以「终其一生恰一次低语」锐化；漂洗断言移到上方强制延续，故 v25 机制保持钉死而非静默失测。

**v25 搁置的「被抓说谎」项，部分落地。** 非测谎，亦非内容暴露——本轮仅低语 *行为本身* 变为可目击（`witnessed together "whispered.Actor.Hearer"`），故同场村民现开始相信 *发生过* 低语，而 *说了什么* 仍与历来一样秘密。这足以给敲诈以杠杆（carol 从不需要知道或在乎 eve 低语了什么，只需要她做了），但不是 v25 搁置的更完整机制——尚无人能抓住谎言实际声称了什么，只能抓住发生过说谎形行为。

**在一般原语上重奠基（v49）。** 上方所述四动作协议、动机信念存款与惩罚性 `Desire` 不再是敲诈自有——它们属于 `Prax.Coerce` 的 `Coercion`/`coerce`，内容无关的杠杆骨架，证据可选（烧谷仓的保护勒索是原语的另一实例，无证据）。`Prax.Blackmail.shakedown` 保持其精确 v30 签名并组合一个 `Coercion`：证据触发、债务要求、曝光惩罚与证据信徒内核是它供给的全部；威胁/服从/违抗/惩罚、标记与惩罚性 want 是原语的。上方服从算术仍字节复现，但不再是所钉之物——重奠基自有测试契约是六条设计性质（拖延永不主导、观众放大恐惧、重复榨取保持不可能，…），旧小数仅作比较基线保留，从断言精确分数转向断言它们产生的决策形状。

→ 代码：`Prax.Debt`（`owe`/`settle`/`owes`）、`Prax.Blackmail`（`shakedown`，v49：`Prax.Coerce` 的实例）、`Prax.Coerce`（`Coercion`/`coerce`，v49）、`Prax.Worlds.Village`（`villageP` 的 `Scene` 角色、`whisperShakedown`、eve 的阈值恐惧 want、`slanderer` 站队）；断言于 `Prax.DebtSpec`、`Prax.BlackmailSpec`、`Prax.CoerceSpec`、`Prax.VillageSpec`、`Prax.GoldenDriveSpec`。

### 29. 一条成员脊骨，两台生成器 — 派系、亲属，与跨越宿怨的婚礼（`prax feud`）（v31）

两 backlog 行（`Factions & membership`、`Kinship & households`）并入一轮，因它们共享恰一原语：**成员**。家庭是小派系；亲属 *生成* 成员（婚姻移动它们）；派系公理把成员变成团结。`Prax.Faction` 与 `Prax.Kin` 作为骑乘该脊骨的两薄模块交付，且 §19 的宿怨重构其上——不留作第二平行设计——作为本轮概括成立的自有证明。

**成员是基、单槽事实。** `member.<who>!<faction>`——一主要效忠，且 `!` 是全部语义：加入一户、叛逃、嫁入皆同一排他覆盖，非三机制。`comrades` 从 `member.X!F ∧ member.Y!F ∧ X≠Y` 派生 `allied.X.Y`——并 **保留名 `allied`**，故已建于该名上的一切（相互性公理、「盟友之敌即我敌」、`societyP` 的疏远 affordance）未修改地消费。第三公理 `factionStanding` 以成员连接扩展 v21 的信念门禁声誉（`standingUnless` 的形状）——对同志的冒犯、*我相信发生了*，使我 regard 冒犯者——并规格测试交付（`Prax.FactionSpec`），但本轮未接线进任何世界：仅 `FactionSpec` 钉死，村庄接线决定已陈述并推迟而非投机建造（见 ledger Tier 1 行同一存项）。

**`Prax.Kin` 是其上的纯派生。** 基词汇是 `parent.<parent>.<child>` 与 `married.<a>.<b>`（断言一次；对称派生，非断言两次）；`kinAxioms` 闭合婚姻对称、`sibling`、`grandparent` 与两条 `inLaw` 规则（配偶之父母；兄弟姐妹之配偶）——陈述为 **单向**（先获亲属、后自我：`inLaw.P.B` 读作「P 是 B 的姻亲」），无对称 `inLaw.B.P` 派生。因是纯派生，撤回安全免费：解除婚姻（撤回 `married` 事实）取消它支撑的每个姻亲——但 **成员本身不取消派生**，因 `wed` 的成员转移是基 `!` 覆盖，非从婚姻事实派生。该不对称是要点，非疏忽：搬了家的人即使离婚后仍已搬，恰如真实叛逃。`wed joiner faction spouse` 把婚礼编译为恰两物：婚姻基事实，与一次把加入者成员移入具名派系的 `!` 覆盖——折叠的全部回报浓缩一行。*哪* 方移动是作者每婚礼的选择（世界内容，非模块政策）。职衔把同一排他惯用语一般化到继承：`office.<name>!<holder>` 加 `succession`，门禁于持有者死亡且主张者为持有者子女的主张动作——任何子女可主张，单槽取第一个有动机者，是诚实排他语义而非发明的年龄长子继承（本模型无年龄；发明「最年长」会是无原则事实）。

**宿怨，已重构——且未修改的 `FeudSpec` 是证明。** §19 两手写 `Insert "allied.bob.carol"` / `Insert "allied.carol.dave"` setup 事实已去，换为三条 `joins "X" "kestrel"` 事实；`comrades` 现派生那两事实曾直接断言之物。五个原 `FeudSpec` 测试在 *触碰任何其他物之前* 对着重构世界跑，字节未修改通过——无测试编辑，因无既有断言提及 `allied.*`（每条皆以 `resents.*`/`shunned.*`/`wronged.*` 措辞，恰重构保留的派生词汇）。一语义皱褶经检查而非假定：旧成对链两跳派生 `resents.dave.alice`（经 `allied.carol.dave`）；户在一跳派生（`comrades` 把共享 `kestrel` 的每个人直接连到其他每个人）——对每个既有测试不可见，因无一计数派生深度。

**婚礼拍，现场。** Esme 从自有单成员户 `wren` 起步——构造上对宿怨惰性：`comrades` 需要一户 *两* 成员才派生任何物，而她尚无户伴，故婚前事实恰为此，直接对照 `feudWorld` 检查（基与派生视图同一——无其他物触及她的名）：

```
member.esme.wren
```

（无 `allied.esme.*`，无 `resents.esme.*`——`dbToSentences` 把 `!` 排他打成 `.`，故这是基事实 `member.esme!wren`。）

然后婚礼——`wed "esme" "kestrel" "dave"`（新娘移动；本世界的创作选择，非模块默认）——派生世界翻转。基事实恰按 `wed` 编译的两物变化：

```
married.esme.dave
member.esme.kestrel        -- the ! overwrite: member.esme!wren is gone
```

闭合视图一趟派生下游一切——她现为嫁入整户的同志，并继承她未参与制造的恩怨：

```
allied.bob.esme      allied.esme.bob        -- comrades: shared kestrel membership
allied.carol.esme    allied.esme.carol
allied.dave.esme     allied.esme.dave
married.dave.esme    married.esme.dave      -- marriage symmetry (kinAxioms)
resents.esme.alice                          -- her in-laws' grudge, inherited through the chain
```

Alice 被动驱动 12 tick（其他每节无头轨迹使用的同一 `advance`/`npcAct` 惯用语）显示 planner 第一次尝试就拾起新派生敌意——无 BLOCK、无调参：

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

`kestrel` 每个成员——含当日早间加入的新娘——在第一次机会就疏远 Alice，然后空闲：他们再无可追求之物。

**所存而非所建。** 多重归属（一角色同时多派系）；职衔以外的持有继承；出生（`parent.*` 事实当前须断言，从不由游玩生成）；作为驱动 *动作* 的离婚（解除经对 `married` 事实的原始撤回测试，非角色可选择的实践）；以及 `factionStanding` 接线进世界（上方已陈述并推迟）——皆记于 ledger Tier 1 行而非本轮尝试。村庄本身未触：无金标准搅动，因本轮 `Prax.Worlds.Village` 无物导入 `Prax.Faction` 或 `Prax.Kin`。

→ 代码：`Prax.Faction`（`member`/`joins`/`comrades`/`factionStanding`）、`Prax.Kin`（`kinAxioms`/`wed`/`succession`）、`Prax.Worlds.Feud`；断言于 `Prax.FactionSpec`、`Prax.KinSpec`、`Prax.FeudSpec`。

### 30. 告白与赦免 — 归路真实，且变窄（`prax village`）（v32）

`Prax.Confession` 给村庄第一条从谎言回来的路。标记告白时不删除——它 *转换*：`<who>.lied.<hearer>.<event>` 变为 `<who>.confessed.<hearer>.<event>`，同一记忆、改变的价，因此特质仍可对残余标价。（**v48**：清偿动词是创作参数，非硬编码词 `confessed`——村庄传入 `"confessed"` 且此处无变，但撤回/吹嘘/承认骑乘同一机械。）告白设计上是自证其罪：它经闲聊与说谎已骑乘的同一带源传闻信道（v20）把行为存入听者信念，故 §24 声誉栈对信念所做的一切，对告白也做。赦免是分离动作，且可拒绝：告白清除你自有良心；只有第二方的 *授予* 经插入世界击败者事实清除你的站队。你可以告白而被拒绝——良心干净，站队仍脏。赦免者的耐心不是有人递增的计数器；它是知识——`incorrigible` 把 §24 的 `notoriety` Count 惯用语指向内，故「我已原谅你够多次」从赦免者 *所信* 派生，恰如恶名本身从村庄所信派生。

**告白几乎无法解决的形状问题。** eve 来自 §25/§28 的良心标记是内容形——`eve.lied.dana.stole.carol.loaf`，命名 *carol*，她构陷之人。她的诽谤者站队（§28）从完全不同之物派生——行为，`whispered.eve.dana`，命名 *eve*。转换标记的告白必须把信念存入 *行为*（实际使 eve 麻烦之物）——非对捏造内容的再断言（那只会在新信徒上种构陷）。一模式不能同时是标记自有形状与存款形状；实现开始前已标为风险，村庄接线一旦尝试就真实撞上（两种朴素接线皆对着引擎建造并现场探测；两种下 `absolve` 从未向任何人提供），经修正 `confess` 取标记模式与存款模式为两独立参数解决——仅从标记自身绑定之物落地（告白者、原听者、标记自有事件变量），对任何其他物检查并响亮报错。

**现场，从干净 `villageWorld`。** eve 向 dana 低语；gale 仍在磨坊，直接目击低语——在任何人告白任何物前她已 regard eve 为诽谤者：

```
eve.lied.dana.stole.carol.loaf: True
dana.believes.whispered.eve.dana.seen: True
gale.believes.whispered.eve.dana.seen: True
```

向 gale 告白对 eve 无代价——gale 已持有 regard，故无新信徒可惊吓，恶名阈值不移动：

```
eve.confessed.dana.stole.carol.loaf: True
eve.lied.dana.stole.carol.loaf (the lied form, converted away): False
gale.believes.whispered.eve.dana.heard.eve: True
gale.believes.stole.carol.loaf.heard.eve (a re-assertion of the fabricated content): False
```

注意 gale *不* 开始相信什么：非「carol 偷了面包」的再断言（eve 捏造的内容），仅行为及其虚假，源出 eve 自己。那是存款模式修正在做工——告白直接牵连 eve，同时把 carol 的处境恰留在 §25 所留（未触、未助）。

gale 给予赦免——击败者落地，她自有与 dana 的诽谤者 regard 皆从派生视图溶解，无物被遗忘：

```
recanted.eve: True
regards.dana.eve.slanderer (derived view): False
regards.gale.eve.slanderer (derived view): False
dana.believes.whispered.eve.dana.seen (memory persists): True
gale.believes.whispered.eve.dana.heard.eve (memory persists): True
```

**再犯弹回，且这次更糟。** eve 与 gale 返回广场——bob、carol 与「you」已在——eve 再向 bob 低语。她刚获授予的击败者消失（§24 小偷生活于其下的同一再偷惯用语），且因这次低语发生在拥挤广场而非空磨坊，那里每个旁观者立刻 regard 她——单动作越过恶名阈值，原磨坊侧低语从未做到：

```
recanted.eve (snapped away): False
regards.you.eve.slanderer: True
regards.bob.eve.slanderer: True
regards.carol.eve.slanderer: True
notorious.eve.slanderer: True
```

**厌烦，及其限度。** gale 现相信来自 eve 的两桩不同低语谎言实例——原初与再犯——且她的耐心（`incorrigible "whispered.V.H" 2 "incorrigible"`，写进 `villageAxioms` 的两振阈值）已耗尽：

```
regards.gale.eve.incorrigible: True
gale's own "absolve eve" affordance gone from her menu: True
regards.dana.eve.incorrigible (dana witnessed only the original instance): False
```

dana 只曾目击第一实例，尚未厌烦——耐心按赦免者计，恰如本引擎其他每个 regard。

**未发货的弧：向实际被伤害之人告白。** 自然救赎会经 carol 而非 gale——她是 eve 构陷之人，原谅你的实际受害者比原谅旁观者意味更多。它被建造并测量，非仅想象：给 carol 一条公开 `merciful` 欲望（以便 eve 自有深度-2 前瞻可经对她的信念模型看见告白→赦免），并将其量级从 0 扫到 50。在每个正值结果相同——向 carol 告白远低于 eve 普通基线，无论创作慈悲多慷慨都不越过（经 `scoreActions` 现场测量，逐字）：

```
mercifulValue=0:      confess to carol about framing carol  ->  -19.73   (worst option)
mercifulValue=5..50:  confess to carol about framing carol  ->    7.92   (FLAT -- value plateaus)
                       eve's routine baseline (Go to mill / Wait / steal / honest work) -> 14.08-17.68
```

机制是结构的，非调参不足。向 carol 告白使她成为低语行为的 *新* 信徒——carol 尚非 regard 者——故告白本身吃下完整、立即的恶名阈值打击，其上 planner 自有 `othersScore` 项对 *预测的* 第三方赦免价值只应用固定 0.5 折扣。该 0.5 天花板封顶可达成救济，无论创作欲望多大；carol 自有赦免选择一旦对她有利，是离散开关，非随她被说多么仁慈而连续缩放。记于此而非发货——本轮着手测量的「阈值戏剧」，已测量，并发现不足以驱动未强制弧。

**自由游玩：秘密仍昂贵。** 放任不管，eve 从不告白且 gale 从不赦免——她的谎言不够便宜，深度 2 也无被信念的仁慈赦免者，算术不会偏向花掉它。在 §25/§27/§28 皆抽取的原自由游玩轨迹外再驱动 100 回合（迄今最长先例的两倍），钉于 `VillageSpec` 并在本轮自有完整套件跑程确认绿：

```
eve.lied.dana.stole.carol.loaf (still unconfessed after 100 turns): True
eve.confessed.dana.stole.carol.loaf: False
recanted.eve: False
```

**证伪扫描：归路是否够到 carol 自有不公？** 否——§25 直接覆盖（其自有「更新 — v32」段，现场重检而非假定）：告白清除 *告白者* 的标记与 *告白者* 的站队；本轮无物撤回已种在他人中的信念，也无物让第三方代表被构陷受害者告白。本轮建造的归路真实，但收窄到说谎者可直接面对之人——不延伸到其谎言二手够到之人，对被构陷之人完全无作为。

→ 代码：`Prax.Confession`（`confess`/`absolve`/`incorrigible`）、`Prax.Worlds.Village`
（`confessWhisper`/`absolveWhisper`、`honest` 特质的第二欲望、`villageAxioms` 的 `incorrigible` 接线）；断言于
`Prax.ConfessionSpec`、`Prax.VillageSpec`。

## 特性覆盖图

已实现的一切、它住在何处，以及如何看见它。第一块是引擎核心（酒吧，Part I）；第二块是 Part II，每世界/工具一行。

| 特性 | 代码 | 你何时看见… |
|---|---|---|
| Trie DB、`.` 下降 | `Prax.Db` | （处处——全部状态） |
| 排他 `!`（已修正） | `Prax.Db.insert` | 移动（`at!Place` 替换旧值）、点单/上菜 |
| 统一 / 模式匹配 | `Prax.Db.unify` | 每个动作前置条件 |
| `Match` | `Prax.Query` | 任何动作变为可用 |
| `Not`（失败即否定） | `Prax.Query` | 问候后问候消失 |
| `Eq`（兼赋值） | `Prax.Query` | Fulfill（`Eq Actor Bartender`） |
| `Neq` | `Prax.Query` | 问候（不能问候自己） |
| `Cmp`（`lt/lte/gt/gte`） | `Prax.Query` | 微醺阈值；铃 |
| `Calc`（`add/sub/mul`） | `Prax.Query` | 饮酒计数递增 |
| `Count` | `Prax.Query` | 铃（数顾客） |
| `Subquery` | `Prax.Query` | 铃（聚集人群） |
| `Insert` / `Delete` | `Prax.Engine` | 点单、上菜、移动 |
| `Call` + 函数 + `FnCase` | `Prax.Engine` | 变微醺（`recordDrink`→`checkTipsy`） |
| 实践孵化 + `init` | `Prax.Engine` | 开局播种顾客饮酒计数 |
| 单角色与多角色实践 | `Prax.Types`/`Bar` | `world`（1 角色）、`tendBar`（2 角色） |
| `dataFacts` | `Prax.Engine` | 四种饮料选择 |
| Want / 效用 / 前瞻 | `Prax.Planner` | bex 走进点单；ada 上菜 |
| 轮转循环 + CLI 菜单 | `Prax.Loop` / `app/Main` | 整场会话 |
| 情感（共存、有目标、消退） | `Prax.Emotion` `feelToward` | 「对你感到恼火」 |
| 关系求值（数值、非对称） | `Prax.Core` `adjustScore` | 「对…的温暖」爬升 |
| 关系门禁 affordance | `Prax.Core` `scoreAtLeast` | 一温暖就出现「请…喝一杯」 |
| 反应（孵化实践 + 回应链） | `Prax.Reactions` | 问候 →「回礼」/「回绝」 |
| 规范（违规标记 + 不赞成） | `Prax.Reactions` | 逃单 →「违反规范」→ ada 反应 |
| planner 中的避规范 | `Prax.Planner` + `Want` | NPC 给小费而非逃单 |
| 信念（按 agent，可假） | `Prax.Beliefs` | 谣言 →「…相信 ada 怨恨他们」 |
| 信念门禁行为 / 修正 | `Prax.Beliefs` | 假信念压制友好；证据修正 |
| 对话（说话者轮次、话题、quips） | `Prax.Conversation` | 「…在闲聊（rapport）」；对话 |
| 故事管理器（DM）作为元层 agent | `dmPractice` / `director` | 「director：让 ada 反对…」 |
| 角色弧（阶段门禁 want） | `Prax.Arc` | 「bex 感到希望」→「在此如家」；归属 |
| 仅玩家的转变（逆欲望） | `arc` 实践 | 「放弃…」被提供但从不被 NPC 采取 |
| 一阶联结词（`Or`/`Absent`/`Exists`，`forAll`/`implies`） | `Prax.Query` | 结局冻结；全称检查 |
| 道义义务（□）、履行/违约、违反义务（□□） | `Prax.Deontic` | 酒吧：「欠 ada…」 |
| 阵容移除（角色死亡并离开） | `Prax.Engine` / `Intrigue` | `prax intrigue`：什么都不做则有人死 |
| 分支戏剧剧集 | `Prax.Worlds.Intrigue` | `prax intrigue`：警告/下毒/恋情 → 不同结局 |
| 压力测试器 + 检查器（`explain`） | `Prax.Stress` / `Prax.Inspect` | `prax stress intrigue` |
| 存档 / 继续（状态 = 事实 DB） | `Prax.Persist` | 按 `s`；然后 `prax intrigue resume` |
| 场景创作层（CAST + scenes/beats/junctions） | `Prax.Script` / `Worlds.Play` | `prax play`；`prax flow` |
| 剧本经 JSON 往返 | `Prax.Script.Json` | `prax dump-play`；`prax play examples/…` |
| 玩家即戏剧管理器 | `Bar.barDirectorWorld` / `candidateActions` | `prax dm`：你的菜单是作者动作 |
| 前向链派生（可击败） | `Prax.EL` / `Prax.Derive` | `prax feud`：1 错 + 4 规则 → 涌现宿怨 |
| 静态类型检查器 + 排序推断 | `Prax.TypeCheck` | `prax check <world>` |
| 定时 junction、角色素描（memories：v18 建，v46 移除——呈现，非世界内容） | `Prax.Script` | `prax audience`；超时结局 |
| 量化结果（`ForEach`）+ 创作目击 | `Prax.Engine` / `Prax.Witness` | `prax village`：同场者获得 `.seen` |
| 闲聊 / 带源传闻（`gossip`/`heard`，多值 `.seen`/`.heard.<source>` 出处） | `Prax.Rumor` | `prax village`：carol 告知；菜单不重复 |
| `standing`/`standingUnless`/`regardedAs`/`notoriety`（派生声誉，基事实补偿击败者） | `Prax.Repute` | `prax village`：regard、恶名、补偿非失忆 |
| 秘密与欺骗（`conceal`/`lie`） | `Prax.Deceit` | `prax village`：bob 隐瞒；eve 构陷 |
| 事业：部分集实践、休眠追求（`endeavor`/`Part`） | `Prax.Project` | `prax village`：bob 挣面包；旁观读目的 |
| 性情即行为估值（`Trait`/`personaVocabulary`/`bearing`/`transparent`/`cast`）；诚实村民漂洗谎言 | `Prax.Persona` | `prax village`：gale；预测对照 |
| 债务作带受益人义务（`owe`/`settle`），信念门禁老赖站队 | `Prax.Debt` | `prax village` / 规格测试 |
| 敲诈（`shakedown`：威胁/服从/违抗/曝光），阈值恐惧 | `Prax.Blackmail`，`Prax.Worlds.Village` | `prax village`：carol 敲 eve；一次低语 |
| 成员作一条脊骨（`member.<who>!<faction>`，`comrades`，信念门禁 `factionStanding`）；亲属生成（`wed`/`kinAxioms`/`succession`） | `Prax.Faction`，`Prax.Kin` | `prax feud`：婚礼翻转派生；疏远 |
| 告白与赦免（`confess`/`absolve`/`incorrigible`）：标记转换而非删除；归路变窄 | `Prax.Confession` | `prax village`：向 gale 告白；再犯弹回 |

若表格与场景行不能使你相信某特性真在做所声称之事，同一行为在测试套件中断言（`cabal test`，431 测试）。Part I：`Prax.QuerySpec`、`Prax.EngineSpec`、`Prax.PlannerSpec` + `Prax.MindsSpec`（want/效用/前瞻，现为对照信念心智的 round-walk——`predictMove`、`charDesires`、`professed`/`conventional`）、`Prax.CoreSpec`（情感/关系）、`Prax.ReactionsSpec`（反应、规范、避规范）、`Prax.BeliefsSpec`（按 agent 与假信念）、`Prax.ConversationSpec`（说话者轮次、话题、一次性 quips）、`Prax.ArcSpec`（弧阶段）、`Prax.DeonticSpec`（□、履行、违约、违反义务）、`Prax.DebtSpec`（`owe`/`settle`、demand→老赖站队生命周期、信念门禁可见性与债务人自有不可避免的自我 regard）、`Prax.ConfessionSpec`（标记转换及其标价残余、存款落为带源传闻、赦免的授予/拒绝门、`incorrigible` 的按赦免者耐心，以及钉死前现场测量的自发告白与敲诈防御算术）、`Prax.DbSpec`（trie 精确 `!`/`.`/撤回语义，含回退的幽灵剪枝尝试自有回归网——断言实例事实必须在其瞬态孩子排空至零后幸存）、`Prax.BarSpec`，以及 `Prax.LoopSpec`（确定性 25 回合重放——自 v44 起回合边界而非阵容中的 ticker 跑调度；倾诉对象/受害者 `predictMove` 分裂）、`Prax.StressSpec`、`Prax.PersistSpec`（存档/继续）、`Prax.ScriptSpec` + `Prax.Script.JsonSpec`（场景层 + JSON，含单边界故事法则、定时 junction/素描与 `audience`）、`Prax.DirectorSpec`（玩家即 DM）、`Prax.ELSpec`/`Prax.DeriveSpec`（排他逻辑格与前向链）、`Prax.TypeCheckSpec`、`Prax.WitnessSpec` + `Prax.VillageSpec` + `Prax.RumorSpec` + `Prax.SightSpec`（`ForEach` 目击、同场、质问 affordance、带源传闻与闲聊门，以及盖印哪些移动被预测的目击调度规则）、`Prax.ReputeSpec`（派生站队、基事实补偿击败者与阈值恶名——`VillageSpec` 后续用例把同一机制带过完整自主弧、再犯弹回与所致威慑）、`Prax.DeceitSpec`（`conceal` 的形状及其被监视/未被监视 planner 探针、`lie` 的无证据门、自构陷与主体即听者排除、每听者一次、听到自己的谎言传回使 `lie` 换为 `gossip`，以及——v25——说谎者自有标记（`<liar>.lied.<hearer>.<event>`），可遗忘且可加，真实 `gossip` 不留下标记——`VillageSpec` 后续用例把同一机制带进完整村庄：被监视盗窃失败、完美犯罪仍需真正空广场，eve 的构陷仍造成无救济的疏远）、`Prax.ProjectSpec`（`endeavor` 的承接/部分门禁/产出形状、独立烤箱建造夹具、追求欲望的精确形状及其休眠 vs 已承接可信性，以及在 planner 深度驱动四部分至完成的地平线回归——`VillageSpec` 后续用例把同一机制带进完整村庄：bob 未强制救赎、旁观教目的推理喂给信念相对、短视的 `predictMove`，以及保持隐瞒诚实的项目中途机会主义拍），以及 `Prax.PersonaSpec`（`bearing`/`personaVocabulary`/`cast` 机械及其响亮错误守卫、`transparent` 的可击败假定、经诱惑双胞胎对上 `pickAction` 的行为估值核心分裂、边际谎言性质与被信念良心预测——`VillageSpec` 后续用例把同一机制带进完整村庄：gale 性情自 t=0 可读、eve 构陷推进且 gale 从不无提示说谎的自由游玩驱动，以及关于怨恨被告知后 eve 与 gale 的预测对照），以及 `Prax.BlackmailSpec`（`shakedown` 的动机信念存款、自我动机可信度、站立威胁曝光，以及两边钉死的服从算术——两旁观者服从、一旁观者理性违抗、违抗与等待的精确拖延平局——外加评审发现的保留变量碰撞守卫）——`VillageSpec` 的敲诈弧用例把同一机制带进完整村庄：carol 一旦持有目击证据威胁落地，eve 服从且声誉栈对无关者保持不动，阈值恐惧使 eve 悬崖下自由游玩低语恰如历来一样理性，同时在强制延续下复述它结构上排除的那一自由游玩后果（§27 的漂洗））、`Prax.FactionSpec`（`comrades` 的共享成员派生及其 `X≠Y`/跨派系否定、叛逃的撤回安全、`factionStanding` 的信念门禁——含弑亲与受害者自我信念钉——及其保留变量守卫），以及 `Prax.KinSpec`（每条 `kinAxioms` 规则正负、`wed` 的两事实与双方名守卫、解除取消姻亲派生而成员持久，以及继承生命周期的死亡门禁、仅子女主张与单槽竞赛解析）——`Prax.FeudSpec` 把两者未修改地带进涌现沙箱：重构未触的五条原断言，外加婚礼拍的派生翻转与驱动疏远——`VillageSpec` 自有后续用例把 `Prax.Confession` 带进完整村庄：eve 对 gale 无代价告白（存款自源，非对被构陷内容的再断言）、赦免溶解站队而每个信念持久、新鲜低语弹开击败者并立刻落地广场每个旁观者、gale 的耐心在第二实例耗尽而 dana（一实例）不，以及 eve 的构陷经 100 回合未强制自由游玩仍未告白而幸存。

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
