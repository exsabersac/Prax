-- | 角色弧（Versu 论文 §X）。
--
-- 社会实践提供 /外部、低层/ 动作，而角色弧表示角色的 /内部、高层/ 状态——其夜晚的贯穿线。
-- 它是单一事实 @X.arc!\<stage\>@（经纠正后的 @!@ 单槽，因此进入新阶段覆盖旧的）。角色的 wants
-- 可门禁于其弧阶段，因此推进弧重塑其追求；且弧响应发生在他们身上的事而推进。
--
-- 既有引擎上的微型可复用库，类似 "Prax.Beliefs"。
module Prax.Arc
  ( arcSentence
  , arcOf
  , arcIs
  , enterArc
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..))

-- | The sentence @who.arc!stage@.
arcSentence :: String -> String -> String
arcSentence who stage = who ++ ".arc!" ++ stage

-- | The path @who.arc@ (to bind the current stage: @Match (arcOf who ++ "!S")@).
arcOf :: String -> String
arcOf who = who ++ ".arc"

-- | Condition: @who@ is currently in arc stage @stage@.
arcIs :: String -> String -> Condition
arcIs who stage = Match (arcSentence who stage)

-- | @who@ enters arc stage @stage@ (overriding any previous stage).
enterArc :: String -> String -> Outcome
enterArc who stage = Insert (arcSentence who stage)
