-- | 前向链派生层：领域知识作为蕴含规则 @body → head@，在世界上闭合到不动点（LEDGER #17）。
--
-- 这是论文的规范模型构造 @m(G,A)@（Def 16–18）：反复对模型应用每个蕴含直到停止增长。关键部分是
-- 事实用排他逻辑 'Prax.EL.meet'（最大下界）组合，因此会强制排他槽成两个值的规则产生论文的 @⊥@ ——
-- __被检测的矛盾__，从不静默覆盖（更早朴素尖峰落入的陷阱）。
--
-- 两个有意设计选择：
--
--   * __闭包是视图。__ 'closure' 取基 'Db' 并返回 /闭合/ 的；它从不变更基。调用者保持基为真相源
--     并重算——因此前提被撤回的结论简单消失（免费可废止性），这是搅动沙盒所需要的。
--   * __关系性，非仅命题。__ 论文的前件测试 @X ≤ A@ 推广为用 "Prax.Query" /查询/ 体，使规则绑定变量
--     （@parent.X.Y ∧ parent.Y.Z → grandparent.X.Z@）。对基身体这与 @≤@ 重合；带变量时是自然推广。
--
-- 本引擎无道义：它恰好在交给它的公理列表下闭合世界。其逻辑在 □ 运算符下闭合的世界（DEON 性质 1）
-- 通过扩展自身列表声明（闭包运算符住在 "Prax.Deontic"）；'closure'\/'run'\/'cookAxioms' 把提升的
-- 规则当作普通公理。
module Prax.Derive
  ( Axiom(..)
  , axiom
  , Contradiction(..)
  , closure
  , closureFrom
  , derived
  , contradiction
  , axiomFootprint
  , axiomNegPatterns
  , axiomHeadPatterns
  , monotoneAxioms
  , CookedRule(..)
  , cookAxioms
  , runCooked
  ) where

import           Control.Monad (foldM)
import           Data.List (nub)
import qualified Data.Map.Strict as Map

import           Prax.Db (Db, insertToks, insertAll, emptyDb, internTokens, groundTokens, tokensToSentence, dbToSentences)
import           Prax.Query (Condition (..), CmpOp (..), query, CookedCondition (..), cookCondition, cookedReadAnchors, queryCooked)
import           Prax.EL (meet, leq)
import           Prax.Sym (Sym, symName)

-- | 蕴含规则 @axiomWhen → axiomThen@：当体对某些变量绑定成立时，断言每个（落地）头句子。
-- 头是保留其 @!@/@.@ 标签的句子 /模板/（因此它们被 'Prax.EL.meet' 进模型时尊重排他）。
data Axiom = Axiom
  { axiomWhen :: [Condition]
  , axiomThen :: [String]
  }
  deriving (Eq, Show)

-- | @axiom body heads@。
axiom :: [Condition] -> [String] -> Axiom
axiom = Axiom

-- | 检测到的矛盾（@⊥@）：其断言与模型不相容的头句子。
newtype Contradiction = Contradiction String
  deriving (Eq, Show)

-- | 在一组公理下闭合世界：构建排他逻辑模型，反复应用每个蕴含直到停止增长。
closure :: [Axiom] -> Db -> Either Contradiction Db
closure []  db0 = Right db0
closure axs db0 = run axs db0 db0

-- | 用新基事实延续 *已闭合* 模型。恰为 'closure' 的半朴素循环，从 (model ∪ facts, delta = facts) 进入。
-- 仅当事实对这些公理单调时可靠——无 '!' 且不统一任何否定体模式，且 'monotoneAxioms' 为真——这是
-- *调用方* 的义务（'Prax.Engine.monotoneInsert'）；违例由 ViewInvariant 网捕获，不静默吸收。
closureFrom :: [Axiom] -> Db -> [String] -> Either Contradiction Db
closureFrom axs closed facts =
  run axs (insertAll facts closed) (insertAll facts emptyDb)

-- Shared by 'run' and 'runCooked': does @m@ already entail head tokens @h@,
-- and meet a fresh head into the model (⊥ iff incompatible).
entailed :: Db -> [(Sym, Maybe Char)] -> Bool
entailed m h = leq m (insertToks h emptyDb)

meetOne :: Db -> [(Sym, Maybe Char)] -> Either Contradiction Db
meetOne m h = maybe (Left (Contradiction (tokensToSentence h))) Right
                    (meet m (insertToks h emptyDb))

