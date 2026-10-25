module Prax.EmotionSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)

import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (dbToSentences, exists, insertAll, emptyDb)
import           Prax.Query (Condition (..), query)
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, performAction,
                              possibleActions, setCharacters, roundBoundary)
import           Prax.Planner (candidateActions)
import           Prax.Emotion
import           Prax.Derive (closure)
import           Prax.Witness (CoPresence)

facts :: PraxState -> [String]
facts = dbToSentences . db

-- Coexistence -------------------------------------------------------------------


tests :: TestTree
tests = testGroup "Prax.Emotion"
  [ testGroup "coexisting feelings"
    [ testCase "angry at carol and afraid of bob coexist independently" $ do
        let st0 = performOutcome (feelToward "ada" angry "carol") emptyState
            st1 = performOutcome (feelToward "ada" afraid "bob") st0
            fs  = facts st1
        assertBool "angry at carol" ("ada.feels.angry.toward.carol" `elem` fs)
        assertBool "afraid of bob"  ("ada.feels.afraid.toward.bob" `elem` fs)

    , testCase "unfeeling one leaves the other standing" $ do
        let st0 = performOutcome (feelToward "ada" angry "carol") emptyState
            st1 = performOutcome (feelToward "ada" afraid "bob") st0
            st2 = performOutcome (unfeelToward "ada" angry "carol") st1
            fs  = facts st2
        assertBool "angry at carol discharged" ("ada.feels.angry.toward.carol" `notElem` fs)
        assertBool "afraid of bob survives"    ("ada.feels.afraid.toward.bob" `elem` fs)

    , testCase "untargeted and targeted instances of the same emotion coexist" $ do
        -- 'exists' is what 'feeling' checks; and since v39's asserted-
        -- endpoint marking, the untargeted instance ALSO survives as its own
        -- asserted fact ('dbToSentences' now emits it) even after gaining a
        -- targeted sibling underneath — the old leaf-vs-ancestor ambiguity
        -- is gone.
        let st0 = performOutcome (feel "ada" happy) emptyState
            st1 = performOutcome (feelToward "ada" happy "carol") st0
        assertBool "untargeted happy" (exists "ada.feels.happy" (db st1))
        assertBool "targeted happy"   (exists "ada.feels.happy.toward.carol" (db st1))

    , testCase "unfeel discharges the whole feeling, targets included" $ do
        let st0 = performOutcome (feelToward "ada" angry "carol") emptyState
            st1 = performOutcome (feelToward "ada" angry "bob") st0
            st2 = performOutcome (unfeel "ada" angry) st1
            fs  = facts st2
        assertBool "angry at carol gone" ("ada.feels.angry.toward.carol" `notElem` fs)
        assertBool "angry at bob gone"   ("ada.feels.angry.toward.bob" `notElem` fs)
    ]

  , testGroup "feeling/feelingToward"
    [ testCase "feeling matches a targeted instance (Match sees subtrees)" $ do
        let st = performOutcome (feelToward "ada" annoyed "carol") emptyState
        assertBool "feeling annoyed matches the targeted instance"
          (not (null (query (db st) [feeling "ada" annoyed] Map.empty)))

    , testCase "feelingToward requires the specific target" $ do
        let st = performOutcome (feelToward "ada" annoyed "carol") emptyState
        assertBool "feelingToward carol holds"
          (not (null (query (db st) [feelingToward "ada" annoyed "carol"] Map.empty)))
        assertBool "feelingToward bob does not"
          (null (query (db st) [feelingToward "ada" annoyed "bob"] Map.empty))
    ]

  -- Fade-by-lifetime (v44): each onset carries its own expiry ('feelTowardFor'
  -- -> InsertFor), and the engine retracts it at the round boundary its
  -- lifetime lapses -- per-onset spans, no synchronized sweep.
  , testGroup "feelings fade"
    [ testCase "both feelings gone after the lifetime lapses; feeling again is possible" $ do
        let withFeelings =
              performOutcome (feelTowardFor 2 "ada" afraid "bob")
                (performOutcome (feelTowardFor 2 "ada" angry "carol") emptyState)

        assertBool "angry present at onset"
          (exists "ada.feels.angry.toward.carol" (db withFeelings))
        assertBool "afraid present at onset"
          (exists "ada.feels.afraid.toward.bob" (db withFeelings))

        let st1 = roundBoundary withFeelings         -- turn 1: not yet due (due at 0+2)
        assertBool "not yet lapsed after one boundary"
          (exists "ada.feels.angry.toward.carol" (db st1))

        let st2 = roundBoundary st1                  -- turn 2: the lifetime lapses
        assertBool "angry gone at the due boundary"
          (not (exists "ada.feels.angry.toward.carol" (db st2)))
        assertBool "afraid gone at the due boundary"
          (not (exists "ada.feels.afraid.toward.bob" (db st2)))

        -- reappear-able: feeling again after the fade works exactly as before.
        let st3 = performOutcome (feelToward "ada" angry "carol") st2
        assertBool "angry can be felt again after fading"
          (exists "ada.feels.angry.toward.carol" (db st3))
    ]

  -- THE INVARIANT (load-bearing): emotions change decision-making, never what
  -- decisions can be made. Nothing in this module (and nothing pricing yet)
  -- may gate action availability — a fixture character's full candidateActions
  -- list must be identical with and without every vocabulary feeling present.
  , testGroup "express: feelings visible to co-present others"
    [ testCase "express deposits .seen beliefs of Actor.feels.<emotion>" $ do
        -- CoPresence must bind Witness (and Actor) in the world's own place vocab.
        let room :: CoPresence
            room = [ Match "at.Actor!P", Match "at.Witness!P" ]
            p = practice
              { practiceId = "room", roles = ["R"]
              , actions = [ express room angry "[Actor]: show anger" ] }
            st0 = foldl (flip performOutcome)
                    (setCharacters (map character ["ada", "bob", "cal"])
                      (definePractices [p] emptyState))
                    [ Insert "practice.room.here"
                    , Insert "at.ada!square", Insert "at.bob!square"
                    , Insert "at.cal!mill"   -- elsewhere: must not witness
                    , feel "ada" angry ]
        assertBool "express offered while angry"
          (any (("show anger" `isInfixOf`) . gaLabel) (possibleActions st0 "ada"))
        let st1 = case [ ga | ga <- possibleActions st0 "ada"
                            , "show anger" `isInfixOf` gaLabel ga ] of
                    (ga:_) -> performAction st0 ga
                    []     -> error "no express"
        assertBool "bob (co-present) saw ada feels angry"
          (exists "bob.believes.ada.feels.angry.seen" (db st1))
        assertBool "cal (elsewhere) holds no such belief"
          (not (exists "cal.believes.ada.feels.angry.seen" (db st1)))
        assertBool "ada does not witness herself"
          (not (exists "ada.believes.ada.feels.angry.seen" (db st1)))

    , testCase "expressToward deposits the targeted feeling belief" $ do
        let room :: CoPresence
            room = [ Match "at.Actor!P", Match "at.Witness!P" ]
            p = practice
              { practiceId = "room", roles = ["R"]
              , actions = [ expressToward room angry "[Actor]: bare anger at [Target]" ] }
            st0 = foldl (flip performOutcome)
                    (setCharacters (map character ["ada", "bob", "carol"])
                      (definePractices [p] emptyState))
                    [ Insert "practice.room.here"
                    , Insert "at.ada!square", Insert "at.bob!square"
                    , Insert "at.carol!square"
                    , feelToward "ada" angry "carol" ]
        let st1 = case [ ga | ga <- possibleActions st0 "ada"
                            , "bare anger at carol" `isInfixOf` gaLabel ga ] of
                    (ga:_) -> performAction st0 ga
                    []     -> error "no expressToward"
        assertBool "bob saw ada angry toward carol"
          (exists "bob.believes.ada.feels.angry.toward.carol.seen" (db st1))
        -- carol is co-present and is the Target; she still witnesses (Neq only
        -- excludes Actor). Seeing that ada is angry at her is intended.
        assertBool "carol (target, co-present) also witnesses"
          (exists "carol.believes.ada.feels.angry.toward.carol.seen" (db st1))

    , testCase "express is not offered without the feeling" $ do
        let room :: CoPresence
            room = [ Match "at.Actor!P", Match "at.Witness!P" ]
            p = practice
              { practiceId = "room", roles = ["R"]
              , actions = [ express room angry "[Actor]: show anger" ] }
            st0 = foldl (flip performOutcome)
                    (setCharacters (map character ["ada", "bob"])
                      (definePractices [p] emptyState))
                    [ Insert "practice.room.here"
                    , Insert "at.ada!square", Insert "at.bob!square" ]
        assertBool "no express without feeling"
          (not (any (("show anger" `isInfixOf`) . gaLabel) (possibleActions st0 "ada")))

    , testCase "express rejects dotted emotion tokens" $ do
        r <- try (evaluate (length (show (express [] "an.gry" "x"))))
        assertBool "dotted emotion rejected"
          (isLeft (r :: Either ErrorCall Int))
    ]

  , testGroup "intensity"
    [ testCase "feelAt plants exclusive intensity; unfeel clears it" $ do
        let st0 = foldl (flip performOutcome) emptyState (feelAt 3 "ada" angry)
        assertBool "feeling present" (exists "ada.feels.angry" (db st0))
        assertBool "intensity 3" (exists "ada.feels.angry.intensity!3" (db st0))
        let st1 = foldl (flip performOutcome) st0 (feelAt 5 "ada" angry)
        assertBool "intensity replaced exclusively"
          (exists "ada.feels.angry.intensity!5" (db st1)
           && not (exists "ada.feels.angry.intensity!3" (db st1)))
        let st2 = performOutcome (unfeel "ada" angry) st1
        assertBool "intensity gone with feeling"
          (not (exists "ada.feels.angry.intensity!5" (db st2)))

    , testCase "intensityAtLeast gates on the leaf" $ do
        let st = foldl (flip performOutcome) emptyState (feelAt 2 "ada" afraid)
        assertBool "gte 2 holds"
          (not (null (query (db st) (intensityAtLeast "ada" afraid 2) Map.empty)))
        assertBool "gte 3 fails"
          (null (query (db st) (intensityAtLeast "ada" afraid 3) Map.empty))

    , testCase "feelTowardAt + intensityTowardAtLeast" $ do
        let st = foldl (flip performOutcome) emptyState
                  (feelTowardAt 4 "ada" angry "carol")
        assertBool "targeted intensity"
          (exists "ada.feels.angry.toward.carol.intensity!4" (db st))
        assertBool "toward gate holds"
          (not (null (query (db st)
                 (intensityTowardAtLeast "ada" angry "carol" 3) Map.empty)))

    , testCase "feelAt rejects non-positive intensity" $ do
        r <- try (evaluate (length (show (feelAt 0 "ada" angry))))
        assertBool "zero rejected" (isLeft (r :: Either ErrorCall Int))
    ]

  , testGroup "intensity with lifetime"
    [ testCase "feelAtFor fades intensity with the feeling" $ do
        let st0 = foldl (flip performOutcome) emptyState (feelAtFor 2 4 "ada" angry)
        assertBool "feeling" (exists "ada.feels.angry" (db st0))
        assertBool "intensity" (exists "ada.feels.angry.intensity!4" (db st0))
        let st1 = roundBoundary st0
        assertBool "still after one" (exists "ada.feels.angry.intensity!4" (db st1))
        let st2 = roundBoundary st1
        assertBool "feeling gone" (not (exists "ada.feels.angry" (db st2)))
        assertBool "intensity gone with subtree" (not (exists "ada.feels.angry.intensity!4" (db st2)))

    , testCase "feelTowardAtFor + reject bad args" $ do
        let st = foldl (flip performOutcome) emptyState
                  (feelTowardAtFor 1 2 "ada" afraid "carol")
        assertBool "targeted" (exists "ada.feels.afraid.toward.carol.intensity!2" (db st))
        r <- try (evaluate (length (show (feelAtFor 0 2 "ada" angry))))
        assertBool "zero lifetime" (isLeft (r :: Either ErrorCall Int))
        r2 <- try (evaluate (length (show (feelAtFor 2 0 "ada" angry))))
        assertBool "zero intensity" (isLeft (r2 :: Either ErrorCall Int))
    ]

  , testGroup "default lifetimes"
    [ testCase "defaultLifetime table + feelDefault / feelTowardDefault" $ do
        defaultLifetime "surprised" @?= 1
        defaultLifetime "happy" @?= 5
        defaultLifetime "unknown-mood" @?= 3
        let st0 = foldl (flip performOutcome) emptyState
                    [ feelDefault "ana" happy
                    , feelTowardDefault "ana" angry "bob" ]
        assertBool "happy" (exists "ana.feels.happy" (db st0))
        assertBool "toward" (exists "ana.feels.angry.toward.bob" (db st0))
    ]

  , testGroup "the invariant: feelings never gate action availability"
    [ testCase "candidateActions is identical with and without every feeling" $ do
        let vocabulary = [happy, sad, angry, afraid, disgusted, surprised, annoyed, pleased]
            fixtureP = practice
              { practiceId = "fixture"
              , practiceName = "a fixture affordance"
              , roles = ["W"]
              , actions =
                  [ action "[Actor]: wave" [ Match "practice.fixture.W" ] []
                  , action "[Actor]: greet [Other]"
                      [ Match "character.Other", Neq "Actor" "Other" ] []
                  ]
              }
            fix    = character "fix"
            friend = character "pal"
            fixtureWorld =
              foldl (flip performOutcome)
                (setCharacters [fix, friend] (definePractices [fixtureP] emptyState))
                [ Insert "character.fix", Insert "character.pal"
                , Insert "practice.fixture.fix" ]
            baseline = candidateActions fixtureWorld fix
            withFeelings =
              foldl (flip performOutcome) fixtureWorld
                (concat [ [feel "fix" e, feelToward "fix" e "pal"] | e <- vocabulary ])
            afterFeelings = candidateActions withFeelings fix
        baseline @?= afterFeelings
    ]

  , testCase "hasMood matches mood subtree" $
      hasMood "ana" @?= Match "mood.ana"
  , testCase "everMood / neverMood are Exists/Absent of mood leaf" $ do
      everMood "ana" @?= Exists [ Match "mood.ana!Emotion" ]
      neverMood "ana" @?= Absent [ Match "mood.ana!Emotion" ]

  , testCase "lacksMood is Not of mood subtree" $
      lacksMood "ana" @?= Not "mood.ana"

  , testCase "moodFromFeeling derives baseline mood from episodic feel" $ do
      let axs = [ moodFromFeeling "happy" ]
          db0 = insertAll ["ana.feels.happy"] emptyDb
      case closure axs db0 of
        Left _ -> assertBool "closure" False
        Right db1 -> assertBool "mood" (exists "mood.ana!happy" db1)

  , testCase "setMood exclusive baseline; inMood matches; clearMood retracts" $ do
      let st0 = performOutcome (setMood "ana" "cheerful") emptyState
      assertBool "mood" (exists "mood.ana!cheerful" (db st0))
      let st1 = performOutcome (setMood "ana" "gloomy") st0
      assertBool "overwrite" (exists "mood.ana!gloomy" (db st1))
      assertBool "old gone" (not (exists "mood.ana!cheerful" (db st1)))
      -- gate via practice
      let p = practice
            { practiceId = "moodgate"
            , roles = []
            , actions = [ action "[Actor]: brood" [inMood "Actor" "gloomy"] [Insert "brooded.Actor"] ]
            }
          world = definePractices [p]
                    (foldl (flip performOutcome) emptyState
                      [ Insert "practice.moodgate", setMood "ana" "gloomy", setMood "ben" "cheerful" ])
      assertBool "ana" (any ("brood" `isInfixOf`) (map gaLabel (possibleActions world "ana")))
      assertBool "ben" (not (any ("brood" `isInfixOf`) (map gaLabel (possibleActions world "ben"))))
      let st2 = performOutcome (clearMood "ana") st1
      assertBool "cleared" (not (exists "mood.ana!gloomy" (db st2)))

  , testCase "lacksFeeling is Not of feels path" $
      lacksFeeling "ada" "angry" @?= Not "ada.feels.angry"

  , testCase "lacksFeelingToward is Not of toward path" $
      lacksFeelingToward "ada" "angry" "bex" @?= Not "ada.feels.angry.toward.bex"


  , testCase "everFeeling / neverFeeling are Exists/Absent over feels.*" $ do
      everFeeling "ana" @?= Exists [ Match "ana.feels.Emotion" ]
      neverFeeling "ana" @?= Absent [ Match "ana.feels.Emotion" ]

  , testCase "everFeelingToward / neverFeelingToward are Exists/Absent over feels.*.toward.*" $ do
      everFeelingToward "ana" @?= Exists [ Match "ana.feels.Emotion.toward.Target" ]
      neverFeelingToward "ana" @?= Absent [ Match "ana.feels.Emotion.toward.Target" ]
  , testCase "hasFeeling / hasFeelingToward alias feeling*" $ do
      hasFeeling "ada" "angry" @?= feeling "ada" "angry"
      hasFeelingToward "ada" "angry" "ben" @?= feelingToward "ada" "angry" "ben"

  , testCase "hasInMood aliases inMood" $
      hasInMood "ada" "gloomy" @?= inMood "ada" "gloomy"

  ]
