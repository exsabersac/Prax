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
  , onTopic
  , offTopic
  , isSpeaker
  , isListener
  , hasChattedWith
  , neverChattedWith
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..), Action, action)

-- | @x@ 与 @y@ 之间对话实例的路径（规范化序，使双向同一槽）。
talkPath :: String -> String -> String
talkPath x y = "practice.converse." ++ x ++ "." ++ y

-- | 条件：@x@ 与 @y@ 正在交谈（此序）。
talkingWith :: String -> String -> Condition
talkingWith x y = Match (talkPath x y)

-- | 打开对话的结果：@opener@ 成为说话者，话题设为所给主题。
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

-- | 一句 quip：当前说话者可说一次的台词，说完后换边。
quip :: String -> String -> String -> [Condition] -> [Outcome] -> Action
quip key label topic conds effects =
  action label
    (speakerConds
      ++ [ Match (convP ++ ".topic!" ++ topic)
         , Not (convP ++ ".said." ++ key ++ ".Actor") ]
      ++ conds)
    ([ Insert (convP ++ ".said." ++ key ++ ".Actor") ] ++ effects ++ passTurn)

-- | 把对话舵向 @newTopic@（仅当尚无人在该话题上）。
changeSubject :: String -> String -> Action
changeSubject label newTopic =
  action label
    (speakerConds
      ++ [ Not (convP ++ ".topic!" ++ newTopic)
         , Not (convP ++ ".visited." ++ newTopic) ])
    ([ Insert (convP ++ ".topic!" ++ newTopic)
     , Insert (convP ++ ".visited." ++ newTopic) ] ++ passTurn)

-- | 结束对话（移除实例）。
endConversation :: String -> Action
endConversation label =
  action label speakerConds [ Delete convP ]

-- | 条件：当前对话话题为 @topic@（在 converse.A.B 实例内）。
onTopic :: String -> Condition
onTopic topic = Match (convP ++ ".topic!" ++ topic)

-- | 条件：Actor 现为说话者。
isSpeaker :: Condition
isSpeaker = Match (convP ++ ".speaker!Actor")

-- | 条件：Actor 现为听者（说话者对偶）。
isListener :: Condition
isListener = Match (convP ++ ".listener!Actor")

-- | 条件：当前对话话题不是 @topic@（@onTopic@ 的 Not 对偶）。
offTopic :: String -> Condition
offTopic topic = Not (convP ++ ".topic!" ++ topic)

-- | 条件：@who@ 曾与 @other@ 聊过（@chattedWith@ 叶）。
hasChattedWith :: String -> String -> Condition
hasChattedWith who other = Match (who ++ ".chattedWith." ++ other)

-- | 条件：@who@ 从未与 @other@ 聊过。
neverChattedWith :: String -> String -> Condition
neverChattedWith who other = Not (who ++ ".chattedWith." ++ other)
