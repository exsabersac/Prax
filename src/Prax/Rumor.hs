-- | 谣言传播：告知你所持证据。
--
-- 配合目击（"Prax.Witness"）闭合信息环：在人们面前发生的事传出他们之外。告知在听者中以
-- __传闻出处__ 种植同一事件信念——@\<hearer\>.believes.\<event\>.heard.\<teller\>@，
-- 每告知者一边，旁于任何 @.seen@ 边——因此证据累积（佐证可计数），目击记录永不被覆盖。
--
-- 像可观察性一样，__什么可告知是创作的__：'gossip' 按事件模式声明一个告知动作（通用
-- 「分享任何信念」本不可能——查询变量绑定单路径段）。传播是 want 驱动：创作想要他人知道的角色，
-- 普通 planner 携带消息。
-- v75：'gossipPublic' 一对多告知。
module Prax.Rumor
  ( gossip
  , gossipPublic
  , heard
  , heardFrom
  , neverHeard
  , lacksHeardFrom
  , everHeard
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), action, authoredVarClash, authoredPatClash)
import           Prax.Beliefs (beliefAbout)
import           Prax.Witness (CoPresence, asRole)

-- | 一个动作：把你持有证据的事件告诉同场听者。世界可经额外条件加门（如不信任门）。
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

-- | 公开八卦：同场所有听者各得一条 @.heard.Actor@（镜像 confessPublic 的 ForEach）。
-- @gate@ 仍按每名听者检查；无单一 Hearer 绑定。
gossipPublic :: CoPresence -> [Condition] -> String -> String -> Action
gossipPublic copresence gate pat label
  | (v : _) <- offenders =
      error ("Prax.Rumor.gossipPublic: " ++ show v ++ " in an authored gate or event"
             ++ " pattern -- the Prax namespace is reserved for machinery")
  | otherwise = action label
      ([ Match (beliefAbout "Actor" pat) ] ++ gate)
      [ ForEach (asRole "Hearer" copresence
                 ++ [ Neq "Hearer" "Actor"
                    , Neq "Hearer" subject
                    , Absent [ Match (beliefAbout "Hearer" pat ++ ".seen") ]
                    , Not (beliefAbout "Hearer" pat ++ ".heard.Actor") ])
          [ Insert (beliefAbout "Hearer" pat ++ ".heard.Actor") ] ]
  where
    offenders = authoredVarClash [] gate [] ++ authoredPatClash [] (pathNames pat)
    subject = case filter isVariable (pathNames pat) of
      (v : _) -> v
      []      -> error ("gossipPublic: event pattern " ++ show pat
                        ++ " names no one (a rumor is about someone)")

-- | 条件：@who@ 对 @event@ 有传闻证据（来自任何人）。该子树上的布尔 `Exists`。
heard :: String -> String -> Condition
heard who event = Exists [ Match (beliefAbout who event ++ ".heard.Src") ]

-- | 条件：@who@ 从特定 @source@ 听说 @event@。
heardFrom :: String -> String -> String -> Condition
heardFrom who source event =
  Match (beliefAbout who event ++ ".heard." ++ source)

-- | 条件：@who@ 从未经传闻得知 @event@（无任一 @.heard.*@ 叶）。
neverHeard :: String -> String -> Condition
neverHeard who event = Absent [ Match (beliefAbout who event ++ ".heard.Src") ]

-- | 条件：@who@ 曾从任一来源听过 @event@（存在 `.heard.Src` 叶）。
everHeard :: String -> String -> Condition
everHeard who event = Match (beliefAbout who event ++ ".heard.Src")

-- | 条件：@who@ 未从特定 @source@ 听说 @event@（@heardFrom@ 的 Not 对偶）。
lacksHeardFrom :: String -> String -> String -> Condition
lacksHeardFrom who source event =
  Not (beliefAbout who event ++ ".heard." ++ source)
