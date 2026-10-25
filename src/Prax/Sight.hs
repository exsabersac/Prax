-- | 目击：知道人们在何处本身就是信息。
--
-- 感知骑引擎调度（规格 @docs/specs/2026-07-16-v44-the-schedule.md@）：世界在其目击模板上声明
-- 'Prax.Schedule.sightRule'（保留变量 @Seer@\/@Seen@\/@Spot@），引擎在每回合边界触发的周期-1
-- 循环规则，为每个共现对刷新地点信念：
--
-- > <seer>.believes.at.<seen>!<place>      -- 最佳猜测（单槽：被覆盖）
-- > <seer>.believes.atSince.<seen>!<turn>  -- 形成时间
--
-- 目击在分离后持续（「最后已知位置」），且 'sightedWithin' 把时间戳变为预测范围窗口：视界是
-- 带声明含义的创作世界参数，非引擎常量。
module Prax.Sight
  ( sightedWithin
  , lastKnownAt
  , unknownWhere
  , lacksKnownWhere
  , knownWhere
  ) where

import           Prax.Query (Condition (..), CmpOp (..), CalcOp (..))
import           Prax.Types (turnPath)

-- | 关于 @Actor@\/@Witness@ 的作用域片段：Witness 在给定回合数内被看见过（共享地点的近期记忆）。
sightedWithin :: Int -> [Condition]
sightedWithin h =
  [ Match "Actor.believes.atSince.Witness!Since"
  , Match (turnPath ++ "!Now")
  , Calc "Expiry" Add "Since" (show h)
  , Cmp Gte "Expiry" "Now" ]

-- | 条件：@seer@ 相信 @seen@ 在 @place@（最后已知位置，排他叶）。
lastKnownAt :: String -> String -> String -> Condition
lastKnownAt seer seen place =
  Match (seer ++ ".believes.at." ++ seen ++ "!" ++ place)

-- | 条件：@seer@ 对 @seen@ 无任何最后已知位置（无 @believes.at.<seen>!<Place>@ 叶）。
unknownWhere :: String -> String -> Condition
unknownWhere seer seen =
  Absent [ Match (seer ++ ".believes.at." ++ seen ++ "!Place") ]

-- | 条件：@seer@ 对 @seen@ 无最后已知位置（@unknownWhere@ 同体；对齐 lacks* 命名）。
lacksKnownWhere :: String -> String -> Condition
lacksKnownWhere = unknownWhere

-- | 条件：@seer@ 对 @seen@ 持有某一最后已知位置（子树存在）。
knownWhere :: String -> String -> Condition
knownWhere seer seen =
  Match (seer ++ ".believes.at." ++ seen)
