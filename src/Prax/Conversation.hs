-- | 对话：说话者、话题与 quips（Versu 论文 §X；Emily Short 关于 Versu 对话的博客）。
--
-- 对话是带 /选定说话者/（轮流）与单一当前 /话题/ 的两方实践。**quip** 是说一行并应用效果的
-- 普通动作——对核心模型与信念——正是 "Prax.Core" 与 "Prax.Beliefs" 的机制；「响应只是普通类型的
-- 动作…同一效用 planner。」角色保持话题（quip 仅在其话题上可用），直到有人有意改变主题。
--
-- 既有引擎上的可复用库（无新机制）：对话是带 @speaker!@、@listener!@、@topic!@ 事实的
-- @practice.converse.\<A\>.\<B\>@。世界经 'quip' / 'changeSubject' / 'endConversation' 构建器
-- 在角色为 @["A","B"]@ 的实践内提供具体 quips。
module Prax.Conversation
  ( talkPath
  , talkingWith
  , beginConversation
  , quip
  , changeSubject
  , endConversation
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..), Action, action)

-- | Path of a conversation instance between @x@ and @y@ (in this order).
talkPath :: String -> String -> String
talkPath x y = "practice.converse." ++ x ++ "." ++ y

-- | Condition: @x@ and @y@ are conversing (this ordering).
talkingWith :: String -> String -> Condition
talkingWith x y = Match (talkPath x y)

-- | Outcomes that open a conversation: @opener@ becomes the first speaker,
-- @other@ the listener, starting on @topic@. Records @topic@ as visited and
-- marks the pair as having chatted (so a world can prevent re-opening).
beginConversation :: String -> String -> String -> [Outcome]
beginConversation opener other topic =
  [ Insert base
  , Insert (base ++ ".speaker!" ++ opener)
  , Insert (base ++ ".listener!" ++ other)
  , Insert (base ++ ".topic!" ++ topic)
  , Insert (base ++ ".visited." ++ topic)
  , Insert (opener ++ ".chattedWith." ++ other)
  , Insert (other ++ ".chattedWith." ++ opener)
  ]
  where base = talkPath opener other

-- Within-practice actions reference the instance by its role variables A and B.
convP :: String
convP = "practice.converse.A.B"

-- The current speaker is the actor; bind the listener as Partner.
speakerConds :: [Condition]
speakerConds =
  [ Match (convP ++ ".speaker!Actor")
  , Match (convP ++ ".listener!Partner")
  ]

-- Hand the floor to the other party.
passTurn :: [Outcome]
passTurn =
  [ Insert (convP ++ ".speaker!Partner")
  , Insert (convP ++ ".listener!Actor")
  ]

-- | A quip: a line the current speaker can say once, on the given @topic@, with
-- @effects@ (and any extra @conds@). Saying it passes the turn.
--
-- @key@ is a short unique tag used to record that this quip has been said (so it
-- is one-shot per speaker); @label@ is the displayed line template.
quip :: String -> String -> String -> [Condition] -> [Outcome] -> Action
quip key label topic conds effects =
  action label
    (speakerConds
      ++ [ Match (convP ++ ".topic!" ++ topic)
         , Not (convP ++ ".said." ++ key ++ ".Actor") ]
      ++ conds)
    ([ Insert (convP ++ ".said." ++ key ++ ".Actor") ] ++ effects ++ passTurn)

-- | Steer the conversation onto @newTopic@ (only if not already there and not
-- already covered). Passes the turn.
changeSubject :: String -> String -> Action
changeSubject label newTopic =
  action label
    (speakerConds
      ++ [ Not (convP ++ ".topic!" ++ newTopic)
         , Not (convP ++ ".visited." ++ newTopic) ])
    ([ Insert (convP ++ ".topic!" ++ newTopic)
     , Insert (convP ++ ".visited." ++ newTopic) ] ++ passTurn)

-- | End the conversation (removes the instance).
endConversation :: String -> Action
endConversation label =
  action label speakerConds [ Delete convP ]
