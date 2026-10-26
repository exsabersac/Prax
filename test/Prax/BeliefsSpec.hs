module Prax.BeliefsSpec (tests) where

import           Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (Db, dbToSentences, emptyDb, insertAll, valToString)
import           Prax.Query (Condition (..), query, satisfies)
import           Prax.Sym (intern)
import           Prax.Types (Outcome (..), PraxState (..), emptyState)
import           Prax.Engine (performOutcome, withDb)
import           Prax.Beliefs

-- Apply a list of outcomes to an empty state, return the resulting facts.
run :: [Outcome] -> [String]
run outs = dbToSentences (db (foldl (flip performOutcome) emptyState outs))

tests :: TestTree
tests = testGroup "Prax.Beliefs"
  [ testCase "beliefSentence / beliefAbout build the expected paths" $ do
      beliefSentence "bex" "resentedBy.ada" "yes" @?= "bex.believes.resentedBy.ada!yes"
      beliefAbout "bex" "sky" @?= "bex.believes.sky"

  , testCase "believe records a belief; believesThat matches it" $ do
      assertBool "belief recorded"
        ("bex.believes.sky.green" `elem` run [ believe "bex" "sky" "green" ])
      believesThat "bex" "sky" "green" @?= Match "bex.believes.sky!green"

  , testCase "a new value for an issue overrides the old (single-slot)" $ do
      let fs = run [ believe "bex" "sky" "green", believe "bex" "sky" "blue" ]
      assertBool "new value present" ("bex.believes.sky.blue" `elem` fs)
      assertBool "old value gone"   ("bex.believes.sky.green" `notElem` fs)

  , testCase "forget drops the belief" $ do
      let fs = run [ believe "bex" "sky" "blue", forget "bex" "sky" ]
      assertBool "no sky belief remains" (not (any ("believes.sky." `isInfixOf`) fs))

  , testCase "doubts / holdsBelief are issue-level gates" $ do
      doubts "bex" "sky" @?= Absent [ Match "bex.believes.sky" ]
      holdsBelief "bex" "sky" @?= Match "bex.believes.sky"

  , testCase "beliefs are per-agent: two agents can disagree" $ do
      let fs = run [ believe "bex" "murderer" "ada", believe "cid" "murderer" "you" ]
      assertBool "bex's view" ("bex.believes.murderer.ada" `elem` fs)
      assertBool "cid's view"  ("cid.believes.murderer.you" `elem` fs)

  , testCase "a belief can be false — diverging from the shared world" $ do
      -- Shared world: ada is actually pleased. bex nonetheless believes she is cross.
      let world = insertAll [ "ada.mood!pleased" ] emptyDb :: Db
          st    = performOutcome (believe "bex" "adaMood" "cross") (withDb (const world) emptyState)
          fs    = dbToSentences (db st)
      assertBool "world truth stands"   ("ada.mood.pleased" `elem` fs)
      assertBool "bex's belief diverges" ("bex.believes.adaMood.cross" `elem` fs)
      -- Querying bex's belief yields 'cross', not the world's 'pleased'.
      let bel = query (db st) [ Match (beliefAbout "bex" "adaMood" ++ "!V") ] Map.empty
      map (fmap valToString . Map.lookup (intern "V")) bel @?= [Just "cross"]

  , testCase "disbelievesThat is Not of believesThat path" $
      disbelievesThat "bex" "sky" "green" @?= Not "bex.believes.sky!green"

  , testCase "everBelieves / neverBelieves are agent-scoped Exists/Absent" $ do
      everBelieves "bex" @?= Exists [ Match "bex.believes.Issue" ]
      neverBelieves "bex" @?= Absent [ Match "bex.believes.Issue" ]

  , testCase "lacksBelief aliases neverBelieves" $
      lacksBelief "bex" @?= neverBelieves "bex"
  
  , testCase "hasBelief aliases everBelieves" $
      hasBelief "bex" @?= everBelieves "bex"
  , testCase "hasBelievesThat / hasHoldsBelief aliases" $ do
      hasBelievesThat "ada" "weather" "rain" @?= believesThat "ada" "weather" "rain"
      hasHoldsBelief "ada" "weather" @?= holdsBelief "ada" "weather"
  , testCase "lacksHoldsBelief aliases doubts" $
      lacksHoldsBelief "ada" "weather" @?= doubts "ada" "weather"


  , testCase "believesThat / holdsBelief / everBelieves evaluate on believe world" $ do
      assertBool "neverBelieves on empty"
        (satisfies (db emptyState) [neverBelieves "bex"] Map.empty)
      assertBool "lacksBelief on empty"
        (satisfies (db emptyState) [lacksBelief "bex"] Map.empty)
      assertBool "doubts on empty"
        (satisfies (db emptyState) [doubts "bex" "sky"] Map.empty)
      assertBool "lacksHoldsBelief on empty"
        (satisfies (db emptyState) [lacksHoldsBelief "bex" "sky"] Map.empty)
      let st = performOutcome (believe "bex" "sky" "blue") emptyState
      assertBool "believesThat"
        (satisfies (db st) [believesThat "bex" "sky" "blue"] Map.empty)
      assertBool "hasBelievesThat"
        (satisfies (db st) [hasBelievesThat "bex" "sky" "blue"] Map.empty)
      assertBool "holdsBelief"
        (satisfies (db st) [holdsBelief "bex" "sky"] Map.empty)
      assertBool "hasHoldsBelief"
        (satisfies (db st) [hasHoldsBelief "bex" "sky"] Map.empty)
      assertBool "everBelieves"
        (satisfies (db st) [everBelieves "bex"] Map.empty)
      assertBool "hasBelief"
        (satisfies (db st) [hasBelief "bex"] Map.empty)
      assertBool "disbelievesThat fails"
        (not (satisfies (db st) [disbelievesThat "bex" "sky" "blue"] Map.empty))
      assertBool "disbelievesThat other value"
        (satisfies (db st) [disbelievesThat "bex" "sky" "green"] Map.empty)
      assertBool "doubts fails"
        (not (satisfies (db st) [doubts "bex" "sky"] Map.empty))
      assertBool "lacksHoldsBelief fails"
        (not (satisfies (db st) [lacksHoldsBelief "bex" "sky"] Map.empty))

  ]
