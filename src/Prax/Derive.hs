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

-- | @axiom body heads@.
axiom :: [Condition] -> [String] -> Axiom
axiom = Axiom

-- | A detected contradiction (@⊥@): the head sentence whose assertion was
-- incompatible with the model.
newtype Contradiction = Contradiction String
  deriving (Eq, Show)

-- | 在一组公理下闭合世界：构建排他逻辑模型，反复应用每个蕴含直到停止增长。
closure :: [Axiom] -> Db -> Either Contradiction Db
closure []  db0 = Right db0
closure axs db0 = run axs db0 db0

-- | Continue an ALREADY-CLOSED model with new base facts. Exactly
-- 'closure'’s semi-naive loop, entered at (model ∪ facts, delta = facts).
-- Sound only when the facts are monotone for these axioms — '!'-free and
-- unifying no negated body pattern, with 'monotoneAxioms' true — which is
-- the CALLER's obligation ('Prax.Engine.monotoneInsert'); a violation is
-- caught by the ViewInvariant net, not silently absorbed.
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

-- | An axiom's body and heads, precompiled once per world (see 'cookAxioms'):
-- the body pattern-split ('Prax.Query.cookCondition') and the head sentences
-- pre-tokenized and interned ('Prax.Db.internTokens') — the same compilation
-- 'run'\'s local @rules@ otherwise redoes on every call.
data CookedRule = CookedRule
  { crBody  :: [CookedCondition]
  , crHeads :: [[(Sym, Maybe Char)]]
  }
  deriving (Eq, Show)

-- | Precompile a domain's axioms to 'CookedRule's: exactly the rules in the
-- list, bodies pattern-split and heads pre-tokenized. Deontics-free — a world
-- that closes under the □ operator (DEON property 1) hands an already-expanded
-- list (the closure operator lives in "Prax.Deontic"), and its lifted rules
-- cook here like any other. The caller stores the result in
-- 'Prax.Types.cookedRules', so
-- 'runCooked' — invoked once per 'Prax.Engine.reclose'\/'Prax.Engine.applyGrowToks',
-- thousands of times a round — never re-cooks the axiom set.
cookAxioms :: [Axiom] -> [CookedRule]
cookAxioms axs =
  [ CookedRule (map cookCondition body) (map internTokens hs)
  | Axiom body hs <- axs ]

-- | 'run'\'s cooked mirror: case-for-case the same semi-naive loop
-- (@go@\/@deltaJoin@), typed over precompiled 'CookedRule's and
-- 'Prax.Query.queryCooked' instead of re-deriving @rules@ from @axs@ and
-- re-splitting each body pattern via 'Prax.Query.query' on every call. A
-- deliberately independent, hand-verified parallel implementation — not a
-- delegation through 'run' — so 'closure'\/'closureFrom' (which still call
-- 'run') remain a genuinely separate code path from the engine's hot loop,
-- exactly the property "Prax.ViewInvariantSpec"'s net depends on to recompute
-- against something other than the code under test.
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

-- | The facts the axioms /add/ to a world (closure minus base). Empty on
-- contradiction.
derived :: [Axiom] -> Db -> [String]
derived axs db = case closure axs db of
  Right closed -> filter (`notElem` dbToSentences db) (dbToSentences closed)
  Left _       -> []

-- | The contradiction a world's axioms produce, if any (the @⊥@ witness).
contradiction :: [Axiom] -> Db -> Maybe String
contradiction axs db = case closure axs db of
  Left (Contradiction h) -> Just h
  Right _                -> Nothing

-- | Every path pattern the axioms can read or write: body atoms at any
-- polarity (including inside Absent\/Exists\/Or\/Subquery — the
-- 'Prax.Query.cookedReadAnchors' walk), and head templates. Any □-lifted rules
-- a deontic world declared are ordinary rules in the list ('cookAxioms'), so
-- they need no second enumeration here. A ground delta that may-unify none of
-- these commutes with 'closure' (v27 spec theorem) — the basis of the engine's
-- delta-irrelevance fast path.
axiomFootprint :: [CookedRule] -> [[Sym]]
axiomFootprint rules =
  concat [ cookedReadAnchors (crBody r) ++ map (map fst) (crHeads r) | r <- rules ]

-- | Every pattern under a negation in any body: inserting a fact these
-- patterns match can UN-fire a rule (retraction), so such facts never take
-- the continuation tier.
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

-- | Every head template the axioms can write — any □-lifted rules a deontic
-- world declared included, for free, since 'cookAxioms' emitted them as rules
-- of their own. A delta that feeds some axiom can change derived facts only in
-- these families.
axiomHeadPatterns :: [CookedRule] -> [[Sym]]
axiomHeadPatterns rules = concat [ map (map fst) (crHeads r) | r <- rules ]

-- | Is the axiom set continuation-safe: does adding base facts only ever ADD
-- derived facts (given the caller also avoids negated patterns)? Conditions
-- must be monotone-up: CMatch/CNot/CAbsent (negations are handled via
-- 'axiomNegPatterns'), recursion through CExists/COr/CSubquery, CCount
-- freely, CCmp only in the grows-only direction — the count side growing
-- past a numeric literal (Gt/Gte with the literal right, Lt/Lte with it
-- left) — and CEq/CNeq only over pattern-bound variables. An Eq/Neq over an
-- aggregate-bound variable (a 'CCount' result or a 'CSubquery' set variable)
-- expresses exactly-k/not-k, which UN-fires as the aggregate grows past k —
-- anti-monotone despite Eq/Neq otherwise being a safe equality test. CCalc
-- (and any other CCmp shape) disables the tier for the world; the fallback
-- is today's full reclose, correct just slower.
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
