{-# LANGUAGE LambdaCase #-}
module Prax.ScheduleRuleSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (performOutcome, performAction, setSchedule, registerEngineRules, roundBoundary, definePractices, possibleActions)
import           Prax.TypeCheck (TypeError (..), typeCheck)
import           Prax.Schedule (gathering, festival, duringFestival, hasFestival, outsideFestival, lacksFestival, pulse)
import           Prax.Deontic (oblige, discharge, isObliged, breach)
import           Prax.Emotion (setMood, inMood, clearMood)
import           Prax.Worlds.Play (playWorld)

-- A one-rule schedule: "mark" flags every flagged thing every 2 boundaries
-- (the retired DriftSpec markR, now an engine ScheduleRule the boundary fires).
markR :: ScheduleRule
markR = ScheduleRule "mark" 2 [([Match "flag.X"], [Insert "marked.X"])]

-- Install a schedule on a fresh clocked world (emptyState seeds turn!0), then
-- seed the world's flag facts. setSchedule start-sates each rule one period out.
scheduled :: [ScheduleRule] -> [Outcome] -> PraxState
scheduled rules = foldl (flip performOutcome) (setSchedule rules emptyState)

dueOf :: String -> PraxState -> Maybe Int
dueOf name = Map.lookup name . scheduleDues

-- Force a schedule installation to WHNF (enough to hit setSchedule's guards).
rejects :: [ScheduleRule] -> IO Bool
rejects rules = isLeft <$> (try (evaluate (setSchedule rules emptyState))
                              :: IO (Either ErrorCall PraxState))

tests :: TestTree
tests = testGroup "Prax.ScheduleRule"
  [ testCase "a rule does not fire before its due" $ do
      let st = roundBoundary (scheduled [markR] [Insert "flag.a"])   -- turn 1; due at 2
      assertBool "marked.a absent (due seeded at 2, now 1)" (not (exists "marked.a" (db st)))

  , testCase "a rule fires at its due, covering every binding" $ do
      let base = scheduled [markR] [Insert "flag.a", Insert "flag.b"]
          st   = roundBoundary (roundBoundary base)                  -- turn 2 = due
      assertBool "marked.a inserted" (exists "marked.a" (db st))
      assertBool "marked.b inserted" (exists "marked.b" (db st))

  , testCase "the due re-arms period boundaries from now" $ do
      let base = scheduled [markR] [Insert "flag.a"]
          st2  = roundBoundary (roundBoundary base)                  -- turn 2: fires, re-arms
      dueOf "mark" st2 @?= Just 4
      let st3 = roundBoundary st2                                    -- turn 3: not yet due at 4
      dueOf "mark" st3 @?= Just 4
      assertBool "no re-fire before the new due (mark still stands from turn 2)"
        (exists "marked.a" (db st3))

  , testCase "two rules with different periods fire on their own schedules" $ do
      let p2 = ScheduleRule "p2" 2 [([Match "flagA.X"], [Insert "markedA.X"])]
          p3 = ScheduleRule "p3" 3 [([Match "flagB.X"], [Insert "markedB.X"])]
          base = scheduled [p2, p3] [Insert "flagA.a", Insert "flagB.a"]
          step = roundBoundary
          st1 = step base
          st2 = step st1
          st3 = step st2
          st4 = step st3
          st5 = step st4
          st6 = step st5

      -- turn 1: neither due (seeded at 2 / 3).
      dueOf "p2" st1 @?= Just 2
      dueOf "p3" st1 @?= Just 3
      -- turn 2: p2 fires, re-arms to 4; p3 not yet.
      dueOf "p2" st2 @?= Just 4
      dueOf "p3" st2 @?= Just 3
      -- turn 3: p3 fires, re-arms to 6; p2 not yet.
      dueOf "p2" st3 @?= Just 4
      dueOf "p3" st3 @?= Just 6
      -- turn 4: p2 fires, re-arms to 6.
      dueOf "p2" st4 @?= Just 6
      dueOf "p3" st4 @?= Just 6
      -- turn 5: neither due.
      dueOf "p2" st5 @?= Just 6
      dueOf "p3" st5 @?= Just 6
      -- turn 6: both fire, re-arm to 8 and 9.
      dueOf "p2" st6 @?= Just 8
      dueOf "p3" st6 @?= Just 9
      assertBool "markedA.a present" (exists "markedA.a" (db st6))
      assertBool "markedB.a present" (exists "markedB.a" (db st6))

  , testCase "a late fire (clock jumped past the due) re-arms FROM the boundary it fires at" $ do
      -- The clock-jump idiom: jump the clock forward (performOutcome, the
      -- only sanctioned author-free clock write) so the rule is overdue, then
      -- one boundary fires it late and re-arms a period from NOW, not the
      -- stale due.
      let base = performOutcome (Insert "turn!10")
                   (scheduled [markR] [Insert "flag.a"])              -- overdue (due 2, clock 10)
          st   = roundBoundary base                                   -- now 11: fires late
      assertBool "fired late" (exists "marked.a" (db st))
      dueOf "mark" st @?= Just 13                                     -- 11 + period, not 2 + period

  , testCase "duplicate rule names are a loud construction-time error (one due key each)" $
      rejects [ ScheduleRule "same" 2 [], ScheduleRule "same" 3 [] ] >>= assertBool "rejected"

  , testCase "a multi-segment rule name is a loud construction-time error" $
      rejects [ ScheduleRule "a.b" 2 [] ] >>= assertBool "rejected"

  , testCase "a body authoring the Prax namespace is a loud error" $
      rejects [ ScheduleRule "x" 2 [([Match "flag.PraxNow"], [])] ] >>= assertBool "rejected"

  , testCase "a body authoring Actor is a loud error (a schedule rule has no actor)" $
      rejects [ ScheduleRule "x" 2 [([Match "flag.Actor"], [])] ] >>= assertBool "rejected"

  , testCase "the usability win: D/D2/Now are ordinary variables, not reserved" $ do
      ok <- not <$> rejects [ ScheduleRule "x" 2 [([Match "flag.Now"], [Insert "marked.D"])] ]
      assertBool "D and Now are unremarkable author variables" ok

  , testCase "a zero period is a loud error" $
      rejects [ ScheduleRule "x" 0 [([Match "flag.a"], [Insert "marked.a"])] ] >>= assertBool "rejected"

  , testCase "a schedule world is well-formed" $ do
      -- markR's guard reads flag.X, produced by a registered practice's init
      -- (the DriftSpec "flagSeed" pattern) so the v42 dead-condition lint sees
      -- it -- this pins well-formedness of the schedule machinery.
      let flagSeed = practice { practiceId = "flagSeed", initOutcomes = [ Insert "flag.seed" ] }
          st = setSchedule [markR] (definePractices [flagSeed] emptyState)
      assertBool "no type errors" (null (typeCheck st))

  , testGroup "gathering (open fires; the fact expires -- no close rule)"
    [ testCase "opens at period, not before" $ do
        let base = scheduled [ gathering "fair" 3 1 [Insert "marketDay.now"] ] []
            st2  = roundBoundary (roundBoundary base)                 -- turn 2
        assertBool "not open before period" (not (exists "marketDay.now" (db st2)))
        let st3 = roundBoundary st2                                   -- turn 3 == period
        assertBool "opens exactly at period" (exists "marketDay.now" (db st3))

    , testCase "closes at period + duration (the expiry queue tears it down)" $ do
        let base = scheduled [ gathering "fair" 3 1 [Insert "marketDay.now"] ] []
            st3  = roundBoundary (roundBoundary (roundBoundary base)) -- turn 3: open
        assertBool "still open at period" (exists "marketDay.now" (db st3))
        let st4 = roundBoundary st3                                   -- turn 4 == period + duration
        assertBool "closed exactly at period + duration" (not (exists "marketDay.now" (db st4)))

    , testCase "recurs: opens again a full period later" $ do
        let base = scheduled [ gathering "fair" 3 1 [Insert "marketDay.now"] ] []
            drive k st = iterate roundBoundary st !! k
            st6 = drive 6 base                                        -- second open at 2*period
        assertBool "cycle 2 opens at 2 x period" (exists "marketDay.now" (db st6))
        dueOf "fair" st6 @?= Just 9                                   -- re-armed to 6 + period

    , testCase "duration == period is a loud construction-time error" $ do
        r <- try (evaluate (length (show (gathering "fair" 3 3 [Insert "x"]))))
        assertBool "duration == period rejected" (isLeft (r :: Either ErrorCall Int))

    , testCase "duration == 0 is a loud construction-time error" $ do
        r <- try (evaluate (length (show (gathering "fair" 3 0 [Insert "x"]))))
        assertBool "duration == 0 rejected" (isLeft (r :: Either ErrorCall Int))

    , testCase "dual gatherings coexist: fair and chapel open on independent periods" $ do
        -- v37 residual: multiple simultaneous gatherings are in-scope when
        -- periods align; prove two named gatherings do not collide on dues.
        let base = scheduled
              [ gathering "fair" 4 1 [Insert "marketDay.now"]
              , gathering "chapel" 6 2 [Insert "chapelOpen.now"]
              ] []
            drive k st0 = iterate roundBoundary st0 !! k
            st4 = drive 4 base   -- fair opens (period 4); chapel not yet
            st6 = drive 6 base   -- chapel opens (period 6); fair closed at 5
        assertBool "fair open at 4" (exists "marketDay.now" (db st4))
        assertBool "chapel closed at 4" (not (exists "chapelOpen.now" (db st4)))
        assertBool "chapel open at 6" (exists "chapelOpen.now" (db st6))
        assertBool "fair closed at 6 (opened 4, duration 1)" (not (exists "marketDay.now" (db st6)))
        dueOf "fair" st4 @?= Just 8
        dueOf "chapel" st6 @?= Just 12

    , testCase "festival seeds festival.<name> leaf for the open window" $ do
        let base = scheduled [ festival "harvest" 3 1 [Insert "marketDay.now"] ] []
            st3 = iterate roundBoundary base !! 3
        assertBool "festival leaf" (exists "festival.harvest" (db st3))
        assertBool "open outs too" (exists "marketDay.now" (db st3))
        let st4 = roundBoundary st3
        assertBool "festival expired with window" (not (exists "festival.harvest" (db st4)))
    ]

  , testGroup "the compiler-level door shares the global rule-name table (v46)"
    [ testCase "registerEngineRules seeds a due exactly like setSchedule (one period out)" $ do
        -- emptyState clocks turn!0, so a period-1 engine rule is due at 1.
        let st = registerEngineRules [ScheduleRule "story" 1 []] emptyState
        dueOf "story" st @?= Just 1

    , testCase "adding an authored 'story' rule to a compiled script world is a loud collision" $ do
        -- playWorld already carries the engine-registered 'story' rule; an
        -- author naming a schedule rule 'story' would share its one due key.
        r <- try (evaluate (length (show (scheduleDues
               (setSchedule [ScheduleRule "story" 2 []] playWorld)))))
        assertBool "rejected: the compiled script already registered 'story'"
          (isLeft (r :: Either ErrorCall Int))

    , testCase "an authored 'story' rule blocks the engine door, and vice versa" $ do
        -- Direction 1: authored first, engine door second.
        let authored = setSchedule [ScheduleRule "story" 2 []] emptyState
        r1 <- try (evaluate (length (show (scheduleDues
                (registerEngineRules [ScheduleRule "story" 1 []] authored)))))
        assertBool "engine door rejected: 'story' already authored"
          (isLeft (r1 :: Either ErrorCall Int))
        -- Direction 2: engine door first, authored second.
        let engineFirst = registerEngineRules [ScheduleRule "story" 1 []] emptyState
        r2 <- try (evaluate (length (show (scheduleDues
                (setSchedule [ScheduleRule "story" 2 []] engineFirst)))))
        assertBool "authoring door rejected: 'story' already registered by the engine"
          (isLeft (r2 :: Either ErrorCall Int))
    ]

  , testGroup "festival gate sandbox (Match/Not festival.<name>)"
    [ testCase "duringFestival / outsideFestival are Match/Not duals" $ do
        duringFestival "harvest" @?= Match "festival.harvest"
        outsideFestival "harvest" @?= Not "festival.harvest"

    , testCase "hasFestival / lacksFestival alias during/outside" $ do
        hasFestival "harvest" @?= duringFestival "harvest"
        lacksFestival "harvest" @?= outsideFestival "harvest"

    , testCase "rite action available only inside the festival window" $ do
        let rite = practice
              { practiceId = "harvestRite"
              , roles = []
              , actions =
                  [ action "[Actor]: dance the harvest"
                      [ duringFestival "harvest" ]
                      [ Insert "danced.Actor" ]
                  , action "[Actor]: wait out the season"
                      [ outsideFestival "harvest" ]
                      [ Insert "waited.Actor" ]
                  ]
              }
            base = definePractices [rite]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestRite" ])
            canDance st = any (("dance the harvest" `isInfixOf`) . gaLabel)
                                (possibleActions st "ada")
            canWait  st = any (("wait out the season" `isInfixOf`) . gaLabel)
                                (possibleActions st "ada")
            st0 = base                          -- turn 0; due at 3 — outside
            st3 = iterate roundBoundary base !! 3  -- festival opens
            st4 = roundBoundary st3                -- festival expires
        assertBool "outside before open: wait yes" (canWait st0)
        assertBool "outside before open: dance no" (not (canDance st0))
        assertBool "festival leaf at open" (exists "festival.harvest" (db st3))
        assertBool "inside window: dance yes" (canDance st3)
        assertBool "inside window: wait no" (not (canWait st3))
        assertBool "after expire: wait yes" (canWait st4)
        assertBool "after expire: dance no" (not (canDance st4))

    , testCase "harvest vow arc: prepare outside → vow during → fulfill after" $ do
        -- 可玩弧（不改 Village 金标准）：节前备祭 → 节中起誓种义务 → 节后兑现 discharge。
        let vow = practice
              { practiceId = "harvestVow"
              , roles = []
              , actions =
                  [ action "[Actor]: prepare the offering"
                      [ outsideFestival "harvest"
                      , Not "prepared.Actor" ]
                      [ Insert "prepared.Actor" ]
                  , action "[Actor]: vow at the altar"
                      [ duringFestival "harvest"
                      , Match "prepared.Actor"
                      , Not "vowed.Actor" ]
                      [ Insert "vowed.Actor"
                      , oblige "Actor" "offered.harvest" ]
                  , action "[Actor]: make the offering"
                      [ outsideFestival "harvest"
                      , isObliged "Actor" "offered.harvest"
                      , Not "offered.harvest" ]
                      [ Insert "offered.harvest"
                      , discharge "Actor" "offered.harvest" ]
                  ]
              }
            base = definePractices [vow]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestVow" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: prepare yes" (hasAct "prepare the offering" st0)
        assertBool "before: vow no" (not (hasAct "vow at the altar" st0))
        assertBool "before: offer no" (not (hasAct "make the offering" st0))
        let stPrep = doAct "prepare the offering" st0
        assertBool "prepared leaf" (exists "prepared.ada" (db stPrep))
        let stOpen = iterate roundBoundary stPrep !! 3
        assertBool "festival open" (exists "festival.harvest" (db stOpen))
        assertBool "open: vow yes" (hasAct "vow at the altar" stOpen)
        assertBool "open: prepare no (already done / inside)" (not (hasAct "prepare the offering" stOpen))
        assertBool "open: offer no (still inside)" (not (hasAct "make the offering" stOpen))
        let stVow = doAct "vow at the altar" stOpen
        assertBool "vowed" (exists "vowed.ada" (db stVow))
        assertBool "obligation planted" (exists "obliged.ada.offered.harvest" (db stVow))
        let stAfter = roundBoundary stVow
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: offer yes" (hasAct "make the offering" stAfter)
        assertBool "after: vow no" (not (hasAct "vow at the altar" stAfter))
        let stDone = doAct "make the offering" stAfter
        assertBool "offered" (exists "offered.harvest" (db stDone))
        assertBool "obligation discharged"
          (not (exists "obliged.ada.offered.harvest" (db stDone)))
        assertBool "offer gone once done" (not (hasAct "make the offering" stDone))

    , testCase "harvest vow arc shirk path: vow then breach outside window" $ do
        let vow = practice
              { practiceId = "harvestVow2"
              , roles = []
              , actions =
                  [ action "[Actor]: prepare the offering"
                      [ outsideFestival "harvest"
                      , Not "prepared.Actor" ]
                      [ Insert "prepared.Actor" ]
                  , action "[Actor]: vow at the altar"
                      [ duringFestival "harvest"
                      , Match "prepared.Actor"
                      , Not "vowed.Actor" ]
                      [ Insert "vowed.Actor"
                      , oblige "Actor" "offered.harvest" ]
                  , action "[Actor]: shirk the vow"
                      [ outsideFestival "harvest"
                      , isObliged "Actor" "offered.harvest"
                      , Not "offered.harvest"
                      , Not "shirked.Actor" ]
                      [ Insert "shirked.Actor"
                      , breach "Actor" "offered.harvest" ]
                  ]
              }
            base = definePractices [vow]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestVow2" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            stPrep = doAct "prepare the offering" base
            stOpen = iterate roundBoundary stPrep !! 3
            stVow  = doAct "vow at the altar" stOpen
            stAfter = roundBoundary stVow
        assertBool "obligation still holds" (exists "obliged.ada.offered.harvest" (db stAfter))
        assertBool "shirk offered" (hasAct "shirk the vow" stAfter)
        let stShirk = doAct "shirk the vow" stAfter
        assertBool "shirked" (exists "shirked.ada" (db stShirk))
        assertBool "breach recorded" (exists "violated.ada.offered.harvest" (db stShirk))
        assertBool "shirk once" (not (hasAct "shirk the vow" stShirk))

    , testCase "harvest wedding arc: court outside → wed during → feast after" $ do
        -- 更丰节庆门禁叙事：节前求亲 → 节中成婚写 married 叶 → 节后宴贺；仍不改 Village。
        let rite = practice
              { practiceId = "harvestWedding"
              , roles = ["Beloved"]
              , actions =
                  [ action "[Actor]: court [Beloved]"
                      [ outsideFestival "harvest"
                      , Not "courting.Actor.Beloved"
                      , Not "married.Actor.Beloved" ]
                      [ Insert "courting.Actor.Beloved" ]
                  , action "[Actor]: wed [Beloved] at harvest"
                      [ duringFestival "harvest"
                      , Match "courting.Actor.Beloved"
                      , Not "married.Actor.Beloved" ]
                      [ Insert "married.Actor.Beloved"
                      , Insert "married.Beloved.Actor"
                      , Delete "courting.Actor.Beloved" ]
                  , action "[Actor]: feast the marriage"
                      [ outsideFestival "harvest"
                      , Match "married.Actor.Beloved"
                      , Not "feasted.Actor" ]
                      [ Insert "feasted.Actor" ]
                  ]
              }
            base = definePractices [rite]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestWedding.ben" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: court yes" (hasAct "court" st0)
        assertBool "before: wed no" (not (hasAct "wed" st0))
        assertBool "before: feast no" (not (hasAct "feast" st0))
        let stCourt = doAct "court" st0
        assertBool "courting leaf" (exists "courting.ada.ben" (db stCourt))
        let stOpen = iterate roundBoundary stCourt !! 3
        assertBool "festival open" (exists "festival.harvest" (db stOpen))
        assertBool "open: wed yes" (hasAct "wed" stOpen)
        assertBool "open: feast no" (not (hasAct "feast" stOpen))
        let stWed = doAct "wed" stOpen
        assertBool "married a->b" (exists "married.ada.ben" (db stWed))
        assertBool "married b->a" (exists "married.ben.ada" (db stWed))
        assertBool "courting cleared" (not (exists "courting.ada.ben" (db stWed)))
        let stAfter = roundBoundary stWed
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: feast yes" (hasAct "feast" stAfter)
        assertBool "after: wed no" (not (hasAct "wed" stAfter))
        let stFeast = doAct "feast" stAfter
        assertBool "feasted" (exists "feasted.ada" (db stFeast))
        assertBool "feast once" (not (hasAct "feast" stFeast))

    , testCase "harvest revel arc: revel during → sober mood after" $ do
        -- 节庆门禁 + 心境：节中狂欢种 festive 心境，节后醒酒清除；不改 Village。
        let revel = practice
              { practiceId = "harvestRevel"
              , roles = []
              , actions =
                  [ action "[Actor]: revel at the fair"
                      [ duringFestival "harvest"
                      , Not "mood.Actor!festive" ]
                      [ setMood "Actor" "festive"
                      , Insert "reveled.Actor" ]
                  , action "[Actor]: sober up after harvest"
                      [ outsideFestival "harvest"
                      , inMood "Actor" "festive" ]
                      [ clearMood "Actor"
                      , Insert "sobered.Actor" ]
                  ]
              }
            base = definePractices [revel]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestRevel" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: revel no" (not (hasAct "revel" st0))
        assertBool "before: sober no" (not (hasAct "sober" st0))
        let stOpen = iterate roundBoundary st0 !! 3
        assertBool "open: revel yes" (hasAct "revel" stOpen)
        let stRev = doAct "revel" stOpen
        assertBool "festive mood" (exists "mood.ada!festive" (db stRev))
        assertBool "reveled" (exists "reveled.ada" (db stRev))
        assertBool "open: revel once" (not (hasAct "revel" stRev))
        let stAfter = roundBoundary stRev
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: sober yes" (hasAct "sober" stAfter)
        let stSob = doAct "sober" stAfter
        assertBool "mood cleared" (not (exists "mood.ada!festive" (db stSob)))
        assertBool "sobered" (exists "sobered.ada" (db stSob))
        assertBool "sober once" (not (hasAct "sober" stSob))

    , testCase "harvest petition arc: draft outside → present during → grant after" $ do
        let pet = practice
              { practiceId = "harvestPetition"
              , roles = []
              , actions =
                  [ action "[Actor]: draft a petition"
                      [ outsideFestival "harvest"
                      , Not "petition.Actor!ready" ]
                      [ Insert "petition.Actor!ready" ]
                  , action "[Actor]: present the petition"
                      [ duringFestival "harvest"
                      , Match "petition.Actor!ready"
                      , Not "petitioned.Actor" ]
                      [ Insert "petitioned.Actor"
                      , Delete "petition.Actor!ready" ]
                  , action "[Actor]: receive a grant"
                      [ outsideFestival "harvest"
                      , Match "petitioned.Actor"
                      , Not "granted.Actor" ]
                      [ Insert "granted.Actor" ]
                  ]
              }
            base = definePractices [pet]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestPetition" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: draft yes" (hasAct "draft" st0)
        assertBool "before: present no" (not (hasAct "present" st0))
        let stDraft = doAct "draft" st0
        assertBool "ready" (exists "petition.ada!ready" (db stDraft))
        assertBool "draft once" (not (hasAct "draft" stDraft))
        let stOpen = iterate roundBoundary stDraft !! 3
        assertBool "festival open" (exists "festival.harvest" (db stOpen))
        assertBool "open: present yes" (hasAct "present" stOpen)
        assertBool "open: grant no" (not (hasAct "receive a grant" stOpen))
        let stPres = doAct "present" stOpen
        assertBool "petitioned" (exists "petitioned.ada" (db stPres))
        assertBool "ready cleared" (not (exists "petition.ada!ready" (db stPres)))
        let stAfter = roundBoundary stPres
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: grant yes" (hasAct "receive a grant" stAfter)
        let stGrant = doAct "receive a grant" stAfter
        assertBool "granted" (exists "granted.ada" (db stGrant))
        assertBool "grant once" (not (hasAct "receive a grant" stGrant))

    , testCase "harvest trial arc: accuse outside → judge during → sentence after" $ do
        let trial = practice
              { practiceId = "harvestTrial"
              , roles = []
              , actions =
                  [ action "[Actor]: accuse the culprit"
                      [ outsideFestival "harvest"
                      , Not "accused.Actor" ]
                      [ Insert "accused.Actor" ]
                  , action "[Actor]: judge the case"
                      [ duringFestival "harvest"
                      , Match "accused.Actor"
                      , Not "judged.Actor" ]
                      [ Insert "judged.Actor" ]
                  , action "[Actor]: pass sentence"
                      [ outsideFestival "harvest"
                      , Match "judged.Actor"
                      , Not "sentenced.Actor" ]
                      [ Insert "sentenced.Actor" ]
                  ]
              }
            base = definePractices [trial]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestTrial" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: accuse yes" (hasAct "accuse" st0)
        assertBool "before: judge no" (not (hasAct "judge" st0))
        let stAcc = doAct "accuse" st0
        assertBool "accused" (exists "accused.ada" (db stAcc))
        assertBool "accuse once" (not (hasAct "accuse" stAcc))
        let stOpen = iterate roundBoundary stAcc !! 3
        assertBool "festival open" (exists "festival.harvest" (db stOpen))
        assertBool "open: judge yes" (hasAct "judge" stOpen)
        assertBool "open: sentence no" (not (hasAct "pass sentence" stOpen))
        let stJudge = doAct "judge" stOpen
        assertBool "judged" (exists "judged.ada" (db stJudge))
        let stAfter = roundBoundary stJudge
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: sentence yes" (hasAct "pass sentence" stAfter)
        let stSent = doAct "pass sentence" stAfter
        assertBool "sentenced" (exists "sentenced.ada" (db stSent))
        assertBool "sentence once" (not (hasAct "pass sentence" stSent))

    , testCase "harvest mourning arc: vigil outside → eulogize during → bury after" $ do
        let mourn = practice
              { practiceId = "harvestMourn"
              , roles = []
              , actions =
                  [ action "[Actor]: keep vigil"
                      [ outsideFestival "harvest"
                      , Not "vigil.Actor" ]
                      [ Insert "vigil.Actor" ]
                  , action "[Actor]: deliver the eulogy"
                      [ duringFestival "harvest"
                      , Match "vigil.Actor"
                      , Not "eulogized.Actor" ]
                      [ Insert "eulogized.Actor" ]
                  , action "[Actor]: bury the dead"
                      [ outsideFestival "harvest"
                      , Match "eulogized.Actor"
                      , Not "buried.Actor" ]
                      [ Insert "buried.Actor" ]
                  ]
              }
            base = definePractices [mourn]
                     (scheduled [ festival "harvest" 3 1 [] ]
                        [ Insert "practice.harvestMourn" ])
            hasAct needle st =
              any ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada")
            doAct needle st =
              case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st "ada") of
                (ga : _) -> performAction st ga
                []       -> error ("no action matching " ++ show needle)
            st0 = base
        assertBool "before: vigil yes" (hasAct "vigil" st0)
        assertBool "before: eulogy no" (not (hasAct "eulogy" st0))
        let stV = doAct "vigil" st0
        assertBool "vigil" (exists "vigil.ada" (db stV))
        let stOpen = iterate roundBoundary stV !! 3
        assertBool "festival open" (exists "festival.harvest" (db stOpen))
        assertBool "open: eulogy yes" (hasAct "eulogy" stOpen)
        assertBool "open: bury no" (not (hasAct "bury" stOpen))
        let stE = doAct "eulogy" stOpen
        assertBool "eulogized" (exists "eulogized.ada" (db stE))
        let stAfter = roundBoundary stE
        assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
        assertBool "after: bury yes" (hasAct "bury" stAfter)
        let stB = doAct "bury" stAfter
        assertBool "buried" (exists "buried.ada" (db stB))
        assertBool "bury once" (not (hasAct "bury" stB))
    ]

  , testGroup "pulse (period heartbeat, no auto-expiry)"
    [ testCase "pulse builds a ScheduleRule with the given period" $ do
        let ScheduleRule n p body = pulse "tax" 4 [Insert "taxed.now"]
        n @?= "tax"
        p @?= 4
        assertBool "one clause" (length body == 1)
    , testCase "pulse rejects period < 1" $ do
        r <- try (evaluate (length (show (pulse "tax" 0 [Insert "x"]))))
        assertBool "bad period" (isLeft (r :: Either ErrorCall Int))
    ]

  , testGroup "engine-rule provenance exempts the reserved-family scan (v53)"
    [ testCase "registerEngineRules records the rule name; setSchedule does not" $ do
        engineRuleNames (registerEngineRules [ScheduleRule "story" 1 []] emptyState) @?= ["story"]
        engineRuleNames (setSchedule [ScheduleRule "auth" 1 []] emptyState)         @?= []

    , testCase "an authored rule writing a reserved family is flagged; the SAME body through the engine door is exempt" $ do
        -- The provenance pin, made non-vacuous: the rule body EXPLICITLY writes
        -- scenePatience.a.b (which no shipped story rule exercises). Same shape,
        -- opposite verdict — provenance, not the rule's shape, is what differs.
        let body = [([], [Insert "scenePatience.a.b"])]
            authored = setSchedule       [ScheduleRule "story" 1 body] emptyState
            engine   = registerEngineRules [ScheduleRule "story" 1 body] emptyState
        assertBool "authored rule flags ReservedFamily scenePatience"
          (any (\case ReservedFamily "scenePatience" _ _ -> True; _ -> False) (typeCheck authored))
        typeCheck engine @?= []          -- machinery may write reserved families (v45's charter)

    , testCase "a duplicate name through the engine door alone still errors loudly (the record-update forces the guard)" $ do
        -- The laziness question: registerEngineRules now record-updates
        -- engineRuleNames onto addScheduleRules' result. A record update forces
        -- its base to WHNF, so the duplicate-name guard still fires BEFORE any
        -- name is silently recorded. Forcing engineRuleNames alone must error.
        r <- try (evaluate (length (show (engineRuleNames
               (registerEngineRules [ScheduleRule "dup" 1 [], ScheduleRule "dup" 1 []] emptyState)))))
        assertBool "rejected: duplicate engine-door names share one due key"
          (isLeft (r :: Either ErrorCall Int))
    ]
  ]
