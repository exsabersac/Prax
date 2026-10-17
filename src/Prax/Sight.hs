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
  ) where

import           Prax.Query (Condition (..), CmpOp (..), CalcOp (..))
import           Prax.Types (turnPath)

-- | Scope fragment over @Actor@\/@Witness@: the Witness was sighted within the
-- last @h@ ticks. Worlds @Or@ this with co-presence-now in their
-- 'predictionScope'.
sightedWithin :: Int -> [Condition]
sightedWithin h =
  [ Match "Actor.believes.atSince.Witness!Since"
  , Match (turnPath ++ "!Now")
  , Calc "Expiry" Add "Since" (show h)
  , Cmp Gte "Expiry" "Now" ]
