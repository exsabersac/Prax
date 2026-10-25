-- | Deontic Exclusion Logic — 一等「应当」/义务层
-- （Evans, "Introducing Exclusion Logic as a Deontic Logic", DEON 2010；完整精炼见
-- @docs/research/deon-notes.md@）。
--
-- 论文结果是道义逻辑在 Exclusion Logic 之上 /无需新语义/：@□P@（「P 应当成立」）只是普通句子
-- @Ob:P@ 的语法糖。我们的世界 DB 已是 Exclusion-Logic 模型（我们的 @.@ 是论文的多值运算符；
-- 我们的 @!@ 是其排他），因此本模块 /不加机制/ ——像 "Prax.Core"/"Prax.Reactions" 一样，只是
-- 既有引擎上的智能构造器库（不改 DB、'Prax.Query.Condition' 语言或 planner）。
--
-- 义务「@who@ 应当实现 @content@」是事实 @obliged.\<who\>.\<content\>@（镜像 "Prax.Reactions"
-- 的 @violated.\<who\>.\<norm\>@）。义务是多值的，因此一个 agent 可同时持有多个。迭代 @□□@ ——
-- 修复性 / 违反义务的义务——是嵌套事实 @obliged.\<who\>.obliged.\<who\>.\<content\>@
-- （'obligeReparative'）。
--
-- __分层是全部要点。__ 正是它避开标准道义逻辑悖论（Ross 悖论、「重言式义务」、Chisholm）：
-- @□@ 只应用于 /简单项/，从不应用于 @∧@/@∨@/@→@。因此 'oblige'/'isObliged' 取普通句子 'String'，
-- 从不取 @['Condition']@ ——不要放松这一点。
--
-- __忠实实现的__（论文 §2.3）：/表示/（□ = 事实）、/冲突检测/（性质 2——不兼容义务塌缩为 ⊥：
-- 'conflicts'）、/行为耦合/（义务上的 wants 驱动未变更的效用 planner——'wantFulfilled'/'avoidBreach'）、
-- 以及 /在蕴含下闭合/（性质 1——@Ob.P@ 与领域规则 @P→Q@ 一起派生 @Ob.Q@：'obligedClose' 在运算符下
-- 提升每个全-@Match@ 领域规则，使义务对其内容的后果闭合。世界公理在何种逻辑下闭合是创作声明——
-- 道义世界写 @setAxioms (obligedClose axs)@；通用派生引擎（"Prax.Derive"）既不知词汇也不决定时刻。
-- "Prax.TypeCheck" 网住忘记声明的事故：能调用义务却省略闭包的世界被标记
-- 'Prax.TypeCheck.DeonticUnclosed'）。
--
-- __有意不实现的__（文档化，非隐藏）：LRT/@m(X)@ 决策程序（那机制属于未来静态类型检查器，
-- LEDGER #8），以及冲突义务间的优先级排序（Alchourrón–Makinson）。
--
-- __冲突：检测 vs. 解决。__ 'conflicts' 是 /预测性/ 测试——「这两个内容是否联合可满足？」两个真正
-- 不兼容的义务 /不能共持/ 于 DB：断言第二个 @!@-清除它们分歧的第一部分，正是论文的 ⊥（你不能
-- 连贯地欠两者）。现场戏剧反而来自履行竞争排他世界资源的 /不同/ 职责；那些被共持并 __涌现解决__ ——
-- 效用 planner 履行更高价值职责，失败者落入 'inBreach'。显式优先级排序（Alchourrón–Makinson）
-- 是干净的后续扩展，不在此构建。
module Prax.Deontic
  ( -- * Fact convention
    obligationPath
  , obligedHead
  , obligedLiftPrefix
    -- * Entailment closure (□ property 1)
  , obligedLift
  , obligedClose
    -- * Asserting / discharging obligations (Outcomes)
  , oblige
  , discharge
  , breach
  , obligeReparative
    -- * Querying obligations (Conditions)
  , isObliged
  , neverObliged
  , fulfilled
  , inBreach
    -- * Norm-conflict detection (pure)
  , conflicts
  , incompatiblePairs
  , obligationsOf
    -- * Behavioural coupling (Wants)
  , wantFulfilled
  , avoidBreach
    -- * Location-scoped obligations
  , obligeWhenAt
  , dischargeWhenAt
  , isObligedWhenAt
  ) where

import           Data.List (isPrefixOf, tails)
import           Data.Maybe (mapMaybe)

import           Prax.Db (Db, insertAll, emptyDb, exists, dbToSentences)
import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..), Want (..))
import           Prax.Derive (Axiom (..))
import           Prax.Reactions (markViolation, violationOf)

-- Fact convention --------------------------------------------------------------

-- | 义务算子的头字面——引擎中 *唯一* 的义务头。
obligedHead :: String
obligedHead = "obliged"

