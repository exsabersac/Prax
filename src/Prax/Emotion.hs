-- | 共存的情节情感（规格 2026-07-15-v38），替换 Versu 继承的单槽情绪：
-- @\<who\>.feels.\<emotion\>@ 与 @\<who\>.feels.\<emotion\>.toward.\<target\>@ 是普通多值
-- 事实——对两人愤怒同时惧怕第三人全部共存，各自独立。不变量（用户，承重）：情感改变
-- 决策制定，从不改变哪些决策可被做出——此处无物触及动作可用性；定价是读这些事实的普通欲望，
-- 按世界创作。创作指引：偏好负定价（情感作为驱动自身解除的不适）——心理正确，且 v33 的
-- FloorCheck 保持未感状态免规划，而正定价情感可被动作插入因而 AlwaysLive（允许；代价即代价）。
-- 起始在触发动机处创作（'Prax.Rng.draw' 片段）；消退是起始上的创作寿命——'feelFor'\/'feelTowardFor'
-- 经引擎到期队列断言（规格 @docs/specs/2026-07-16-v44-the-schedule.md@），因此每个情感从自身起始
-- 存活自己的 @n@ 回合（v36 情节原则，无同步清扫）。情感是情节性的：它们消退；气质（特质、标记）
-- 从不——特质使情感更可能，而非更久。 对他心可见（v59）：'express'/'expressToward' 经普通目击通道把当前感受存为同场者的 `.seen` 信念——自愿出示，非自动广播。 强度（v60）：'feelAt'/'feelTowardAt' 在感受下挂排他 @intensity!N@ 叶；'intensityAtLeast' 供定价门禁——仍不收缩其他实践决策空间。
module Prax.Emotion
  ( -- * An Ekman-based vocabulary (moved from Prax.Core; plain names)
    happy, sad, angry, afraid, disgusted, surprised, annoyed, pleased
    -- * Feeling and unfeeling (Outcomes)
  , feel, feelToward, unfeel, unfeelToward
    -- * Feeling with a lifetime (fades on its own onset's clock)
  , feelFor, feelTowardFor
    -- * Reading feelings (Conditions)
  , feeling, feelingToward
    -- * Making feelings visible to co-present others (ordinary .seen beliefs)
  , express, expressToward
    -- * Intensity (exclusive leaf under the feeling)
  , feelAt, feelTowardAt, intensityAtLeast, intensityTowardAtLeast
  ) where

import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Types
import           Prax.Witness (CoPresence, witnessed)

happy, sad, angry, afraid, disgusted, surprised, annoyed, pleased :: String
happy = "happy"; sad = "sad"; angry = "angry"; afraid = "afraid"
disgusted = "disgusted"; surprised = "surprised"
annoyed = "annoyed"; pleased = "pleased"

feelsPath :: String -> String -> String
feelsPath who emotion = who ++ ".feels." ++ emotion

-- | @who@ 开始感到 @emotion@（无目标）。
feel :: String -> String -> Outcome
feel who emotion = Insert (feelsPath who emotion)

-- | @who@ 开始对 @target@ 感到 @emotion@。
feelToward :: String -> String -> String -> Outcome
feelToward who emotion target =
  Insert (feelsPath who emotion ++ ".toward." ++ target)

-- | 类似 'feel'，但情感在 @n@ 个回合边界后到期（经 'InsertFor'）。
feelFor :: Int -> String -> String -> Outcome
feelFor n who emotion = InsertFor n (feelsPath who emotion)

-- | 类似 'feelToward'，带 @n@ 边界寿命。
feelTowardFor :: Int -> String -> String -> String -> Outcome
feelTowardFor n who emotion target =
  InsertFor n (feelsPath who emotion ++ ".toward." ++ target)

-- | 释放：整段情感消失，目标一并清除。
unfeel :: String -> String -> Outcome
unfeel who emotion = Delete (feelsPath who emotion)

unfeelToward :: String -> String -> String -> Outcome
unfeelToward who emotion target =
  Delete (feelsPath who emotion ++ ".toward." ++ target)

-- | @who@ 当前感到 @emotion@——一旦感到即为真（无目标或有目标皆可）。
feeling :: String -> String -> Condition
feeling who emotion = Match (feelsPath who emotion)

-- | @who@ 对 @target@ 感到 @emotion@。
feelingToward :: String -> String -> String -> Condition
feelingToward who emotion target =
  Match (feelsPath who emotion ++ ".toward." ++ target)

-- | Single path-segment guard (emotion tokens must not contain @.@ / @!@).
segOk :: String -> Bool
segOk n = not (null n) && all (`notElem` (".!" :: String)) n

-- | Actor makes a current untargeted feeling visible: every co-present other
-- comes to believe @Actor.feels.<emotion>@ via the ordinary @.seen@ channel
-- ('Prax.Witness.witnessed'). The affordance is offered only while the feeling
-- holds — that ADDS a communicative option; it does not remove unrelated
-- affordances (the module invariant: feelings never shrink the decision space
-- of other practices).
express :: CoPresence -> String -> String -> Action
express copresence emotion label
  | not (segOk emotion) =
      error ("express: emotion " ++ show emotion ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("Actor.feels." ++ emotion) ]
      [ witnessed copresence ("Actor.feels." ++ emotion) ]

-- | Same for a targeted feeling; binds @Target@ from the feeling fact itself.
expressToward :: CoPresence -> String -> String -> Action
expressToward copresence emotion label
  | not (segOk emotion) =
      error ("expressToward: emotion " ++ show emotion ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("Actor.feels." ++ emotion ++ ".toward.Target") ]
      [ witnessed copresence ("Actor.feels." ++ emotion ++ ".toward.Target") ]

-- | Begin feeling @emotion@ at intensity @n@ (@n >= 1@). Intensity is an
-- exclusive leaf under the feeling path; 'unfeel' clears it with the feeling.
feelAt :: Int -> String -> String -> [Outcome]
feelAt n who emotion
  | n < 1 = error ("feelAt: intensity " ++ show n ++ " must be >= 1")
  | not (segOk emotion) =
      error ("feelAt: emotion " ++ show emotion ++ " must be a single path segment")
  | otherwise =
      [ feel who emotion
      , Insert (feelsPath who emotion ++ ".intensity!" ++ show n) ]

-- | Targeted feeling at intensity @n@.
feelTowardAt :: Int -> String -> String -> String -> [Outcome]
feelTowardAt n who emotion target
  | n < 1 = error ("feelTowardAt: intensity " ++ show n ++ " must be >= 1")
  | not (segOk emotion) =
      error ("feelTowardAt: emotion " ++ show emotion ++ " must be a single path segment")
  | otherwise =
      [ feelToward who emotion target
      , Insert (feelsPath who emotion ++ ".toward." ++ target ++ ".intensity!" ++ show n) ]

-- | Gate: @who@ feels @emotion@ at intensity at least @n@.
intensityAtLeast :: String -> String -> Int -> [Condition]
intensityAtLeast who emotion n =
  [ Match (feelsPath who emotion ++ ".intensity!FeelIntensity")
  , Cmp Gte "FeelIntensity" (show n) ]

-- | Gate: targeted feeling at intensity at least @n@.
intensityTowardAtLeast :: String -> String -> String -> Int -> [Condition]
intensityTowardAtLeast who emotion target n =
  [ Match (feelsPath who emotion ++ ".toward." ++ target ++ ".intensity!FeelIntensity")
  , Cmp Gte "FeelIntensity" (show n) ]

