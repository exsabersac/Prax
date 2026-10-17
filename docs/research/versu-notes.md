# Versu — 架构笔记

从一手资料提炼，供 `prax` 重实现使用。最丰富的来源是 IEEE 论文，直接阅读
（下方页码引用均对该文）。

**一手来源：** Evans & Short, "Versu—A Simulationist Storytelling System," *IEEE
Transactions on Computational Intelligence and AI in Games* 6(2):113–130, 2014.
PDF: https://cs.uky.edu/~sgware/reading/papers/evans2014versu.pdf · IEEE:
https://ieeexplore.ieee.org/document/6648395/（获 IEEE CIS Outstanding Paper Award）。

其他一手：Emily Short 的博客（https://emshort.blog/category/versu/），尤其
[Introducing Versu](https://emshort.blog/2013/02/14/introducing-versu/)、
[Conversation Implementation](https://emshort.blog/2013/02/26/versu-conversation-implementation/)、
[Mailbag: Writing for Versu](https://emshort.blog/2017/05/18/mailbag-writing-for-versu/)。

---

## 1. 两类对象 + 逻辑 DB + 决策循环

> "Our simulation is built up out of two types of objects: agents and social practices." (p.116)

架构（Fig. 3, p.117）：三份创作输入文件（Social Practice File、World Initialization File、
Character File）被解析并用于填充中央**数据库**（整个世界状态）。**Decision Maker** 把
角色参与的实践所提供的 affordance 喂给 agent；agent 选择；**Action Executor** 变更 DB；
循环重复。玩家选择用同一管线，只是 affordance 去 UI 而非 DM。

## 2. Exclusion logic / Praxis（数据库）

- 「模拟状态完全由模态逻辑中的一组句子决定。……没有传统意义上的对象或指针。」(p.118)
- 声称的优点：**可见性**（无隐藏）、**可调试性**（逻辑断点：哪个实践使某事实为真）、
  **可序列化**。(p.118)
- 语法 (p.119)：字面量 `X ::= S | S.X | S!X`。`.` = 普通（可多值）下钻；`!` = 排他：
  「B 是 A 成立的唯一方式」（单值槽）。
- 事实形成 **trie**；共享前缀是对象；删除前缀则「一举」删除子树（`brown.` 移除关于 Brown
  的所有事实）。前缀是「Praxis 对对象的等价物」。(p.119)
- **经 `!` 的自动清理：** 切换 `p!a` → `p!b`（插入 `p!b`）按「排他逻辑的更新规则」自动移除
  状态 a 的全部本地数据 `p!a.*`。(p.119) → 单值边垃圾回收陈旧状态；STRIPS `remove` 子句
  变得不必要。
- 强隐式类型（类似 ML/Haskell）；排他信息喂给类型检查器
  （`agent.sex!gender` ⇒ agent 恰好有一个性别）。(p.120)

## 3. 社会实践（Social practices）

- 「社会实践是 affordance 的层次集合，向其参与者（仅按所扮演角色刻画）提供各种选项。」(p.121)
- **构成性（非规制性）：** 「每个 affordance 都包含在一个实践中，且仅当该实践被实例化时可用。」
  这就是如何解决无限选择问题——agent 只看到自己所在实践的 affordance。(p.120)
- 用 `process` 声明；通过断言一个句子实例化。原文 (p.121)：
  ```
  process.greet.X(agent).Y(agent)
    action "Greet"
      preconditions
        X.in!L and Y.in!L
      postconditions
        text "[X] says 'Hi' to [Y obj]"
  end
  ```
  断言 `process.greet.jack.jill` 以 `[jack/X, jill/Y]` 激活它。
- **角色无关**（任何阵容可填角色）→ 高重玩性；n 角色剧集有 2^n 种玩家/NPC 分配。(p.115)
- **并发：** 许多实践同时运行；agent 的选项是其所在全部实践 affordance 的*并集*。
  实践持有任意持久状态，并可孵化实践。
- 超出 PDDL 的动作语言：析取前置、失败即否定、嵌套 ∀/∃ 前置、数值表达式、领域公理、
  条件效果。(p.121)
- **规范（Norms）：** 违反规范的动作获得标记违规的后置；agent 有强烈欲望尊重规范；
  违规孵化提供反应（disapprove/forgive/anger/evict）的子实践。(p.121)

## 4. 动作选择 / 自主性

- **强自主：** 「总是由个体 agent 用基于效用的反应式动作选择决定做什么。」实践只建议。
  (Abstract, p.113)
- **前向链 apply-evaluate-undo：** 「他们实际执行动作结果……相对欲望评估此未来世界状态……
  然后撤销后果。」撤销便宜，因为原语「高效可撤销」。(p.122)
- **效用 = Σ 满足的欲望。** 「want 是使一个句子为真的欲望，该句子可以是排他逻辑的任意句子。」
  每个 want 有数值修饰；每个*单独实例化*（绑定）再加一次其修饰。(p.122)
- DM/故事管理器「只是一种特殊类型的实践」；反应式，每剧集手写，甚至可由人类扮演。
  (p.118, p.127)
- 玩家 UI：affordance 菜单；两个按钮 **act** / **more**（more = 让 NPC 继续）。(p.113)

## 5. 核心模型（情感 / 关系 / 信念）

否则孤立的实践经此通道通信。(p.124)
- **情感：** 基于 Ekman，单槽，新覆盖旧，记得先前情绪 + 目标 + 触发事件。(p.116, p.124)
- **关系 = 角色评价**（Sacks 的成员类别化）：「在 x 眼中，y 扮演角色 R 有多好？」
  评价是**多重且不对称的**，带理由存储：
  `Agent.relationship.Evaluated.role!Value!Explanation`。获取方式：硬编码、解释动作、
  或听信他人。(p.122–123)
- **公开关系状态：** 单一对称长期立场（朋友/恋人/敌人）；变更需双方主动选择；
  从不单方面强加给玩家。(p.123, p.125)
- **信念：** 世界状态默认共享；仅在需要错误信念/分歧处有按议题的个体信念。
  无法表示量化/嵌套信念。(p.124, p.129)
- **反应性是实践：** 每个动作孵化提出响应的反应实践；响应本身是动作，可再孵化反应。
  (p.123–124)
- **角色弧：** 内部高层选择（内在性）；真正的转变（逆自己欲望选择）仅属玩家。(p.124)
- **对话：** 说话者 + 话题；对话行是 **quips**（文本模板 + 对社会/情感状态的效果），
  可能跨说话者共享，带话题标签。(p.125)

## 6. 值得注意的声称能力（账本目标）

- 经角色/角色分离的重玩性（同一故事，多种视角/分配）。
- 可复用的角色无关实践（相对 Façade 硬编码的联合行为）。
- 作者从未显式写出的涌现关系。
- 并发实践 → 分层、潜台词行为。
- 规模：一年创作 >1000 个参数化动作；>300 个欲望。(p.128–129)
- 混合作者控制：分离决策（agent）与协调 + 连续性（实践）。(Fig. 4, p.128)
- 旗舰创作作品：**Blood & Laurels**（古罗马），建于该引擎。

## 7. 创作工具：Prompter

建于 Praxis 之上；作者以剧本格式创建场景/对话，标情感/评价效果，编译到 Praxis。
把分支 20 分钟剧集的创作从约 1–2 个月压到 <1 周。(p.130；Short 的 Mailbag 帖。)

## 未核实 / 以后再补

- 排他逻辑的完整形式语义 + 决策程序在付费墙后的 DEON 2010 论文中
  （Evans, "Introducing Exclusion Logic as a Deontic Logic"）。IEEE 论文只*描述*更新规则。
  形式化道义 `should` / 规范冲突前需要。
- 无公开 Praxis 语法或 Versu 源码（IP 由 Linden Lab 保留）。
