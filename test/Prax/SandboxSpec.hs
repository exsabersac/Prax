-- | Prax.Worlds.Sandbox 可测闭环：磨坊审判、教会异端、婚入获站队、
-- 债务买沉默、双节庆错峰市集喊冤、受害方叛逃和解、沉默×叛逃×节庆复合门禁、
-- 臭名+愤怒市集声援、站队胁迫招供（Coerce）、教会异端×磨坊正义同场双压、
-- 教会异端×沉默债、教会胁迫悔罪（Coerce×heretic）、
-- 沉默×胁迫交叉与烙印游街（默认未激活），
-- 以及轻量 wants 驱动的自选节拍。
-- 自有逐步断言与短轨迹；不触碰 Village / Bar / Feud / GoldenDrive 等既有金标准。
module Prax.SandboxSpec (tests) where

import           Data.List (isInfixOf)
import           Data.Maybe (listToMaybe)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists)
import           Prax.Types
import           Prax.Engine (possibleActions, performAction, performOutcome, roundBoundary)
import           Prax.TypeCheck (typeCheck)
import           Prax.Host (practiceNames, castNames, festivalsOf, membersOf, leadersOf)
import           Prax.Planner (pickAction)
import           Prax.Loop (advance, npcAct)
import           Prax.Worlds.Sandbox
  ( sandboxWorld, playerName, sandboxDesires, millJustice, millCry
  , churchJustice, bobHeresyJustice, squeezeDesireName, fearsBrandName
  , activateSqueeze, activateChurchBob
  , inquisitDesireName, fearsBrandHereticName, activateInquisit
  , activateParade, activateChurchParade )

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
                 { charDesires = ["flees-mill", "returns-to-mill"]
                                  ++ millJustice ++ ["cries-theft-at-market"] }
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
                  { charDesires = ["flees-mill", "returns-to-mill"] ++ millCry }
  in st0 { characters =
              [ if charName c == "carol" then carol' else c
              | c <- characters st0 ] }

-- Repute/emotion bystander: dave holds rally want (weight 9 > cry 7) so at
-- market, once bob is notorious (≥2 regards) and dave is angry, he rallies.
reputeSeed :: PraxState
reputeSeed =
  let st0 = sandboxWorld
      dave' = (actorOf "dave" st0)
                 { charDesires = ["rallies-against-thief"] ++ millCry }
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
      eve'  = (actorOf "eve" st0)  { charDesires = ["buys-church-silence"] }
      gale' = (actorOf "gale" st0)
                { charDesires = churchJustice ++ ["breaks-church-silence"] }
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
        (any ((== "buys-church-silence") . desireName) sandboxDesires)
      assertBool "churchBobHeresy defined"
        ("churchBobHeresy" `elem` practiceNames sandboxWorld)
      assertBool "churchBobHeresy inactive by default"
        (not (exists "practice.churchBobHeresy" (db sandboxWorld)))
      assertBool "bob heresy desires in vocabulary"
        (all (`elem` map desireName sandboxDesires)
           ["seeks-bob-heresy", "punishes-bob-heretic"])
      assertBool "presence" ("presence" `elem` practiceNames sandboxWorld)
      assertBool "squeeze desire registered"
        (any ((== squeezeDesireName) . desireName) sandboxDesires)
      assertBool "fears-brand registered"
        (any ((== fearsBrandName) . desireName) sandboxDesires)
      assertBool "you mill" (playerName `elem` membersOf sandboxWorld "mill")
      assertBool "ira mill" ("ira" `elem` membersOf sandboxWorld "mill")
      assertBool "kyle guild" ("kyle" `elem` membersOf sandboxWorld "guild")
      assertBool "priest leads" ("priest" `elem` leadersOf sandboxWorld "church")
      festivalsOf sandboxWorld @?= []
      assertBool "vocab loaded" (not (null sandboxDesires))
      assertBool "dave holds mill justice"
        ("seeks-theft-truth" `elem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "dave holds market cry"
        ("cries-theft-at-market" `elem` charDesires (actorOf "dave" sandboxWorld))
      assertBool "priest holds church justice"
        ("punishes-heretic" `elem` charDesires (actorOf "priest" sandboxWorld))
      assertBool "fran holds joins-mill"
        ("joins-mill" `elem` charDesires (actorOf "fran" sandboxWorld))
      assertBool "bob holds buys-ira-silence"
        ("buys-ira-silence" `elem` charDesires (actorOf "bob" sandboxWorld))
      assertBool "ira holds breaks-silence-deal"
        ("breaks-silence-deal" `elem` charDesires (actorOf "ira" sandboxWorld))
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
                                         ++ ["seeks-heresy-truth", "punishes-heretic"
                                            , "wants-exile-eve"] }
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
  ]
