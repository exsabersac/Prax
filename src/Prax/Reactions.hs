-- | 反应与规范（Versu 论文 §X 与 §VIII-D）。
--
-- Versu 把反应性实现为普通社会实践：执行动作孵化向受影响角色提供响应的 /反应/ 实践，且响应
-- 本身是可再孵化反应的动作。规范使用同一机制——违反规范的动作标记违规并孵化反应（此处为
-- 不赞成）向旁观者提供响应。
--
-- 像 "Prax.Core" 一样，这是既有引擎上的可复用标准库；不增加新机制。反应实例只是按参与者键控的
-- 孵化实践；响应通过删除实例消费它。用 'Prax.Engine.definePractice' 注册你自己的反应实践
-- （例如 'Prax.Worlds.Bar.disapprovalP'）。
module Prax.Reactions
  ( -- * Spawning and ending reactions
    reactionPath
  , spawnReaction
  , endReaction
  , reactionActive
    -- * Norm violations
  , markViolation
  , violationOf
  ) where

import           Data.List (intercalate)

import           Prax.Query (Condition (..))
import           Prax.Types

-- Reactions --------------------------------------------------------------------

-- | The DB path of a reaction instance: @practice.\<id\>.\<part…\>@. Parts may be
-- constants or action variables (grounded when the outcome runs).
reactionPath :: String -> [String] -> String
reactionPath pid parts = intercalate "." ("practice" : pid : parts)

-- | Spawn a reaction practice instance (offer its responses to the participants).
spawnReaction :: String -> [String] -> Outcome
spawnReaction pid parts = Insert (reactionPath pid parts)

-- | Consume a reaction instance (a response has been taken).
endReaction :: String -> [String] -> Outcome
endReaction pid parts = Delete (reactionPath pid parts)

-- | Condition: this reaction instance is currently pending.
reactionActive :: String -> [String] -> Condition
reactionActive pid parts = Match (reactionPath pid parts)

-- Norms ------------------------------------------------------------------------

-- Where a norm violation by @who@ is recorded.
violationPath :: String -> String -> String
violationPath who norm = intercalate "." ["violated", who, norm]

-- | Record that @who@ violated the named @norm@. Agents are given strong
-- negative wants on their own violations, so the planner avoids causing them.
markViolation :: String -> String -> Outcome
markViolation who norm = Insert (violationPath who norm)

-- | Condition matching a recorded violation of @norm@ by @who@.
violationOf :: String -> String -> Condition
violationOf who norm = Match (violationPath who norm)
