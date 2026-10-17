-- | 哪些欲望是创作动作原则上甚至能改善的？每世界从词汇计算一次（规格
-- @docs/specs/2026-07-11-v26-planner-work.md@ §2），由 planner 咨以跳过可证明无果的预测：
-- 其欲望无一能被可用动作改善的被相信模型，不容有动机的移动。
--
-- 分析是 __保守的__：仅在可从创作模式证明时回答「不可改善」。任何不确定——不可解析 'Call' 后的
-- 结果、公理可能派生的事实上的 wants、由 'Subquery'\/'Count'\/'Calc' 门禁的 wants——计为可改善。
-- 不健全的「不可改善」是 planner 行为变更与缺陷；虚假的「可改善」只花费我们本来就会做的评价。
--
-- 一条声明不变量承载保守性（对创作世界的假设，非构造保证）：__实体名永不与谓词名字面碰撞__ ——
-- 无角色、地点或值命名为 @lied@、@believes@、@regards@ 等。'mayUnifySyms' 恰好在一处花费它
-- （下方锚点）。以谓词段命名角色的世界会使分析作废；每个已发布世界满足不变量，且金标准决策序列
-- 测试会把违规呈现为丢弃的预测。
--
-- __创作边界 = 字符串，世界模型 = 煮熟。__ 字符串表面（'Prax.Types.conditionVars' 与 v40 创作
-- 守护）在煮熟存在前运行——它验证作者所写。此处一切是世界模型分析并读煮熟形式：状态的预煮表
-- （'cookedDefs'\/'cookedRules'\/'cookedDesires'\/'cookedWants'），从不读创作字符串。
--
-- 'livenessOf'（规格 @docs/specs/2026-07-13-v33-live-relevance.md@）在同一词汇上添加状态条件维度：
-- 不只「是否有任何东西能改善此 want 类？」还有「那可改善性现在是否活着？」每个命名欲望的按
-- 'Prax.Types.Liveness' 配方——负 want 类的地板检查、正 want 类的环境门禁、或无便宜状态测试适用时的
-- 'Prax.Types.AlwaysLive'——每世界计算一次并缓存在 'Prax.Types.PraxState' 上（像 'improvableDesires'
-- 自身），供 planner 的按状态死-现在测试便宜咨用。保守性方向方向同向：门禁仅在可证明安全时移除工作
-- （公理可派生或其他不确定候选永不当门禁），且每个不确定——不可解析结果、@Subquery@\/@Count@\/@Calc@
-- 污染的 want——保持欲望为 'Prax.Types.AlwaysLive'。
module Prax.Relevance
  ( mayUnifySyms
  , improvableDesires
  , livenessOf
  , bearingTemplates
  , evictionShadowNames
  , moverReadAnchors
  , producibleAtoms
  , cookedFnPool
  , cookedOutcomeAtoms
  ) where

import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import           Prax.Db (Bindings, Val (..), pathNames, dbToSentences)
import           Prax.Derive (CookedRule (..))
import           Prax.Query (CookedCondition (..), cookCondition, cookedReadAnchors, groundCookedCondition, groundNames)
import           Prax.Sym (Sym, intern, symIsVar)
import           Prax.Types

-- | 一路径模式的落地实例能否为另一模式的实例？保守 may-unify。
mayUnifySyms :: [Sym] -> [Sym] -> Bool
mayUnifySyms as bs = anchored && and (zipWith seg as bs)
  where
    seg x y = symIsVar x || symIsVar y || x == y
    anchored = or (zipWith literalMatch as bs)
    literalMatch x y = not (symIsVar x) && not (symIsVar y) && x == y

-- | 排他插入的驱逐阴影，在 token 上计算（将被清除的兄弟路径）。
evictionShadowNames :: [(Sym, Maybe Char)] -> [[Sym]]
evictionShadowNames toks =
  [ map fst (take i toks) ++ [intern "PraxEvicted"]
  | (i, (_, op)) <- zip [1 ..] toks, op == Just '!' ]

