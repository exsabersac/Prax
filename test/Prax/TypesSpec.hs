{-# LANGUAGE ScopedTypeVariables #-}
module Prax.TypesSpec (tests) where

import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (assertBool, testCase, (@?=))

import           Prax.Db (exists)
import           Prax.Engine (performOutcome, setCharacters)
import           Prax.Query (Condition (..))
import           Prax.Types

tests :: TestTree
tests = testGroup "Prax.Types"
  [ testGroup "path / death helpers"
    [ testCase "turnPath is the clock root" $
        turnPath @?= "turn"

    , testCase "deadSentence prefixes dead." $
        deadSentence "beth" @?= "dead.beth"

    , testCase "livingCharacters drops dead-marked cast" $ do
        let st0 = setCharacters [character "ana", character "bob"] emptyState
            st1 = performOutcome (Insert (deadSentence "bob")) st0
        map charName (livingCharacters st0) @?= ["ana", "bob"]
        map charName (livingCharacters st1) @?= ["ana"]
    ]

  , testGroup "isPraxVar / authoredPatClash"
    [ testCase "isPraxVar matches Prax* prefixes only" $ do
        assertBool "PraxFoo" (isPraxVar "PraxFoo")
        assertBool "PraxX" (isPraxVar "PraxX")
        assertBool "Actor not Prax" (not (isPraxVar "Actor"))
        assertBool "plain" (not (isPraxVar "plain"))
        assertBool "empty" (not (isPraxVar ""))

    , testCase "authoredPatClash flags Prax vars and forbidden splices" $ do
        authoredPatClash ["Actor"] ["deed", "Actor", "PraxX"]
          @?= ["Actor", "PraxX"]
        authoredPatClash [] ["ok", "fine"] @?= []
    ]

  , testGroup "outcomeVars / outcomeSents"
    [ testCase "outcomeVars walks Insert/Delete/InsertFor/Call/ForEach/Roll" $ do
        outcomeVars (Insert "a.X") @?= ["a", "X"]
        outcomeVars (Delete "b.Y") @?= ["b", "Y"]
        outcomeVars (InsertFor 2 "c.Z") @?= ["c", "Z"]
        outcomeVars (Call "f" ["P", "Q"]) @?= ["P", "Q"]
        outcomeVars (ForEach [Match "at.Who!here"] [Insert "saw.Who"])
          @?= ["at", "Who", "here", "saw", "Who"]
        outcomeVars (Roll 1 2 [Match "ok.X"] [Delete "gone.X"])
          @?= ["ok", "X", "gone", "X"]

    , testCase "outcomeSents collects sentence strings; Call skipped" $ do
        outcomeSents [Insert "a.x", Delete "b.y", InsertFor 1 "c.z", Call "f" ["P"]]
          @?= ["a.x", "b.y", "c.z"]
        outcomeSents [ForEach [Match "g.X"] [Insert "h.X", Call "g" ["X"]]]
          @?= ["g.X", "h.X"]
    ]

  , testGroup "emptyState clock seed"
    [ testCase "emptyState seeds turn!0" $
        assertBool "turn!0 present" (exists "turn!0" (db emptyState))
    ]
  ]
