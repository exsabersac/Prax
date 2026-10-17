-- | 共存的情节情感（规格 2026-07-15-v38），替换 Versu 继承的单槽情绪：
-- @\<who\>.feels.\<emotion\>@ 与 @\<who\>.feels.\<emotion\>.toward.\<target\>@ 是普通多值
-- 事实——对两人愤怒同时惧怕第三人全部共存，各自独立。不变量（用户，承重）：情感改变
-- 决策制定，从不改变哪些决策可被做出——此处无物触及动作可用性；定价是读这些事实的普通欲望，
-- 按世界创作。创作指引：偏好负定价（情感作为驱动自身解除的不适）——心理正确，且 v33 的
-- FloorCheck 保持未感状态免规划，而正定价情感可被动作插入因而 AlwaysLive（允许；代价即代价）。
-- 起始在触发动机处创作（'Prax.Rng.draw' 片段）；消退是起始上的创作寿命——'feelFor'\/'feelTowardFor'
-- 经引擎到期队列断言（规格 @docs/specs/2026-07-16-v44-the-schedule.md@），因此每个情感从自身起始
-- 存活自己的 @n@ 回合（v36 情节原则，无同步清扫）。情感是情节性的：它们消退；气质（特质、标记）
-- 从不——特质使情感更可能，而非更久。
module Prax.Emotion
  ( -- * An Ekman-based vocabulary (moved from Prax.Core; plain names)
    happy, sad, angry, afraid, disgusted, surprised, annoyed, pleased
    -- * Feeling and unfeeling (Outcomes)
  , feel, feelToward, unfeel, unfeelToward
    -- * Feeling with a lifetime (fades on its own onset's clock)
  , feelFor, feelTowardFor
    -- * Reading feelings (Conditions)
  , feeling, feelingToward
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types

happy, sad, angry, afraid, disgusted, surprised, annoyed, pleased :: String
happy = "happy"; sad = "sad"; angry = "angry"; afraid = "afraid"
disgusted = "disgusted"; surprised = "surprised"
annoyed = "annoyed"; pleased = "pleased"

feelsPath :: String -> String -> String
feelsPath who emotion = who ++ ".feels." ++ emotion

-- | @who@ comes to feel @emotion@ (untargeted).
feel :: String -> String -> Outcome
feel who emotion = Insert (feelsPath who emotion)

-- | @who@ comes to feel @emotion@ toward @target@. Arguments may be action
-- variables, grounded when the outcome runs.
feelToward :: String -> String -> String -> Outcome
feelToward who emotion target =
  Insert (feelsPath who emotion ++ ".toward." ++ target)

-- | Like 'feel', but the feeling EXPIRES @n@ round boundaries after onset (the
-- one lifetime mechanism, 'Prax.Types.InsertFor' — the same 'Prax.Schedule.lasts'
-- gives a schedule rule). Each onset lives its own @n@ rounds from when it
-- fired; re-feeling refreshes the timer, discharging ('unfeel') purges it.
feelFor :: Int -> String -> String -> Outcome
feelFor n who emotion = InsertFor n (feelsPath who emotion)

-- | Like 'feelToward', with an @n@-boundary lifetime (see 'feelFor').
feelTowardFor :: Int -> String -> String -> String -> Outcome
feelTowardFor n who emotion target =
  InsertFor n (feelsPath who emotion ++ ".toward." ++ target)

-- | Discharge: the whole feeling goes, targets included (venting,
-- confronting, being won over — authored at the discharging action).
unfeel :: String -> String -> Outcome
unfeel who emotion = Delete (feelsPath who emotion)

unfeelToward :: String -> String -> String -> Outcome
unfeelToward who emotion target =
  Delete (feelsPath who emotion ++ ".toward." ++ target)

-- | @who@ currently feels @emotion@ — true the instant onset writes ANY
-- instance, targeted or not ('Match' sees subtrees). Since v39
-- ('Prax.Db.retract' prunes unasserted childless nodes; spec
-- @docs/specs/2026-07-15-v39-asserted-endpoints.md@) this correctly falls
-- back to 'False' the moment the last instance is discharged: 'unfeelToward'
-- deletes the targeted @.toward.\<target\>@ leaf, and the now-childless,
-- never-asserted @.toward@ scaffold is pruned rather than left standing, so
-- there is no residue for a subtree 'Match' to read. For PRICING that should
-- scale with how many targets remain, prefer 'feelingToward' with a fresh
-- variable as the target — not for safety (the residue trap is gone) but for
-- its per-target semantics.
feeling :: String -> String -> Condition
feeling who emotion = Match (feelsPath who emotion)

-- | @who@ feels @emotion@ toward @target@ — pass an already-known target for
-- a specific check, or a fresh variable (the caller's own choice of name) to
-- bind it to an ACTUAL remaining target, so a want priced over it counts once
-- per standing grudge (v38's reviewer note: −8 per target is the better
-- semantics than a single presence test over the bare subtree ('feeling')).
-- Since v39 both this and 'feeling' correctly stop matching once every
-- instance is discharged (the drained scaffold is pruned), so the choice
-- between them is about SEMANTICS — per-target pricing versus a single
-- presence test — not about avoiding a residue trap. The recommended shape
-- for any PRICING want over "still feels this, toward whoever".
feelingToward :: String -> String -> String -> Condition
feelingToward who emotion target =
  Match (feelsPath who emotion ++ ".toward." ++ target)
