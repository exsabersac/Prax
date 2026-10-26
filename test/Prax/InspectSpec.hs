module Prax.InspectSpec (tests) where

import           Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (assertBool, testCase, (@?=))

import           Prax.Db (Val (..))
import           Prax.Engine (definePractices, performOutcome, setCharacters)
import           Prax.Inspect (explain, explainMatching, firstFailing)
import           Prax.Query (Condition (..))
import           Prax.Sym (intern)
import           Prax.Types

-- Minimal world: wave needs both at yard; bea is the role but not at yard.
waveWorld :: PraxState
waveWorld =
  let p = practice
        { practiceId = "yard", roles = ["R"]
        , actions =
            [ action "[Actor]: wave at [R]"
                [ Match "at.Actor!yard", Match "at.R!yard" ]
                [ Insert "waved.Actor.R" ]
            , action "[Actor]: wait" [] [ Insert "waited.Actor" ]
            ]
        }
      st0 = definePractices [p] emptyState
      st1 = setCharacters [character "ada", character "bea"] st0
  in foldl (flip performOutcome) st1
       [ Insert "practice.yard.bea"
       , Insert "at.ada!yard"
       ]

tests :: TestTree
tests = testGroup "Prax.Inspect"
  [ testCase "firstFailing is Nothing on an empty conjunction" $
      firstFailing (db waveWorld) [] Map.empty @?= Nothing

  , testCase "firstFailing names the leftmost failing conjunct" $ do
      let conds = [ Match "at.Actor!yard", Match "at.R!yard" ]
          b = Map.fromList
            [ (intern "Actor", VSym (intern "ada"))
            , (intern "R", VSym (intern "bea"))
            ]
      firstFailing (db waveWorld) conds b @?= Just (Match "at.R!yard")

  , testCase "explain reports AVAILABLE vs blocked-by for needle matches" $ do
      let wave = explain waveWorld "ada" "wave"
          wait = explain waveWorld "ada" "wait"
      assertBool "wave blocked" (any ("blocked by" `isInfixOf`) wave)
      assertBool "wait available" (any ("AVAILABLE" `isInfixOf`) wait)

  , testCase "explainMatching filters explain lines by needle" $ do
      explainMatching waveWorld "ada" "wave" "___nomatch___" @?= []
      let kept = explainMatching waveWorld "ada" "wave" "blocked"
      assertBool "kept blocked lines" (not (null kept))
  ]
