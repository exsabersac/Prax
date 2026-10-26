module Prax.ArcSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (dbToSentences, exists)
import qualified Data.Map.Strict as Map
import           Prax.Query (Condition (..), satisfies)
import           Prax.Types
import           Prax.Engine (performOutcome, definePractices, possibleActions, performAction, setCharacters)
import           Prax.Arc

run :: [Outcome] -> [String]
run outs = dbToSentences (db (foldl (flip performOutcome) emptyState outs))

tests :: TestTree
tests = testGroup "Prax.Arc"
  [ testCase "arcSentence / arcIs / arcOf build the expected fact" $ do
      arcSentence "bex" "hopeful" @?= "bex.arc!hopeful"
      arcOf "bex" @?= "bex.arc"
      arcIs "bex" "hopeful" @?= Match "bex.arc!hopeful"
      hasArc "bex" @?= Match "bex.arc"
      lacksArc "bex" @?= Not "bex.arc"

  , testCase "enterArc records the stage" $
      assertBool "stage recorded" ("bex.arc.hopeful" `elem` run [ enterArc "bex" "hopeful" ])

  , testCase "entering a new stage overrides the old (single-slot)" $ do
      let fs = run [ enterArc "bex" "hopeful", enterArc "bex" "belonging" ]
      assertBool "new stage" ("bex.arc.belonging" `elem` fs)
      assertBool "old stage gone" (not (any ("arc.hopeful" `isInfixOf`) fs))
  
  , testCase "leaveArc clears the stage" $ do
      let fs = run [ enterArc "bex" "hopeful", leaveArc "bex" ]
      assertBool "gone" (not (any ("bex.arc" `isInfixOf`) fs))

  , testCase "adoptArc Action Not/Insert shape; dotted stage errors" $ do
      let a = adoptArc "belonging" "[Actor]: step into belonging"
      actionName a @?= "[Actor]: step into belonging"
      actionConditions a @?= [ Not "Actor.arc!belonging" ]
      actionOutcomes a @?= [ Insert "Actor.arc!belonging" ]
      r <- try (evaluate (length (show (adoptArc "be.long" "x"))))
      assertBool "dotted stage" (isLeft (r :: Either ErrorCall Int))

  , testCase "adoptArc is an Actor-scoped enter action" $ do
      let p = practice
            { practiceId = "arc"
            , roles = []
            , actions = [ adoptArc "belonging" "[Actor]: step into belonging" ]
            }
          st0 = foldl (flip performOutcome)
                  (setCharacters [character "bex"] (definePractices [p] emptyState))
                  [ Insert "practice.arc", enterArc "bex" "hopeful" ]
          st1 = case filter (("belonging" `isInfixOf`) . gaLabel) (possibleActions st0 "bex") of
                  (ga:_) -> performAction st0 ga
                  [] -> error "no adopt"
      assertBool "new" (exists "bex.arc!belonging" (db st1))
      assertBool "old gone" (not (exists "bex.arc!hopeful" (db st1)))
  , testCase "lacksArcIs is Not of arc stage path" $
      lacksArcIs "ada" "hopeful" @?= Not "ada.arc!hopeful"
  , testCase "everArc / neverArc are Exists/Absent of arc stage" $ do
      everArc "ada" @?= Exists [ Match "ada.arc!Stage" ]
      neverArc "ada" @?= Absent [ Match "ada.arc!Stage" ]

  , testCase "hasArcIs aliases arcIs" $
      hasArcIs "bex" "hopeful" @?= arcIs "bex" "hopeful"


  , testCase "arcIs / hasArc / everArc evaluate on enterArc world" $ do
      assertBool "neverArc on empty"
        (satisfies (db emptyState) [neverArc "bex"] Map.empty)
      assertBool "lacksArc on empty"
        (satisfies (db emptyState) [lacksArc "bex"] Map.empty)
      let st = performOutcome (enterArc "bex" "hopeful") emptyState
      assertBool "arcIs"
        (satisfies (db st) [arcIs "bex" "hopeful"] Map.empty)
      assertBool "hasArcIs"
        (satisfies (db st) [hasArcIs "bex" "hopeful"] Map.empty)
      assertBool "hasArc"
        (satisfies (db st) [hasArc "bex"] Map.empty)
      assertBool "everArc"
        (satisfies (db st) [everArc "bex"] Map.empty)
      assertBool "lacksArcIs fails"
        (not (satisfies (db st) [lacksArcIs "bex" "hopeful"] Map.empty))
      assertBool "neverArc fails"
        (not (satisfies (db st) [neverArc "bex"] Map.empty))
      let gone = performOutcome (leaveArc "bex") st
      assertBool "lacksArc after leave"
        (satisfies (db gone) [lacksArc "bex"] Map.empty)

  ]