-- The shared semi-naive engine (the former closure-local 'go', verbatim,
-- with 'rules' computed from the axiom list).
run :: [Axiom] -> Db -> Db -> Either Contradiction Db
run axs = go
  where
    rules = [ (body, map internTokens hs)
            | Axiom body hs <- axs ]

    -- Semi-naive evaluation: each round fires the rules using at least one fact
    -- from @delta@ (the facts derived last round), so nothing already known is
    -- re-derived. @delta@ starts as the whole base, then shrinks to just what is
    -- new. Terminates when a round produces no fresh fact.
    go model delta =
      -- 'groundTokens' never re-splits a bound value on ./! (see its haddock
      -- invariant in Prax.Db) — relies on axiom heads binding only
      -- separator-free values, which holds for every unify-produced binding.
      let heads = [ groundTokens h b | (body, hs) <- rules
                                     , b <- deltaJoin model delta body, h <- hs ]
          fresh = nub (filter (not . entailed model) heads)
      in if null fresh
           then Right model
           else case foldM meetOne model fresh of
                  Left c  -> Left c
                  Right m -> go m (foldl (flip insertToks) emptyDb fresh)

    -- Bindings of @body@ in which at least one 'Match' atom is satisfied by a
    -- @delta@ fact (the others by the full model). With @delta@ = the base this is
    -- a full query; thereafter it visits only the newly-relevant joins.
    deltaJoin model delta body =
      case [ i | (i, Match _) <- zip [0 :: Int ..] body ] of
        []  -> query model body Map.empty        -- no positive atom: fire on the model
        pos -> nub (concatMap joinAt pos)
      where
        joinAt i = foldl step [Map.empty] (zip [0 :: Int ..] body)
          where step bs (j, c) = concatMap (query (if j == i then delta else model) [c]) bs

-- | 公理的体与头，每世界预编译一次（见 'cookAxioms'）：体经模式拆分（'Prax.Query.cookCondition'），
-- 头句子预分词并 intern（'Prax.Db.internTokens'）——否则 'run' 的局部 @rules@ 每次调用都会重做的同一编译。
data CookedRule = CookedRule
  { crBody  :: [CookedCondition]
  , crHeads :: [[(Sym, Maybe Char)]]
  }
  deriving (Eq, Show)

-- | 把域公理预编译为 'CookedRule'：恰为列表中的规则，体模式拆分、头预分词。无道义——在 □ 算子下闭合的世界
-- （DEON 性质 1）交出已展开列表（闭包算子在 "Prax.Deontic"），其提升规则在此像其他规则一样煮。调用方把结果存入
-- 'Prax.Types.cookedRules'，因此 'runCooked'——每次 'Prax.Engine.reclose'\/'Prax.Engine.applyGrowToks'
-- 调用一次，每回合数千次——从不重煮公理集。
cookAxioms :: [Axiom] -> [CookedRule]
cookAxioms axs =
  [ CookedRule (map cookCondition body) (map internTokens hs)
  | Axiom body hs <- axs ]

-- | 'run' 的煮熟镜像：逐 case 同一半朴素循环（@go@\/@deltaJoin@），类型落在预编译 'CookedRule' 与
-- 'Prax.Query.queryCooked' 上，而非每次从 @axs@ 重导 @rules@ 并用 'Prax.Query.query' 重拆体模式。
-- 有意独立、手验的并行实现——不经 'run' 委托——因此 'closure'\/'closureFrom'（仍调用 'run'）相对引擎热循环
-- 保持真正分离的代码路径，恰是 "Prax.ViewInvariantSpec" 网依赖的性质：对照非被测代码重算。
runCooked :: [CookedRule] -> Db -> Db -> Either Contradiction Db
runCooked rules = go
  where
    go model delta =
      let heads = [ groundTokens h b | CookedRule body hs <- rules
                                      , b <- deltaJoinCooked model delta body, h <- hs ]
          fresh = nub (filter (not . entailed model) heads)
      in if null fresh
           then Right model
           else case foldM meetOne model fresh of
                  Left c  -> Left c
                  Right m -> go m (foldl (flip insertToks) emptyDb fresh)

    deltaJoinCooked model delta body =
      case [ i | (i, CMatch _) <- zip [0 :: Int ..] body ] of
        []  -> queryCooked model body Map.empty
        pos -> nub (concatMap joinAt pos)
      where
        joinAt i = foldl step [Map.empty] (zip [0 :: Int ..] body)
          where step bs (j, c) = concatMap (queryCooked (if j == i then delta else model) [c]) bs

