module Prax.FactionSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Query (Condition (..))
import           Prax.Db (exists)
import           Prax.Types
import           Prax.Engine (performOutcome, setAxioms, definePractices,
                              possibleActions, performAction)
import           Prax.Faction

-- Two houses: hall (ana, ben) and yard (cass). One shared axiom set (comrades).
houses :: PraxState
houses = setAxioms [comrades] (foldl (flip performOutcome) emptyState setup)
  where
    setup = [ joins "ana" "hall", joins "ben" "hall", joins "cass" "yard" ]

tests :: TestTree
tests = testGroup "Prax.Faction"
  [ testCase "memberPath: single-slot exclusion fact" $
      assertBool "the ! separates who from faction"
        (memberPath "ana" "hall" == "member.ana!hall")

  , testCase "comrades: shared membership derives allied, both directions" $ do
      let v = readView houses
      assertBool "ana allied ben" (exists "allied.ana.ben" v)
      assertBool "ben allied ana" (exists "allied.ben.ana" v)

  , testCase "comrades: X<>Y guard — no self-alliance" $
      assertBool "ana is not allied with herself"
        (not (exists "allied.ana.ana" (readView houses)))

  , testCase "comrades: cross-faction negative — no shared house, no alliance" $ do
      let v = readView houses
      assertBool "ana (hall) not allied with cass (yard)" (not (exists "allied.ana.cass" v))
      assertBool "cass (yard) not allied with ana (hall)" (not (exists "allied.cass.ana" v))

  , testCase "defection un-derives: joining a new faction overwrites the old, retracting stale allied pairs" $ do
      let moved = performOutcome (joins "ana" "yard") houses
          v = readView moved
      assertBool "ana no longer allied with ben (old house)" (not (exists "allied.ana.ben" v))
      assertBool "ben no longer allied with ana (old house)" (not (exists "allied.ben.ana" v))
      assertBool "ana is now allied with cass (new house)" (exists "allied.ana.cass" v)
      assertBool "cass is now allied with ana (new house)" (exists "allied.cass.ana" v)
      assertBool "ana's old membership is gone from the base"
        (not (exists "member.ana!hall" (db moved)))
      assertBool "ana's new membership is the sole base fact"
        (exists "member.ana!yard" (db moved))

  , testCase "factionStanding: an unbelieved offense moves no one" $ do
      let world = setAxioms [factionStanding "struck.A.V" "brutal"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "ana" "hall", joins "ben" "hall", joins "dave" "hall"
                       , joins "cass" "yard" ])
          v = readView world
      assertBool "no one regards ana as brutal (no belief asserted)"
        (not (any (`exists` v)
               [ "regards.ben.ana.brutal", "regards.dave.ana.brutal", "regards.cass.ana.brutal" ]))

  , testCase "factionStanding: a believed offense moves co-members only" $ do
      let world = setAxioms [factionStanding "struck.A.V" "brutal"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "ana" "hall", joins "ben" "hall", joins "dave" "hall"
                       , joins "cass" "yard"
                       , Insert "dave.believes.struck.ana.ben"
                       , Insert "cass.believes.struck.ana.ben"
                       , Insert "ana.believes.struck.ana.ben"
                       ])
          v = readView world
      assertBool "dave (co-member of victim ben's faction) regards ana as brutal"
        (exists "regards.dave.ana.brutal" v)
      assertBool "cass (a different faction) believes it too but derives nothing"
        (not (exists "regards.cass.ana.brutal" v))
      assertBool "ana (the offender) derives no self-regard, even believing her own act"
        (not (exists "regards.ana.ana.brutal" v))

  , testCase "factionStanding: defection dissolves the regard (retraction's sharpest case)" $ do
      -- the regard is DERIVED from co-membership; membership is a base fact.
      -- dave believed the offense while a hall member and regarded ana; the
      -- moment he defects, the derivation loses its join and the regard is
      -- gone — while his belief (a base fact) persists untouched.
      let held = setAxioms [factionStanding "struck.A.V" "brutal"]
                   (foldl (flip performOutcome) emptyState
                      [ joins "ana" "hall", joins "ben" "hall", joins "dave" "hall"
                      , Insert "dave.believes.struck.ana.ben" ])
          defected = performOutcome (joins "dave" "yard") held
      assertBool "co-membered: dave regards ana"
        (exists "regards.dave.ana.brutal" (readView held))
      assertBool "defected: the regard un-derives"
        (not (exists "regards.dave.ana.brutal" (readView defected)))
      assertBool "his belief persists — only the solidarity is gone"
        (exists "dave.believes.struck.ana.ben" (db defected))

  , testCase "isMember matches memberPath exclusive leaf" $
      isMember "ana" "hall" @?= Match "member.ana!hall"

  , testCase "memberPath: an empty or separator-bearing name errors loudly" $ do
      r1 <- try (evaluate (length (memberPath "" "hall")))
      assertBool "empty who errors" (isLeft (r1 :: Either ErrorCall Int))
      r2 <- try (evaluate (length (memberPath "a.b" "hall")))
      assertBool "dotted who errors" (isLeft (r2 :: Either ErrorCall Int))
      r3 <- try (evaluate (length (memberPath "ana" "ha!ll")))
      assertBool "bang'd faction errors" (isLeft (r3 :: Either ErrorCall Int))

  , testCase "factionStanding: a pattern naming fewer than two variables errors loudly" $ do
      r <- try (evaluate (length (show (factionStanding "struck.A.constant" "brutal"))))
      assertBool "an offender-only pattern is an error, not a silent single-variable guard"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "factionStanding: the usability win -- W and F are ordinary variables now (v40 moved the axiom's own join variables to the Prax namespace)" $ do
      r1 <- try (evaluate (length (show (factionStanding "struck.W.V" "brutal"))))
      assertBool "an offender named W no longer collides with anything"
        (not (isLeft (r1 :: Either ErrorCall Int)))
      r2 <- try (evaluate (length (show (factionStanding "struck.A.F" "brutal"))))
      assertBool "a victim named F no longer collides with anything"
        (not (isLeft (r2 :: Either ErrorCall Int)))

  , testCase "factionStanding: a pattern authoring the Prax namespace errors loudly" $ do
      r <- try (evaluate (length (show (factionStanding "struck.PraxW.V" "brutal"))))
      assertBool "an offender named PraxW collides with the axiom's own (now-namespaced) believer variable"
        (isLeft (r :: Either ErrorCall Int))

  , testCase "factionStanding: the victim's own belief of the offense against them derives their regard too" $ do
      let world = setAxioms [factionStanding "struck.A.V" "brutal"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "ana" "hall", joins "ben" "hall"
                       , Insert "ben.believes.struck.ana.ben"
                       ])
          v = readView world
      assertBool "ben (the victim, a co-member of himself trivially) regards ana as brutal"
        (exists "regards.ben.ana.brutal" v)
  , testCase "affiliate allows multi-belonging alongside exclusive primary membership" $ do
      let st = setAxioms [comrades, affiliateComrades]
                 (foldl (flip performOutcome) emptyState
                    [ joins "ana" "hall"
                    , affiliate "ana" "guild"
                    , affiliate "ben" "guild"
                    , joins "ben" "yard" ])
          v = readView st
      assertBool "primary hall" (exists "member.ana!hall" (db st))
      assertBool "secondary guild" (exists "affiliate.ana.guild" (db st))
      assertBool "affiliate comrades allied" (exists "allied.ana.ben" v)
      let st2 = performOutcome (unaffiliate "ana" "guild") st
      assertBool "unaffiliate clears" (not (exists "affiliate.ana.guild" (db st2)))
      assertBool "primary intact" (exists "member.ana!hall" (db st2))

  , testCase "affiliate rejects dotted names" $ do
      r <- try (evaluate (length (show (affiliate "a.b" "guild"))))
      assertBool "dotted who" (isLeft (r :: Either ErrorCall Int))


  , testCase "appointLeader exclusive; depose clears; isLeader matches" $ do
      let st0 = foldl (flip performOutcome) emptyState
                  [ appointLeader "ana" "hall"
                  , joins "ana" "hall" ]
      assertBool "leads" (exists "leads.hall!ana" (db st0))
      let st1 = performOutcome (appointLeader "ben" "hall") st0
      assertBool "overwrite" (exists "leads.hall!ben" (db st1))
      assertBool "ana gone" (not (exists "leads.hall!ana" (db st1)))
      let st2 = performOutcome (deposeLeader "hall") st1
      assertBool "deposed" (not (exists "leads.hall!ben" (db st2)))

  , testCase "appointLeader rejects dotted names" $ do
      r <- try (evaluate (length (show (appointLeader "a.b" "hall"))))
      assertBool "dotted" (isLeft (r :: Either ErrorCall Int))


  , testCase "transferLeadership hands exclusive lead to heir" $ do
      let p = practice
            { practiceId = "hall"
            , roles = []
            , actions = [ transferLeadership "hall" "[Actor]: name [Heir] as hall leader" ]
            }
          st0 = definePractices [p]
                  (foldl (flip performOutcome) emptyState
                    [ Insert "practice.hall"
                    , Insert "leads.hall!ana"
                    , Insert "member.ana!hall"
                    , Insert "member.ben!hall" ])
      let st1 = case filter (("name" `isInfixOf`) . gaLabel) (possibleActions st0 "ana") of
                  (ga:_) -> performAction st0 ga
                  [] -> error "no transfer"
      assertBool "ben leads" (exists "leads.hall!ben" (db st1))
      assertBool "ana gone" (not (exists "leads.hall!ana" (db st1)))

  -- Village golden still deferred for in-world factionStanding wiring; this
  -- fixture proves the village-shaped pattern without touching Village.
  , testCase "village-shaped guild fixture: co-members of victim regard thief" $ do
      let world = setAxioms [factionStanding "stole.Culprit.Victim" "thief"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "bob" "guild", joins "carol" "mill", joins "dave" "mill"
                       , joins "eve" "outsiders"
                       , Insert "dave.believes.stole.bob.carol"
                       , Insert "eve.believes.stole.bob.carol"
                       , Insert "bob.believes.stole.bob.carol"
                       ])
          v = readView world
      assertBool "dave (co-member of victim carol) regards bob as thief"
        (exists "regards.dave.bob.thief" v)
      assertBool "eve (outsiders) derives nothing"
        (not (exists "regards.eve.bob.thief" v))
      assertBool "bob derives no self-regard"
        (not (exists "regards.bob.bob.thief" v))

  , testCase "lacksMember is Not of member path" $
      lacksMember "eve" "guild" @?= Not "member.eve!guild"

  , testCase "lacksAffiliate / lacksLeader duals" $ do
      lacksAffiliate "ada" "guild" @?= Not "affiliate.ada.guild"
      lacksLeader "ada" "guild" @?= Not "leads.guild!ada"

  , testCase "regardsAs / lacksRegard / everRegards / neverRegards duals" $ do
      regardsAs "dave" "bob" "thief" @?= Match "regards.dave.bob.thief"
      lacksRegard "dave" "bob" "thief" @?= Not "regards.dave.bob.thief"
      everRegards "dave" @?= Exists [ Match "regards.dave.Target.Label" ]
      neverRegards "eve" @?= Absent [ Match "regards.eve.Target.Label" ]

  -- Village-shaped mill fixture: mill co-members regard the thief when they
  -- believe the theft (still Spec-only; Village golden untouched).
  , testCase "village-shaped mill fixture: mill co-members regard thief" $ do
      let world = setAxioms [factionStanding "stole.Culprit.Victim" "thief"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "bob" "guild", joins "carol" "mill", joins "dave" "mill"
                       , joins "fran" "mill"
                       , Insert "dave.believes.stole.bob.carol"
                       , Insert "fran.believes.stole.bob.carol"
                       , Insert "bob.believes.stole.bob.carol"
                       ])
          v = readView world
      assertBool "dave regards bob" (exists "regards.dave.bob.thief" v)
      assertBool "fran (mill co-member) regards bob" (exists "regards.fran.bob.thief" v)
      assertBool "bob no self-regard" (not (exists "regards.bob.bob.thief" v))


  , testCase "everMember / neverMember are Exists/Absent over member.<who>!*" $ do
      everMember "dave" @?= Exists [ Match "member.dave!Faction" ]
      neverMember "eve" @?= Absent [ Match "member.eve!Faction" ]

  , testCase "village-shaped church fixture: church co-members regard heretic" $ do
      let world = setAxioms [factionStanding "blasphemed.Culprit.Victim" "heretic"]
                    (foldl (flip performOutcome) emptyState
                       [ joins "priest" "church", joins "gale" "church"
                       , joins "bob" "guild"
                       , Insert "gale.believes.blasphemed.eve.gale"
                       , Insert "priest.believes.blasphemed.eve.gale"
                       , Insert "bob.believes.blasphemed.eve.gale"
                       ])
          v = readView world
      assertBool "gale (victim, church) regards eve" (exists "regards.gale.eve.heretic" v)
      assertBool "priest (church co-member) regards eve" (exists "regards.priest.eve.heretic" v)
      assertBool "bob (guild outsider) derives nothing"
        (not (exists "regards.bob.eve.heretic" v))
  ]
