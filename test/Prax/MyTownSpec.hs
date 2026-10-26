-- | MyTown M1 验收：Session S01–S06、CLI 01–07、AFF/NEG/INV、满 5 站位、trust、
-- action.id、praxAct 整回合、Save/Load。@stack test --test-arguments '-p MyTown'@。
module Prax.MyTownSpec (tests) where

import           Data.List (isInfixOf, isPrefixOf, sort, (\\))
import qualified Data.Map.Strict as Map
import           Data.Either (isLeft, isRight)
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

import           Prax.Db (dbToSentences)
import           Prax.Types
import           Prax.Engine (possibleActions, performAction)
import           Prax.TypeCheck (typeCheck)
import           Prax.Planner (candidateActions)
import           Prax.Session
import qualified Prax.Worlds.MyTown as MyTown

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

mustNew :: IO Session
mustNew = case praxNew MyTown.worldId of
  Right s -> pure s
  Left e  -> assertFailure e >> error "unreachable"

menuByLabel :: Session -> String -> Maybe MenuItem
menuByLabel s needle =
  case [ m | m <- praxMenu s, needle `isInfixOf` menuLabel m ] of
    (m : _) -> Just m
    []      -> Nothing

actByLabel :: Session -> String -> IO (Session, ActResult)
actByLabel s needle =
  case menuByLabel s needle of
    Nothing -> assertFailure ("no menu item matching " ++ show needle
                              ++ "; had: " ++ show (map menuLabel (praxMenu s)))
               >> error "unreachable"
    Just m  -> case praxAct s (menuActionId m) of
      Left e  -> assertFailure e >> error "unreachable"
      Right r -> pure r

doAct :: String -> String -> PraxState -> PraxState
doAct who needle st =
  case [ ga | ga <- possibleActions st who, needle `isInfixOf` gaLabel ga ] of
    (ga : _) -> performAction st ga
    []       -> error ("no action for " ++ who ++ " matching " ++ show needle
                       ++ "; had: " ++ show (map gaLabel (possibleActions st who)))

factInfix :: PraxState -> String -> Bool
factInfix st needle = any (needle `isInfixOf`) (dbToSentences (db st))

