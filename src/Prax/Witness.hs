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

-- | The witness deposit as a first-class outcome: every co-present character
-- (except the actor) comes to believe @event@ with provenance @seen@. This is
-- what 'observable' appends; exported so generated actions (e.g.
-- "Prax.Project" stages) can carry observability in their own effects.
witnessed :: CoPresence -> String -> Outcome
witnessed copresence event =
  ForEach (copresence ++ [ Neq "Witness" "Actor" ])
          [ Insert (beliefAbout "Witness" event ++ ".seen") ]

-- | Declare an action's public appearance: every co-present character (except
-- the actor, who already knows what they did) comes to believe @event@ with
-- provenance @seen@. The event sentence may use the action's own variables.
observable :: CoPresence -> String -> Action -> Action
observable copresence event act =
  act { actionOutcomes = actionOutcomes act ++ [ witnessed copresence event ] }

-- | Condition: @who@ directly witnessed @event@.
saw :: String -> String -> Condition
saw who event = Match (beliefAbout who event ++ ".seen")

-- | Retarget a co-presence template: substitute a different variable for
-- @Witness@ (e.g. @Hearer@), so the template stays single-sourced in the
-- world while other layers quantify over their own role.
asRole :: String -> CoPresence -> [Condition]
asRole v = map (groundCondition (Map.singleton (intern "Witness") (VSym (intern v))))
