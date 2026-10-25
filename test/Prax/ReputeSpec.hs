module Prax.ReputeSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (definePractices, defineFunctions, performOutcome, possibleActions, performAction, setAxioms, setCharacters)
import           Prax.Core (coreFns)
import           Prax.Derive (Axiom (..))
import           Prax.Repute

-- The tale: kai is believed (variously) to have kicked the dog. Standing is
-- derived from the evidence, defeated by forgiveness, and notorious at two.
world :: PraxState
world = setAxioms [ standingUnless "kicked.Brute.dog" "forgiven.Brute" "brute"
                   , notoriety "brute" 2 ]
                   (foldl (flip performOutcome) base setup)
  where
    base = setCharacters (map character ["ana", "ben", "kai"])
             (definePractices [p] emptyState)
    -- an affordance gated on the DERIVED standing: preconditions read the view
    p = practice
      { practiceId = "yard", roles = ["R"]
      , actions = [ action "[Actor]: scowl at [B]"
                      [ regardedAs "Actor" "B" "brute", Not "scowled.Actor.B" ]
                      [ Insert "scowled.Actor.B" ] ] }
    setup =
      [ Insert "practice.yard.here"
      , Insert "ana.believes.kicked.kai.dog.seen"
      , Insert "ben.believes.kicked.kai.dog.heard.ana" ]