--------------------------------------------------------------------------------
-- Suite
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "MyTown"
  [ testGroup "MyTown.Session"
      [ testCase "S01 praxNew my-town lands on player turn" $ do
          s <- mustNew
          sessWorldId s @?= "my-town"
          sessPlayer s @?= "you"
          let i = cursor (sessState s)
              cs = characters (sessState s)
          assertBool "cursor on you" (i >= 0 && charName (cs !! i) == "you")

      , testCase "S02 praxView projects locations (no raw EL dump required)" $ do
          s <- mustNew
          let v = praxView s
          viewWorldId v @?= "my-town"
          viewLocationId v @?= Just "square"
          let heres = Map.fromList
                [ (actorId a, actorHere a) | a <- viewActors v ]
          heres Map.! "you"   @?= Just "square"
          heres Map.! "bob"   @?= Just "square"
          heres Map.! "carol" @?= Just "square"
          heres Map.! "dana"  @?= Just "mill"
          heres Map.! "eve"   @?= Just "mill"
          heres Map.! "gale"  @?= Just "mill"

      , testCase "S03 Menu action.id is ga:v1 canonical (Act rejects label)" $ do
          s <- mustNew
          let menu = praxMenu s
          assertBool "non-empty menu" (not (null menu))
          mapM_ (\m -> assertBool ("prefix " ++ menuActionId m)
                         ("ga:v1:" `isPrefixOf` menuActionId m)) menu
          case menuByLabel s "公开帮助" of
            Nothing -> assertFailure "expected 公开帮助 on opening square"
            Just m  -> do
              assertBool "decode round-trips" (isRight (decodeActionId (menuActionId m)))
              assertBool "label is not a valid actionId"
                (isLeft (praxAct s (menuLabel m)))

      , testCase "S04 praxAct runs full player turn (NPC until you again)" $ do
          s0 <- mustNew
          (s1, r) <- actByLabel s0 "公开帮助 carol"
          let i = cursor (sessState s1)
              cs = characters (sessState s1)
          assertBool "back on you" (charName (cs !! i) == "you")
          assertBool "narrative includes player line"
            (any ("公开帮助" `isInfixOf`) (actNarrative r))
          assertBool "bob saw the help"
            (factInfix (sessState s1) "bob.believes.helped.you.carol.seen")

      , testCase "S05 praxSave/praxLoad round-trip with worldId" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          let raw = praxSave s1
          assertBool "format tag" ("prax-state-v4" `isInfixOf` raw)
          assertBool "worldId" ("my-town" `isInfixOf` raw)
          case praxLoad raw of
            Left e -> assertFailure e
            Right s2 -> do
              sessWorldId s2 @?= "my-town"
              db (sessState s2) @?= db (sessState s1)
              cursor (sessState s2) @?= cursor (sessState s1)

      , testCase "S06 menu hides empty Wait; praxWait returns to player" $ do
          s0 <- mustNew
          assertBool "稍候 not in player menu"
            (all (not . ("稍候" `isInfixOf`) . menuLabel) (praxMenu s0))
          case praxWait s0 of
            Left e -> assertFailure e
            Right (s1, _) -> do
              let i = cursor (sessState s1)
                  cs = characters (sessState s1)
              assertBool "still/again on you" (charName (cs !! i) == "you")
      ]

  , testGroup "MyTown.CLI"
      [ testCase "CLI-01 worldId my-town registered in Session registry" $
          assertBool "template" (isRight (worldTemplate "my-town"))

      , testCase "CLI-02 praxNew(\"my-town\") succeeds" $ do
          s <- mustNew
          sessWorldId s @?= MyTown.worldId

      , testCase "CLI-03 opening menu non-empty" $ do
          s <- mustNew
          assertBool "menu" (not (null (praxMenu s)))

      , testCase "CLI-04 act by opaque actionId" $ do
          s0 <- mustNew
          case menuByLabel s0 "前往 mill" of
            Nothing -> assertFailure "no 前往 mill"
            Just m  -> case praxAct s0 (menuActionId m) of
              Left e -> assertFailure e
              Right (s1, _) -> viewLocationId (praxView s1) @?= Just "mill"

      , testCase "CLI-05 save emits JSON envelope" $ do
          s <- mustNew
          let raw = praxSave s
          assertBool "has blob key shape" ("\"blob\"" `isInfixOf` raw)

      , testCase "CLI-06 load restores session" $ do
          s0 <- mustNew
          case praxLoad (praxSave s0) of
            Left e -> assertFailure e
            Right s1 -> sessPlayer s1 @?= "you"

      , testCase "CLI-07 resume equivalence: save∘load preserves menu ids set" $ do
          s0 <- mustNew
          let ids0 = sort (map menuActionId (praxMenu s0))
          case praxLoad (praxSave s0) of
            Left e -> assertFailure e
            Right s1 -> sort (map menuActionId (praxMenu s1)) @?= ids0
      ]

  , testGroup "MyTown.World"
      [ testCase "roster full 5 NPC + you; seed standing" $ do
          let names = sort (map charName (characters MyTown.myTownWorld))
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st = MyTown.myTownWorld
          assertBool "bob square" (factInfix st "at.bob.square")
          assertBool "carol square" (factInfix st "at.carol.square")
          assertBool "dana mill" (factInfix st "at.dana.mill")
          assertBool "eve mill" (factInfix st "at.eve.mill")
          assertBool "gale mill" (factInfix st "at.gale.mill")
          assertBool "you square" (factInfix st "at.you.square")

      , testCase "NEG-ROSTER opening cast must be exactly {you,bob,carol,dana,eve,gale}" $ do
          -- 硬卡：缺员或顶替均不得绿（集合必须恰好等于六名，不许少人/冒充）。
          let required = sort ["you","bob","carol","dana","eve","gale"]
              names    = sort (map charName (characters MyTown.myTownWorld))
              missing  = required \\ names
              impostors = names \\ required
          length (characters MyTown.myTownWorld) @?= 6
          names @?= required
          assertBool ("缺员不得过: " ++ show missing) (null missing)
          assertBool ("顶替/冒充不得过: " ++ show impostors) (null impostors)

      , testCase "typeCheck my-town is clean" $
          typeCheck MyTown.myTownWorld @?= []

      , testCase "AFF-01 前往" $ do
          let st = doAct "you" "前往 mill" MyTown.myTownWorld
          assertBool "moved" (factInfix st "at.you.mill")

      , testCase "AFF-02 稍候 (empty outcomes; available to NPC via candidates)" $ do
          let st = MyTown.myTownWorld
              bob = head [ c | c <- characters st, charName c == "bob" ]
              waits = [ ga | ga <- candidateActions st bob
                           , "稍候" `isInfixOf` gaLabel ga ]
          assertBool "bob can wait" (not (null waits))

      , testCase "AFF-03 公开帮助 → trust helpedMe + witnessed" $ do
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "bob.seen" (factInfix st "bob.believes.helped.you.carol.seen")
          assertBool "carol trust helpedMe"
            (factInfix st ("carol.relationship.you.trust.score."
                           ++ show MyTown.trustHelpedMe))
          assertBool "reason helpedMe"
            (factInfix st "carol.relationship.you.trust.reason.helpedMe")

      , testCase "AFF-04 说破 (bob) → trust sawHelp" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you 帮助了 carol" st0
          assertBool "spokeUp" (factInfix st1 "spokeUp.bob.you.carol")
          assertBool "bob trust you sawHelp"
            (factInfix st1 ("bob.relationship.you.trust.score."
                            ++ show MyTown.trustSawHelp))
          assertBool "reason sawHelp"
            (factInfix st1 "bob.relationship.you.trust.reason.sawHelp")

      , testCase "AFF-05 转告 does not write .seen" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
          assertBool "dana heard" (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "dana not seen" (not (factInfix st3 "dana.believes.helped.you.carol.seen"))

      , testCase "AFF-06 怀疑 heard∧¬seen → trust heardRumor" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
              st5 = doAct "dana" "怀疑地打量 you" st4
          assertBool "eyed" (factInfix st5 "eyed.dana.you")
          assertBool "trust hit"
            (factInfix st5 ("dana.relationship.you.trust.score."
                            ++ show MyTown.trustHeardRumor))
          assertBool "reason heardRumor"
            (factInfix st5 "dana.relationship.you.trust.reason.heardRumor")

      , testCase "NEG no shun/steal/earnBread/whisper/ostracize affordances" $ do
          let labels = map gaLabel (possibleActions MyTown.myTownWorld "you")
                       ++ map gaLabel (possibleActions MyTown.myTownWorld "bob")
                       ++ map gaLabel (possibleActions MyTown.myTownWorld "dana")
              banned = ["shun", "steal", "earnBread", "honest work", "whisper",
                        "ostracize", "偷", "疏远", "敲诈"]
          mapM_ (\b -> assertBool ("no " ++ b)
                         (not (any (b `isInfixOf`) labels))) banned

      , testCase "INV speak-up requires .seen (hearsay alone insufficient)" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              speak = [ ga | ga <- possibleActions st3 "dana"
                           , "说破" `isInfixOf` gaLabel ga ]
          assertBool "dana cannot speak up without seeing" (null speak)

      , testCase "INV eye suppressed when .seen" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              eye = [ ga | ga <- possibleActions st0 "bob"
                         , "怀疑" `isInfixOf` gaLabel ga
                         , "you" `isInfixOf` gaLabel ga ]
          assertBool "eyewitness does not eye" (null eye)

      , testCase "INV mill does not witness square help" $ do
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "dana no seen" (not (factInfix st "dana.believes.helped.you.carol.seen"))
          assertBool "eve no seen" (not (factInfix st "eve.believes.helped.you.carol.seen"))
      ]
  ]
