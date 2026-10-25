-- | 创作目击：来自观察的信息不对称。
--
-- 动作的公共外观是作者用 'observable' 陈述的语义属性——未声明动作不是事件（等待不是新闻），
-- 且声明外观可有意不同于动作 /所做/（毒杯子可看起来像倒酒）。
--
-- 被目击事件是普通信念（"Prax.Beliefs"）：@\<witness\>.believes.\<event\>.seen@ —— @.seen@ 叶
-- 记录 /出处/（直接观察，/多值/）。谣言层（@Prax.Rumor@，v20）在 @.seen@ 旁添加 @.heard.\<source\>@
-- 边，每告知者一边，因此证据累积而非覆盖——排他槽会让传闻摧毁目击记录，且在槽上混用 @!@ 与 @.@
-- 是检查器拒绝的 @CardinalityClash@。
--
-- 共现是 __世界词汇__（引擎无地点概念）：每个世界一次提供 'CoPresence' 模板，以其自身术语关联
-- 固定变量 @Witness@ 与 @Actor@。
module Prax.Witness
  ( CoPresence
  , witnessed
  , observable
  , saw
  , asRole
  , neverSaw
  ) where

import qualified Data.Map.Strict as Map

import           Prax.Db (Val (..))
import           Prax.Query (Condition (..), groundCondition)
import           Prax.Sym (intern)
import           Prax.Types (Action (..), Outcome (..))
import           Prax.Beliefs (beliefAbout)

-- | Conditions relating the fixed variables @Witness@ and @Actor@ in the
-- world's own vocabulary (location facts, current scene, …). Everything that
-- constrains who can witness is the template's job; 'observable' adds only the
-- actor-exclusion.
type CoPresence = [Condition]

-- | 作为一等结果的目击存款：每个同场角色（除行动者）获得对事件的 `.seen` 信念。
witnessed :: CoPresence -> String -> Outcome
witnessed copresence event =
  ForEach (copresence ++ [ Neq "Witness" "Actor" ])
          [ Insert (beliefAbout "Witness" event ++ ".seen") ]

-- | 声明动作的公开外观：每个同场角色（除行动者）目击所给事件字符串。
observable :: CoPresence -> String -> Action -> Action
observable copresence event act =
  act { actionOutcomes = actionOutcomes act ++ [ witnessed copresence event ] }

-- | 条件：@who@ 直接目击了 @event@。
saw :: String -> String -> Condition
saw who event = Match (beliefAbout who event ++ ".seen")

-- | 重定向同场模板：把 @Witness@ 换成不同变量名。
asRole :: String -> CoPresence -> [Condition]
asRole v = map (groundCondition (Map.singleton (intern "Witness") (VSym (intern v))))

-- | 条件：@who@ 从未直接目击 @event@（无 `.seen` 叶）。
neverSaw :: String -> String -> Condition
neverSaw who event = Absent [ Match (beliefAbout who event ++ ".seen") ]
