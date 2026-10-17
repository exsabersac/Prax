-- | 压力测试与覆盖（Versu 的压力测试工具——「用计算机控制全部角色跑数百局游戏实例…我们能快速
-- 发现 bug 与异常」——外加 Prompter 的场景覆盖报告）。
--
-- 'stressTest' 玩许多播种局，其中 /每个/ 角色每回合取均匀随机的可用动作，并报告到达哪些结局、
-- 哪些动作 id 曾触发（覆盖）、以及多少跑程撞上死胡同（活角色无移动）。给定种子则纯且确定——使用
-- 微型内建 LCG，无额外依赖。
--
-- 对单值事实族（@\<family\>!\<id\>@ 或 @\<family\>.\<id\>@ 路径——例如 "Prax.Script" 世界的
-- @currentScene@）的覆盖是可选、声明的参数（@Maybe String@）：调用者命名想跟踪的族，或 @Nothing@
-- 跳过跟踪。无默认族——@currentScene@ 不被本模块特权化，只被碰巧命名它的 CLI 调用者特权化。
--
-- 死胡同检测器的声明限制（v46）：空闲通过计数器恰好容忍一个无移动进展的回合边界——仅经引擎调度
-- 跨两个或更多边界推进的场景（例如无 beat、唯一出口为 @after n@ 且 n ≥ 2 的场景）报告虚假死胡同。
-- 无已发布世界有该形状（每个场景提供角色 beat）；对此类世界用无检测器的 'Prax.Loop.runNpcTicks'
-- 驱动。
module Prax.Stress
  ( RunResult(..)
  , StressReport(..)
  , runRandom
  , stressTest
  ) where

import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Maybe (isNothing, listToMaybe)
import           Data.Set (Set)
import qualified Data.Set as Set
import           Data.Word (Word64)

import           Prax.Db (unify, valToString)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Engine (possibleActions, performAction)
import           Prax.Loop (advance)

-- A minimal linear-congruential PRNG (Knuth's MMIX constants).
lcg :: Word64 -> Word64
lcg x = 6364136223846793005 * x + 1442695040888963407

-- A uniform index in @[0, n)@ and the next seed (n must be > 0).
pick :: Int -> Word64 -> (Int, Word64)
pick n s = let s' = lcg s in (fromIntegral (s' `mod` fromIntegral n), s')

-- The ending reached, if any (an @ending.\<key\>@ fact).
endingReached :: PraxState -> Maybe String
endingReached st =
  listToMaybe [ e | b <- unify "ending.E" (db st) Map.empty
                  , Just e <- [valToString <$> Map.lookup (intern "E") b] ]

-- | 覆盖 @family@ 的当前成员（若有）（场景 id 等）。
familyReached :: String -> PraxState -> Maybe String
familyReached family st =
  listToMaybe [ s | b <- unify (family ++ ".S") (db st) Map.empty
                  , Just s <- [valToString <$> Map.lookup (intern "S") b] ]

-- | 一次随机游玩的结果。
data RunResult = RunResult
  { runEnding  :: Maybe String   -- ^ the ending reached, if any
  , runActions :: Set String     -- ^ ids of actions performed
  , runVisited  :: Set String     -- ^ coverage-family members visited (empty
                                  --   if no family was named, or the world
                                  --   populates none of it)
  , runDeadEnd :: Bool           -- ^ a living character had no available action
  , runTurns   :: Int
  } deriving (Eq, Show)

-- | 最多 @cap@ 回合玩一局：每回合玩家随机选，NPC 经 planner。
runRandom :: Int -> Word64 -> Maybe String -> PraxState -> RunResult
runRandom cap seed mFamily st0 = go cap seed Set.empty (visit Set.empty st0) 0 0 st0
  where
    -- Record the visited state's current member of the tracked family, if any.
    visit scs st = maybe scs (`Set.insert` scs) (mFamily >>= (`familyReached` st))
    -- passes = how many living characters in a row have had nothing to do.
    -- 'advance' fires the engine's round boundary once per rotation, on the
    -- wrap call (the first call after every living character has had a
    -- turn) — so a full rotation of idle passes (passes == length living)
    -- does NOT by itself prove the boundary has had its say: whichever idle
    -- streak starts right at the top of a fresh run (cursor == -1) needs one
    -- MORE call beyond that rotation before the wrap fires (advance's own
    -- wrap condition is "i <= cursor", and cursor starts at -1, one below
    -- every valid index). So only declare a dead end once passes exceeds a
    -- full rotation — that extra call guarantees a wrap, hence a boundary
    -- firing, occurred within the idle streak and still changed nothing.
    go 0 _ acc scs n _ st = RunResult (endingReached st) acc scs False n
    go k s acc scs n passes st =
      case endingReached st of
        Just e -> RunResult (Just e) acc scs False n
        Nothing
          | null living                 -> RunResult Nothing acc scs False n
          | passes > length living      -> RunResult Nothing acc scs True  n  -- everyone stuck, boundary included
          | otherwise ->
              let (actor, st1) = advance st
                  acts = possibleActions st1 (charName actor)
              in case acts of
                   [] -> go k s acc (visit scs st1) n (passes + 1) st1        -- idle: pass, don't spend a turn
                   _  -> let (i, s') = pick (length acts) s
                             ga = acts !! i
                             st2 = performAction st1 ga
                         in go (k - 1) s' (Set.insert (gaActionId ga) acc)
                               (visit scs st2) (n + 1) 0 st2
      where living = livingCharacters st

-- | 多次跑程的聚合报告。
data StressReport = StressReport
  { srRuns     :: Int
  , srEndings  :: Map String Int   -- ^ ending → how many runs reached it
  , srCoverage :: Set String       -- ^ every action id that fired in any run
  , srVisited   :: Map String Int   -- ^ coverage-family member -> how many runs visited it
  , srDeadEnds :: Int              -- ^ runs that hit a dead end
  , srNoEnding :: Int              -- ^ runs that hit the turn cap with no ending
  } deriving (Eq, Show)

-- | 跑 @runs@ 次播种随机游戏，每局最多 @cap@ 回合，报告覆盖。
stressTest :: Int -> Int -> Maybe String -> PraxState -> StressReport
stressTest runs cap mFamily st0 =
  foldl' tally (StressReport runs Map.empty Set.empty Map.empty 0 0)
    [ runRandom cap (seedFor i) mFamily st0 | i <- [1 .. runs] ]
  where
    seedFor i = fromIntegral i * 2654435761   -- spread the seeds apart
    tally r res =
      r { srEndings  = maybe (srEndings r)
                             (\e -> Map.insertWith (+) e 1 (srEndings r))
                             (runEnding res)
        , srCoverage = Set.union (srCoverage r) (runActions res)
        , srVisited   = foldr (\s -> Map.insertWith (+) s 1)
                             (srVisited r) (Set.toList (runVisited res))
        , srDeadEnds = srDeadEnds r + fromEnum (runDeadEnd res)
        , srNoEnding = srNoEnding r
                         + fromEnum (isNothing (runEnding res) && not (runDeadEnd res))
        }
