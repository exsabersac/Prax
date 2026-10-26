module Prax.ChronicleSpec (tests) where

import           Data.List (isInfixOf, isPrefixOf, sort)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters)
import           Prax.Repute (standingUnless, notoriety)
import           Prax.Chronicle
import           Prax.Host (feelingsOf, festivalsOf, holdingOf,
                             carryingOf, shunnedOf, locationsOf, occupantsOf, holdersOf, carriersOf,
                             obligationsOf, breachesOf, debtsOf,
                             threatenedOf, stallOf, kinOf,
                             brandedOf, exiledOf, denouncedOf,
                             moodsOf, arcsOf, liesOf, traitsOf,
                             chattedWithOf, chattersOf, esteemedOf, scornedOf,
                             beliefsOf, believersOf, projectsOf, practitionersOf, bondsOf,
                             extortedOf, compliedOf, defiedOf,
                             revokedOf, confessedOf, censuredOf,
                             paradedOf, criedOf, ralliedOf,
                             fledOf, reconciledOf, marriedOf,
                             ostracizedOf, atonedOf, hungryOf,
                             eyedOf, confrontedOf, wrongedOf,
                             recantedOf, shortTemperedOf, appetiteOf,
                             resentsOf, alliedOf, demandedOf,
                             notoriousOf, regardsOf, regardsToward, factionsNamed,
                             membersOf, affiliatesOf, affiliatorsOf, leadersOf, agesOf,
                             siblingsOf, parentsOf, childrenOf,
                             grandparentsOf, grandchildrenOf, inLawsOf, spousesOf, creditorsOf, debtorsOf, demandersOf, demandeesOf, threatenersOf, threateneesOf, extortersOf, extorteesOf, compliersOf, complieesOf, defiersOf, defieesOf, wrongersOf, wrongeesOf, eyersOf, eyeesOf, confrontersOf, confronteesOf, revokersOf, revokeesOf, ostracizersOf, ostracizeesOf, denouncersOf, denounceesOf, censurersOf, censureesOf, paradersOf, paradeesOf, criersOf, crieesOf, ralliersOf, rallieesOf, alliesOf, resentersOf, shunnersOf, esteemersOf, scornersOf, bondersOf, liarsOf)

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
      askChronicle st "leaders of hall" @?= ["ana leads hall"]
      askChronicle st "leaders of void" @?= ["nobody leads void"]
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
      askChronicle st "short-tempered of carol" @?= ["shortTempered.carol"]
      askChronicle st "shortTempered of void" @?= ["void has no short-temper mark"]
      askChronicle st "short-tempered of void" @?= ["void has no short-temper mark"]
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
      askChronicle st "festivals" @?= festivalsOf st
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


  , testCase "askChronicle obligations/breaches/debts dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "obliged.ana.guard.gate"
            , Insert "violated.ben.guard.gate"
            , Insert "debt.cora.dell.favor"
            ]
      askChronicle st "obligations of ana" @?= obligationsOf st "ana"
      askChronicle st "breaches of ben" @?= breachesOf st "ben"
      askChronicle st "debts of cora" @?= debtsOf st "cora"

  , testCase "askChronicle threatened/stall/kin dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "threatened.racket.mob.vic"
            , Insert "stall.loaf"
            , Insert "sibling.mia.pat"
            , Insert "parent.mia.ada"
            ]
      askChronicle st "threatened of vic" @?= threatenedOf st "vic"
      askChronicle st "what is on the stall" @?= stallOf st
      askChronicle st "stall" @?= stallOf st
      askChronicle st "kin of mia" @?= kinOf st "mia"


  , testCase "askChronicle branded/exiled/denounced dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "branded.bob"
            , Insert "exiled.eve"
            , Insert "denounced.dave.bob"
            ]
      askChronicle st "branded of bob" @?= brandedOf st "bob"
      askChronicle st "exiled of eve" @?= exiledOf st "eve"
      askChronicle st "denounced of bob" @?= denouncedOf st "bob"

  , testCase "askChronicle mood/arc dual Host moodsOf/arcsOf raw leaves" $ do
      -- Host moodsOf/arcsOf return full leaves; Chronicle phrases them.
      let st = foldl (flip performOutcome) emptyState
            [ Insert "mood.ana.cheerful"
            , Insert "mia.arc.hopeful"
            ]
      moodsOf st "ana" @?= ["mood.ana.cheerful"]
      arcsOf st "mia" @?= ["mia.arc.hopeful"]
      askChronicle st "mood of ana" @?= ["ana mood cheerful"]
      askChronicle st "arc of mia" @?= ["mia arc hopeful"]
      askChronicle st "moods of ana" @?= moodsOf st "ana"
      askChronicle st "arcs of mia" @?= arcsOf st "mia"
      askChronicle st "moods of void" @?= ["void has no mood marks"]
      askChronicle st "arcs of void" @?= ["void has no arc marks"]


  , testCase "askChronicle lies/traits/chatted dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ana.lied.about.bob"
            , Insert "trait.ana.brave"
            , Insert "ana.chattedWith.ben"
            ]
      askChronicle st "lies of ana" @?= liesOf st "ana"
      askChronicle st "traits of ana" @?= traitsOf st "ana"
      askChronicle st "chatted with ana" @?= chattedWithOf st "ana"

  , testCase "askChronicle esteemed/scorned dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "esteemed.ana.ben"
            , Insert "scorned.ben.carol"
            ]
      askChronicle st "esteemed of ana" @?= esteemedOf st "ana"
      askChronicle st "scorned of ben" @?= scornedOf st "ben"


  , testCase "askChronicle beliefs/projects/bonds dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ana.believes.kicked.kai.dog"
            , Insert "practice.yard.ana.crew"
            , Insert "bond.ana.ben"
            ]
      askChronicle st "beliefs of ana" @?= beliefsOf st "ana"
      askChronicle st "projects of ana" @?= projectsOf st "ana"
      askChronicle st "bonds of ana" @?= bondsOf st "ana"


  , testCase "askChronicle extorted/complied/defied dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "mob.extorted.vic.racket"
            , Insert "complied.racket.mob.vic"
            , Insert "defied.racket.vic.mob"
            ]
      askChronicle st "extorted of vic" @?= extortedOf st "vic"
      askChronicle st "complied of vic" @?= compliedOf st "vic"
      askChronicle st "defied of vic" @?= defiedOf st "vic"


  , testCase "askChronicle revoked/confessed/censured dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "revoked.ira.bob"
            , Insert "confessed.bob"
            , Insert "censured.priest.eve"
            ]
      askChronicle st "revoked of bob" @?= revokedOf st "bob"
      askChronicle st "confessed of bob" @?= confessedOf st "bob"
      askChronicle st "censured of eve" @?= censuredOf st "eve"

  , testCase "askChronicle paraded/cried/rallied dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "paraded.dave.bob"
            , Insert "cried.dave.bob"
            , Insert "rallied.dave.bob"
            ]
      askChronicle st "paraded of bob" @?= paradedOf st "bob"
      askChronicle st "cried of bob" @?= criedOf st "bob"
      askChronicle st "rallied of bob" @?= ralliedOf st "bob"


  , testCase "askChronicle fled/reconciled/married dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "fled.carol"
            , Insert "reconciled.carol"
            , Insert "married.fran.dave"
            ]
      askChronicle st "fled of carol" @?= fledOf st "carol"
      askChronicle st "reconciled of carol" @?= reconciledOf st "carol"
      askChronicle st "married of fran" @?= marriedOf st "fran"

  , testCase "askChronicle ostracized/atoned/hungry dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ostracized.dana.bob"
            , Insert "atoned.bob"
            , Insert "hungry.bob"
            ]
      askChronicle st "ostracized of bob" @?= ostracizedOf st "bob"
      askChronicle st "atoned of bob" @?= atonedOf st "bob"
      askChronicle st "hungry of bob" @?= hungryOf st "bob"

  , testCase "askChronicle eyed/confronted/wronged dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "eyed.dana.bob"
            , Insert "confronted.carol.bob"
            , Insert "wronged.alice.bob"
            ]
      askChronicle st "eyed of bob" @?= eyedOf st "bob"
      askChronicle st "confronted of bob" @?= confrontedOf st "bob"
      askChronicle st "wronged of bob" @?= wrongedOf st "bob"

  , testCase "askChronicle recanted dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "recanted.eve"
            ]
      askChronicle st "recanted of eve" @?= recantedOf st "eve"

  , testCase "askChronicle shortTempered/appetite dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "shortTempered.carol"
            , Insert "appetite.bob"
            ]
      askChronicle st "shortTempered of carol" @?= shortTemperedOf st "carol"
      askChronicle st "short-tempered of carol" @?= shortTemperedOf st "carol"
      askChronicle st "appetite of bob" @?= appetiteOf st "bob"

  , testCase "askChronicle resents/allied dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "resents.bob.alice"
            , Insert "allied.bob.carol"
            , Insert "allied.dave.eve"
            ]
      askChronicle st "resents of bob" @?= resentsOf st "bob"
      askChronicle st "allied of bob" @?= alliedOf st "bob"
      askChronicle st "allied of eve" @?= alliedOf st "eve"

  , testCase "askChronicle demanded/notorious dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "demanded.ira.ana.flour"
            , Insert "notorious.ana.thief"
            ]
      askChronicle st "demanded of ana" @?= demandedOf st "ana"
      askChronicle st "notorious of ana" @?= notoriousOf st "ana"

  , testCase "askChronicle regardsToward/factionsNamed dual Host view" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "regards.dave.eve.hero"
            , Insert "member.ana.guild"
            , Insert "affiliate.bob.mill"
            , Insert "leads.choir!carol"
            ]
      askChronicle st "regards toward eve" @?= regardsToward st "eve"
      askChronicle st "what factions" @?= factionsNamed st

  , testCase "askChronicle members/affiliates/leads dual Host names" $ do
      -- Host *Of return bare names; Chronicle phrases them.
      let st = foldl (flip performOutcome) emptyState
            [ Insert "member.ana!hall"
            , Insert "member.ben!hall"
            , Insert "affiliate.ana.guild"
            , Insert "leads.hall!ana"
            ]
      membersOf st "hall" @?= ["ana", "ben"]
      affiliatesOf st "ana" @?= ["guild"]
      leadersOf st "hall" @?= ["ana"]
      askChronicle st "members of hall" @?=
        ["ana is a member of hall", "ben is a member of hall"]
      askChronicle st "affiliates of ana" @?= ["ana affiliates guild"]
      askChronicle st "leads of hall" @?= ["ana leads hall"]

  , testCase "askChronicle age dual Host agesOf raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "age.mia.17"
            ]
      agesOf st "mia" @?= ["age.mia.17"]
      askChronicle st "age of mia" @?= ["mia age 17"]
      askChronicle st "ages of mia" @?= agesOf st "mia"
      askChronicle st "ages of void" @?= ["void has no age marks"]

  , testCase "askChronicle regards-of dual Host regardsToward phrasing" $ do
      -- Host regardsToward returns full leaves on target; Chronicle phrases observers.
      let st = foldl (flip performOutcome) emptyState
            [ Insert "regards.dave.eve.hero"
            , Insert "regards.kai.dog.victim"
            ]
      regardsToward st "eve" @?= ["regards.dave.eve.hero"]
      regardsToward st "dog" @?= ["regards.kai.dog.victim"]
      askChronicle st "regards of eve" @?= ["dave as hero"]
      askChronicle st "regards of dog" @?= ["kai as victim"]
      regardsOf st "dave" @?= ["regards.dave.eve.hero"]
      askChronicle st "regards by dave" @?= regardsOf st "dave"
      askChronicle st "regards by kai" @?= regardsOf st "kai"
      askChronicle st "regards by void" @?= ["void regards nobody"]

  , testCase "askChronicle siblings dual Host siblingsOf raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "sibling.mia.pat"
            , Insert "sibling.mia.sam"
            ]
      siblingsOf st "mia" @?= ["sibling.mia.pat", "sibling.mia.sam"]
      askChronicle st "siblings of mia" @?=
        ["mia sibling pat", "mia sibling sam"]

  , testCase "askChronicle parents/children dual Host raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "parent.pat.ana"
            , Insert "parent.mia.ana"
            , Insert "parent.ana.cara"
            ]
      parentsOf st "ana" @?= ["parent.mia.ana", "parent.pat.ana"]
      childrenOf st "ana" @?= ["parent.ana.cara"]
      askChronicle st "parents of ana" @?=
        ["mia parent of ana", "pat parent of ana"]
      askChronicle st "children of ana" @?= ["ana parent of cara"]
      askChronicle st "parents of void" @?= ["void has no known parents"]
      askChronicle st "children of void" @?= ["void has no known children"]

  , testCase "askChronicle grandparents/grandchildren/in-laws dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "grandparent.gran.ana"
            , Insert "grandparent.mia.cara"
            , Insert "inLaw.pat.eve"
            , Insert "inLaw.mia.eve"
            ]
      grandparentsOf st "ana" @?= ["grandparent.gran.ana"]
      grandchildrenOf st "mia" @?= ["grandparent.mia.cara"]
      inLawsOf st "eve" @?= ["inLaw.mia.eve", "inLaw.pat.eve"]
      askChronicle st "grandparents of ana" @?= ["gran grandparent of ana"]
      askChronicle st "grandchildren of mia" @?= ["mia grandparent of cara"]
      askChronicle st "in-laws of eve" @?=
        ["mia in-law of eve", "pat in-law of eve"]
      askChronicle st "grandparents of void" @?=
        ["void has no known grandparents"]
      askChronicle st "grandchildren of void" @?=
        ["void has no known grandchildren"]
      askChronicle st "in-laws of void" @?= ["void has no known in-laws"]

  , testCase "askChronicle spouses dual Host spousesOf raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "married.fran.carol"
            , Insert "married.carol.fran"
            , Insert "married.dave.eve"
            ]
      spousesOf st "fran" @?= ["married.fran.carol"]
      spousesOf st "carol" @?= ["married.carol.fran"]
      askChronicle st "spouses of fran" @?= ["fran spouse carol"]
      askChronicle st "spouses of carol" @?= ["carol spouse fran"]
      askChronicle st "spouses of void" @?= ["void has no known spouses"]

  , testCase "askChronicle creditors/debtors dual Host raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "debt.ira.bob.favor"
            , Insert "debt.gale.bob.church-favor"
            , Insert "debt.ira.dave.favor"
            ]
      creditorsOf st "bob" @?=
        ["debt.gale.bob.church-favor", "debt.ira.bob.favor"]
      debtorsOf st "ira" @?= ["debt.ira.bob.favor", "debt.ira.dave.favor"]
      askChronicle st "creditors of bob" @?=
        ["gale creditor of bob", "ira creditor of bob"]
      askChronicle st "debtors of ira" @?=
        ["ira creditor of bob", "ira creditor of dave"]
      askChronicle st "creditors of void" @?= ["void has no known creditors"]
      askChronicle st "debtors of void" @?= ["void has no known debtors"]

  , testCase "askChronicle demanders/demandees dual Host raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "demanded.ira.bob.favor"
            , Insert "demanded.gale.bob.church-favor"
            , Insert "demanded.ira.dave.favor"
            ]
      demandersOf st "bob" @?=
        ["demanded.gale.bob.church-favor", "demanded.ira.bob.favor"]
      demandeesOf st "ira" @?=
        ["demanded.ira.bob.favor", "demanded.ira.dave.favor"]
      askChronicle st "demanders of bob" @?=
        ["gale demander of bob", "ira demander of bob"]
      askChronicle st "demandees of ira" @?=
        ["ira demander of bob", "ira demander of dave"]
      askChronicle st "demanders of void" @?= ["void has no known demanders"]
      askChronicle st "demandees of void" @?= ["void has no known demandees"]


  , testCase "askChronicle threateners/threatenees/extorters/extortees dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "threatened.sid1.ana.ben"
            , Insert "threatened.sid2.cai.ana"
            , Insert "ana.extorted.ben.sid1"
            , Insert "dai.extorted.ana.sid3"
            ]
      threatenersOf st "ben" @?= ["threatened.sid1.ana.ben"]
      threateneesOf st "ana" @?= ["threatened.sid1.ana.ben"]
      extortersOf st "ben" @?= ["ana.extorted.ben.sid1"]
      extorteesOf st "ana" @?= ["ana.extorted.ben.sid1"]
      askChronicle st "threateners of ben" @?= ["ana threatener of ben"]
      askChronicle st "threatenees of ana" @?= ["ana threatener of ben"]
      askChronicle st "extorters of ben" @?= ["ana extorter of ben"]
      askChronicle st "extortees of ana" @?= ["ana extorter of ben"]
      askChronicle st "threateners of void" @?= ["void has no known threateners"]
      askChronicle st "threatenees of void" @?= ["void has no known threatenees"]
      askChronicle st "extorters of void" @?= ["void has no known extorters"]
      askChronicle st "extortees of void" @?= ["void has no known extortees"]



  , testCase "askChronicle compliers/compliees/defiers/defiees dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "complied.sid1.ana.ben"
            , Insert "complied.sid2.cai.ana"
            , Insert "defied.sid3.ben.ana"
            , Insert "defied.sid4.ana.dai"
            ]
      compliersOf st "ana" @?= ["complied.sid1.ana.ben"]
      complieesOf st "ben" @?= ["complied.sid1.ana.ben"]
      defiersOf st "ana" @?= ["defied.sid3.ben.ana"]
      defieesOf st "ben" @?= ["defied.sid3.ben.ana"]
      askChronicle st "compliers of ana" @?= ["ben complier of ana"]
      askChronicle st "compliees of ben" @?= ["ben complier of ana"]
      askChronicle st "defiers of ana" @?= ["ben defier of ana"]
      askChronicle st "defiees of ben" @?= ["ben defier of ana"]
      askChronicle st "compliers of void" @?= ["void has no known compliers"]
      askChronicle st "compliees of void" @?= ["void has no known compliees"]
      askChronicle st "defiers of void" @?= ["void has no known defiers"]
      askChronicle st "defiees of void" @?= ["void has no known defiees"]



  , testCase "askChronicle wrongers/wrongees dual Host raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "wronged.alice.bob"
            , Insert "wronged.bob.carol"
            ]
      wrongersOf st "bob" @?= ["wronged.alice.bob"]
      wrongeesOf st "alice" @?= ["wronged.alice.bob"]
      askChronicle st "wrongers of bob" @?= ["alice wronger of bob"]
      askChronicle st "wrongees of alice" @?= ["alice wronger of bob"]
      askChronicle st "wrongers of void" @?= ["void has no known wrongers"]
      askChronicle st "wrongees of void" @?= ["void has no known wrongees"]



  , testCase "askChronicle eyers/eyees/confronters/confrontees dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "eyed.dana.bob"
            , Insert "eyed.bob.eve"
            , Insert "confronted.carol.bob"
            , Insert "confronted.bob.gale"
            ]
      eyersOf st "bob" @?= ["eyed.dana.bob"]
      eyeesOf st "dana" @?= ["eyed.dana.bob"]
      confrontersOf st "bob" @?= ["confronted.carol.bob"]
      confronteesOf st "carol" @?= ["confronted.carol.bob"]
      askChronicle st "eyers of bob" @?= ["dana eyer of bob"]
      askChronicle st "eyees of dana" @?= ["dana eyer of bob"]
      askChronicle st "confronters of bob" @?= ["carol confronter of bob"]
      askChronicle st "confrontees of carol" @?= ["carol confronter of bob"]
      askChronicle st "eyers of void" @?= ["void has no known eyers"]
      askChronicle st "eyees of void" @?= ["void has no known eyees"]
      askChronicle st "confronters of void" @?= ["void has no known confronters"]
      askChronicle st "confrontees of void" @?= ["void has no known confrontees"]


  , testCase "askChronicle revokers/revokees dual Host raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "revoked.ira.bob"
            , Insert "revoked.bob.dave"
            ]
      revokersOf st "bob" @?= ["revoked.ira.bob"]
      revokeesOf st "ira" @?= ["revoked.ira.bob"]
      askChronicle st "revokers of bob" @?= ["ira revoker of bob"]
      askChronicle st "revokees of ira" @?= ["ira revoker of bob"]
      askChronicle st "revokers of void" @?= ["void has no known revokers"]
      askChronicle st "revokees of void" @?= ["void has no known revokees"]



  , testCase "askChronicle ostracizers..paradees dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ostracized.ira.bob"
            , Insert "denounced.gale.eve"
            , Insert "censured.ira.bob"
            , Insert "paraded.gale.eve"
            ]
      ostracizersOf st "bob" @?= ["ostracized.ira.bob"]
      ostracizeesOf st "ira" @?= ["ostracized.ira.bob"]
      denouncersOf st "eve" @?= ["denounced.gale.eve"]
      denounceesOf st "gale" @?= ["denounced.gale.eve"]
      censurersOf st "bob" @?= ["censured.ira.bob"]
      censureesOf st "ira" @?= ["censured.ira.bob"]
      paradersOf st "eve" @?= ["paraded.gale.eve"]
      paradeesOf st "gale" @?= ["paraded.gale.eve"]
      askChronicle st "ostracizers of bob" @?= ["ira ostracizer of bob"]
      askChronicle st "ostracizees of ira" @?= ["ira ostracizer of bob"]
      askChronicle st "denouncers of eve" @?= ["gale denouncer of eve"]
      askChronicle st "denouncees of gale" @?= ["gale denouncer of eve"]
      askChronicle st "censurers of bob" @?= ["ira censurer of bob"]
      askChronicle st "censurees of ira" @?= ["ira censurer of bob"]
      askChronicle st "paraders of eve" @?= ["gale parader of eve"]
      askChronicle st "paradees of gale" @?= ["gale parader of eve"]
      askChronicle st "ostracizers of void" @?= ["void has no known ostracizers"]
      askChronicle st "paradees of void" @?= ["void has no known paradees"]


  , testCase "askChronicle criers/criees/ralliers/ralliees dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "cried.bob.ira"
            , Insert "rallied.fran.bob"
            ]
      criersOf st "ira" @?= ["cried.bob.ira"]
      crieesOf st "bob" @?= ["cried.bob.ira"]
      ralliersOf st "bob" @?= ["rallied.fran.bob"]
      rallieesOf st "fran" @?= ["rallied.fran.bob"]
      askChronicle st "criers of ira" @?= ["bob crier of ira"]
      askChronicle st "criees of bob" @?= ["bob crier of ira"]
      askChronicle st "ralliers of bob" @?= ["fran rallier of bob"]
      askChronicle st "ralliees of fran" @?= ["fran rallier of bob"]
      askChronicle st "criers of void" @?= ["void has no known criers"]
      askChronicle st "ralliees of void" @?= ["void has no known ralliees"]


  , testCase "askChronicle allies dual Host alliesOf raw leaves" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "allied.bob.fran"
            , Insert "allied.fran.bob"
            , Insert "allied.eve.gale"
            ]
      alliesOf st "bob" @?= ["allied.bob.fran"]
      alliesOf st "fran" @?= ["allied.fran.bob"]
      askChronicle st "allies of bob" @?= ["bob ally fran"]
      askChronicle st "allies of fran" @?= ["fran ally bob"]
      askChronicle st "allies of void" @?= ["void has no known allies"]



  , testCase "askChronicle resenters/shunners dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "resents.bob.ira"
            , Insert "resents.eve.bob"
            , Insert "shunned.gale.fran"
            , Insert "shunned.bob.eve"
            ]
      resentersOf st "ira" @?= ["resents.bob.ira"]
      shunnersOf st "fran" @?= ["shunned.gale.fran"]
      askChronicle st "resenters of ira" @?= ["bob resenter of ira"]
      askChronicle st "resenters of bob" @?= ["eve resenter of bob"]
      askChronicle st "shunners of fran" @?= ["gale shunner of fran"]
      askChronicle st "shunners of eve" @?= ["bob shunner of eve"]
      askChronicle st "resenters of void" @?= ["void has no known resenters"]
      askChronicle st "shunners of void" @?= ["void has no known shunners"]



  , testCase "askChronicle esteemers/scorners dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "esteemed.ana.ben.hero"
            , Insert "esteemed.cass.ben"
            , Insert "scorned.ana.dave.thief"
            , Insert "scorned.ben.dave"
            ]
      esteemersOf st "ben" @?= ["esteemed.ana.ben.hero", "esteemed.cass.ben"]
      scornersOf st "dave" @?= ["scorned.ana.dave.thief", "scorned.ben.dave"]
      askChronicle st "esteemers of ben" @?=
        ["ana esteemer of ben", "cass esteemer of ben"]
      askChronicle st "scorners of dave" @?=
        ["ana scorner of dave", "ben scorner of dave"]
      askChronicle st "esteemers of void" @?= ["void has no known esteemers"]
      askChronicle st "scorners of void" @?= ["void has no known scorners"]



  , testCase "askChronicle bonders/liars dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "bond.ana.ben.friends"
            , Insert "bond.cass.ben"
            , Insert "eve.lied.dana.stole.carol.loaf"
            , Insert "nia.lied.dana.took.kit.gem"
            ]
      bondersOf st "ben" @?= ["bond.ana.ben.friends", "bond.cass.ben"]
      liarsOf st "dana" @?=
        ["eve.lied.dana.stole.carol.loaf", "nia.lied.dana.took.kit.gem"]
      askChronicle st "bonders of ben" @?=
        ["ana bonder of ben", "cass bonder of ben"]
      askChronicle st "liars of dana" @?=
        ["eve liar of dana", "nia liar of dana"]
      askChronicle st "bonders of void" @?= ["void has no known bonders"]
      askChronicle st "liars of void" @?= ["void has no known liars"]

  , testCase "askChronicle chatters dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ana.chattedWith.ben"
            , Insert "cass.chattedWith.ben"
            , Insert "dave.chattedWith.eve"
            ]
      chattersOf st "ben" @?= ["ana.chattedWith.ben", "cass.chattedWith.ben"]
      askChronicle st "chatters of ben" @?=
        ["ana chatter of ben", "cass chatter of ben"]
      askChronicle st "chatters of eve" @?= ["dave chatter of eve"]
      askChronicle st "chatters of void" @?= ["void has no known chatters"]

  , testCase "askChronicle occupants dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "at.ana!yard"
            , Insert "at.ben!yard"
            , Insert "at.cass!market"
            ]
      occupantsOf st "yard" @?= ["at.ana.yard", "at.ben.yard"]
      askChronicle st "occupants of yard" @?=
        ["ana at yard", "ben at yard"]
      askChronicle st "occupants of market" @?= ["cass at market"]
      askChronicle st "occupants of void" @?= ["nobody is at void"]

  , testCase "askChronicle holders/carriers dual Host" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "holding.ana.loaf"
            , Insert "holding.ben.loaf"
            , Insert "carrying.cass.flour"
            , Insert "carrying.dave.flour"
            ]
      holdersOf st "loaf" @?= ["holding.ana.loaf", "holding.ben.loaf"]
      carriersOf st "flour" @?= ["carrying.cass.flour", "carrying.dave.flour"]
      askChronicle st "holders of loaf" @?=
        ["ana holder of loaf", "ben holder of loaf"]
      askChronicle st "carriers of flour" @?=
        ["cass carrier of flour", "dave carrier of flour"]
      askChronicle st "holders of void" @?= ["nobody holds void"]
      askChronicle st "carriers of void" @?= ["nobody carries void"]

  , testCase "affiliatorsOf / affiliators of dual" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "affiliate.ana.guild"
            , Insert "affiliate.ben.guild"
            , Insert "affiliate.ana.choir"
            ]
      sort (affiliatorsOf st "guild") @?= ["ana", "ben"]
      affiliatorsOf st "choir" @?= ["ana"]
      affiliatorsOf st "void" @?= []
      askChronicle st "affiliators of guild" @?=
        ["ana affiliates guild", "ben affiliates guild"]
      askChronicle st "affiliators of choir" @?=
        ["ana affiliates choir"]
      askChronicle st "affiliators of void" @?=
        ["no one affiliates with void"]

  , testCase "practitionersOf / practitioners of dual" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "practice.bake.ana"
            , Insert "practice.bake.ana.crew.ben"
            , Insert "practice.hunt.ben.did.track"
            ]
      sort (practitionersOf st "bake") @?=
        [ "practice.bake.ana"
        , "practice.bake.ana.crew.ben"
        ]
      practitionersOf st "hunt" @?= ["practice.hunt.ben.did.track"]
      practitionersOf st "void" @?= []
      askChronicle st "practitioners of bake" @?=
        [ "practice.bake.ana"
        , "practice.bake.ana.crew.ben"
        ]
      askChronicle st "practitioners of hunt" @?=
        ["practice.hunt.ben.did.track"]
      askChronicle st "practitioners of void" @?=
        ["no one is in practice void"]

  , testCase "believersOf / believers of dual" $ do
      let st = foldl (flip performOutcome) emptyState
            [ Insert "ana.believes.at.ben.yard"
            , Insert "ben.believes.flag.x"
            , Insert "cass.believes.flag.x"
            ]
      believersOf st "flag.x" @?= ["ben.believes.flag.x", "cass.believes.flag.x"]
      believersOf st "at.ben.yard" @?= ["ana.believes.at.ben.yard"]
      believersOf st "void" @?= []
      askChronicle st "believers of flag.x" @?=
        ["ben.believes.flag.x", "cass.believes.flag.x"]
      askChronicle st "believers of at.ben.yard" @?=
        ["ana.believes.at.ben.yard"]
      askChronicle st "believers of void" @?=
        ["no one believes void"]

  ]
