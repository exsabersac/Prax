-- | Prax.Worlds.Sandbox 可测闭环：磨坊审判、教会异端、婚入获站队、
-- 债务买沉默与磨坊正义交叉，以及轻量 wants 驱动的自选节拍。
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
import           Prax.Worlds.Sandbox (sandboxWorld, playerName, sandboxDesires)

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

-- Captured from a live wants-driven run (v271). Pins harvest tribunal /
-- church heresy / mill-wedding / silence-debt beats until both exiles.
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
  , "bob: bob: buy ira's silence about the theft"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: tear up bob's silence deal"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  , "bob: bob: Wait a moment"
  , "carol: carol: exile the thief"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: exile the heretic"
  ]

-- Focused silence arc trajectory: start after ira has learned (regard up),
-- then free-play until ira has revoked + denounced (or bob exiled path).
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
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: learn of the theft"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: Wait a moment"
  , "dave: dave: Wait a moment"
  , "fran: fran: Wait a moment"
  , "eve: eve: Wait a moment"
  , "gale: gale: Wait a moment"
  , "priest: priest: Wait a moment"
  , "ira: ira: Wait a moment"
  , "bob: bob: Wait a moment"
  , "carol: carol: denounce the thief"
  , "dave: dave: denounce the thief"
  , "fran: fran: denounce the thief"
  , "eve: eve: Wait a moment"
  , "gale: gale: censure the heretic"
  , "priest: priest: censure the heretic"
  , "ira: ira: denounce the thief"
  ]

tests :: TestTree
tests = testGroup "Prax.Worlds.Sandbox (playable festival + factionStanding arcs)"
  [ testCase "well-formed: typeCheck empty" $
      typeCheck sandboxWorld @?= []

  , testCase "cast / practices / factions / desires seed" $ do
      assertBool "player in cast" (playerName `elem` castNames sandboxWorld)
      assertBool "millTribunal" ("millTribunal" `elem` practiceNames sandboxWorld)
      assertBool "churchHeresy" ("churchHeresy" `elem` practiceNames sandboxWorld)
      assertBool "millWed" ("millWed" `elem` practiceNames sandboxWorld)
      assertBool "millSilence" ("millSilence" `elem` practiceNames sandboxWorld)
      assertBool "presence" ("presence" `elem` practiceNames sandboxWorld)
      assertBool "you mill" (playerName `elem` membersOf sandboxWorld "mill")
      assertBool "ira mill" ("ira" `elem` membersOf sandboxWorld "mill")
      assertBool "priest leads" ("priest" `elem` leadersOf sandboxWorld "church")
      festivalsOf sandboxWorld @?= []
      assertBool "vocab loaded" (not (null sandboxDesires))
      assertBool "dave holds mill justice"
        ("seeks-theft-truth" `elem` charDesires (actorOf "dave" sandboxWorld))
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

  , testCase "wants: pickAction chooses learn / hear / wed / buy at seed" $ do
      pickLabel "dave" sandboxWorld @?= Just "dave: learn of the theft"
      pickLabel "carol" sandboxWorld @?= Just "carol: learn of the theft"
      pickLabel "ira" sandboxWorld @?= Just "ira: learn of the theft"
      pickLabel "priest" sandboxWorld @?= Just "priest: hear the blasphemy"
      pickLabel "gale" sandboxWorld @?= Just "gale: hear the blasphemy"
      pickLabel "fran" sandboxWorld @?= Just "fran: wed into the mill beside carol"
      pickLabel "bob" sandboxWorld @?= Just "bob: Wait a moment"
      pickLabel "eve" sandboxWorld @?= Just "eve: Wait a moment"

  , testCase "wants: after ira learns, bob buys silence" $ do
      let stLearn = doAct "ira" "learn" sandboxWorld
      pickLabel "bob" stLearn @?= Just "bob: buy ira's silence about the theft"
      let stBuy = doAct "bob" "buy" stLearn
      pickLabel "ira" stBuy @?= Just "ira: tear up bob's silence deal"

  , testCase "wants: pickAction denounces during festival, exiles after" $ do
      let stLearn = doAct "dave" "learn" sandboxWorld
      pickLabel "dave" stLearn @?= Just "dave: Wait a moment"
      let stOpen = iterate roundBoundary stLearn !! 3
      assertBool "festival open" (exists "festival.harvest" (db stOpen))
      pickLabel "dave" stOpen @?= Just "dave: denounce the thief"
      let stDen = doAct "dave" "denounce" stOpen
          stAfter = roundBoundary stDen
      pickLabel "dave" stAfter @?= Just "dave: exile the thief"

  , testCase "wants: priest pickAction hears → censures → exiles" $ do
      let stHear = doAct "priest" "hear" sandboxWorld
      pickLabel "priest" stHear @?= Just "priest: Wait a moment"
      let stOpen = iterate roundBoundary stHear !! 3
      pickLabel "priest" stOpen @?= Just "priest: censure the heretic"
      let stCen = doAct "priest" "censure" stOpen
          stAfter = roundBoundary stCen
      pickLabel "priest" stAfter @?= Just "priest: exile the heretic"

  , testCase "wants free-play golden: 39 NPC turns through silence + both exiles" $
      driveLabels (length sandboxGolden) sandboxWorld @?= sandboxGolden

  , testCase "wants silence golden: 32 NPC turns from ira-learned through denounce" $
      driveLabels (length sandboxSilenceGolden) silenceSeed
        @?= sandboxSilenceGolden
  ]
