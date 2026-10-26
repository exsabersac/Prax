module Prax.SightSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (Val (..), exists)
import           Prax.Query (Condition (..), groundCondition, query, satisfies)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setCharacters,
                               setSchedule, roundBoundary)
import           Prax.TypeCheck (typeCheck)
import           Prax.Schedule (sightRule)
import           Prax.Sight (sightedWithin, lastKnownAt, unknownWhere, lacksKnownWhere, knownWhere, hasKnownWhere)

-- Two rooms; ute and vic share one, wes is alone in the other.
sighting :: [Condition]
sighting = [ Match "at.Seer!Spot", Match "at.Seen!Spot" ]

world :: PraxState
world = foldl (flip performOutcome) base setup
  where
    -- The engine's period-1 sighting rule (v44): no ticker character; the
    -- rule fires at every round boundary. 'emptyState' seeds turn!0.
    base = setSchedule [ sightRule sighting ]
             (setCharacters (map character ["ute", "vic", "wes"])
                (definePractices [] emptyState))
    setup = [ Insert "at.ute!hall", Insert "at.vic!hall", Insert "at.wes!attic" ]

-- One round boundary = one perception tick: the boundary advances the clock
-- and fires the due period-1 sighting rule.
tick :: PraxState -> PraxState
tick = roundBoundary

tests :: TestTree
tests = testGroup "Prax.Sight"
  [ testCase "the round boundary advances the world turn" $ do
      assertBool "turn 0 at setup" (exists "turn!0" (db world))
      assertBool "turn 1 after a boundary" (exists "turn!1" (db (tick world)))
      assertBool "turn 2 after two" (exists "turn!2" (db (tick (tick world))))

  , testCase "co-presence deposits sightings, both ways; the absent see nothing" $ do
      let st = tick world
      assertBool "ute sighted vic in the hall" (exists "ute.believes.at.vic!hall" (db st))
      assertBool "vic sighted ute" (exists "vic.believes.at.ute!hall" (db st))
      assertBool "stamped with the turn" (exists "ute.believes.atSince.vic!1" (db st))
      assertBool "nobody sighted wes" (not (exists "ute.believes.at.wes" (db st)))
      assertBool "wes sighted nobody" (not (exists "wes.believes.at.ute" (db st)))

  , testCase "a sighting persists after separation, and a new one overwrites it" $ do
      let st1 = tick world                                        -- ute sees vic in hall
          st2 = tick (performOutcome (Insert "at.vic!attic") st1) -- vic left; boundary again
      assertBool "ute still believes vic is in the hall (stale)"
        (exists "ute.believes.at.vic!hall" (db st2))
      assertBool "and the stamp did not refresh" (exists "ute.believes.atSince.vic!1" (db st2))
      -- ute follows and re-sights: overwrite
      let st3 = tick (performOutcome (Insert "at.ute!attic") st2)
      assertBool "belief updated" (exists "ute.believes.at.vic!attic" (db st3))
      assertBool "old belief gone" (not (exists "ute.believes.at.vic!hall" (db st3)))
      assertBool "stamp refreshed" (exists "ute.believes.atSince.vic!3" (db st3))

  , testCase "lastKnownAt matches believes.at exclusive leaf" $
      lastKnownAt "ute" "vic" "hall" @?= Match "ute.believes.at.vic!hall"

  , testCase "sightedWithin is a window over the stamp" $ do
      -- Direct query of the scope fragment, grounded to a fixed Actor/Witness pair.
      let grounded h = map (groundCondition (Map.fromList [ (intern "Actor", VSym (intern "ute"))
                                                            , (intern "Witness", VSym (intern "vic")) ]))
                            (sightedWithin h)
          holds h st = not (null (query (readView st) (grounded h) Map.empty))

          st1 = tick world                                        -- turn 1: ute sights vic
          -- Separate them so later boundaries (which advance the turn) don't
          -- refresh the stamp -- otherwise co-presence would keep re-sighting
          -- every boundary and the window would never lapse.
          st1' = performOutcome (Insert "at.vic!attic") st1
          st2  = tick (tick st1')                                 -- turn 3 = expiry (1+2)
          st3  = tick st2                                         -- turn 4: window lapsed

      assertBool "holds right after the sighting" (holds 2 st1)
      assertBool "still holds at the expiry turn" (holds 2 st2)
      assertBool "fails once the window has lapsed" (not (holds 2 st3))

  , testCase "the fixture world is well-formed" $
      typeCheck world @?= []

  , testGroup "the schedule setter guards the sighting template (re-homed from the v40/v43 sightP guard)"
    [ testCase "a sighting template authoring the Prax namespace is a loud construction-time error" $ do
        r <- try (evaluate (setSchedule [ sightRule [Match "at.PraxN!Spot", Match "at.Seen!Spot"] ] emptyState))
        assertBool "PraxN in the sighting template is rejected" (isLeft (r :: Either ErrorCall PraxState))

    , testCase "Seer/Seen/Spot remain legal -- they are the contract, not forbidden" $ do
        r <- try (evaluate (setSchedule [ sightRule sighting ] emptyState))
        assertBool "the ordinary Seer/Seen/Spot fixture is NOT rejected"
          (not (isLeft (r :: Either ErrorCall PraxState)))

    , testCase "a sighting template authoring Actor is a loud construction-time error" $ do
        r <- try (evaluate (setSchedule [ sightRule [Match "at.Actor!Spot", Match "at.Seen!Spot"] ] emptyState))
        assertBool "Actor in the sighting template is rejected" (isLeft (r :: Either ErrorCall PraxState))
    ]
  , testCase "unknownWhere is Absent of any last-known place leaf" $
      unknownWhere "ute" "vic" @?= Absent [ Match "ute.believes.at.vic!Place" ]
  , testCase "lacksKnownWhere aliases unknownWhere" $
      lacksKnownWhere "ute" "vic" @?= unknownWhere "ute" "vic"

  , testCase "knownWhere is Match on believes.at subtree" $
      knownWhere "ada" "bex" @?= Match "ada.believes.at.bex"

  , testCase "hasKnownWhere aliases knownWhere" $
      hasKnownWhere "ada" "bex" @?= knownWhere "ada" "bex"


  , testCase "lastKnownAt / knownWhere evaluate on believes.at Insert world" $ do
      assertBool "unknownWhere on empty"
        (satisfies (db emptyState) [unknownWhere "ute" "vic"] Map.empty)
      assertBool "lacksKnownWhere on empty"
        (satisfies (db emptyState) [lacksKnownWhere "ute" "vic"] Map.empty)
      let st = performOutcome (Insert "ute.believes.at.vic!hall") emptyState
      assertBool "lastKnownAt"
        (satisfies (db st) [lastKnownAt "ute" "vic" "hall"] Map.empty)
      assertBool "knownWhere"
        (satisfies (db st) [knownWhere "ute" "vic"] Map.empty)
      assertBool "hasKnownWhere"
        (satisfies (db st) [hasKnownWhere "ute" "vic"] Map.empty)
      assertBool "unknownWhere fails"
        (not (satisfies (db st) [unknownWhere "ute" "vic"] Map.empty))

  ]
