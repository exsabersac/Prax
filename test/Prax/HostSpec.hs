module Prax.HostSpec (tests) where

import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool)

import           Prax.Db (exists)
import           Prax.Types
import           Prax.Query (Condition (..))
import           Prax.Engine (definePractice, performOutcome)
import           Prax.Host (step, stepExact, inject, queryFacts, queryView, available, availableActions)

waveP :: Practice
waveP = practice
  { practiceId = "wave"
  , roles = []
  , actions =
      [ action "[Actor]: wave"
          [ Not "waved.Actor" ]
          [ Insert "waved.Actor" ] ]
  }

world :: PraxState
world = definePractice waveP
          (foldl (flip performOutcome) emptyState
            [ Insert "practice.wave" ])

tests :: TestTree
tests = testGroup "Prax.Host"
  [ testCase "available lists menu labels" $
      assertBool "wave offered" (any ("wave" `isInfixOf`) (available world "ada"))

  , testCase "step performs a matching action" $ do
      case step world "ada" "wave" of
        Left err -> assertBool err False
        Right st -> do
          assertBool "waved" (exists "waved.ada" (db st))
          assertBool "wave gone after once-guard"
            (not (any ("wave" `isInfixOf`) (available st "ada")))

  , testCase "step Left when nothing matches" $
      case step world "ada" "nonexistent-act" of
        Left _  -> pure ()
        Right _ -> assertBool "expected Left" False

  , testCase "inject writes outcomes; queryFacts reads base" $ do
      let st = inject world [ Insert "flag.ada", Insert "note.hall" ]
      assertBool "flag" ("flag.ada" `elem` queryFacts st)
      assertBool "note" ("note.hall" `elem` queryFacts st)

  , testCase "stepExact requires full label" $ do
      case stepExact world "ada" "wave" of
        Left _ -> pure ()
        Right _ -> assertBool "infix should fail exact" False
      case stepExact world "ada" "ada: wave" of
        Right st -> assertBool "waved" (exists "waved.ada" (db st))
        Left e -> assertBool e False

  , testCase "availableActions non-empty; queryView includes derived-capable read" $ do
      assertBool "actions" (not (null (availableActions world "ada")))
      assertBool "facts" ("practice.wave" `elem` queryFacts world)
      assertBool "view" ("practice.wave" `elem` queryView world)

  ]
