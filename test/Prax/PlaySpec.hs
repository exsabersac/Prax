-- | Authorship pins for the Play demo script (`prax play` / `prax flow`).
-- Behavioural scene/ending drive lives in ScriptSpec; this module nails the
-- exported script shape so a silent rewrite of cast, openings, or endings
-- fails loudly.
module Prax.PlaySpec (tests) where

import           Data.Char (toLower)
import           Data.List (isInfixOf)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Query (Condition (..))
import           Prax.Types (Want (..), deadSentence, characters, charName, charWants)
import           Prax.Script
  ( Script (..), Scene (..), CastMember (..), Junction (..)
  , currentSceneOf
  )
import           Prax.Worlds.Play (playScript, playWorld, playerName)

tests :: TestTree
tests = testGroup "Prax.Worlds.Play (script authorship)"
  [ testCase "playerName is marcus (the poet)" $
      playerName @?= "marcus"

  , testCase "playScript starts at confidence with the intrigue triad cast" $ do
      scriptStart playScript @?= "confidence"
      map castName (scriptCast playScript) @?= ["marcus", "artus", "cassia"]
      map castPlayable (scriptCast playScript) @?= [True, False, False]

  , testCase "cassia wants artus dead (drives the banquet poison beat)" $ do
      let cassia = head [ c | c <- scriptCast playScript, castName c == "cassia" ]
      map wantConditions (castDesires cassia)
        @?= [[ Match (deadSentence "artus") ]]

  , testCase "two scenes: confidence → banquet, with authored openings" $ do
      map sceneId (scriptScenes playScript) @?= ["confidence", "banquet"]
      case scriptScenes playScript of
        [conf, banq] -> do
          assertBool "confidence opening names the portico"
            ("portico" `isInfixOf` map toLower (sceneOpening conf))
          assertBool "banquet opening names the hall"
            ("banquet" `isInfixOf` map toLower (sceneOpening banq))
          length (sceneBeats conf) @?= 1
          length (sceneBeats banq) @?= 4
        _ -> assertBool "expected exactly two scenes" False

  , testCase "confidence junctions to banquet; banquet ends in three named endings" $ do
      case scriptScenes playScript of
        [conf, banq] -> do
          map junctionName (sceneJunctions conf) @?= ["toBanquet"]
          map junctionTo (sceneJunctions conf) @?= [Just "banquet"]
          map junctionName (sceneJunctions banq)
            @?= ["betrayal", "loyalty", "complicity"]
          map junctionTo (sceneJunctions banq) @?= [Nothing, Nothing, Nothing]
        _ -> assertBool "expected exactly two scenes" False

  , testCase "playWorld is the compile of playScript (start scene + cast)" $ do
      currentSceneOf playWorld @?= Just (scriptStart playScript)
      map charName (characters playWorld)
        @?= map castName (scriptCast playScript)
      let cassia = head [ c | c <- characters playWorld, charName c == "cassia" ]
      assertBool "cassia still wants artus dead after compile"
        (any (([Match (deadSentence "artus")] ==) . wantConditions) (charWants cassia))
  ]
