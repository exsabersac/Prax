module Prax.ChronicleSpec (tests) where

import           Data.List (isInfixOf, isPrefixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters)
import           Prax.Repute (standingUnless, notoriety)
import           Prax.Chronicle
import           Prax.Host (feelingsOf, festivalsOf, holdingOf,
                             carryingOf, shunnedOf, locationsOf)

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

  , testCase "askChronicle mood-of lists baseline mood" $ do
      let st = foldl (flip performOutcome) emptyState [ Insert "mood.ana!cheerful" ]
      askChronicle st "mood of ana" @?= ["ana mood cheerful"]
      askChronicle st "mood of bob" @?= ["bob has no baseline mood"]

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

  , testCase "askChronicle arc-of / age-of / siblings-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "mia.arc!hopeful"
                , Insert "age.mia!17"
                , Insert "sibling.mia.pat"
                , Insert "sibling.pat.mia" ]
          -- sibling facts are typically derived; plant both directions in base for the query surface
          stV = st
      askChronicle stV "arc of mia" @?= ["mia arc hopeful"]
      askChronicle stV "arc of bob" @?= ["bob has no arc stage"]
      askChronicle stV "age of mia" @?= ["mia age 17"]
      askChronicle stV "siblings of mia" @?= ["mia sibling pat"]

  , testCase "askChronicle members-of lists faction members" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "member.ana!hall"
                , Insert "member.ben!hall"
                , Insert "member.cass!yard" ]
      askChronicle st "members of hall"
        @?= ["ana is a member of hall", "ben is a member of hall"]
      askChronicle st "members of nobody"
        @?= ["nobody is a member of nobody"]

  , testCase "askChronicle branded-of / revoked-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "branded.bob"
                , Insert "brandedHeretic.eve"
                , Insert "revoked.ira.bob"
                , Insert "revoked.gale.eve" ]
      askChronicle st "branded of bob" @?= ["branded.bob"]
      askChronicle st "branded of eve" @?= ["brandedHeretic.eve"]
      askChronicle st "branded of void" @?= ["void has no brand marks"]
      askChronicle st "revoked of bob" @?= ["revoked.ira.bob"]
      askChronicle st "revoked of void" @?= ["void has no revoked deals"]

  , testCase "askChronicle confessed/recanted/ostracized/exiled-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "confessed.bob"
                , Insert "ana.confessed.H.stole.C.loaf"
                , Insert "recanted.eve"
                , Insert "ostracized.dana.bob"
                , Insert "exiled.bob" ]
      askChronicle st "confessed of bob" @?= ["confessed.bob"]
      askChronicle st "confessed of ana" @?= ["ana.confessed.H.stole.C.loaf"]
      askChronicle st "confessed of void" @?= ["void has no confessions on record"]
      askChronicle st "recanted of eve" @?= ["recanted.eve"]
      askChronicle st "recanted of void" @?= ["void has no recantation on record"]
      askChronicle st "ostracized of bob" @?= ["ostracized.dana.bob"]
      askChronicle st "ostracized of void" @?= ["void has no ostracize marks"]
      askChronicle st "exiled of bob" @?= ["exiled.bob"]
      askChronicle st "exiled of void" @?= ["void has no exile mark"]

  , testCase "askChronicle denounced/censured/paraded-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "denounced.dave.bob"
                , Insert "censured.priest.eve"
                , Insert "paraded.dave.bob" ]
      askChronicle st "denounced of bob" @?= ["denounced.dave.bob"]
      askChronicle st "denounced of void" @?= ["void has no denounce marks"]
      askChronicle st "censured of eve" @?= ["censured.priest.eve"]
      askChronicle st "censured of void" @?= ["void has no censure marks"]
      askChronicle st "paraded of bob" @?= ["paraded.dave.bob"]
      askChronicle st "paraded of void" @?= ["void has no parade marks"]

  , testCase "askChronicle cried/rallied/fled/reconciled/married-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "cried.dave.bob"
                , Insert "rallied.ira.bob"
                , Insert "fled.carol"
                , Insert "reconciled.carol"
                , Insert "married.fran.carol" ]
      askChronicle st "cried of bob" @?= ["cried.dave.bob"]
      askChronicle st "cried of void" @?= ["void has no cry marks"]
      askChronicle st "rallied of bob" @?= ["rallied.ira.bob"]
      askChronicle st "rallied of void" @?= ["void has no rally marks"]
      askChronicle st "fled of carol" @?= ["fled.carol"]
      askChronicle st "fled of void" @?= ["void has no flee mark"]
      askChronicle st "reconciled of carol" @?= ["reconciled.carol"]
      askChronicle st "reconciled of void" @?= ["void has no reconcile mark"]
      askChronicle st "married of fran" @?= ["married.fran.carol"]
      askChronicle st "married of void" @?= ["void has no marriage marks"]

  , testCase "askChronicle eyed/confronted/atoned-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "eyed.dana.bob"
                , Insert "confronted.carol.bob"
                , Insert "atoned.bob" ]
      askChronicle st "eyed of bob" @?= ["eyed.dana.bob"]
      askChronicle st "eyed of void" @?= ["void has no eye marks"]
      askChronicle st "confronted of bob" @?= ["confronted.carol.bob"]
      askChronicle st "confronted of void" @?= ["void has no confront marks"]
      askChronicle st "atoned of bob" @?= ["atoned.bob"]
      askChronicle st "atoned of void" @?= ["void has no atonement on record"]

  , testCase "askChronicle wronged/hungry-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "wronged.alice.bob"
                , Insert "hungry.bob" ]
      askChronicle st "wronged of bob" @?= ["wronged.alice.bob"]
      askChronicle st "wronged of void" @?= ["void has no wrong marks"]
      askChronicle st "hungry of bob" @?= ["hungry.bob"]
      askChronicle st "hungry of void" @?= ["void has no hunger mark"]

  , testCase "askChronicle shortTempered/appetite-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "shortTempered.carol"
                , Insert "appetite.bob" ]
      askChronicle st "shortTempered of carol" @?= ["shortTempered.carol"]
      askChronicle st "shortTempered of void" @?= ["void has no short-temper mark"]
      askChronicle st "appetite of bob" @?= ["appetite.bob"]
      askChronicle st "appetite of void" @?= ["void has no appetite mark"]

  , testCase "askChronicle resents-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "resents.bob.alice"
                , Insert "resents.carol.alice" ]
      askChronicle st "resents of bob" @?= ["resents.bob.alice"]
      askChronicle st "resents of void" @?= ["void has no resentment marks"]

  , testCase "askChronicle allied-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "allied.bob.carol"
                , Insert "allied.dave.eve" ]
      askChronicle st "allied of bob" @?= ["allied.bob.carol"]
      askChronicle st "allied of void" @?= ["void has no alliance marks"]

  , testCase "askChronicle what-is-on-the-stall" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "stall.loaf"
                , Insert "stall.pie"
                , Insert "flag.x" ]
      askChronicle st "what is on the stall" @?= ["stall.loaf", "stall.pie"]
      askChronicle emptyState "what is on the stall" @?= ["the stall is empty"]

  , testCase "askChronicle what-festivals" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "festival.harvest"
                , Insert "festival.market"
                , Insert "flag.x" ]
      askChronicle st "what festivals" @?= ["festival.harvest", "festival.market"]
      askChronicle emptyState "what festivals" @?= ["no festivals are open"]

  , testCase "askChronicle holding-of / carrying-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "holding.ana.loaf"
                , Insert "holding.ben.coin"
                , Insert "carrying.ana.bag"
                , Insert "flag.x" ]
      askChronicle st "holding of ana" @?= ["holding.ana.loaf"]
      askChronicle st "holding of void" @?= ["void holds nothing"]
      askChronicle st "carrying of ana" @?= ["carrying.ana.bag"]
      askChronicle st "carrying of void" @?= ["void carries nothing"]

  , testCase "askChronicle threatened-of / shunned-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "threatened.sid1.ana.ben"
                , Insert "threatened.sid2.cai.ana"
                , Insert "shunned.ana.bob"
                , Insert "flag.x" ]
      askChronicle st "threatened of ana" @?=
        [ "threatened.sid1.ana.ben"
        , "threatened.sid2.cai.ana"
        ]
      askChronicle st "threatened of void" @?= ["void has no threat marks"]
      askChronicle st "shunned of ana" @?= ["shunned.ana.bob"]
      askChronicle st "shunned of void" @?= ["void has shunned no one"]

  , testCase "askChronicle locations-of / demanded-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "at.ana.yard"
                , Insert "at.ben.market"
                , Insert "demanded.ana.ben.favor"
                , Insert "demanded.cai.ana.coin"
                , Insert "flag.x" ]
      askChronicle st "locations of ana" @?= ["at.ana.yard"]
      askChronicle st "locations of void" @?= ["void has no known location"]
      askChronicle st "demanded of ana" @?=
        [ "demanded.ana.ben.favor"
        , "demanded.cai.ana.coin"
        ]
      askChronicle st "demanded of void" @?= ["void has no demand marks"]

  , testCase "askChronicle extorted-of / complied-of / defied-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "ana.extorted.ben.sid1"
                , Insert "cai.extorted.ana.sid2"
                , Insert "complied.sid1.ana.ben"
                , Insert "defied.sid2.ben.ana"
                , Insert "flag.x" ]
      askChronicle st "extorted of ana" @?=
        [ "ana.extorted.ben.sid1"
        , "cai.extorted.ana.sid2"
        ]
      askChronicle st "extorted of void" @?= ["void has no extortion marks"]
      askChronicle st "complied of ana" @?= ["complied.sid1.ana.ben"]
      askChronicle st "complied of void" @?= ["void has no compliance marks"]
      askChronicle st "defied of ana" @?= ["defied.sid2.ben.ana"]
      askChronicle st "defied of void" @?= ["void has no defiance marks"]

  , testCase "askChronicle obligations-of / breaches-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "obliged.ana.truth"
                , Insert "obliged.ben.silence"
                , Insert "violated.ana.truth"
                , Insert "flag.x" ]
      askChronicle st "obligations of ana" @?= ["obliged.ana.truth"]
      askChronicle st "obligations of void" @?= ["void has no obligations"]
      askChronicle st "breaches of ana" @?= ["violated.ana.truth"]
      askChronicle st "breaches of void" @?= ["void has no breaches"]

  , testCase "askChronicle lies-of / chatted-with / traits-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "ana.lied.about.theft"
                , Insert "ana.chattedWith.ben"
                , Insert "trait.ana.brave"
                , Insert "flag.x" ]
      askChronicle st "lies of ana" @?= ["ana.lied.about.theft"]
      askChronicle st "lies of void" @?= ["void has no lie marks"]
      askChronicle st "chatted with ana" @?= ["ana.chattedWith.ben"]
      askChronicle st "chatted with void" @?= ["void has chatted with no one"]
      askChronicle st "traits of ana" @?= ["trait.ana.brave"]
      askChronicle st "traits of void" @?= ["void has no traits on record"]

  , testCase "askChronicle bonds-of / esteemed-of / scorned-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "bond.ana.friend"
                , Insert "esteemed.ana.ben"
                , Insert "scorned.ana.cai"
                , Insert "flag.x" ]
      askChronicle st "bonds of ana" @?= ["bond.ana.friend"]
      askChronicle st "bonds of void" @?= ["void has no bonds"]
      askChronicle st "esteemed of ana" @?= ["esteemed.ana.ben"]
      askChronicle st "esteemed of void" @?= ["void has esteemed no one"]
      askChronicle st "scorned of ana" @?= ["scorned.ana.cai"]
      askChronicle st "scorned of void" @?= ["void has scorned no one"]

  , testCase "askChronicle beliefs-of / projects-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "ana.believes.stole.bob.carol"
                , Insert "practice.mill.ana.crew"
                , Insert "practice.flag"
                , Insert "flag.x" ]
      askChronicle st "beliefs of ana" @?= ["ana.believes.stole.bob.carol"]
      askChronicle st "beliefs of void" @?= ["void has no beliefs on record"]
      askChronicle st "projects of ana" @?= ["practice.mill.ana.crew"]
      askChronicle st "projects of void" @?= ["void has no project marks"]

  , testCase "askChronicle kin-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "married.ana.ben"
                , Insert "parent.ana.cara"
                , Insert "sibling.ben.dave"
                , Insert "inLaw.ana.eve"
                , Insert "grandparent.ana.fay"
                , Insert "flag.x" ]
      askChronicle st "kin of ana" @?=
        [ "grandparent.ana.fay"
        , "inLaw.ana.eve"
        , "married.ana.ben"
        , "parent.ana.cara"
        ]
      askChronicle st "kin of ben" @?= ["married.ana.ben", "sibling.ben.dave"]
      askChronicle st "kin of cara" @?= ["parent.ana.cara"]
      askChronicle st "kin of void" @?= ["void has no kin marks"]

  , testCase "askChronicle notorious-of" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "notorious.ana.thief"
                , Insert "notorious.ben.liar"
                , Insert "flag.x" ]
      askChronicle st "notorious of ana" @?= ["notorious.ana.thief"]
      askChronicle st "notorious of ben" @?= ["notorious.ben.liar"]
      askChronicle st "notorious of void" @?= ["void has no notoriety marks"]

  , testCase "askChronicle regards-toward" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "regards.dave.bob.thief"
                , Insert "regards.fran.bob.thief"
                , Insert "regards.dave.eve.hero"
                , Insert "flag.x" ]
      askChronicle st "regards toward bob"
        @?= ["regards.dave.bob.thief", "regards.fran.bob.thief"]
      askChronicle st "regards toward eve" @?= ["regards.dave.eve.hero"]
      askChronicle st "regards toward void" @?= ["nobody regards void"]

  , testCase "askChronicle what-factions" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "member.dave.mill"
                , Insert "affiliate.fran.choir"
                , Insert "leads.guild!ana"
                , Insert "flag.x" ]
      askChronicle st "what factions" @?= ["choir", "guild", "mill"]
      askChronicle emptyState "what factions" @?= ["no factions are named"]


  , testCase "askChronicle festivals/holding/carrying dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "festival.market"
            , Insert "holding.ana.purse"
            , Insert "carrying.ben.loaf"
            ]
      askChronicle st "what festivals" @?= festivalsOf st
      askChronicle st "holding of ana" @?= holdingOf st "ana"
      askChronicle st "carrying of ben" @?= carryingOf st "ben"
      askChronicle st "holding of void" @?= ["void holds nothing"]
      askChronicle st "carrying of void" @?= ["void carries nothing"]

  , testCase "askChronicle shunned/locations dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "shunned.ana.bob"
            , Insert "at.carol.square"
            ]
      askChronicle st "shunned of ana" @?= shunnedOf st "ana"
      askChronicle st "locations of carol" @?= locationsOf st "carol"
      askChronicle st "shunned of void" @?= ["void has shunned no one"]
      askChronicle st "locations of void" @?= ["void has no known location"]

  , testCase "askChronicle feelings-of dual Host feelingsOf" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ana.feels.guilt.about.bob"
            , Insert "ana.feels.pride"
            ]
      askChronicle st "feelings of ana" @?= feelingsOf st "ana"

  ]