-- | 公理向世界 /添加/ 的事实（闭包减基）。矛盾时为空。
derived :: [Axiom] -> Db -> [String]
derived axs db = case closure axs db of
  Right closed -> filter (`notElem` dbToSentences db) (dbToSentences closed)
  Left _       -> []

-- | 世界公理产生的矛盾（若有）（@⊥@ 见证）。
contradiction :: [Axiom] -> Db -> Maybe String
contradiction axs db = case closure axs db of
  Left (Contradiction h) -> Just h
  Right _                -> Nothing

-- | 公理可读或可写的每个路径模式：任意极性的体原子（含 Absent\/Exists\/Or\/Subquery 内——
-- 'Prax.Query.cookedReadAnchors' 行走），以及头模板。道义世界声明的任何 □-提升规则已是列表中的普通规则
-- （'cookAxioms'），故此处无需二次枚举。与这些均不可统一的落地 delta 与 'closure' 交换（v27 规格定理）——
-- 引擎 delta 无关快路径的基础。
axiomFootprint :: [CookedRule] -> [[Sym]]
axiomFootprint rules =
  concat [ cookedReadAnchors (crBody r) ++ map (map fst) (crHeads r) | r <- rules ]

-- | 任一体中否定下的每个模式：插入这些模式匹配的事实可 *熄火* 规则（撤回），故此类事实永不走延续层。
axiomNegPatterns :: [CookedRule] -> [[Sym]]
axiomNegPatterns rules = concat [ concatMap negOf (crBody r) | r <- rules ]
  where
    negOf c = case c of
      CNot p          -> [p]
      CAbsent cs      -> cookedReadAnchors cs   -- everything inside a ¬∃
      CExists cs      -> concatMap negOf cs
      COr clauses     -> concatMap (concatMap negOf) clauses
      CSubquery _ _ w -> concatMap negOf w
      _               -> []

-- | 公理可写的每个头模板——道义世界声明的任何 □-提升规则免费包含，因 'cookAxioms' 已把它们发成自有规则。
-- 喂给某公理的 delta 只能在这些族中改变派生事实。
axiomHeadPatterns :: [CookedRule] -> [[Sym]]
axiomHeadPatterns rules = concat [ map (map fst) (crHeads r) | r <- rules ]

-- | 公理集是否延续安全：添加基事实是否只 *增加* 派生事实（假定调用方也避开否定模式）？条件必须单调向上：
-- CMatch/CNot/CAbsent（否定经 'axiomNegPatterns' 处理）、经 CExists/COr/CSubquery 递归、CCount 自由、
-- CCmp 仅在只增长方向——计数侧越过数值字面（字面在右的 Gt/Gte，字面在左的 Lt/Lte）——且 CEq/CNeq
-- 仅在模式绑定变量上。聚合绑定变量上的 Eq/Neq（'CCount' 结果或 'CSubquery' 集合变量）表达恰好-k/非-k，
-- 随聚合越过 k 而熄火——尽管 Eq/Neq 否则是安全相等测试，此处反单调。CCalc（及其他 CCmp 形状）对本世界禁用该层；
-- 回退是今日的完整 reclose，正确只是更慢。
monotoneAxioms :: [CookedRule] -> Bool
monotoneAxioms = all (bodyOk . crBody)
  where
    bodyOk body = all (condOk (aggVars body)) body

    -- Every variable bound by an aggregate anywhere in the body (a body
    -- shares one binding environment, so a CCount/CSubquery result nested
    -- under CExists/COr/CSubquery is still visible to an Eq/Neq elsewhere
    -- in the body).
    aggVars = concatMap collect
      where
        collect c = case c of
          CCount r _      -> [r]
          CSubquery s _ w -> s : aggVars w
          CExists cs      -> aggVars cs
          COr clauses     -> concatMap aggVars clauses
          _               -> []

    condOk aggs c = case c of
      CMatch _        -> True
      CNot _          -> True
      CAbsent _       -> True
      CEq l r         -> l `notElem` aggs && r `notElem` aggs
      CNeq l r        -> l `notElem` aggs && r `notElem` aggs
      CCount _ _      -> True
      CExists cs      -> all (condOk aggs) cs
      COr clauses     -> all (all (condOk aggs)) clauses
      CSubquery _ _ w -> all (condOk aggs) w
      CCmp op l r     -> case op of
        Gt  -> numeric r
        Gte -> numeric r
        Lt  -> numeric l
        Lte -> numeric l
      CCalc {}        -> False
    numeric x = let s = symName x
                in not (null s) && all (`elem` ("0123456789" :: String)) s
