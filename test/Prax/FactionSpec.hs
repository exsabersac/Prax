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
import           Prax.Kin (wed)

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

  , testCase "everAffiliate / neverAffiliate / everLeader / neverLeader" $ do
      everAffiliate "ada" @?= Exists [ Match "affiliate.ada.Faction" ]
      neverAffiliate "ada" @?= Absent [ Match "affiliate.ada.Faction" ]
      everLeader "ana" @?= Exists [ Match "leads.Faction!ana" ]
      neverLeader "ana" @?= Absent [ Match "leads.Faction!ana" ]

  , testCase "hasMember / hasLeader / hasAffiliate / hasRegardAs aliases" $ do
      hasMember "ada" "guild" @?= isMember "ada" "guild"
      hasLeader "ana" "guild" @?= isLeader "ana" "guild"
      hasAffiliate "ada" "church" @?= affiliates "ada" "church"
      hasRegardAs "ada" "bex" "thief" @?= regardsAs "ada" "bex" "thief"

  -- Village-shaped mill justice arc (Spec-only; Village golden untouched):
  -- learn → factionStanding regard → confront gated on regard → defection
  -- dissolves the gate while the belief base fact persists.
  , testCase "village-shaped mill justice arc: belief→regard→gate→defection" $ do
      let justice = practice
            { practiceId = "millJustice"
            , roles = []
            , actions =
                [ action "[Actor]: learn of the theft"
                    [ isMember "Actor" "mill"
                    , Not "Actor.believes.stole.bob.carol" ]
                    [ Insert "Actor.believes.stole.bob.carol" ]
                , action "[Actor]: confront the thief"
                    [ Match "regards.Actor.bob.thief"
                    , Not "confronted.Actor.bob" ]
                    [ Insert "confronted.Actor.bob" ]
                ]
            }
          world0 = setAxioms [factionStanding "stole.Culprit.Victim" "thief"]
                     (definePractices [justice]
                       (foldl (flip performOutcome) emptyState
                          [ joins "bob" "guild", joins "carol" "mill"
                          , joins "dave" "mill", joins "fran" "mill"
                          , joins "eve" "outsiders"
                          , Insert "practice.millJustice"
                          , Insert "eve.believes.stole.bob.carol"
                          ]))
          hasAct who needle st =
            any ((needle `isInfixOf`) . gaLabel) (possibleActions st who)
          doAct who needle st =
            case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st who) of
              (ga : _) -> performAction st ga
              []       -> error ("no action " ++ show needle ++ " for " ++ who)
      assertBool "before: dave cannot confront" (not (hasAct "dave" "confront" world0))
      assertBool "before: eve cannot confront despite belief"
        (not (hasAct "eve" "confront" world0))
      assertBool "eve (outsider) derives no regard"
        (not (exists "regards.eve.bob.thief" (readView world0)))
      let stLearn = doAct "dave" "learn" world0
      assertBool "dave believes" (exists "dave.believes.stole.bob.carol" (db stLearn))
      assertBool "dave regards bob as thief"
        (exists "regards.dave.bob.thief" (readView stLearn))
      assertBool "dave can confront" (hasAct "dave" "confront" stLearn)
      assertBool "fran (mill, no belief) cannot confront"
        (not (hasAct "fran" "confront" stLearn))
      assertBool "eve still cannot" (not (hasAct "eve" "confront" stLearn))
      let stFran = doAct "fran" "learn" stLearn
      assertBool "fran regards" (exists "regards.fran.bob.thief" (readView stFran))
      assertBool "fran can confront" (hasAct "fran" "confront" stFran)
      let stCon = doAct "dave" "confront" stFran
      assertBool "confronted" (exists "confronted.dave.bob" (db stCon))
      assertBool "confront once" (not (hasAct "dave" "confront" stCon))
      let stDef = performOutcome (joins "fran" "outsiders") stCon
      assertBool "fran regard dissolved after defection"
        (not (exists "regards.fran.bob.thief" (readView stDef)))
      assertBool "fran belief persists" (exists "fran.believes.stole.bob.carol" (db stDef))
      assertBool "fran cannot confront after defection"
        (not (hasAct "fran" "confront" stDef))
      assertBool "dave (still mill) still regards"
        (exists "regards.dave.bob.thief" (readView stDef))

  -- Village-shaped church censure arc: belief→heretic regard→censure gate;
  -- guild outsider with the same belief stays gated out.
  , testCase "village-shaped church censure arc: belief→regard→censure gate" $ do
      let censure = practice
            { practiceId = "churchCensure"
            , roles = []
            , actions =
                [ action "[Actor]: hear the blasphemy"
                    [ isMember "Actor" "church"
                    , Not "Actor.believes.blasphemed.eve.gale" ]
                    [ Insert "Actor.believes.blasphemed.eve.gale" ]
                , action "[Actor]: censure the heretic"
                    [ Match "regards.Actor.eve.heretic"
                    , Not "censured.Actor.eve" ]
                    [ Insert "censured.Actor.eve" ]
                ]
            }
          world0 = setAxioms [factionStanding "blasphemed.Culprit.Victim" "heretic"]
                     (definePractices [censure]
                       (foldl (flip performOutcome) emptyState
                          [ joins "priest" "church", joins "gale" "church"
                          , joins "bob" "guild"
                          , Insert "practice.churchCensure"
                          , Insert "bob.believes.blasphemed.eve.gale"
                          ]))
          hasAct who needle st =
            any ((needle `isInfixOf`) . gaLabel) (possibleActions st who)
          doAct who needle st =
            case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st who) of
              (ga : _) -> performAction st ga
              []       -> error ("no action " ++ show needle ++ " for " ++ who)
      assertBool "bob (guild) derives no regard despite belief"
        (not (exists "regards.bob.eve.heretic" (readView world0)))
      assertBool "bob cannot censure" (not (hasAct "bob" "censure" world0))
      let stHear = doAct "priest" "hear" world0
      assertBool "priest regards" (exists "regards.priest.eve.heretic" (readView stHear))
      assertBool "priest can censure" (hasAct "priest" "censure" stHear)
      assertBool "gale (no belief yet) cannot" (not (hasAct "gale" "censure" stHear))
      let stCen = doAct "priest" "censure" stHear
      assertBool "censured" (exists "censured.priest.eve" (db stCen))
      let stGale = doAct "gale" "hear" stCen
      assertBool "gale (victim) regards" (exists "regards.gale.eve.heretic" (readView stGale))
      assertBool "gale can censure" (hasAct "gale" "censure" stGale)

  -- Affiliate is secondary belonging: factionStanding joins only primary
  -- member.! spines, so an affiliate who believes still derives nothing.
  , testCase "village-shaped affiliate negative: affiliate belief derives no factionStanding" $ do
      let world = setAxioms [factionStanding "stole.Culprit.Victim" "thief", affiliateComrades]
                    (foldl (flip performOutcome) emptyState
                       [ joins "carol" "mill", joins "dave" "mill"
                       , joins "fran" "guild"
                       , affiliate "fran" "mill"   -- secondary mill tie only
                       , affiliate "dave" "mill"   -- dave also affiliates (comrades need both)
                       , Insert "fran.believes.stole.bob.carol"
                       , Insert "dave.believes.stole.bob.carol"
                       ])
          v = readView world
      assertBool "dave (primary mill) regards" (exists "regards.dave.bob.thief" v)
      assertBool "fran (affiliate mill only — no primary mill) derives nothing"
        (not (exists "regards.fran.bob.thief" v))
      assertBool "affiliate comrades still allied" (exists "allied.fran.dave" v)
      assertBool "fran primary remains guild" (exists "member.fran!guild" (db world))
      assertBool "fran affiliate mill" (exists "affiliate.fran.mill" (db world))

  -- Victim defection dissolves co-member regards: factionStanding joins the
  -- victim's *current* primary membership, so when carol leaves the mill the
  -- dave↔carol co-member join fails and the regard un-derives — belief stays.
  , testCase "village-shaped victim defection dissolves co-member regards" $ do
      let held = setAxioms [factionStanding "stole.Culprit.Victim" "thief"]
                   (foldl (flip performOutcome) emptyState
                      [ joins "bob" "guild", joins "carol" "mill", joins "dave" "mill"
                      , Insert "dave.believes.stole.bob.carol" ])
          left = performOutcome (joins "carol" "guild") held
      assertBool "held: dave regards" (exists "regards.dave.bob.thief" (readView held))
      assertBool "after victim left mill: regard gone"
        (not (exists "regards.dave.bob.thief" (readView left)))
      assertBool "dave belief persists" (exists "dave.believes.stole.bob.carol" (db left))
      assertBool "carol now guild" (exists "member.carol!guild" (db left))
      assertBool "dave still mill" (exists "member.dave!mill" (db left))

  -- Wedding into the victim's faction grants factionStanding: fran (guild)
  -- believes the theft but derives nothing until wed into mill beside carol.
  , testCase "village-shaped wedding into mill grants factionStanding regard" $ do
      let justice = practice
            { practiceId = "millWedJustice"
            , roles = []
            , actions =
                [ action "[Actor]: confront the thief"
                    [ Match "regards.Actor.bob.thief"
                    , Not "confronted.Actor.bob" ]
                    [ Insert "confronted.Actor.bob" ]
                ]
            }
          before = setAxioms [factionStanding "stole.Culprit.Victim" "thief"]
                     (definePractices [justice]
                       (foldl (flip performOutcome) emptyState
                          [ joins "bob" "guild", joins "carol" "mill"
                          , joins "fran" "guild"
                          , Insert "practice.millWedJustice"
                          , Insert "fran.believes.stole.bob.carol"
                          ]))
          after = foldl (flip performOutcome) before (wed "fran" "mill" "carol")
          hasAct who needle st =
            any ((needle `isInfixOf`) . gaLabel) (possibleActions st who)
          doAct who needle st =
            case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st who) of
              (ga : _) -> performAction st ga
              []       -> error ("no action " ++ show needle ++ " for " ++ who)
      assertBool "before: no regard" (not (exists "regards.fran.bob.thief" (readView before)))
      assertBool "before: cannot confront" (not (hasAct "fran" "confront" before))
      assertBool "wed: fran now mill" (exists "member.fran!mill" (db after))
      assertBool "wed: married" (exists "married.fran.carol" (db after))
      assertBool "after: regard derives" (exists "regards.fran.bob.thief" (readView after))
      assertBool "after: can confront" (hasAct "fran" "confront" after)
      let stCon = doAct "fran" "confront" after
      assertBool "confronted" (exists "confronted.fran.bob" (db stCon))

  ]