-- The Call-resolution pool: every registered function's cooked case outcomes,
-- guards ignored (conservatively: all cases), keyed by 'fnName'. Reads the one
-- registry ('Prax.Types.cookedFns') directly — since v47 functions have a
-- single home, so there is no practice fold and no resolution-order subtlety
-- (both this pool and 'Prax.Engine.lookupCookedFn' read the same Map, exactly).
cookedFnPool :: Map String ([String], [([CookedCondition], [CookedOutcome])])
             -> Map String [CookedOutcome]
cookedFnPool = Map.map (concatMap snd . snd)

-- The insert- and delete-shaped atoms an outcome can produce, resolving
-- 'CCall's through the pool (conservatively: all cases). An exclusion insert
-- both asserts its path and evicts that value's __siblings__ — whose names
-- appear nowhere in the outcome — so the delete side carries the path itself
-- plus its eviction shadows ('evictionShadowNames': conservatively, any
-- sibling). Returns Nothing for "unknown effects" (unresolvable 'CCall'):
-- the caller must treat that as improves-everything.
cookedOutcomeAtoms :: Map String [CookedOutcome] -> [String] -> CookedOutcome
                   -> Maybe ([[Sym]], [[Sym]])
cookedOutcomeAtoms fns visited o = case o of
  CInsert toks
    | any ((== Just '!') . snd) toks
                  -> Just ([map fst toks], map fst toks : evictionShadowNames toks)
    | otherwise   -> Just ([map fst toks], [])
  CInsertFor _ toks -> cookedOutcomeAtoms fns visited (CInsert toks)  -- deferred
                                                     -- retract is environment: same atoms
  CDelete toks    -> Just ([], [map fst toks])
  CForEach _ outs -> mconcat' (map (cookedOutcomeAtoms fns visited) outs)
  CRoll _ _ _ outs -> mconcat' (map (cookedOutcomeAtoms fns visited) outs)  -- body may hit
  CCall fn _
    | fn `elem` visited -> Just ([], [])           -- cycle: already counted
    | otherwise -> case Map.lookup fn fns of
        Nothing   -> Nothing                       -- unknown function: wild
        Just outs -> mconcat' (map (cookedOutcomeAtoms fns (fn : visited)) outs)
  where
    mconcat' ms = do
      pairs <- sequence ms
      pure (concatMap fst pairs, concatMap snd pairs)

