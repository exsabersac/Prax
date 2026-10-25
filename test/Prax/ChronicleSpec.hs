module Prax.ChronicleSpec (tests) where

import           Data.List (isInfixOf, isPrefixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters)
import           Prax.Repute (standingUnless, notoriety)
import           Prax.Chronicle

-- Two knowers of a kick; standing derives; notoriety at threshold 2.
world :: PraxState
world = setAxioms [ standingUnless "kicked.Brute.dog" "forgiven.Brute" "brute"
                  , notoriety "brute" 2 ]
                  (foldl (flip performOutcome) base setup)
  where
    base = setCharacters (map character ["ana", "ben", "kai"])
             (definePractices [p] emptyState)
    p = practice { practiceId = "yard", roles = ["R"], actions = [] }
    setup =
      [ Insert "practice.yard.here"
      , Insert "ana.believes.kicked.kai.dog.seen"
      , Insert "ben.believes.kicked.kai.dog.heard.ana" ]

tests :: TestTree
tests = testGroup "Prax.Chronicle"
  [ testCase "chronicleEvents parses seen and heard provenance" $ do
      let evs = chronicleEvents (db world)
      assertBool "ana saw" $
        EventRecord "ana" "kicked.kai.dog" Seen `elem` evs
      assertBool "ben heard via ana" $
        EventRecord "ben" "kicked.kai.dog" (Heard "ana") `elem` evs

  , testCase "salientEvents thresholds by distinct knowers" $ do
      let one = map fst (salientEvents 1 (db world))
          two = map fst (salientEvents 2 (db world))
          three = map fst (salientEvents 3 (db world))
      assertBool "salient at 1" ("kicked.kai.dog" `elem` one)
      assertBool "salient at 2" ("kicked.kai.dog" `elem` two)
      assertBool "not salient at 3" ("kicked.kai.dog" `notElem` three)

  , testCase "knowerCount counts distinct knowers" $
      knowerCount "kicked.kai.dog" (db world) @?= 2

  , testCase "regardingHooks and notorietyHooks from the closed view" $ do
      let rs = regardingHooks world
          ns = notorietyHooks world
      assertBool "ana regards kai" (RegardHook "ana" "kai" "brute" `elem` rs)
      assertBool "ben regards kai" (RegardHook "ben" "kai" "brute" `elem` rs)
      assertBool "kai notorious" (NotoriousHook "kai" "brute" `elem` ns)

  , testCase "summarize mentions the event and the standing" $ do
      let lines_ = summarize world
      assertBool "event line" (any ("kicked.kai.dog" `isInfixOf`) lines_)
      assertBool "regard line" (any ("regards kai as brute" `isInfixOf`) lines_)
      assertBool "notorious line" (any ("notorious as brute" `isInfixOf`) lines_)

  , testCase "askChronicle who-knows / regards / notorious / salient" $ do
      askChronicle world "who knows kicked.kai.dog"
        @?= ["ana knows kicked.kai.dog", "ben knows kicked.kai.dog"]
      askChronicle world "regards of kai"
        @?= ["ana as brute", "ben as brute"]
      askChronicle world "what is notorious"
        @?= ["kai as brute"]
      assertBool "salient 2 mentions knowers"
        (any ("2 knowers" `isInfixOf`) (askChronicle world "salient 2"))
      askChronicle world "who knows never.happened"
        @?= ["nobody is known to know never.happened"]

  , testCase "defeater dissolves regard hooks while memory (and chronicle events) persist" $ do
      let f = performOutcome (Insert "forgiven.kai") world
      assertBool "no regard hooks" (null (regardingHooks f))
      assertBool "no notoriety hooks" (null (notorietyHooks f))
      assertBool "events still chronicled"
        (knowerCount "kicked.kai.dog" (db f) == 2)

  , testCase "askChronicle feelings-of lists base feeling facts" $ do
      let st = foldl (flip performOutcome) world
                [ Insert "ana.feels.angry"
                , Insert "ana.feels.angry.toward.kai"
                , Insert "ana.feels.angry.intensity!2" ]
      let lines = askChronicle st "feelings of ana"
      assertBool "lists angry" (any ("ana.feels.angry" ==) lines
                                 || any ("ana.feels.angry" `isPrefixOf`) lines)
      -- exact leaf sentences from dbToSentences
      assertBool "has toward" ("ana.feels.angry.toward.kai" `elem` lines)
      -- dbToSentences flattens exclusive labels (! → .) for display
      assertBool "has intensity" ("ana.feels.angry.intensity.2" `elem` lines)
      askChronicle st "feelings of nobody"
        @?= ["nobody has no recorded feelings"]

  , testCase "askChronicle leads-of and affiliates-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "leads.hall!ana"
                , Insert "affiliate.ana.guild" ]
      askChronicle st "leads of hall" @?= ["ana leads hall"]
      askChronicle st "affiliates of ana" @?= ["ana affiliates guild"]


  , testCase "askChronicle debts-of lists debt facts involving who" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "debt.cora.dell.favor"
                , Insert "debt.eve.cora.coin" ]
      askChronicle st "debts of cora"
        @?= ["debt.cora.dell.favor", "debt.eve.cora.coin"]
      askChronicle st "debts of nobody"
        @?= ["nobody has no debts on record"]

  ]
