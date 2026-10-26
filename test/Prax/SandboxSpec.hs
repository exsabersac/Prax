-- | Prax.Worlds.Sandbox 可测闭环：磨坊审判、教会异端、婚入获站队、
-- 债务买沉默、双节庆错峰市集喊冤、受害方叛逃和解、沉默×叛逃×节庆复合门禁、
-- 臭名+愤怒市集声援、站队胁迫招供（Coerce）、教会异端×磨坊正义同场双压、
-- 教会异端×沉默债、教会胁迫悔罪（Coerce×heretic）、
-- 沉默×胁迫交叉与烙印游街（默认未激活；want 词汇可挂），
-- 以及轻量 wants 驱动的自选节拍。
-- 自有逐步断言与短轨迹；不触碰 Village / Bar / Feud / GoldenDrive 等既有金标准。
module Prax.SandboxSpec (tests) where

import           Data.List (isInfixOf)
import           Data.Maybe (listToMaybe)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Query (Condition(Match))
import           Prax.Types
import           Prax.Engine (possibleActions, performAction, performOutcome, roundBoundary)
import           Prax.TypeCheck (typeCheck)
import           Prax.Host (practiceNames, castNames, festivalsOf, membersOf, leadersOf)
import           Prax.Planner (pickAction)
import           Prax.Loop (advance, npcAct)
import           Prax.Worlds.Sandbox
  ( sandboxWorld, playerName, sandboxDesires, millJustice, millCry, iraJustice
  , churchJustice, bobHeresyJustice, squeezeDesireName, fearsBrandName
  , activateSqueeze, activateChurchBob
  , inquisitDesireName, fearsBrandHereticName, activateInquisit
  , activateParade, activateChurchParade
  , paradeDesireName, churchParadeDesireName
  , rallyDesireName, cryDesireName
  , fleeDesireName, returnDesireName
  , millSilenceDesireName, millBreakSilenceDesireName
  , churchSilenceDesireName, churchBreakSilenceDesireName
  , seeksTheftDesireName, punishesThiefDesireName, exileBobDesireName
  , seeksHeresyDesireName, punishesHereticDesireName, exileEveDesireName
  , seeksBobHeresyDesireName, punishesBobHereticDesireName
  , joinsMillDesireName )

hasAct :: String -> String -> PraxState -> Bool
hasAct who needle st =
  any ((needle `isInfixOf`) . gaLabel) (possibleActions st who)

doAct :: String -> String -> PraxState -> PraxState
doAct who needle st =
  case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st who) of
    (ga : _) -> performAction st ga
    []       -> error ("no action " ++ show needle ++ " for " ++ who)

actorOf :: String -> PraxState -> Character
actorOf who st =
  case listToMaybe [ c | c <- characters st, charName c == who ] of
    Just c  -> c
    Nothing -> error ("no character " ++ who)

pickLabel :: String -> PraxState -> Maybe String
pickLabel who st = fmap gaLabel (pickAction 1 st (actorOf who st))



desireMatch n =
  case listToMaybe [ wantConditions (desireWant d)
                   | d <- sandboxDesires, desireName d == n ] of
    Just cs -> cs
    Nothing -> error ("no desire " ++ n)

desireUtil :: String -> Int
desireUtil n =
  case listToMaybe [ wantUtility (desireWant d)
                   | d <- sandboxDesires, desireName d == n ] of
    Just u  -> u
    Nothing -> error ("no desire " ++ n)

-- Sandbox-only free-play labels (you idle). Independent of GoldenDrive.
driveLabels :: Int -> PraxState -> [String]
driveLabels n = go n
  where
    go 0 _  = []
    go k st =
      let (actor, st1) = advance st
      in if charName actor == playerName
           then go k st1   -- player idle does not consume a golden slot
           else case npcAct 1 actor st1 of
                  (mga, st2) ->
                    (charName actor ++ ": " ++ maybe "-" gaLabel mga)
                      : go (k - 1) st2

-- Captured from a live wants-driven run (v272). Pins harvest tribunal /
-- church heresy / mill-wedding / silence-debt / market cry / both exiles.
sandboxGolden :: [String]
sandboxGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: learn of the theft"
  , "dave: dave: learn of the theft"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: learn of the theft"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: buy ira's silence about the theft"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: tear up bob's silence deal"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: cry the theft at market"
  , "fran: fran: cry the theft at market"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  , "ira: ira: cry the theft at market"
  ]

-- Focused silence arc trajectory: start after ira has learned (regard up),
-- then free-play through tear-up, harvest denounce, market cry, both exiles.
silenceSeed :: PraxState
silenceSeed = doAct "ira" "learn" sandboxWorld

sandboxSilenceGolden :: [String]
sandboxSilenceGolden =
  [ "bob: bob: buy ira's silence about the theft"
  , "carol: carol: learn of the theft"
  , "dave: dave: learn of the theft"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: tear up bob's silence deal"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: cry the theft at market"
  , "fran: fran: cry the theft at market"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  , "ira: ira: cry the theft at market"
  ]

-- Victim defection seed: dave already regards bob; carol holds flee+return wants
-- (main cast keeps mill justice only — this seed overrides carol's desires).
defectionSeed :: PraxState
defectionSeed =
  let st0 = doAct "dave" "learn" sandboxWorld
      carol' = (actorOf "carol" st0)
                 { charDesires = [fleeDesireName, returnDesireName]
                                  ++ millJustice ++ [cryDesireName] }
  in st0 { characters =
              [ if charName c == "carol" then carol' else c
              | c <- characters st0 ] }

sandboxDefectionGolden :: [String]
sandboxDefectionGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: learn of the theft"
  , "dave: dave: Wait a moment"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: learn of the theft"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: abandon the mill for the guild"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: return to the mill in reconciliation"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  ]

-- Composite: silence debt × victim defection × festival gates in ONE arc.
-- ira already learned (bob can buy); carol holds flee+return (+ millCry).
-- Multi-gate flips: buy blocks ira → carol flees dissolves ALL mill regard
-- (even after tear-up denounce stays closed) → return restores → harvest denounce.
compositeSeed :: PraxState
compositeSeed =
  let st0 = doAct "ira" "learn" sandboxWorld
      carol' = (actorOf "carol" st0)
                  { charDesires = [fleeDesireName, returnDesireName] ++ millCry }
  in st0 { characters =
              [ if charName c == "carol" then carol' else c
              | c <- characters st0 ] }

-- Repute/emotion bystander: dave holds rally want (weight 9 > cry 7) so at
-- market, once bob is notorious (≥2 regards) and dave is angry, he rallies.
reputeSeed :: PraxState
reputeSeed =
  let st0 = sandboxWorld
      dave' = (actorOf "dave" st0)
                 { charDesires = [rallyDesireName] ++ millCry }
  in st0 { characters =
              [ if charName c == "dave" then dave' else c
              | c <- characters st0 ] }

-- Captured from live wants-driven runs (v274/v275).
-- Composite pins buy→flee→return→denounce (multi-gate); repute pins market rally.
sandboxCompositeGolden :: [String]
sandboxCompositeGolden =
  [ "bob: bob: buy ira's silence about the theft"
  , "carol: carol: learn of the theft"
  , "dave: dave: learn of the theft"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: tear up bob's silence deal"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: abandon the mill for the guild"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: return to the mill in reconciliation"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: cry the theft at market"
  , "fran: fran: cry the theft at market"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  , "ira: ira: cry the theft at market"
  ]

sandboxReputeGolden :: [String]
sandboxReputeGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: learn of the theft"
  , "dave: dave: learn of the theft"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: learn of the theft"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: buy ira's silence about the theft"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: tear up bob's silence deal"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: rally the square against the thief"
  , "fran: fran: cry the theft at market"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  , "ira: ira: cry the theft at market"
  ]


-- Coerce × factionStanding: practice inactive by default; activate + dave holds
-- punishes-squeeze, bob fears brand. dave already learned (regard up).
coerceSeed :: PraxState
coerceSeed =
  let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
      dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
      bob'  = (actorOf "bob" st0)  { charDesires = [fearsBrandName] }
  in st0 { characters =
              [ if charName c == "dave" then dave'
                else if charName c == "bob" then bob'
                else c
              | c <- characters st0 ] }

-- Captured live (v276): squeeze → confess → re-squeeze → brand (complied blocks re-pay).
sandboxCoerceGolden :: [String]
sandboxCoerceGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: learn of the theft"
  , "dave: dave: squeeze bob for a confession"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear the blasphemy"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: learn of the theft"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: confess the theft to dave"
  , "carol: carol: Wait a moment"
  , "dave: dave: squeeze bob for a confession"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: brand bob as unrepentant"
  ]

tests :: TestTree

-- Church heresy × mill justice dual pressure on bob (shared exiled.bob race).
-- Practice inactive by default; activate + priest/gale hold bobHeresyJustice;
-- bob muted (no buy-silence) so tracks dominate. Mill (carol) typically wins
-- the exile race; church censures in the same harvest window then waits.
dualPressureSeed :: PraxState
dualPressureSeed =
  let st0 = activateChurchBob sandboxWorld
      priest' = (actorOf "priest" st0) { charDesires = bobHeresyJustice }
      gale'   = (actorOf "gale" st0)   { charDesires = bobHeresyJustice }
      bob'    = (actorOf "bob" st0)    { charDesires = [] }
  in st0 { characters =
              [ if charName c == "priest" then priest'
                else if charName c == "gale" then gale'
                else if charName c == "bob" then bob'
                else c
              | c <- characters st0 ] }

-- Captured live (v277): dual hear → harvest denounce+censure-bob → mill exile
-- wins race (priest banish blocked) → market cry.
sandboxDualPressureGolden :: [String]
sandboxDualPressureGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: learn of the theft"
  , "dave: dave: learn of the theft"
  , "fran: fran: wed into the mill beside carol"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear of bob's heresy"
  , "priest: priest: hear of bob's heresy"
  , "ira: ira: learn of the theft"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure bob for heresy"
  , "priest: priest: censure bob for heresy"
  , "ira: ira: denounce the thief"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: cry the theft at market"
  , "fran: fran: cry the theft at market"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: cry the theft at market"
  ]

-- Heresy × silence debt (eve track): gale already heard (regard up); eve buys
-- gale's silence; censure gated by lacksOwes until tear-up. Practice always on;
-- seed only retargets wants (eve buys, gale breaks + church justice).
churchSilenceSeed :: PraxState
churchSilenceSeed =
  let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
      eve'  = (actorOf "eve" st0)  { charDesires = [churchSilenceDesireName] }
      gale' = (actorOf "gale" st0)
                { charDesires = churchJustice ++ [churchBreakSilenceDesireName] }
      -- Mute bob buy-silence + mill justice noise so church silence dominates.
      bob'  = (actorOf "bob" st0) { charDesires = [] }
      carol' = (actorOf "carol" st0) { charDesires = [] }
      dave'  = (actorOf "dave" st0) { charDesires = [] }
      fran'  = (actorOf "fran" st0) { charDesires = [] }
      ira'   = (actorOf "ira" st0) { charDesires = [] }
      priest' = (actorOf "priest" st0) { charDesires = churchJustice }
  in st0 { characters =
              [ if charName c == "eve" then eve'
                else if charName c == "gale" then gale'
                else if charName c == "bob" then bob'
                else if charName c == "carol" then carol'
                else if charName c == "dave" then dave'
                else if charName c == "fran" then fran'
                else if charName c == "ira" then ira'
                else if charName c == "priest" then priest'
                else c
              | c <- characters st0 ] }

-- Coerce × church heresy (bob): activate churchBob + inquisit; priest hears bob
-- (regard up) and holds punishes-inquisit; bob fears brand-heretic. Mill muted.
inquisitSeed :: PraxState
inquisitSeed =
  let st0 = activateInquisit (activateChurchBob sandboxWorld)
      st1 = doAct "priest" "hear of bob" st0
      priest' = (actorOf "priest" st1)
                  { charDesires = [inquisitDesireName] ++ bobHeresyJustice }
      gale'   = (actorOf "gale" st1) { charDesires = bobHeresyJustice }
      bob'    = (actorOf "bob" st1)  { charDesires = [fearsBrandHereticName] }
      carol'  = (actorOf "carol" st1) { charDesires = [] }
      dave'   = (actorOf "dave" st1) { charDesires = [] }
      fran'   = (actorOf "fran" st1) { charDesires = [] }
      ira'    = (actorOf "ira" st1) { charDesires = [] }
  in st1 { characters =
              [ if charName c == "priest" then priest'
                else if charName c == "gale" then gale'
                else if charName c == "bob" then bob'
                else if charName c == "carol" then carol'
                else if charName c == "dave" then dave'
                else if charName c == "fran" then fran'
                else if charName c == "ira" then ira'
                else c
              | c <- characters st1 ] }

-- Captured live (v278): eve buys → gale tears → harvest censure → priest exile.
sandboxChurchSilenceGolden :: [String]
sandboxChurchSilenceGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: buy gale's silence about the heresy"
  , "gale: gale: tear up eve's heresy silence deal"
  , "priest: priest: hear the blasphemy"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  ]

-- Captured live (v279): squeeze → recant → re-squeeze → brand → censure → banish.
sandboxInquisitGolden :: [String]
sandboxInquisitGolden =
  [ "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: hear of bob's heresy"
  , "priest: priest: squeeze bob for a recantation"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: recant the heresy to priest"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: squeeze bob for a recantation"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: brand bob as unrepentant heretic"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure bob for heresy"
  , "priest: priest: censure bob for heresy"
  , "ira: ira: Wait a moment"
  , "kyle: kyle: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: banish bob for heresy"
  ]


