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

-- | 给普通插入包上寿命：被断言事实存活 @n@ 个回合边界，然后引擎撤回它（唯一到期机制——
-- 'Prax.Types.InsertFor'）。对非 'Insert' 大声报错——'Delete'\/'Call'\/'ForEach' 上的寿命无意义。
-- 注意：撤回取走路径的整棵子树，因此寿命应落在叶事实上。
lasts :: Int -> Outcome -> Outcome
lasts n (Insert s) = InsertFor n s
lasts _ o = error ("Prax.Schedule.lasts: only an Insert can carry a lifetime, got: "
                   ++ show o)

-- | 循环集会：一条规则；开放效果每 @period@ 边界触发，其断言事实存活 @duration@ 边界
-- （v37 设计的关闭规则被到期包含——临时事实一种机制）。要求 @0 < duration < period@；
-- 从不开放、或开放在下次前从不失效的集会，不是集会。
gathering :: String -> Int -> Int -> [Outcome] -> ScheduleRule
gathering name period duration openOuts
  | duration < 1 || duration >= period =
      error ("Prax.Schedule: gathering " ++ name ++ " needs 0 < duration < period")
  | otherwise = ScheduleRule name period [ ([], map (lasts duration) openOuts) ]

-- | 感知作为周期-1 循环规则：创作的目击模板，用读作事实的时钟打戳（'Prax.Types.turnPath'——
-- tick 机制现属引擎）。@Now@\/@Seer@\/@Seen@\/@Spot@ 是其契约变量——模板绑定它们，结果直接读回——
-- 因此与其他规则体一样，创作 @sighting@ 中仅禁止 @Prax@ 命名空间与 @Actor@
-- （'Prax.Engine.setSchedule' 强制）。
sightRule :: [Condition] -> ScheduleRule
sightRule sighting = ScheduleRule "sight" 1
  [ ( sighting ++ [ Neq "Seer" "Seen", Match (turnPath ++ "!Now") ]
    , [ Insert "Seer.believes.at.Seen!Spot"
      , Insert "Seer.believes.atSince.Seen!Now" ] ) ]
