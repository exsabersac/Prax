-- | 基于效用的动作选择（Versu §IX），带超出源的前瞻扩展，在 v23 重设计
-- （规格：docs/specs/2026-07-10-v23-planner-realism-design.md）。
--
-- 选择是论文的 apply-and-evaluate：按每个候选产生的世界打分。前瞻是 __对被相信心智的回合漫步__：
-- 一个想象回合，其中 actor 的 'predictionScope' 内每个其他角色从 actor 对他们的 __被相信模型__
-- （"Prax.Minds"——可能错误）取一次 /有动机的/ 移动，随后是 actor 自身下一选择，递归。折扣：
-- 0.9 自身未来移动，0.5 他人。累积是想象回合上绝对效用的折扣流。未知心智与范围外角色被建模为
-- 静止——从不「帮忙」。
module Prax.Planner
  ( evaluate
  , evaluateCooked
  , candidateActions
  , predictMove
  , scoreActions
  , pickAction
  , motiveSignature
  ) where

import           Data.List (nub, sort, sortOn)
import qualified Data.Map.Strict as Map
import           Data.Maybe (listToMaybe)
import           Data.Ord (Down(..))

import           Prax.Db (Val (..), exists, childKeys)
import           Prax.Query (countSatisfying, groundCondition, query, CookedCondition, queryCooked)
import           Prax.Sym (Sym, intern)
import           Prax.Types
import           Prax.Engine (possibleActions, performAction, groundedDeltaAnchors)
import           Prax.Minds (believedDesires, cookedSelfWants, cookedDesiresFor)
import           Prax.Relevance (moverReadAnchors, mayUnifySyms)

-- | 世界相对一组 wants 的总效用：@Σ utility × #satisfying@。
evaluate :: PraxState -> [Want] -> Int
evaluate st wants =
  sum [ wantUtility w * countSatisfying view (wantConditions w) Map.empty
      | w <- wants ]
  where view = readView st

-- | 'evaluate' 的煮熟镜像，由 'Prax.Minds.cookedSelfWants'\/'Prax.Minds.cookedDesiresFor' 喂养——
-- Planner 内部打分路径（'scoreActions'\/'predictMove'\/'pickAction'）。与 'evaluate' 逐 case：
-- 同一效用×满足计数之和，经 'queryCooked' 而非 'countSatisfying'。
evaluateCooked :: PraxState -> [([CookedCondition], Int)] -> Int
evaluateCooked st wants =
  sum [ u * length (queryCooked view cs Map.empty) | (cs, u) <- wants ]
  where view = readView st

-- | 角色实际可采取的动作（实践绑定过滤）。死者不进入任何人的计划，包括自己的：
-- 咨询时已标记死亡的角色无候选，因此 'predictMove' 与行动者自身 'selfNext' 递归都不会
-- 围绕或穿过他们规划。
candidateActions :: PraxState -> Character -> [GroundedAction]
candidateActions st c
  | exists (deadSentence (charName c)) (db st) = []
  | otherwise =
      let as = possibleActions st (charName c)
      in case charBoundTo c of
           Nothing  -> as
           Just pid -> filter ((== pid) . gaPracticeId) as

-- | mover 是否在 actor 的预测范围内？世界的模板（覆盖 @Actor@/@Witness@）落地到该对并对照
-- 视图查询；空模板意味着所有人。
inScope :: PraxState -> Character -> Character -> Bool
inScope st actor m =
  not (null (query (readView st) grounded Map.empty))
  where
    grounded = map (groundCondition binds) (predictionScope st)
    binds = Map.fromList [ (intern "Actor",   VSym (intern (charName actor)))
                         , (intern "Witness", VSym (intern (charName m))) ]

-- | 被相信欲望是否现在已死：处于地板（负 want 类自身条件零绑定）或被门禁关闭（正 want 类
-- 环境门禁零绑定）？（'Prax.Relevance.livenessOf'；Owner 落地到 mover，匹配
-- 'Prax.Minds.cookedDesiresFor'。）
--
-- The Owner binding is passed to 'queryCooked' as a seed binding rather than
-- substituted into the conditions up front: 'Prax.Db.unifySyms' consults an
-- already-bound variable at every occurrence, so one seed binding grounds
-- @Owner@ everywhere it appears in the (possibly multi-condition) conjunct.
--
-- 不在 'cookedDesires' 中的 'FloorCheck' 欲望（@conds = []@）经空合取恒等式查询
-- （'Prax.Query.queryCookedWith' 对 @[]@ 的 fold 返回不变的 @[b0]@）——一个绑定、非空，因此计为
-- 活而非死：未记录的欲望永不可静默读作已在地板。
deadNow :: PraxState -> Character -> Desire -> Bool
deadNow st m d = case Map.lookup (desireName d) (liveness st) of
  Just FloorCheck     -> null (queryCooked v conds owner)
    where conds = Map.findWithDefault [] (desireName d) (cookedDesires st)
  Just (GateCheck gs) -> any (\g -> null (queryCooked v g owner)) gs
  _                   -> False
  where
    v     = readView st
    owner = Map.singleton (intern "Owner") (VSym (intern (charName m)))

