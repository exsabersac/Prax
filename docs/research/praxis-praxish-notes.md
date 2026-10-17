# Praxis & Praxish — 实现笔记

Haskell 移植的参考。Praxish 源码检出（git-ignored）于
`references/praxish/`（`db.js`、`praxish.js`、`planner.js`、`demos/`）。下方原文摘录
于本会话直接从这些文件读出。

- Praxish 仓库：https://github.com/mkremins/praxish（「Versu 的 Praxis 的部分重建」）
- RePraxis（C# 移植，陈述纠正后的 `!` 规则）：https://github.com/ShiJbey/RePraxis
- Praxis 是 Evans 支撑 Versu 的排他逻辑 DSL（论文 §VI–VII）；见 `versu-notes.md`。

## 数据库（`db.js`）

状态是嵌套 JS 对象（trie）；叶是 `{}`；句子是 `.`/`!` 分隔的路径。

`DB.unify(sentence, db, bindings)` — 在 **`.` 与 `!` 两者** 上切分模式（对*匹配*它们相同；
区分只在插入时重要）。对每段：若是变量（首字母大写，`DB.isVariable`）且未绑定，
则对当前子树每个键分支（每值分叉一个「可能世界」，扩展绑定）；若已绑定或常量，
则下钻该键或丢弃该世界。返回一致绑定映射的列表。这是核心非确定列表单子匹配。
`DB.unifyAll` 把绑定串过句子列表（合取）。

`DB.insert(db, sentence)` — 分词时保留尾标点（`/[^\.\!]+.?/g`）。**其 `!` 处理有 bug**
（作者自己的 TODO）：它做 `subtree[key] = {}`——总是覆盖孩子的子树。这会丢数据：
在 `foo!bar.baz` 之后插入 `foo!bar.meow` 会抹掉 `baz`。

**我们实现的纠正语义（论文 §VII + RePraxis）：** `P!K` 断言 `P` 有*恰好一个*孩子。
插入它应移除 `P` 下 `K` 的任何**兄弟姐妹**，但**保留** `K` 及其既有子树。
因此 `x.age!32` 然后 `x.age!33` ⇒ `age` 有唯一孩子 `33`；
`foo!bar.baz` 然后 `foo!bar.meow` ⇒ `bar` 保留 `baz` 与 `meow`（只有 `bar` 的兄弟姐妹
会被排除）。这是相对 Praxish 最重要的单一分歧。

`DB.retract` 删除路径的叶键。`DB.ground(sentence, bindings)` 把已绑定变量代回路径
（保留 `.`/`!`），对数组（集合值）警告。

## 查询 DSL（`praxish.js` 的 `Praxish.query`）

条件是字符串；`parts = 按空白切分`：
- **1 token** → 逻辑句子：`DB.unify`（合取；扩展绑定）。
- `not S` → 失败即否定：当且仅当 `S` 零次统一时保留匹配。
- `eq A B` → 若一侧已绑定/常量、另一侧未绑定变量，则**绑定**它（赋值）；
  若两侧都已绑定，则当且仅当字符串相等时保留；两侧都未绑定 = 作者错误。
- `neq A B` → 两侧都必须已绑定；当且仅当不等时保留。
- `lt|lte|gt|gte A B` → 两侧已绑定；经 `Number()` 数值比较。
- `calc R op A B` → `op ∈ {add,sub,mul}` 把结果写入新逻辑变量 `R`；`calc R count Xs`
  计数数组值绑定（数组只来自 `set` 子查询）。无 `div`。
- 子查询对象 `{set: R, find: [lvars], where: [conds]}` → 跑嵌套查询，把每个结果投影到
  `find`，把列表存到 `R` 下。**子查询不能嵌套。**
- `killsPerStep` 元数据记录哪个条件消灭了全部绑定（不可能动作调试）。值得为日后
  「为何前置失败」检查器复现。

在 Haskell 中我们把条件建模为类型化的 `Condition` ADT（无字符串切分），精确保留这些语义。
Praxish 的 DSL 缺少论文的完整 FOL（`∀`/`∃`/`∨`/`→`）；那些是 v1 之后的（见 LEDGER）。

## 实践、动作、结果（`praxish.js`）

- `definePractice` 注册 `practiceDef` 并在 `practiceData.<id>.` 下插入其静态 `data` 句子。
- 实践字段：`id`、`name`（模板）、`roles`（数组；实例键）、`actions`、
  可选 `data`、`init`（实例首次孵化时跑一次的结果）、`functions`
  （命名、参数、`cases` 为 `{conditions, outcomes}`——守卫条件效果）。
- 动作字段：`name`（带 `[Var]` 的模板，兼作 actionID）、`conditions`、`outcomes`
  （字符串：`insert …` / `delete …` / `call fn args…`）。
- `getAllPossibleActions(state, actor)` — 对每个已实例化实践
  （`db.practice.<id>.<roles…>`），统一角色以枚举实例，播种 `{Actor: actor}` +
  角色绑定，经 `query` 跑每个动作的 `conditions`；每个幸存绑定是一个落地动作
  （名称经 `renderText`，`[Var]`→值）。
- `performOutcome` — `insert`：检测**孵化**（插入 `practice.<id>.<roles>` 且实例先前不存在），
  插入后用角色绑定跑该实践的 `init` 一次。`delete`：`DB.retract`。`call`：跨 practiceDefs
  找命名函数，绑定参数，跑**第一个**匹配 case 的结果。
- `renderText` = 字面 `[key]`→值替换。

## 动作选择（`planner.js` / `demos/pwim/app.js`）

- 主循环是 **轮转，每 tick 一个 actor**（演示中 1000 ms 间隔）；玩家回合暂停等待输入，
  NPC 用 planner。
- `Planner.scoreActions(state, actor, depth)` — 对每个可能动作：克隆 DB，推测性
  `performAction`，`score = evaluate(db, goals)`，以折扣 **0.9**（自身未来）与 **0.5**
  （他人）递归到 `depth`，然后恢复 DB。`pickAction` = argmax。
- **我们的改动（忠实 Versu）：** 用**按角色的 `[Want]`** 替换 Praxish 的单一全局
  `goals`/`evaluate`；`evaluate db wants = Σ modifier × (#satisfying bindings)`（论文 §IX-A）。
  不可变性意味着「克隆 + 撤销」只是对 `apply action db` 打分并丢弃。

## 示例内容（`demos/`，我们的移植目标）

- `demos/test/tests.js` — 冒烟测试 + `greet`、`tendBar`、`ticTacToe`、`jukebox` 实践。
- `demos/pwim/domain.js` — 小故事世界：`world`（经 `connected` 的地点、`Go to`）、
  `greet`、`tendBar`（order/fulfill）。最佳具体语法参考；`Prax.Worlds.Bar` 的基础。
- `demos/sway` — Swaygent（Ensemble 风格意愿/影响）选择器 — v1 之后。
- PWIM 基于嵌入的自由文本玩家输入（arXiv 2406.00942）— v1 之后，外部模型依赖。