-- | 义务的 DB 路径：@obliged.\<who\>.\<content\>@。
obligationPath :: String -> String -> String
obligationPath who content = obligedHead ++ "." ++ who ++ "." ++ content

-- | 每个 □-提升句子携带的前缀（'obligedLift' 发出）。
obligedLiftPrefix :: String
obligedLiftPrefix = obligedHead ++ ".Obligor."

-- Entailment closure (□ property 1) --------------------------------------------

-- | 在义务算子下提升一条纯合取域规则（DEON □）。
obligedLift :: Axiom -> Maybe Axiom
obligedLift (Axiom body heads)
  | all isMatch body = Just (Axiom (map liftCond body) (map liftSent heads))
  | otherwise        = Nothing
  where
    isMatch (Match _) = True
    isMatch _         = False
    liftCond (Match s) = Match (liftSent s)
    liftCond c         = c
    liftSent s = obligedLiftPrefix ++ s

-- | 在义务算子下闭合世界公理（把可提升规则展开进列表）。
obligedClose :: [Axiom] -> [Axiom]
obligedClose axs = axs ++ mapMaybe obligedLift axs

-- Asserting / discharging ------------------------------------------------------

-- | @oblige who content@——断言 @who@ 应促成 @content@。
oblige :: String -> String -> Outcome
oblige who content = Insert (obligationPath who content)

-- | 撤回义务（已履行或取消）。
discharge :: String -> String -> Outcome
discharge who content = Delete (obligationPath who content)

-- | 记录 @who@ 未履行职责。违约 /是/ 可查询事实。
breach :: String -> String -> Outcome
breach = markViolation

-- | 修复性\/违反义务的义务 @□□content@。
obligeReparative :: String -> String -> Outcome
obligeReparative who content = oblige who (obligationPath who content)

-- Querying ---------------------------------------------------------------------

-- | 条件：@who@ 当前有义务促成 @content@。
isObliged :: String -> String -> Condition
isObliged who content = Match (obligationPath who content)

-- | 条件：@who@ 无任何 @content@ 义务叶。
neverObliged :: String -> String -> Condition
neverObliged who content = Not (obligationPath who content)

-- | 已履行义务的条件：@who@ 有义务且内容已成立。
fulfilled :: String -> String -> [Condition]
fulfilled who content = [ isObliged who content, Match content ]

-- | 条件：@who@ 违约于职责 @content@。
inBreach :: String -> String -> Condition
inBreach = violationOf

-- Norm-conflict detection ------------------------------------------------------

-- | 论文的不相容测试（性质 2）：两内容是否冲突？
conflicts :: String -> String -> Bool
conflicts c1 c2 =
  let d = insertAll [c1, c2] emptyDb
  in not (exists c1 d && exists c2 d)

-- | 候选内容列表中每一对不相容对。
incompatiblePairs :: [String] -> [(String, String)]
incompatiblePairs cs =
  [ (a, b) | (a : rest) <- tails cs, b <- rest, conflicts a b ]

-- | @who@ 当前有义务促成的内容（供检查）。
obligationsOf :: String -> Db -> [String]
obligationsOf who d =
  [ drop (length prefix) s | s <- dbToSentences d, prefix `isPrefixOf` s ]
  where prefix = obligedHead ++ "." ++ who ++ "."

-- Behavioural coupling ---------------------------------------------------------

-- | 想 /履行/ 义务的 want：每满足实例效用 @k@。
wantFulfilled :: String -> String -> Int -> Want
wantFulfilled who content = Want (fulfilled who content)

-- | 想 /避免违约/ 的 want：作强负效用应用。
avoidBreach :: String -> String -> Int -> Want
avoidBreach who content k = Want [ inBreach who content ] (negate (abs k))

-- Location-scoped obligations (v70) -------------------------------------------

-- | 地点作用域义务路径：@obliged.<who>.whenAt.<place>.<content>@。
whenAtPath :: String -> String -> String -> String
whenAtPath who place content =
  obligedHead ++ "." ++ who ++ ".whenAt." ++ place ++ "." ++ content

-- | 断言 @who@ 仅在处于 @place@ 时应当促成 @content@（地点作用域道义规范）。
obligeWhenAt :: String -> String -> String -> Outcome
obligeWhenAt who place content = Insert (whenAtPath who place content)

-- | 撤回地点作用域义务。
dischargeWhenAt :: String -> String -> String -> Outcome
dischargeWhenAt who place content = Delete (whenAtPath who place content)

-- | 条件：@who@ 有 whenAt 义务且当前在 @place@（履行门禁用）。
isObligedWhenAt :: String -> String -> String -> [Condition]
isObligedWhenAt who place content =
  [ Match ("at." ++ who ++ "!" ++ place)
  , Match (whenAtPath who place content) ]