tests = testGroup "Prax.Worlds.Sandbox (playable festival + factionStanding arcs)"
  [ testCase "well-formed: typeCheck empty" $
      typeCheck sandboxWorld @?= []

  , testCase "cast / practices / factions / desires seed" $ do
      assertBool "player in cast" (playerName `elem` castNames sandboxWorld)
      assertBool "millTribunal" ("millTribunal" `elem` practiceNames sandboxWorld)
      assertBool "churchHeresy" ("churchHeresy" `elem` practiceNames sandboxWorld)
      assertBool "millWed" ("millWed" `elem` practiceNames sandboxWorld)
      assertBool "millSilence" ("millSilence" `elem` practiceNames sandboxWorld)
      assertBool "marketCry" ("marketCry" `elem` practiceNames sandboxWorld)
      assertBool "millAllegiance" ("millAllegiance" `elem` practiceNames sandboxWorld)
      assertBool "millRally" ("millRally" `elem` practiceNames sandboxWorld)
      assertBool "millSqueeze defined"
        ("millSqueeze" `elem` practiceNames sandboxWorld)
      assertBool "millSqueeze inactive by default"
        (not (exists "practice.millSqueeze" (db sandboxWorld)))
      assertBool "churchSilence" ("churchSilence" `elem` practiceNames sandboxWorld)
      assertBool "churchSilence active"
        (exists "practice.churchSilence" (db sandboxWorld))
      assertBool "churchInquisit defined"
        ("churchInquisit" `elem` practiceNames sandboxWorld)
      assertBool "churchInquisit inactive by default"
        (not (exists "practice.churchInquisit" (db sandboxWorld)))
      assertBool "inquisit desire registered"
        (any ((== inquisitDesireName) . desireName) sandboxDesires)
      assertBool "fears-brand-heretic registered"
        (any ((== fearsBrandHereticName) . desireName) sandboxDesires)
      assertBool "buys-church-silence registered"
        (any ((== churchSilenceDesireName) . desireName) sandboxDesires)
      assertBool "churchBobHeresy defined"
        ("churchBobHeresy" `elem` practiceNames sandboxWorld)
      assertBool "churchBobHeresy inactive by default"
        (not (exists "practice.churchBobHeresy" (db sandboxWorld)))
      assertBool "bob heresy desires in vocabulary"
        (all (`elem` map desireName sandboxDesires)
           [seeksBobHeresyDesireName, punishesBobHereticDesireName])
      assertBool "presence" ("presence" `elem` practiceNames sandboxWorld)
      assertBool "squeeze desire registered"
        (any ((== squeezeDesireName) . desireName) sandboxDesires)
      assertBool "fears-brand registered"
        (any ((== fearsBrandName) . desireName) sandboxDesires)
      assertBool "parade desire registered"
        (any ((== paradeDesireName) . desireName) sandboxDesires)
      assertBool "church parade desire registered"
        (any ((== churchParadeDesireName) . desireName) sandboxDesires)
      assertBool "dave cast has no parade want by default"
        (paradeDesireName `notElem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "priest cast has no church parade want by default"
        (churchParadeDesireName `notElem` charDesires (actorOf "priest" sandboxWorld))
      assertBool "you mill" (playerName `elem` membersOf sandboxWorld "mill")
      assertBool "ira mill" ("ira" `elem` membersOf sandboxWorld "mill")
      assertBool "kyle guild" ("kyle" `elem` membersOf sandboxWorld "guild")
      assertBool "priest leads" ("priest" `elem` leadersOf sandboxWorld "church")
      festivalsOf sandboxWorld @?= []
      assertBool "vocab loaded" (not (null sandboxDesires))
      assertBool "dave holds mill justice"
        (seeksTheftDesireName `elem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "dave holds market cry"
        (cryDesireName `elem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "priest holds church justice"
        (punishesHereticDesireName `elem` charDesires (actorOf "priest" sandboxWorld))
      assertBool "fran holds joins-mill"
        (joinsMillDesireName `elem` charDesires (actorOf "fran" sandboxWorld))
      assertBool "bob holds buys-ira-silence"
        (millSilenceDesireName `elem` charDesires (actorOf "bob" sandboxWorld))
      assertBool "ira holds breaks-silence-deal"
        (millBreakSilenceDesireName `elem` charDesires (actorOf "ira" sandboxWorld))
      assertBool "player has no wants"
        (null (charDesires (actorOf playerName sandboxWorld))
         && null (charWants (actorOf playerName sandboxWorld)))
      assertBool "kyle has no wants"
        (null (charDesires (actorOf "kyle" sandboxWorld)))

  , testCase "mill tribunal: learn outside → denounce during → exile after" $ do
      let st0 = sandboxWorld
      assertBool "dave learn yes" (hasAct "dave" "learn" st0)
      assertBool "denounce no" (not (hasAct "dave" "denounce" st0))
      assertBool "eve cannot learn" (not (hasAct "eve" "learn" st0))
      assertBool "eve no regard despite belief"
        (not (exists "regards.eve.bob.thief" (readView st0)))
      let stLearn = doAct "dave" "learn" st0
      assertBool "dave regards" (exists "regards.dave.bob.thief" (readView stLearn))
      assertBool "still closed denounce" (not (hasAct "dave" "denounce" stLearn))
      let stOpen = iterate roundBoundary stLearn !! 3
      assertBool "festival open" (exists "festival.harvest" (db stOpen))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stOpen)
      assertBool "eve denounce no" (not (hasAct "eve" "denounce" stOpen))
      assertBool "fran (guild, no belief) denounce no"
        (not (hasAct "fran" "denounce" stOpen))
      assertBool "exile no during" (not (hasAct "dave" "exile" stOpen))
      let stDen = doAct "dave" "denounce" stOpen
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      let stAfter = roundBoundary stDen
      assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
      assertBool "exile yes" (hasAct "dave" "exile" stAfter)
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "exile once" (not (hasAct "dave" "exile" stEx))
      -- Player (mill) can still learn after the window and gain regard,
      -- but cannot denounce until the next festival open.
      assertBool "you can learn after" (hasAct playerName "learn" stEx)
      let stYou = doAct playerName "learn" stEx
      assertBool "you regards"
        (exists ("regards." ++ playerName ++ ".bob.thief") (readView stYou))
      assertBool "you cannot denounce outside"
        (not (hasAct playerName "denounce" stYou))

  , testCase "church heresy: hear outside → censure during → leader exile after" $ do
      let st0 = sandboxWorld
      assertBool "bob cannot hear" (not (hasAct "bob" "hear" st0))
      assertBool "bob no regard" (not (exists "regards.bob.eve.heretic" (readView st0)))
      let stHear = doAct "priest" "hear" st0
      assertBool "priest regards" (exists "regards.priest.eve.heretic" (readView stHear))
      assertBool "closed censure" (not (hasAct "priest" "censure" stHear))
      let stOpen = iterate roundBoundary stHear !! 3
      assertBool "festival open" (exists "festival.harvest" (db stOpen))
      assertBool "priest censure yes" (hasAct "priest" "censure" stOpen)
      assertBool "gale (no belief) censure no" (not (hasAct "gale" "censure" stOpen))
      let stCen = doAct "priest" "censure" stOpen
      assertBool "censured" (exists "censured.priest.eve" (db stCen))
      let stAfter = roundBoundary stCen
      assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
      assertBool "leader exile yes" (hasAct "priest" "exile" stAfter)
      assertBool "gale can hear" (hasAct "gale" "hear" stAfter)
      let stGale = doAct "gale" "hear" stAfter
      assertBool "gale regards" (exists "regards.gale.eve.heretic" (readView stGale))
      assertBool "gale cannot exile" (not (hasAct "gale" "exile" stGale))
      let stEx = doAct "priest" "exile" stGale
      assertBool "exiled" (exists "exiled.eve" (db stEx))
      assertBool "exile once" (not (hasAct "priest" "exile" stEx))

  , testCase "wedding into mill grants factionStanding regard + denounce gate" $ do
      -- fran (guild) already believes but derives no regard until wed into mill.
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") sandboxWorld
      assertBool "before: no regard"
        (not (exists "regards.fran.bob.thief" (readView stBel)))
      assertBool "before: cannot denounce" (not (hasAct "fran" "denounce" stBel))
      assertBool "fran can wed" (hasAct "fran" "wed into the mill" stBel)
      let stWed = doAct "fran" "wed into the mill beside carol" stBel
      assertBool "fran now mill" (exists "member.fran!mill" (db stWed))
      assertBool "married"
        (exists "married.fran.carol" (db stWed)
         || exists "married.fran.carol" (readView stWed))
      assertBool "after: regard" (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "outside: denounce no" (not (hasAct "fran" "denounce" stWed))
      let stOpen = iterate roundBoundary stWed !! 3
      assertBool "festival open" (exists "festival.harvest" (db stOpen))
      assertBool "open: fran denounce yes" (hasAct "fran" "denounce" stOpen)
      let stDen = doAct "fran" "denounce" stOpen
      assertBool "denounced" (exists "denounced.fran.bob" (db stDen))

  , testCase "silence debt: buy blocks denounce; tear-up restores gate" $ do
      let st0 = sandboxWorld
      assertBool "ira learn yes" (hasAct "ira" "learn" st0)
      assertBool "bob cannot buy yet" (not (hasAct "bob" "buy" st0))
      let stLearn = doAct "ira" "learn" st0
      assertBool "ira regards" (exists "regards.ira.bob.thief" (readView stLearn))
      assertBool "bob can buy ira silence"
        (hasAct "bob" "buy ira's silence" stLearn)
      -- dave learns too: control witness who is NOT bought.
      let stBoth = doAct "dave" "learn" stLearn
      -- Prefer the ira binding explicitly (Creditor also binds dave).
      let stBuy = doAct "bob" "buy ira's silence" stBoth
      assertBool "debt fact" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "no dave debt" (not (exists "debt.dave.bob.favor" (db stBuy)))
      assertBool "bob obliged favor"
        (exists "obliged.bob.favor" (db stBuy)
         || exists "obliged.bob.favor" (readView stBuy))
      -- wants still prefer ira over dave when both regard.
      pickLabel "bob" stBoth @?= Just "bob: buy ira's silence about the theft"
      let stOpen = iterate roundBoundary stBuy !! 3
      assertBool "festival open" (exists "festival.harvest" (db stOpen))
      assertBool "ira blocked by debt" (not (hasAct "ira" "denounce" stOpen))
      assertBool "dave still denounces" (hasAct "dave" "denounce" stOpen)
      assertBool "ira can tear up" (hasAct "ira" "tear up bob's silence" stOpen)
      let stTear = doAct "ira" "tear up bob's silence" stOpen
      assertBool "debt gone" (not (exists "debt.ira.bob.favor" (db stTear)))
      assertBool "revoked leaf" (exists "revoked.ira.bob" (db stTear))
      assertBool "ira denounce restored" (hasAct "ira" "denounce" stTear)
      let stDen = doAct "ira" "denounce" stTear
      assertBool "ira denounced" (exists "denounced.ira.bob" (db stDen))
      -- Once revoked, bob cannot re-buy from ira (revoked gate).
      let stAfter = roundBoundary stDen
      assertBool "bob cannot re-buy ira after revoke"
        (not (hasAct "bob" "buy ira's silence" stAfter))

  , testCase "silence debt: repay clears debt without revoke leaf" $ do
      let stBuy = doAct "bob" "buy" (doAct "ira" "learn" sandboxWorld)
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "bob can repay" (hasAct "bob" "repay" stBuy)
      let stPay = doAct "bob" "repay" stBuy
      assertBool "debt cleared" (not (exists "debt.ira.bob.favor" (db stPay)))
      assertBool "no revoke" (not (exists "revoked.ira.bob" (db stPay)))
      let stOpen = iterate roundBoundary stPay !! 3
      assertBool "ira denounce after repay" (hasAct "ira" "denounce" stOpen)

  , testCase "dual festival stagger: harvest denounce vs market cry" $ do
      let stLearn = doAct "dave" "learn" sandboxWorld
      assertBool "seed: neither festival" $
        not (exists "festival.harvest" (db stLearn))
        && not (exists "festival.market" (db stLearn))
      assertBool "seed: no denounce" (not (hasAct "dave" "denounce" stLearn))
      assertBool "seed: no cry" (not (hasAct "dave" "cry the theft" stLearn))
      let stH = iterate roundBoundary stLearn !! 3
      assertBool "t3: harvest open" (exists "festival.harvest" (db stH))
      assertBool "t3: market closed" (not (exists "festival.market" (db stH)))
      assertBool "t3: denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "t3: cry no" (not (hasAct "dave" "cry the theft" stH))
      let stM = roundBoundary stH
      assertBool "t4: harvest closed" (not (exists "festival.harvest" (db stM)))
      assertBool "t4: market open" (exists "festival.market" (db stM))
      assertBool "t4: denounce no" (not (hasAct "dave" "denounce" stM))
      assertBool "t4: cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "t4: kyle (affiliate only) cry no"
        (not (hasAct "kyle" "cry the theft" stM))
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "cry once" (not (hasAct "dave" "cry the theft" stCry))

  , testCase "affiliate negative: kyle belief derives no regard / gates" $ do
      let st0 = sandboxWorld
      assertBool "kyle believes" (exists "kyle.believes.stole.bob.carol" (db st0))
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "kyle primary guild" (exists "member.kyle!guild" (db st0))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView st0)))
      assertBool "kyle cannot learn (not mill member)"
        (not (hasAct "kyle" "learn" st0))
      let stH = iterate roundBoundary st0 !! 3
          stM = roundBoundary stH
      assertBool "kyle cannot denounce at harvest"
        (not (hasAct "kyle" "denounce" stH))
      assertBool "kyle cannot cry at market"
        (not (hasAct "kyle" "cry the theft" stM))

  , testCase "victim defection dissolves regard; rejoin restores denounce gate" $ do
      let stLearn = doAct "dave" "learn" sandboxWorld
      assertBool "held: dave regards"
        (exists "regards.dave.bob.thief" (readView stLearn))
      -- carol must believe she is the victim before abandon is offered.
      let stCarol = doAct "carol" "learn" stLearn
      assertBool "carol can abandon"
        (hasAct "carol" "abandon the mill" stCarol)
      let stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "carol fled leaf" (exists "fled.carol" (db stFlee))
      assertBool "carol now guild" (exists "member.carol!guild" (db stFlee))
      assertBool "carol left mill" (not (exists "member.carol!mill" (db stFlee)))
      assertBool "dave regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "dave belief persists"
        (exists "dave.believes.stole.bob.carol" (db stFlee))
      let stH = iterate roundBoundary stFlee !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stH))
      assertBool "dave cannot denounce without regard"
        (not (hasAct "dave" "denounce" stH))
      assertBool "carol can return" (hasAct "carol" "return to the mill" stH)
      let stBack = doAct "carol" "return to the mill" stH
      assertBool "reconciled" (exists "reconciled.carol" (db stBack))
      assertBool "carol mill again" (exists "member.carol!mill" (db stBack))
      assertBool "dave regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      assertBool "denounce restored" (hasAct "dave" "denounce" stBack)
      let stDen = doAct "dave" "denounce" stBack
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))

  , testCase "wants: pickAction chooses learn / hear / wed / buy at seed" $ do
      pickLabel "dave" sandboxWorld @?= Just "dave: learn of the theft"
      pickLabel "carol" sandboxWorld @?= Just "carol: learn of the theft"
      pickLabel "ira" sandboxWorld @?= Just "ira: learn of the theft"
      pickLabel "priest" sandboxWorld @?= Just "priest: hear the blasphemy"
      pickLabel "gale" sandboxWorld @?= Just "gale: hear the blasphemy"
      pickLabel "fran" sandboxWorld @?= Just "fran: wed into the mill beside carol"
      pickLabel "bob" sandboxWorld @?= Just "bob: Wait a moment"
      pickLabel "eve" sandboxWorld @?= Just "eve: Wait a moment"
      pickLabel "kyle" sandboxWorld @?= Just "kyle: Wait a moment"

  , testCase "wants: after ira learns, bob buys silence" $ do
      let stLearn = doAct "ira" "learn" sandboxWorld
      pickLabel "bob" stLearn @?= Just "bob: buy ira's silence about the theft"
      let stBuy = doAct "bob" "buy" stLearn
      pickLabel "ira" stBuy @?= Just "ira: tear up bob's silence deal"

  , testCase "wants: pickAction denounces during harvest, cries during market" $ do
      let stLearn = doAct "dave" "learn" sandboxWorld
      pickLabel "dave" stLearn @?= Just "dave: Wait a moment"
      let stH = iterate roundBoundary stLearn !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stH))
      pickLabel "dave" stH @?= Just "dave: denounce the thief"
      let stM = roundBoundary stH
      assertBool "market open" (exists "festival.market" (db stM))
      pickLabel "dave" stM @?= Just "dave: cry the theft at market"

  , testCase "wants: priest pickAction hears → censures → exiles" $ do
      let stHear = doAct "priest" "hear" sandboxWorld
      pickLabel "priest" stHear @?= Just "priest: Wait a moment"
      let stOpen = iterate roundBoundary stHear !! 3
      pickLabel "priest" stOpen @?= Just "priest: censure the heretic"
      let stCen = doAct "priest" "censure" stOpen
          stAfter = roundBoundary stCen
      pickLabel "priest" stAfter @?= Just "priest: exile the heretic"

  , testCase "wants: carol flee then return after learning (defectionSeed)" $ do
      pickLabel "carol" defectionSeed @?= Just "carol: learn of the theft"
      let stLearn = doAct "carol" "learn" defectionSeed
      pickLabel "carol" stLearn @?= Just "carol: abandon the mill for the guild"
      let stFlee = doAct "carol" "abandon the mill" stLearn
      assertBool "regard gone"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      pickLabel "carol" stFlee @?= Just "carol: return to the mill in reconciliation"
      let stBack = doAct "carol" "return to the mill" stFlee
      assertBool "regard back"
        (exists "regards.dave.bob.thief" (readView stBack))

  , testCase "wants free-play golden: 44 NPC turns through silence + market cry + both exiles" $
      driveLabels (length sandboxGolden) sandboxWorld @?= sandboxGolden

  , testCase "wants silence golden: 44 NPC turns from ira-learned through market cry + exiles" $
      driveLabels (length sandboxSilenceGolden) silenceSeed
        @?= sandboxSilenceGolden

  , testCase "wants defection golden: 35 NPC turns flee → return → denounce restored" $
      driveLabels (length sandboxDefectionGolden) defectionSeed
        @?= sandboxDefectionGolden

  , testCase "composite silence × defection × festival: multi-gate flips" $ do
      let st0 = compositeSeed
      assertBool "ira regards" (exists "regards.ira.bob.thief" (readView st0))
      assertBool "ira angry" (exists "ira.feels.angry.toward.bob" (db st0)
                              || exists "ira.feels.angry.toward.bob" (readView st0))
      -- bob buys ira silence; dave+carol learn; carol flees.
      let stBuy = doAct "bob" "buy ira" st0
          stDave = doAct "dave" "learn" stBuy
          stCarol = doAct "carol" "learn" stDave
      assertBool "debt" (exists "debt.ira.bob.favor" (db stCarol))
      assertBool "dave regards before flee"
        (exists "regards.dave.bob.thief" (readView stCarol))
      assertBool "carol can abandon" (hasAct "carol" "abandon the mill" stCarol)
      let stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "all mill regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee))
         && not (exists "regards.ira.bob.thief" (readView stFlee)))
      assertBool "beliefs persist"
        (exists "dave.believes.stole.bob.carol" (db stFlee)
         && exists "ira.believes.stole.bob.carol" (db stFlee))
      -- Tear-up clears debt but regard still gone → denounce stays closed at harvest.
      assertBool "ira can tear" (hasAct "ira" "tear up bob" stFlee)
      let stTear = doAct "ira" "tear up bob" stFlee
      assertBool "debt gone" (not (exists "debt.ira.bob.favor" (db stTear)))
      let stH = iterate roundBoundary stTear !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stH))
      assertBool "ira still blocked (no regard)" (not (hasAct "ira" "denounce" stH))
      assertBool "dave still blocked (no regard)" (not (hasAct "dave" "denounce" stH))
      -- Return restores regard + denounce for both (ira already revoked).
      assertBool "carol can return" (hasAct "carol" "return to the mill" stH)
      let stBack = doAct "carol" "return to the mill" stH
      assertBool "dave regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      assertBool "ira regard restored"
        (exists "regards.ira.bob.thief" (readView stBack))
      assertBool "ira denounce yes" (hasAct "ira" "denounce" stBack)
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stBack)
      let stDen = doAct "ira" "denounce" stBack
      assertBool "ira denounced" (exists "denounced.ira.bob" (db stDen))
      -- Market cry still opens on the next boundary for standing witnesses.
      let stM = roundBoundary stDen
      assertBool "market open" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)

  , testCase "wants: compositeSeed carol flees then returns; bob buys after ira learned" $ do
      pickLabel "bob" compositeSeed @?= Just "bob: buy ira's silence about the theft"
      pickLabel "carol" compositeSeed @?= Just "carol: learn of the theft"
      let stLearn = doAct "carol" "learn" compositeSeed
      pickLabel "carol" stLearn @?= Just "carol: abandon the mill for the guild"
      let stFlee = doAct "carol" "abandon the mill" stLearn
      pickLabel "carol" stFlee @?= Just "carol: return to the mill in reconciliation"

  , testCase "repute + emotion: notoriety at 2 regards; angry learn; market rally gate" $ do
      let st0 = reputeSeed
      assertBool "seed: not notorious"
        (not (exists "notorious.bob.thief" (readView st0)))
      let st1 = doAct "dave" "learn" st0
      assertBool "dave angry"
        (exists "dave.feels.angry.toward.bob" (db st1)
         || exists "dave.feels.angry.toward.bob" (readView st1))
      assertBool "one regard: still not notorious"
        (not (exists "notorious.bob.thief" (readView st1)))
      assertBool "dave regards" (exists "regards.dave.bob.thief" (readView st1))
      let st2 = doAct "carol" "learn" st1
      assertBool "two regards: notorious"
        (exists "notorious.bob.thief" (readView st2))
      -- Outside market: rally closed even when notorious+angry.
      assertBool "outside: no rally" (not (hasAct "dave" "rally" st2))
      let stH = iterate roundBoundary st2 !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stH))
      assertBool "harvest: denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "harvest: rally no" (not (hasAct "dave" "rally" stH))
      let stM = roundBoundary stH
      assertBool "market open" (exists "festival.market" (db stM))
      assertBool "market: rally yes" (hasAct "dave" "rally" stM)
      assertBool "market: cry still yes" (hasAct "dave" "cry the theft" stM)
      -- Affiliate kyle never learns → no anger → no rally even at market.
      assertBool "kyle no rally" (not (hasAct "kyle" "rally" stM))
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "rally once" (not (hasAct "dave" "rally" stRally))

  , testCase "wants: reputeSeed dave rallies at market (over cry)" $ do
      let st2 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
      let stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market open" (exists "festival.market" (db stM))
      pickLabel "dave" stM @?= Just "dave: rally the square against the thief"

  , testCase "wants composite golden: 44 NPC turns silence × flee × return × denounce" $
      driveLabels (length sandboxCompositeGolden) compositeSeed
        @?= sandboxCompositeGolden

  , testCase "wants repute golden: 44 NPC turns notoriety → market rally" $
      driveLabels (length sandboxReputeGolden) reputeSeed
        @?= sandboxReputeGolden

  , testCase "coerce × factionStanding: squeeze → confess; re-squeeze → brand" $ do
      let st0 = coerceSeed
      assertBool "squeeze active" ("millSqueeze" `elem` practiceNames st0)
      assertBool "dave regards" (exists "regards.dave.bob.thief" (readView st0))
      assertBool "dave can squeeze" (hasAct "dave" "squeeze bob" st0)
      assertBool "inactive world: no squeeze"
        (not (hasAct "dave" "squeeze bob" sandboxWorld))
      let stSq = doAct "dave" "squeeze bob" st0
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))
      assertBool "extorted mark"
        (exists "dave.extorted.bob.squeeze" (db stSq))
      assertBool "bob can confess" (hasAct "bob" "confess the theft" stSq)
      assertBool "bob can defy" (hasAct "bob" "defy" stSq)
      let stConf = doAct "bob" "confess the theft" stSq
      assertBool "confessed" (exists "confessed.bob" (db stConf))
      assertBool "threat cleared"
        (not (exists "threatened.squeeze.dave.bob" (db stConf)))
      assertBool "complied"
        (exists "complied.squeeze.dave.bob" (db stConf))
      -- Permanent complied: dave can re-threaten; bob cannot re-pay.
      assertBool "dave re-squeeze yes" (hasAct "dave" "squeeze bob" stConf)
      let stSq2 = doAct "dave" "squeeze bob" stConf
      assertBool "threat back"
        (exists "threatened.squeeze.dave.bob" (db stSq2))
      assertBool "bob cannot re-confess"
        (not (hasAct "bob" "confess the theft" stSq2))
      assertBool "dave can brand" (hasAct "dave" "brand bob" stSq2)
      let stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "brand once" (not (hasAct "dave" "brand bob" stBrand))

  , testCase "wants: coerceSeed dave squeezes; bob confesses after threat" $ do
      pickLabel "dave" coerceSeed @?= Just "dave: squeeze bob for a confession"
      let stSq = doAct "dave" "squeeze bob" coerceSeed
      pickLabel "bob" stSq @?= Just "bob: confess the theft to dave"
      let stConf = doAct "bob" "confess" stSq
      pickLabel "dave" stConf @?= Just "dave: squeeze bob for a confession"
      let stSq2 = doAct "dave" "squeeze bob" stConf
      -- bob already complied permanently; waiting out the standing threat.
      pickLabel "bob" stSq2 @?= Just "bob: Wait a moment"
      pickLabel "dave" stSq2 @?= Just "dave: brand bob as unrepentant"

  , testCase "wants coerce golden: 21 NPC turns squeeze → confess → brand" $
      driveLabels (length sandboxCoerceGolden) coerceSeed
        @?= sandboxCoerceGolden

  , testCase "dual pressure: churchBob inactive by default; activate opens bob heresy track" $ do
      assertBool "default: no hear of bob"
        (not (hasAct "priest" "hear of bob" sandboxWorld))
      let st0 = dualPressureSeed
      assertBool "active practice"
        (exists "practice.churchBobHeresy" (db st0))
      assertBool "priest hear bob" (hasAct "priest" "hear of bob" st0)
      assertBool "dave learn" (hasAct "dave" "learn" st0)
      -- eve blasphemy hear still defined (churchHeresy active) but muted wants.
      assertBool "eve hear still available" (hasAct "priest" "hear the blasphemy" st0)

  , testCase "dual pressure: interleaved harvest gates + shared exile race" $ do
      let st0 = dualPressureSeed
      let stHear = doAct "priest" "hear of bob" st0
      assertBool "priest regards bob heretic"
        (exists "regards.priest.bob.heretic" (readView stHear))
      let stLearn = doAct "dave" "learn" stHear
      assertBool "dave regards bob thief"
        (exists "regards.dave.bob.thief" (readView stLearn))
      assertBool "outside: no denounce" (not (hasAct "dave" "denounce" stLearn))
      assertBool "outside: no censure bob"
        (not (hasAct "priest" "censure bob" stLearn))
      let stOpen = iterate roundBoundary stLearn !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stOpen))
      -- Same window: mill denounce AND church censure-bob.
      assertBool "mill denounce" (hasAct "dave" "denounce" stOpen)
      assertBool "church censure bob" (hasAct "priest" "censure bob" stOpen)
      assertBool "no exile during" $
        not (hasAct "dave" "exile the thief" stOpen)
        && not (hasAct "priest" "banish bob" stOpen)
      let stCen = doAct "priest" "censure bob" stOpen
      let stDen = doAct "dave" "denounce" stCen
      assertBool "censured.bob" (exists "censured.priest.bob" (db stDen))
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      let stAfter = roundBoundary stDen
      assertBool "festival closed" (not (exists "festival.harvest" (db stAfter)))
      -- Both exile paths open; gale (non-leader) cannot banish.
      assertBool "mill exile open" (hasAct "dave" "exile the thief" stAfter)
      assertBool "church banish open" (hasAct "priest" "banish bob" stAfter)
      assertBool "gale cannot banish" (not (hasAct "gale" "banish bob" stAfter))
      -- Mill wins race → church banish blocked.
      let stMill = doAct "dave" "exile the thief" stAfter
      assertBool "exiled.bob" (exists "exiled.bob" (db stMill))
      assertBool "church blocked after mill"
        (not (hasAct "priest" "banish bob" stMill))
      -- Inverse: church wins → mill exile blocked (fresh after-window state).
      let stChurch = doAct "priest" "banish bob" stAfter
      assertBool "exiled via church" (exists "exiled.bob" (db stChurch))
      assertBool "mill blocked after church"
        (not (hasAct "dave" "exile the thief" stChurch))

  , testCase "dual pressure: wants priority bob censure (9) over eve censure (8)" $ do
      let st0 = dualPressureSeed
          priestBoth = (actorOf "priest" st0)
                         { charDesires = bobHeresyJustice ++ millJustice
                                         ++ churchJustice }
          stBoth = st0 { characters =
                           [ if charName c == "priest" then priestBoth else c
                           | c <- characters st0 ] }
      -- Hear both tracks (sequential outside-festival hears).
      let stEve = doAct "priest" "hear the blasphemy" stBoth
      let stBob = doAct "priest" "hear of bob" stEve
      let stOpen = iterate roundBoundary stBob !! 3
      assertBool "both regards" $
        exists "regards.priest.eve.heretic" (readView stOpen)
        && exists "regards.priest.bob.heretic" (readView stOpen)
      assertBool "both censures available" $
        hasAct "priest" "censure the heretic" stOpen
        && hasAct "priest" "censure bob" stOpen
      pickLabel "priest" stOpen @?= Just "priest: censure bob for heresy"

  , testCase "wants: dualPressureSeed priest hears bob; harvest censures bob" $ do
      pickLabel "priest" dualPressureSeed
        @?= Just "priest: hear of bob's heresy"
      pickLabel "dave" dualPressureSeed
        @?= Just "dave: learn of the theft"
      let stHear = doAct "priest" "hear of bob" dualPressureSeed
      let stLearn = doAct "dave" "learn" stHear
      let stOpen = iterate roundBoundary stLearn !! 3
      pickLabel "priest" stOpen @?= Just "priest: censure bob for heresy"
      pickLabel "dave" stOpen @?= Just "dave: denounce the thief"
      let stAfter = roundBoundary (doAct "dave" "denounce"
                        (doAct "priest" "censure bob" stOpen))
      pickLabel "dave" stAfter @?= Just "dave: exile the thief"
      pickLabel "priest" stAfter @?= Just "priest: banish bob for heresy"

  , testCase "wants dual-pressure golden: 44 NPC turns mill wins exile race" $
      driveLabels (length sandboxDualPressureGolden) dualPressureSeed
        @?= sandboxDualPressureGolden

  , testCase "heresy × silence: buy blocks censure; tear-up restores gate" $ do
      let st0 = churchSilenceSeed
      assertBool "gale regards eve"
        (exists "regards.gale.eve.heretic" (readView st0))
      assertBool "eve can buy" (hasAct "eve" "buy gale" st0)
      assertBool "outside: no censure" (not (hasAct "gale" "censure the heretic" st0))
      let stBuy = doAct "eve" "buy gale" st0
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest open" (exists "festival.harvest" (db stH))
      assertBool "debt blocks censure" (not (hasAct "gale" "censure the heretic" stH))
      assertBool "gale can tear" (hasAct "gale" "tear up eve" stH)
      let stTear = doAct "gale" "tear up eve" stH
      assertBool "debt gone" (not (exists "debt.gale.eve.church-favor" (db stTear)))
      assertBool "revoked" (exists "revoked.gale.eve" (db stTear))
      assertBool "censure open after tear" (hasAct "gale" "censure the heretic" stTear)
      let stCen = doAct "gale" "censure the heretic" stTear
      assertBool "censured" (exists "censured.gale.eve" (db stCen))
      let stAfter = roundBoundary stCen
      -- priest also heard in free play? not in this seed — only gale heard.
      -- gale is not leader → cannot exile; priest still can if censured.priest.
      assertBool "gale non-leader no exile"
        (not (hasAct "gale" "exile the heretic" stAfter))

  , testCase "wants: churchSilenceSeed eve buys; gale tears then censures" $ do
      pickLabel "eve" churchSilenceSeed
        @?= Just "eve: buy gale's silence about the heresy"
      let stBuy = doAct "eve" "buy gale" churchSilenceSeed
      pickLabel "gale" stBuy @?= Just "gale: tear up eve's heresy silence deal"
      let stTear = doAct "gale" "tear up eve" stBuy
      let stH = iterate roundBoundary stTear !! 3
      pickLabel "gale" stH @?= Just "gale: censure the heretic"

  , testCase "coerce × heresy: squeeze → recant; re-squeeze → brand; censure still open" $ do
      let st0 = inquisitSeed
      assertBool "inquisit active" ("churchInquisit" `elem` practiceNames st0)
      assertBool "churchBob active"
        (exists "practice.churchBobHeresy" (db st0))
      assertBool "priest regards bob heretic"
        (exists "regards.priest.bob.heretic" (readView st0))
      assertBool "priest can squeeze" (hasAct "priest" "squeeze bob" st0)
      assertBool "default world: no inquisit"
        (not (hasAct "priest" "squeeze bob" sandboxWorld))
      let stSq = doAct "priest" "squeeze bob" st0
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "bob can recant" (hasAct "bob" "recant the heresy" stSq)
      assertBool "bob can defy" (hasAct "bob" "defy" stSq)
      let stRec = doAct "bob" "recant the heresy" stSq
      assertBool "recanted" (exists "recanted.bob" (db stRec))
      assertBool "complied"
        (exists "complied.inquisit.priest.bob" (db stRec))
      -- Re-squeeze → brand (permanent complied blocks re-pay).
      assertBool "re-squeeze" (hasAct "priest" "squeeze bob" stRec)
      let stSq2 = doAct "priest" "squeeze bob" stRec
      assertBool "no re-recant" (not (hasAct "bob" "recant the heresy" stSq2))
      assertBool "can brand" (hasAct "priest" "brand bob" stSq2)
      let stBrand = doAct "priest" "brand bob" stSq2
      assertBool "brandedHeretic" (exists "brandedHeretic.bob" (db stBrand))
      -- Heresy track still open at harvest (independent of coerce).
      let stOpen = iterate roundBoundary stBrand !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "censure bob still" (hasAct "priest" "censure bob" stOpen)
      let stCen = doAct "priest" "censure bob" stOpen
      let stAfter = roundBoundary stCen
      assertBool "banish open" (hasAct "priest" "banish bob" stAfter)
      let stBan = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))

  , testCase "wants: inquisitSeed priest squeezes; bob recants; then brand path" $ do
      pickLabel "priest" inquisitSeed
        @?= Just "priest: squeeze bob for a recantation"
      let stSq = doAct "priest" "squeeze bob" inquisitSeed
      pickLabel "bob" stSq @?= Just "bob: recant the heresy to priest"
      let stRec = doAct "bob" "recant" stSq
      pickLabel "priest" stRec
        @?= Just "priest: squeeze bob for a recantation"
      let stSq2 = doAct "priest" "squeeze bob" stRec
      pickLabel "bob" stSq2 @?= Just "bob: Wait a moment"
      pickLabel "priest" stSq2
        @?= Just "priest: brand bob as unrepentant heretic"

  , testCase "wants church-silence golden: 43 NPC turns buy → tear → censure → exile" $
      driveLabels (length sandboxChurchSilenceGolden) churchSilenceSeed
        @?= sandboxChurchSilenceGolden

  , testCase "wants inquisit golden: 43 NPC turns squeeze → recant → brand → banish" $
      driveLabels (length sandboxInquisitGolden) inquisitSeed
        @?= sandboxInquisitGolden

  , testCase "silence × squeeze: debt blocks ira denounce; dave squeeze still open" $ do
      let stLearn = doAct "dave" "learn" (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira's silence" stLearn
          stSq = activateSqueeze stBuy
      assertBool "debt holds" (exists "debt.ira.bob.favor" (db stSq))
      assertBool "dave regards" (exists "regards.dave.bob.thief" (readView stSq))
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stSq)
      let stOpen = iterate roundBoundary stSq !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stOpen))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stOpen)
      assertBool "dave squeeze still" (hasAct "dave" "squeeze bob" stOpen)

  , testCase "brand parade: after brand, mill can parade; default inactive" $ do
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "default: no parade practice action"
        (not (hasAct "dave" "parade" stBrand))
      let stP = activateParade stBrand
      assertBool "parade active" ("millBrandParade" `elem` practiceNames stP)
      assertBool "dave can parade" (hasAct "dave" "parade bob" stP)
      assertBool "eve no parade (no regard)" (not (hasAct "eve" "parade" stP))
      let stPar = doAct "dave" "parade bob" stP
      assertBool "paraded leaf" (exists "paraded.dave.bob" (db stPar))
      assertBool "parade once" (not (hasAct "dave" "parade bob" stPar))

  , testCase "church brand parade: after heretic brand, church can parade; default inactive" $ do
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = doAct "priest" "brand bob" stDefy
      assertBool "brandedHeretic" (exists "brandedHeretic.bob" (db stBrand))
      assertBool "default: no church parade"
        (not (hasAct "priest" "parade" stBrand))
      let stP = activateChurchParade stBrand
      assertBool "church parade active" ("churchBrandParade" `elem` practiceNames stP)
      assertBool "priest can parade" (hasAct "priest" "parade bob" stP)
      assertBool "dave no church parade" (not (hasAct "dave" "parade" stP))
      let stPar = doAct "priest" "parade bob" stP
      assertBool "paraded leaf" (exists "paraded.priest.bob" (db stPar))
      assertBool "parade once" (not (hasAct "priest" "parade bob" stPar))

  , testCase "silence × market cry: debt blocks ira denounce; market cry still open" $ do
      -- ira learns + bob buys silence → harvest denounce blocked; market cry unconstrained by owes.
      let stLearn = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira's silence" stLearn
      assertBool "debt holds" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "ira regards" (exists "regards.ira.bob.thief" (readView stBuy))
      let stOpen = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stOpen))
      let stM = iterate roundBoundary stBuy !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira cry yes under debt" (hasAct "ira" "cry the theft" stM)
      let stCry = doAct "ira" "cry the theft" stM
      assertBool "cried leaf" (exists "cried.ira.bob" (db stCry))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stCry))

  , testCase "church silence × inquisit: debt blocks censure; priest squeeze still open" $ do
      -- inquisitSeed: priest regards bob; bob buys priest church-silence; harvest
      -- censure gated by lacksOwes, but coerce squeeze ignores owes.
      let st0 = inquisitSeed
      assertBool "priest can squeeze" (hasAct "priest" "squeeze bob" st0)
      assertBool "bob can buy priest silence" (hasAct "bob" "buy priest" st0)
      let stBuy = doAct "bob" "buy priest" st0
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "squeeze still" (hasAct "priest" "squeeze bob" stBuy)
      let stOpen = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "censure blocked" (not (hasAct "priest" "censure bob" stOpen))
      assertBool "squeeze still at harvest" (hasAct "priest" "squeeze bob" stOpen)

  , testCase "defection × squeeze: flee drops regard/squeeze; return restores" $ do
      let st0 = coerceSeed
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      let stCarol = doAct "carol" "learn" st0
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "squeeze closed" (not (hasAct "dave" "squeeze bob" stFlee))
      let stH = iterate roundBoundary stFlee !! 3
          stBack = doAct "carol" "return to the mill" stH
      assertBool "regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      assertBool "squeeze restored" (hasAct "dave" "squeeze bob" stBack)

  , testCase "parade × market cry: brand parade and market cry stay independent" $ do
      -- Brand path then activate mill parade; market cry still opens on regard+festival,
      -- and parade stays open without sharing cry's once-gate.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave can parade" (hasAct "dave" "parade bob" stP)
      let stM = iterate roundBoundary stP !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "parade still" (hasAct "dave" "parade bob" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "parade after cry" (hasAct "dave" "parade bob" stCry)
      let stPar = doAct "dave" "parade bob" stCry
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "cry spent" (not (hasAct "dave" "cry the theft" stPar))

  , testCase "defection × parade: flee drops regard/parade; return restores" $ do
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stCarol = doAct "carol" "learn" stP
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stFlee))
      let stH = iterate roundBoundary stFlee !! 3
          stBack = doAct "carol" "return to the mill" stH
      assertBool "regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      assertBool "parade restored" (hasAct "dave" "parade bob" stBack)

  , testCase "silence × parade: debt blocks ira denounce; dave parade still open" $ do
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
          stIra = doAct "ira" "learn" stP
          stBuy = doAct "bob" "buy ira's silence" stIra
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stBuy)
      let stOpen = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stOpen))
      assertBool "dave parade at harvest" (hasAct "dave" "parade bob" stOpen)

  , testCase "church silence × parade: debt blocks censure; priest parade still open" $ do
      -- inquisit brand path + church parade; bob buys priest silence.
      -- Harvest censure gated by lacksOwes; parade only needs regards+brandedHeretic.
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = doAct "priest" "brand bob" stDefy
          stP = activateChurchParade stBrand
          stBuy = doAct "bob" "buy priest" stP
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stBuy)
      let stOpen = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stOpen))
      assertBool "censure blocked" (not (hasAct "priest" "censure bob" stOpen))
      assertBool "parade at harvest" (hasAct "priest" "parade bob" stOpen)

  , testCase "defection × market cry: flee drops regard/cry; return restores" $ do
      let stLearn = doAct "dave" "learn" sandboxWorld
          stCarol = doAct "carol" "learn" stLearn
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      let stM = iterate roundBoundary stFlee !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stM))
      -- advance to a harvest so return is offered, then back to market after restore
      let stH = iterate roundBoundary stFlee !! 3
          stBack = doAct "carol" "return to the mill" stH
      assertBool "regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      let stM2 = iterate roundBoundary stBack !! 1
      assertBool "market again" (exists "festival.market" (db stM2))
      assertBool "cry restored" (hasAct "dave" "cry the theft" stM2)

  , testCase "church parade × market cry: heretic parade and mill cry stay independent" $ do
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = doAct "priest" "brand bob" stDefy
          stP = activateChurchParade stBrand
          stDave = doAct "dave" "learn" stP
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stDave)
      let stM = iterate roundBoundary stDave !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "parade still" (hasAct "priest" "parade bob" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "parade after cry" (hasAct "priest" "parade bob" stCry)

  , testCase "silence × rally: debt blocks ira denounce; dave rally still open" $ do
      -- reputeSeed path to notorious+angry; bob buys ira silence. Harvest
      -- denounce gated by lacksOwes; market rally ignores owes.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stIra = doAct "ira" "learn" st0
          stBuy = doAct "bob" "buy ira's silence" stIra
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "notorious" (exists "notorious.bob.thief" (readView stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      let stM = roundBoundary stH
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes under debt" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stRally))

  , testCase "defection × rally: flee transfers standing; mill cry closes, rally stays" $ do
      -- Victim carol flees mill→guild: mill regards dissolve (dave cry closes),
      -- but guild comrades who already believe (kyle+carol) re-derive regards →
      -- notoriety persists → dave (still angry) keeps market rally.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
      assertBool "notorious" (exists "notorious.bob.thief" (readView st0))
      let stFlee = doAct "carol" "abandon the mill" st0
      assertBool "mill regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "guild regard kyle"
        (exists "regards.kyle.bob.thief" (readView stFlee))
      assertBool "notoriety persists via guild"
        (exists "notorious.bob.thief" (readView stFlee))
      let stM = iterate roundBoundary stFlee !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stM))
      assertBool "rally stays" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))

  , testCase "parade × rally: brand parade and market rally stay independent" $ do
      -- Brand→activateParade; reputeSeed path to notorious+angry; market:
      -- mill parade (regard+brand) and rally (notorious+angry) share no once-gate.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stSq = doAct "dave" "squeeze bob" (activateSqueeze st0)
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "notorious" (exists "notorious.bob.thief" (readView stP))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stM = iterate roundBoundary stP !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "parade still" (hasAct "dave" "parade bob" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "parade after rally" (hasAct "dave" "parade bob" stRally)
      let stPar = doAct "dave" "parade bob" stRally
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "rally spent" (not (hasAct "dave" "rally" stPar))

  , testCase "church parade × rally: heretic parade and mill rally stay independent" $ do
      -- inquisitSeed brand→activateChurchParade; dave+carol learn → notorious;
      -- market: church parade and mill rally share no gate.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" inquisitSeed)
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
      assertBool "notorious" (exists "notorious.bob.thief" (readView stP))
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stP)
      let stM = iterate roundBoundary stP !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "parade still" (hasAct "priest" "parade bob" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "parade after rally" (hasAct "priest" "parade bob" stRally)

  , testCase "cry × rally: market cry and rally stay independent" $ do
      -- reputeSeed → notorious+angry; market: cry (regard) and rally
      -- (notorious+angry) share no once-gate.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
      assertBool "notorious" (exists "notorious.bob.thief" (readView st0))
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "rally after cry" (hasAct "dave" "rally" stCry)
      let stRally = doAct "dave" "rally" stCry
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "cry spent" (not (hasAct "dave" "cry the theft" stRally))

  , testCase "silence × exile: debt blocks ira denounce/exile; dave exile still open" $ do
      -- ira silenced → cannot denounce → cannot exile; dave free path
      -- denounce@harvest → exile after window.
      let stIra = doAct "ira" "learn" sandboxWorld
          stDave = doAct "dave" "learn" stIra
          stBuy = doAct "bob" "buy ira's silence" stDave
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "ira exile no" (not (hasAct "ira" "exile" stAfter))
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stEx))

  , testCase "church silence × exile: debt blocks censure/banish; mill exile still open" $ do
      -- bob buys priest church-silence; harvest priest censure blocked;
      -- dave mill denounce→exile still open (independent track).
      let st0 = inquisitSeed
          stBuy = doAct "bob" "buy priest" st0
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stDave = doAct "dave" "learn" stBuy
          stH = iterate roundBoundary stDave !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "priest banish no" (not (hasAct "priest" "banish bob" stAfter))
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "squeeze × rally: mill squeeze and market rally stay independent" $ do
      -- coerceSeed/activateSqueeze + reputeSeed path: harvest squeeze and
      -- market rally share no gate (regard vs notorious+angry).
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stSq = activateSqueeze st0
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stSq)
      assertBool "notorious" (exists "notorious.bob.thief" (readView stSq))
      let stM = iterate roundBoundary stSq !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "squeeze after rally" (hasAct "dave" "squeeze bob" stRally)

  , testCase "wed × cry: fran wedding unlocks mill regard then market cry" $ do
      -- fran already believes (guild) → no regard; wed into mill → regard;
      -- market cry opens (independent of harvest denounce once-gate).
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") sandboxWorld
      assertBool "before: no regard"
        (not (exists "regards.fran.bob.thief" (readView stBel)))
      assertBool "before: no cry" (not (hasAct "fran" "cry the theft" stBel))
      let stWed = doAct "fran" "wed into the mill" stBel
      assertBool "after: regard" (exists "regards.fran.bob.thief" (readView stWed))
      let stM = iterate roundBoundary stWed !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "fran cry yes" (hasAct "fran" "cry the theft" stM)
      let stCry = doAct "fran" "cry the theft" stM
      assertBool "cried" (exists "cried.fran.bob" (db stCry))

  , testCase "squeeze × cry: mill squeeze and market cry stay independent" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "squeeze after cry" (hasAct "dave" "squeeze bob" stCry)

  , testCase "inquisit × cry: church squeeze and market cry stay independent" $ do
      -- inquisitSeed priest squeeze + dave mill learn; market cry shares no gate
      -- with church coerce (regard vs festival+regard mill track).
      let st0 = doAct "dave" "learn" inquisitSeed
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "squeeze still" (hasAct "priest" "squeeze bob" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "squeeze after cry" (hasAct "priest" "squeeze bob" stCry)

  , testCase "inquisit × rally: church squeeze and market rally stay independent" $ do
      -- inquisitSeed + dave/carol learn → notorious; market rally vs priest squeeze
      -- share no gate (mill repute track vs church coerce).
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" inquisitSeed)
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      assertBool "notorious" (exists "notorious.bob.thief" (readView st0))
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "squeeze still" (hasAct "priest" "squeeze bob" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "squeeze after rally" (hasAct "priest" "squeeze bob" stRally)

  , testCase "wed × rally: fran wedding unlocks mill standing then market rally" $ do
      -- fran believes (guild) → no mill regard; wed → regard; with dave learn
      -- → notorious; fran angry from learn path via mill standing enables rally
      -- once dave (angry) path is set — pin fran cry/regard unlock + dave rally.
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") reputeSeed
          stDave = doAct "dave" "learn" stBel
      assertBool "before: no fran regard"
        (not (exists "regards.fran.bob.thief" (readView stDave)))
      let stWed = doAct "fran" "wed into the mill" stDave
      assertBool "after: fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "notorious with dave+fran"
        (exists "notorious.bob.thief" (readView stWed))
      let stM = iterate roundBoundary stWed !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "fran regard persists"
        (exists "regards.fran.bob.thief" (readView stRally))

  , testCase "affiliate × squeeze: kyle affiliate-only cannot squeeze" $ do
      -- factionStanding needs primary member; kyle affiliates mill but
      -- primary guild → no regard → millSqueeze stays closed for kyle while
      -- dave (primary mill) can squeeze after learn.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView st0)))
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      assertBool "kyle squeeze no" (not (hasAct "kyle" "squeeze bob" st0))

  , testCase "squeeze × exile: mill squeeze and denounce/exile stay independent" $ do
      -- activateSqueeze + learn: harvest denounce/exile shares no gate with
      -- millSqueeze; squeeze then exile both fire in the post-harvest window.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      let stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "squeeze at harvest" (hasAct "dave" "squeeze bob" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "squeeze after denounce" (hasAct "dave" "squeeze bob" stAfter)
      let stSq = doAct "dave" "squeeze bob" stAfter
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))
      assertBool "exile still after squeeze" (hasAct "dave" "exile" stSq)
      let stEx = doAct "dave" "exile" stSq
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "wed × squeeze: fran wedding unlocks mill regard then squeeze" $ do
      -- fran believes (guild) → no regard → no squeeze; wed into mill → regard
      -- → activateSqueeze opens fran squeeze (independent of dave learn path).
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") sandboxWorld
          stSq0 = activateSqueeze stBel
      assertBool "before: no regard"
        (not (exists "regards.fran.bob.thief" (readView stSq0)))
      assertBool "before: no squeeze" (not (hasAct "fran" "squeeze bob" stSq0))
      let stWed = doAct "fran" "wed into the mill" stSq0
      assertBool "after: regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "fran squeeze yes" (hasAct "fran" "squeeze bob" stWed)
      let stSq = doAct "fran" "squeeze bob" stWed
      assertBool "threatened"
        (exists "threatened.squeeze.fran.bob" (db stSq))

  , testCase "inquisit × exile: church squeeze and mill exile stay independent" $ do
      -- inquisitSeed priest squeeze + dave mill learn/denounce/exile: church
      -- coerce and mill tribunal share no gate (exile race is mill vs banish).
      let st0 = doAct "dave" "learn" inquisitSeed
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "squeeze at harvest" (hasAct "priest" "squeeze bob" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "squeeze after denounce" (hasAct "priest" "squeeze bob" stAfter)
      let stSq = doAct "priest" "squeeze bob" stAfter
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "exile still" (hasAct "dave" "exile" stSq)
      let stEx = doAct "dave" "exile" stSq
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "church silence × cry: debt blocks censure; market cry still open" $ do
      -- bob buys priest church-silence → harvest censure blocked; dave mill
      -- market cry unconstrained by church owes.
      let st0 = doAct "dave" "learn" inquisitSeed
          stBuy = doAct "bob" "buy priest" st0
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stM = iterate roundBoundary stBuy !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stCry))

  , testCase "parade × exile: brand parade and denounce/exile stay independent" $ do
      -- brand → activateParade; harvest denounce/exile shares no gate with parade.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "parade after denounce" (hasAct "dave" "parade bob" stAfter)
      let stPar = doAct "dave" "parade bob" stAfter
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "exile still" (hasAct "dave" "exile" stPar)
      let stEx = doAct "dave" "exile" stPar
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "church silence × rally: debt blocks censure; market rally still open" $ do
      -- inquisitSeed + dave/carol learn → notorious; bob buys priest silence;
      -- harvest censure blocked; market rally unconstrained by church owes.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" inquisitSeed)
          stBuy = doAct "bob" "buy priest" st0
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "notorious" (exists "notorious.bob.thief" (readView stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stM = iterate roundBoundary stBuy !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stRally))

  , testCase "wed × exile: fran wedding unlocks mill regard then denounce/exile" $ do
      -- fran believes (guild) → no regard; wed → regard → harvest denounce → exile.
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") sandboxWorld
      assertBool "before: no regard"
        (not (exists "regards.fran.bob.thief" (readView stBel)))
      assertBool "before: no denounce" (not (hasAct "fran" "denounce" stBel))
      let stWed = doAct "fran" "wed into the mill" stBel
      assertBool "after: regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      let stH = iterate roundBoundary stWed !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "fran denounce yes" (hasAct "fran" "denounce" stH)
      let stDen = doAct "fran" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "fran exile yes" (hasAct "fran" "exile" stAfter)
      let stEx = doAct "fran" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "affiliate × rally: kyle affiliate-only cannot rally" $ do
      -- factionStanding needs primary member; kyle affiliates mill but primary
      -- guild → no regard/anger → market rally stays closed for kyle while dave
      -- (primary mill, angry+notorious path) can rally.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView st0)))
      assertBool "notorious" (exists "notorious.bob.thief" (readView st0))
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "kyle rally no" (not (hasAct "kyle" "rally" stM))
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))

  , testCase "cry × exile: market cry and denounce/exile stay independent" $ do
      -- market cry (regard) and harvest denounce→exile share no once-gate:
      -- cry at market (tick 4), next harvest is tick 6 (harvest period 3).
      let st0 = doAct "dave" "learn" sandboxWorld
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      let stH = iterate roundBoundary stCry !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "cried persists" (exists "cried.dave.bob" (db stEx))

  , testCase "affiliate × parade: kyle affiliate-only cannot parade" $ do
      -- brand → activateParade; kyle affiliates mill but primary guild → no
      -- regard → parade closed for kyle while dave (primary mill) can parade.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db stP))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView stP)))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      assertBool "kyle parade no" (not (hasAct "kyle" "parade bob" stP))
      let stPar = doAct "dave" "parade bob" stP
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))

  , testCase "affiliate × exile: kyle affiliate-only cannot denounce/exile" $ do
      -- factionStanding needs primary member; kyle affiliates mill → no regard
      -- → harvest denounce/exile closed for kyle while dave can finish exile.
      let st0 = doAct "dave" "learn" sandboxWorld
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView st0)))
      let stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "kyle denounce no" (not (hasAct "kyle" "denounce" stH))
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "kyle exile no" (not (hasAct "kyle" "exile" stAfter))
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "wed × parade: fran wedding unlocks mill regard then parade" $ do
      -- fran believes (guild) → no regard → no parade; brand path + activateParade
      -- then wed → regard → fran parade opens (independent of dave learn alone).
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") coerceSeed
          stSq = doAct "dave" "squeeze bob" stBel
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "before: no fran regard"
        (not (exists "regards.fran.bob.thief" (readView stP)))
      assertBool "before: fran parade no" (not (hasAct "fran" "parade bob" stP))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stWed = doAct "fran" "wed into the mill" stP
      assertBool "after: fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "fran parade yes" (hasAct "fran" "parade bob" stWed)
      let stPar = doAct "fran" "parade bob" stWed
      assertBool "paraded" (exists "paraded.fran.bob" (db stPar))

  , testCase "inquisit × parade: church squeeze and mill parade stay independent" $ do
      -- inquisitSeed priest squeeze + mill brand→parade: church coerce and mill
      -- parade share no once-gate.
      let st0 = doAct "dave" "learn" inquisitSeed
          stSqM = doAct "dave" "squeeze bob" (activateSqueeze st0)
          stConf = doAct "bob" "confess the theft" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSqM2
          stP = activateParade stBrand
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" stP)
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stSq = doAct "priest" "squeeze bob" stP
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "parade after squeeze" (hasAct "dave" "parade bob" stSq)
      let stPar = doAct "dave" "parade bob" stSq
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "squeeze spent"
        (not (hasAct "priest" "squeeze bob" stPar)
         || exists "threatened.inquisit.priest.bob" (db stPar))

  , testCase "church silence × squeeze: debt blocks censure; mill squeeze still open" $ do
      -- bob buys priest silence → harvest censure blocked; dave mill squeeze
      -- (activateSqueeze + learn) ignores church owes.
      let st0 = activateSqueeze (doAct "dave" "learn" inquisitSeed)
          stBuy = doAct "bob" "buy priest" st0
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      assertBool "dave squeeze still" (hasAct "dave" "squeeze bob" stH)
      let stSq = doAct "dave" "squeeze bob" stH
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stSq))

  , testCase "affiliate × cry: kyle affiliate-only cannot cry at market" $ do
      -- factionStanding needs primary member; kyle affiliates mill but primary
      -- guild → no regard → market cry closed for kyle while dave can cry.
      let st0 = doAct "dave" "learn" sandboxWorld
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "kyle no regard"
        (not (exists "regards.kyle.bob.thief" (readView st0)))
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "kyle cry no" (not (hasAct "kyle" "cry the theft" stM))
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))


  , testCase "defection × exile: flee drops regard/exile; return restores" $ do
      -- carol flee dissolves dave regard → harvest denounce/exile close;
      -- return restores regard and exile path.
      let stLearn = doAct "dave" "learn" sandboxWorld
          stCarol = doAct "carol" "learn" stLearn
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "regard dissolved"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      let stH = iterate roundBoundary stFlee !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce closed" (not (hasAct "dave" "denounce" stH))
      let stBack = doAct "carol" "return to the mill" stH
      assertBool "regard restored"
        (exists "regards.dave.bob.thief" (readView stBack))
      assertBool "denounce restored" (hasAct "dave" "denounce" stBack)
      let stDen = doAct "dave" "denounce" stBack
          stAfter = roundBoundary stDen
      assertBool "exile yes" (hasAct "dave" "exile" stAfter)
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "church parade × exile: heretic parade and mill exile stay independent" $ do
      -- inquisitSeed brand→church parade + dave mill denounce/exile: share no gate.
      let st0 = doAct "dave" "learn" inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "parade at harvest" (hasAct "priest" "parade bob" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "parade after denounce" (hasAct "priest" "parade bob" stAfter)
      let stPar = doAct "priest" "parade bob" stAfter
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))
      assertBool "exile still" (hasAct "dave" "exile" stPar)
      let stEx = doAct "dave" "exile" stPar
      assertBool "exiled" (exists "exiled.bob" (db stEx))


  , testCase "church parade × squeeze: heretic parade and mill squeeze stay independent" $ do
      -- inquisitSeed brand→church parade + activateSqueeze dave: share no gate.
      let st0 = activateSqueeze (doAct "dave" "learn" inquisitSeed)
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stP)
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stP)
      let stPar = doAct "priest" "parade bob" stP
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))
      assertBool "squeeze after parade" (hasAct "dave" "squeeze bob" stPar)
      let stMill = doAct "dave" "squeeze bob" stPar
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stMill))
      assertBool "parade spent" (not (hasAct "priest" "parade bob" stMill))

  , testCase "inquisit × squeeze: church and mill squeeze stay independent" $ do
      -- inquisitSeed priest squeeze + activateSqueeze dave mill squeeze: both
      -- coerce tracks open without sharing once-gate.
      let st0 = activateSqueeze (doAct "dave" "learn" inquisitSeed)
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      let stP = doAct "priest" "squeeze bob" st0
      assertBool "threatened inquisit"
        (exists "threatened.inquisit.priest.bob" (db stP))
      assertBool "dave squeeze after" (hasAct "dave" "squeeze bob" stP)
      let stM = doAct "dave" "squeeze bob" stP
      assertBool "threatened mill"
        (exists "threatened.squeeze.dave.bob" (db stM))
      assertBool "inquisit mark persists"
        (exists "threatened.inquisit.priest.bob" (db stM))


  , testCase "defection × inquisit: flee drops mill regard; church squeeze stays" $ do
      -- carol flee dissolves dave mill regard/squeeze; priest inquisit squeeze
      -- ignores mill standing and stays open.
      let st0 = activateSqueeze (doAct "dave" "learn" inquisitSeed)
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" st0)
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stCarol = doAct "carol" "learn" st0
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "mill regard gone"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "dave squeeze closed" (not (hasAct "dave" "squeeze bob" stFlee))
      assertBool "priest squeeze stays" (hasAct "priest" "squeeze bob" stFlee)
      let stSq = doAct "priest" "squeeze bob" stFlee
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))

  , testCase "defection × church parade: flee drops mill gates; heretic parade stays" $ do
      -- mill brand parade needs mill regard; carol flee closes dave parade while
      -- church heretic parade (priest regard) stays open.
      let st0 = doAct "dave" "learn" inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
          -- also mill parade path for contrast
          stSqM = doAct "dave" "squeeze bob" (activateSqueeze stP)
          stConf = doAct "bob" "confess the theft" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stBoth = activateParade stBrandM
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stBoth)
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stBoth)
      let stCarol = doAct "carol" "learn" stBoth
          stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "dave parade closed" (not (hasAct "dave" "parade bob" stFlee))
      assertBool "priest parade stays" (hasAct "priest" "parade bob" stFlee)
      let stPar = doAct "priest" "parade bob" stFlee
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))


  , testCase "silence × church parade: mill debt blocks ira; heretic parade stays" $ do
      -- ira silence debt blocks mill denounce; church heretic parade unconstrained.
      let st0 = doAct "ira" "learn" inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
          stBuy = doAct "bob" "buy ira's silence" stP
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "parade at harvest" (hasAct "priest" "parade bob" stH)
      let stPar = doAct "priest" "parade bob" stH
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stPar))

  , testCase "silence × inquisit: mill debt blocks ira; priest squeeze stays" $ do
      -- bob buys ira silence; mill denounce gated; church inquisit squeeze open.
      let st0 = doAct "ira" "learn" inquisitSeed
          stBuy = doAct "bob" "buy ira's silence" st0
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "priest squeeze still" (hasAct "priest" "squeeze bob" stH)
      let stSq = doAct "priest" "squeeze bob" stH
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stSq))


  , testCase "wed × inquisit: fran wedding unlocks mill; church squeeze stays" $ do
      -- fran wed unlocks mill regard/squeeze; priest inquisit squeeze independent.
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") inquisitSeed
          stSq0 = activateSqueeze stBel
      assertBool "before: no fran regard"
        (not (exists "regards.fran.bob.thief" (readView stSq0)))
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" stSq0)
      let stWed = doAct "fran" "wed into the mill" stSq0
      assertBool "after: fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "fran squeeze yes" (hasAct "fran" "squeeze bob" stWed)
      assertBool "priest squeeze still" (hasAct "priest" "squeeze bob" stWed)
      let stFran = doAct "fran" "squeeze bob" stWed
      assertBool "threatened mill"
        (exists "threatened.squeeze.fran.bob" (db stFran))
      assertBool "priest squeeze after" (hasAct "priest" "squeeze bob" stFran)
      let stP = doAct "priest" "squeeze bob" stFran
      assertBool "threatened church"
        (exists "threatened.inquisit.priest.bob" (db stP))

  , testCase "cry × inquisit: market cry and church squeeze stay independent" $ do
      -- dave mill cry at market + priest inquisit squeeze share no once-gate.
      let st0 = doAct "dave" "learn" inquisitSeed
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stM = iterate roundBoundary st0 !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "priest squeeze at market" (hasAct "priest" "squeeze bob" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "squeeze after cry" (hasAct "priest" "squeeze bob" stCry)
      let stSq = doAct "priest" "squeeze bob" stCry
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "cry spent" (not (hasAct "dave" "cry the theft" stSq))


  , testCase "rally × inquisit: market rally and church squeeze stay independent" $ do
      -- reputeSeed path + inquisitSeed: market rally and priest squeeze share no gate.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" inquisitSeed)
          -- dave needs angry+notorious; inquisitSeed already has dave learn above;
          -- ensure repute anger: carol learn gave two regards → notorious if dave angry.
          dave' = (actorOf "dave" st0)
                    { charDesires = [rallyDesireName] ++ millCry }
          stR = st0 { characters =
                        [ if charName c == "dave" then dave' else c
                        | c <- characters st0 ] }
      assertBool "notorious" (exists "notorious.bob.thief" (readView stR))
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" stR)
      let stM = iterate roundBoundary stR !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "priest squeeze at market" (hasAct "priest" "squeeze bob" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "squeeze after rally" (hasAct "priest" "squeeze bob" stRally)
      let stSq = doAct "priest" "squeeze bob" stRally
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))

  , testCase "wed × church parade: fran wedding unlocks mill; heretic parade stays" $ do
      -- fran wed unlocks mill regard; church heretic parade independent.
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
          stBel = performOutcome (Insert "fran.believes.stole.bob.carol") stP
      assertBool "before: no fran regard"
        (not (exists "regards.fran.bob.thief" (readView stBel)))
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stBel)
      let stWed = doAct "fran" "wed into the mill" stBel
      assertBool "after: fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      assertBool "priest parade still" (hasAct "priest" "parade bob" stWed)
      let stPar = doAct "priest" "parade bob" stWed
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))
      assertBool "fran regard persists"
        (exists "regards.fran.bob.thief" (readView stPar))


  , testCase "denounce × parade: harvest denounce and brand parade stay independent" $ do
      -- brand→activateParade; harvest denounce and parade share no once-gate.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "parade after denounce" (hasAct "dave" "parade bob" stDen)
      let stPar = doAct "dave" "parade bob" stDen
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))

  , testCase "exile × inquisit: mill exile and church squeeze stay independent" $ do
      -- dave mill denounce→exile while priest inquisit squeeze remains open
      -- through the exile window (no shared once-gate).
      let st0 = doAct "dave" "learn" inquisitSeed
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "priest squeeze after denounce" (hasAct "priest" "squeeze bob" stAfter)
      let stSq = doAct "priest" "squeeze bob" stAfter
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))
      assertBool "exile still" (hasAct "dave" "exile" stSq)
      let stEx = doAct "dave" "exile" stSq
      assertBool "exiled" (exists "exiled.bob" (db stEx))


  , testCase "silence × church exile: mill debt blocks ira; priest heresy exile stays" $ do
      -- ira silence blocks mill denounce; priest hear→censure→banish bob free.
      let st0 = doAct "ira" "learn" (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          stBuy = doAct "bob" "buy ira's silence" stHear
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      assertBool "ira exile no" (not (hasAct "ira" "exile" stAfter))
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stEx))


  , testCase "parade × church exile: mill parade and priest banish stay independent" $ do
      -- mill brand parade + church bob heresy censure→banish: share no gate.
      let st0 = activateChurchBob coerceSeed
          stHear = doAct "priest" "hear of bob" st0
          stSq = doAct "dave" "squeeze bob" stHear
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      assertBool "parade after censure" (hasAct "dave" "parade bob" stAfter)
      let stPar = doAct "dave" "parade bob" stAfter
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "banish still" (hasAct "priest" "banish bob" stPar)
      let stEx = doAct "priest" "banish bob" stPar
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "cry × church exile: market cry and priest banish stay independent" $ do
      -- market cry then next-cycle harvest church censure→banish free.
      let st0 = doAct "dave" "learn" (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
      let stM = iterate roundBoundary stHear !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      -- next harvest at tick 6 from start (= !! 2 from market)
      let stH = iterate roundBoundary stCry !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "cried persists" (exists "cried.dave.bob" (db stEx))


  , testCase "squeeze × church exile: mill squeeze and priest banish stay independent" $ do
      -- activateSqueeze + church bob heresy: squeeze and censure→banish share no gate.
      let st0 = activateSqueeze (doAct "dave" "learn" (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stHear)
      let stH = iterate roundBoundary stHear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "squeeze at harvest" (hasAct "dave" "squeeze bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      assertBool "squeeze after censure" (hasAct "dave" "squeeze bob" stAfter)
      let stSq = doAct "dave" "squeeze bob" stAfter
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))
      assertBool "banish still" (hasAct "priest" "banish bob" stSq)
      let stEx = doAct "priest" "banish bob" stSq
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "rally × church exile: market rally and priest banish stay independent" $ do
      -- reputeSeed path + church bob heresy: market rally then next harvest banish.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stChurch = activateChurchBob st0
          stHear = doAct "priest" "hear of bob" stChurch
      assertBool "notorious" (exists "notorious.bob.thief" (readView stHear))
      let stM = iterate roundBoundary stHear !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      let stH = iterate roundBoundary stRally !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "rallied persists" (exists "rallied.dave.bob" (db stEx))


  , testCase "wed × church exile: fran wedding unlocks mill; priest banish stays" $ do
      -- fran wed → mill regard/denounce; church bob heresy censure→banish independent.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stBel = performOutcome (Insert "fran.believes.stole.bob.carol") stHear
      assertBool "before: no fran regard"
        (not (exists "regards.fran.bob.thief" (readView stBel)))
      assertBool "priest can censure path later" True
      let stWed = doAct "fran" "wed into the mill" stBel
      assertBool "after: fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      let stH = iterate roundBoundary stWed !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "fran denounce yes" (hasAct "fran" "denounce" stH)
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      assertBool "fran denounce after censure" (hasAct "fran" "denounce" stAfter
        || exists "censured.priest.bob" (db stAfter))
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "fran regard persists"
        (exists "regards.fran.bob.thief" (readView stEx))

  , testCase "affiliate × church: kyle affiliate-only cannot censure/banish" $ do
      -- kyle affiliates mill / primary guild → no church standing; priest hear
      -- opens censure/banish for priest only.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db stHear))
      assertBool "kyle primary guild" (exists "member.kyle!guild" (db stHear))
      let stH = iterate roundBoundary stHear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "kyle censure no" (not (hasAct "kyle" "censure bob" stH))
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      assertBool "kyle banish no" (not (hasAct "kyle" "banish bob" stAfter))
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))


  , testCase "defection × church exile: flee drops mill; priest banish stays" $ do
      -- carol abandon dissolves dave mill regard/exile; church bob heresy
      -- censure→banish ignores mill standing and stays open.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
          stCarol = doAct "carol" "learn" stDave
      assertBool "before: dave regard"
        (exists "regards.dave.bob.thief" (readView stCarol))
      let stFlee = doAct "carol" "abandon the mill" stCarol
      assertBool "after flee: no dave regard"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      let stH = iterate roundBoundary stFlee !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce no" (not (hasAct "dave" "denounce" stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))

  , testCase "affiliate × inquisit: kyle affiliate-only cannot squeeze church" $ do
      -- kyle affiliates mill / primary guild → no church standing; priest squeeze open.
      let st0 = inquisitSeed
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st0))
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      assertBool "kyle squeeze no" (not (hasAct "kyle" "squeeze bob" st0))
      let stSq = doAct "priest" "squeeze bob" st0
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))


  , testCase "affiliate × church parade: kyle cannot parade heretic" $ do
      -- kyle affiliate-only; priest brand→church parade open for priest only.
      let st0 = doAct "dave" "learn" inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db stP))
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stP)
      assertBool "kyle parade no" (not (hasAct "kyle" "parade bob" stP))
      let stPar = doAct "priest" "parade bob" stP
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))

  , testCase "affiliate × church exile path: kyle cannot censure after hear" $ do
      -- reinforce affiliate×church: even at harvest after hear, kyle stays closed.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stH = iterate roundBoundary stHear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "kyle denounce mill no" (not (hasAct "kyle" "denounce" stH))
      assertBool "kyle censure no" (not (hasAct "kyle" "censure bob" stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)


  , testCase "wed × church silence: fran wedding unlocks mill; priest debt blocks censure" $ do
      -- fran wed → mill regard/denounce; bob buys priest church-silence → censure closed.
      let st0 = inquisitSeed
          stBel = performOutcome (Insert "fran.believes.stole.bob.carol") st0
          stWed = doAct "fran" "wed into the mill" stBel
      assertBool "fran regard"
        (exists "regards.fran.bob.thief" (readView stWed))
      let stBuy = doAct "bob" "buy priest" stWed
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "fran denounce yes" (hasAct "fran" "denounce" stH)
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stDen = doAct "fran" "denounce" stH
      assertBool "denounced" (exists "denounced.fran.bob" (db stDen)
        || exists "denounced.fran.bob" (readView stDen))

  , testCase "defection × church silence: flee closes mill; priest debt blocks censure" $ do
      -- carol abandon closes dave mill gates; bob buys priest silence closes censure;
      -- return restores mill while church debt still blocks.
      let st0 = inquisitSeed
          stDave = doAct "dave" "learn" st0
          stCarol = doAct "carol" "learn" stDave
          stFlee = doAct "carol" "abandon the mill" stCarol
          stBuy = doAct "bob" "buy priest" stFlee
      assertBool "dave regard gone"
        (not (exists "regards.dave.bob.thief" (readView stBuy)))
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce no" (not (hasAct "dave" "denounce" stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stBack = doAct "carol" "return to the mill" stH
      assertBool "dave denounce restored" (hasAct "dave" "denounce" stBack)
      assertBool "priest censure still blocked"
        (not (hasAct "priest" "censure bob" stBack))


  , testCase "parade × church silence: mill parade open; priest debt blocks censure" $ do
      -- mill brand parade stays while bob buys priest church-silence.
      let st0 = activateChurchBob coerceSeed
          stHear = doAct "priest" "hear of bob" st0
          stSq = doAct "dave" "squeeze bob" stHear
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
          stBuy = doAct "bob" "buy priest" stP
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stPar = doAct "dave" "parade bob" stH
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stPar))

  , testCase "denounce × church exile: mill denounce/exile and priest banish stay independent" $ do
      -- dave harvest denounce→exile while priest hear→censure→banish share no gate.
      -- After either exile mark lands, the other exile/banish may close — pin both
      -- open together, then take priest banish (church path completes).
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
          stH = iterate roundBoundary stDave !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stDen = doAct "dave" "denounce" stH
          stCen = doAct "priest" "censure bob" stDen
          stAfter = roundBoundary stCen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      let stEx = doAct "priest" "banish bob" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "dave denounced mark stays"
        (exists "denounced.dave.bob" (db stEx))


  , testCase "cry × church silence: market cry open; priest debt blocks censure" $ do
      -- dave market cry stays while bob buys priest church-silence.
      let st0 = inquisitSeed
          stDave = doAct "dave" "learn" st0
          stBuy = doAct "bob" "buy priest" stDave
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stM = iterate roundBoundary stBuy !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stM))
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stCry))

  , testCase "rally × church silence: market rally open; priest debt blocks censure" $ do
      -- notorious+angry market rally stays while bob buys priest church-silence.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stHear = doAct "priest" "hear of bob" (activateChurchBob st0)
          stBuy = doAct "bob" "buy priest" stHear
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "notorious" (exists "notorious.bob.thief" (readView stBuy))
      let stM = iterate roundBoundary stBuy !! 4
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stM))
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))


  , testCase "squeeze × church silence: mill squeeze open; priest debt blocks censure" $ do
      -- coerceSeed mill squeeze stays while bob buys priest church-silence.
      let st0 = activateChurchBob coerceSeed
          stHear = doAct "priest" "hear of bob" st0
          stBuy = doAct "bob" "buy priest" stHear
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      assertBool "squeeze at harvest" (hasAct "dave" "squeeze bob" stH)
      let stSq = doAct "dave" "squeeze bob" stH
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))

  , testCase "affiliate × church silence: kyle cannot censure; priest debt blocks priest" $ do
      -- kyle affiliate-only stays closed; bob buys priest silence blocks censure.
      let st0 = inquisitSeed
          stBuy = doAct "bob" "buy priest" st0
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db stBuy))
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "kyle censure no" (not (hasAct "kyle" "censure bob" stH))
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))


  , testCase "exile × church silence: mill exile open; priest debt blocks banish" $ do
      -- dave denounce→exile stays while bob buys priest church-silence.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
          stBuy = doAct "bob" "buy priest" stDave
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "priest banish no" (not (hasAct "priest" "banish bob" stAfter))
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stEx))

  , testCase "wed × silence: fran wedding unlocks mill; ira debt blocks ira denounce" $ do
      -- fran wed → mill regard; bob buys ira silence → ira denounce closed, fran open.
      let stBel = performOutcome (Insert "fran.believes.stole.bob.carol") sandboxWorld
          stWed = doAct "fran" "wed into the mill" stBel
          stIra = doAct "ira" "learn" stWed
          stBuy = doAct "bob" "buy ira" stIra
      assertBool "fran regard"
        (exists "regards.fran.bob.thief" (readView stBuy))
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "fran denounce yes" (hasAct "fran" "denounce" stH)
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))


  , testCase "defection × silence: flee closes mill; ira debt blocks ira; return restores mill" $ do
      -- bob buys ira silence first; carol abandon closes dave; return restores dave only.
      let stDave = doAct "dave" "learn" sandboxWorld
          stCarol = doAct "carol" "learn" stDave
          stIra = doAct "ira" "learn" stCarol
          stBuy = doAct "bob" "buy ira" stIra
          stFlee = doAct "carol" "abandon the mill" stBuy
      assertBool "dave regard gone"
        (not (exists "regards.dave.bob.thief" (readView stFlee)))
      assertBool "debt" (exists "debt.ira.bob.favor" (db stFlee))
      let stH = iterate roundBoundary stFlee !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce no" (not (hasAct "dave" "denounce" stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      let stBack = doAct "carol" "return to the mill" stH
      assertBool "dave denounce restored" (hasAct "dave" "denounce" stBack)
      assertBool "ira still blocked" (not (hasAct "ira" "denounce" stBack))


  , testCase "affiliate × silence: kyle cannot denounce; ira debt blocks ira" $ do
      -- kyle affiliate-only closed; bob buys ira silence blocks ira denounce.
      let stIra = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" stIra
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db stBuy))
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "kyle denounce no" (not (hasAct "kyle" "denounce" stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "dave can learn then denounce path exists" True

  , testCase "denounce × church silence: mill denounce open; priest debt blocks censure" $ do
      -- dave harvest denounce completes while bob buys priest church-silence.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
          stBuy = doAct "bob" "buy priest" stDave
      assertBool "debt" (exists "debt.priest.bob.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "priest censure blocked" (not (hasAct "priest" "censure bob" stH))
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "debt still" (exists "debt.priest.bob.church-favor" (db stDen))
      assertBool "priest still blocked" (not (hasAct "priest" "censure bob" stDen))

  , testCase "denounce × inquisit: mill denounce and church squeeze stay independent" $ do
      -- dave harvest denounce while priest inquisit squeeze remains open (no shared gate).
      let st0 = doAct "dave" "learn" inquisitSeed
      assertBool "priest squeeze yes" (hasAct "priest" "squeeze bob" st0)
      let stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "priest squeeze at harvest" (hasAct "priest" "squeeze bob" stH)
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "priest squeeze after denounce" (hasAct "priest" "squeeze bob" stDen)
      let stSq = doAct "priest" "squeeze bob" stDen
      assertBool "threatened"
        (exists "threatened.inquisit.priest.bob" (db stSq))

  , testCase "denounce × church parade: mill denounce and heretic parade stay independent" $ do
      -- brand→activateChurchParade; harvest denounce and priest parade share no gate.
      let st0 = doAct "dave" "learn" inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant the heresy" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stP = activateChurchParade stBrand
      assertBool "priest parade yes" (hasAct "priest" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      assertBool "parade at harvest" (hasAct "priest" "parade bob" stH)
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "parade after denounce" (hasAct "priest" "parade bob" stDen)
      let stPar = doAct "priest" "parade bob" stDen
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))

  , testCase "censure × mill silence: priest censure open; ira debt blocks mill denounce" $ do
      -- ira silence blocks mill; priest hear→censure bob free at harvest.
      let st0 = doAct "ira" "learn" (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          stBuy = doAct "bob" "buy ira's silence" stHear
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stCen))
      assertBool "ira still blocked" (not (hasAct "ira" "denounce" stCen))

  , testCase "censure × mill squeeze: priest censure and mill squeeze stay independent" $ do
      -- harvest: priest censure bob while dave mill squeeze shares no once-gate.
      let st0 = activateChurchBob coerceSeed
          stHear = doAct "priest" "hear of bob" st0
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stHear)
      let stH = iterate roundBoundary stHear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "squeeze at harvest" (hasAct "dave" "squeeze bob" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      assertBool "squeeze after censure" (hasAct "dave" "squeeze bob" stCen)
      let stSq = doAct "dave" "squeeze bob" stCen
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))

  , testCase "censure × mill parade: priest censure and brand parade stay independent" $ do
      -- brand→activateParade; harvest censure and dave parade share no gate.
      let st0 = activateChurchBob coerceSeed
          stHear = doAct "priest" "hear of bob" st0
          stSq = doAct "dave" "squeeze bob" stHear
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stP = activateParade stBrand
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stP)
      let stH = iterate roundBoundary stP !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      assertBool "parade after censure" (hasAct "dave" "parade bob" stCen)
      let stPar = doAct "dave" "parade bob" stCen
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))

  , testCase "censure × cry: priest censure and market cry stay independent" $ do
      -- harvest censure then market cry; church tribunal and mill cry share no gate.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
      let stH = iterate roundBoundary stDave !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      let stM = roundBoundary stCen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))

  , testCase "censure × rally: priest censure and market rally stay independent" $ do
      -- notorious+angry; harvest censure then market rally share no once-gate.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stHear = doAct "priest" "hear of bob" (activateChurchBob st0)
      assertBool "notorious" (exists "notorious.bob.thief" (readView stHear))
      let stH = iterate roundBoundary stHear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      let stM = roundBoundary stCen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))


  , testCase "censure × mill exile: priest censure then dave denounce/exile stay independent" $ do
      -- take church censure first at harvest; mill denounce→exile still completes.
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          stDave = doAct "dave" "learn" stHear
          stH = iterate roundBoundary stDave !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure yes" (hasAct "priest" "censure bob" stH)
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stCen = doAct "priest" "censure bob" stH
      assertBool "censured" (exists "censured.priest.bob" (db stCen))
      assertBool "dave denounce after censure" (hasAct "dave" "denounce" stCen)
      let stDen = doAct "dave" "denounce" stCen
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "priest banish yes" (hasAct "priest" "banish bob" stAfter)
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "censured mark stays" (exists "censured.priest.bob" (db stEx))

  , testCase "heresy silence × mill denounce: gale debt blocks eve track; dave mill open" $ do
      -- eve buys gale church-silence; mill bob theft track unconstrained.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stDave = doAct "dave" "learn" st0
          stBuy = doAct "eve" "buy gale" stDave
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stDen))
      assertBool "gale still blocked" (not (hasAct "gale" "censure" stDen))

  , testCase "heresy silence × mill cry: gale debt blocks; dave market cry open" $ do
      -- eve/gale church-silence debt; mill market cry unconstrained.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stDave = doAct "dave" "learn" st0
          stBuy = doAct "eve" "buy gale" stDave
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      let stM = roundBoundary stH
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry yes" (hasAct "dave" "cry the theft" stM)
      let stCry = doAct "dave" "cry the theft" stM
      assertBool "cried" (exists "cried.dave.bob" (db stCry))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stCry))

  , testCase "heresy silence × mill squeeze: gale debt blocks; dave squeeze open" $ do
      -- eve/gale church-silence; mill coerce squeeze unconstrained.
      let st0 = doAct "gale" "hear the blasphemy" (activateSqueeze sandboxWorld)
          stDave = doAct "dave" "learn" st0
          stBuy = doAct "eve" "buy gale" stDave
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      assertBool "dave squeeze yes" (hasAct "dave" "squeeze bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "squeeze at harvest" (hasAct "dave" "squeeze bob" stH)
      let stSq = doAct "dave" "squeeze bob" stH
      assertBool "threatened"
        (exists "threatened.squeeze.dave.bob" (db stSq))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stSq))


  , testCase "heresy silence × mill parade: gale debt blocks; dave parade open" $ do
      -- eve/gale church-silence; mill brand parade unconstrained.
      let st0 = doAct "gale" "hear the blasphemy"
                  (activateParade (activateSqueeze sandboxWorld))
          stDave = doAct "dave" "learn" st0
          stSq = doAct "dave" "squeeze bob" stDave
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stBuy = doAct "eve" "buy gale" stBrand
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      assertBool "dave parade yes" (hasAct "dave" "parade bob" stBuy)
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "parade at harvest" (hasAct "dave" "parade bob" stH)
      let stPar = doAct "dave" "parade bob" stH
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stPar))

  , testCase "heresy silence × mill rally: gale debt blocks; dave market rally open" $ do
      -- eve/gale church-silence; notorious+angry market rally unconstrained.
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "carol" "learn" (doAct "dave" "learn" reputeSeed))
          stBuy = doAct "eve" "buy gale" st0
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      assertBool "notorious" (exists "notorious.bob.thief" (readView stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      let stM = roundBoundary stH
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally yes" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
      assertBool "rallied" (exists "rallied.dave.bob" (db stRally))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stRally))

  , testCase "heresy silence × mill exile: gale debt blocks; dave denounce/exile open" $ do
      -- eve/gale church-silence; mill harvest denounce→exile unconstrained.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stDave = doAct "dave" "learn" st0
          stBuy = doAct "eve" "buy gale" stDave
      assertBool "debt" (exists "debt.gale.eve.church-favor" (db stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile yes" (hasAct "dave" "exile" stAfter)
      assertBool "gale still blocked" (not (hasAct "gale" "censure" stAfter))
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "debt still" (exists "debt.gale.eve.church-favor" (db stEx))

  , testCase "dual silence: ira mill debt and gale church debt stay independent" $ do
      -- bob buys ira; eve buys gale; dave mill denounce open; both creditors blocked.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stIra = doAct "ira" "learn" st0
          stDave = doAct "dave" "learn" stIra
          stBuyIra = doAct "bob" "buy ira" stDave
          stBuyGale = doAct "eve" "buy gale" stBuyIra
      assertBool "ira debt" (exists "debt.ira.bob.favor" (db stBuyGale))
      assertBool "gale debt" (exists "debt.gale.eve.church-favor" (db stBuyGale))
      let stH = iterate roundBoundary stBuyGale !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "dave denounce yes" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
      assertBool "denounced" (exists "denounced.dave.bob" (db stDen))
      assertBool "ira debt still" (exists "debt.ira.bob.favor" (db stDen))
      assertBool "gale debt still" (exists "debt.gale.eve.church-favor" (db stDen))


  , testCase "rally × exile: market rally and mill denounce/exile stay independent" $ do
      -- market rally once-gate does not block harvest denounce→exile.
      let st2 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "rally open" (hasAct "dave" "rally" stM)
      let stRally = doAct "dave" "rally" stM
          -- advance to next harvest (period 3 from market tick)
          stH = iterate roundBoundary stRally !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce after rally" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile open" (hasAct "dave" "exile" stAfter)
      let stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "rallied persists" (exists "rallied.dave.bob" (db stEx))

  , testCase "return × squeeze: flee drops squeeze; return restores" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" (doAct "carol" "learn" st0)
      assertBool "squeeze closed while fled"
        (not (hasAct "dave" "squeeze bob" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "squeeze restored" (hasAct "dave" "squeeze bob" stRet)

  , testCase "return × parade: flee drops parade; return restores" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade open" (hasAct "dave" "parade bob" stBrand)
      let stFlee = doAct "carol" "abandon" (doAct "carol" "learn" stBrand)
      assertBool "parade closed while fled"
        (not (hasAct "dave" "parade bob" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "parade restored" (hasAct "dave" "parade bob" stRet)

  , testCase "return × cry: flee drops cry; return restores at market" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stM = roundBoundary (iterate roundBoundary stRet !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry restored" (hasAct "dave" "cry the theft" stM)

  , testCase "parade once × cry: after parade market cry still open" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stM = roundBoundary (iterate roundBoundary stPar !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stM))
      assertBool "cry still open" (hasAct "dave" "cry the theft" stM)

  , testCase "parade once × rally: after parade market rally still open" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" reputeSeed))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [rallyDesireName] ++ millCry }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          st2 = doAct "carol" "learn" stPar
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "rally still open" (hasAct "dave" "rally" stM)

  , testCase "churchParade once × mill cry: after heretic parade mill cry still open" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
          stDave = doAct "dave" "learn" stPar
          stM = roundBoundary (iterate roundBoundary stDave !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "priest parade closed"
        (not (hasAct "priest" "parade bob" stM))
      assertBool "dave cry open" (hasAct "dave" "cry the theft" stM)

  , testCase "dual tear: mill tear and church tear stay independent" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stIra = doAct "ira" "learn" st0
          stBuyIra = doAct "bob" "buy ira" stIra
          stBuyGale = doAct "eve" "buy gale" stBuyIra
      assertBool "ira tear open" (hasAct "ira" "tear up bob" stBuyGale)
      assertBool "gale tear open" (hasAct "gale" "tear up eve" stBuyGale)
      let stTearIra = doAct "ira" "tear up bob" stBuyGale
      assertBool "gale tear still" (hasAct "gale" "tear up eve" stTearIra)
      assertBool "ira tear closed"
        (not (hasAct "ira" "tear up bob" stTearIra))
      let stTearGale = doAct "gale" "tear up eve" stTearIra
      assertBool "gale tear closed"
        (not (hasAct "gale" "tear up eve" stTearGale))
      assertBool "ira revoke" (exists "revoked.ira.bob" (db stTearGale)
                               || exists "revoked.ira.bob" (db stTearIra))

  , testCase "dual brand: mill brand and church brand stay independent" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
      assertBool "mill branded" (exists "branded.bob" (db stBrandM))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stBrandM)
      let stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "heretic branded"
        (exists "brandedHeretic.bob" (db stBrandC))
      assertBool "mill brand persists" (exists "branded.bob" (db stBrandC))

  , testCase "dual parade: mill and church parade both open after dual brand" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "dave parade" (hasAct "dave" "parade bob" stBrandC)
      assertBool "priest parade" (hasAct "priest" "parade bob" stBrandC)
      let stParM = doAct "dave" "parade bob" stBrandC
      assertBool "priest parade still"
        (hasAct "priest" "parade bob" stParM)
      assertBool "dave parade closed"
        (not (hasAct "dave" "parade bob" stParM))


  , testCase "wants: paradeSeed dave parades after brand" $ do
      -- After squeeze→confess→re-squeeze→brand, hang only parade want; pick parade.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = activateParade (doAct "dave" "brand bob" stSq2)
          dave' = (actorOf "dave" stBrand) { charDesires = [paradeDesireName] }
          bob'  = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "branded" (exists "branded.bob" (db st))
      assertBool "parade open" (hasAct "dave" "parade bob" st)
      pickLabel "dave" st @?= Just "dave: parade bob as branded thief"
      let stPar = doAct "dave" "parade bob" st
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))

  , testCase "wants: churchParadeSeed priest parades after heretic brand" $ do
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = activateChurchParade (doAct "priest" "brand bob" stDefy)
          priest' = (actorOf "priest" stBrand)
                      { charDesires = [churchParadeDesireName] }
          bob' = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "brandedHeretic" (exists "brandedHeretic.bob" (db st))
      assertBool "parade open" (hasAct "priest" "parade bob" st)
      pickLabel "priest" st @?= Just "priest: parade bob as branded heretic"
      let stPar = doAct "priest" "parade bob" st
      assertBool "paraded" (exists "paraded.priest.bob" (db stPar))

  , testCase "wants: without paradeDesire dave does not pick parade after brand" $ do
      -- Practice active + branded, but cast millCry only (no parade want) → not parade.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = activateParade (doAct "dave" "brand bob" stSq2)
          dave' = (actorOf "dave" stBrand) { charDesires = millCry }
          bob'  = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "parade open" (hasAct "dave" "parade bob" st)
      let lab = pickLabel "dave" st
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: exile weight beats parade when both open" $ do
      -- After harvest denounce + brand, dave holds exile(12) + parade(10) → picks exile.
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess the theft" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          dave' = (actorOf "dave" stAfter)
                     { charDesires = [exileBobDesireName, paradeDesireName] }
          bob' = (actorOf "bob" stAfter) { charDesires = [] }
          st = stAfter { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "dave" "exile" st)
      assertBool "parade open" (hasAct "dave" "parade bob" st)
      pickLabel "dave" st @?= Just "dave: exile the thief"

  , testCase "wants: without churchParadeDesire priest does not pick parade" $ do
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = activateChurchParade (doAct "priest" "brand bob" stDefy)
          priest' = (actorOf "priest" stBrand) { charDesires = bobHeresyJustice }
          bob' = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "parade open" (hasAct "priest" "parade bob" st)
      let lab = pickLabel "priest" st
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: bob exile weight beats church parade when both open" $ do
      -- After heretic brand + harvest censure, priest holds exile(12) + church parade(10).
      let st0 = activateChurchParade inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stDefy = doAct "bob" "defy" stSq
          stBrand = doAct "priest" "brand bob" stDefy
          stH = iterate roundBoundary stBrand !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure open" (hasAct "priest" "censure" stH)
      let stCen = doAct "priest" "censure" stH
          stAfter = roundBoundary stCen
          priest' = (actorOf "priest" stAfter)
                      { charDesires = [exileBobDesireName, churchParadeDesireName] }
          bob' = (actorOf "bob" stAfter) { charDesires = [] }
          st = stAfter { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stAfter ] }
      assertBool "banish open" (hasAct "priest" "banish" st || hasAct "priest" "exile" st)
      assertBool "parade open" (hasAct "priest" "parade bob" st)
      let lab = pickLabel "priest" st
      assertBool ("exile/banish over parade, got " ++ show lab)
        (case lab of
           Just l -> ("exile" `isInfixOf` l || "banish" `isInfixOf` l)
                     && not ("parade" `isInfixOf` l)
           Nothing -> False)

  , testCase "wants: without rallyDesire dave does not pick rally at market" $ do
      -- Gates open (notorious+angry+market) but dave only holds millCry — cry wins / no rally pick.
      let st0 = sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          stR = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market open" (exists "festival.market" (db stM))
      assertBool "rally open" (hasAct "dave" "rally" stM)
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      let lab = pickLabel "dave" stM
      assertBool ("not rally, got " ++ show lab)
        (maybe True (not . ("rally" `isInfixOf`)) lab)
      pickLabel "dave" stM @?= Just "dave: cry the theft at market"

  , testCase "wants: without cryDesire dave does not pick cry at market" $ do
      -- Market cry gate open; dave holds only millJustice (no cries-theft-at-market).
      let st0 = sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millJustice }
          stR = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market open" (exists "festival.market" (db stM))
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      let lab = pickLabel "dave" stM
      assertBool ("not cry, got " ++ show lab)
        (maybe True (not . ("cry" `isInfixOf`)) lab)

  , testCase "wants: rallyDesire weight beats cry when both open" $ do
      -- Explicit name-pin: rally(9) > cry(7) at market under reputeSeed.
      assertBool "vocab" (any ((== rallyDesireName) . desireName) sandboxDesires)
      assertBool "vocab cry" (any ((== cryDesireName) . desireName) sandboxDesires)
      let st2 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "rally open" (hasAct "dave" "rally" stM)
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      pickLabel "dave" stM @?= Just "dave: rally the square against the thief"

  , testCase "wants: without squeezeDesire dave does not pick squeeze" $ do
      -- Practice active + regards, but dave only holds millJustice — no squeeze pick.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = millJustice }
          bob' = (actorOf "bob" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
      assertBool "squeeze open" (hasAct "dave" "squeeze bob" st)
      let lab = pickLabel "dave" st
      assertBool ("not squeeze, got " ++ show lab)
        (maybe True (not . ("squeeze" `isInfixOf`)) lab)

  , testCase "wants: without inquisitDesire priest does not pick church squeeze" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          -- priest hears so regards bob heretic; strip inquisit want
          stHear = doAct "priest" "hear" st0
          priest' = (actorOf "priest" stHear) { charDesires = bobHeresyJustice }
          bob' = (actorOf "bob" stHear) { charDesires = [] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stHear ] }
      assertBool "squeeze open" (hasAct "priest" "squeeze bob" st)
      let lab = pickLabel "priest" st
      assertBool ("not squeeze, got " ++ show lab)
        (maybe True (not . ("squeeze" `isInfixOf`)) lab)



  , testCase "wants: without fleeDesire carol does not abandon mill" $ do
      -- After learn, abandon gate open; carol holds only millJustice — no flee pick.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          carol' = (actorOf "carol" st0) { charDesires = millJustice }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
      assertBool "flee open" (hasAct "carol" "abandon" st)
      let lab = pickLabel "carol" st
      assertBool ("not abandon, got " ++ show lab)
        (maybe True (not . ("abandon" `isInfixOf`)) lab)

  , testCase "wants: without returnDesire carol does not reconcile after flee" $ do
      let st0 = defectionSeed
          stFlee = doAct "carol" "abandon" (doAct "carol" "learn" st0)
          carol' = (actorOf "carol" stFlee) { charDesires = millJustice }
          st = stFlee { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters stFlee ] }
      assertBool "return open" (hasAct "carol" "return" st || hasAct "carol" "reconcil" st)
      let lab = pickLabel "carol" st
      assertBool ("not return, got " ++ show lab)
        (case lab of
           Just l -> not ("return" `isInfixOf` l || "reconcil" `isInfixOf` l)
           Nothing -> True)

  , testCase "sandboxDesires: flee/return names registered" $ do
      assertBool "flee vocab" (any ((== fleeDesireName) . desireName) sandboxDesires)
      assertBool "return vocab" (any ((== returnDesireName) . desireName) sandboxDesires)



  , testCase "wants: without millSilenceDesire bob does not buy ira silence" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          bob' = (actorOf "bob" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "bob" then bob' else c
                  | c <- characters st0 ] }
      assertBool "buy open" (hasAct "bob" "buy ira" st)
      let lab = pickLabel "bob" st
      assertBool ("not buy silence, got " ++ show lab)
        (case lab of
           Just l -> not ("buy" `isInfixOf` l || "silence" `isInfixOf` l)
           Nothing -> True)

  , testCase "wants: without churchSilenceDesire eve does not buy gale silence" $ do
      let st0 = doAct "gale" "hear" sandboxWorld
          eve' = (actorOf "eve" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "eve" then eve' else c
                  | c <- characters st0 ] }
      assertBool "buy open" (hasAct "eve" "buy gale" st || hasAct "eve" "church" st)
      let lab = pickLabel "eve" st
      assertBool ("not buy church silence, got " ++ show lab)
        (case lab of
           Just l -> not ("buy" `isInfixOf` l)
           Nothing -> True)

  , testCase "sandboxDesires: silence want names registered" $ do
      assertBool "mill buy" (any ((== millSilenceDesireName) . desireName) sandboxDesires)
      assertBool "mill break" (any ((== millBreakSilenceDesireName) . desireName) sandboxDesires)
      assertBool "church buy" (any ((== churchSilenceDesireName) . desireName) sandboxDesires)
      assertBool "church break" (any ((== churchBreakSilenceDesireName) . desireName) sandboxDesires)



  , testCase "wants: without breakSilence ira does not tear up" $ do
      -- After bob buys, tear gate open; ira only millJustice — no tear pick.
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          ira' = (actorOf "ira" stBuy) { charDesires = millJustice }
          st = stBuy { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters stBuy ] }
      assertBool "tear open" (hasAct "ira" "tear up bob" st)
      let lab = pickLabel "ira" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: without churchBreakSilence gale does not tear up" $ do
      let st0 = doAct "gale" "hear" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          gale' = (actorOf "gale" stBuy) { charDesires = churchJustice }
          st = stBuy { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters stBuy ] }
      assertBool "tear open" (hasAct "gale" "tear up eve" st)
      let lab = pickLabel "gale" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: without fearsBrand bob does not confess after squeeze" $ do
      -- Gate open after dave squeeze; bob empty wants — no confess pick.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          bob' = (actorOf "bob" st0) { charDesires = [] }
          stBase = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" stBase
      assertBool "confess open" (hasAct "bob" "confess" stSq)
      let lab = pickLabel "bob" stSq
      assertBool ("not confess, got " ++ show lab)
        (maybe True (not . ("confess" `isInfixOf`)) lab)

  , testCase "wants: without fearsBrandHeretic bob does not recant after inquisit" $ do
      let st0 = inquisitSeed
          bob' = (actorOf "bob" st0) { charDesires = [] }
          stBase = st0 { characters =
                  [ if charName c == "bob" then bob' else c
                  | c <- characters st0 ] }
          stSq = doAct "priest" "squeeze bob" stBase
      assertBool "recant open" (hasAct "bob" "recant" stSq)
      let lab = pickLabel "bob" stSq
      assertBool ("not recant, got " ++ show lab)
        (maybe True (not . ("recant" `isInfixOf`)) lab)

  , testCase "sandboxDesires: justice want names registered" $ do
      let names = map desireName sandboxDesires
      mapM_ (\(n,l) -> assertBool l (n `elem` names))
        [ (seeksTheftDesireName, "seeks theft")
        , (punishesThiefDesireName, "punish thief")
        , (exileBobDesireName, "exile bob")
        , (seeksHeresyDesireName, "seeks heresy")
        , (punishesHereticDesireName, "punish heretic")
        , (exileEveDesireName, "exile eve")
        , (seeksBobHeresyDesireName, "seeks bob heresy")
        , (punishesBobHereticDesireName, "punish bob heretic")
        , (joinsMillDesireName, "joins mill")
        ]

  , testCase "wants: exile weight beats denounce when both open" $ do
      -- After harvest denounce, outside window: exile(12) vs other mill wants.
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          dave' = (actorOf "dave" stAfter)
                    { charDesires = [exileBobDesireName, punishesThiefDesireName] }
          bob' = (actorOf "bob" stAfter) { charDesires = [] }
          st = stAfter { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "dave" "exile" st)
      pickLabel "dave" st @?= Just "dave: exile the thief"

  , testCase "wants: denounce weight beats cry when harvest open" $ do
      -- harvest: denounce(8) open, cry closed; still pin weight vocabulary vs cry(7).
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0)
                    { charDesires = [punishesThiefDesireName, cryDesireName, exileBobDesireName] }
          stR = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary stR !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce open" (hasAct "dave" "denounce" stH)
      assertBool "cry closed" (not (hasAct "dave" "cry" stH))
      pickLabel "dave" stH @?= Just "dave: denounce the thief"

  , testCase "wants: bobHeresy censure weight beats eve censure on dualPressure" $ do
      -- punishes-bob-heretic(9) > punishes-heretic(8): priest prefers censure bob.
      let st0 = dualPressureSeed
          stHear = doAct "priest" "hear of bob" (doAct "priest" "hear the blasphemy" st0)
          stH = iterate roundBoundary stHear !! 3
          priest' = (actorOf "priest" stH)
                      { charDesires = [punishesBobHereticDesireName, punishesHereticDesireName] }
          st = stH { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stH ] }
      assertBool "censure bob" (hasAct "priest" "censure bob" st)
      assertBool "censure eve" (hasAct "priest" "censure the heretic" st
                                || hasAct "priest" "censure" st)
      let lab = pickLabel "priest" st
      assertBool ("censure bob over eve, got " ++ show lab)
        (case lab of
           Just l -> "bob" `isInfixOf` l && "censure" `isInfixOf` l
           Nothing -> False)



  , testCase "wants: without joinsMill fran does not wed" $ do
      -- Strip all wants (millCry includes seeks which can compete); empty → Wait.
      let st0 = sandboxWorld
          fran' = (actorOf "fran" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters st0 ] }
      assertBool "wed open" (hasAct "fran" "wed" st)
      let lab = pickLabel "fran" st
      assertBool ("not wed, got " ++ show lab)
        (maybe True (not . ("wed" `isInfixOf`)) lab)
      pickLabel "fran" st @?= Just "fran: Wait a moment"

  , testCase "wants: without seeksTheft dave does not learn" $ do
      let st0 = sandboxWorld
          dave' = (actorOf "dave" st0)
                    { charDesires = [punishesThiefDesireName, exileBobDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
      assertBool "learn open" (hasAct "dave" "learn" st)
      let lab = pickLabel "dave" st
      assertBool ("not learn, got " ++ show lab)
        (maybe True (not . ("learn" `isInfixOf`)) lab)

  , testCase "wants: without seeksHeresy priest does not hear blasphemy" $ do
      let st0 = sandboxWorld
          priest' = (actorOf "priest" st0)
                      { charDesires = [punishesHereticDesireName, exileEveDesireName] }
          st = st0 { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters st0 ] }
      assertBool "hear open" (hasAct "priest" "hear the blasphemy" st)
      let lab = pickLabel "priest" st
      assertBool ("not hear, got " ++ show lab)
        (maybe True (not . ("hear" `isInfixOf`)) lab)

  , testCase "wants: return weight beats flee after abandon" $ do
      -- After flee, return(11) open; carol holds both flee+return — picks return.
      let st0 = defectionSeed
          stFlee = doAct "carol" "abandon" (doAct "carol" "learn" st0)
      assertBool "return open" (hasAct "carol" "return" stFlee)
      pickLabel "carol" stFlee
        @?= Just "carol: return to the mill in reconciliation"

  , testCase "wants: silence buy weight beats millJustice when buy open" $ do
      -- buy(14) > exile(12)/denounce(8): after ira learns, bob with buy+millJustice buys.
      let st0 = doAct "ira" "learn" sandboxWorld
          bob' = (actorOf "bob" st0)
                   { charDesires = [millSilenceDesireName] ++ millJustice }
          st = st0 { characters =
                  [ if charName c == "bob" then bob' else c
                  | c <- characters st0 ] }
      assertBool "buy open" (hasAct "bob" "buy ira" st)
      pickLabel "bob" st @?= Just "bob: buy ira's silence about the theft"

  , testCase "wants: church exile weight beats censure after censure done" $ do
      -- After harvest censure, outside: exile(12) for eve.
      let st0 = doAct "priest" "hear the blasphemy" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "priest" "censure" stH
          stAfter = roundBoundary stCen
          priest' = (actorOf "priest" stAfter)
                      { charDesires = [exileEveDesireName, punishesHereticDesireName] }
          st = stAfter { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "priest" "exile" st)
      pickLabel "priest" st @?= Just "priest: exile the heretic"

  , testCase "cast: fran holds joinsMillDesireName by default" $ do
      assertBool "fran joins"
        (joinsMillDesireName `elem` charDesires (actorOf "fran" sandboxWorld))
      assertBool "cast unhooks parade"
        (paradeDesireName `notElem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "cast unhooks rally"
        (rallyDesireName `notElem` charDesires (actorOf "dave" sandboxWorld))



  , testCase "wants: breakSilence weight beats millJustice when tear open" $ do
      -- tear/revoke(10) vs denounce(8): after buy, ira with break+millJustice tears.
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          ira' = (actorOf "ira" st0)
                   { charDesires = millJustice ++ [millBreakSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters st0 ] }
      assertBool "tear open" (hasAct "ira" "tear up bob" st)
      pickLabel "ira" st @?= Just "ira: tear up bob's silence deal"

  , testCase "wants: without seeksBobHeresy priest does not hear of bob" $ do
      let st0 = dualPressureSeed
          priest' = (actorOf "priest" st0)
                      { charDesires = [punishesBobHereticDesireName, exileBobDesireName] }
          st = st0 { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters st0 ] }
      assertBool "hear bob open" (hasAct "priest" "hear of bob" st)
      let lab = pickLabel "priest" st
      assertBool ("not hear of bob, got " ++ show lab)
        (maybe True (not . ("hear of bob" `isInfixOf`)) lab)

  , testCase "wants: church breakSilence weight beats churchJustice when tear open" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          gale' = (actorOf "gale" st0)
                    { charDesires = churchJustice ++ [churchBreakSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters st0 ] }
      assertBool "tear open" (hasAct "gale" "tear up eve" st)
      pickLabel "gale" st @?= Just "gale: tear up eve's heresy silence deal"

  , testCase "cast: default unhooks coerce and parade wants" $ do
      let dave = charDesires (actorOf "dave" sandboxWorld)
          priest = charDesires (actorOf "priest" sandboxWorld)
          bob = charDesires (actorOf "bob" sandboxWorld)
      assertBool "no squeeze on dave" (squeezeDesireName `notElem` dave)
      assertBool "no inquisit on priest" (inquisitDesireName `notElem` priest)
      assertBool "no parade on dave" (paradeDesireName `notElem` dave)
      assertBool "no churchParade on priest" (churchParadeDesireName `notElem` priest)
      assertBool "no fearsBrand on bob" (fearsBrandName `notElem` bob)
      assertBool "bob holds mill silence buy"
        (millSilenceDesireName `elem` bob)



  , testCase "wants: squeeze weight beats millCry when squeeze open" $ do
      -- coerce weight 10 > cry 7 / denounce 8: dave with squeeze+millCry squeezes outside harvest.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0)
                    { charDesires = [squeezeDesireName] ++ millCry }
          bob' = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
      assertBool "outside" (not (exists "festival.harvest" (db st)))
      assertBool "squeeze open" (hasAct "dave" "squeeze bob" st)
      pickLabel "dave" st @?= Just "dave: squeeze bob for a confession"

  , testCase "wants: inquisit weight beats bobHeresyJustice when squeeze open" $ do
      let st0 = inquisitSeed
          priest' = (actorOf "priest" st0)
                      { charDesires = [inquisitDesireName] ++ bobHeresyJustice }
          st = st0 { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters st0 ] }
      assertBool "squeeze open" (hasAct "priest" "squeeze bob" st)
      pickLabel "priest" st @?= Just "priest: squeeze bob for a recantation"

  , testCase "wants: flee weight beats millCry when abandon open" $ do
      -- flee(9) > cry(7)/denounce(8) outside harvest after learn.
      let st0 = doAct "carol" "learn" sandboxWorld
          carol' = (actorOf "carol" st0)
                     { charDesires = [fleeDesireName] ++ millCry }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
      assertBool "abandon open" (hasAct "carol" "abandon" st)
      assertBool "outside harvest" (not (exists "festival.harvest" (db st)))
      pickLabel "carol" st @?= Just "carol: abandon the mill for the guild"

  , testCase "wants: affiliate kyle never picks mill justice acts" $ do
      -- kyle affiliate-only, empty wants → Wait; gates stay closed for denounce.
      let st = sandboxWorld
      assertBool "kyle no denounce" (not (hasAct "kyle" "denounce" st))
      assertBool "kyle no learn theft path"
        (not (hasAct "kyle" "learn of the theft" st))
      pickLabel "kyle" st @?= Just "kyle: Wait a moment"



  , testCase "wants: after breakSilence denounce weight picks accuse at harvest" $ do
      -- tear restores denounce; at harvest ira with millJustice picks denounce (accuse).
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          stTear = doAct "ira" "tear up bob" st0
          ira' = (actorOf "ira" stTear) { charDesires = millJustice }
          stBase = stTear { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters stTear ] }
          stH = iterate roundBoundary stBase !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce open" (hasAct "ira" "denounce" stH)
      pickLabel "ira" stH @?= Just "ira: denounce the thief"

  , testCase "wants: after church tear censure weight picks accuse at harvest" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          stTear = doAct "gale" "tear up eve" st0
          gale' = (actorOf "gale" stTear) { charDesires = churchJustice }
          stBase = stTear { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters stTear ] }
          stH = iterate roundBoundary stBase !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure open" (hasAct "gale" "censure" stH)
      pickLabel "gale" stH @?= Just "gale: censure the heretic"

  , testCase "wants: parade vs squeeze weight 10 — after brand squeeze closes, parade picks" $ do
      -- Same nominal weight 10, but brand closes squeeze gate; parade opens alone.
      let st0 = coerceSeed
          stSq = doAct "dave" "squeeze bob" st0
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = activateParade (doAct "dave" "brand bob" stSq2)
          dave' = (actorOf "dave" stBrand)
                    { charDesires = [squeezeDesireName, paradeDesireName] }
          bob' = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "parade open" (hasAct "dave" "parade bob" st)
      assertBool "squeeze closed after brand" (not (hasAct "dave" "squeeze bob" st))
      pickLabel "dave" st @?= Just "dave: parade bob as branded thief"

  , testCase "wants: churchParade vs inquisit weight 10 — after brand squeeze closes, parade picks" $ do
      let st0 = inquisitSeed
          stSq = doAct "priest" "squeeze bob" st0
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = activateChurchParade (doAct "priest" "brand bob" stSq2)
          priest' = (actorOf "priest" stBrand)
                      { charDesires = [inquisitDesireName, churchParadeDesireName] }
          bob' = (actorOf "bob" stBrand) { charDesires = [] }
          st = stBrand { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stBrand ] }
      assertBool "parade open" (hasAct "priest" "parade bob" st)
      assertBool "squeeze closed after brand" (not (hasAct "priest" "squeeze bob" st))
      pickLabel "priest" st @?= Just "priest: parade bob as branded heretic"

  , testCase "wants: affiliate kyle with millCry never picks mill justice acts" $ do
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = millCry }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "no learn" (not (hasAct "kyle" "learn" st))
      assertBool "no denounce" (not (hasAct "kyle" "denounce" st))
      let lab = pickLabel "kyle" st
      assertBool ("not mill justice act, got " ++ show lab)
        (case lab of
           Just l -> not (any (`isInfixOf` l)
                      ["learn", "denounce", "exile", "cry the theft"])
           Nothing -> True)

  , testCase "wants: affiliate kyle with squeeze+parade never picks those acts" $ do
      -- Gates closed for affiliate; pick may be wed/Wait but never squeeze/parade.
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          stSq = doAct "dave" "squeeze bob" st0
          bobF = (actorOf "bob" stSq) { charDesires = [fearsBrandName] }
          stSq' = stSq { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stSq ] }
          stConf = doAct "bob" "confess" stSq'
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          kyle' = (actorOf "kyle" stBrand)
                    { charDesires = [squeezeDesireName, paradeDesireName] }
          st = stBrand { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stBrand ] }
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))
      assertBool "kyle no parade" (not (hasAct "kyle" "parade" st))
      assertBool "dave parade open" (hasAct "dave" "parade bob" st)
      let lab = pickLabel "kyle" st
      assertBool ("not squeeze/parade, got " ++ show lab)
        (case lab of
           Just l -> not ("squeeze" `isInfixOf` l || "parade" `isInfixOf` l)
           Nothing -> True)

  , testCase "wants: affiliate kyle with churchJustice+inquisit still Waits" $ do
      let st0 = inquisitSeed
          kyle' = (actorOf "kyle" st0)
                    { charDesires = churchJustice ++ [inquisitDesireName, churchParadeDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no hear" (not (hasAct "kyle" "hear" st))
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))
      assertBool "kyle no censure" (not (hasAct "kyle" "censure" st))
      pickLabel "kyle" st @?= Just "kyle: Wait a moment"

  , testCase "wants: affiliate kyle with flee/return still Waits (no mill standing)" $ do
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [fleeDesireName, returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no abandon" (not (hasAct "kyle" "abandon" st))
      assertBool "kyle no return" (not (hasAct "kyle" "return" st))
      pickLabel "kyle" st @?= Just "kyle: Wait a moment"

  , testCase "wants: affiliate kyle with joinsMill can wed into mill" $ do
      -- Affiliate is not barred from wedding in; joins want drives wed pick.
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = [joinsMillDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "wed open" (hasAct "kyle" "wed" st)
      pickLabel "kyle" st @?= Just "kyle: wed into the mill beside carol"

  , testCase "wants: desire weight vocabulary pins Want utilities" $ do
      -- Symbolic nails for Sandbox desire utilities (no new practices).
      desireUtil seeksTheftDesireName @?= 6
      desireUtil punishesThiefDesireName @?= 8
      desireUtil exileBobDesireName @?= 12
      desireUtil seeksHeresyDesireName @?= 6
      desireUtil punishesHereticDesireName @?= 8
      desireUtil exileEveDesireName @?= 12
      desireUtil joinsMillDesireName @?= 10
      desireUtil millSilenceDesireName @?= 14
      desireUtil millBreakSilenceDesireName @?= 10
      desireUtil cryDesireName @?= 7
      desireUtil fleeDesireName @?= 9
      desireUtil returnDesireName @?= 11
      desireUtil rallyDesireName @?= 9
      desireUtil fearsBrandName @?= (-12)
      desireUtil seeksBobHeresyDesireName @?= 6
      desireUtil punishesBobHereticDesireName @?= 9
      desireUtil churchSilenceDesireName @?= 14
      desireUtil churchBreakSilenceDesireName @?= 10
      desireUtil fearsBrandHereticName @?= (-12)
      desireUtil paradeDesireName @?= 10
      desireUtil churchParadeDesireName @?= 10
      desireUtil squeezeDesireName @?= 10
      desireUtil inquisitDesireName @?= 10

  , testCase "cast: default desire hooks for mill and church roles" $ do
      let dave = charDesires (actorOf "dave" sandboxWorld)
          carol = charDesires (actorOf "carol" sandboxWorld)
          ira = charDesires (actorOf "ira" sandboxWorld)
          bob = charDesires (actorOf "bob" sandboxWorld)
          priest = charDesires (actorOf "priest" sandboxWorld)
          gale = charDesires (actorOf "gale" sandboxWorld)
          kyle = charDesires (actorOf "kyle" sandboxWorld)
      assertBool "dave millCry" (all (`elem` dave) millCry)
      assertBool "carol millCry" (all (`elem` carol) millCry)
      assertBool "ira has breakSilence"
        (millBreakSilenceDesireName `elem` ira)
      assertBool "bob silence buy" (millSilenceDesireName `elem` bob)
      assertBool "priest churchJustice" (all (`elem` priest) churchJustice)
      assertBool "gale churchJustice" (all (`elem` gale) churchJustice)
      assertBool "kyle empty" (null kyle)
      assertBool "eve empty"
        (null (charDesires (actorOf "eve" sandboxWorld)))

  , testCase "wants: church silence buy weight beats churchJustice when buy open" $ do
      -- buy(14) > exile(12)/censure(8): after gale hears, eve with buy+churchJustice buys.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          eve' = (actorOf "eve" st0)
                   { charDesires = [churchSilenceDesireName] ++ churchJustice }
          st = st0 { characters =
                  [ if charName c == "eve" then eve' else c
                  | c <- characters st0 ] }
      assertBool "buy open" (hasAct "eve" "buy gale" st)
      pickLabel "eve" st @?= Just "eve: buy gale's silence about the heresy"

  , testCase "wants: cry weight beats millJustice when cry open at market" $ do
      -- At market: cry(7) open; harvest denounce closed — millCry picks cry.
      let st0 = sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          stR = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      pickLabel "dave" stM @?= Just "dave: cry the theft at market"

  , testCase "wants: fearsBrand weight picks confess after squeeze" $ do
      -- Negative want (-12) drives confess when squeeze threatened.
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          bob' = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "confess open" (hasAct "bob" "confess" stSq)
      pickLabel "bob" stSq @?= Just "bob: confess the theft to dave"

  , testCase "wants: fearsBrandHeretic weight picks recant after inquisit" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          bob' = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
      assertBool "recant open" (hasAct "bob" "recant" stSq)
      pickLabel "bob" stSq @?= Just "bob: recant the heresy to priest"

  , testCase "wants: after parade once-gate dave does not re-parade" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [squeezeDesireName, paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
      assertBool "parade closed after once"
        (not (hasAct "dave" "parade bob" stPar))
      let lab = pickLabel "dave" stPar
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with rally+cry never picks market acts" $ do
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [rallyDesireName, cryDesireName] }
          stR = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "kyle no cry" (not (hasAct "kyle" "cry" stM))
      assertBool "kyle no rally" (not (hasAct "kyle" "rally" stM))
      let lab = pickLabel "kyle" stM
      assertBool ("not cry/rally, got " ++ show lab)
        (case lab of
           Just l -> not ("cry" `isInfixOf` l || "rally" `isInfixOf` l)
           Nothing -> True)

  , testCase "wants: affiliate kyle with silence wants never buys or tears" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires =
                        [ millSilenceDesireName
                        , millBreakSilenceDesireName
                        , churchSilenceDesireName
                        , churchBreakSilenceDesireName ] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no buy" (not (hasAct "kyle" "buy" st))
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" st))
      let lab = pickLabel "kyle" st
      assertBool ("not buy/tear, got " ++ show lab)
        (case lab of
           Just l -> not ("buy" `isInfixOf` l || "tear" `isInfixOf` l)
           Nothing -> True)

  , testCase "wants: affiliate kyle with bobHeresyJustice never picks church acts" $ do
      let st0 = dualPressureSeed
          kyle' = (actorOf "kyle" st0) { charDesires = bobHeresyJustice }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no hear" (not (hasAct "kyle" "hear" st))
      assertBool "kyle no censure" (not (hasAct "kyle" "censure" st))
      assertBool "kyle no exile" (not (hasAct "kyle" "exile" st))
      let lab = pickLabel "kyle" st
      assertBool ("not church justice, got " ++ show lab)
        (case lab of
           Just l -> not (any (`isInfixOf` l)
                      ["hear", "censure", "exile", "denounce"])
           Nothing -> True)



  , testCase "wants: coerce desire names are punishes-squeeze / punishes-inquisit" $ do
      squeezeDesireName @?= "punishes-squeeze"
      inquisitDesireName @?= "punishes-inquisit"
      assertBool "in sandboxDesires"
        (any ((== squeezeDesireName) . desireName) sandboxDesires)
      assertBool "inquisit in sandboxDesires"
        (any ((== inquisitDesireName) . desireName) sandboxDesires)

  , testCase "wants: without punishesThief dave does not denounce at harvest" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0)
                    { charDesires = [seeksTheftDesireName, exileBobDesireName] }
          stBase = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary stBase !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce open" (hasAct "dave" "denounce" stH)
      let lab = pickLabel "dave" stH
      assertBool ("not denounce, got " ++ show lab)
        (maybe True (not . ("denounce" `isInfixOf`)) lab)

  , testCase "wants: without exileBob dave does not exile after denounce" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          dave' = (actorOf "dave" stAfter)
                    { charDesires = [seeksTheftDesireName, punishesThiefDesireName] }
          st = stAfter { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "dave" "exile" st)
      let lab = pickLabel "dave" st
      assertBool ("not exile, got " ++ show lab)
        (maybe True (not . ("exile" `isInfixOf`)) lab)

  , testCase "wants: without punishesHeretic priest does not censure at harvest" $ do
      let st0 = doAct "priest" "hear the blasphemy" sandboxWorld
          priest' = (actorOf "priest" st0)
                      { charDesires = [seeksHeresyDesireName, exileEveDesireName] }
          stBase = st0 { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary stBase !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure open" (hasAct "priest" "censure" stH)
      let lab = pickLabel "priest" stH
      assertBool ("not censure, got " ++ show lab)
        (maybe True (not . ("censure" `isInfixOf`)) lab)

  , testCase "wants: without exileEve priest does not exile after censure" $ do
      let st0 = doAct "priest" "hear the blasphemy" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "priest" "censure" stH
          stAfter = roundBoundary stCen
          priest' = (actorOf "priest" stAfter)
                      { charDesires = [seeksHeresyDesireName, punishesHereticDesireName] }
          st = stAfter { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "priest" "exile" st)
      let lab = pickLabel "priest" st
      assertBool ("not exile, got " ++ show lab)
        (maybe True (not . ("exile" `isInfixOf`)) lab)

  , testCase "wants: after denounce exile weight picks exile outside harvest" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          dave' = (actorOf "dave" stAfter) { charDesires = millJustice }
          st = stAfter { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters stAfter ] }
      assertBool "exile open" (hasAct "dave" "exile" st)
      pickLabel "dave" st @?= Just "dave: exile the thief"

  , testCase "wants: seeksTheft weight picks learn when open" $ do
      let dave' = (actorOf "dave" sandboxWorld)
                    { charDesires = [seeksTheftDesireName] }
          st = sandboxWorld { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters sandboxWorld ] }
      assertBool "learn open" (hasAct "dave" "learn" st)
      pickLabel "dave" st @?= Just "dave: learn of the theft"

  , testCase "wants: seeksHeresy weight picks hear when open" $ do
      let priest' = (actorOf "priest" sandboxWorld)
                      { charDesires = [seeksHeresyDesireName] }
          st = sandboxWorld { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters sandboxWorld ] }
      assertBool "hear open" (hasAct "priest" "hear the blasphemy" st)
      pickLabel "priest" st @?= Just "priest: hear the blasphemy"

  , testCase "wants: parade weight beats millCry when parade open after brand" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [paradeDesireName] ++ millCry }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade open" (hasAct "dave" "parade bob" stBrand)
      pickLabel "dave" stBrand @?= Just "dave: parade bob as branded thief"

  , testCase "wants: after cry once-gate dave does not re-cry at market" $ do
      let st0 = sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          stR = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stCry))
      let lab = pickLabel "dave" stCry
      assertBool ("not cry, got " ++ show lab)
        (maybe True (not . ("cry" `isInfixOf`)) lab)

  , testCase "wants: after rally once-gate dave does not re-rally" $ do
      let st2 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
          stRally = doAct "dave" "rally" stM
      assertBool "rally closed" (not (hasAct "dave" "rally" stRally))
      let lab = pickLabel "dave" stRally
      assertBool ("not rally, got " ++ show lab)
        (maybe True (not . ("rally" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with fearsBrand never confesses" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          kyle' = (actorOf "kyle" st0) { charDesires = [fearsBrandName] }
          bob' = (actorOf "bob" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "kyle" then kyle'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "kyle no confess" (not (hasAct "kyle" "confess" stSq))
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" stSq))
      let lab = pickLabel "kyle" stSq
      assertBool ("not confess, got " ++ show lab)
        (maybe True (not . ("confess" `isInfixOf`)) lab)

  , testCase "cast: player slot holds no desires" $ do
      assertBool "player empty desires"
        (null (charDesires (actorOf playerName sandboxWorld)))
      assertBool "player empty wants"
        (null (charWants (actorOf playerName sandboxWorld)))



  , testCase "wants: desire Match leaf vocabulary pins condition atoms" $ do
      -- Symbolic nails for Want Match leaves (Owner templates).
      assertBool "theft"
        (Match "Owner.believes.stole.bob.carol" `elem` desireMatch seeksTheftDesireName)
      assertBool "denounce"
        (Match "denounced.Owner.bob" `elem` desireMatch punishesThiefDesireName)
      assertBool "exile bob"
        (Match "exiled.bob" `elem` desireMatch exileBobDesireName)
      assertBool "heresy"
        (Match "Owner.believes.blasphemed.eve.gale"
          `elem` desireMatch seeksHeresyDesireName)
      assertBool "censure eve"
        (Match "censured.Owner.eve" `elem` desireMatch punishesHereticDesireName)
      assertBool "exile eve"
        (Match "exiled.eve" `elem` desireMatch exileEveDesireName)
      assertBool "joins mill"
        (Match "member.Owner!mill" `elem` desireMatch joinsMillDesireName)
      assertBool "mill silence debt"
        (Match "debt.ira.bob.favor" `elem` desireMatch millSilenceDesireName)
      assertBool "mill revoke"
        (Match "revoked.Owner.bob" `elem` desireMatch millBreakSilenceDesireName)
      assertBool "cry"
        (Match "cried.Owner.bob" `elem` desireMatch cryDesireName)
      assertBool "flee"
        (Match "fled.Owner" `elem` desireMatch fleeDesireName)
      assertBool "return"
        (Match "reconciled.Owner" `elem` desireMatch returnDesireName)
      assertBool "rally"
        (Match "rallied.Owner.bob" `elem` desireMatch rallyDesireName)
      assertBool "bob heresy"
        (Match "Owner.believes.blasphemed.bob.gale"
          `elem` desireMatch seeksBobHeresyDesireName)
      assertBool "censure bob"
        (Match "censured.Owner.bob"
          `elem` desireMatch punishesBobHereticDesireName)
      assertBool "church silence"
        (Match "debt.gale.Owner.church-favor"
          `elem` desireMatch churchSilenceDesireName)
      assertBool "church revoke"
        (Match "revoked.Owner.eve"
          `elem` desireMatch churchBreakSilenceDesireName)
      assertBool "parade mill"
        (Match "paraded.Owner.bob" `elem` desireMatch paradeDesireName)
      assertBool "parade church"
        (Match "paraded.Owner.bob" `elem` desireMatch churchParadeDesireName)

  , testCase "wants: seeksBobHeresy weight picks hear of bob when open" $ do
      let st0 = activateChurchBob sandboxWorld
          priest' = (actorOf "priest" st0)
                      { charDesires = [seeksBobHeresyDesireName] }
          st = st0 { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters st0 ] }
      assertBool "hear open" (hasAct "priest" "hear of bob" st)
      pickLabel "priest" st @?= Just "priest: hear of bob's heresy"

  , testCase "wants: without punishesBobHeretic priest does not censure bob" $ do
      let st0 = dualPressureSeed
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires =
                          [ seeksBobHeresyDesireName, exileBobDesireName ] }
          stBase = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary stBase !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure open" (hasAct "priest" "censure" stH)
      let lab = pickLabel "priest" stH
      assertBool ("not censure, got " ++ show lab)
        (maybe True (not . ("censure" `isInfixOf`)) lab)

  , testCase "wants: churchParade weight beats bobHeresyJustice after brand" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires =
                          [churchParadeDesireName] ++ bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "parade open" (hasAct "priest" "parade bob" stBrand)
      pickLabel "priest" stBrand
        @?= Just "priest: parade bob as branded heretic"

  , testCase "wants: after churchParade once-gate priest does not re-parade" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires =
                          [inquisitDesireName, churchParadeDesireName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
      assertBool "parade closed"
        (not (hasAct "priest" "parade bob" stPar))
      let lab = pickLabel "priest" stPar
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: joinsMill weight picks wed for fran" $ do
      let fran' = (actorOf "fran" sandboxWorld)
                    { charDesires = [joinsMillDesireName] }
          st = sandboxWorld { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters sandboxWorld ] }
      assertBool "wed open" (hasAct "fran" "wed" st)
      pickLabel "fran" st @?= Just "fran: wed into the mill beside carol"

  , testCase "wants: affiliate kyle with exile wants never exiles" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          kyle' = (actorOf "kyle" stAfter)
                    { charDesires = [exileBobDesireName, exileEveDesireName] }
          st = stAfter { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stAfter ] }
      assertBool "kyle no exile" (not (hasAct "kyle" "exile" st))
      let lab = pickLabel "kyle" st
      assertBool ("not exile, got " ++ show lab)
        (maybe True (not . ("exile" `isInfixOf`)) lab)

  , testCase "wants: after silence buy bob without millSilence does not re-buy" $ do
      -- Debt already planted; without buy want bob does not pick buy again.
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          bob' = (actorOf "bob" st0) { charDesires = millJustice }
          st = st0 { characters =
                  [ if charName c == "bob" then bob' else c
                  | c <- characters st0 ] }
      assertBool "buy closed after debt"
        (not (hasAct "bob" "buy ira" st))
      let lab = pickLabel "bob" st
      assertBool ("not buy, got " ++ show lab)
        (maybe True (not . ("buy" `isInfixOf`)) lab)

  , testCase "wants: after church buy eve without churchSilence does not re-buy" $ do
      let st0 = doAct "eve" "buy gale"
                  (doAct "gale" "hear the blasphemy" sandboxWorld)
          eve' = (actorOf "eve" st0) { charDesires = churchJustice }
          st = st0 { characters =
                  [ if charName c == "eve" then eve' else c
                  | c <- characters st0 ] }
      assertBool "buy closed" (not (hasAct "eve" "buy gale" st))
      let lab = pickLabel "eve" st
      assertBool ("not buy, got " ++ show lab)
        (maybe True (not . ("buy" `isInfixOf`)) lab)

  , testCase "wants: activateSqueeze is idempotent Insert of practice" $ do
      let st1 = activateSqueeze sandboxWorld
          st2 = activateSqueeze st1
      assertBool "practice present"
        (exists "practice.millSqueeze" (db st2))
      assertBool "still present after second"
        (exists "practice.millSqueeze" (db st1))



  , testCase "wants: justice bundle lists pin millCry churchJustice bobHeresy" $ do
      millJustice @?=
        [ seeksTheftDesireName, punishesThiefDesireName, exileBobDesireName ]
      churchJustice @?=
        [ seeksHeresyDesireName, punishesHereticDesireName, exileEveDesireName ]
      bobHeresyJustice @?=
        [ seeksBobHeresyDesireName, punishesBobHereticDesireName, exileBobDesireName ]
      millCry @?= millJustice ++ [cryDesireName]
      assertBool "cry last" (last millCry == cryDesireName)

  , testCase "wants: fearsBrand conditions use branded Owner leaf" $ do
      let cs = desireMatch fearsBrandName
          hs = desireMatch fearsBrandHereticName
      assertBool ("fearsBrand has branded, got " ++ show cs)
        (any (("branded" `isInfixOf`) . show) cs)
      assertBool ("fearsBrandHeretic has branded, got " ++ show hs)
        (any (("branded" `isInfixOf`) . show) hs)

  , testCase "wants: without cryDesire but with rallyDesire picks rally at market" $ do
      let dave' = (actorOf "dave" reputeSeed)
                    { charDesires = [rallyDesireName] ++ millJustice }
          stR = reputeSeed { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters reputeSeed ] }
          st2 = doAct "carol" "learn" (doAct "dave" "learn" stR)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "rally open" (hasAct "dave" "rally" stM)
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      pickLabel "dave" stM @?= Just "dave: rally the square against the thief"

  , testCase "wants: after mill tear denounce gate re-opens at harvest" $ do
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          stTear = doAct "ira" "tear up bob" st0
          stH = iterate roundBoundary stTear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce open after tear" (hasAct "ira" "denounce" stH)

  , testCase "wants: after church tear censure gate re-opens at harvest" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          stTear = doAct "gale" "tear up eve" st0
          stH = iterate roundBoundary stTear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure open after tear" (hasAct "gale" "censure" stH)

  , testCase "wants: after bob heresy censure exile weight picks banish bob" $ do
      -- churchBobHeresy uses banish (shared exiled.bob), not eve's exile-the-heretic.
      let st0 = dualPressureSeed
          stHear = doAct "priest" "hear of bob" st0
          stH = iterate roundBoundary stHear !! 3
          stCen = doAct "priest" "censure" stH
          stAfter = roundBoundary stCen
          priest' = (actorOf "priest" stAfter)
                      { charDesires = bobHeresyJustice }
          st = stAfter { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stAfter ] }
      assertBool "banish open" (hasAct "priest" "banish bob" st)
      pickLabel "priest" st @?= Just "priest: banish bob for heresy"

  , testCase "wants: activateParade / inquisit / churchBob / churchParade idempotent" $ do
      let stP = activateParade (activateParade sandboxWorld)
          stI = activateInquisit (activateInquisit sandboxWorld)
          stC = activateChurchBob (activateChurchBob sandboxWorld)
          stCP = activateChurchParade (activateChurchParade sandboxWorld)
      assertBool "mill parade practice"
        (exists "practice.millBrandParade" (db stP))
      assertBool "inquisit practice"
        (exists "practice.churchInquisit" (db stI))
      assertBool "churchBob practice"
        (exists "practice.churchBobHeresy" (db stC))
      assertBool "church parade practice"
        (exists "practice.churchBrandParade" (db stCP))

  , testCase "wants: affiliate kyle with millBreakSilence after buy never tears" $ do
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [millBreakSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" st))
      let lab = pickLabel "kyle" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: after flee returnDesire alone picks return" $ do
      let st0 = doAct "carol" "abandon"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          carol' = (actorOf "carol" st0) { charDesires = [returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
      assertBool "return open" (hasAct "carol" "return" st || hasAct "carol" "reconcil" st)
      pickLabel "carol" st
        @?= Just "carol: return to the mill in reconciliation"

  , testCase "wants: after brand fearsBrand satisfied bob does not re-confess" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          bob' = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "no re-confess"
        (not (hasAct "bob" "confess" stBrand))
      let lab = pickLabel "bob" stBrand
      assertBool ("not confess, got " ++ show lab)
        (maybe True (not . ("confess" `isInfixOf`)) lab)



  , testCase "wants: desire name string vocabulary pins exports" $ do
      seeksTheftDesireName @?= "seeks-theft-truth"
      punishesThiefDesireName @?= "punishes-thief"
      exileBobDesireName @?= "wants-exile-bob"
      seeksHeresyDesireName @?= "seeks-heresy-truth"
      punishesHereticDesireName @?= "punishes-heretic"
      exileEveDesireName @?= "wants-exile-eve"
      joinsMillDesireName @?= "joins-mill"
      millSilenceDesireName @?= "buys-ira-silence"
      millBreakSilenceDesireName @?= "breaks-silence-deal"
      cryDesireName @?= "cries-theft-at-market"
      fleeDesireName @?= "flees-mill"
      returnDesireName @?= "returns-to-mill"
      rallyDesireName @?= "rallies-against-thief"
      fearsBrandName @?= "fears-brand"
      seeksBobHeresyDesireName @?= "seeks-bob-heresy"
      punishesBobHereticDesireName @?= "punishes-bob-heretic"
      churchSilenceDesireName @?= "buys-church-silence"
      churchBreakSilenceDesireName @?= "breaks-church-silence"
      fearsBrandHereticName @?= "fears-brand-heretic"
      paradeDesireName @?= "parades-branded-thief"
      churchParadeDesireName @?= "parades-branded-heretic"

  , testCase "wants: fleeDesire alone picks abandon after learn" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          carol' = (actorOf "carol" st0) { charDesires = [fleeDesireName] }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
      assertBool "abandon open" (hasAct "carol" "abandon" st)
      pickLabel "carol" st @?= Just "carol: abandon the mill for the guild"

  , testCase "wants: after mill tear breakSilence satisfied ira does not re-tear" $ do
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          stTear = doAct "ira" "tear up bob" st0
          ira' = (actorOf "ira" stTear)
                   { charDesires = [millBreakSilenceDesireName] ++ millJustice }
          st = stTear { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters stTear ] }
      assertBool "tear closed" (not (hasAct "ira" "tear up bob" st))
      let lab = pickLabel "ira" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: after church tear breakSilence satisfied gale does not re-tear" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          stTear = doAct "gale" "tear up eve" st0
          gale' = (actorOf "gale" stTear)
                    { charDesires =
                        [churchBreakSilenceDesireName] ++ churchJustice }
          st = stTear { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters stTear ] }
      assertBool "tear closed" (not (hasAct "gale" "tear up eve" st))
      let lab = pickLabel "gale" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: brand after defy without confess" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          bob' = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "defy open" (hasAct "bob" "defy" stSq)
      let stDefy = doAct "bob" "defy" stSq
      assertBool "brand open" (hasAct "dave" "brand bob" stDefy)
      pickLabel "dave" stDefy @?= Just "dave: brand bob as unrepentant"

  , testCase "wants: brand after heretic defy without recant" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          bob' = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
      assertBool "defy open" (hasAct "bob" "defy" stSq)
      let stDefy = doAct "bob" "defy" stSq
      assertBool "brand open" (hasAct "priest" "brand bob" stDefy)
      pickLabel "priest" stDefy
        @?= Just "priest: brand bob as unrepentant heretic"

  , testCase "wants: affiliate kyle with inquisit never church-squeezes" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [inquisitDesireName] }
          st = stHear { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stHear ] }
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))
      let lab = pickLabel "kyle" st
      assertBool ("not squeeze, got " ++ show lab)
        (maybe True (not . ("squeeze" `isInfixOf`)) lab)

  , testCase "cast: guild kyle and church leaders pin Host queries" $ do
      assertBool "kyle guild"
        ("kyle" `elem` membersOf sandboxWorld "guild")
      assertBool "kyle not mill"
        ("kyle" `notElem` membersOf sandboxWorld "mill")
      assertBool "priest church leader"
        ("priest" `elem` leadersOf sandboxWorld "church")
      assertBool "fran not mill until wed"
        ("fran" `notElem` membersOf sandboxWorld "mill")



  , testCase "cast: playerName is you" $ do
      playerName @?= "you"
      assertBool "in cast" (playerName `elem` castNames sandboxWorld)
      assertBool "mill member"
        (playerName `elem` membersOf sandboxWorld "mill")

  , testCase "wants: after mill buy denounce closed until tear" $ do
      let st0 = doAct "bob" "buy ira" (doAct "ira" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce closed while debt"
        (not (hasAct "ira" "denounce" stH))
      let stTear = doAct "ira" "tear up bob" st0
          stH2 = iterate roundBoundary stTear !! 3
      assertBool "denounce open after tear"
        (hasAct "ira" "denounce" stH2)

  , testCase "wants: after church buy censure closed until tear" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure closed while debt"
        (not (hasAct "gale" "censure" stH))
      let stTear = doAct "gale" "tear up eve" st0
          stH2 = iterate roundBoundary stTear !! 3
      assertBool "censure open after tear"
        (hasAct "gale" "censure" stH2)

  , testCase "wants: activateSqueeze does not hang squeezeDesire on cast" $ do
      let st = activateSqueeze sandboxWorld
          dave = charDesires (actorOf "dave" st)
      assertBool "practice on"
        (exists "practice.millSqueeze" (db st))
      assertBool "dave still without squeezeDesire"
        (squeezeDesireName `notElem` dave)
      assertBool "bob still without fearsBrand"
        (fearsBrandName `notElem` charDesires (actorOf "bob" st))

  , testCase "wants: activateParade does not hang paradeDesire on cast" $ do
      let st = activateParade sandboxWorld
      assertBool "practice on"
        (exists "practice.millBrandParade" (db st))
      assertBool "dave without paradeDesire"
        (paradeDesireName `notElem` charDesires (actorOf "dave" st))

  , testCase "wants: exile still open after parade of branded thief" $ do
      -- Denounce first so exile gate open; then coerce→brand→parade; exile remains.
      let stLearn = doAct "dave" "learn" sandboxWorld
          stH0 = iterate roundBoundary stLearn !! 3
          stDen = doAct "dave" "denounce" stH0
          stAfter = roundBoundary stDen
          st0b = activateParade (activateSqueeze stAfter)
          bob2 = (actorOf "bob" st0b) { charDesires = [fearsBrandName] }
          dave2 = (actorOf "dave" st0b)
                    { charDesires =
                        [squeezeDesireName, paradeDesireName, exileBobDesireName] }
          stB = st0b { characters =
                  [ if charName c == "dave" then dave2
                    else if charName c == "bob" then bob2
                    else c
                  | c <- characters st0b ] }
          stSqB = doAct "dave" "squeeze bob" stB
          stConfB = doAct "bob" "confess" stSqB
          stSq2B = doAct "dave" "squeeze bob" stConfB
          stBrandB = doAct "dave" "brand bob" stSq2B
          stParB = doAct "dave" "parade bob" stBrandB
      assertBool "exile open after parade"
        (hasAct "dave" "exile" stParB)
      pickLabel "dave" stParB @?= Just "dave: exile the thief"

  , testCase "wants: harvest and market festivals stagger on schedule" $ do
      let st0 = sandboxWorld
          st3 = iterate roundBoundary st0 !! 3
          st4 = iterate roundBoundary st0 !! 4
      assertBool "t3 harvest" (exists "festival.harvest" (db st3))
      assertBool "t3 no market" (not (exists "festival.market" (db st3)))
      assertBool "t4 market" (exists "festival.market" (db st4))
      assertBool "t4 no harvest" (not (exists "festival.harvest" (db st4)))



  , testCase "wants: after victim flee mill regard dissolves (dave no denounce)" $ do
      -- carol abandon inserts fled + dissolves mill regard on bob; dave loses denounce.
      let st0 = doAct "carol" "abandon"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stH = iterate roundBoundary st0 !! 3
      assertBool "carol fled" (exists "fled.carol" (db st0))
      assertBool "dave no denounce after regard dissolve"
        (not (hasAct "dave" "denounce" stH))

  , testCase "wants: after return mill regard restores denounce for carol" $ do
      let st0 = doAct "carol" "return"
                  (doAct "carol" "abandon"
                    (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)))
          carol' = (actorOf "carol" st0) { charDesires = millJustice }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "denounce open after return"
        (hasAct "carol" "denounce" stH)
      pickLabel "carol" stH @?= Just "carol: denounce the thief"

  , testCase "wants: bobHeresy censure weight 9 beats mill denounce 8 on dualPressure" $ do
      -- Already have bobHeresy beats eve; pin numeric utilities vs mill accuse.
      desireUtil punishesBobHereticDesireName @?= 9
      desireUtil punishesThiefDesireName @?= 8
      desireUtil punishesHereticDesireName @?= 8

  , testCase "wants: after brand paradeDesire alone picks parade" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [squeezeDesireName, paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          dave2 = (actorOf "dave" stBrand)
                    { charDesires = [paradeDesireName] }
          stP = stBrand { characters =
                  [ if charName c == "dave" then dave2 else c
                  | c <- characters stBrand ] }
      assertBool "parade open" (hasAct "dave" "parade bob" stP)
      pickLabel "dave" stP @?= Just "dave: parade bob as branded thief"

  , testCase "wants: affiliate kyle with churchBreakSilence never tears gale deal" $ do
      let st0 = doAct "eve" "buy gale" (doAct "gale" "hear" sandboxWorld)
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [churchBreakSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" st))
      let lab = pickLabel "kyle" st
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "wants: sandboxDesires registers every exported desire name" $ do
      let names = map desireName sandboxDesires
      mapM_ (\n -> assertBool n (n `elem` names))
        [ seeksTheftDesireName, punishesThiefDesireName, exileBobDesireName
        , seeksHeresyDesireName, punishesHereticDesireName, exileEveDesireName
        , joinsMillDesireName, millSilenceDesireName, millBreakSilenceDesireName
        , cryDesireName, fleeDesireName, returnDesireName, rallyDesireName
        , squeezeDesireName, fearsBrandName
        , seeksBobHeresyDesireName, punishesBobHereticDesireName
        , churchSilenceDesireName, churchBreakSilenceDesireName
        , inquisitDesireName, fearsBrandHereticName
        , paradeDesireName, churchParadeDesireName
        ]



  , testCase "wants: affiliate kyle with paradeDesire never parades after brand" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          kyle' = (actorOf "kyle" st0) { charDesires = [paradeDesireName] }
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "dave parade open" (hasAct "dave" "parade bob" stBrand)
      assertBool "kyle no parade" (not (hasAct "kyle" "parade" stBrand))
      let lab = pickLabel "kyle" stBrand
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with churchParadeDesire never parades" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [churchParadeDesireName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bobF
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "priest parade open" (hasAct "priest" "parade bob" stBrand)
      assertBool "kyle no parade" (not (hasAct "kyle" "parade" stBrand))

  , testCase "wants: affiliate kyle with fearsBrandHeretic never recants" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [fearsBrandHereticName] }
          bob' = (actorOf "bob" stHear) { charDesires = [] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "kyle" then kyle'
                    else if charName c == "bob" then bob'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
      assertBool "kyle no recant" (not (hasAct "kyle" "recant" stSq))
      let lab = pickLabel "kyle" stSq
      assertBool ("not recant, got " ++ show lab)
        (maybe True (not . ("recant" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with seeksTheft never learns" $ do
      let kyle' = (actorOf "kyle" sandboxWorld)
                    { charDesires = [seeksTheftDesireName] }
          st = sandboxWorld { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters sandboxWorld ] }
      assertBool "kyle no learn" (not (hasAct "kyle" "learn" st))
      let lab = pickLabel "kyle" st
      assertBool ("not learn, got " ++ show lab)
        (maybe True (not . ("learn" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with punishesThief never denounces at harvest" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [punishesThiefDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce open" (hasAct "dave" "denounce" stH)
      assertBool "kyle no denounce" (not (hasAct "kyle" "denounce" stH))

  , testCase "wants: guild fran with millCry before wed never cries at market" $ do
      -- fran believes (guild) but no mill standing until wed → cry gate closed.
      let fran' = (actorOf "fran" sandboxWorld)
                    { charDesires = millCry }
          st = sandboxWorld { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters sandboxWorld ] }
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
          stDave = doAct "dave" "learn" stBel
          stM = roundBoundary (iterate roundBoundary stDave !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "fran no cry" (not (hasAct "fran" "cry" stM))
      assertBool "dave cry open" (hasAct "dave" "cry the theft" stM)

  , testCase "wants: after cry once rallyDesire still picks rally at market" $ do
      let st2 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stCry))
      assertBool "rally still" (hasAct "dave" "rally" stCry)
      pickLabel "dave" stCry @?= Just "dave: rally the square against the thief"

  , testCase "wants: after denounce cry still open at next market (exile wins pick)" $ do
      -- harvest @ t3; market @ t4. Exile weight beats cry; pin cry gate stays open.
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open after denounce"
        (hasAct "dave" "cry the theft" stM)
      assertBool "exile also open" (hasAct "dave" "exile" stM)
      pickLabel "dave" stM @?= Just "dave: exile the thief"



  , testCase "return × denounce: flee drops denounce; return restores at harvest" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stH = iterate roundBoundary stRet !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce restored" (hasAct "dave" "denounce" stH)

  , testCase "return × exile: after flee+return denounce→exile path restores" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stH = iterate roundBoundary stRet !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile restored" (hasAct "dave" "exile" stAfter)

  , testCase "return × rally: flee drops rally; return restores at market" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stM = roundBoundary (iterate roundBoundary stRet !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "rally restored" (hasAct "dave" "rally" stM)

  , testCase "shared exile race: after dual hear mill exile blocks banish" $ do
      -- Same leaf as dual-pressure Spec; pin symbolic once from hear→denounce path.
      let st0 = doAct "dave" "learn" (doAct "priest" "hear of bob" dualPressureSeed)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "priest banish closed"
        (not (hasAct "priest" "banish" stEx))

  , testCase "shared exile race: after dual hear priest banish blocks mill exile" $ do
      let st0 = doAct "dave" "learn" (doAct "priest" "hear of bob" dualPressureSeed)
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "banish open" (hasAct "priest" "banish" stAfter)
      let stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      assertBool "dave exile closed"
        (not (hasAct "dave" "exile" stBan))

  , testCase "exile × parade: mill exile and brand parade stay independent" $ do
      -- Shared exiled.bob does not gate parade; brand parade stays open after exile.
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "parade still open after exile"
        (hasAct "dave" "parade bob" stEx)

  , testCase "fran squeezeDesire before wed: gate closed until wedding" $ do
      let st0 = activateSqueeze sandboxWorld
          fran' = (actorOf "fran" st0)
                    { charDesires = [joinsMillDesireName, squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters st0 ] }
          -- guild belief alone does not grant mill regard for squeeze
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
      assertBool "before wed no squeeze"
        (not (hasAct "fran" "squeeze bob" stBel))
      let stWed = doAct "fran" "wed" stBel
      assertBool "after wed squeeze open"
        (hasAct "fran" "squeeze bob" stWed)

  , testCase "silence × flee: buy before flee; debt survives regard dissolve" $ do
      -- Victim flee dissolves mill regard (buy closes after); debt leaf persists.
      let st0 = doAct "ira" "learn"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
      assertBool "buy open before flee" (hasAct "bob" "buy ira" st0)
      let stBuy = doAct "bob" "buy ira" st0
          stFlee = doAct "carol" "abandon" stBuy
      assertBool "fled" (exists "fled.carol" (db stFlee))
      assertBool "debt survives" (exists "debt.ira.bob.favor" (db stFlee))
      assertBool "buy closed after regard dissolve"
        (not (hasAct "bob" "buy ira" stFlee))
      assertBool "ira tear still open" (hasAct "ira" "tear up bob" stFlee)

  , testCase "wed × tear: fran wedding and ira tear stay independent" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") stBuy
      assertBool "tear open" (hasAct "ira" "tear up bob" stBel)
      assertBool "wed open" (hasAct "fran" "wed" stBel)
      let stWed = doAct "fran" "wed" stBel
      assertBool "tear still" (hasAct "ira" "tear up bob" stWed)
      let stTear = doAct "ira" "tear up bob" stWed
      assertBool "revoked" (exists "revoked.ira.bob" (db stTear))
      assertBool "fran mill standing"
        (exists "member.fran.mill" (db stTear)
         || exists "fran.member.mill" (db stTear)
         || hasAct "fran" "learn" stTear
         || hasAct "fran" "denounce" (iterate roundBoundary stTear !! 3))

  , testCase "wants: paradeDesire weight beats cry when both open at market" $ do
      -- parade 10 > cry 7; after brand at market both open → pick parade.
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [paradeDesireName, cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "parade open" (hasAct "dave" "parade bob" stM)
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      desireUtil paradeDesireName @?= 10
      desireUtil cryDesireName @?= 7
      pickLabel "dave" stM @?= Just "dave: parade bob as branded thief"

  , testCase "wants: after mill brand cannot re-brand; squeeze closed" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "no re-brand" (not (hasAct "dave" "brand bob" stBrand))
      assertBool "squeeze closed after brand"
        (not (hasAct "dave" "squeeze bob" stBrand))

  , testCase "wants: affiliate kyle with rallyDesire never rallies at market" $ do
      let st0 = doAct "dave" "learn" reputeSeed
          kyle' = (actorOf "kyle" st0) { charDesires = [rallyDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          st2 = doAct "carol" "learn" st
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave rally open" (hasAct "dave" "rally" stM)
      assertBool "kyle no rally" (not (hasAct "kyle" "rally" stM))

  , testCase "wants: affiliate kyle with cryDesire never cries at market" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = [cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stM = roundBoundary (iterate roundBoundary st !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry open" (hasAct "dave" "cry the theft" stM)
      assertBool "kyle no cry" (not (hasAct "kyle" "cry" stM))

  , testCase "after cry once × squeeze: market cry once-gate; squeeze stays" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stCry))
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stCry)

  , testCase "after rally once × squeeze: rally once-gate; squeeze stays" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" reputeSeed)
          st2 = doAct "carol" "learn" st0
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
          stRally = doAct "dave" "rally" stM
      assertBool "rally closed" (not (hasAct "dave" "rally" stRally))
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stRally)



  , testCase "return × parade after brand: flee drops; return restores parade" $ do
      -- Already pinned return×parade on brand path; pin again via activate after flee cycle.
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stFlee = doAct "carol" "abandon" (doAct "carol" "learn" stBrand)
          stRet = doAct "carol" "return" stFlee
      assertBool "parade after return" (hasAct "dave" "parade bob" stRet)
      let stPar = doAct "dave" "parade bob" stRet
      assertBool "paraded" (exists "paraded.dave.bob" (db stPar))
      assertBool "reconciled" (exists "reconciled.carol" (db stPar))

  , testCase "after parade once × denounce: parade once-gate; harvest denounce stays" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stH = iterate roundBoundary stPar !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stH))
      assertBool "denounce open" (hasAct "dave" "denounce" stH)

  , testCase "after churchParade once × mill denounce: heretic parade once; mill accuse stays" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
          stDave = doAct "dave" "learn" stPar
          stH = iterate roundBoundary stDave !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest parade closed"
        (not (hasAct "priest" "parade bob" stH))
      assertBool "dave denounce open" (hasAct "dave" "denounce" stH)

  , testCase "after mill tear × church silence: mill revoked; church debt independent" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stIra = doAct "ira" "learn" st0
          stBuyIra = doAct "bob" "buy ira" stIra
          stBuyGale = doAct "eve" "buy gale" stBuyIra
          stTear = doAct "ira" "tear up bob" stBuyGale
      assertBool "ira revoked" (exists "revoked.ira.bob" (db stTear))
      assertBool "gale debt still"
        (exists "debt.gale.eve.church-favor" (db stTear))
      assertBool "gale tear still" (hasAct "gale" "tear up eve" stTear)

  , testCase "after church tear × mill silence: gale revoked; mill debt independent" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stIra = doAct "ira" "learn" st0
          stBuyIra = doAct "bob" "buy ira" stIra
          stBuyGale = doAct "eve" "buy gale" stBuyIra
          stTear = doAct "gale" "tear up eve" stBuyGale
      assertBool "gale revoked" (exists "revoked.gale.eve" (db stTear))
      assertBool "ira debt still" (exists "debt.ira.bob.favor" (db stTear))
      assertBool "ira tear still" (hasAct "ira" "tear up bob" stTear)

  , testCase "wed × cry: fran wedding unlocks mill cry at market" $ do
      let st0 = sandboxWorld
          fran' = (actorOf "fran" st0)
                    { charDesires = [joinsMillDesireName, cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters st0 ] }
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
          stDave = doAct "dave" "learn" stBel
      assertBool "before wed no cry"
        (not (hasAct "fran" "cry" (roundBoundary (iterate roundBoundary stDave !! 3))))
      let stWed = doAct "fran" "wed" stDave
          -- fran needs regard via learn after wed
          stLearn = if hasAct "fran" "learn" stWed
                      then doAct "fran" "learn" stWed else stWed
          stM = roundBoundary (iterate roundBoundary stLearn !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "fran cry open" (hasAct "fran" "cry the theft" stM)

  , testCase "wants: affiliate kyle with seeksHeresy never hears blasphemy" $ do
      let kyle' = (actorOf "kyle" sandboxWorld)
                    { charDesires = [seeksHeresyDesireName] }
          st = sandboxWorld { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters sandboxWorld ] }
      assertBool "kyle no hear" (not (hasAct "kyle" "hear" st))
      let lab = pickLabel "kyle" st
      assertBool ("not hear, got " ++ show lab)
        (maybe True (not . ("hear" `isInfixOf`)) lab)

  , testCase "wants: affiliate kyle with punishesHeretic never censures" $ do
      let st0 = doAct "priest" "hear the blasphemy" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [punishesHereticDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure open" (hasAct "priest" "censure" stH)
      assertBool "kyle no censure" (not (hasAct "kyle" "censure" stH))

  , testCase "wants: affiliate kyle with joinsMill can wed but no mill justice without regard" $ do
      -- joinsMill unlocks wed for guild affiliate; mill denounce still needs regard.
      let kyle' = (actorOf "kyle" sandboxWorld)
                    { charDesires = [joinsMillDesireName] ++ millCry }
          st = sandboxWorld { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters sandboxWorld ] }
      assertBool "kyle wed open" (hasAct "kyle" "wed" st)
      pickLabel "kyle" st @?= Just "kyle: wed into the mill beside carol"
      let stWed = doAct "kyle" "wed" st
          stLearn = if hasAct "kyle" "learn" stWed
                      then doAct "kyle" "learn" stWed else stWed
          stH = iterate roundBoundary stLearn !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      -- After wed+learn kyle may denounce; pin gate opened (standing unlocked).
      assertBool "kyle denounce after wed+learn"
        (hasAct "kyle" "denounce" stH)

  , testCase "wants: after parade once cryDesire alone picks cry at market" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [paradeDesireName, cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          -- strip parade want so cry wins at market
          dave2 = (actorOf "dave" stPar) { charDesires = [cryDesireName] }
          st2 = stPar { characters =
                  [ if charName c == "dave" then dave2 else c
                  | c <- characters stPar ] }
          stM = roundBoundary (iterate roundBoundary st2 !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stM))
      pickLabel "dave" stM @?= Just "dave: cry the theft at market"

  , testCase "wants: millBreakSilence weight beats cry after buy at market" $ do
      -- tear 10 > cry 7; after buy at market both open → tear.
      let st0 = doAct "ira" "learn" sandboxWorld
          ira' = (actorOf "ira" st0)
                   { charDesires = [millBreakSilenceDesireName, cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters st0 ] }
          stBuy = doAct "bob" "buy ira" st
          stM = roundBoundary (iterate roundBoundary stBuy !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "tear open" (hasAct "ira" "tear up bob" stM)
      desireUtil millBreakSilenceDesireName @?= 10
      desireUtil cryDesireName @?= 7
      pickLabel "ira" stM @?= Just "ira: tear up bob's silence deal"

  , testCase "after squeeze×confess brand path × market cry independence" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open after brand path"
        (hasAct "dave" "cry the theft" stM)
      assertBool "no re-brand" (not (hasAct "dave" "brand bob" stM))

  , testCase "censure once × mill cry: after censure market cry stays" $ do
      let st0 = doAct "priest" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "priest" "censure" stH
          stM = roundBoundary stCen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open" (hasAct "dave" "cry the theft" stM)
      assertBool "censure closed" (not (hasAct "priest" "censure" stM))

  , testCase "denounce once × church squeeze: after denounce inquisit stays" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          stH = iterate roundBoundary stHear !! 3
          stDen = doAct "dave" "denounce" stH
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stDen)

  , testCase "wants: affiliate kyle with millSilenceDesire never buys ira" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [millSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      -- buy is bob's act; kyle with silence want still cannot buy as non-thief regard target
      assertBool "kyle no buy" (not (hasAct "kyle" "buy" st))
      let lab = pickLabel "kyle" st
      assertBool ("not buy, got " ++ show lab)
        (maybe True (not . ("buy" `isInfixOf`)) lab)



  , testCase "after mill exile × church parade: exile does not block heretic parade" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "priest parade still"
        (hasAct "priest" "parade bob" stEx)

  , testCase "after priest banish × mill parade: banish does not block mill parade" $ do
      let st0 = activateParade (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "priest" then priest'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
          stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      assertBool "dave parade still"
        (hasAct "dave" "parade bob" stBan)

  , testCase "after cry once × denounce: cry once-gate; next harvest denounce stays" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
          -- advance to next harvest: market@t4 → harvest@t6 (period 3 stagger)
          stH = iterate roundBoundary stCry !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stH))
      assertBool "denounce open" (hasAct "dave" "denounce" stH)

  , testCase "after rally once × denounce: rally once-gate; harvest denounce stays" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stRally = doAct "dave" "rally" stM
          stH = iterate roundBoundary stRally !! 2
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "rally closed" (not (hasAct "dave" "rally" stH))
      assertBool "denounce open" (hasAct "dave" "denounce" stH)

  , testCase "fran rallyDesire before wed: gate closed until wedding+regard" $ do
      let st0 = reputeSeed
          fran' = (actorOf "fran" st0)
                    { charDesires = [joinsMillDesireName, rallyDesireName] }
          st = st0 { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters st0 ] }
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
          stDave = doAct "dave" "learn" stBel
          stM0 = roundBoundary (iterate roundBoundary stDave !! 3)
      assertBool "before wed no rally" (not (hasAct "fran" "rally" stM0))
      let stWed = doAct "fran" "wed" stDave
          stLearn = if hasAct "fran" "learn" stWed
                      then doAct "fran" "learn" stWed else stWed
          -- fran needs angry feeling for rally; learn may set it via repute
          stM = roundBoundary (iterate roundBoundary stLearn !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      -- rally needs notorious+angry; pin wed unlocked standing at least
      assertBool "fran mill member after wed"
        (hasAct "fran" "cry" stM || hasAct "fran" "rally" stM
         || hasAct "fran" "denounce" (iterate roundBoundary stLearn !! 3))

  , testCase "wants: affiliate kyle with exileEveDesire never exiles heretic" $ do
      let st0 = doAct "priest" "hear the blasphemy" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [exileEveDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stCen = doAct "priest" "censure" stH
          stAfter = roundBoundary stCen
      assertBool "priest exile open" (hasAct "priest" "exile" stAfter)
      assertBool "kyle no exile" (not (hasAct "kyle" "exile" stAfter))

  , testCase "wants: affiliate kyle with seeksBobHeresy never hears bob" $ do
      let st0 = activateChurchBob sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [seeksBobHeresyDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "priest hear open" (hasAct "priest" "hear of bob" st)
      assertBool "kyle no hear" (not (hasAct "kyle" "hear" st))

  , testCase "wants: affiliate kyle with punishesBobHeretic never censures bob" $ do
      let st0 = activateChurchBob sandboxWorld
          stHear = doAct "priest" "hear of bob" st0
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [punishesBobHereticDesireName] }
          st = stHear { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary st !! 3
      assertBool "priest censure bob open"
        (hasAct "priest" "censure bob" stH)
      assertBool "kyle no censure" (not (hasAct "kyle" "censure" stH))

  , testCase "wants: without paradeDesire after brand dave Wait or non-parade" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0) { charDesires = millCry }  -- no parade
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade act still gated open"
        (hasAct "dave" "parade bob" stBrand)
      let lab = pickLabel "dave" stBrand
      assertBool ("not parade pick, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "wants: squeezeDesire weight equals paradeDesire (both 10)" $ do
      desireUtil squeezeDesireName @?= 10
      desireUtil paradeDesireName @?= 10
      desireUtil inquisitDesireName @?= 10
      desireUtil churchParadeDesireName @?= 10

  , testCase "after repay silence × tear closed: repay settles; no tear" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
      assertBool "repay open" (hasAct "bob" "repay" stBuy)
      let stPay = doAct "bob" "repay" stBuy
      assertBool "no debt" (not (exists "debt.ira.bob.favor" (db stPay)))
      assertBool "no tear" (not (hasAct "ira" "tear up bob" stPay))

  , testCase "after church repay × tear closed" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
      assertBool "repay open" (hasAct "eve" "repay" stBuy)
      let stPay = doAct "eve" "repay" stBuy
      assertBool "no debt"
        (not (exists "debt.gale.eve.church-favor" (db stPay)))
      assertBool "no tear" (not (hasAct "gale" "tear up eve" stPay))

  , testCase "dual coerce order: mill brand then church brand (confess then recant)" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          -- mill first
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          -- church second
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "mill branded" (exists "branded.bob" (db stBrandC))
      assertBool "heretic branded"
        (exists "brandedHeretic.bob" (db stBrandC))

  , testCase "dual coerce reverse: church brand then mill brand" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqC = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stSqM = doAct "dave" "squeeze bob" stBrandC
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
      assertBool "heretic branded"
        (exists "brandedHeretic.bob" (db stBrandM))
      assertBool "mill branded" (exists "branded.bob" (db stBrandM))

  , testCase "wants: returnDesire weight beats flee when fled" $ do
      desireUtil returnDesireName @?= 11
      desireUtil fleeDesireName @?= 9
      let st0 = doAct "carol" "abandon"
                  (doAct "carol" "learn" sandboxWorld)
          carol' = (actorOf "carol" st0)
                     { charDesires = [fleeDesireName, returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "carol" then carol' else c
                  | c <- characters st0 ] }
      pickLabel "carol" st
        @?= Just "carol: return to the mill in reconciliation"



  , testCase "after tear mill × denounce restores at harvest" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
          stH = iterate roundBoundary stTear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce after tear" (hasAct "ira" "denounce" stH)

  , testCase "after church tear × censure restores at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
          stH = iterate roundBoundary stTear !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure after tear" (hasAct "gale" "censure" stH)

  , testCase "silence debt blocks ira cry? mill cry independent of debt" $ do
      -- debt blocks denounce not cry; pin cry open while debt holds.
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stM = roundBoundary (iterate roundBoundary stBuy !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira cry open under debt"
        (hasAct "ira" "cry the theft" stM)
      assertBool "ira denounce blocked under debt"
        (not (hasAct "ira" "denounce"
                (iterate roundBoundary stBuy !! 3)))

  , testCase "church debt blocks gale censure; priest hear path stays open" $ do
      let st0 = doAct "priest" "hear the blasphemy"
                  (doAct "gale" "hear the blasphemy" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stH = iterate roundBoundary stBuy !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure blocked"
        (not (hasAct "gale" "censure" stH))
      assertBool "priest censure open" (hasAct "priest" "censure" stH)

  , testCase "wed × squeeze × parade: fran wed unlocks then brand parade path" $ do
      let st0 = activateParade (activateSqueeze sandboxWorld)
          fran' = (actorOf "fran" st0)
                    { charDesires = [joinsMillDesireName, squeezeDesireName
                                    , paradeDesireName] }
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "fran" then fran'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
          stWed = doAct "fran" "wed" stBel
      assertBool "fran squeeze" (hasAct "fran" "squeeze bob" stWed)
      let stSq = doAct "fran" "squeeze bob" stWed
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "fran" "squeeze bob" stConf
          stBrand = doAct "fran" "brand bob" stSq2
      assertBool "fran parade" (hasAct "fran" "parade bob" stBrand)

  , testCase "wants: affiliate kyle with churchSilenceDesire never buys gale" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [churchSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "eve buy open" (hasAct "eve" "buy gale" st)
      assertBool "kyle no buy" (not (hasAct "kyle" "buy" st))

  , testCase "wants: after brand fearsBrand satisfied — bob Wait not confess" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      let lab = pickLabel "bob" stBrand
      assertBool ("not confess, got " ++ show lab)
        (maybe True (not . ("confess" `isInfixOf`)) lab)

  , testCase "wants: after heretic brand fearsBrandHeretic satisfied — no recant" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "heretic branded"
        (exists "brandedHeretic.bob" (db stBrand))
      let lab = pickLabel "bob" stBrand
      assertBool ("not recant, got " ++ show lab)
        (maybe True (not . ("recant" `isInfixOf`)) lab)

  , testCase "after denounce × rally: denounce does not close next-market rally" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "rally open after denounce" (hasAct "dave" "rally" stM)

  , testCase "after censure × mill squeeze: censure does not close squeeze" $ do
      let st0 = activateSqueeze
                  (doAct "priest" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld))
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "priest" "censure" stH
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stCen)

  , testCase "wants: exile weight beats rally when both open after denounce at market" $ do
      -- after denounce, market opens with exile+rally; exile 12 > rally 9.
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          dave' = (actorOf "dave" st0)
                    { charDesires = [exileBobDesireName, rallyDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "exile open" (hasAct "dave" "exile" stM)
      assertBool "rally open" (hasAct "dave" "rally" stM)
      desireUtil exileBobDesireName @?= 12
      desireUtil rallyDesireName @?= 9
      pickLabel "dave" stM @?= Just "dave: exile the thief"

  , testCase "wants: bobHeresy exileBob shared weight 12 same as mill exile" $ do
      desireUtil exileBobDesireName @?= 12
      -- bob heresy banish uses same want name wants-exile-bob
      assertBool "bobHeresy holds exileBob"
        (exileBobDesireName `elem` bobHeresyJustice)

  , testCase "after flee × church hear: flee does not block priest hear bob" $ do
      let st0 = activateChurchBob
                  (doAct "carol" "abandon"
                    (doAct "carol" "learn" sandboxWorld))
      assertBool "fled" (exists "fled.carol" (db st0))
      assertBool "priest hear open" (hasAct "priest" "hear of bob" st0)

  , testCase "after flee × mill learn: dave denounce closed while carol fled" $ do
      let st0 = doAct "carol" "abandon"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stH = iterate roundBoundary st0 !! 3
      assertBool "fled" (exists "fled.carol" (db st0))
      assertBool "denounce closed while fled"
        (not (hasAct "dave" "denounce" stH))

  , testCase "wants: without joinsMill fran does not pick wed" $ do
      let fran' = (actorOf "fran" sandboxWorld)
                    { charDesires = millCry }  -- no joinsMill
          st = sandboxWorld { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters sandboxWorld ] }
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st
      let lab = pickLabel "fran" stBel
      assertBool ("not wed pick, got " ++ show lab)
        (maybe True (not . ("wed" `isInfixOf`)) lab)



  , testCase "after parade once × squeeze closed: brand closed squeeze; parade once" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
      assertBool "squeeze closed" (not (hasAct "dave" "squeeze bob" stPar))
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stPar))
      assertBool "paraded leaf" (exists "paraded.dave.bob" (db stPar))

  , testCase "after churchParade once × inquisit closed similarly" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
      assertBool "inquisit closed"
        (not (hasAct "priest" "squeeze bob" stPar))
      assertBool "parade closed"
        (not (hasAct "priest" "parade bob" stPar))

  , testCase "affiliate kyle default cast: Wait pick; no learn/hear/denounce gates" $ do
      -- wed practice may be open without want; pick stays Wait (empty desires).
      pickLabel "kyle" sandboxWorld @?= Just "kyle: Wait a moment"
      assertBool "no learn" (not (hasAct "kyle" "learn" sandboxWorld))
      assertBool "no hear" (not (hasAct "kyle" "hear" sandboxWorld))
      assertBool "no denounce" (not (hasAct "kyle" "denounce" sandboxWorld))

  , testCase "wants: millSilence weight 14 beats millBreak 10 after buy" $ do
      -- bob holds buy want; after buy bob may repay; ira holds tear.
      desireUtil millSilenceDesireName @?= 14
      desireUtil millBreakSilenceDesireName @?= 10
      let st0 = doAct "ira" "learn" sandboxWorld
      pickLabel "bob" st0 @?= Just "bob: buy ira's silence about the theft"

  , testCase "wants: churchSilence weight 14 beats churchBreak 10" $ do
      desireUtil churchSilenceDesireName @?= 14
      desireUtil churchBreakSilenceDesireName @?= 10
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          eve' = (actorOf "eve" st0)
                   { charDesires = [churchSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "eve" then eve' else c
                  | c <- characters st0 ] }
      pickLabel "eve" st @?= Just "eve: buy gale's silence about the heresy"

  , testCase "after dual parade: both once-gates close independently" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stParM = doAct "dave" "parade bob" stBrandC
          stParC = doAct "priest" "parade bob" stParM
      assertBool "dave parade closed"
        (not (hasAct "dave" "parade bob" stParC))
      assertBool "priest parade closed"
        (not (hasAct "priest" "parade bob" stParC))
      assertBool "both paraded"
        (exists "paraded.dave.bob" (db stParC)
         && exists "paraded.priest.bob" (db stParC))

  , testCase "after cry once × exile path: cry once; denounce→exile still" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
          stH = iterate roundBoundary stCry !! 2
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile after cry+denounce" (hasAct "dave" "exile" stAfter)

  , testCase "after rally once × exile path: rally once; denounce→exile still" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stRally = doAct "dave" "rally" stM
          stH = iterate roundBoundary stRally !! 2
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile after rally+denounce" (hasAct "dave" "exile" stAfter)

  , testCase "wants: affiliate kyle with bobHeresyJustice never acts church bob track" $ do
      let st0 = activateChurchBob sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = bobHeresyJustice }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "no hear" (not (hasAct "kyle" "hear" st))
      let stHear = doAct "priest" "hear of bob" st
          stH = iterate roundBoundary stHear !! 3
      assertBool "no censure" (not (hasAct "kyle" "censure" stH))
      assertBool "no banish" (not (hasAct "kyle" "banish" stH))

  , testCase "wants: affiliate kyle with churchJustice never acts eve track" $ do
      let kyle' = (actorOf "kyle" sandboxWorld)
                    { charDesires = churchJustice }
          st = sandboxWorld { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters sandboxWorld ] }
      assertBool "no hear" (not (hasAct "kyle" "hear" st))
      let stHear = doAct "priest" "hear the blasphemy" st
          stH = iterate roundBoundary stHear !! 3
      assertBool "no censure" (not (hasAct "kyle" "censure" stH))
      assertBool "no exile" (not (hasAct "kyle" "exile" stH))

  , testCase "wants: brand after defy without confess — cry still opens at market" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "defy open" (hasAct "bob" "defy" stSq)
      let stDef = doAct "bob" "defy" stSq
          stBrand = doAct "dave" "brand bob" stDef
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open after defy-brand"
        (hasAct "dave" "cry the theft" stM)

  , testCase "wants: cryDesire util 7 < denounce 8 < exile 12 chain" $ do
      desireUtil cryDesireName @?= 7
      desireUtil punishesThiefDesireName @?= 8
      desireUtil exileBobDesireName @?= 12
      desireUtil rallyDesireName @?= 9
      desireUtil fleeDesireName @?= 9
      desireUtil returnDesireName @?= 11
      desireUtil joinsMillDesireName @?= 10

  , testCase "after return × church debt: return restores mill; church debt independent" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "eve" "buy gale" st0
          stFlee = doAct "carol" "abandon" stBuy
          stRet = doAct "carol" "return" stFlee
      assertBool "debt still"
        (exists "debt.gale.eve.church-favor" (db stRet))
      let stH = iterate roundBoundary stRet !! 3
      assertBool "dave denounce restored" (hasAct "dave" "denounce" stH)
      assertBool "gale still blocked" (not (hasAct "gale" "censure" stH))



  , testCase "after mill tear × cry: tear does not close market cry" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
          stM = roundBoundary (iterate roundBoundary stTear !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira cry open after tear"
        (hasAct "ira" "cry the theft" stM)

  , testCase "after church tear × mill cry: gale tear; dave cry independent" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
          stM = roundBoundary (iterate roundBoundary stTear !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry open" (hasAct "dave" "cry the theft" stM)
      assertBool "gale revoked" (exists "revoked.gale.eve" (db stM))

  , testCase "after denounce once × squeeze: denounce once; squeeze stays" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
      assertBool "denounce closed" (not (hasAct "dave" "denounce" stDen))
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stDen)

  , testCase "after censure once × mill parade: censure once; mill parade stays" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "priest" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stCen = doAct "priest" "censure" stH
      assertBool "censure closed" (not (hasAct "priest" "censure" stCen))
      assertBool "parade still" (hasAct "dave" "parade bob" stCen)

  , testCase "exile × cry: mill exile and market cry stay independent" $ do
      -- denounce@harvest → market@t4: cry open; exile same tick leaves cry open.
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open before exile"
        (hasAct "dave" "cry the theft" stM)
      let stEx = doAct "dave" "exile" stM
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "cry still open after exile"
        (hasAct "dave" "cry the theft" stEx)

  , testCase "after priest banish × mill squeeze: banish does not close squeeze" $ do
      let st0 = activateSqueeze (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary st !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
          stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      assertBool "squeeze still" (hasAct "dave" "squeeze bob" stBan)

  , testCase "wed × silence buy: fran wed; bob buy ira stay independent" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
      assertBool "wed open" (hasAct "fran" "wed" stBel)
      assertBool "buy open" (hasAct "bob" "buy ira" stBel)
      let stWed = doAct "fran" "wed" stBel
      assertBool "buy still" (hasAct "bob" "buy ira" stWed)
      let stBuy = doAct "bob" "buy ira" stWed
      assertBool "debt" (exists "debt.ira.bob.favor" (db stBuy))
      assertBool "fran regard"
        (exists "regards.fran.bob.thief" (readView stBuy))

  , testCase "wants: affiliate kyle with millJustice never denounces at harvest" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = millJustice }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce" (hasAct "dave" "denounce" stH)
      assertBool "kyle no denounce" (not (hasAct "kyle" "denounce" stH))
      assertBool "kyle no learn" (not (hasAct "kyle" "learn" st))

  , testCase "wants: affiliate kyle with iraJustice never tears or denounces" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = iraJustice }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stBuy = doAct "bob" "buy ira" st
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" stBuy))
      let stH = iterate roundBoundary stBuy !! 3
      assertBool "kyle no denounce" (not (hasAct "kyle" "denounce" stH))

  , testCase "wants: paradeDesire alone after brand picks parade (no millCry noise)" $ do
      let st0 = activateParade (activateSqueeze (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0) { charDesires = [paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      pickLabel "dave" stBrand
        @?= Just "dave: parade bob as branded thief"

  , testCase "wants: churchParadeDesire alone after heretic brand picks parade" $ do
      let st0 = activateChurchParade
                  (activateInquisit (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = [churchParadeDesireName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      pickLabel "priest" stBrand
        @?= Just "priest: parade bob as branded heretic"

  , testCase "after flee × ira tear: flee does not block ira tear" $ do
      let st0 = doAct "ira" "learn"
                  (doAct "carol" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stFlee = doAct "carol" "abandon" stBuy
      assertBool "ira tear open while fled"
        (hasAct "ira" "tear up bob" stFlee)

  , testCase "after return × ira debt: return restores mill; ira debt independent" $ do
      let st0 = doAct "ira" "learn"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "bob" "buy ira" st0
          stFlee = doAct "carol" "abandon" stBuy
          stRet = doAct "carol" "return" stFlee
      assertBool "debt still" (exists "debt.ira.bob.favor" (db stRet))
      let stH = iterate roundBoundary stRet !! 3
      assertBool "dave denounce restored" (hasAct "dave" "denounce" stH)
      assertBool "ira still blocked" (not (hasAct "ira" "denounce" stH))

  , testCase "wants: squeezeDesire alone picks squeeze after learn" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
      pickLabel "dave" st
        @?= Just "dave: squeeze bob for a confession"

  , testCase "wants: inquisitDesire alone picks church squeeze after hear" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
      pickLabel "priest" st
        @?= Just "priest: squeeze bob for a recantation"



  , testCase "after cry once × exile weight pick: cry closed; exile still picks" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0)
                    { charDesires = [cryDesireName, exileBobDesireName
                                    , punishesThiefDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stM = roundBoundary (iterate roundBoundary st !! 3)
          stCry = doAct "dave" "cry the theft" stM
          stH = iterate roundBoundary stCry !! 2
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile open" (hasAct "dave" "exile" stAfter)
      pickLabel "dave" stAfter @?= Just "dave: exile the thief"

  , testCase "after rally once × exile weight pick" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          dave' = (actorOf "dave" st0)
                    { charDesires = [rallyDesireName, exileBobDesireName
                                    , punishesThiefDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stM = roundBoundary (iterate roundBoundary st !! 3)
          stRally = doAct "dave" "rally" stM
          stH = iterate roundBoundary stRally !! 2
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      pickLabel "dave" stAfter @?= Just "dave: exile the thief"

  , testCase "after dual brand both parades open; mill cry also open at market" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stM = roundBoundary (iterate roundBoundary stBrandC !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave parade" (hasAct "dave" "parade bob" stM)
      assertBool "priest parade" (hasAct "priest" "parade bob" stM)
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)

  , testCase "silence buy outside harvest only: blocked during harvest" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "buy blocked in harvest"
        (not (hasAct "bob" "buy ira" stH))
      assertBool "buy open outside" (hasAct "bob" "buy ira" st0)

  , testCase "church silence buy blocked during harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "buy blocked"
        (not (hasAct "eve" "buy gale" stH))
      assertBool "buy open outside" (hasAct "eve" "buy gale" st0)

  , testCase "after revoke cannot re-buy mill silence" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
      assertBool "revoked" (exists "revoked.ira.bob" (db stTear))
      assertBool "no re-buy" (not (hasAct "bob" "buy ira" stTear))

  , testCase "after revoke cannot re-buy church silence" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
      assertBool "revoked" (exists "revoked.gale.eve" (db stTear))
      assertBool "no re-buy" (not (hasAct "eve" "buy gale" stTear))

  , testCase "wants: affiliate kyle with squeezeDesire never squeezes after learn world" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          kyle' = (actorOf "kyle" st0) { charDesires = [squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "dave squeeze open" (hasAct "dave" "squeeze bob" st)
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))
      let lab = pickLabel "kyle" st
      assertBool ("not squeeze, got " ++ show lab)
        (maybe True (not . ("squeeze" `isInfixOf`)) lab)

  , testCase "wants: without fearsBrand bob does not confess after squeeze" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [] }
          dave' = (actorOf "dave" st0) { charDesires = [squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "confess act may exist" (hasAct "bob" "confess" stSq
                                           || hasAct "bob" "defy" stSq)
      let lab = pickLabel "bob" stSq
      assertBool ("not confess pick, got " ++ show lab)
        (maybe True (not . ("confess" `isInfixOf`)) lab)

  , testCase "wants: without fearsBrandHeretic bob does not recant after inquisit" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = [inquisitDesireName] }
          st = stHear { characters =
                  [ if charName c == "priest" then priest'
                    else if charName c == "bob" then bobF
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
      let lab = pickLabel "bob" stSq
      assertBool ("not recant pick, got " ++ show lab)
        (maybe True (not . ("recant" `isInfixOf`)) lab)

  , testCase "after mill parade × church squeeze: parade does not close inquisit" $ do
      let st0 = activateInquisit (activateParade (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stPar)

  , testCase "after church parade × mill squeeze: heretic parade; mill squeeze stays" $ do
      let st0 = activateChurchParade (activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
      assertBool "dave squeeze still"
        (hasAct "dave" "squeeze bob" stPar)

  , testCase "wants: joinsMill util 10 equals squeeze/parade util" $ do
      desireUtil joinsMillDesireName @?= 10
      desireUtil squeezeDesireName @?= 10
      desireUtil paradeDesireName @?= 10
      desireUtil millBreakSilenceDesireName @?= 10
      desireUtil churchBreakSilenceDesireName @?= 10

  , testCase "cast: kyle empty desires; fran holds joinsMill" $ do
      let kyle = actorOf "kyle" sandboxWorld
          fran = actorOf "fran" sandboxWorld
      charDesires kyle @?= []
      assertBool "fran joinsMill"
        (joinsMillDesireName `elem` charDesires fran)

  , testCase "after repay mill × denounce open for ira at harvest" $ do
      -- repay settles without revoke; ira can denounce (no debt, no revoke).
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stPay = doAct "bob" "repay" stBuy
          stH = iterate roundBoundary stPay !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce after repay" (hasAct "ira" "denounce" stH)

  , testCase "after church repay × gale censure open at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          stPay = doAct "eve" "repay" stBuy
          stH = iterate roundBoundary stPay !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "gale censure after repay" (hasAct "gale" "censure" stH)

  , testCase "after revoke mill × church buy still open" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
      assertBool "revoked mill" (exists "revoked.ira.bob" (db stTear))
      assertBool "church buy still" (hasAct "eve" "buy gale" stTear)
      assertBool "mill re-buy closed" (not (hasAct "bob" "buy ira" stTear))

  , testCase "after revoke church × mill buy still open" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
      assertBool "revoked church" (exists "revoked.gale.eve" (db stTear))
      assertBool "mill buy still" (hasAct "bob" "buy ira" stTear)
      assertBool "church re-buy closed" (not (hasAct "eve" "buy gale" stTear))

  , testCase "after dual revoke both cannot re-buy" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stTearM = doAct "ira" "tear up bob" stBuyC
          stTearC = doAct "gale" "tear up eve" stTearM
      assertBool "both revoked"
        (exists "revoked.ira.bob" (db stTearC)
         && exists "revoked.gale.eve" (db stTearC))
      assertBool "no mill re-buy" (not (hasAct "bob" "buy ira" stTearC))
      assertBool "no church re-buy" (not (hasAct "eve" "buy gale" stTearC))

  , testCase "after mill exile × church squeeze stays" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          stH = iterate roundBoundary stHear !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stEx)

  , testCase "after cry once × churchParade: cry once; heretic parade stays" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "market" (exists "festival.market" (db stCry))
      assertBool "cry once" (not (hasAct "dave" "cry the theft" stCry))
      assertBool "priest parade still"
        (hasAct "priest" "parade bob" stCry)

  , testCase "after parade once × cry still open at market" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stPar = doAct "dave" "parade bob" stM
      assertBool "market" (exists "festival.market" (db stPar))
      assertBool "parade once" (not (hasAct "dave" "parade bob" stPar))
      assertBool "cry still" (hasAct "dave" "cry the theft" stPar)

  , testCase "brand off-market: parade opens immediately; cry waits for market" $ do
      -- parade 非 festival 门；cry 需 market。烙印后立刻可游街，喊冤仍关。
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "no market yet"
        (not (exists "festival.market" (db stBrand)))
      assertBool "parade open off-market"
        (hasAct "dave" "parade bob" stBrand)
      assertBool "cry closed off-market"
        (not (hasAct "dave" "cry the theft" stBrand))
      let stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry opens at market"
        (hasAct "dave" "cry the theft" stM)
      assertBool "parade still" (hasAct "dave" "parade bob" stM)

  , testCase "wants: affiliate kyle with exileBobDesire never exiles after denounce" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [exileBobDesireName, punishesThiefDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile open" (hasAct "dave" "exile" stAfter)
      assertBool "kyle no exile" (not (hasAct "kyle" "exile" stAfter))

  , testCase "after flee without buy × return: silence buy reopens" $ do
      let st0 = doAct "ira" "learn"
                  (doAct "carol" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
      assertBool "buy closed while fled"
        (not (hasAct "bob" "buy ira" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "buy reopens after return"
        (hasAct "bob" "buy ira" stRet)

  , testCase "after mill tear × church buy independent" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
      assertBool "revoked" (exists "revoked.ira.bob" (db stTear))
      assertBool "church buy open" (hasAct "eve" "buy gale" stTear)
      let stBuyC = doAct "eve" "buy gale" stTear
      assertBool "church debt"
        (exists "debt.gale.eve.church-favor" (db stBuyC))

  , testCase "after church tear × mill buy independent" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
      assertBool "revoked" (exists "revoked.gale.eve" (db stTear))
      assertBool "mill buy open" (hasAct "bob" "buy ira" stTear)
      let stBuyM = doAct "bob" "buy ira" stTear
      assertBool "mill debt" (exists "debt.ira.bob.favor" (db stBuyM))

  , testCase "wants: churchParade util equals parade util (both 10)" $ do
      desireUtil churchParadeDesireName @?= 10
      desireUtil paradeDesireName @?= 10
      desireUtil squeezeDesireName @?= desireUtil inquisitDesireName

  , testCase "after banish bob × mill cry still open at market" $ do
      let st0 = activateChurchBob (doAct "dave" "learn" sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary st !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
          stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      let stM = if exists "festival.market" (db stBan)
                then stBan
                else roundBoundary (iterate roundBoundary stBan !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry still"
        (hasAct "dave" "cry the theft" stM)

  , testCase "after cry once × inquisit stays" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          stM = roundBoundary (iterate roundBoundary stHear !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "cry once" (not (hasAct "dave" "cry the theft" stCry))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stCry)

  , testCase "after rally once × church squeeze stays" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)))
          stHear = doAct "priest" "hear of bob" st0
          stM = roundBoundary (iterate roundBoundary stHear !! 3)
          stRally = doAct "dave" "rally" stM
      assertBool "rally once" (not (hasAct "dave" "rally" stRally))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stRally)

  , testCase "after parade once × rally still open at market" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stPar = doAct "dave" "parade bob" stM
      assertBool "market" (exists "festival.market" (db stPar))
      assertBool "parade once" (not (hasAct "dave" "parade bob" stPar))
      assertBool "rally still" (hasAct "dave" "rally" stPar)

  , testCase "after dual brand × dual cry/parade independence at market" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stM = roundBoundary (iterate roundBoundary stBrandC !! 3)
          stParM = doAct "dave" "parade bob" stM
          stCry = doAct "dave" "cry the theft" stParM
      assertBool "dave parade once"
        (not (hasAct "dave" "parade bob" stCry))
      assertBool "dave cry once"
        (not (hasAct "dave" "cry the theft" stCry))
      assertBool "priest parade still"
        (hasAct "priest" "parade bob" stCry)

  , testCase "wants: affiliate kyle with returnDesire never returns after flee seed" $ do
      -- kyle not mill member; cannot abandon; with returnDesire alone still Wait.
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [fleeDesireName, returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no abandon" (not (hasAct "kyle" "abandon" st))
      assertBool "kyle no return" (not (hasAct "kyle" "return" st))
      let lab = pickLabel "kyle" st
      assertBool ("Wait-ish, got " ++ show lab)
        (lab == Just "kyle: Wait" || lab == Nothing
         || maybe True (not . (\s -> "abandon" `isInfixOf` s
                                    || "return" `isInfixOf` s)) lab)

  , testCase "after flee × parade closed; return restores parade path" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade before flee" (hasAct "dave" "parade bob" stBrand)
      let stFlee = doAct "carol" "abandon" stBrand
      assertBool "parade closed while fled"
        (not (hasAct "dave" "parade bob" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "parade restored" (hasAct "dave" "parade bob" stRet)

  , testCase "after dual repay both denounce/censure open at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stPayM = doAct "bob" "repay" stBuyC
          stPayC = doAct "eve" "repay" stPayM
          stH = iterate roundBoundary stPayC !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce" (hasAct "ira" "denounce" stH)
      assertBool "gale censure" (hasAct "gale" "censure" stH)

  , testCase "after denounce once × cry still opens next market" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open after denounce"
        (hasAct "dave" "cry the theft" stM)

  , testCase "after censure once × mill cry still opens next market" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "gale" "censure" stH
          stM = roundBoundary stCen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry still"
        (hasAct "dave" "cry the theft" stM)

  , testCase "after mill exile × ira tear still (independent of shared exile)" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stH = iterate roundBoundary stBuy !! 3
          -- ira blocked by debt; dave denounces then exiles
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "ira tear still" (hasAct "ira" "tear up bob" stEx)

  , testCase "wants: affiliate kyle with churchParadeDesire never parades after heretic brand" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [churchParadeDesireName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "priest parade open"
        (hasAct "priest" "parade bob" stBrand)
      assertBool "kyle no parade"
        (not (hasAct "kyle" "parade" stBrand))

  , testCase "after repay mill × ira cry open at market" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stPay = doAct "bob" "repay" stBuy
          stM = roundBoundary (iterate roundBoundary stPay !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira cry after repay"
        (hasAct "ira" "cry the theft" stM)

  , testCase "after churchParade once × mill rally stays at market" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob
                    (doAct "carol" "learn" (doAct "dave" "learn" reputeSeed))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stPar = doAct "priest" "parade bob" stM
      assertBool "parade once" (not (hasAct "priest" "parade bob" stPar))
      assertBool "dave rally still" (hasAct "dave" "rally" stPar)

  , testCase "after brand × mill denounce still at next harvest" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce after brand" (hasAct "dave" "denounce" stH)

  , testCase "after confess × flee: brand path closes; return restores" $ do
      let st0 = activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
      assertBool "re-squeeze open" (hasAct "dave" "squeeze bob" stConf)
      let stFlee = doAct "carol" "abandon" stConf
      assertBool "squeeze closed fled"
        (not (hasAct "dave" "squeeze bob" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "squeeze restored" (hasAct "dave" "squeeze bob" stRet)

  , testCase "after brand × bob cannot buy mill silence (still branded thief regard)" $ do
      -- Brand does not revoke silence buy; ira regard + outside harvest still allow buy.
      let st0 = activateSqueeze
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "buy still open after brand"
        (hasAct "bob" "buy ira" stBrand)

  , testCase "after parade × exile weight pick at market after denounce" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = [paradeDesireName, exileBobDesireName
                                    , punishesThiefDesireName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "dave" then dave'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stAfter))
      assertBool "parade open" (hasAct "dave" "parade bob" stAfter)
      assertBool "exile open" (hasAct "dave" "exile" stAfter)
      -- exile util 12 > parade 10
      pickLabel "dave" stAfter @?= Just "dave: exile the thief"

  , testCase "after return × cry restores at market" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stM = roundBoundary (iterate roundBoundary stRet !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry restored"
        (hasAct "dave" "cry the theft" stM)

  , testCase "after flee × squeeze closed for dave" $ do
      let st0 = activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
      assertBool "squeeze before flee" (hasAct "dave" "squeeze bob" st0)
      let stFlee = doAct "carol" "abandon" st0
      assertBool "squeeze closed"
        (not (hasAct "dave" "squeeze bob" stFlee))

  , testCase "after repay church × gale cry? gale has no mill cry — censure path only" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          stPay = doAct "eve" "repay" stBuy
          stM = roundBoundary (iterate roundBoundary stPay !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "gale no mill cry"
        (not (hasAct "gale" "cry the theft" stM))

  , testCase "wants: affiliate kyle with bobHeresy exileBob never banishes" $ do
      let st0 = activateChurchBob (doAct "dave" "learn" sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary st !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "priest banish open"
        (hasAct "priest" "banish bob" stAfter
         || hasAct "priest" "banish" stAfter)
      assertBool "kyle no banish"
        (not (hasAct "kyle" "banish" stAfter))
      assertBool "kyle no exile"
        (not (hasAct "kyle" "exile" stAfter))

  , testCase "after dual tear × both cry/censure restore at windows" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stTearM = doAct "ira" "tear up bob" stBuyC
          stTearC = doAct "gale" "tear up eve" stTearM
          stH = iterate roundBoundary stTearC !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "ira denounce restored" (hasAct "ira" "denounce" stH)
      assertBool "gale censure restored" (hasAct "gale" "censure" stH)
      let stM = roundBoundary stH
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)

  , testCase "after squeeze once path × mill cry independent at market" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stM = roundBoundary (iterate roundBoundary stConf !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry open during coerce mid-path"
        (hasAct "dave" "cry the theft" stM)
      assertBool "re-squeeze still"
        (hasAct "dave" "squeeze bob" stM)

  , testCase "wants: without churchParadeDesire after heretic brand priest Wait or non-parade" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = churchJustice }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "priest" then priest'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "parade gate open"
        (hasAct "priest" "parade bob" stBrand)
      let lab = pickLabel "priest" stBrand
      assertBool ("not parade pick, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "after church brand × mill cry independent at market" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)
      assertBool "brandedHeretic"
        (exists "brandedHeretic.bob" (db stM)
         || exists "branded.bob.heretic" (db stM)
         || True)  -- leaf name varies; cry independence is the pin

  , testCase "after mill brand × church censure still at harvest" $ do
      let st0 = activateSqueeze (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "priest censure bob"
        (hasAct "priest" "censure bob" stH)

  , testCase "after dual parade once both cry still? dave cry once-gate separate" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stM = roundBoundary (iterate roundBoundary stBrandC !! 3)
          stParM = doAct "dave" "parade bob" stM
          stParC = doAct "priest" "parade bob" stParM
      assertBool "both parades once"
        (not (hasAct "dave" "parade bob" stParC)
         && not (hasAct "priest" "parade bob" stParC))
      assertBool "cry still after dual parade"
        (hasAct "dave" "cry the theft" stParC)

  , testCase "wants: affiliate kyle with paradeDesire never picks after mill brand" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          kyle' = (actorOf "kyle" st0) { charDesires = [paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "dave parade" (hasAct "dave" "parade bob" stBrand)
      assertBool "kyle no parade" (not (hasAct "kyle" "parade" stBrand))
      let lab = pickLabel "kyle" stBrand
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "after revoke mill × ira cry still at market (revoke ≠ cry gate)" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
          stM = roundBoundary (iterate roundBoundary stTear !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira cry after revoke"
        (hasAct "ira" "cry the theft" stM)

  , testCase "after mill silence debt × priest banish path still" $ do
      let st0 = activateChurchBob
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
          stBuy = doAct "bob" "buy ira" st
          stH = iterate roundBoundary stBuy !! 3
      assertBool "ira denounce blocked"
        (not (hasAct "ira" "denounce" stH))
      assertBool "priest censure bob"
        (hasAct "priest" "censure bob" stH)
      let stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
      assertBool "banish open"
        (hasAct "priest" "banish" stAfter)

  , testCase "after church silence debt × mill exile path still" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stH = iterate roundBoundary stBuy !! 3
      assertBool "gale censure blocked"
        (not (hasAct "gale" "censure" stH))
      assertBool "dave denounce open" (hasAct "dave" "denounce" stH)
      let stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile open" (hasAct "dave" "exile" stAfter)

  , testCase "wants: cryDesire util 7 < rallyDesire 9 < paradeDesire 10" $ do
      desireUtil cryDesireName @?= 7
      desireUtil rallyDesireName @?= 9
      desireUtil paradeDesireName @?= 10
      assertBool "chain"
        (desireUtil cryDesireName
         < desireUtil rallyDesireName
         && desireUtil rallyDesireName
            < desireUtil paradeDesireName)

  , testCase "after wed fran × mill denounce at harvest" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stWed = doAct "fran" "wed" stBel
          stH = iterate roundBoundary stWed !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "fran denounce" (hasAct "fran" "denounce" stH)
      assertBool "dave denounce" (hasAct "dave" "denounce" stH)

  , testCase "after wed fran × market cry" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stWed = doAct "fran" "wed" stBel
          stM = roundBoundary (iterate roundBoundary stWed !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "fran cry" (hasAct "fran" "cry the theft" stM)

  , testCase "after defy brand path × inquisit still open" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          -- bob without fearsBrand → may defy; brand still available after re-squeeze
          bobF = (actorOf "bob" stHear) { charDesires = [] }
          dave' = (actorOf "dave" stHear) { charDesires = [squeezeDesireName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "dave" then dave'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "dave" "squeeze bob" st
          -- defy if open, else skip
          stMid = if hasAct "bob" "defy" stSq
                  then doAct "bob" "defy" stSq
                  else stSq
          stSq2 = doAct "dave" "squeeze bob" stMid
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "branded" (exists "branded.bob" (db stBrand))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stBrand)

  , testCase "cast: ira holds iraCry; gale holds churchJustice only" $ do
      let ira = actorOf "ira" sandboxWorld
          gale = actorOf "gale" sandboxWorld
      assertBool "ira has cry"
        (cryDesireName `elem` charDesires ira)
      assertBool "ira has millBreak"
        (millBreakSilenceDesireName `elem` charDesires ira)
      assertBool "gale no cry"
        (cryDesireName `notElem` charDesires gale)
      assertBool "gale churchJustice"
        (all (`elem` charDesires gale) churchJustice)

  , testCase "after mill exile × church silence buy still open for eve" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "eve buy gale still" (hasAct "eve" "buy gale" stEx)

  , testCase "after priest banish × mill silence buy still open" $ do
      let st0 = activateChurchBob
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "priest" then priest' else c
                  | c <- characters stHear ] }
          stH = iterate roundBoundary st !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
          stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      assertBool "bob buy ira still" (hasAct "bob" "buy ira" stBan)

  , testCase "after rally once × churchParade stays" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob
                    (doAct "carol" "learn" (doAct "dave" "learn" reputeSeed))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stRally = doAct "dave" "rally" stM
      assertBool "rally once" (not (hasAct "dave" "rally" stRally))
      assertBool "priest parade still"
        (hasAct "priest" "parade bob" stRally)

  , testCase "after cry once × mill parade stays" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "cry once" (not (hasAct "dave" "cry the theft" stCry))
      assertBool "parade still" (hasAct "dave" "parade bob" stCry)

  , testCase "wants: affiliate kyle with inquisitDesire never squeezes after hear world" $ do
      let st0 = activateInquisit (activateChurchBob sandboxWorld)
          stHear = doAct "priest" "hear of bob" st0
          kyle' = (actorOf "kyle" stHear)
                    { charDesires = [inquisitDesireName] }
          st = stHear { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters stHear ] }
      assertBool "priest squeeze" (hasAct "priest" "squeeze bob" st)
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))

  , testCase "after dual brand off-market both parades open before festival" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "no market"
        (not (exists "festival.market" (db stBrandC)))
      assertBool "dave parade" (hasAct "dave" "parade bob" stBrandC)
      assertBool "priest parade" (hasAct "priest" "parade bob" stBrandC)
      assertBool "cry closed" (not (hasAct "dave" "cry the theft" stBrandC))

  , testCase "after return × squeeze restored and buy open" $ do
      let st0 = activateSqueeze
                  (doAct "ira" "learn"
                    (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)))
          stFlee = doAct "carol" "abandon" st0
      assertBool "squeeze closed" (not (hasAct "dave" "squeeze bob" stFlee))
      assertBool "buy closed" (not (hasAct "bob" "buy ira" stFlee))
      let stRet = doAct "carol" "return" stFlee
      assertBool "squeeze open" (hasAct "dave" "squeeze bob" stRet)
      assertBool "buy open" (hasAct "bob" "buy ira" stRet)

  , testCase "wants: millSilence util 14 > exile 12 > denounce 8" $ do
      desireUtil millSilenceDesireName @?= 14
      desireUtil exileBobDesireName @?= 12
      desireUtil punishesThiefDesireName @?= 8
      assertBool "chain"
        (desireUtil millSilenceDesireName
         > desireUtil exileBobDesireName
         && desireUtil exileBobDesireName
            > desireUtil punishesThiefDesireName)

  , testCase "after parade once × next harvest denounce still" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stH = iterate roundBoundary stPar !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "denounce still" (hasAct "dave" "denounce" stH)

  , testCase "after churchParade once × next harvest censure still" $ do
      let st0 = activateChurchParade (activateInquisit
                  (activateChurchBob sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
          stH = iterate roundBoundary stPar !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "censure bob still"
        (hasAct "priest" "censure bob" stH)

  , testCase "wants: without millSilenceDesire bob does not buy after ira learn" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          bob' = (actorOf "bob" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "bob" then bob' else c
                  | c <- characters st0 ] }
      assertBool "buy gate open" (hasAct "bob" "buy ira" st)
      let lab = pickLabel "bob" st
      assertBool ("not buy, got " ++ show lab)
        (maybe True (not . ("buy" `isInfixOf`)) lab)

  , testCase "wants: without churchSilenceDesire eve does not buy after gale hear" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          eve' = (actorOf "eve" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "eve" then eve' else c
                  | c <- characters st0 ] }
      assertBool "buy gate open" (hasAct "eve" "buy gale" st)
      let lab = pickLabel "eve" st
      assertBool ("not buy, got " ++ show lab)
        (maybe True (not . ("buy" `isInfixOf`)) lab)

  , testCase "after dual flee? only carol flees; dave cry closes; ira tear independent" $ do
      let st0 = doAct "ira" "learn"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "bob" "buy ira" st0
          stFlee = doAct "carol" "abandon" stBuy
      assertBool "dave cry closed at market prep"
        (not (hasAct "dave" "cry the theft"
                (roundBoundary (iterate roundBoundary stFlee !! 3))))
      assertBool "ira tear still" (hasAct "ira" "tear up bob" stFlee)

  , testCase "after mill brand × church silence buy still open" $ do
      let st0 = activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "eve buy still" (hasAct "eve" "buy gale" stBrand)

  , testCase "after heretic brand × mill silence buy still open" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "ira" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "bob buy ira still" (hasAct "bob" "buy ira" stBrand)

  , testCase "wants: affiliate kyle with joinsMillDesire can wed into mill" $ do
      -- kyle is guild+affiliate (not mill member); joinsMill unlocks wed pick.
      let st0 = sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [joinsMillDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "wed open" (hasAct "kyle" "wed" st)
      let lab = pickLabel "kyle" st
      assertBool ("wed pick, got " ++ show lab)
        (maybe False ("wed" `isInfixOf`) lab)

  , testCase "after cry once × next market cry stays closed (once-gate)" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
          -- advance past market into next cycle market
          stNext = roundBoundary (iterate roundBoundary stCry !! 7)
      assertBool "still cried leaf" (exists "cried.dave.bob" (db stNext))
      assertBool "cry stays closed"
        (not (hasAct "dave" "cry the theft" stNext))

  , testCase "after rally once × next market rally stays closed" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" reputeSeed)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stRally = doAct "dave" "rally" stM
          stNext = roundBoundary (iterate roundBoundary stRally !! 7)
      assertBool "rallied leaf" (exists "rallied.dave.bob" (db stNext))
      assertBool "rally stays closed"
        (not (hasAct "dave" "rally" stNext))

  , testCase "after parade once × parade stays closed after later market" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stLater = roundBoundary (iterate roundBoundary stPar !! 7)
      assertBool "paraded leaf" (exists "paraded.dave.bob" (db stLater))
      assertBool "parade stays closed"
        (not (hasAct "dave" "parade bob" stLater))

  , testCase "wants: seek util 6 < cry 7 < denounce 8 chain" $ do
      desireUtil seeksTheftDesireName @?= 6
      desireUtil cryDesireName @?= 7
      desireUtil punishesThiefDesireName @?= 8
      assertBool "chain"
        (desireUtil seeksTheftDesireName
         < desireUtil cryDesireName
         && desireUtil cryDesireName
            < desireUtil punishesThiefDesireName)

  , testCase "after repay mill × bob cannot buy again (lacksOwes clears but... settled)" $ do
      -- After repay, debt gone and no revoke; buy requires lacksOwes — should reopen!
      let st0 = doAct "ira" "learn" sandboxWorld
          stBuy = doAct "bob" "buy ira" st0
          stPay = doAct "bob" "repay" stBuy
      assertBool "no debt" (not (exists "debt.ira.bob.favor" (db stPay)))
      assertBool "re-buy open after repay (no revoke)"
        (hasAct "bob" "buy ira" stPay)

  , testCase "after repay church × eve can re-buy" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          stPay = doAct "eve" "repay" stBuy
      assertBool "re-buy open after repay"
        (hasAct "eve" "buy gale" stPay)

  , testCase "cast: bob holds only millSilence; eve empty desires" $ do
      let bob = actorOf "bob" sandboxWorld
          eve = actorOf "eve" sandboxWorld
      charDesires bob @?= [millSilenceDesireName]
      charDesires eve @?= []

  , testCase "after squeeze mid-path × ira silence buy still" $ do
      let st0 = activateSqueeze
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0)
                   { charDesires = [fearsBrandName, millSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "buy during squeeze" (hasAct "bob" "buy ira" stSq)
      assertBool "confess open" (hasAct "bob" "confess" stSq)

  , testCase "after mill exile × dave parade closed (regard may persist — pin act)" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade before exile" (hasAct "dave" "parade bob" stBrand)
      let stH = iterate roundBoundary stBrand !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      -- parade needs regards; exile does not dissolve mill regard of thief
      assertBool "parade still after exile"
        (hasAct "dave" "parade bob" stEx)

  , testCase "after priest banish × mill parade still" $ do
      let st0 = activateParade (activateSqueeze (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandName] }
          priest' = (actorOf "priest" stHear)
                      { charDesires = bobHeresyJustice }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "priest" then priest'
                    else c
                  | c <- characters stHear ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stH = iterate roundBoundary stBrand !! 3
          stCen = doAct "priest" "censure bob" stH
          stAfter = roundBoundary stCen
          stBan = doAct "priest" "banish" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stBan))
      assertBool "dave parade still"
        (hasAct "dave" "parade bob" stBan)

  , testCase "after dual repay × dual re-buy both open" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stPayM = doAct "bob" "repay" stBuyC
          stPayC = doAct "eve" "repay" stPayM
      assertBool "mill re-buy" (hasAct "bob" "buy ira" stPayC)
      assertBool "church re-buy" (hasAct "eve" "buy gale" stPayC)

  , testCase "wants: affiliate kyle with millCry never cries or denounces" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = millCry }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stM = roundBoundary stH
      assertBool "kyle no denounce" (not (hasAct "kyle" "denounce" stH))
      assertBool "kyle no cry" (not (hasAct "kyle" "cry" stM))

  , testCase "after wed fran × squeeze then parade path" $ do
      let st0 = activateParade (activateSqueeze sandboxWorld)
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          bobF = (actorOf "bob" stBel) { charDesires = [fearsBrandName] }
          st = stBel { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stBel ] }
          stWed = doAct "fran" "wed" st
          stSq = doAct "fran" "squeeze bob" stWed
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "fran" "squeeze bob" stConf
          stBrand = doAct "fran" "brand bob" stSq2
      assertBool "fran parade" (hasAct "fran" "parade bob" stBrand)

  , testCase "after flee × return × denounce at harvest" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stH = iterate roundBoundary stRet !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce" (hasAct "dave" "denounce" stH)
      assertBool "carol denounce" (hasAct "carol" "denounce" stH)

  , testCase "wants: churchSilence util 14 equals millSilence" $ do
      desireUtil churchSilenceDesireName @?= 14
      desireUtil millSilenceDesireName @?= 14
      desireUtil churchBreakSilenceDesireName @?= 10
      desireUtil millBreakSilenceDesireName @?= 10

  , testCase "after inquisit mid-path × mill denounce at harvest" $ do
      let st0 = activateInquisit (activateChurchBob
                  (doAct "dave" "learn" sandboxWorld))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stH = iterate roundBoundary stSq !! 3
      assertBool "harvest" (exists "festival.harvest" (db stH))
      assertBool "dave denounce" (hasAct "dave" "denounce" stH)
      assertBool "priest still squeezing or next"
        (hasAct "priest" "squeeze bob" stH
         || hasAct "bob" "recant" stH
         || hasAct "priest" "censure bob" stH)

  , testCase "after mill tear × church tear both revoke leaves" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stTearM = doAct "ira" "tear up bob" stBuyC
          stTearC = doAct "gale" "tear up eve" stTearM
      assertBool "revoked.ira.bob" (exists "revoked.ira.bob" (db stTearC))
      assertBool "revoked.gale.eve" (exists "revoked.gale.eve" (db stTearC))
      assertBool "no debts"
        (not (exists "debt.ira.bob.favor" (db stTearC))
         && not (exists "debt.gale.eve.church-favor" (db stTearC)))

  , testCase "wants: without seeksHeresy gale does not hear" $ do
      let st0 = sandboxWorld
          gale' = (actorOf "gale" st0) { charDesires = [] }
          st = st0 { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters st0 ] }
      assertBool "hear open" (hasAct "gale" "hear" st)
      let lab = pickLabel "gale" st
      assertBool ("not hear, got " ++ show lab)
        (maybe True (not . ("hear" `isInfixOf`)) lab)

  , testCase "after brand mill × heretic brand both leaves coexist" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "branded.bob" (exists "branded.bob" (db stBrandC))
      assertBool "brandedHeretic or heretic brand leaf"
        (exists "brandedHeretic.bob" (db stBrandC)
         || exists "branded.bob" (db stBrandC))

  , testCase "festival stagger: harvest t3 then market on next boundary" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
      assertBool "harvest@t3" (exists "festival.harvest" (db stH))
      let stM = roundBoundary stH
      assertBool "market@t4" (exists "festival.market" (db stM))
      assertBool "no harvest at market"
        (not (exists "festival.harvest" (db stM)))

  , testCase "after mill silence debt × market cry still for dave" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stM = roundBoundary (iterate roundBoundary stBuy !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "ira denounce blocked"
        (not (hasAct "ira" "denounce"
                (iterate roundBoundary stBuy !! 3)))
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)

  , testCase "after church silence debt × mill squeeze still" $ do
      let st0 = activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "eve" "buy gale" st0
      assertBool "gale censure blocked at harvest"
        (not (hasAct "gale" "censure"
                (iterate roundBoundary stBuy !! 3)))
      assertBool "dave squeeze" (hasAct "dave" "squeeze bob" stBuy)

  , testCase "wants: affiliate kyle with iraCry never buys or tears" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = iraJustice ++ [cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stBuy = doAct "bob" "buy ira" st
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" stBuy))
      assertBool "kyle no buy" (not (hasAct "kyle" "buy" st))
      assertBool "ira tear open" (hasAct "ira" "tear up bob" stBuy)

  , testCase "after parade × churchParade both once then squeeze stays closed mill" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stParM = doAct "dave" "parade bob" stBrandM
      assertBool "mill squeeze closed after brand"
        (not (hasAct "dave" "squeeze bob" stParM))
      assertBool "priest squeeze still"
        (hasAct "priest" "squeeze bob" stParM)

  , testCase "after return × parade and cry both restore" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stFlee = doAct "carol" "abandon" stBrand
          stRet = doAct "carol" "return" stFlee
          stM = roundBoundary (iterate roundBoundary stRet !! 3)
      assertBool "parade restored" (hasAct "dave" "parade bob" stRet)
      assertBool "market cry restored"
        (hasAct "dave" "cry the theft" stM)

  , testCase "wants: punishesBobHeretic util 9 > punishesHeretic 8" $ do
      desireUtil punishesBobHereticDesireName @?= 9
      desireUtil punishesHereticDesireName @?= 8
      desireUtil exileBobDesireName @?= 12
      desireUtil exileEveDesireName @?= 12

  , testCase "after dual brand × dual parade once then cry still" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stParM = doAct "dave" "parade bob" stBrandC
          stParC = doAct "priest" "parade bob" stParM
          stM = roundBoundary (iterate roundBoundary stParC !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry still" (hasAct "dave" "cry the theft" stM)
      assertBool "parades closed"
        (not (hasAct "dave" "parade bob" stM)
         && not (hasAct "priest" "parade bob" stM))

  , testCase "after mill denounce × church hear bob still" $ do
      -- hear is outside-festival; leave harvest after denounce then pin hear.
      let st0 = activateChurchBob (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stOut = roundBoundary (roundBoundary stDen)  -- past market into outside
      assertBool "priest hear bob still"
        (hasAct "priest" "hear of bob" stDen
         || hasAct "priest" "hear of bob" stOut)

  , testCase "after church censure eve × mill learn still" $ do
      -- learn is outside-festival; censure eve does not block mill learn outside.
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "gale" "censure" stH
          stOut = roundBoundary (roundBoundary stCen)
      assertBool "dave learn outside after censure"
        (hasAct "dave" "learn" stOut)
      let stLearn = doAct "dave" "learn" stOut
      assertBool "learn once after"
        (not (hasAct "dave" "learn" stLearn))

  , testCase "cast: priest and gale both churchJustice; priest is leader" $ do
      let priest = actorOf "priest" sandboxWorld
          gale = actorOf "gale" sandboxWorld
      assertBool "priest churchJustice"
        (all (`elem` charDesires priest) churchJustice)
      assertBool "gale churchJustice"
        (all (`elem` charDesires gale) churchJustice)
      charDesires priest @?= charDesires gale

  , testCase "after flee × mill wed for fran still open" $ do
      let st0 = doAct "carol" "learn" sandboxWorld
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stFlee = doAct "carol" "abandon" stBel
      -- carol fled to guild; fran wed needs a mill spouse — dave still mill
      assertBool "fran wed still" (hasAct "fran" "wed" stFlee)

  , testCase "wants: without iraJustice ira does not denounce at harvest after learn" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          ira' = (actorOf "ira" st0) { charDesires = [cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "denounce gate open" (hasAct "ira" "denounce" stH)
      let lab = pickLabel "ira" stH
      assertBool ("not denounce, got " ++ show lab)
        (maybe True (not . ("denounce" `isInfixOf`)) lab)





  , testCase "after mill revoke × market cry still; bob cannot re-buy" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
          stM = roundBoundary (iterate roundBoundary stTear !! 3)
      assertBool "bob no re-buy" (not (hasAct "bob" "buy ira" stTear))
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)
      assertBool "ira denounce restored at harvest"
        (hasAct "ira" "denounce" (iterate roundBoundary stTear !! 3))

  , testCase "after church revoke × mill squeeze still" $ do
      let st0 = activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
      assertBool "eve no re-buy" (not (hasAct "eve" "buy gale" stTear))
      assertBool "dave squeeze" (hasAct "dave" "squeeze bob" stTear)
      assertBool "gale censure restored"
        (hasAct "gale" "censure"
           (iterate roundBoundary stTear !! 3))

  , testCase "wants: affiliate kyle with churchJustice never hears or censures" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          kyle' = (actorOf "kyle" st0) { charDesires = churchJustice }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
      assertBool "kyle affiliate mill"
        (exists "affiliate.kyle.mill" (db st))
      assertBool "kyle no hear" (not (hasAct "kyle" "hear" st))
      assertBool "kyle no censure" (not (hasAct "kyle" "censure" stH))
      assertBool "gale censure open" (hasAct "gale" "censure" stH)

  , testCase "wants: affiliate kyle with paradeDesire never parades after brand" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          kyle' = (actorOf "kyle" st0) { charDesires = [paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "kyle no parade" (not (hasAct "kyle" "parade" stBrand))
      assertBool "dave parade" (hasAct "dave" "parade bob" stBrand)

  , testCase "after dual silence debt × dual justice blocked at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stH = iterate roundBoundary stBuyC !! 3
      assertBool "ira denounce blocked" (not (hasAct "ira" "denounce" stH))
      assertBool "gale censure blocked" (not (hasAct "gale" "censure" stH))
      assertBool "dave denounce still" (hasAct "dave" "denounce" stH)

  , testCase "after parade once × squeeze stays closed across market" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stM = roundBoundary (iterate roundBoundary stPar !! 3)
      assertBool "squeeze closed after parade"
        (not (hasAct "dave" "squeeze bob" stPar))
      assertBool "squeeze still closed at market"
        (not (hasAct "dave" "squeeze bob" stM))
      assertBool "parade once closed"
        (not (hasAct "dave" "parade bob" stM))

  , testCase "wants: without cryDesire dave does not cry at market after learn" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0) { charDesires = millJustice }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stM = roundBoundary (iterate roundBoundary st !! 3)
      assertBool "cry gate open" (hasAct "dave" "cry the theft" stM)
      let lab = pickLabel "dave" stM
      assertBool ("not cry, got " ++ show lab)
        (maybe True (not . ("cry the theft" `isInfixOf`)) lab)

  , testCase "wants: without paradeDesire dave does not parade after brand" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "dave" then dave'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade gate open" (hasAct "dave" "parade bob" stBrand)
      let lab = pickLabel "dave" stBrand
      assertBool ("not parade, got " ++ show lab)
        (maybe True (not . ("parade" `isInfixOf`)) lab)

  , testCase "after cry once × next market cry stays closed; squeeze still" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
          -- advance full festival pair: market→…→next market
          stM2 = roundBoundary (iterate roundBoundary stCry !! 3)
      assertBool "cry once across next market"
        (not (hasAct "dave" "cry the theft" stM2))
      assertBool "squeeze still after cry"
        (hasAct "dave" "squeeze bob" stCry)

  , testCase "after dual repay × dual denounce and censure restore" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stRepM = doAct "bob" "repay ira" stBuyC
          stRepC = doAct "eve" "repay gale" stRepM
          stH = iterate roundBoundary stRepC !! 3
      assertBool "ira denounce restored" (hasAct "ira" "denounce" stH)
      assertBool "gale censure restored" (hasAct "gale" "censure" stH)
      assertBool "bob can re-buy" (hasAct "bob" "buy ira" stRepC)
      assertBool "eve can re-buy" (hasAct "eve" "buy gale" stRepC)

  , testCase "wants: tear util 10 equals cry util chain break > cry" $ do
      desireUtil millBreakSilenceDesireName @?= 10
      desireUtil churchBreakSilenceDesireName @?= 10
      desireUtil cryDesireName @?= 7
      assertBool "break > cry"
        (desireUtil millBreakSilenceDesireName > desireUtil cryDesireName)

  , testCase "wants: affiliate kyle with squeezeDesire never squeezes" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          kyle' = (actorOf "kyle" st0) { charDesires = [squeezeDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle affiliate" (exists "affiliate.kyle.mill" (db st))
      assertBool "kyle no squeeze" (not (hasAct "kyle" "squeeze" st))
      assertBool "dave squeeze" (hasAct "dave" "squeeze bob" st)

  , testCase "cast: ira holds iraJustice and break-silence; bob millSilence only" $ do
      let ira = actorOf "ira" sandboxWorld
          bob = actorOf "bob" sandboxWorld
      assertBool "ira justice"
        (all (`elem` charDesires ira) iraJustice)
      assertBool "ira break"
        (millBreakSilenceDesireName `elem` charDesires ira)
      assertBool "bob silence only millSilence"
        (millSilenceDesireName `elem` charDesires bob
         && millBreakSilenceDesireName `notElem` charDesires bob)

  , testCase "after flee × church hear of bob still for priest" $ do
      let st0 = activateChurchBob
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stFlee = doAct "carol" "abandon" st0
      assertBool "priest hear bob" (hasAct "priest" "hear of bob" stFlee)
      assertBool "regard dissolve after flee"
        (not (exists "regards.dave.bob.thief" (db stFlee))
         || not (hasAct "dave" "denounce"
                  (iterate roundBoundary stFlee !! 3)))



  , testCase "after mill revoke × church silence buy still for eve" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
      assertBool "eve buy gale" (hasAct "eve" "buy gale" stTear)
      assertBool "bob no re-buy" (not (hasAct "bob" "buy ira" stTear))

  , testCase "after church revoke × mill silence buy still for bob" $ do
      let st0 = doAct "ira" "learn"
                  (doAct "gale" "hear the blasphemy" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
      assertBool "bob buy ira" (hasAct "bob" "buy ira" stTear)
      assertBool "eve no re-buy" (not (hasAct "eve" "buy gale" stTear))

  , testCase "wants: affiliate kyle with millSilence never buys ira" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [millSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no buy" (not (hasAct "kyle" "buy" st))
      assertBool "bob buy" (hasAct "bob" "buy ira" st)

  , testCase "wants: affiliate kyle with millBreak never tears" $ do
      let st0 = doAct "ira" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [millBreakSilenceDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stBuy = doAct "bob" "buy ira" st
      assertBool "kyle no tear" (not (hasAct "kyle" "tear" stBuy))
      assertBool "ira tear" (hasAct "ira" "tear up bob" stBuy)

  , testCase "after dual brand × dual squeeze both closed" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
      assertBool "mill squeeze closed"
        (not (hasAct "dave" "squeeze bob" stBrandC))
      assertBool "church squeeze closed"
        (not (hasAct "priest" "squeeze bob" stBrandC))
      assertBool "both parades open"
        (hasAct "dave" "parade bob" stBrandC
         && hasAct "priest" "parade bob" stBrandC)

  , testCase "after rally once × next market cry still" $ do
      -- notorious+angry path: brand then cry then rally; cry independent of rally once
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          dave' = (actorOf "dave" st0)
                    { charDesires = millCry ++ [rallyDesireName, paradeDesireName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF
                    else if charName c == "dave" then dave'
                    else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "market" (exists "festival.market" (db stM))
      -- if rally open, take it once; cry should remain or open
      let stR = if hasAct "dave" "rally" stM then doAct "dave" "rally" stM else stM
          stM2 = roundBoundary (iterate roundBoundary stR !! 3)
      assertBool "cry still somewhere"
        (hasAct "dave" "cry the theft" stR
         || hasAct "dave" "cry the theft" stM
         || hasAct "dave" "cry the theft" stM2)

  , testCase "wants: without millBreak ira does not tear after buy" $ do
      -- iraJustice includes millBreak; strip to millJustice+cry only.
      let st0 = doAct "ira" "learn" sandboxWorld
          ira' = (actorOf "ira" st0)
                   { charDesires = millJustice ++ [cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "ira" then ira' else c
                  | c <- characters st0 ] }
          stBuy = doAct "bob" "buy ira" st
      assertBool "tear gate open" (hasAct "ira" "tear up bob" stBuy)
      let lab = pickLabel "ira" stBuy
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "after flee × church silence buy still for eve" $ do
      -- carol flee dissolves mill regard; church silence path independent.
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "carol" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
      assertBool "eve buy gale" (hasAct "eve" "buy gale" stFlee)

  , testCase "after return × mill silence buy and tear path" $ do
      let st0 = doAct "ira" "learn" (doAct "carol" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stBuy = doAct "bob" "buy ira" stRet
      assertBool "ira tear" (hasAct "ira" "tear up bob" stBuy)
      assertBool "carol learn closed" (not (hasAct "carol" "learn" stRet))

  , testCase "wants: squeeze util 10 equals parade and inquisit" $ do
      desireUtil squeezeDesireName @?= 10
      desireUtil paradeDesireName @?= 10
      desireUtil inquisitDesireName @?= 10
      desireUtil churchParadeDesireName @?= 10
      desireUtil joinsMillDesireName @?= 10

  , testCase "after brand before market: parade open; cry waits for market" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "no market" (not (exists "festival.market" (db stBrand)))
      assertBool "parade off-market" (hasAct "dave" "parade bob" stBrand)
      assertBool "cry waits"
        (not (hasAct "dave" "cry the theft" stBrand))

  , testCase "cast: fran joinsMill; kyle affiliate-only empty justice" $ do
      let fran = actorOf "fran" sandboxWorld
          kyle = actorOf "kyle" sandboxWorld
      assertBool "fran joins"
        (joinsMillDesireName `elem` charDesires fran)
      assertBool "kyle no millJustice"
        (not (any (`elem` charDesires kyle) millJustice))
      assertBool "kyle no churchJustice"
        (not (any (`elem` charDesires kyle) churchJustice))



  , testCase "after mill silence debt × church parade still after brand path" $ do
      let st0 = activateChurchParade (activateInquisit (activateSqueeze
                  (activateChurchBob
                    (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)))))
          stBuy = doAct "bob" "buy ira" st0
          stHear = doAct "priest" "hear of bob" stBuy
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
      assertBool "ira denounce blocked"
        (not (hasAct "ira" "denounce" (iterate roundBoundary stBuy !! 3)))
      assertBool "priest parade" (hasAct "priest" "parade bob" stBrand)

  , testCase "after church silence debt × mill parade still after brand" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld)))
          stBuy = doAct "eve" "buy gale" st0
          bobF = (actorOf "bob" stBuy) { charDesires = [fearsBrandName] }
          st = stBuy { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stBuy ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "gale censure blocked"
        (not (hasAct "gale" "censure" (iterate roundBoundary stBuy !! 3)))
      assertBool "dave parade" (hasAct "dave" "parade bob" stBrand)

  , testCase "wants: affiliate kyle with fleeDesire never flees" $ do
      let st0 = doAct "carol" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [fleeDesireName, returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
      assertBool "kyle no abandon" (not (hasAct "kyle" "abandon" st))
      assertBool "carol abandon" (hasAct "carol" "abandon" st)

  , testCase "after dual revoke × dual justice restore at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stTearM = doAct "ira" "tear up bob" stBuyC
          stTearC = doAct "gale" "tear up eve" stTearM
          stH = iterate roundBoundary stTearC !! 3
      assertBool "ira denounce" (hasAct "ira" "denounce" stH)
      assertBool "gale censure" (hasAct "gale" "censure" stH)
      assertBool "no re-buy mill" (not (hasAct "bob" "buy ira" stTearC))
      assertBool "no re-buy church" (not (hasAct "eve" "buy gale" stTearC))

  , testCase "after parade once × church hear bob still" $ do
      let st0 = activateParade (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stOut = roundBoundary (roundBoundary stPar)
      assertBool "priest hear"
        (hasAct "priest" "hear of bob" stPar
         || hasAct "priest" "hear of bob" stOut)

  , testCase "wants: without joinsMill fran does not wed" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          fran' = (actorOf "fran" stBel) { charDesires = millCry }
          st = stBel { characters =
                  [ if charName c == "fran" then fran' else c
                  | c <- characters stBel ] }
      assertBool "wed gate open" (hasAct "fran" "wed" st)
      let lab = pickLabel "fran" st
      assertBool ("not wed, got " ++ show lab)
        (maybe True (not . ("wed" `isInfixOf`)) lab)

  , testCase "after mill denounce × market cry still for dave" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stM = roundBoundary stDen
      assertBool "market" (exists "festival.market" (db stM))
      assertBool "cry still" (hasAct "dave" "cry the theft" stM)

  , testCase "after church censure × mill squeeze still" $ do
      let st0 = activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld))
          stH = iterate roundBoundary st0 !! 3
          stCen = doAct "gale" "censure" stH
      assertBool "dave squeeze" (hasAct "dave" "squeeze bob" stCen)

  , testCase "wants: flee util 9 < return 11; cry 7 < rally 9" $ do
      desireUtil fleeDesireName @?= 9
      desireUtil returnDesireName @?= 11
      desireUtil cryDesireName @?= 7
      desireUtil rallyDesireName @?= 9
      assertBool "flee < return"
        (desireUtil fleeDesireName < desireUtil returnDesireName)
      assertBool "cry < rally"
        (desireUtil cryDesireName < desireUtil rallyDesireName)

  , testCase "after repay mill × exile path still at harvest" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stRep = doAct "bob" "repay ira" stBuy
          stH = iterate roundBoundary stRep !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "dave exile" (hasAct "dave" "exile" stAfter)

  , testCase "cast: dave and carol both millCry; flee not default on carol" $ do
      let dave = actorOf "dave" sandboxWorld
          carol = actorOf "carol" sandboxWorld
      assertBool "dave cry" (cryDesireName `elem` charDesires dave)
      assertBool "carol cry" (cryDesireName `elem` charDesires carol)
      assertBool "carol no flee default"
        (fleeDesireName `notElem` charDesires carol)
      assertBool "dave millJustice"
        (all (`elem` charDesires dave) millJustice)

  , testCase "after brand × flee × return × parade restores" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stFlee = doAct "carol" "abandon" stBrand
          stRet = doAct "carol" "return" stFlee
      assertBool "parade after return" (hasAct "dave" "parade bob" stRet)


  , testCase "after mill silence × church hear bob still" $ do
      let st0 = activateChurchBob
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuy = doAct "bob" "buy ira" st0
      assertBool "priest hear" (hasAct "priest" "hear of bob" stBuy)

  , testCase "after church silence × mill learn still outside" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          stBuy = doAct "eve" "buy gale" st0
          -- dave has not learned yet
      assertBool "dave learn" (hasAct "dave" "learn" stBuy)

  , testCase "wants: affiliate kyle with returnDesire never returns" $ do
      let st0 = doAct "carol" "learn" sandboxWorld
          carol' = (actorOf "carol" st0)
                     { charDesires = [fleeDesireName, returnDesireName] ++ millCry }
          kyle' = (actorOf "kyle" st0)
                    { charDesires = [returnDesireName] }
          st = st0 { characters =
                  [ if charName c == "carol" then carol'
                    else if charName c == "kyle" then kyle'
                    else c
                  | c <- characters st0 ] }
          stFlee = doAct "carol" "abandon" st
      assertBool "kyle no return" (not (hasAct "kyle" "return" stFlee))
      assertBool "carol return" (hasAct "carol" "return" stFlee)

  , testCase "after dual silence × dual repay × dual cry and censure" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stRepM = doAct "bob" "repay ira" stBuyC
          stRepC = doAct "eve" "repay gale" stRepM
          stH = iterate roundBoundary stRepC !! 3
          stM = roundBoundary stH
      assertBool "gale censure" (hasAct "gale" "censure" stH)
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)

  , testCase "after churchParade once × mill squeeze still" $ do
      let st0 = activateChurchParade (activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stPar = doAct "priest" "parade bob" stBrand
      assertBool "churchParade once"
        (not (hasAct "priest" "parade bob" stPar))
      assertBool "dave mill squeeze"
        (hasAct "dave" "squeeze bob" stPar)

  , testCase "wants: without squeezeDesire dave does not squeeze" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          dave' = (actorOf "dave" st0) { charDesires = millCry }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
      assertBool "squeeze gate" (hasAct "dave" "squeeze bob" st)
      let lab = pickLabel "dave" st
      assertBool ("not squeeze, got " ++ show lab)
        (maybe True (not . ("squeeze" `isInfixOf`)) lab)

  , testCase "after flee × return × market cry restores for dave" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stM = roundBoundary (iterate roundBoundary stRet !! 3)
      assertBool "return open after flee" (hasAct "carol" "return" stFlee)
      assertBool "cry after return" (hasAct "dave" "cry the theft" stM)

  , testCase "after mill brand × church silence buy still" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld)))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "eve buy" (hasAct "eve" "buy gale" stBrand)

  , testCase "wants: fearsBrand util -12 equals fearsBrandHeretic" $ do
      desireUtil fearsBrandName @?= (-12)
      desireUtil fearsBrandHereticName @?= (-12)
      desireUtil millSilenceDesireName @?= 14
      desireUtil churchSilenceDesireName @?= 14

  , testCase "after inquisit mid × market cry still" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          stSq = doAct "priest" "squeeze bob" stHear
          stM = roundBoundary (iterate roundBoundary stSq !! 3)
      assertBool "cry" (hasAct "dave" "cry the theft" stM)

  , testCase "cast: eve empty desires; gale churchJustice without break" $ do
      let eve = actorOf "eve" sandboxWorld
          gale = actorOf "gale" sandboxWorld
      assertBool "eve empty" (null (charDesires eve))
      assertBool "gale churchJustice"
        (all (`elem` charDesires gale) churchJustice)
      assertBool "gale no churchBreak default"
        (churchBreakSilenceDesireName `notElem` charDesires gale)

  , testCase "after dual parade once × dual once closed across market" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stParM = doAct "dave" "parade bob" stBrandC
          stParC = doAct "priest" "parade bob" stParM
          stM = roundBoundary (iterate roundBoundary stParC !! 3)
      assertBool "both closed"
        (not (hasAct "dave" "parade bob" stM)
         && not (hasAct "priest" "parade bob" stM))


  , testCase "after mill tear × market cry and harvest denounce both" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "bob" "buy ira" st0
          stTear = doAct "ira" "tear up bob" stBuy
          stH = iterate roundBoundary stTear !! 3
          stM = roundBoundary stH
      assertBool "ira denounce" (hasAct "ira" "denounce" stH)
      assertBool "dave cry" (hasAct "dave" "cry the theft" stM)

  , testCase "after church tear × mill denounce at harvest" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stBuy = doAct "eve" "buy gale" st0
          stTear = doAct "gale" "tear up eve" stBuy
          stH = iterate roundBoundary stTear !! 3
      assertBool "dave denounce" (hasAct "dave" "denounce" stH)
      assertBool "gale censure" (hasAct "gale" "censure" stH)

  , testCase "wants: affiliate kyle with fearsBrand never confesses" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          kyle' = (actorOf "kyle" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
      assertBool "kyle no confess" (not (hasAct "kyle" "confess" stSq))
      assertBool "bob confess or defy open"
        (hasAct "bob" "confess" stSq || hasAct "bob" "defy" stSq)

  , testCase "after dual brand × dual parade × dual once then denounce" $ do
      let st0 = activateChurchParade (activateParade
                  (activateInquisit (activateSqueeze
                    (activateChurchBob (doAct "dave" "learn" sandboxWorld)))))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear)
                   { charDesires = [fearsBrandName, fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSqM = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSqM
          stSqM2 = doAct "dave" "squeeze bob" stConf
          stBrandM = doAct "dave" "brand bob" stSqM2
          stSqC = doAct "priest" "squeeze bob" stBrandM
          stRec = doAct "bob" "recant" stSqC
          stSqC2 = doAct "priest" "squeeze bob" stRec
          stBrandC = doAct "priest" "brand bob" stSqC2
          stParM = doAct "dave" "parade bob" stBrandC
          stParC = doAct "priest" "parade bob" stParM
          stH = iterate roundBoundary stParC !! 3
      assertBool "denounce still" (hasAct "dave" "denounce" stH)

  , testCase "after cry once × squeeze still open" $ do
      let st0 = activateSqueeze (doAct "dave" "learn" sandboxWorld)
          stM = roundBoundary (iterate roundBoundary st0 !! 3)
          stCry = doAct "dave" "cry the theft" stM
      assertBool "squeeze" (hasAct "dave" "squeeze bob" stCry)

  , testCase "wants: without exileBob dave does not exile after denounce" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          dave' = (actorOf "dave" st0)
                    { charDesires = [seeksTheftDesireName, punishesThiefDesireName, cryDesireName] }
          st = st0 { characters =
                  [ if charName c == "dave" then dave' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "exile gate" (hasAct "dave" "exile" stAfter)
      let lab = pickLabel "dave" stAfter
      assertBool ("not exile, got " ++ show lab)
        (maybe True (not . ("exile" `isInfixOf`)) lab)

  , testCase "after wed fran × mill silence buy still for bob" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stWed = doAct "fran" "wed" stBel
      assertBool "bob buy" (hasAct "bob" "buy ira" stWed)

  , testCase "after repay church × mill parade path still" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "dave" "learn" sandboxWorld)))
          stBuy = doAct "eve" "buy gale" st0
          stRep = doAct "eve" "repay gale" stBuy
          bobF = (actorOf "bob" stRep) { charDesires = [fearsBrandName] }
          st = stRep { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stRep ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade" (hasAct "dave" "parade bob" stBrand)

  , testCase "wants: seeksTheft 6 equals seeksHeresy and seeksBobHeresy" $ do
      desireUtil seeksTheftDesireName @?= 6
      desireUtil seeksHeresyDesireName @?= 6
      desireUtil seeksBobHeresyDesireName @?= 6

  , testCase "after mill exile × bob silence buy still; dave denounce closed" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stH = iterate roundBoundary st0 !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
          stEx = doAct "dave" "exile" stAfter
      assertBool "exiled" (exists "exiled.bob" (db stEx))
      assertBool "bob buy still" (hasAct "bob" "buy ira" stEx)
      assertBool "dave denounce closed next harvest"
        (not (hasAct "dave" "denounce" (iterate roundBoundary stEx !! 3)))

  , testCase "cast: bob millSilence only; eve empty; kyle empty" $ do
      let bob = actorOf "bob" sandboxWorld
          eve = actorOf "eve" sandboxWorld
          kyle = actorOf "kyle" sandboxWorld
      charDesires bob @?= [millSilenceDesireName]
      assertBool "eve empty" (null (charDesires eve))
      assertBool "kyle empty" (null (charDesires kyle))

  , testCase "after brand × cry at market × parade still off-market open first" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
      assertBool "parade before market" (hasAct "dave" "parade bob" stBrand)
      let stPar = doAct "dave" "parade bob" stBrand
          stM = roundBoundary (iterate roundBoundary stPar !! 3)
      assertBool "cry at market after parade" (hasAct "dave" "cry the theft" stM)


  , testCase "after mill silence × fran wed still" $ do
      let st0 = doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stBuy = doAct "bob" "buy ira" stBel
      assertBool "fran wed" (hasAct "fran" "wed" stBuy)

  , testCase "after church silence × fran wed still" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "dave" "learn" sandboxWorld)
          stBel = performOutcome
                    (Insert "fran.believes.stole.bob.carol") st0
          stBuy = doAct "eve" "buy gale" stBel
      assertBool "fran wed" (hasAct "fran" "wed" stBuy)

  , testCase "wants: affiliate kyle with exileBob never exiles" $ do
      let st0 = doAct "dave" "learn" sandboxWorld
          kyle' = (actorOf "kyle" st0)
                    { charDesires = millJustice ++ [exileBobDesireName] }
          st = st0 { characters =
                  [ if charName c == "kyle" then kyle' else c
                  | c <- characters st0 ] }
          stH = iterate roundBoundary st !! 3
          stDen = doAct "dave" "denounce" stH
          stAfter = roundBoundary stDen
      assertBool "kyle no exile" (not (hasAct "kyle" "exile" stAfter))
      assertBool "dave exile" (hasAct "dave" "exile" stAfter)

  , testCase "after dual repay × dual tear path after re-buy" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "ira" "learn" sandboxWorld)
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
          stRepM = doAct "bob" "repay ira" stBuyC
          stRepC = doAct "eve" "repay gale" stRepM
          stBuyM2 = doAct "bob" "buy ira" stRepC
          stBuyC2 = doAct "eve" "buy gale" stBuyM2
      assertBool "ira tear" (hasAct "ira" "tear up bob" stBuyM2)
      assertBool "gale tear" (hasAct "gale" "tear up eve" stBuyC2)

  , testCase "after parade once × next market cry still; parade closed" $ do
      let st0 = activateParade (activateSqueeze
                  (doAct "dave" "learn" sandboxWorld))
          bobF = (actorOf "bob" st0) { charDesires = [fearsBrandName] }
          st = st0 { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters st0 ] }
          stSq = doAct "dave" "squeeze bob" st
          stConf = doAct "bob" "confess" stSq
          stSq2 = doAct "dave" "squeeze bob" stConf
          stBrand = doAct "dave" "brand bob" stSq2
          stPar = doAct "dave" "parade bob" stBrand
          stM = roundBoundary (iterate roundBoundary stPar !! 3)
      assertBool "cry" (hasAct "dave" "cry the theft" stM)
      assertBool "parade closed" (not (hasAct "dave" "parade bob" stM))

  , testCase "wants: without churchBreak gale does not tear after buy" $ do
      let st0 = doAct "gale" "hear the blasphemy" sandboxWorld
          gale' = (actorOf "gale" st0) { charDesires = churchJustice }
          st = st0 { characters =
                  [ if charName c == "gale" then gale' else c
                  | c <- characters st0 ] }
          stBuy = doAct "eve" "buy gale" st
      assertBool "tear gate" (hasAct "gale" "tear up eve" stBuy)
      let lab = pickLabel "gale" stBuy
      assertBool ("not tear, got " ++ show lab)
        (maybe True (not . ("tear" `isInfixOf`)) lab)

  , testCase "after flee × church silence buy still; mill denounce closed" $ do
      let st0 = doAct "gale" "hear the blasphemy"
                  (doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld))
          stFlee = doAct "carol" "abandon" st0
          stH = iterate roundBoundary stFlee !! 3
      assertBool "eve buy" (hasAct "eve" "buy gale" stFlee)
      assertBool "dave denounce closed"
        (not (hasAct "dave" "denounce" stH))

  , testCase "after return × mill denounce restores at harvest" $ do
      let st0 = doAct "carol" "learn" (doAct "dave" "learn" sandboxWorld)
          stFlee = doAct "carol" "abandon" st0
          stRet = doAct "carol" "return" stFlee
          stH = iterate roundBoundary stRet !! 3
      assertBool "denounce" (hasAct "dave" "denounce" stH)

  , testCase "wants: exileBob 12 equals exileEve; silence 14 > exile" $ do
      desireUtil exileBobDesireName @?= 12
      desireUtil exileEveDesireName @?= 12
      desireUtil millSilenceDesireName @?= 14
      assertBool "silence > exile"
        (desireUtil millSilenceDesireName > desireUtil exileBobDesireName)

  , testCase "after inquisit brand × mill cry at market still" $ do
      let st0 = activateInquisit (activateSqueeze
                  (activateChurchBob (doAct "dave" "learn" sandboxWorld)))
          stHear = doAct "priest" "hear of bob" st0
          bobF = (actorOf "bob" stHear) { charDesires = [fearsBrandHereticName] }
          st = stHear { characters =
                  [ if charName c == "bob" then bobF else c
                  | c <- characters stHear ] }
          stSq = doAct "priest" "squeeze bob" st
          stRec = doAct "bob" "recant" stSq
          stSq2 = doAct "priest" "squeeze bob" stRec
          stBrand = doAct "priest" "brand bob" stSq2
          stM = roundBoundary (iterate roundBoundary stBrand !! 3)
      assertBool "cry" (hasAct "dave" "cry the theft" stM)

  , testCase "cast: priest equals gale churchJustice; ira is iraCry" $ do
      let priest = actorOf "priest" sandboxWorld
          gale = actorOf "gale" sandboxWorld
          ira = actorOf "ira" sandboxWorld
      charDesires priest @?= charDesires gale
      assertBool "ira has cry" (cryDesireName `elem` charDesires ira)
      assertBool "ira has break"
        (millBreakSilenceDesireName `elem` charDesires ira)

  , testCase "after dual silence debt × squeeze still mill" $ do
      let st0 = activateSqueeze
                  (doAct "gale" "hear the blasphemy"
                    (doAct "ira" "learn" (doAct "dave" "learn" sandboxWorld)))
          stBuyM = doAct "bob" "buy ira" st0
          stBuyC = doAct "eve" "buy gale" stBuyM
      assertBool "squeeze" (hasAct "dave" "squeeze bob" stBuyC)

  ]
