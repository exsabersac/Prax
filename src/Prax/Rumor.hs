-- | 谣言传播：告知你所持证据。
--
-- 配合目击（"Prax.Witness"）闭合信息环：在人们面前发生的事传出他们之外。告知在听者中以
-- __传闻出处__ 种植同一事件信念——@\<hearer\>.believes.\<event\>.heard.\<teller\>@，
-- 每告知者一边，旁于任何 @.seen@ 边——因此证据累积（佐证可计数），目击记录永不被覆盖。
--
-- 像可观察性一样，__什么可告知是创作的__：'gossip' 按事件模式声明一个告知动作（通用
-- 「分享任何信念」本不可能——查询变量绑定单路径段）。传播是 want 驱动：创作想要他人知道的角色，
-- 普通 planner 携带消息。
module Prax.Rumor
  ( gossip
  , heard
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), action, authoredVarClash, authoredPatClash)
import           Prax.Beliefs (beliefAbout)
import           Prax.Witness (CoPresence, asRole)

-- | An action: tell a co-present hearer about an event you have evidence for.
--
-- The event pattern may use variables (e.g. @\"stole.Culprit.Item\"@); its
-- __first__ variable is the rumor's subject, who is never offered as a hearer
-- (you don't tell bob about bob's theft). Also never offered: the teller
-- themself, an eyewitness (no news value), and anyone this teller has already
-- told (@.heard.\<teller\>@ doubles as the one-shot marker). The world adds its
-- own gate (e.g. "not someone you distrust") and its 'CoPresence' template —
-- written over @Witness@, retargeted at the @Hearer@ via 'Prax.Witness.asRole'.
--
-- The evidence condition is a /prefix/ match on @believes.\<event\>@: the node
-- exists iff some provenance edge sits beneath it, and matching the prefix
-- binds the pattern's variables exactly once per known event no matter how
-- many provenance edges there are — no duplicate tells for a teller who both
-- saw and heard. The event pattern's namespace must not overlap any valued-belief
-- issue path in the same world — 'Witness' and gossip deposits must be the only
-- writers under the pattern's @believes.@ prefix.
gossip :: CoPresence -> [Condition] -> String -> String -> Action
gossip copresence gate pat label
  | (v : _) <- offenders =
      error ("Prax.Rumor.gossip: " ++ show v ++ " in an authored gate or event"
             ++ " pattern -- the Prax namespace is reserved for machinery")
  | otherwise = action label conds [ Insert (beliefAbout "Hearer" pat ++ ".heard.Actor") ]
  where
    offenders = authoredVarClash [] gate [] ++ authoredPatClash [] (pathNames pat)
    subject = case filter isVariable (pathNames pat) of
      (v : _) -> v
      []      -> error ("gossip: event pattern " ++ show pat
                        ++ " names no one (a rumor is about someone)")
    conds =
      [ Match (beliefAbout "Actor" pat) ]   -- any evidence; binds the pattern's variables
      ++ asRole "Hearer" copresence
      ++ [ Neq "Hearer" "Actor"
         , Neq "Hearer" subject
         , Absent [ Match (beliefAbout "Hearer" pat ++ ".seen") ]
         , Not (beliefAbout "Hearer" pat ++ ".heard.Actor") ]
      ++ gate

-- | Condition: @who@ has hearsay evidence of @event@ (from anyone). A boolean
-- ∃, so multiple sources yield one row — corroboration never duplicates an
-- affordance.
heard :: String -> String -> Condition
heard who event = Exists [ Match (beliefAbout who event ++ ".heard.Src") ]
