# Exclusion Logic as a Deontic Logic — 精炼笔记（供 LEDGER #34）

来源（通读，本地）：`references/papers/EVAIEL.pdf` —
Richard Evans, "Introducing Exclusion Logic as a Deontic Logic," DEON 2010,
Springer LNCS 6181, pp. 179–195. DOI 10.1007/978-3-642-14183-6_14.
下方页码是论文内部页码（1–18）。

这是曾阻塞 #34（道义 `should`/义务 + 规范冲突）的一手来源。这些笔记抓住所需的一切，
使不必重读 PDF。**对实现最重要的单一事实是论文与我们引擎之间的记法翻转——见 §0。**

## 0. 相对我们引擎的记法翻转（先读）

论文用两个二元树运算符；**相对 `Prax.Db`，其含义对调**：

| 概念 | 论文 | 我们的引擎（`Prax.Db`） |
|---|---|---|
| 多值 / 兼容（「A 是 B 的*一种*方式」；`A:B` 与 `A:C` 共存） | `:`（又称边标签 `*`） | `.` |
| 排他 / 单值（「B 是 A 的*唯一*方式」；`A.B` 排除 `A.C`） | `.`（又称边标签 `!`） | `!` |

因此论文的义务句子 **`Ob:P`（多值）= 我们的 `Ob.P`**，论文的排他 `A.B` = 我们的 `A!B`。
我们的 trie DB *就是* Exclusion-Logic 模型（单棵标注有根树）；`unify`/`insert` 已实现 EL 的
树 + 排他语义（纠正后的 `!` 正是 EL 的「唯一孩子」边）。

## 1. Exclusion Logic（EL）核心

- **前命题**模态逻辑：**无否定、无析取**，只有受限蕴含。设计用于陈述式刻画层次有限状态机——
  「数据之树」(p.1)。物质不相容被当作概念上先于否定（Brandom/Sellars），因此不相容由
  排他运算符表达，而非 `¬` + 非逻辑公理 (p.1–2)。
- **语法（Def 1, p.2）：** `X ::= S | S:X | S.X`；`E ::= X | E ∧ E`；`G ::= E | E → E`。
  谨慎**分层**：项 → 合取 → 蕴含。`→` **不可递归嵌入**（`P→Q` 合式；`P→Q→R` 不合式）。
- **两个运算符（Remark 1, p.2）：** `A:B` = 「B 是 A 的*一种*方式」（兼容；`A:B` 与 `A:C` 共存）。
  `A.B` = 「B 是 A 的*唯一*方式」（排除 `A.C`）。
- **否定受限 (p.3)：** `¬P` = 与 P 不相容的*内容最少*主张。`⊥ ≡ A.A ∧ A.B`；`¬P ≡ P → ⊥`。
  可否定*简单*项（`P` 或 `P.X`）但**不能**否定复合项（`P∧Q`、`P→Q`）——`→` 不可嵌入。
- **析取受限 (p.3)：** `P∨Q` = 最小上界；角色 `A` 可为 `A.B ∨ A.C` 扮演角色，但不等同于它。
  无一般 `∨`。
- **语义 (p.4–5)：** 在 **Labeled Rooted Trees (LRTs)** 的格中解释表达式。边标 `*`（多值；我们的 `.`）
  或 `!`（唯一孩子；我们的 `!`）。合法 LRT = 无环、连通、无冗余、*尊重排他*（Def 3）。
  `signature s_X(v)` = 根→v 的符号路径（Def 4）。偏序 `≤` 由子图同构 + 边特异性（`! ≤ *`）
  （Def 6）：`A ≤ B` 当且仅当 A 携带至少与 B 一样多的信息。`⊥ ≤ X ≤ ⊤`；带 glb `⊓`（=
  合取；若不相容则 `X⊓Y=⊥`，Def 8）与 lub `⊔`（Def 9）的格。(Prop 5, p.10)
- **满足（Def 10, p.10）：** `⊨_X E iff Sat(X, R_X, *, E)`。`A∧B` = 两者。
  **`A→B` 在 v = 对每个可达 v'（传递闭包 E*_X）：¬Sat(A) 或 Sat(B)`** ——蕴含在*一个*模型的
  *所有*顶点上量化，因此**强于实质蕴含**但弱于 Lewis 严格蕴含 (p.10–11)。
  关键后果：`A.B ⊭ A.C → Z` (p.16) ——用于化解 Chisholm（下方 §2）。
