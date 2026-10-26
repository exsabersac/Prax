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


  , testCase "leadersOf lists leads.<faction>.<who> from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "leads.hall!ana"
                , Insert "leads.yard!ben" ]
      leadersOf st "hall" @?= ["ana"]
      leadersOf st "yard" @?= ["ben"]
      leadersOf st "void" @?= []

  , testCase "debtsOf lists debt leaves involving who" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "debt.ana.ben.favor"
                , Insert "debt.cass.ana.coin"
                , Insert "debt.dave.eve.secret" ]
      sort (debtsOf st "ana") @?= ["debt.ana.ben.favor", "debt.cass.ana.coin"]
      debtsOf st "dave" @?= ["debt.dave.eve.secret"]
      debtsOf st "void" @?= []

  , testCase "obligationsOf lists obliged.<who>.* from the closed view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "obliged.ana.settle.up"
                , Insert "obliged.ana.whenAt.bar.greet.ben"
                , Insert "obliged.ben.tip.carol"
                , Insert "flag.x" ]
      sort (obligationsOf st "ana") @?=
        ["obliged.ana.settle.up", "obliged.ana.whenAt.bar.greet.ben"]
      obligationsOf st "ben" @?= ["obliged.ben.tip.carol"]
      obligationsOf st "void" @?= []

  , testCase "breachesOf lists violated.<who>.* from the closed view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "violated.ana.tipping"
                , Insert "violated.ana.queue"
                , Insert "violated.ben.courtesy"
                , Insert "flag.x" ]
      sort (breachesOf st "ana") @?= ["violated.ana.queue", "violated.ana.tipping"]
      breachesOf st "ben" @?= ["violated.ben.courtesy"]
      breachesOf st "void" @?= []

  , testCase "feelingsOf / liesOf / chattedWithOf list who-prefixed leaves" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "ana.feels.angry.toward.ben"
                , Insert "ana.feels.afraid"
                , Insert "ben.feels.happy"
                , Insert "ana.lied.ben.stole.loaf"
                , Insert "ana.chattedWith.ben"
                , Insert "cass.chattedWith.ana"
                , Insert "flag.x" ]
      sort (feelingsOf st "ana") @?= ["ana.feels.afraid", "ana.feels.angry.toward.ben"]
      feelingsOf st "ben" @?= ["ben.feels.happy"]
      liesOf st "ana" @?= ["ana.lied.ben.stole.loaf"]
      liesOf st "void" @?= []
      chattedWithOf st "ana" @?= ["ana.chattedWith.ben"]
      chattedWithOf st "cass" @?= ["cass.chattedWith.ana"]

  , testCase "regardsToward / factionsNamed from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "regards.dave.bob.thief"
                , Insert "regards.fran.bob.thief"
                , Insert "regards.dave.eve.hero"
                , Insert "member.dave.mill"
                , Insert "affiliate.fran.choir"
                , Insert "leads.guild!ana" ]
      regardsToward st "bob" @?= ["regards.dave.bob.thief", "regards.fran.bob.thief"]
      regardsToward st "eve" @?= ["regards.dave.eve.hero"]
      factionsNamed st @?= ["choir", "guild", "mill"]

  , testCase "traitsOf / moodsOf / bondsOf / kinOf / notoriousOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "trait.ana.brave"
                , Insert "trait.ana.stubborn"
                , Insert "trait.ben.shy"
                , Insert "mood.ana!calm"
                , Insert "mood.ben!angry"
                , Insert "bond.ana.ben.friends"
                , Insert "bond.cass.dave.rivals"
                , Insert "married.ana.ben"
                , Insert "parent.ana.cara"
                , Insert "sibling.ben.dave"
                , Insert "notorious.ana.thief"
                , Insert "notorious.ben.liar"
                , Insert "flag.x" ]
      sort (traitsOf st "ana") @?= ["trait.ana.brave", "trait.ana.stubborn"]
      traitsOf st "ben" @?= ["trait.ben.shy"]
      traitsOf st "void" @?= []
      moodsOf st "ana" @?= ["mood.ana.calm"]
      moodsOf st "ben" @?= ["mood.ben.angry"]
      bondsOf st "ana" @?= ["bond.ana.ben.friends"]
      bondsOf st "cass" @?= ["bond.cass.dave.rivals"]
      sort (kinOf st "ana") @?= ["married.ana.ben", "parent.ana.cara"]
      sort (kinOf st "ben") @?= ["married.ana.ben", "sibling.ben.dave"]
      kinOf st "cara" @?= ["parent.ana.cara"]
      notoriousOf st "ana" @?= ["notorious.ana.thief"]
      notoriousOf st "ben" @?= ["notorious.ben.liar"]
      notoriousOf st "void" @?= []

  , testCase "esteemedOf / scornedOf / beliefsOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "esteemed.ana.ben.hero"
                , Insert "esteemed.ana.cass.sage"
                , Insert "scorned.ana.dave.thief"
                , Insert "scorned.ben.dave.thief"
                , Insert "ana.believes.at.ben.yard"
                , Insert "ana.believes.stole.loaf.seen"
                , Insert "ben.believes.flag.x"
                , Insert "flag.x" ]
      sort (esteemedOf st "ana") @?= ["esteemed.ana.ben.hero", "esteemed.ana.cass.sage"]
      esteemedOf st "void" @?= []
      scornedOf st "ana" @?= ["scorned.ana.dave.thief"]
      scornedOf st "ben" @?= ["scorned.ben.dave.thief"]
      sort (beliefsOf st "ana") @?=
        ["ana.believes.at.ben.yard", "ana.believes.stole.loaf.seen"]
      beliefsOf st "ben" @?= ["ben.believes.flag.x"]
      beliefsOf st "void" @?= []

  , testCase "arcsOf / agesOf / projectsOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "ana.arc!hopeful"
                , Insert "ben.arc!bitter"
                , Insert "age.ana!32"
                , Insert "age.ben!18"
                , Insert "practice.bake.ana"
                , Insert "practice.bake.ana.did.mix"
                , Insert "practice.bake.ana.crew.ben"
                , Insert "practice.hunt.ben.did.track"
                , Insert "flag.x" ]
      arcsOf st "ana" @?= ["ana.arc.hopeful"]
      arcsOf st "ben" @?= ["ben.arc.bitter"]
      arcsOf st "void" @?= []
      agesOf st "ana" @?= ["age.ana.32"]
      agesOf st "ben" @?= ["age.ben.18"]
      sort (projectsOf st "ana") @?=
        [ "practice.bake.ana"
        , "practice.bake.ana.crew.ben"
        , "practice.bake.ana.did.mix"
        ]
      projectsOf st "ben" @?= ["practice.hunt.ben.did.track"]
      projectsOf st "void" @?= []
  
  , testCase "demandedOf / festivalsOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "demanded.ana.ben.favor"
                , Insert "demanded.cai.ana.coin"
                , Insert "festival.harvest"
                , Insert "festival.midwinter"
                , Insert "flag.x" ]
      sort (demandedOf st "ana") @?=
        [ "demanded.ana.ben.favor"
        , "demanded.cai.ana.coin"
        ]
      demandedOf st "ben" @?= ["demanded.ana.ben.favor"]
      demandedOf st "void" @?= []
      festivalsOf st @?= ["festival.harvest", "festival.midwinter"]
      festivalsOf emptyState @?= []

  , testCase "locationsOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "at.ana!yard"
                , Insert "at.ben!market"
                , Insert "flag.x" ]
      locationsOf st "ana" @?= ["at.ana.yard"]
      locationsOf st "ben" @?= ["at.ben.market"]
      locationsOf st "void" @?= []
  , testCase "holdingOf / carryingOf / shunnedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "holding.ana.loaf"
                , Insert "carrying.ben.flour"
                , Insert "shunned.cai.T"
                , Insert "flag.x" ]
      holdingOf st "ana" @?= ["holding.ana.loaf"]
      holdingOf st "void" @?= []
      carryingOf st "ben" @?= ["carrying.ben.flour"]
      carryingOf st "void" @?= []
      shunnedOf st "cai" @?= ["shunned.cai.T"]
      shunnedOf st "void" @?= []

  , testCase "threatenedOf / extortedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "threatened.sid1.ana.ben"
                , Insert "threatened.sid2.cai.ana"
                , Insert "ana.extorted.ben.sid1"
                , Insert "dai.extorted.ana.sid3"
                , Insert "flag.x" ]
      threatenedOf st "ana" @?=
        [ "threatened.sid1.ana.ben"
        , "threatened.sid2.cai.ana"
        ]
      threatenedOf st "void" @?= []
      extortedOf st "ana" @?=
        [ "ana.extorted.ben.sid1"
        , "dai.extorted.ana.sid3"
        ]
      extortedOf st "void" @?= []

  , testCase "compliedOf / defiedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "complied.sid1.ana.ben"
                , Insert "complied.sid2.cai.ana"
                , Insert "defied.sid3.ben.ana"
                , Insert "defied.sid4.ana.dai"
                , Insert "flag.x" ]
      compliedOf st "ana" @?=
        [ "complied.sid1.ana.ben"
        , "complied.sid2.cai.ana"
        ]
      compliedOf st "void" @?= []
      defiedOf st "ana" @?=
        [ "defied.sid3.ben.ana"
        , "defied.sid4.ana.dai"
        ]
      defiedOf st "void" @?= []

  , testCase "brandedOf / revokedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "branded.bob"
                , Insert "brandedHeretic.eve"
                , Insert "branded.ana"
                , Insert "revoked.ira.bob"
                , Insert "revoked.gale.eve"
                , Insert "revoked.bob.dave"
                , Insert "flag.x" ]
      brandedOf st "bob" @?= ["branded.bob"]
      brandedOf st "eve" @?= ["brandedHeretic.eve"]
      brandedOf st "void" @?= []
      revokedOf st "bob" @?=
        [ "revoked.bob.dave"
        , "revoked.ira.bob"
        ]
      revokedOf st "void" @?= []

  , testCase "confessedOf / recantedOf / ostracizedOf / exiledOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "confessed.bob"
                , Insert "ana.confessed.H.stole.C.loaf"
                , Insert "recanted.eve"
                , Insert "ostracized.dana.bob"
                , Insert "ostracized.bob.carol"
                , Insert "exiled.bob"
                , Insert "flag.x" ]
      confessedOf st "bob" @?= ["confessed.bob"]
      confessedOf st "ana" @?= ["ana.confessed.H.stole.C.loaf"]
      confessedOf st "void" @?= []
      recantedOf st "eve" @?= ["recanted.eve"]
      recantedOf st "void" @?= []
      ostracizedOf st "bob" @?=
        [ "ostracized.bob.carol"
        , "ostracized.dana.bob"
        ]
      ostracizedOf st "void" @?= []
      exiledOf st "bob" @?= ["exiled.bob"]
      exiledOf st "void" @?= []

  , testCase "denouncedOf / censuredOf / paradedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "denounced.dave.bob"
                , Insert "denounced.bob.carol"
                , Insert "censured.priest.eve"
                , Insert "censured.gale.bob"
                , Insert "paraded.dave.bob"
                , Insert "paraded.priest.eve"
                , Insert "flag.x" ]
      denouncedOf st "bob" @?=
        [ "denounced.bob.carol"
        , "denounced.dave.bob"
        ]
      denouncedOf st "void" @?= []
      censuredOf st "bob" @?= ["censured.gale.bob"]
      censuredOf st "eve" @?= ["censured.priest.eve"]
      censuredOf st "void" @?= []
      paradedOf st "bob" @?= ["paraded.dave.bob"]
      paradedOf st "eve" @?= ["paraded.priest.eve"]
      paradedOf st "void" @?= []

  , testCase "criedOf / ralliedOf / fledOf / reconciledOf / marriedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "cried.dave.bob"
                , Insert "cried.bob.carol"
                , Insert "rallied.dave.bob"
                , Insert "rallied.ira.bob"
                , Insert "fled.carol"
                , Insert "reconciled.carol"
                , Insert "married.fran.carol"
                , Insert "married.dave.eve"
                , Insert "flag.x" ]
      criedOf st "bob" @?=
        [ "cried.bob.carol"
        , "cried.dave.bob"
        ]
      criedOf st "void" @?= []
      ralliedOf st "bob" @?=
        [ "rallied.dave.bob"
        , "rallied.ira.bob"
        ]
      ralliedOf st "void" @?= []
      fledOf st "carol" @?= ["fled.carol"]
      fledOf st "void" @?= []
      reconciledOf st "carol" @?= ["reconciled.carol"]
      reconciledOf st "void" @?= []
      marriedOf st "fran" @?= ["married.fran.carol"]
      marriedOf st "carol" @?= ["married.fran.carol"]
      marriedOf st "dave" @?= ["married.dave.eve"]
      marriedOf st "void" @?= []

  , testCase "eyedOf / confrontedOf / atonedOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "eyed.dana.bob"
                , Insert "eyed.bob.eve"
                , Insert "confronted.carol.bob"
                , Insert "confronted.bob.gale"
                , Insert "atoned.bob"
                , Insert "flag.x" ]
      eyedOf st "bob" @?=
        [ "eyed.bob.eve"
        , "eyed.dana.bob"
        ]
      eyedOf st "void" @?= []
      confrontedOf st "bob" @?=
        [ "confronted.bob.gale"
        , "confronted.carol.bob"
        ]
      confrontedOf st "void" @?= []
      atonedOf st "bob" @?= ["atoned.bob"]
      atonedOf st "void" @?= []

  , testCase "wrongedOf / hungryOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "wronged.alice.bob"
                , Insert "wronged.bob.carol"
                , Insert "hungry.bob"
                , Insert "flag.x" ]
      wrongedOf st "bob" @?=
        [ "wronged.alice.bob"
        , "wronged.bob.carol"
        ]
      wrongedOf st "void" @?= []
      hungryOf st "bob" @?= ["hungry.bob"]
      hungryOf st "void" @?= []

  , testCase "shortTemperedOf / appetiteOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "shortTempered.carol"
                , Insert "appetite.bob"
                , Insert "flag.x" ]
      shortTemperedOf st "carol" @?= ["shortTempered.carol"]
      shortTemperedOf st "void" @?= []
      appetiteOf st "bob" @?= ["appetite.bob"]
      appetiteOf st "void" @?= []

  , testCase "resentsOf from the view" $ do
      let st = foldl (flip performOutcome) emptyState
                [ Insert "resents.bob.alice"
                , Insert "resents.carol.alice"
                , Insert "resents.bob.dave"
                , Insert "flag.x" ]
      resentsOf st "bob" @?=
        [ "resents.bob.alice"
        , "resents.bob.dave"
        ]
      resentsOf st "void" @?= []

  ]
