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
  , hasArc
  , lacksArc
  , enterArc
  , leaveArc
  , adoptArc
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), action)

-- | 句子 @who.arc!stage@。
arcSentence :: String -> String -> String
arcSentence who stage = who ++ ".arc!" ++ stage

-- | 路径 @who.arc@（绑定当前阶段：@Match (arcOf who ++ "!S")@）。
arcOf :: String -> String
arcOf who = who ++ ".arc"

-- | 条件：@who@ 当前处于弧阶段 @stage@。
arcIs :: String -> String -> Condition
arcIs who stage = Match (arcSentence who stage)

-- | @who@ 进入弧阶段 @stage@（覆盖任何先前阶段）。
enterArc :: String -> String -> Outcome
enterArc who stage = Insert (arcSentence who stage)

-- | 清除 @who@ 的弧阶段。
leaveArc :: String -> Outcome
leaveArc who = Delete (arcOf who)

-- | Actor 自愿进入弧阶段 @stage@（创作动作用）。
adoptArc :: String -> String -> Action
adoptArc stage label
  | null stage || any (`elem` (".!" :: String)) stage =
      error ("adoptArc: stage " ++ show stage ++ " must be a single path segment")
  | otherwise = action label
      [ Not ("Actor.arc!" ++ stage) ]
      [ Insert ("Actor.arc!" ++ stage) ]

-- | 条件：@who@ 当前处于任一弧阶段（@who.arc@ 子树非空）。
hasArc :: String -> Condition
hasArc who = Match (arcOf who)

-- | 条件：@who@ 当前无弧阶段（'hasArc' 的对偶）。
lacksArc :: String -> Condition
lacksArc who = Not (arcOf who)