- **决策程序（Def 13–18, Prop 6–7, p.11–13）：** 不枚举模型——构建**规范最小模型 `m(X)`**
  并直接测试蕴涵：`X ⊨ Y iff ⊔[X] ≤ ⊔[Y] iff m(X) ≤ m(Y)`。`m` 把合映射到 LRT 并反复应用
  蕴含 `G` 以闭合模型（`m(G,A)`）。**复杂度：多项式——`nm²k²`**（n = 判断数，m = 最大合取数，
  k = 最大合取复杂度）。「测试蕴涵是多项式时间且实际高效」(p.13)。

## 2. DEL — Deontic Exclusion Logic（§2, p.13–17）

回报。**DEL 是 EL 加一个语法添加与*零*语义变更。**

- **语法 (p.14)：** 向项添加 `□X`：`X ::= S | S:X | S.X | □X`；`E`、`G` 如前。
  `□P` 读作「**P 应当成立**。」
- **`□P` 是 `Ob:P` 的纯语法糖** (p.14) —— `Ob` 是普通 EL **常量**，暗示性命名。
  在我们的记法（翻转）中：**`□P` ≡ 事实 `Ob.P`**。无新语义：义务只是树中的普通句子。
  因为 `Ob:` 是多值运算符，**多个义务共存**（`Ob.P`、`Ob.Q`、…），而不兼容者塌缩
  （见性质 2）。
- **分层（Fig 13, p.14）：** 合式：`□A ∧ □B`、`A → □B`、`□□A`。
  **不合式：`□(A∧B)`、`□(A→B)`** —— `□` 只应用于*简单项*，从不应用于合取/蕴含。
  `□` **可迭代**（`□□A`）但**不可**辖域覆盖逻辑联结词。
- **为何它是（最小）道义逻辑（§2.3, p.15）：** 道义 `Ob` 须满足的三个直觉，均已被 EL 语义尊重：
  1. **在严格蕴含下闭合：** `P→Q, □P ⊨ □Q`（经 EL 的 `→` 满足条件）。
  2. **无不兼容道义判断：** 若 P、Q 不兼容，*无*模型满足 `□P ∧ □Q`（经 EL 的 `∧`：合取是 `⊥`）。
     → **规范冲突呈现为不可满足**，而非静默共存。
  3. **应当 ≠ 是：** `□P ⊭ P` ——义务可保持未满足。
  这些*允许*（不强迫）把 `□` 读作道义 ⇒ DEL 是*最小*道义逻辑。
- **避开 SDL 悖论（§2.4, p.15–17）：**
  - **重言式义务**（SDL 对重言式 P 有 `⊨ □P`）：DEL 唯一重言式是蕴含（`A.B→A`），且 `□`
    不能应用于蕴含 ⇒ `□` 内无重言式。
  - **Ross 悖论**（SDL `□P ⊨ □(P∨Q)`）：DEL 不允许 `□` 内有 `∨`（分层）。
  - **Chisholm 谜题 / 违反义务（contrary-to-duty）(p.16–17)：****四条主张表示为
    （用 `P.True`/`P.False` 表示 `P`/`¬P`）：
    1. `⊤ → □ Go.True`   2. `Go.True → □ Tell.True`
    3. `Go.False → □ Tell.False`   4. `Go.False`
    因为 DEL 的 `→` 强于实质（`A.B ⊭ A.C→Z`），坏推理 (4)→(2) 被阻断；你得到
    `□□ Tell.True` **与** `□ Tell.False`，兼容。
    **`□□ Tell.True`** = 「*理想上*，若事件按应有方式展开，Jones 本应告知邻居」——
    **迭代 `□` 捕获理想 / CTD 嵌套** (p.17)。
- **相对 von Wright / Castañeda（Fig 14, p.17）：** `□□P`：SDL 是，DEL **是**，vW 否。
  `□(P→Q)`：SDL 是，DEL **否**，vW 否。DEL = 原则性中间地带。
- **计算注记（§3, p.17）：** 「DEL 已被用于驱动多智能体模拟」——社会实践用 DEL 建模：
  **轮流、社会地位、排队、以及禁忌活动**；「对陈述式表示社会实践富有表达力且直观。」
  （这就是 Versu/Praxis——DEL 是其逻辑。）

## 3. 对 #34 的实现含义（计划的根据）

我们的引擎已实现 EL 基底。要添加*忠实*的道义层：

