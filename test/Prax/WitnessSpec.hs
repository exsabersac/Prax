module Prax.WitnessSpec (tests) where

import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Query (Condition (..), satisfies)
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, possibleActions, performAction, setCharacters)
import           Prax.Witness

-- A minimal world: three located characters, one observable act.
-- Co-presence: sharing a place.
together :: CoPresence
together = [ Match "at.Actor!P", Match "at.Witness!P" ]

wave :: Action
wave = observable together "waved.Actor" $
  action "[Actor]: wave" [ Match "at.Actor!Place" ] [ Insert "waved" ]

world :: PraxState
world = foldl (flip performOutcome) base setup
  where
    base = setCharacters (map character ["ann", "bea", "cal"])
             (definePractices [p] emptyState)
    p = practice { practiceId = "greet", roles = ["R"], actions = [wave] }
    setup =
      [ Insert "practice.greet.stage"
      , Insert "at.ann!square", Insert "at.bea!square", Insert "at.cal!mill" ]

-- ann performs her (only) available action.
annActs :: PraxState
annActs = case possibleActions world "ann" of
  (ga : _) -> performAction world ga
  []       -> error "wave not offered to ann"

tests :: TestTree
tests = testGroup "Prax.Witness"
  [ testCase "a co-present character comes to believe the event; an absent one doesn't" $ do
      assertBool "bea (co-present) believes it, provenance seen"
        (exists "bea.believes.waved.ann.seen" (db annActs))
      assertBool "cal (elsewhere) holds no such belief"
        (not (exists "cal.believes.waved.ann.seen" (db annActs)))

  , testCase "the actor is not their own witness" $
      assertBool "ann holds no belief about her own act"
        (not (exists "ann.believes.waved.ann.seen" (db annActs)))

  , testCase "observable only appends; the action's own effects are untouched" $ do
      actionName wave @?= "[Actor]: wave"
      take 1 (actionOutcomes wave) @?= [ Insert "waved" ]

  , testCase "saw is the seen-provenance belief condition" $
      saw "W" "waved.ann" @?= Match "W.believes.waved.ann.seen"

  , testCase "neverSaw is Absent over the seen leaf" $
      neverSaw "W" "waved.ann" @?= Absent [ Match "W.believes.waved.ann.seen" ]

  , testCase "the seen deposit is multi-valued: other evidence survives beside it" $ do
      -- Pre-plant hearsay under the same belief node, then let the witness
      -- deposit fire: with multi-valued (.) storage both edges coexist; an
      -- exclusive (!) deposit would destroy the hearsay. (Regression guard for
      -- the v20 provenance vocabulary.)
      let planted = performOutcome (Insert "bea.believes.waved.ann.heard.cal") world
          st = case possibleActions planted "ann" of
                 (ga : _) -> performAction planted ga
                 []       -> error "wave not offered to ann"
      assertBool "the witness deposit landed"
        (exists "bea.believes.waved.ann.seen" (db st))
      assertBool "the pre-existing hearsay edge survived the deposit"
        (exists "bea.believes.waved.ann.heard.cal" (db st))

  , testCase "everSaw is Exists over the seen leaf" $
      everSaw "W" "waved.ann" @?= Exists [ Match "W.believes.waved.ann.seen" ]

  , testCase "lacksSaw is Not of saw path" $
      lacksSaw "ada" "theft" @?= Not "ada.believes.theft.seen"

  , testCase "hasSaw aliases saw" $
      hasSaw "ada" "theft" @?= saw "ada" "theft"

  , testCase "saw / hasSaw / everSaw evaluate after wave" $ do
      assertBool "neverSaw on clean"
        (satisfies (db world) [neverSaw "bea" "waved.ann"] Map.empty)
      assertBool "lacksSaw on clean"
        (satisfies (db world) [lacksSaw "bea" "waved.ann"] Map.empty)
      assertBool "saw"
        (satisfies (db annActs) [saw "bea" "waved.ann"] Map.empty)
      assertBool "hasSaw"
        (satisfies (db annActs) [hasSaw "bea" "waved.ann"] Map.empty)
      assertBool "everSaw"
        (satisfies (db annActs) [everSaw "bea" "waved.ann"] Map.empty)
      assertBool "neverSaw fails"
        (not (satisfies (db annActs) [neverSaw "bea" "waved.ann"] Map.empty))
      assertBool "lacksSaw fails"
        (not (satisfies (db annActs) [lacksSaw "bea" "waved.ann"] Map.empty))
      assertBool "cal neverSaw"
        (satisfies (db annActs) [neverSaw "cal" "waved.ann"] Map.empty)

  , testCase "asRole redirects Witness variable in co-presence template" $ do
      asRole "Hearer" together
        @?= [ Match "at.Actor!P", Match "at.Hearer!P" ]
      asRole "Victim" [ Match "at.Witness!Spot", Neq "Witness" "Actor" ]
        @?= [ Match "at.Victim!Spot", Neq "Victim" "Actor" ]

  ]
