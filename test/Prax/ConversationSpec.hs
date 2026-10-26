module Prax.ConversationSpec (tests) where

import           Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, assertFailure, (@?=))

import           Prax.Db (dbToSentences, Val (..))
import           Prax.Sym (intern)
import           Prax.Query (Condition (..), satisfies)
import           Prax.Types
import           Prax.Engine (definePractice, performOutcome, possibleActions, performAction)
import           Prax.Conversation

-- A minimal conversation practice for testing the scaffolding.
talkP :: Practice
talkP = practice
  { practiceId = "converse"
  , practiceName = "[A] and [B] are talking"
  , roles = ["A", "B"]
  , actions =
      [ quip "hi" "[Actor]: say hi to [Partner]" "greetings" []
          [ Insert "Actor.saidHiTo.Partner" ]
      , quip "weather" "[Actor]: remark on the weather to [Partner]" "weather" []
          [ Insert "Actor.talkedWeatherWith.Partner" ]
      , changeSubject "[Actor]: change the subject to the weather" "weather"
      , endConversation "[Actor]: wrap up the chat"
      ]
  }

base :: PraxState
base = definePractice talkP emptyState

start :: PraxState
start = foldl (flip performOutcome) base (beginConversation "ada" "bex" "greetings")

opts :: PraxState -> String -> [String]
opts st a = map gaLabel (possibleActions st a)

perform :: PraxState -> String -> String -> IO PraxState
perform st actor needle =
  case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st actor) of
    (ga : _) -> pure (performAction st ga)
    []       -> assertFailure ("no " ++ show needle ++ " for " ++ actor
                               ++ "; had: " ++ show (opts st actor)) >> pure st