-- | 预测者对 mover 下一移动的猜测：在预测者对被预测者的被相信模型下 mover 的最佳候选——
-- 且仅当它严格改善该模型相对什么都不做（无动机移动是噪声，非计划）。心智不可读或无动机时为 'Nothing'。
predictMove :: PraxState -> Character -> Character -> Maybe GroundedAction
predictMove st p m =
  case believedDesires st p m of
    [] -> Nothing
    ds
      -- every believed desire is DEAD: statically dead (no authored action
      -- could ever improve it) OR dead-now (improvable in principle, but not
      -- in THIS state) — no candidate can strictly beat standing still, so
      -- don't ground or evaluate any (Prax.Relevance; exact — a single LIVE
      -- desire keeps the FULL model, unimprovable/dead-now costs included,
      -- so deterrents still deter)
      | all (\d -> desireName d `notElem` improvables st || deadNow st m d) ds -> Nothing
      | otherwise ->
          let model  = cookedDesiresFor st (charName m) ds
              still  = evaluateCooked st model
              scored = sortOn (\(ga, s) -> (Down s, gaLabel ga))
                         [ (a, evaluateCooked (performAction st a) model)
                         | a <- candidateActions st m ]
          in case scored of
               ((a, s) : _) | s > still -> Just a
               _                        -> Nothing

-- The other living characters, one full cycle in cast order starting after
-- the actor (the loop's round-robin order).
othersAfter :: PraxState -> Character -> [Character]
othersAfter st actor =
  filter ((/= charName actor) . charName) (drop (i + 1) cs ++ take (i + 1) cs)
  where
    cs = livingCharacters st
    i  = case [ k | (k, c) <- zip [0 :: Int ..] cs, charName c == charName actor ] of
           (k : _) -> k
           []      -> length cs - 1   -- an actor outside the cast walks everyone

-- | 一条想象路径对选择根状态的累积效应，作为折入派生事实锥的锚点族：一旦任何扩展喂入公理
-- （'footprint'），每个可触发头（'axiomHeads'）加入 delta——并留下，因为头自身也在 footprint 中。
type PathDelta = Maybe [[Sym]]

extendDelta :: PraxState -> PathDelta -> Maybe [[Sym]] -> PathDelta
extendDelta st (Just old) (Just new) =
  Just (old ++ new ++ [ h | feeds, h <- axiomHeads st, h `notElem` old ])
  where feeds = any (\n -> any (mayUnifySyms n) (footprint st)) new
extendDelta _ _ _ = Nothing

-- | 按每个候选打开的想象回合打分（最佳在前；平局按标签打破以保证确定性）。在一次选择内，每个预测
-- 要么是根状态的——当路径 delta 可证明触及不到（actor, mover）预测所读的任何东西时重用——要么现场计算。
scoreActions :: Int -> PraxState -> Character -> [(GroundedAction, Double)]
scoreActions depth st0 actor = go depth (Just []) st0
  where
    -- The root memo: each mover's step decision (scope gate + prediction)
    -- at the PICK's root state. Map values are lazy — a mover whose pairs
    -- never reuse never computes its root prediction.
    rootStep = Map.fromList
      [ (charName m, stepPredict st0 m) | m <- othersAfter st0 actor ]
    rootReads = Map.fromList
      [ (charName m, moverReadAnchors st0 actor m) | m <- othersAfter st0 actor ]
    stepPredict s m
      | inScope s actor m = predictMove s actor m
      | otherwise         = Nothing

    -- Reuse the root's decision when sound; live otherwise (opaque path,
    -- a mover the root never enumerated, or a delta/read intersection).
    predictAt :: PathDelta -> PraxState -> Character -> Maybe GroundedAction
    predictAt (Just delta) s m
      | Just rs <- Map.lookup (charName m) rootReads
      , not (any (\d -> any (mayUnifySyms d) rs) delta)
      = Map.findWithDefault (stepPredict s m) (charName m) rootStep
    predictAt _ s m = stepPredict s m

    go d delta st =
      sortOn (\(ga, s) -> (Down s, gaLabel ga))
        [ (a, valueAfter d
                (extendDelta st0 delta (groundedDeltaAnchors st a))
                (performAction st a))
        | a <- candidateActions st actor ]

    valueAfter d delta st1 = base + rest
      where
        base = fromIntegral (evaluateCooked st1 (cookedSelfWants st1 actor))
        rest
          | d <= 0    = 0
          | otherwise = othersScore + selfNext
          where
            (afterRound, afterDelta, othersScore) =
              foldl step (st1, delta, 0) (othersAfter st1 actor)
            step (s, dlt, acc) m = case predictAt dlt s m of
              Nothing -> (s, dlt, acc)
              Just ga ->
                let s'   = performAction s ga
                    dlt' = extendDelta st0 dlt (groundedDeltaAnchors s ga)
                in (s', dlt', acc + 0.5 * fromIntegral (evaluateCooked s' (cookedSelfWants s' actor)))
            selfNext = case go (d - 1) afterDelta afterRound of
              ((_, v) : _) -> 0.9 * v
              []           -> 0

-- | 行动者的最佳动作（确定），若有。
pickAction :: Int -> PraxState -> Character -> Maybe GroundedAction
pickAction depth st actor = fst <$> listToMaybe (scoreActions depth st actor)

-- | 角色当前的 'MotiveSignature'——按构造便宜：落地而不打分，对照缓存视图的四次计数/存在遍历，
-- 无前瞻。这是安静回合的全部代价。
motiveSignature :: PraxState -> Character -> MotiveSignature
motiveSignature st c = MotiveSignature
  { msBearing      = sort (nub [ aid
                               | ga <- candidateActions st c
                               , let aid = gaActionId ga
                               , aid `elem` bearingSet ])
  , msSatisfaction = [ length (queryCooked v cs Map.empty)
                     | (cs, _) <- cookedSelfWants st c ]
  , msLiveDesires  = [ desireName d
                     | d <- desires st
                     , desireName d `elem` charDesires c
                     , desireName d `elem` improvables st
                     , not (deadNow st c d) ]
  , msKnownMotives = [ (m, d)
                     | m <- childKeys (charName c ++ ".believes.desires") v
                     , d <- childKeys (charName c ++ ".believes.desires." ++ m) v ]
  }
  where
    v = readView st
    bearingSet = Map.findWithDefault [] (charName c) (caresAbout st)
