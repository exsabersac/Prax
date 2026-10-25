-- | 回合循环：阵容上的轮转（Praxish 的 @tick@）。
--
-- 纯步进原语，使同一核心驱动交互 CLI 与确定性重放测试。planner 是确定的，因此
-- 'runNpcTicks' 产生可复现的旁白轨迹。
module Prax.Loop
  ( advance
  , npcAct
  , runNpcTicks
  , runPassive
  ) where

import           Data.Maybe (listToMaybe)
import qualified Data.Map.Strict as Map

import           Prax.Db (exists)
import           Prax.Types
import           Prax.Engine (performAction, roundBoundary)
import           Prax.Planner (pickAction, motiveSignature, candidateActions)

-- | 推进到下一个活角色（跳过事实 @dead.\<name\>@）并返回它；每次轮转回绕时运行引擎回合边界
-- （规格 @docs/specs/2026-07-16-v44-the-schedule.md@）。下一活索引 @i@ 在 @i <= cursor@ 时为
-- 回绕——含相等，因此单幸存者阵容每回合回绕（严格 @<@ 会冻结引擎时间）。初始 @cursor = -1@
-- 表示第 1 回合前无边界触发。回绕时：运行 'Prax.Engine.roundBoundary' 一次（推进时钟、先触发到期
-- 再触发到期规则——规则可能杀死角色），然后从边界后存活中重新选择行动者，从索引 0 扫描新回合
-- （回绕未改 @cursor@，且边界只能杀不能复活，因此从 @cursor@ 再扫会找到同一最低索引幸存者——
-- 回合重新开始）。
advance :: PraxState -> (Character, PraxState)
advance st0 =
  case nextLiving st0 of
    Nothing -> error "Prax.Loop.advance: no living characters"
    Just i
      | i <= cursor st0 ->                        -- 回绕（含相等：单幸存者）
          let st1 = roundBoundary st0
          in case nextLiving st1 of               -- 重选：规则可能已杀死某人
               Just j  -> (characters st1 !! j, st1 { cursor = j })
               Nothing -> error "Prax.Loop.advance: no living characters"
      | otherwise -> (characters st0 !! i, st0 { cursor = i })
  where
    nextLiving st = listToMaybe
      [ i | k <- [1 .. n], let i = (cursor st + k) `mod` n, alive st i ]
      where n = length (characters st)
    alive st i = not (exists (deadSentence (charName (characters st !! i))) (db st))

-- | 让 NPC 行动（规格 2026-07-13-v35）：若其动机签名仍等于站立意图所基于的签名，则
-- __不重新审议__ 直接执行该意图（承诺是默认）；否则完整审议（'pickAction'），执行结果，
-- 并存入新意图。站立动作若其落地已不再被提供则不可执行：'stillOffered' 直接对照当前候选检查
-- （签名的 bearing 分量会漏掉已消失的非 bearing 动作，尤其是移动）。
-- 返回 @(Maybe GroundedAction, 新状态)@；等待则为 Nothing。
npcAct :: Int -> Character -> PraxState -> (Maybe GroundedAction, PraxState)
npcAct depth actor st =
  case Map.lookup name (intentions st) of
    Just intent | intentBasis intent == sig, stillOffered (intentAct intent) ->
      act (intentAct intent) st
    _ ->
      let chosen = pickAction depth st actor
          st1 = st { intentions =
                       Map.insert name (Intention chosen sig) (intentions st) }
      in act chosen st1
  where
    name = charName actor
    sig  = motiveSignature st actor
    -- 站立动作必须仍被提供，用完整落地相等检查——移动选择很少带 want，但一经执行必须过期
    -- （你已到达；在那里再决定），陈旧落地永不执行。
    stillOffered Nothing   = True
    stillOffered (Just ga) = ga `elem` candidateActions st actor
    act (Just ga) s = (Just ga, performAction s ga)
    act Nothing   s = (Nothing, s)

-- | 从给定状态跑 @steps@ 次 NPC 回合，收集每次执行动作的旁白（空闲——'Nothing' 选择——不产生行）。
-- 每个角色由 planner 驱动（用于确定性重放测试）。引擎回合边界骑在 'advance' 内（规格 v44），
-- 因此 @steps@ 次回合在每次轮转回绕时越过边界。
runNpcTicks :: Int -> Int -> PraxState -> ([String], PraxState)
runNpcTicks depth steps = go steps []
  where
    go 0 acc st = (reverse acc, st)
    go k acc st =
      let (actor, st1) = advance st
          (mga, st2)   = npcAct depth actor st1
      in go (k - 1) (maybe acc (\ga -> gaLabel ga : acc) mga) st2

-- | 与 'runNpcTicks' 同，但跳过名为 @idle@ 的角色（玩家旁观 / 被动夹具）。
runPassive :: String -> Int -> Int -> PraxState -> ([String], PraxState)
runPassive idle depth steps = go steps []
  where
    go 0 acc st = (reverse acc, st)
    go k acc st =
      let (actor, st1) = advance st
          (mga, st2)
            | charName actor == idle = (Nothing, st1)
            | otherwise              = npcAct depth actor st1
      in go (k - 1) (maybe acc (\ga -> gaLabel ga : acc) mga) st2
