module Prax.HostSpec (tests) where

import           Data.List (isInfixOf, sort)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Types
import           Prax.Query (Condition (..))
import           Prax.Engine (definePractice, setCharacters, performOutcome)
import           Prax.Host
import           System.Directory (removeFile)

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


  , testCase "checkpoint / restore round-trips facts via Persist" $ do
      let path = "/tmp/prax-host-checkpoint-test.prax"
          st0 = inject world [ Insert "flag.ada" ]
      checkpoint path st0
      st1 <- restore path world
      removeFile path
      assertBool "flag survived" ("flag.ada" `elem` queryFacts st1)

  , testCase "queryChronicle and livingCast and explainActor" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "leads.hall!ana"
                , Insert "dead.bob" ]
          stC = setCharacters (map character ["ana", "bob", "cara"]) st
      queryChronicle stC "leads of hall" @?= ["ana leads hall"]
      assertBool "bob dead skipped" ("bob" `notElem` livingCast stC)
      assertBool "ana live" ("ana" `elem` livingCast stC)
      -- explainActor on empty practice world returns []
      explainActor stC "ana" "nonexistent" @?= []

  , testCase "queryMatching filters base facts by needle" $ do
      let st = inject world [ Insert "flag.ada", Insert "note.hall", Insert "flag.bob" ]
          hits = queryMatching st "flag."
      assertBool "flag.ada" ("flag.ada" `elem` hits)
      assertBool "flag.bob" ("flag.bob" `elem` hits)
      assertBool "note excluded" ("note.hall" `notElem` hits)
      length hits @?= 2

  , testCase "queryViewMatching filters closed view" $ do
      let hits = queryViewMatching world "practice.wave"
      assertBool "wave practice in view" ("practice.wave" `elem` hits)

  , testCase "factDelta, factDeltaMatching reports added and removed" $ do
      let before = inject world [ Insert "flag.ada", Insert "keep.x" ]
          after  = inject world [ Insert "keep.x", Insert "note.hall" ]
          (added, removed) = factDelta before after
      assertBool "note added" ("note.hall" `elem` added)
      assertBool "flag removed" ("flag.ada" `elem` removed)
      assertBool "keep stable" ("keep.x" `notElem` added && "keep.x" `notElem` removed)

  , testCase "availableMatching filters menu by needle" $ do
      let hits = availableMatching world "ada" "wave"
      assertBool "wave" (any ("wave" `isInfixOf`) hits)
      availableMatching world "ada" "nonexistent" @?= []

  , testCase "livingMatching filters living cast by needle" $ do
      let st = setCharacters (map character ["ana", "cara", "bob"]) emptyState
      livingMatching st "a" @?= ["ana", "cara"]

  , testCase "factDeltaMatching filters delta by needle" $ do
      let before = inject world [ Insert "flag.ada", Insert "keep.x" ]
          after  = inject world [ Insert "flag.bob", Insert "keep.x" ]
          (added, removed) = factDeltaMatching "flag." before after
      assertBool "added bob" ("flag.bob" `elem` added)
      assertBool "removed ada" ("flag.ada" `elem` removed)
      assertBool "keep.x not in filtered delta" ("keep.x" `notElem` (added ++ removed))

  , testCase "queryChronicleMatching filters chronicle rows by needle" $ do
      let st = foldl (flip performOutcome) emptyState [ Insert "leads.hall!ana" ]
          stC = setCharacters (map character ["ana"]) st
          allRows = queryChronicle stC "leads of hall"
          filtered = queryChronicleMatching stC "leads of hall" "___nomatch___"
          kept = queryChronicleMatching stC "leads of hall" "ana"
      assertBool "impossible needle empty" (null filtered)
      kept @?= allRows

  , testCase "explainActorMatching filters explain lines" $
      explainActorMatching world "ada" "wave" "___nomatch___" @?= []

  , testCase "practiceNames lists top-level practice ids" $ do
      let names = practiceNames world
      assertBool "wave practice" ("wave" `elem` names)

  , testCase "deadCast lists dead. marked cast members" $ do
      let st = foldl (flip performOutcome) emptyState [ Insert "dead.bob" ]
          stC = setCharacters (map character ["ana", "bob"]) st
      deadCast stC @?= ["bob"]
      assertBool "ana living" ("ana" `elem` livingCast stC)

  , testCase "castNames lists full cast including dead" $ do
      let st = foldl (flip performOutcome) emptyState [ Insert "dead.bob" ]
          stC = setCharacters (map character ["ana", "bob"]) st
      assertBool "ana" ("ana" `elem` castNames stC)
      assertBool "bob" ("bob" `elem` castNames stC)

  , testCase "regardsOf lists regards.<who>.* from the closed view" $ do
      let st = inject world
                 [ Insert "regards.dave.bob.thief"
                 , Insert "regards.dave.eve.liar"
                 , Insert "regards.fran.bob.thief"
                 , Insert "flag.x" ]
          hits = regardsOf st "dave"
      assertBool "dave->bob" ("regards.dave.bob.thief" `elem` hits)
      assertBool "dave->eve" ("regards.dave.eve.liar" `elem` hits)
      assertBool "fran excluded" ("regards.fran.bob.thief" `notElem` hits)
      assertBool "flag excluded" ("flag.x" `notElem` hits)


  , testCase "membersOf / affiliatesOf list faction membership from the view" $ do
      let st = inject world
                 [ Insert "member.ana!hall"
                 , Insert "member.ben!hall"
                 , Insert "member.cass!yard"
                 , Insert "affiliate.ana.guild"
                 , Insert "affiliate.ana.choir" ]
      sort (membersOf st "hall") @?= ["ana", "ben"]
      membersOf st "yard" @?= ["cass"]
      sort (affiliatesOf st "ana") @?= ["choir", "guild"]

  ]