tests :: TestTree
tests = testGroup "Prax.Repute"
  [ testCase "evidence derives per-observer standing (seen and heard alike)" $ do
      let v = readView world
      assertBool "ana (eyewitness) regards kai a brute" (exists "regards.ana.kai.brute" v)
      assertBool "ben (hearsay) regards kai a brute"    (exists "regards.ben.kai.brute" v)
      assertBool "kai holds no self-regard"             (not (exists "regards.kai.kai.brute" v))

  , testCase "notoriety holds at the threshold, not below" $ do
      assertBool "two regarders: notorious" (exists "notorious.kai.brute" (readView world))
      let one = performOutcome (Delete "ben.believes.kicked.kai.dog") world
      assertBool "one regarder: not notorious"
        (not (exists "notorious.kai.brute" (readView one)))
      assertBool "and ben's regard dissolved with his evidence"
        (not (exists "regards.ben.kai.brute" (readView one)))

  , testCase "the defeater dissolves standing while memory persists" $ do
      let f = performOutcome (Insert "forgiven.kai") world
          v = readView f
      assertBool "no regard survives forgiveness"   (not (exists "regards.ana.kai.brute" v))
      assertBool "no notoriety survives"            (not (exists "notorious.kai.brute" v))
      assertBool "ana still remembers what she saw" (exists "ana.believes.kicked.kai.dog.seen" (db f))

  , testCase "a derived-standing-gated affordance appears and disappears" $ do
      assertBool "ana may scowl at kai"
        (any (("scowl at kai" `isInfixOf`) . gaLabel) (possibleActions world "ana"))
      let f = performOutcome (Insert "forgiven.kai") world
      assertBool "forgiven: the scowl is gone"
        (not (any (("scowl at kai" `isInfixOf`) . gaLabel) (possibleActions f "ana")))

  , testCase "regardedAs is the standing condition" $
      regardedAs "W" "kai" "brute" @?= Match "regards.W.kai.brute"

  , testCase "the deed pattern's FIRST variable is the subject" $
      axiomThen (standing "sold.Seller.Buyer.secret" "snitch")
        @?= [ "regards.Regarder.Seller.snitch" ]

  , testCase "a deed pattern with no variable errors loudly" $ do
      r <- try (evaluate (length (show (standing "somethinghappened" "x"))))
      assertBool "standing on a subject-less pattern is an error"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "a defeater variable outside the deed pattern errors loudly" $ do
      r <- try (evaluate (length (show
             (standingUnless "stole.Culprit.loaf" "atoned.Someone" "thief"))))
      assertBool "mis-scoped defeater is an error, not a silent global amnesty"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "standing: a deed pattern authoring Regarder (the axiom's own observer variable) errors loudly" $ do
      r <- try (evaluate (length (show (standing "kicked.Regarder.dog" "brute"))))
      assertBool "Regarder is reserved -- the axiom's own observer join variable"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "standing: a deed pattern authoring the Prax namespace errors loudly" $ do
      r <- try (evaluate (length (show (standing "kicked.PraxX.dog" "brute"))))
      assertBool "the Prax namespace is reserved"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "standingUnless: Regarder is reserved through the same guard (both entry points funnel through it)" $ do
      r <- try (evaluate (length (show
             (standingUnless "stole.Regarder.loaf" "atoned.Regarder" "thief"))))
      assertBool "Regarder is reserved for standingUnless too"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "scornStanding: regard gates a one-shot score drop" $ do
      let base = defineFunctions coreFns
                   (setAxioms [ standing "kicked.Brute.dog" "brute" ]
                     (setCharacters (map character ["ana", "kai"])
                       (definePractices [p] emptyState)))
          p = practice
            { practiceId = "yard", roles = ["R"]
            , actions = [ scornStanding "brute" "warmth" (-8) "regardedBrute" ] }
          st0 = foldl (flip performOutcome) base
                  [ Insert "practice.yard.here"
                  , Insert "ana.believes.kicked.kai.dog.seen" ]
      assertBool "scorn offered while regard holds"
        (any (("scorn kai as brute" `isInfixOf`) . gaLabel) (possibleActions st0 "ana"))
      let st1 = case [ ga | ga <- possibleActions st0 "ana"
                          , "scorn kai as brute" `isInfixOf` gaLabel ga ] of
                  (ga:_) -> performAction st0 ga
                  []     -> error "no scorn"
      assertBool "score seeded negative"
        (exists "ana.relationship.kai.warmth.score!-8" (db st1))
      assertBool "one-shot guard planted"
        (exists "scorned.ana.kai.brute" (db st1))
      assertBool "scorn not re-offered"
        (not (any (("scorn kai as brute" `isInfixOf`) . gaLabel)
                  (possibleActions st1 "ana")))

  , testCase "scornDesire names the scorns-<label> desire" $
      let Desire n _ = scornDesire "ana" "brute" 4
      in n @?= "scorns-brute"

  , testCase "esteemDesire names the esteems-<label> desire" $
      let Desire n _ = esteemDesire "ana" "hero" 3
      in n @?= "esteems-hero"

  , testCase "isNotorious matches notorious.<subject>.<label>" $
      isNotorious "dell" "deadbeat" @?= Match "notorious.dell.deadbeat"

  , testCase "hasEsteemed matches esteemed.<observer>.<subject>.<label>" $
      hasEsteemed "ann" "ben" "hero" @?= Match "esteemed.ann.ben.hero"

  , testCase "esteemStanding: regard gates a one-shot score rise" $ do
      let base = defineFunctions coreFns
                   (setAxioms [ standing "saved.Hero.child" "hero" ]
                     (setCharacters (map character ["ana", "kai"])
                       (definePractices [p] emptyState)))
          p = practice
            { practiceId = "yard", roles = ["R"]
            , actions = [ esteemStanding "hero" "warmth" 5 "regardedHero" ] }
          st0 = foldl (flip performOutcome) base
                  [ Insert "practice.yard.here"
                  , Insert "ana.believes.saved.kai.child.seen" ]
      assertBool "esteem offered while regard holds"
        (any (("esteem kai as hero" `isInfixOf`) . gaLabel) (possibleActions st0 "ana"))
      let st1 = case [ ga | ga <- possibleActions st0 "ana"
                          , "esteem kai as hero" `isInfixOf` gaLabel ga ] of
                  (ga:_) -> performAction st0 ga
                  []     -> error "no esteem"
      assertBool "score seeded positive"
        (exists "ana.relationship.kai.warmth.score!5" (db st1))
      assertBool "one-shot guard planted"
        (exists "esteemed.ana.kai.hero" (db st1))
      assertBool "esteem not re-offered"
        (not (any (("esteem kai as hero" `isInfixOf`) . gaLabel)
                  (possibleActions st1 "ana")))
  , testCase "lacksEsteemed is Not of esteemed path" $
      lacksEsteemed "ana" "bob" "hero" @?= Not "esteemed.ana.bob.hero"


  , testCase "lacksNotorious / hasScorned / lacksScorned duals" $ do
      lacksNotorious "kai" "brute" @?= Not "notorious.kai.brute"
      hasScorned "ana" "kai" "brute" @?= Match "scorned.ana.kai.brute"
      lacksScorned "ana" "kai" "brute" @?= Not "scorned.ana.kai.brute"


  , testCase "everNotorious / neverNotorious are Exists/Absent over labels" $ do
      everNotorious "kai" @?= Exists [ Match "notorious.kai.Label" ]
      neverNotorious "kai" @?= Absent [ Match "notorious.kai.Label" ]
  ]