1. **表示——义务作为一等事实。** 镜像既有 `violated.<who>.<norm>` 约定
   （`Prax.Reactions.violationPath`）。义务「谁应当 φ」= **`Ob.<who>.<φ>`**
   （我们的 `.` = 论文的 `Ob:`，因此多值：agent 可同时持有多个义务）。这正是该 agent 的 `□φ`。
2. **`Prax.Query`/效果中的分层 `should` 运算符。** 添加智能构造器 / `Condition` + `Outcome`：
   - 断言义务（`oblige who φ` ⇒ `Insert "Ob.who.φ"`），
   - 查询它（`isObliged who φ` ⇒ `Match "Ob.who.φ"`）、履行（φ 成立）、
     违反（φ 变得不可能 / 排他反值成立）。
   保持**分层**：运算符取*简单项*（句子），从不取复合 `Condition`——这正是换来悖论回避的东西，
   因此必须是 API 纪律，而非装饰。
3. **规范冲突 = 排他（性质 2）。** 同一槽上*排他*值的两个义务（`Ob.A.go!true` vs `Ob.A.go!false`）
   是论文的不兼容 `□P∧□Q ⇒ ⊥`。需做的设计选择：**检测**冲突（呈现它——DM 或 agent 必须
   解决/排序）而非让我们的 `!`-插入静默覆盖（后写胜）。规范冲突*解决*（#34 的后半）
   是优先级/可废止性所在；论文给出*检测*（⊥）但不给解决策略——若要原则性优先级，
   参见 Alchourrón–Makinson "Hierarchies of Regulations" [ref 1] 与 Boella–van der Torre
   层次规范系统 [ref 2]。
4. **行为耦合已是我们的（Versu 同样）。** 无 planner 变更：
   `Want [ isObliged self φ, Not φ ] (−k)`（或对履行的正 want）使效用 planner 追求/回避义务——
   与已驱动 `Prax.Worlds.Bar` 中 `violationOf` 的同一机制。DEL 提供*表示*；模拟提供*动机*。
5. **经迭代 `□` 的违反义务。** `□□φ` = `Ob.Ob.φ` ——本应成立的「理想」义务。
   对修复性/次优规范有用（Chisholm）。

### v14 时的缺口，均由 v15（`Prax.EL` + `Prax.Derive`）关闭
这些是道义层（v14）首次发布时的诚实局限。派生层（v15）通过真正实现论文机制关闭了它们：
- **在蕴含下闭合（性质 1）— 完成，由创作声明。**
  `Prax.Derive` 把领域规则前向链到不动点（`m(X)`）；`□`-提升本身是 `Prax.Deontic` 中的
  创作声明（`obligedClose` 在 `□` 下提升每个全-`Match` 规则），因此道义世界写
  `setAxioms (obligedClose axs)`，则 `Ob.P` + `P→Q` 产生 `Ob.Q`。（v15 把提升作为自动
  引擎步骤发布；v51 把它移出通用引擎进入世界自身声明——检查器标记能调用义务却省略闭包的
  世界，`Prax.TypeCheck.DeonticUnclosed`。）
- **不相容检测 — 完成，忠实。** `Prax.Db` 保留 `!`/`.` 标签（世界状态是真正的 Exclusion-Logic
  模型），因此 `Prax.EL.meet` 从冲突任一侧检测 `□P∧□Q ⇒ ⊥`——无静默覆盖，也无需 schema。
- **`m(X)` 决策程序 — 已构建。** `Prax.EL` 是 LRT 格（`meet`/`leq`）；它也是 #8（静态类型检查器）
  将复用的基底，后者会在其上添加 `⊔`/一般蕴涵。

## 4. 论文引用的参考文献 (p.18)，若需继续阅读
Alchourrón & Makinson, *Hierarchies of Regulations and their Logic* (1981) [1]；
Boella & van der Torre, *Permissions and Obligations in Hierarchical Normative
Systems*, ICAIL (2003) [2]；Makinson & van der Torre, *Input/Output Logics* (2000)
[7] 与 *Permission from an I/O Perspective* (2003) [8]；Brandom, *Making It
Explicit* (1994) [3]；Castañeda, *The Paradoxes of Deontic Logic* (1981) [5]；von
Wright, *Deontic Logic* (1951) [9]；Evans, *The Logical Form of Status-Function
Declarations* (2009) [6]。（未获取；[1]、[2] 是若进一步做规范冲突*解决*排序的线索。）