-- Positive and negated path patterns of a want's cooked conditions. The Bool
-- is "uncertain": the want's satisfaction depends on machinery (numeric
-- binds, counts, subqueries) beyond pattern presence. Deliberately NOT
-- 'Prax.Query.cookedReadAnchors': subquery internals are machinery here
-- (taint), not read anchors — the two walks answer different questions.
cookedWantPatterns :: [CookedCondition] -> ([[Sym]], [[Sym]], Bool)
cookedWantPatterns = foldr step ([], [], False)
  where
    step c (pos, neg, unc) = case c of
      CMatch p     -> (p : pos, neg, unc)
      CNot p       -> (pos, p : neg, unc)
      CAbsent cs   -> let (p', n', u') = cookedWantPatterns cs
                      in (pos ++ n', neg ++ p', unc || u')
      CExists cs   -> let (p', n', u') = cookedWantPatterns cs
                      in (pos ++ p', neg ++ n', unc || u')
      COr clauses  -> let parts = map cookedWantPatterns clauses
                      in ( pos ++ concatMap (\(p', _, _) -> p') parts
                         , neg ++ concatMap (\(_, n', _) -> n') parts
                         , unc || any (\(_, _, u') -> u') parts )
      CEq {}       -> (pos, neg, unc)
      CNeq {}      -> (pos, neg, unc)
      CCmp {}      -> (pos, neg, unc)
      CCalc {}     -> (pos, neg, True)
      CCount {}    -> (pos, neg, True)
      CSubquery {} -> (pos, neg, True)

-- Every effect an authored MOVER action can cause, resolved once per world:
-- the insert- and delete-shaped atom pools ('cookedOutcomeAtoms' over every
-- action's declared outcomes, plus every practice's 'cpInits' — spawning runs
-- those too), and whether any of them is "wild" (an unresolvable 'CCall',
-- conservatively improves-everything). Ranges over 'cookedDefs' — the
-- practices movers can take — and NOT the schedule surface ('cookedSchedule'
-- lives off 'cookedDefs' by construction, spec v44): a desire only the engine
-- schedule can improve (@hungry.*@, @marketDay.*@) has no improving MOVER
-- action, so the static screen stays exact and its liveness becomes a
-- GateCheck the pulse flips (the v35 wake). Shared by 'improvableDesires' and
-- 'livenessOf' — one atom-pool computation, not two.
data AtomPools = AtomPools
  { poolInserted :: [[Sym]]
  , poolDeleted  :: [[Sym]]
  , poolWild     :: Bool
  }

worldAtomPools :: Map String CookedPractice -> Map String [CookedOutcome] -> AtomPools
worldAtomPools defs fns = AtomPools
  { poolInserted = concatMap (maybe [] fst) atoms
  , poolDeleted  = concatMap (maybe [] snd) atoms
  , poolWild     = Nothing `elem` atoms
  }
  where
    practices = Map.elems defs
    atoms = [ cookedOutcomeAtoms fns [] o
            | cp <- practices, a <- cpActions cp, o <- caOuts a ]
         ++ [ cookedOutcomeAtoms fns [] o | cp <- practices, o <- cpInits cp ]

-- Axiom heads count as derivable: a want (or gate candidate) over a
-- derivable pattern is conservatively improvable\/never a gate. □-lifted
-- heads arrive as rules of their own ('Prax.Derive.cookAxioms'). Shared by
-- 'improvableDesires' and 'livenessOf'.
axiomDerivable :: [CookedRule] -> [Sym] -> Bool
axiomDerivable rules p = any (mayUnifySyms p) heads
  where heads = [ map fst h | r <- rules, h <- crHeads r ]

-- | 某些创作动作可能改善的欲望名（词汇相关性）。
improvableDesires :: PraxState -> [String]
improvableDesires st =
  [ desireName d | d <- desires st, improvable d ]
  where
    pools = worldAtomPools (cookedDefs st) (cookedFnPool (cookedFns st))
    wild = poolWild pools
    inserted = poolInserted pools
    deleted  = poolDeleted pools
    derivable = axiomDerivable (cookedRules st)
    improvable d@(Desire _ (Want _ u))
      | u == 0    = False
      | wild      = True
      | unc       = True
      | any derivable (pos ++ neg) = True
      | u > 0     = any (\i -> any (mayUnifySyms i) pos) inserted
                    || any (\dl -> any (mayUnifySyms dl) neg) deleted
      | otherwise = any (\dl -> any (mayUnifySyms dl) pos) deleted
                    || any (\i -> any (mayUnifySyms i) neg) inserted
      where (pos, neg, unc) = cookedWantPatterns (cookedDesires st Map.! desireName d)

-- | 分类每个具名欲望的此刻已死配方（见 'Liveness'）。
livenessOf :: PraxState -> Map String Liveness
livenessOf st =
  Map.fromList [ (desireName d, classify d) | d <- desires st ]
  where
    pools = worldAtomPools (cookedDefs st) (cookedFnPool (cookedFns st))
    derivable = axiomDerivable (cookedRules st)
    classify d@(Desire _ (Want _ u))
      | u < 0     = FloorCheck
      | u > 0     = positive (cookedDesires st Map.! desireName d)
      | otherwise = AlwaysLive
    positive conds
      | unc || poolWild pools || null gates = AlwaysLive
      | otherwise = GateCheck gates
      where
        (_, _, unc) = cookedWantPatterns conds
        candidates = [ p | CMatch p <- conds ]
        qualifies p = not (any (mayUnifySyms p) (poolInserted pools))
                    && not (derivable p)
        gates = [ [CMatch p] | p <- candidates, qualifies p ]

-- | 'Prax.Planner.predictMove'（作用域门）为预测行动者所读的一切。
moverReadAnchors :: PraxState -> Character -> Character -> [[Sym]]
moverReadAnchors st actor m =
  scopeReads ++ [believesRead, deadRead] ++ affordanceReads ++ functionReads ++ desireReads
  where
    mSym   = intern (charName m)
    actorB = Map.singleton (intern "Actor") (VSym mSym)
    ownerB = Map.singleton (intern "Owner") (VSym mSym)
    scopeB = Map.fromList [ (intern "Actor",   VSym (intern (charName actor)))
                          , (intern "Witness", VSym mSym) ]
    readsOf b conds = cookedReadAnchors (map (groundCookedCondition b) conds)
    scopeReads   = readsOf scopeB (map cookCondition (predictionScope st))
    believesRead = [ intern (charName actor), intern "believes"
                   , intern "desires", mSym, intern "PraxD" ]
    deadRead     = map intern (pathNames (deadSentence (charName m)))
    affordanceReads = concat
      [ groundNames actorB (cpInstanceNames cp)
        : concatMap (\ca -> readsOf actorB (caConds ca)
                            ++ outcomeCondReads actorB (caOuts ca))
                    (cpActions cp)
        ++ outcomeCondReads Map.empty (cpInits cp)
      | cp <- Map.elems (cookedDefs st) ]
    -- The one registry ('cookedFns'), read once (not per practice, since
    -- functions have a single home since v47).
    functionReads = concat [ readsOf Map.empty cs ++ outcomeCondReads Map.empty os
                           | (_, cases) <- Map.elems (cookedFns st), (cs, os) <- cases ]
    desireReads = concat [ readsOf ownerB conds | conds <- Map.elems (cookedDesires st) ]

-- Conditions embedded in outcomes ('CForEach' guards, recursively) — the
-- imagined apply queries these against the node's view.
outcomeCondReads :: Bindings -> [CookedOutcome] -> [[Sym]]
outcomeCondReads b outs = concat
  [ case o of
      CForEach cs os    -> reads' cs os
      CRoll _ _ cs os   -> reads' cs os   -- a roll's guard reads like a CForEach's
      _                 -> []
  | o <- outs ]
  where reads' cs os = cookedReadAnchors (map (groundCookedCondition b) cs)
                         ++ outcomeCondReads b os

-- | 每角色：其创作 want 所激励的 affordance 模板。
bearingTemplates :: PraxState -> Map String [String]
bearingTemplates st =
  Map.fromList [ (charName c, bearing (charPats c)) | c <- characters st ]
  where
    defs = cookedDefs st
    fns = cookedFnPool (cookedFns st)
    actionAtoms = [ (caName a, atoms a)
                  | cp <- Map.elems defs, a <- cpActions cp ]
    atoms a = do
      pairs <- traverse (cookedOutcomeAtoms fns []) (caOuts a)
      pure (concatMap fst pairs ++ concatMap snd pairs)
    charPats c = cookedReadAnchors
      (  concat (Map.findWithDefault [] (charName c) (cookedWants st))
      ++ [ cc | d <- desires st, desireName d `elem` charDesires c
              , cc <- cookedDesires st Map.! desireName d ] )
    bearing pats =
      [ n | (n, m) <- actionAtoms
          , case m of
              Nothing -> True
              Just as -> any (\atom -> any (mayUnifySyms atom) pats) as ]

-- | 已注册世界最终可能包含的一切，用于死条件 lint；无法限界时为 @Nothing@。
producibleAtoms :: PraxState -> Maybe [[Sym]]
producibleAtoms st = do
  pairs <- sequence ( [ cookedOutcomeAtoms fns [] o
                      | cp <- practices, a <- cpActions cp, o <- caOuts a ]
                   ++ [ cookedOutcomeAtoms fns [] o
                      | cp <- practices, o <- cpInits cp ]
                   ++ [ cookedOutcomeAtoms fns [] o
                      | csr <- cookedSchedule st, (_, outs) <- csrBody csr, o <- outs ] )
  pure ( concatMap fst pairs
      ++ [ map intern (pathNames s) | s <- dbToSentences (db st) ]
      ++ [ map fst h | r <- cookedRules st, h <- crHeads r ]
      ++ [[intern turnPath]]        -- the engine produces the clock
      ++ [[intern "contradiction"]] )
  where
    practices = Map.elems (cookedDefs st)
    fns = cookedFnPool (cookedFns st)
