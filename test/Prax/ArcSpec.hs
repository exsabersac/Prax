module Prax.ArcSpec (tests) where

import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (dbToSentences, exists)
import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (performOutcome, definePractices, possibleActions, performAction, setCharacters)
import           Prax.Arc

run :: [Outcome] -> [String]
run outs = dbToSentences (db (foldl (flip performOutcome) emptyState outs))

tests :: TestTree
tests = testGroup "Prax.Arc"
  [ testCase "arcSentence / arcIs build the expected fact" $ do
      arcSentence "bex" "hopeful" @?= "bex.arc!hopeful"
      arcIs "bex" "hopeful" @?= Match "bex.arc!hopeful"

  , testCase "enterArc records the stage" $
      assertBool "stage recorded" ("bex.arc.hopeful" `elem` run [ enterArc "bex" "hopeful" ])

  , testCase "entering a new stage overrides the old (single-slot)" $ do
      let fs = run [ enterArc "bex" "hopeful", enterArc "bex" "belonging" ]
      assertBool "new stage" ("bex.arc.belonging" `elem` fs)
      assertBool "old stage gone" (not (any ("arc.hopeful" `isInfixOf`) fs))
  
  , testCase "leaveArc clears the stage" $ do
      let fs = run [ enterArc "bex" "hopeful", leaveArc "bex" ]
      assertBool "gone" (not (any ("bex.arc" `isInfixOf`) fs))

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
  ]
