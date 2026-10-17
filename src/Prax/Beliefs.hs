-- | 信念（Versu 论文 §X）。
--
-- Versu 保持单一共享世界状态，仅对 agent 观点可能与真相分歧的特定议题存储 /个体/ 信念——用于
-- 「错误信念，或事实分歧。」本模块是那些按议题信念的可复用约定，建于既有引擎之上（无新机制）：
-- 信念只是相信者之下的事实。
--
--   @X.believes.\<issue\>!Value@
--
-- 信念按议题单槽（经纠正后的 @!@）：议题的新值覆盖旧值。因为信念住在 agent 下，两个 agent 可对
-- 同一议题持有不同值（分歧），且任一方可相对应共享世界事实不同（错误信念）。
--
-- 注：这建模显式按议题信念，非论文未构建的量化/嵌套信念（LEDGER #28）。也没有单一
-- 「相信 X，否则回退到世界」查询运算符——那需要析取（LEDGER #7）；改为创作两个带条件的动作。
module Prax.Beliefs
  ( beliefSentence
  , beliefAbout
  , believe
  , believesThat
  , forget
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..))

-- | 句子 @who.believes.\<issue\>!value@。@issue@ 可以是点分路径（多段议题）。
beliefSentence :: String -> String -> String -> String
beliefSentence who issue value = who ++ ".believes." ++ issue ++ "!" ++ value

-- | 路径 @who.believes.\<issue\>@，用于绑定所信的值。
beliefAbout :: String -> String -> String
beliefAbout who issue = who ++ ".believes." ++ issue

-- | @who@ 开始相信 @issue@ 的值为 @value@（覆盖任何先前值）。
believe :: String -> String -> String -> Outcome
believe who issue value = Insert (beliefSentence who issue value)

-- | 条件：@who@ 相信 @issue@ 为 @value@。
believesThat :: String -> String -> String -> Condition
believesThat who issue value = Match (beliefSentence who issue value)

-- | @who@ 丢掉关于 @issue@ 的任何信念。
forget :: String -> String -> Outcome
forget who issue = Delete (beliefAbout who issue)