tests :: TestTree
tests = testGroup "Prax.Conversation"
  [ testCase "beginConversation sets speaker, listener and topic" $ do
      let fs = dbToSentences (db start)
      assertBool "speaker is ada" ("practice.converse.ada.bex.speaker.ada" `elem` fs)
      assertBool "listener is bex" ("practice.converse.ada.bex.listener.bex" `elem` fs)
      assertBool "topic is greetings" ("practice.converse.ada.bex.topic.greetings" `elem` fs)

  , testCase "only the current speaker may quip, and only on the current topic" $ do
      assertBool "speaker can say hi" (any ("say hi to bex" `isInfixOf`) (opts start "ada"))
      assertBool "listener cannot quip"
        (not (any (`isInfixOf'` opts start "bex") ["say hi", "remark on the weather"]))
      -- the weather quip is off-topic (topic is greetings), so not offered
      assertBool "off-topic quip withheld"
        (not (any ("remark on the weather" `isInfixOf`) (opts start "ada")))

  , testCase "a quip applies its effect, is one-shot, and passes the turn" $ do
      st <- perform start "ada" "say hi to bex"
      let fs = dbToSentences (db st)
      assertBool "effect applied" ("ada.saidHiTo.bex" `elem` fs)
      assertBool "turn passed to bex" ("practice.converse.ada.bex.speaker.bex" `elem` fs)
      -- ada is no longer speaker, so cannot immediately say hi again
      assertBool "ada cannot quip out of turn"
        (not (any ("say hi" `isInfixOf`) (opts st "ada")))

  , testCase "changing the subject switches the active topic" $ do
      -- ada says hi; turn passes to bex; bex steers to the weather.
      st1 <- perform start "ada" "say hi to bex"
      st2 <- perform st1 "bex" "change the subject to the weather"
      let fs = dbToSentences (db st2)
      assertBool "topic is now weather" ("practice.converse.ada.bex.topic.weather" `elem` fs)
      -- now the speaker (ada again) can make the weather quip
      assertBool "on-topic weather quip offered"
        (any ("remark on the weather" `isInfixOf`) (opts st2 "ada"))

  , testCase "ending the conversation removes the instance" $ do
      st <- perform start "ada" "wrap up the chat"
      assertBool "conversation gone"
        ("practice.converse.ada.bex" `notElem` dbToSentences (db st))

  , testCase "onTopic / isSpeaker are the converse instance gates" $ do
      onTopic "greetings" @?= Match "practice.converse.A.B.topic!greetings"
      isSpeaker @?= Match "practice.converse.A.B.speaker!Actor"

  , testCase "isListener is the listener exclusive leaf" $
      isListener @?= Match "practice.converse.A.B.listener!Actor"
  , testCase "lacksSpeaker / lacksListener are Not duals" $ do
      lacksSpeaker @?= Not "practice.converse.A.B.speaker!Actor"
      lacksListener @?= Not "practice.converse.A.B.listener!Actor"

  , testCase "lacksChattedWith / everChatted / neverChatted" $ do
      lacksChattedWith "ada" "bex" @?= Not "ada.chattedWith.bex"
      lacksChattedWith "ada" "bex" @?= neverChattedWith "ada" "bex"
      everChatted "ada" @?= Exists [ Match "ada.chattedWith.Other" ]
      neverChatted "ada" @?= Absent [ Match "ada.chattedWith.Other" ]

  , testCase "offTopic / lacksTopic / hasChattedWith / neverChattedWith duals" $ do
      offTopic "greetings" @?= Not "practice.converse.A.B.topic!greetings"
      lacksTopic "greetings" @?= offTopic "greetings"
      hasChattedWith "ada" "bex" @?= Match "ada.chattedWith.bex"
      neverChattedWith "ada" "bex" @?= Not "ada.chattedWith.bex"

  , testCase "everChattedWith aliases hasChattedWith" $
      everChattedWith "ada" "bex" @?= hasChattedWith "ada" "bex"

  , testCase "hasSpeaker / hasListener / hasTopic aliases" $ do
      hasSpeaker @?= isSpeaker
      hasListener @?= isListener
      hasTopic "greetings" @?= onTopic "greetings"

  , testCase "hasChattedWith / everChatted evaluate on Insert world" $ do
      assertBool "neverChatted on empty"
        (satisfies (db emptyState) [neverChatted "ada"] Map.empty)
      assertBool "lacksChattedWith on empty"
        (satisfies (db emptyState) [lacksChattedWith "ada" "bex"] Map.empty)
      let st = performOutcome (Insert "ada.chattedWith.bex") emptyState
      assertBool "hasChattedWith"
        (satisfies (db st) [hasChattedWith "ada" "bex"] Map.empty)
      assertBool "everChattedWith"
        (satisfies (db st) [everChattedWith "ada" "bex"] Map.empty)
      assertBool "everChatted"
        (satisfies (db st) [everChatted "ada"] Map.empty)
      assertBool "neverChatted fails"
        (not (satisfies (db st) [neverChatted "ada"] Map.empty))
      assertBool "neverChattedWith fails"
        (not (satisfies (db st) [neverChattedWith "ada" "bex"] Map.empty))


  , testCase "hasTalkingWith aliases talkingWith" $
      hasTalkingWith "ada" "bex" @?= talkingWith "ada" "bex"
  , testCase "lacksTalkingWith is Not of talkPath" $
      lacksTalkingWith "ada" "bex" @?= Not "practice.converse.ada.bex"

  , testCase "talkingWith evaluates on beginConversation world" $ do
      assertBool "talkingWith"
        (satisfies (db start) [talkingWith "ada" "bex"] Map.empty)
      assertBool "hasTalkingWith"
        (satisfies (db start) [hasTalkingWith "ada" "bex"] Map.empty)
      assertBool "lacksTalkingWith fails"
        (not (satisfies (db start) [lacksTalkingWith "ada" "bex"] Map.empty))
      assertBool "lacksTalkingWith on empty"
        (satisfies (db emptyState) [lacksTalkingWith "ada" "bex"] Map.empty)
      assertBool "talkingWith reverse order absent as different path"
        (not (satisfies (db start) [talkingWith "bex" "ada"] Map.empty))

  , testCase "onTopic / isSpeaker / isListener evaluate on beginConversation world" $ do
      let b = Map.fromList
            [ (intern "A", VSym (intern "ada"))
            , (intern "B", VSym (intern "bex"))
            , (intern "Actor", VSym (intern "ada"))
            ]
      assertBool "onTopic"
        (satisfies (db start) [onTopic "greetings"] b)
      assertBool "hasTopic"
        (satisfies (db start) [hasTopic "greetings"] b)
      assertBool "isSpeaker"
        (satisfies (db start) [isSpeaker] b)
      assertBool "hasSpeaker"
        (satisfies (db start) [hasSpeaker] b)
      assertBool "isListener fails for speaker Actor"
        (not (satisfies (db start) [isListener] b))
      let bListen = Map.insert (intern "Actor") (VSym (intern "bex")) b
      assertBool "isListener"
        (satisfies (db start) [isListener] bListen)
      assertBool "hasListener"
        (satisfies (db start) [hasListener] bListen)
      assertBool "offTopic weather"
        (satisfies (db start) [offTopic "weather"] b)
      assertBool "lacksTopic weather"
        (satisfies (db start) [lacksTopic "weather"] b)
      assertBool "lacksTopic greetings fails"
        (not (satisfies (db start) [lacksTopic "greetings"] b))
      assertBool "lacksSpeaker fails for speaker"
        (not (satisfies (db start) [lacksSpeaker] b))
      assertBool "lacksListener fails for listener"
        (not (satisfies (db start) [lacksListener] bListen))

  ]

-- helper: does any needle appear in the list of strings?
isInfixOf' :: String -> [String] -> Bool
isInfixOf' needle = any (needle `isInfixOf`)