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
  , noViolation
  , lacksViolation
  , everViolated
  , neverViolated
  ) where

import           Data.List (intercalate)

import           Prax.Query (Condition (..))
import           Prax.Types

-- Reactions --------------------------------------------------------------------

-- | 反应实例的 DB 路径：@practice.\<id\>.\<roles...\>@。
reactionPath :: String -> [String] -> String
reactionPath pid parts = intercalate "." ("practice" : pid : parts)

-- | 孵化反应实践实例（向被冒犯者提供其回应动作）。
spawnReaction :: String -> [String] -> Outcome
spawnReaction pid parts = Insert (reactionPath pid parts)

-- | 消费反应实例（已取回应）。
endReaction :: String -> [String] -> Outcome
endReaction pid parts = Delete (reactionPath pid parts)

-- | 条件：此反应实例当前挂起。
reactionActive :: String -> [String] -> Condition
reactionActive pid parts = Match (reactionPath pid parts)

-- Norms ------------------------------------------------------------------------

-- Where a norm violation by @who@ is recorded.
violationPath :: String -> String -> String
violationPath who norm = intercalate "." ["violated", who, norm]

-- | 记录 @who@ 违反了具名 @norm@。代理人可据此反应。
markViolation :: String -> String -> Outcome
markViolation who norm = Insert (violationPath who norm)

-- | 匹配所记录的 @norm@ 违反的条件。
violationOf :: String -> String -> Condition
violationOf who norm = Match (violationPath who norm)

-- | 条件：@who@ 无 @norm@ 违规记录（@violationOf@ 对偶）。
noViolation :: String -> String -> Condition
noViolation who norm = Not (violationPath who norm)

-- | 条件：@who@ 无 @norm@ 违规记录（@noViolation@ 同体；对齐 lacks* 命名）。
lacksViolation :: String -> String -> Condition
lacksViolation = noViolation

-- | 条件：@who@ 有至少一条违规叶（@violated.<who>.*@）。
everViolated :: String -> Condition
everViolated who = Exists [ Match ("violated." ++ who ++ ".Norm") ]

-- | 条件：@who@ 无任何违规叶（@everViolated@ 的 Absent 对偶）。
neverViolated :: String -> Condition
neverViolated who = Absent [ Match ("violated." ++ who ++ ".Norm") ]
