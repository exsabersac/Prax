-- | v44 引擎时间的创作表面（规格 @docs/specs/2026-07-16-v44-the-schedule.md@）：声明循环规则与
-- 寿命；引擎拥有每次触发。'ScheduleRule' 类型留在 "Prax.Types"（唯一归宿，不重导出）——本模块
-- 只是组合子表面。世界用 'Prax.Engine.setSchedule' 安装其调度，旁于 'Prax.Engine.setDesires' /
-- 'Prax.Engine.definePractices'。
--
-- __真实游戏的创作周期__：一回合（人人行动一次）是几分钟虚构——大约每小时 12 回合，醒着的一天
-- ~150——且游戏跑数百到数千回合，因此按虚构尺度创作周期：饥饿 ~72 回合（一天两顿）、酒劲消退 ~12
-- （一小时）、每日市场 ~150、情感消退 ~24-48（数小时）。已发布世界压缩这些（饥饿 3、代谢 2、市场 6、
-- 情感 4）以便测试套件的短驱动能到达脉冲——有意的、非标准的测试截断，非真实创作的模型。想要遥远
-- 脉冲的测试应时钟跳（驱动 'Prax.Engine.roundBoundary' 或直接 'Prax.Engine.performOutcome' 时钟）
-- 而非继承压缩周期。
module Prax.Schedule
  ( lasts
  , gathering
  , sightRule
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types

-- | Wrap plain inserts with a lifetime: the asserted fact lives @n@ round
-- boundaries, then the engine retracts it (the ONE expiry mechanism —
-- 'Prax.Types.InsertFor'). Loud on anything but an 'Insert' — a lifetime on a
-- 'Delete'\/'Call'\/'ForEach' has no meaning. NOTE the retract takes the
-- path's whole subtree, so lifetimes belong on leaf facts.
lasts :: Int -> Outcome -> Outcome
lasts n (Insert s) = InsertFor n s
lasts _ o = error ("Prax.Schedule.lasts: only an Insert can carry a lifetime, got: "
                   ++ show o)

-- | A recurring convening: ONE rule; the open effects fire every @period@
-- boundaries and their asserted facts live @duration@ boundaries (the close
-- rule of the v37 design is subsumed by expiry — one mechanism for a
-- temporary fact). @0 < duration < period@; a gathering that never opens, or
-- one whose opening never lapses before the next, is not a gathering.
gathering :: String -> Int -> Int -> [Outcome] -> ScheduleRule
gathering name period duration openOuts
  | duration < 1 || duration >= period =
      error ("Prax.Schedule: gathering " ++ name ++ " needs 0 < duration < period")
  | otherwise = ScheduleRule name period [ ([], map (lasts duration) openOuts) ]

-- | Perception as a period-1 recurring rule: the authored sighting template,
-- stamped with the clock read as a fact ('Prax.Types.turnPath' — the tick
-- machinery is the engine's now). @Now@\/@Seer@\/@Seen@\/@Spot@ are its
-- CONTRACT variables — the template binds them and the outcomes read them
-- straight back out — so, like every other rule body, only the @Prax@
-- namespace and @Actor@ are forbidden in the authored @sighting@
-- ('Prax.Engine.setSchedule' enforces it).
sightRule :: [Condition] -> ScheduleRule
sightRule sighting = ScheduleRule "sight" 1
  [ ( sighting ++ [ Neq "Seer" "Seen", Match (turnPath ++ "!Now") ]
    , [ Insert "Seer.believes.at.Seen!Spot"
      , Insert "Seer.believes.atSince.Seen!Now" ] ) ]
