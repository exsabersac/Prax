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
  , fulfilled
  , inBreach
    -- * Norm-conflict detection (pure)
  , conflicts
  , incompatiblePairs
  , obligationsOf
    -- * Behavioural coupling (Wants)
  , wantFulfilled
  , avoidBreach
  ) where

import           Data.List (isPrefixOf, tails)
import           Data.Maybe (mapMaybe)

import           Prax.Db (Db, insertAll, emptyDb, exists, dbToSentences)
import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..), Want (..))
import           Prax.Derive (Axiom (..))
import           Prax.Reactions (markViolation, violationOf)

-- Fact convention --------------------------------------------------------------

-- | The obligation operator's head literal — the ONE home for the vocabulary:
-- 'obligationPath', 'obligationsOf', 'obligedLift', and "Prax.TypeCheck"'s
-- declaration-completeness net all draw from it.
obligedHead :: String
obligedHead = "obliged"

-- | The DB path of an obligation: @obliged.\<who\>.\<content\>@. @content@ is a
-- /simple term/ (a sentence) and is kept verbatim, so an exclusion @!@ inside it
-- survives into the trie (this is what makes 'conflicts' meaningful).
obligationPath :: String -> String -> String
obligationPath who content = obligedHead ++ "." ++ who ++ "." ++ content

-- | The prefix every □-lifted sentence carries ('obligedLift' prepends it to
-- each body match and head) — the full lifted-shape convention in one place:
-- "Prax.TypeCheck"'s already-lifted detection matches on THIS, so the checker
-- and the lift cannot desync.
obligedLiftPrefix :: String
obligedLiftPrefix = obligedHead ++ ".Obligor."

-- Entailment closure (□ property 1) --------------------------------------------

-- | Lift a purely-conjunctive domain rule under the obligation operator: prefix
-- @obliged.\<fresh\>.@ to every body match and head, so @□A ⊢ □B@ whenever
-- @A ⊢ B@. Rules whose body uses non-'Match' conditions are not lifted (nothing
-- sensible to place under @□@).
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

-- | Close a world's axioms under the obligation operator (DEON property 1): the
-- authored rules plus the □-lifted twin of every all-'Match' rule. A deontic
-- world declares its closure with @setAxioms (obligedClose axs)@; the general
-- engine ("Prax.Derive") closes over exactly the list it is given, lift included.
obligedClose :: [Axiom] -> [Axiom]
obligedClose axs = axs ++ mapMaybe obligedLift axs

-- Asserting / discharging ------------------------------------------------------

-- | @oblige who content@ — assert that @who@ should bring about @content@ (@□content@).
oblige :: String -> String -> Outcome
oblige who content = Insert (obligationPath who content)

-- | Retract an obligation (it has been met, or is cancelled).
discharge :: String -> String -> Outcome
discharge who content = Delete (obligationPath who content)

-- | Record that @who@ left a duty unmet. A breach /is/ a norm violation, so this
-- reuses "Prax.Reactions" verbatim (agents given a negative 'avoidBreach' want
-- steer clear of it, exactly as with any violation).
breach :: String -> String -> Outcome
breach = markViolation

-- | The reparative / contrary-to-duty obligation @□□content@ — "ideally you would
-- have brought about @content@; failing that, you now ought to". It is an
-- obligation /about an obligation/: the nested fact
-- @obliged.\<who\>.obliged.\<who\>.\<content\>@.
obligeReparative :: String -> String -> Outcome
obligeReparative who content = oblige who (obligationPath who content)

-- Querying ---------------------------------------------------------------------

-- | Condition: @who@ is currently obliged to bring about @content@.
isObliged :: String -> String -> Condition
isObliged who content = Match (obligationPath who content)

-- | Conditions for a met obligation: @who@ is obliged to @content@ /and/ it
-- actually holds. Ought does not collapse to is (paper §2.3, property 3), so both
-- conjuncts are required.
fulfilled :: String -> String -> [Condition]
fulfilled who content = [ isObliged who content, Match content ]

-- | Condition: @who@ is in breach of the duty @content@ (a recorded violation).
inBreach :: String -> String -> Condition
inBreach = violationOf

-- Norm-conflict detection ------------------------------------------------------

-- | The paper's incompatibility test (property 2): are @c1@ and @c2@ jointly
-- unsatisfiable? Assert both into a scratch model; they conflict iff one
-- @!@-clears the other so they cannot both survive (e.g. @conflicts "go!true"
-- "go!false" == True@). Symmetric; @False@ for identical or compatible contents.
-- Pure and cheap (the DB is persistent).
--
-- (There is deliberately no world-seeded variant: our @!@ exclusion is applied
-- per-insert rather than as a persistent schema, so a live world can never change
-- whether two contents mutually conflict — such a function would just duplicate
-- this one.)
conflicts :: String -> String -> Bool
conflicts c1 c2 =
  let d = insertAll [c1, c2] emptyDb
  in not (exists c1 d && exists c2 d)

-- | Every incompatible pair among a list of candidate contents — for vetting a
-- /proposed/ set of duties for internal consistency before assigning them (two
-- genuinely incompatible obligations cannot be co-held, so this checks candidates,
-- not the live DB).
incompatiblePairs :: [String] -> [(String, String)]
incompatiblePairs cs =
  [ (a, b) | (a : rest) <- tails cs, b <- rest, conflicts a b ]

-- | The contents @who@ is currently obliged to (for introspection / a drama
-- manager). Note: reading back from the trie flattens the @!@/@.@ distinction, so
-- results are for display, not to be fed back into 'conflicts'.
obligationsOf :: String -> Db -> [String]
obligationsOf who d =
  [ drop (length prefix) s | s <- dbToSentences d, prefix `isPrefixOf` s ]
  where prefix = obligedHead ++ "." ++ who ++ "."

-- Behavioural coupling ---------------------------------------------------------

-- | A want to /fulfil/ an obligation: utility @k@ per met duty. Feeds the
-- unchanged planner ("Prax.Planner"), which then pursues the duty.
wantFulfilled :: String -> String -> Int -> Want
wantFulfilled who content = Want (fulfilled who content)

-- | A want to /avoid breaching/ a duty: applied as strong-negative @-|k|@ so the
-- planner steers away from the breach (the mechanism by which norms already shape
-- behaviour in "Prax.Worlds.Bar").
avoidBreach :: String -> String -> Int -> Want
avoidBreach who content k = Want [ inBreach who content ] (negate (abs k))
