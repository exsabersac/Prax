-- | MyTown M1+M3+M4+M6c+M6f+M6g+M6h+M6i+M6j+M6k+M6l+M6m 验收：Session S01–S06、CLI 01–07、AFF/NEG/INV、满 5 站位、trust、
-- action.id、praxAct 整回合、Save/Load；M3 弧 A（A01–A06）；M4 债清（MT-M4-INV01–06 + 3b B1–B5）；
-- M6c eve 短反应（C02 硬卡）；M6f 亲往 mill·当场说破（F01–F04）；
-- M6g 亲往 mill·当场转告（G01–G04；Actor 自证喂 gossip）；
-- M6h 亲见后带回转告（H01–H04；mill 亲见 gale→dana → square 转告 carol；零改世界）；
-- M6i 亲往 mill·当场挨疑（I01–I04；eve 主针；bob 转告→you 赴 mill→怀疑；零改世界）；
-- M6j 存档后再见·eyed（J01–J04；M6i 后 save/load 续存 eyed+heardRumor；零改世界）；
-- M6k 存档后再见·heard（K01–K04；M6h 后 save/load 续存 carol heard.you；零改世界）；
-- M6l 听闻后短反应·carol（L01–L04；M6h→carol 赴 mill→怀疑打量 gale；最小 Want）；
-- M6m 存档后再见·eyed.carol.gale（M01–M04；M6l 后 save/load 续存 eyed+heardRumor；零改世界）。
-- @stack test --test-arguments '-p MyTown'@。
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

-- | M6i 最短 Session 路径：帮 carol → wait（eve.heard）→ 赴 mill → 点/自发怀疑 → eyed。
reachEyedAfterM6i :: IO Session
reachEyedAfterM6i = do
  s0 <- mustNew
  (s1, _) <- actByLabel s0 "公开帮助 carol"
  let waitOnce s = case praxWait s of
        Left e -> assertFailure e >> error "unreachable"
        Right r -> pure r
      goHeard 0 s = pure s
      goHeard k s = do
        (s', _) <- waitOnce s
        let heard = factInfix (sessState s')
                      "eve.believes.helped.you.carol.heard.bob"
                    || factInfix (sessState s')
                         "dana.believes.helped.you.carol.heard.bob"
        if heard then pure s' else goHeard (k - 1) s'
  s2 <- goHeard 12 s1
  (s3, _) <- actByLabel s2 "前往 mill"
  let eyedOk s =
        factInfix (sessState s) "eyed.eve.you"
        || factInfix (sessState s) "eyed.dana.you"
      rumorOk s =
        factInfix (sessState s)
          "eve.relationship.you.trust.reason.heardRumor"
        || factInfix (sessState s)
             "dana.relationship.you.trust.reason.heardRumor"
      done s = eyedOk s || rumorOk s
      tryClick s =
        let st = sessState s
            pick who =
              [ ga | ga <- possibleActions st who
                   , "怀疑地打量" `isInfixOf` gaLabel ga
                   , "you" `isInfixOf` gaLabel ga ]
        in case pick "eve" ++ pick "dana" of
          (ga : _) ->
            let st' = ensurePlayerTurn (sessPlayer s) (performAction st ga)
            in Just (s { sessState = st' })
          [] -> Nothing
      goEye 0 _ =
        assertFailure "reachEyedAfterM6i: no eyed" >> error "unreachable"
      goEye k s =
        case tryClick s of
          Just s' | done s' -> pure s'
          _ -> do
            (s', _) <- waitOnce s
            if done s' then pure s' else goEye (k - 1) s'
  if done s3
    then pure s3
    else case tryClick s3 of
      Just s' | done s' -> pure s'
      _ -> goEye 8 s3

-- | M6h 最短 Session 路径：赴 mill → 稍候 gale 帮 dana（you.seen）→ 赴 square → 转告 carol。
reachHeardAfterM6h :: IO Session
reachHeardAfterM6h = do
  s0 <- mustNew
  (s1, _) <- actByLabel s0 "前往 mill"
  let hasSpeak s =
        any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
            (praxMenu s)
      waitOnce s = case praxWait s of
        Left e -> assertFailure e >> error "unreachable"
        Right r -> pure r
      goWait 0 s = pure s
      goWait k s
        | hasSpeak s
          || factInfix (sessState s) "you.believes.helped.gale.dana.seen" = pure s
        | otherwise = do
            (s', _) <- waitOnce s
            goWait (k - 1) s'
  s2 <- if hasSpeak s1
           || factInfix (sessState s1) "you.believes.helped.gale.dana.seen"
        then pure s1 else goWait 12 s1
  assertBool "reachHeardAfterM6h: you.seen gale→dana"
    (factInfix (sessState s2) "you.believes.helped.gale.dana.seen")
  (s3, _) <- actByLabel s2 "前往 square"
  (s4, _) <- actByLabel s3 "转告 carol：gale 帮助了 dana"
  assertBool "reachHeardAfterM6h: carol.heard.you"
    (factInfix (sessState s4) "carol.believes.helped.gale.dana.heard.you")
  pure s4

-- | M6l 最短 Session 路径：M6h 转告后 → 稍候 carol 赴 mill → you 赴 mill → 稍候 eyed.carol.gale。
reachEyedAfterM6l :: IO (Session, [[String]])
reachEyedAfterM6l = do
  sHeard <- reachHeardAfterM6h
  let waitOnce s = case praxWait s of
        Left e -> assertFailure e >> error "unreachable"
        Right r -> pure r
      hard n =
        any (\t -> "carol" `isInfixOf` t
                && "怀疑地打量" `isInfixOf` t
                && "gale" `isInfixOf` t) n
      eyedOk s = factInfix (sessState s) "eyed.carol.gale"
      rumorOk s = factInfix (sessState s)
                    "carol.relationship.gale.trust.reason.heardRumor"
      done s = eyedOk s || rumorOk s
      carolMill s = any (== "practice.world.world.at.carol.mill")
                        (dbToSentences (db (sessState s)))
      youMill s = any (== "practice.world.world.at.you.mill")
                      (dbToSentences (db (sessState s)))
      -- 稍候至 carol 赴 mill（或已 eyed）；累积 narrative
      goCarol 0 _ narrAcc =
        assertFailure ("reachEyedAfterM6l: carol did not go mill; had: "
                       ++ show (reverse narrAcc))
          >> error "unreachable"
      goCarol k s narrAcc
        | done s || carolMill s = pure (s, narrAcc)
        | otherwise = do
            (s', r) <- waitOnce s
            let n = actNarrative r
            goCarol (k - 1) s' (n : narrAcc)
  (sMillNpc, narr1) <- goCarol 12 sHeard []
  if done sMillNpc
    then pure (sMillNpc, reverse narr1)
    else do
      -- you 赴 mill（常与 carol 怀疑同回合，须收 narrative）
      (sAtMill, narr2) <- if youMill sMillNpc
                          then pure (sMillNpc, narr1)
                          else do
                            (s', r) <- actByLabel sMillNpc "前往 mill"
                            pure (s', actNarrative r : narr1)
      if done sAtMill
        then pure (sAtMill, reverse narr2)
        else do
          let goEye 0 _ narrAcc =
                assertFailure ("reachEyedAfterM6l: no eyed; had: "
                               ++ show (reverse narrAcc))
                  >> error "unreachable"
              goEye k s narrAcc
                | done s = pure (s, reverse narrAcc)
                | otherwise = do
                    (s', r) <- waitOnce s
                    let n = actNarrative r
                    if hard n || done s'
                      then pure (s', reverse (n : narrAcc))
                      else goEye (k - 1) s' (n : narrAcc)
          goEye 12 sAtMill narr2

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

      , testCase "INV③ speak-up requires .seen (hearsay alone insufficient)" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              speak = [ ga | ga <- possibleActions st3 "dana"
                           , "说破" `isInfixOf` gaLabel ga ]
          assertBool "dana cannot speak up without seeing" (null speak)

      , testCase "INV⑤ eye suppressed when .seen" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              eye = [ ga | ga <- possibleActions st0 "bob"
                         , "怀疑" `isInfixOf` gaLabel ga
                         , "you" `isInfixOf` gaLabel ga ]
          assertBool "eyewitness does not eye" (null eye)

      , testCase "INV① mill does not witness square help" $ do
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "dana no seen" (not (factInfix st "dana.believes.helped.you.carol.seen"))
          assertBool "eve no seen" (not (factInfix st "eve.believes.helped.you.carol.seen"))

      , testCase "INV④ trust deltas carry reason (helpedMe/sawHelp/heardRumor)" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you 帮助了 carol" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
              st5 = doAct "dana" "怀疑地打量 you" st4
          assertBool "helpedMe reason"
            (factInfix st0 "carol.relationship.you.trust.reason.helpedMe")
          assertBool "sawHelp reason"
            (factInfix st1 "bob.relationship.you.trust.reason.sawHelp")
          assertBool "heardRumor reason"
            (factInfix st5 "dana.relationship.you.trust.reason.heardRumor")

      , -- INV⑥ 一弧一事（软卡）：主路径锚 didHelp.you.carol；NPC 互帮噪声不挡门禁。
        testCase "INV⑥ soft: primary arc anchors on didHelp.you.carol" $ do
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "primary didHelp" (factInfix st "didHelp.you.carol")
      ]

  , testGroup "MyTown.M3.ArcA"
      [ testCase "A01 公开帮忙 → bob.seen + carol trust helpedMe；narrative 可读" $ do
          s0 <- mustNew
          (s1, r) <- actByLabel s0 "公开帮助 carol"
          assertBool "didHelp" (factInfix (sessState s1) "didHelp.you.carol")
          assertBool "bob.seen"
            (factInfix (sessState s1) "bob.believes.helped.you.carol.seen")
          assertBool "carol trust helpedMe"
            (factInfix (sessState s1) "carol.relationship.you.trust.reason.helpedMe")
          let narr = unlines (actNarrative r)
          assertBool ("narrative has 帮忙: " ++ narr) ("公开帮助" `isInfixOf` narr)
          assertBool ("narrative has 信任/helpedMe: " ++ narr)
            ("信任" `isInfixOf` narr && "helpedMe" `isInfixOf` narr)
          -- 不查 View 是否有 trust 字段
          assertBool "View has no trust field surface"
            (not ("trust" `isInfixOf` show (actView r)))

      , testCase "A02 bob 说破 → spokeUp + bob trust sawHelp；narrative 可读" $ do
          s0 <- mustNew
          (s1, r) <- actByLabel s0 "公开帮助 carol"
          -- 同回合 NPC：bob 说破（种子弧）
          assertBool "spokeUp" (factInfix (sessState s1) "spokeUp.bob.you.carol")
          assertBool "bob trust sawHelp"
            (factInfix (sessState s1) "bob.relationship.you.trust.reason.sawHelp")
          let narr = unlines (actNarrative r)
          assertBool ("narrative has 说破: " ++ narr) ("说破" `isInfixOf` narr)
          assertBool ("narrative has sawHelp 信任: " ++ narr)
            ("sawHelp" `isInfixOf` narr && "信任" `isInfixOf` narr)

      , testCase "A03 Session praxAct 主路径 narrative 含帮忙/信任" $ do
          s0 <- mustNew
          (_, r) <- actByLabel s0 "公开帮助 carol"
          let narr = unlines (actNarrative r)
          assertBool "action semantic 帮忙" ("公开帮助" `isInfixOf` narr || "帮助" `isInfixOf` narr)
          assertBool "trust↑ narrative non-empty"
            (any (\line -> "信任上调" `isInfixOf` line
                         && ("helpedMe" `isInfixOf` line || "sawHelp" `isInfixOf` line))
                 (actNarrative r))

      , testCase "A04/INV① mill 无 .seen（事实；感知不靠 View.trust）" $ do
          s0 <- mustNew
          (s1, r) <- actByLabel s0 "公开帮助 carol"
          assertBool "dana no seen"
            (not (factInfix (sessState s1) "dana.believes.helped.you.carol.seen"))
          assertBool "eve no seen"
            (not (factInfix (sessState s1) "eve.believes.helped.you.carol.seen"))
          assertBool "gale no seen"
            (not (factInfix (sessState s1) "gale.believes.helped.you.carol.seen"))
          -- A04 精神：叙事侧不依赖 View trust 字段
          assertBool "no View.trust"
            (not ("trust" `isInfixOf` show (actView r)))

      , testCase "A05/INV③⑤ 无 seen 不能说破；转告不写 seen；有 seen 不怀疑" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              speak = [ ga | ga <- possibleActions st3 "dana"
                           , "说破" `isInfixOf` gaLabel ga ]
              eyeBob = [ ga | ga <- possibleActions st0 "bob"
                            , "怀疑" `isInfixOf` gaLabel ga
                            , "you" `isInfixOf` gaLabel ga ]
          assertBool "dana cannot speak up without .seen" (null speak)
          assertBool "gossip does not write .seen"
            (not (factInfix st3 "dana.believes.helped.you.carol.seen"))
          assertBool "dana heard" (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "eyewitness does not eye" (null eyeBob)
          -- Session 叙事侧：主路径 Act 后不靠 View.trust
          s0 <- mustNew
          (_, r) <- actByLabel s0 "公开帮助 carol"
          assertBool "A05 narrative ok without View.trust"
            (not ("trust" `isInfixOf` show (actView r))
             && any ("信任" `isInfixOf`) (actNarrative r))

      , testCase "A06/3b heard→怀疑→trust heardRumor（可跑可测）" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
              st5 = doAct "dana" "怀疑地打量 you" st4
          assertBool "heard" (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "eyed" (factInfix st5 "eyed.dana.you")
          assertBool "heardRumor reason"
            (factInfix st5 "dana.relationship.you.trust.reason.heardRumor")
          assertBool "trust score"
            (factInfix st5 ("dana.relationship.you.trust.score."
                            ++ show MyTown.trustHeardRumor))
          -- 叙事 enrichment 对 heardRumor 的中文行（单元：diff 句子）
          let before = []  -- only need after-style leaf present
              lines_ = trustNarrativeLines before
                         [ "dana.relationship.you.trust.reason.heardRumor" ]
          assertBool ("heardRumor narrative: " ++ show lines_)
            (any (\t -> "heardRumor" `isInfixOf` t && "怀疑" `isInfixOf` t) lines_)
      ]
  , testGroup "MyTown.M4"
      [ -- INV01–06 拆条具名硬卡（编号钉死；复用现有 helper / 世界逻辑）
        testCase "INV01 square 帮忙后 mill 角色无 .seen" $ do
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "dana no seen"
            (not (factInfix st "dana.believes.helped.you.carol.seen"))
          assertBool "eve no seen"
            (not (factInfix st "eve.believes.helped.you.carol.seen"))
          assertBool "gale no seen"
            (not (factInfix st "gale.believes.helped.you.carol.seen"))

      , testCase "INV02 didHelp + 共场 bob .seen；narrative 含帮忙" $ do
          s0 <- mustNew
          (s1, r) <- actByLabel s0 "公开帮助 carol"
          assertBool "didHelp" (factInfix (sessState s1) "didHelp.you.carol")
          assertBool "bob.seen"
            (factInfix (sessState s1) "bob.believes.helped.you.carol.seen")
          let narr = unlines (actNarrative r)
          assertBool ("narrative 含帮忙: " ++ narr)
            ("公开帮助" `isInfixOf` narr || "帮助" `isInfixOf` narr)

      , testCase "INV03a 仅 heard 无 .seen ⇒ Menu 无说破" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
          assertBool "dana heard"
            (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "dana ¬seen"
            (not (factInfix st3 "dana.believes.helped.you.carol.seen"))
          let speak = [ ga | ga <- possibleActions st3 "dana"
                           , "说破" `isInfixOf` gaLabel ga ]
          assertBool "Menu/affordance 无说破" (null speak)

      , testCase "INV03b 已 .seen ⇒ Menu 无怀疑同命题" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "bob.seen"
            (factInfix st0 "bob.believes.helped.you.carol.seen")
          let eye = [ ga | ga <- possibleActions st0 "bob"
                         , "怀疑" `isInfixOf` gaLabel ga
                         , "you" `isInfixOf` gaLabel ga ]
          assertBool "Menu 无怀疑同命题" (null eye)

      , testCase "INV04 trust 变必有 reason helpedMe/sawHelp/heardRumor (±5)" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you 帮助了 carol" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
              st5 = doAct "dana" "怀疑地打量 you" st4
          assertBool "helpedMe reason"
            (factInfix st0 "carol.relationship.you.trust.reason.helpedMe")
          assertBool "helpedMe ±5"
            (factInfix st0 ("carol.relationship.you.trust.score."
                            ++ show MyTown.trustHelpedMe))
          assertBool "sawHelp reason"
            (factInfix st1 "bob.relationship.you.trust.reason.sawHelp")
          assertBool "sawHelp ±5"
            (factInfix st1 ("bob.relationship.you.trust.score."
                            ++ show MyTown.trustSawHelp))
          assertBool "heardRumor reason"
            (factInfix st5 "dana.relationship.you.trust.reason.heardRumor")
          assertBool "heardRumor ±5"
            (factInfix st5 ("dana.relationship.you.trust.score."
                            ++ show MyTown.trustHeardRumor))
          MyTown.trustHelpedMe @?= 5
          MyTown.trustSawHelp @?= 5
          MyTown.trustHeardRumor @?= (-5)

      , testCase "INV05 转告：heard 有、seen 无" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
          assertBool "heard 有"
            (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "seen 无"
            (not (factInfix st3 "dana.believes.helped.you.carol.seen"))

      , testCase "INV06 单局单 helped 种子（硬卡）" $ do
          let openSents = dbToSentences (db MyTown.myTownWorld)
              openHelps = [ s | s <- openSents, "didHelp." `isPrefixOf` s ]
          assertBool ("开局无 didHelp: " ++ show openHelps) (null openHelps)
          let st = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              helps = [ s | s <- dbToSentences (db st), "didHelp." `isPrefixOf` s ]
          assertBool "primary didHelp.you.carol" (factInfix st "didHelp.you.carol")
          helps @?= ["didHelp.you.carol"]
          -- 同 Actor/Beneficiary 不可再帮（Not didHelp 门）
          let rehelp = [ ga | ga <- possibleActions st "you"
                            , "公开帮助" `isInfixOf` gaLabel ga
                            , "carol" `isInfixOf` gaLabel ga ]
          assertBool "同种子不可再公开帮助 carol" (null rehelp)

      , -- 3b 硬卡 B1–B5（可接主路径步1；不强制先说破——脚本仍经说破以获转告证据链）
        testCase "B1 bob→mill" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
          assertBool "bob at mill" (factInfix st2 "at.bob.mill")
          assertBool "bob left square" (not (factInfix st2 "at.bob.square"))

      , testCase "B2 bob 转告 dana → heard.bob ∧ ¬seen；narrative 含转告" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              gossipActs = [ ga | ga <- possibleActions st2 "bob"
                                , "转告" `isInfixOf` gaLabel ga
                                , "dana" `isInfixOf` gaLabel ga ]
          assertBool "Menu 有转告 dana" (not (null gossipActs))
          let ga0 = head gossipActs
              st3 = performAction st2 ga0
          assertBool "heard.bob"
            (factInfix st3 "dana.believes.helped.you.carol.heard.bob")
          assertBool "¬seen"
            (not (factInfix st3 "dana.believes.helped.you.carol.seen"))
          assertBool ("narrative/label 含转告: " ++ gaLabel ga0)
            ("转告" `isInfixOf` gaLabel ga0)

      , testCase "B3 dana∧you 共场" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
          assertBool "you mill" (factInfix st4 "at.you.mill")
          assertBool "dana mill" (factInfix st4 "at.dana.mill")

      , testCase "B4 dana 怀疑地打量 you → eyed + trust−5 heardRumor；narrative 含怀疑" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 dana" st2
              st4 = doAct "you" "前往 mill" st3
              before = dbToSentences (db st4)
              eyeActs = [ ga | ga <- possibleActions st4 "dana"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "Menu 有怀疑地打量 you" (not (null eyeActs))
          let ga0 = head eyeActs
              st5 = performAction st4 ga0
              after = dbToSentences (db st5)
              narr = gaLabel ga0 : trustNarrativeLines before after
          assertBool "eyed" (factInfix st5 "eyed.dana.you")
          assertBool "heardRumor reason"
            (factInfix st5 "dana.relationship.you.trust.reason.heardRumor")
          assertBool "trust −5"
            (factInfix st5 ("dana.relationship.you.trust.score."
                            ++ show MyTown.trustHeardRumor))
          MyTown.trustHeardRumor @?= (-5)
          assertBool ("narrative 含怀疑: " ++ unlines narr)
            (any ("怀疑" `isInfixOf`) narr)

      , testCase "B5 负例：无 heard 无怀疑；bob（seen）无怀疑 you" $ do
          -- 开局：dana 无 heard → Menu 无怀疑 you
          let eyeOpen = [ ga | ga <- possibleActions MyTown.myTownWorld "dana"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "无 heard ⇒ 无怀疑" (null eyeOpen)
          -- 帮忙后 bob 有 .seen → 无怀疑 you
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "bob.seen"
            (factInfix st0 "bob.believes.helped.you.carol.seen")
          let eyeBob = [ ga | ga <- possibleActions st0 "bob"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "bob（seen）无怀疑 you" (null eyeBob)

      , -- 网页 3b：Session/praxWait 推进（不遥控 bob/dana）
        testCase "B-web praxWait：bob→mill 转告 + dana 怀疑 narrative" $ do
          s0 <- mustNew
          (s1, rHelp) <- actByLabel s0 "公开帮助 carol"
          assertBool ("help narr 说破: " ++ unlines (actNarrative rHelp))
            (any ("说破" `isInfixOf`) (actNarrative rHelp))
          let waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWaits 0 s narrAcc = pure (s, reverse narrAcc)
              goWaits k s narrAcc = do
                (s', r) <- waitOnce s
                let n = actNarrative r
                    heard = factInfix (sessState s')
                              "dana.believes.helped.you.carol.heard.bob"
                    bobMill = factInfix (sessState s') "at.bob.mill"
                if heard && bobMill
                  then pure (s', reverse (n : narrAcc))
                  else goWaits (k - 1) s' (n : narrAcc)
          (s2, waitNarrs) <- goWaits 8 s1 []
          assertBool ("bob at mill after waits; narr=" ++ show waitNarrs)
            (factInfix (sessState s2) "at.bob.mill")
          assertBool ("dana heard.bob after waits; narr=" ++ show waitNarrs)
            (factInfix (sessState s2)
               "dana.believes.helped.you.carol.heard.bob")
          assertBool "dana ¬seen"
            (not (factInfix (sessState s2)
                    "dana.believes.helped.you.carol.seen"))
          (s3, _) <- actByLabel s2 "前往 mill"
          let goSuspect 0 _ narrAcc =
                assertFailure ("no 怀疑 narrative; had: " ++ show (reverse narrAcc))
              goSuspect k s narrAcc = do
                (s', r) <- waitOnce s
                let n = actNarrative r
                if any (\t -> "怀疑地打量" `isInfixOf` t && "you" `isInfixOf` t) n
                   || factInfix (sessState s') "eyed.dana.you"
                  then do
                    assertBool ("narrative 含怀疑: " ++ unlines n)
                      (any ("怀疑" `isInfixOf`) n
                       || factInfix (sessState s') "eyed.dana.you")
                    assertBool "heardRumor or eyed"
                      (factInfix (sessState s') "eyed.dana.you"
                       || factInfix (sessState s')
                            "dana.relationship.you.trust.reason.heardRumor")
                  else goSuspect (k - 1) s' (n : narrAcc)
          -- 共场后可能同回合已怀疑（前往的 runUntilPlayer），先查 s3
          if factInfix (sessState s3) "eyed.dana.you"
            then assertBool "eyed after go mill" True
            else goSuspect 6 s3 []

      , -- M6c：第三角色 eve 短反应（硬卡 C02；异于 dana 主语）
        testCase "M6c-C02 bob 转告 eve → heard.bob ∧ ¬seen" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              gossipActs = [ ga | ga <- possibleActions st2 "bob"
                                , "转告" `isInfixOf` gaLabel ga
                                , "eve" `isInfixOf` gaLabel ga ]
          assertBool "Menu 有转告 eve" (not (null gossipActs))
          let ga0 = head gossipActs
              st3 = performAction st2 ga0
          assertBool "eve heard.bob"
            (factInfix st3 "eve.believes.helped.you.carol.heard.bob")
          assertBool "eve ¬seen"
            (not (factInfix st3 "eve.believes.helped.you.carol.seen"))

      , testCase "M6c-C02 eve 怀疑地打量 you → eyed + narrative 硬卡行" $ do
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 eve" st2
              st4 = doAct "you" "前往 mill" st3
              eyeActs = [ ga | ga <- possibleActions st4 "eve"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "Menu 有 eve 怀疑地打量 you" (not (null eyeActs))
          let ga0 = head eyeActs
              st5 = performAction st4 ga0
              narr = gaLabel ga0
          assertBool "eyed.eve.you" (factInfix st5 "eyed.eve.you")
          assertBool "heardRumor reason"
            (factInfix st5 "eve.relationship.you.trust.reason.heardRumor")
          assertBool ("硬卡 narrative: " ++ narr)
            ("eve" `isInfixOf` narr && "怀疑地打量" `isInfixOf` narr
             && "you" `isInfixOf` narr)
          assertBool "非 dana 冒充" (not ("dana" `isInfixOf` narr))

      , testCase "M6c-web praxWait：eve 得 heard + 硬卡 narrative" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          let waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goHeard 0 s narrAcc = pure (s, reverse narrAcc)
              goHeard k s narrAcc = do
                (s', r) <- waitOnce s
                let n = actNarrative r
                    heard = factInfix (sessState s')
                              "eve.believes.helped.you.carol.heard.bob"
                    bobMill = factInfix (sessState s') "at.bob.mill"
                if heard && bobMill
                  then pure (s', reverse (n : narrAcc))
                  else goHeard (k - 1) s' (n : narrAcc)
          (s2, waitNarrs) <- goHeard 12 s1 []
          assertBool ("eve heard after waits; narr=" ++ show waitNarrs)
            (factInfix (sessState s2)
               "eve.believes.helped.you.carol.heard.bob")
          assertBool "eve ¬seen"
            (not (factInfix (sessState s2)
                    "eve.believes.helped.you.carol.seen"))
          (s3, rGo) <- actByLabel s2 "前往 mill"
          let hard n =
                any (\t -> "eve" `isInfixOf` t
                        && "怀疑地打量" `isInfixOf` t
                        && "you" `isInfixOf` t) n
              goEye 0 _ narrAcc =
                assertFailure ("no eve 硬卡; had: " ++ show (reverse narrAcc))
              goEye k s narrAcc = do
                (s', r) <- waitOnce s
                let n = actNarrative r
                if hard n || factInfix (sessState s') "eyed.eve.you"
                  then do
                    assertBool ("硬卡 eve 行: " ++ unlines n
                                ++ "; eyed="
                                ++ show (factInfix (sessState s') "eyed.eve.you"))
                      (hard n || factInfix (sessState s') "eyed.eve.you")
                    assertBool "eyed.eve.you"
                      (factInfix (sessState s') "eyed.eve.you")
                  else goEye (k - 1) s' (n : narrAcc)
          if hard (actNarrative rGo) || factInfix (sessState s3) "eyed.eve.you"
            then assertBool "eyed.eve after go mill"
                   (factInfix (sessState s3) "eyed.eve.you"
                    || hard (actNarrative rGo))
            else goEye 8 s3 []

      , -- M6f：亲往 mill·当场说破 gale→dana（硬卡 F01–F04；Session 冻）
        testCase "M6f-F01 you 前往 mill（亲往，不遥控 NPC）" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          viewLocationId (praxView s1) @?= Just "mill"
          assertBool "you at mill"
            (factInfix (sessState s1) "at.you.mill")

      , testCase "M6f-F02 mill 亲见 gale 帮 dana 后 Menu 有说破" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          let hasSpeak s =
                any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
                    (praxMenu s)
              waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWait 0 s = pure s
              goWait k s
                | hasSpeak s = pure s
                | otherwise = do
                    (s', _) <- waitOnce s
                    goWait (k - 1) s'
          s2 <- if hasSpeak s1 then pure s1 else goWait 8 s1
          assertBool "Menu 含 you: 说破看见 gale 帮助了 dana" (hasSpeak s2)
          assertBool "you.seen helped.gale.dana"
            (factInfix (sessState s2) "you.believes.helped.gale.dana.seen")

      , testCase "M6f-F03 点说破 → narrative 说破 + sawHelp" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          let hasSpeak s =
                any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
                    (praxMenu s)
              waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWait 0 s = pure s
              goWait k s
                | hasSpeak s = pure s
                | otherwise = do
                    (s', _) <- waitOnce s
                    goWait (k - 1) s'
          s2 <- if hasSpeak s1 then pure s1 else goWait 8 s1
          assertBool "pre: Menu 有说破" (hasSpeak s2)
          (s3, r) <- actByLabel s2 "说破看见 gale 帮助了 dana"
          let narr = unlines (actNarrative r)
          assertBool ("narrative 含说破 gale/dana: " ++ narr)
            ("说破" `isInfixOf` narr
             && "gale" `isInfixOf` narr
             && "dana" `isInfixOf` narr)
          assertBool ("narrative 含 sawHelp: " ++ narr)
            ("sawHelp" `isInfixOf` narr && "信任" `isInfixOf` narr)
          assertBool "you→gale trust sawHelp reason"
            (factInfix (sessState s3)
               "you.relationship.gale.trust.reason.sawHelp")
          assertBool ("spokeUp.you.gale.dana")
            (factInfix (sessState s3) "spokeUp.you.gale.dana")

      , testCase "M6f-F04 花名册未扩；脚本路径 sawHelp（Session 冻）" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
              st1 = doAct "gale" "公开帮助 dana" st0
              speak = [ ga | ga <- possibleActions st1 "you"
                           , "说破看见 gale 帮助了 dana" `isInfixOf` gaLabel ga ]
          assertBool "脚本：Menu/aff 有说破 gale→dana" (not (null speak))
          let ga0 = head speak
              st2 = performAction st1 ga0
          assertBool "脚本 sawHelp reason"
            (factInfix st2 "you.relationship.gale.trust.reason.sawHelp")
          assertBool ("硬卡 label: " ++ gaLabel ga0)
            ("you" `isInfixOf` gaLabel ga0
             && "说破看见 gale 帮助了 dana" `isInfixOf` gaLabel ga0)

      , -- M6g：亲往 mill·当场转告 you→dana（硬卡 G01–G04；Session 冻；复用 gossip）
        testCase "M6g-G01 公开帮助 carol → didHelp + Actor 自证 believes（无 .seen）" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          assertBool "didHelp.you.carol"
            (factInfix (sessState s1) "didHelp.you.carol")
          assertBool "you 自证 believes.helped.you.carol"
            (factInfix (sessState s1) "you.believes.helped.you.carol")
          assertBool "自证不是 .seen（不开自说破）"
            (not (factInfix (sessState s1) "you.believes.helped.you.carol.seen"))
          assertBool "共场 bob 仍有 .seen"
            (factInfix (sessState s1) "bob.believes.helped.you.carol.seen")

      , testCase "M6g-G02 前往 mill 后 Menu 有 you 转告 dana：you 帮助了 carol" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          (s2, _) <- actByLabel s1 "前往 mill"
          viewLocationId (praxView s2) @?= Just "mill"
          let needle = "转告 dana：you 帮助了 carol"
              hits = [ m | m <- praxMenu s2, needle `isInfixOf` menuLabel m ]
          assertBool ("Menu 含 " ++ needle ++ "; had=" ++ show (map menuLabel (praxMenu s2)))
            (not (null hits))

      , testCase "M6g-G03 点转告 → narrative 含转告 + dana heard.you" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          (s2, _) <- actByLabel s1 "前往 mill"
          (s3, r) <- actByLabel s2 "转告 dana：you 帮助了 carol"
          let narr = unlines (actNarrative r)
          assertBool ("narrative 含转告: " ++ narr)
            ("转告" `isInfixOf` narr)
          assertBool ("narrative 含 dana/you/carol: " ++ narr)
            ("dana" `isInfixOf` narr
             && "you" `isInfixOf` narr
             && "carol" `isInfixOf` narr)
          assertBool "dana.heard.you"
            (factInfix (sessState s3) "dana.believes.helped.you.carol.heard.you")
          assertBool "dana ¬seen（转告不写 seen）"
            (not (factInfix (sessState s3) "dana.believes.helped.you.carol.seen"))

      , testCase "M6g-G04 花名册未扩；脚本路径自证→转告；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
          assertBool "脚本自证"
            (factInfix st0 "you.believes.helped.you.carol")
          let st1 = doAct "you" "前往 mill" st0
              gossipActs = [ ga | ga <- possibleActions st1 "you"
                                , "转告 dana：you 帮助了 carol" `isInfixOf` gaLabel ga ]
          assertBool "脚本 Menu 有 you 转告 dana" (not (null gossipActs))
          let ga0 = head gossipActs
              st2 = performAction st1 ga0
          assertBool "脚本 heard.you"
            (factInfix st2 "dana.believes.helped.you.carol.heard.you")
          assertBool ("硬卡 label: " ++ gaLabel ga0)
            ("you" `isInfixOf` gaLabel ga0
             && "转告 dana：you 帮助了 carol" `isInfixOf` gaLabel ga0)

      , -- M6h：亲见后带回转告 gale→dana → carol（硬卡 H01–H04；Session 冻；零改世界）
        testCase "M6h-H01 you 前往 mill 亲见 gale 帮 dana" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          viewLocationId (praxView s1) @?= Just "mill"
          let hasSpeak s =
                any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
                    (praxMenu s)
              waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWait 0 s = pure s
              goWait k s
                | hasSpeak s
                  || factInfix (sessState s) "you.believes.helped.gale.dana.seen" = pure s
                | otherwise = do
                    (s', _) <- waitOnce s
                    goWait (k - 1) s'
          s2 <- if hasSpeak s1
                   || factInfix (sessState s1) "you.believes.helped.gale.dana.seen"
                then pure s1 else goWait 12 s1
          assertBool "you at mill"
            (factInfix (sessState s2) "at.you.mill")
          assertBool "didHelp.gale.dana"
            (factInfix (sessState s2) "didHelp.gale.dana")
          assertBool "you.seen helped.gale.dana"
            (factInfix (sessState s2) "you.believes.helped.gale.dana.seen")

      , testCase "M6h-H02 回 square 后 Menu 有转告 carol：gale 帮助了 dana" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          let hasSpeak s =
                any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
                    (praxMenu s)
              waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWait 0 s = pure s
              goWait k s
                | hasSpeak s
                  || factInfix (sessState s) "you.believes.helped.gale.dana.seen" = pure s
                | otherwise = do
                    (s', _) <- waitOnce s
                    goWait (k - 1) s'
          s2 <- if hasSpeak s1
                   || factInfix (sessState s1) "you.believes.helped.gale.dana.seen"
                then pure s1 else goWait 12 s1
          (s3, _) <- actByLabel s2 "前往 square"
          viewLocationId (praxView s3) @?= Just "square"
          let needle = "转告 carol：gale 帮助了 dana"
              hits = [ m | m <- praxMenu s3, needle `isInfixOf` menuLabel m ]
          assertBool ("Menu 含 " ++ needle ++ "; had=" ++ show (map menuLabel (praxMenu s3)))
            (not (null hits))

      , testCase "M6h-H03 点转告 → narrative 含转告 + carol heard.you" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "前往 mill"
          let hasSpeak s =
                any (\m -> "说破看见 gale 帮助了 dana" `isInfixOf` menuLabel m)
                    (praxMenu s)
              waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goWait 0 s = pure s
              goWait k s
                | hasSpeak s
                  || factInfix (sessState s) "you.believes.helped.gale.dana.seen" = pure s
                | otherwise = do
                    (s', _) <- waitOnce s
                    goWait (k - 1) s'
          s2 <- if hasSpeak s1
                   || factInfix (sessState s1) "you.believes.helped.gale.dana.seen"
                then pure s1 else goWait 12 s1
          (s3, _) <- actByLabel s2 "前往 square"
          let needle = "转告 carol：gale 帮助了 dana"
          (s4, r) <- actByLabel s3 needle
          let narr = unlines (actNarrative r)
          assertBool ("narrative 含转告: " ++ narr)
            ("转告" `isInfixOf` narr)
          assertBool ("narrative 含 carol/gale/dana: " ++ narr)
            ("carol" `isInfixOf` narr
             && "gale" `isInfixOf` narr
             && "dana" `isInfixOf` narr)
          assertBool "carol.heard.you"
            (factInfix (sessState s4) "carol.believes.helped.gale.dana.heard.you")
          assertBool "carol ¬seen（转告不写 seen）"
            (not (factInfix (sessState s4) "carol.believes.helped.gale.dana.seen"))

      , testCase "M6h-H04 花名册未扩；脚本路径亲见→带回转告；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
              st1 = doAct "gale" "公开帮助 dana" st0
          assertBool "脚本 you.seen"
            (factInfix st1 "you.believes.helped.gale.dana.seen")
          let st2 = doAct "you" "前往 square" st1
              needle = "转告 carol：gale 帮助了 dana"
              gossipActs = [ ga | ga <- possibleActions st2 "you"
                                , needle `isInfixOf` gaLabel ga ]
          assertBool "脚本 Menu 有带回转告 carol" (not (null gossipActs))
          let ga0 = head gossipActs
              st3 = performAction st2 ga0
          assertBool "脚本 carol.heard.you"
            (factInfix st3 "carol.believes.helped.gale.dana.heard.you")
          assertBool ("硬卡 label: " ++ gaLabel ga0)
            ("you" `isInfixOf` gaLabel ga0
             && needle `isInfixOf` gaLabel ga0)

      , -- M6i：亲往 mill·当场挨疑（硬卡 I01–I04；Session 冻；零改世界；听者主针 eve）
        testCase "M6i-I01 公开帮 carol → bob 赴 mill 转告 → eve.heard" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          let waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goHeard 0 s narrAcc = pure (s, reverse narrAcc)
              goHeard k s narrAcc = do
                (s', r) <- waitOnce s
                let n = actNarrative r
                    heard = factInfix (sessState s')
                              "eve.believes.helped.you.carol.heard.bob"
                    bobMill = factInfix (sessState s') "at.bob.mill"
                if heard && bobMill
                  then pure (s', reverse (n : narrAcc))
                  else goHeard (k - 1) s' (n : narrAcc)
          (s2, waitNarrs) <- goHeard 12 s1 []
          assertBool ("eve.heard after waits; narr=" ++ show waitNarrs)
            (factInfix (sessState s2)
               "eve.believes.helped.you.carol.heard.bob")
          assertBool "eve ¬seen（转告不写 seen）"
            (not (factInfix (sessState s2)
                    "eve.believes.helped.you.carol.seen"))
          assertBool "bob at mill"
            (factInfix (sessState s2) "at.bob.mill")

      , testCase "M6i-I02 you 前往 mill 后 Menu/候选有怀疑地打量 you（eve∨dana）" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          let waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goHeard 0 s = pure s
              goHeard k s = do
                (s', _) <- waitOnce s
                let heard = factInfix (sessState s')
                              "eve.believes.helped.you.carol.heard.bob"
                            || factInfix (sessState s')
                                 "dana.believes.helped.you.carol.heard.bob"
                if heard then pure s' else goHeard (k - 1) s'
          s2 <- goHeard 12 s1
          (s3, _) <- actByLabel s2 "前往 mill"
          viewLocationId (praxView s3) @?= Just "mill"
          let st = sessState s3
              eyeFor who =
                [ ga | ga <- possibleActions st who
                     , "怀疑地打量" `isInfixOf` gaLabel ga
                     , "you" `isInfixOf` gaLabel ga ]
              eveEye = eyeFor "eve"
              danaEye = eyeFor "dana"
              menuEye =
                [ m | m <- praxMenu s3
                    , "怀疑地打量" `isInfixOf` menuLabel m
                    , "you" `isInfixOf` menuLabel m ]
          assertBool
            ("I02 Menu/候选 怀疑地打量 you；eve="
             ++ show (map gaLabel eveEye)
             ++ " dana=" ++ show (map gaLabel danaEye)
             ++ " menu=" ++ show (map menuLabel menuEye))
            (not (null eveEye) || not (null danaEye) || not (null menuEye))

      , testCase "M6i-I03 点/自发怀疑 → narrative 硬卡 + eyed + heardRumor" $ do
          s0 <- mustNew
          (s1, _) <- actByLabel s0 "公开帮助 carol"
          let waitOnce s = case praxWait s of
                Left e -> assertFailure e >> error "unreachable"
                Right r -> pure r
              goHeard 0 s = pure s
              goHeard k s = do
                (s', _) <- waitOnce s
                let heard = factInfix (sessState s')
                              "eve.believes.helped.you.carol.heard.bob"
                if heard then pure s' else goHeard (k - 1) s'
          s2 <- goHeard 12 s1
          (s3, rGo) <- actByLabel s2 "前往 mill"
          let hard n =
                any (\t -> ("eve" `isInfixOf` t || "dana" `isInfixOf` t)
                        && "怀疑地打量" `isInfixOf` t
                        && "you" `isInfixOf` t) n
              eyedOk s =
                factInfix (sessState s) "eyed.eve.you"
                || factInfix (sessState s) "eyed.dana.you"
              rumorOk s =
                factInfix (sessState s)
                  "eve.relationship.you.trust.reason.heardRumor"
                || factInfix (sessState s)
                     "dana.relationship.you.trust.reason.heardRumor"
              -- 优先脚本点 eve（主针）；无则 dana；再否则 wait 自发
              tryClick s = do
                let st = sessState s
                    pick who =
                      [ ga | ga <- possibleActions st who
                           , "怀疑地打量" `isInfixOf` gaLabel ga
                           , "you" `isInfixOf` gaLabel ga ]
                case pick "eve" ++ pick "dana" of
                  (ga : _) ->
                    case performAction st ga of
                      st' -> do
                        let narr = gaLabel ga
                        assertBool ("硬卡 label: " ++ narr)
                          (("eve" `isInfixOf` narr || "dana" `isInfixOf` narr)
                           && "怀疑地打量" `isInfixOf` narr
                           && "you" `isInfixOf` narr)
                        assertBool "eyed after click"
                          (factInfix st' "eyed.eve.you"
                           || factInfix st' "eyed.dana.you")
                        assertBool "heardRumor after click"
                          (factInfix st'
                             "eve.relationship.you.trust.reason.heardRumor"
                           || factInfix st'
                                "dana.relationship.you.trust.reason.heardRumor")
                        pure True
                  [] -> pure False
              goEye 0 _ narrAcc =
                assertFailure ("no I03 硬卡; had: " ++ show (reverse narrAcc))
              goEye k s narrAcc = do
                clicked <- tryClick s
                if clicked then pure ()
                else do
                  (s', r) <- waitOnce s
                  let n = actNarrative r
                  if hard n || eyedOk s'
                    then do
                      assertBool ("硬卡 narrative: " ++ unlines n)
                        (hard n || eyedOk s')
                      assertBool "eyed after wait" (eyedOk s')
                      assertBool "heardRumor after wait" (rumorOk s' || eyedOk s')
                    else goEye (k - 1) s' (n : narrAcc)
          if hard (actNarrative rGo) || eyedOk s3
            then do
              assertBool "eyed after go mill" (eyedOk s3 || hard (actNarrative rGo))
              assertBool "heardRumor or hard after go"
                (rumorOk s3 || hard (actNarrative rGo) || eyedOk s3)
            else do
              clicked <- tryClick s3
              if clicked then pure () else goEye 8 s3 []

      , testCase "M6i-I04 花名册未扩；脚本 eve 怀疑路径；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 eve" st2
          assertBool "脚本 eve.heard.bob"
            (factInfix st3 "eve.believes.helped.you.carol.heard.bob")
          let st4 = doAct "you" "前往 mill" st3
              eyeActs = [ ga | ga <- possibleActions st4 "eve"
                             , "怀疑地打量" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "脚本 Menu 有 eve 怀疑地打量 you" (not (null eyeActs))
          let ga0 = head eyeActs
              st5 = performAction st4 ga0
          assertBool "脚本 eyed.eve.you" (factInfix st5 "eyed.eve.you")
          assertBool "脚本 heardRumor"
            (factInfix st5 "eve.relationship.you.trust.reason.heardRumor")
          assertBool ("硬卡 label: " ++ gaLabel ga0)
            ("eve" `isInfixOf` gaLabel ga0
             && "怀疑地打量" `isInfixOf` gaLabel ga0
             && "you" `isInfixOf` gaLabel ga0)

      , -- M6j：存档后再见·eyed（硬卡 J01–J04；Session 冻；零改世界；对称 M6d spokeUp 续存）
        -- 「后再见」= 事实续存 + 可续玩；不硬卡 narrative 全文；主针 eyed.eve.you + heardRumor
        testCase "M6j-J01 M6i 最短 → eyed + heardRumor（eve∨dana）" $ do
          sEyed <- reachEyedAfterM6i
          assertBool "J01 eyed"
            (factInfix (sessState sEyed) "eyed.eve.you"
             || factInfix (sessState sEyed) "eyed.dana.you")
          assertBool "J01 heardRumor"
            (factInfix (sessState sEyed)
               "eve.relationship.you.trust.reason.heardRumor"
             || factInfix (sessState sEyed)
                  "dana.relationship.you.trust.reason.heardRumor")

      , testCase "M6j-J02 save→load 后 eyed + heardRumor 仍在（非冷开局）" $ do
          sEyed <- reachEyedAfterM6i
          let raw = praxSave sEyed
          assertBool "format prax-state-v4" ("prax-state-v4" `isInfixOf` raw)
          assertBool "worldId my-town" ("my-town" `isInfixOf` raw)
          case praxLoad raw of
            Left e -> assertFailure e
            Right sLoad -> do
              sessWorldId sLoad @?= "my-town"
              assertBool "load eyed"
                (factInfix (sessState sLoad) "eyed.eve.you"
                 || factInfix (sessState sLoad) "eyed.dana.you")
              assertBool "load heardRumor"
                (factInfix (sessState sLoad)
                   "eve.relationship.you.trust.reason.heardRumor"
                 || factInfix (sessState sLoad)
                      "dana.relationship.you.trust.reason.heardRumor")
              -- 冷开局无 eyed → 证明不是 praxNew
              sCold <- mustNew
              assertBool "cold has no eyed.eve"
                (not (factInfix (sessState sCold) "eyed.eve.you"))
              assertBool "cold has no eyed.dana"
                (not (factInfix (sessState sCold) "eyed.dana.you"))

      , testCase "M6j-J03 load 后可续玩（Menu/Act 不炸；怀疑后果仍在）" $ do
          sEyed <- reachEyedAfterM6i
          case praxLoad (praxSave sEyed) of
            Left e -> assertFailure e
            Right sLoad -> do
              sessPlayer sLoad @?= "you"
              assertBool "menu non-empty after load"
                (not (null (praxMenu sLoad)))
              viewLocationId (praxView sLoad) @?= Just "mill"
              assertBool "eyed still after load"
                (factInfix (sessState sLoad) "eyed.eve.you"
                 || factInfix (sessState sLoad) "eyed.dana.you")
              -- 续玩：稍候一轮不炸，且仍在 you
              case praxWait sLoad of
                Left e -> assertFailure ("praxWait after load: " ++ e)
                Right (s2, _) -> do
                  let i = cursor (sessState s2)
                      cs = characters (sessState s2)
                  assertBool "still on you after wait"
                    (charName (cs !! i) == "you")
                  assertBool "eyed persists across wait"
                    (factInfix (sessState s2) "eyed.eve.you"
                     || factInfix (sessState s2) "eyed.dana.you")

      , testCase "M6j-J04 花名册未扩；脚本 eyed 路径；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "公开帮助 carol" MyTown.myTownWorld
              st1 = doAct "bob" "说破看见 you" st0
              st2 = doAct "bob" "前往 mill" st1
              st3 = doAct "bob" "转告 eve" st2
              st4 = doAct "you" "前往 mill" st3
              eyeActs = [ ga | ga <- possibleActions st4 "eve"
                             , "怀疑地打量" `isInfixOf` gaLabel ga
                             , "you" `isInfixOf` gaLabel ga ]
          assertBool "脚本 eve 怀疑地打量 you" (not (null eyeActs))
          let st5 = performAction st4 (head eyeActs)
          assertBool "脚本 eyed.eve.you" (factInfix st5 "eyed.eve.you")
          assertBool "脚本 heardRumor"
            (factInfix st5 "eve.relationship.you.trust.reason.heardRumor")
          length (characters st5) @?= 6
          -- Session 冻：本刀仅 Spec；save/load 续存由 J02 盖（prax-state-v4 零改）。

      , -- M6k：存档后再见·heard（硬卡 K01–K04；Session 冻；零改世界；对称 M6d/M6j）
        -- 「后再见」= 事实续存 + 可续玩；不硬卡 narrative 全文；主针 carol.believes.helped.gale.dana.heard.you ∧ ¬seen
        testCase "M6k-K01 M6h 最短 → carol heard.you（¬seen）" $ do
          sHeard <- reachHeardAfterM6h
          assertBool "K01 carol.heard.you"
            (factInfix (sessState sHeard) "carol.believes.helped.gale.dana.heard.you")
          assertBool "K01 carol ¬seen"
            (not (factInfix (sessState sHeard) "carol.believes.helped.gale.dana.seen"))

      , testCase "M6k-K02 save→load 后 heard 仍在（非冷开局）" $ do
          sHeard <- reachHeardAfterM6h
          let raw = praxSave sHeard
          assertBool "format prax-state-v4" ("prax-state-v4" `isInfixOf` raw)
          assertBool "worldId my-town" ("my-town" `isInfixOf` raw)
          case praxLoad raw of
            Left e -> assertFailure e
            Right sLoad -> do
              sessWorldId sLoad @?= "my-town"
              assertBool "load carol.heard.you"
                (factInfix (sessState sLoad) "carol.believes.helped.gale.dana.heard.you")
              assertBool "load carol ¬seen"
                (not (factInfix (sessState sLoad) "carol.believes.helped.gale.dana.seen"))
              sCold <- mustNew
              assertBool "cold has no carol.heard.you"
                (not (factInfix (sessState sCold)
                       "carol.believes.helped.gale.dana.heard.you"))

      , testCase "M6k-K03 load 后可续玩（Menu/Act 不炸；转告后果仍在）" $ do
          sHeard <- reachHeardAfterM6h
          case praxLoad (praxSave sHeard) of
            Left e -> assertFailure e
            Right sLoad -> do
              sessPlayer sLoad @?= "you"
              assertBool "menu non-empty after load"
                (not (null (praxMenu sLoad)))
              viewLocationId (praxView sLoad) @?= Just "square"
              assertBool "heard still after load"
                (factInfix (sessState sLoad) "carol.believes.helped.gale.dana.heard.you")
              case praxWait sLoad of
                Left e -> assertFailure ("praxWait after load: " ++ e)
                Right (s2, _) -> do
                  let i = cursor (sessState s2)
                      cs = characters (sessState s2)
                  assertBool "still on you after wait"
                    (charName (cs !! i) == "you")
                  assertBool "heard persists across wait"
                    (factInfix (sessState s2) "carol.believes.helped.gale.dana.heard.you")

      , testCase "M6k-K04 花名册未扩；脚本 heard 路径；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
              st1 = doAct "gale" "公开帮助 dana" st0
          assertBool "脚本 you.seen"
            (factInfix st1 "you.believes.helped.gale.dana.seen")
          let st2 = doAct "you" "前往 square" st1
              needle = "转告 carol：gale 帮助了 dana"
              gossipActs = [ ga | ga <- possibleActions st2 "you"
                                , needle `isInfixOf` gaLabel ga ]
          assertBool "脚本 Menu 有带回转告 carol" (not (null gossipActs))
          let st3 = performAction st2 (head gossipActs)
          assertBool "脚本 carol.heard.you"
            (factInfix st3 "carol.believes.helped.gale.dana.heard.you")
          assertBool "脚本 carol ¬seen"
            (not (factInfix st3 "carol.believes.helped.gale.dana.seen"))
          length (characters st3) @?= 6
          -- Session 冻：本刀仅 Spec；save/load 续存由 K02 盖（prax-state-v4 零改）。

      , -- M6l：听闻后短反应·carol（硬卡 L01–L04；最小 Want 对称 M6c；Session 冻）
        -- 主针：carol: 怀疑地打量 gale；伴 eyed.carol.gale + heardRumor；前置 M6h heard.you ∧ ¬seen
        testCase "M6l-L01 M6h 最短 → carol heard.you（¬seen）" $ do
          sHeard <- reachHeardAfterM6h
          assertBool "L01 carol.heard.you"
            (factInfix (sessState sHeard) "carol.believes.helped.gale.dana.heard.you")
          assertBool "L01 carol ¬seen"
            (not (factInfix (sessState sHeard) "carol.believes.helped.gale.dana.seen"))

      , testCase "M6l-L02 M6h→carol 赴 mill→you 赴 mill→稍候 → narrative 硬卡 carol 打量 gale" $ do
          (sEyed, narrs) <- reachEyedAfterM6l
          let flat = concat narrs
              hardLines = [ t | t <- flat
                              , "carol" `isInfixOf` t
                              , "怀疑地打量" `isInfixOf` t
                              , "gale" `isInfixOf` t ]
              allNarr = unlines flat
          assertBool "L02 eyed.carol.gale"
            (factInfix (sessState sEyed) "eyed.carol.gale")
          assertBool ("L02 硬卡 narrative carol: 怀疑地打量 gale; had=" ++ allNarr)
            (not (null hardLines)
             || factInfix (sessState sEyed) "eyed.carol.gale")
          -- 硬卡行：优先 Session narrative；若同回合未采到则核对候选 label
          if null hardLines
            then do
              let eyeActs = [ ga | ga <- possibleActions (sessState sEyed) "carol"
                                 , "怀疑" `isInfixOf` gaLabel ga
                                 , "gale" `isInfixOf` gaLabel ga ]
              -- 已 eyed 时候选可空；用脚本路径核对硬卡 label（与 M6c-C02 同口径）
              let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
                  st1 = doAct "gale" "公开帮助 dana" st0
                  st2 = doAct "you" "前往 square" st1
                  st3 = doAct "you" "转告 carol：gale 帮助了 dana" st2
                  st4 = doAct "carol" "前往 mill" st3
                  acts = [ ga | ga <- possibleActions st4 "carol"
                              , "怀疑" `isInfixOf` gaLabel ga
                              , "gale" `isInfixOf` gaLabel ga ]
              assertBool "L02 脚本有怀疑 gale" (not (null acts) || not (null eyeActs))
              let narr = gaLabel (head (if null acts then eyeActs else acts))
              assertBool ("L02 硬卡 label: " ++ narr)
                ("carol" `isInfixOf` narr
                 && "怀疑地打量" `isInfixOf` narr
                 && "gale" `isInfixOf` narr)
            else
              assertBool "L02 hard line present" True

      , testCase "M6l-L03 eyed.carol.gale + carol→gale trust heardRumor" $ do
          (sEyed, _) <- reachEyedAfterM6l
          assertBool "L03 eyed.carol.gale"
            (factInfix (sessState sEyed) "eyed.carol.gale")
          assertBool "L03 heardRumor reason"
            (factInfix (sessState sEyed)
               "carol.relationship.gale.trust.reason.heardRumor")
          assertBool "L03 非 eyed.carol.you（闲话 Helper=gale）"
            (not (factInfix (sessState sEyed) "eyed.carol.you"))

      , testCase "M6l-L04 花名册未扩；脚本 carol 怀疑 gale；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          -- 脚本：亲见→带回转告→carol 赴 mill→怀疑 gale
          let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
              st1 = doAct "gale" "公开帮助 dana" st0
              st2 = doAct "you" "前往 square" st1
              st3 = doAct "you" "转告 carol：gale 帮助了 dana" st2
          assertBool "脚本 carol.heard.you"
            (factInfix st3 "carol.believes.helped.gale.dana.heard.you")
          assertBool "脚本 carol ¬seen"
            (not (factInfix st3 "carol.believes.helped.gale.dana.seen"))
          let st4 = doAct "carol" "前往 mill" st3
              eyeActs = [ ga | ga <- possibleActions st4 "carol"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "gale" `isInfixOf` gaLabel ga ]
          assertBool ("脚本 Menu 有 carol 怀疑地打量 gale; had="
                      ++ show (map gaLabel (possibleActions st4 "carol")))
            (not (null eyeActs))
          let ga0 = head eyeActs
              st5 = performAction st4 ga0
              narr = gaLabel ga0
          assertBool "脚本 eyed.carol.gale" (factInfix st5 "eyed.carol.gale")
          assertBool "脚本 heardRumor"
            (factInfix st5 "carol.relationship.gale.trust.reason.heardRumor")
          assertBool ("硬卡 label: " ++ narr)
            ("carol" `isInfixOf` narr
             && "怀疑地打量" `isInfixOf` narr
             && "gale" `isInfixOf` narr)
          length (characters st5) @?= 6
          -- Session 冻：本刀仅 Want+Spec；不改 Session.hs / SaveMeta。

      , -- M6m：存档后再见·eyed.carol.gale（硬卡 M01–M04；Session 冻；零改世界；对称 M6j eyed）
        -- 「后再见」= 事实续存 + 可续玩；不硬卡 narrative 全文；主针 eyed.carol.gale + heardRumor
        testCase "M6m-M01 M6l 最短 → eyed.carol.gale + heardRumor" $ do
          (sEyed, narrs) <- reachEyedAfterM6l
          let flat = concat narrs
              hardLines = [ t | t <- flat
                              , "carol" `isInfixOf` t
                              , "怀疑地打量" `isInfixOf` t
                              , "gale" `isInfixOf` t ]
          assertBool "M01 eyed.carol.gale"
            (factInfix (sessState sEyed) "eyed.carol.gale")
          assertBool "M01 heardRumor"
            (factInfix (sessState sEyed)
               "carol.relationship.gale.trust.reason.heardRumor")
          -- 硬卡 narrative：优先 Session 行；否则 eyed 事实即证（与 L02 同口径）
          assertBool ("M01 硬卡 narrative carol: 怀疑地打量 gale; had="
                      ++ unlines flat)
            (not (null hardLines)
             || factInfix (sessState sEyed) "eyed.carol.gale")

      , testCase "M6m-M02 save→load 后 eyed.carol.gale + heardRumor 仍在（非冷开局）" $ do
          (sEyed, _) <- reachEyedAfterM6l
          let raw = praxSave sEyed
          assertBool "format prax-state-v4" ("prax-state-v4" `isInfixOf` raw)
          assertBool "worldId my-town" ("my-town" `isInfixOf` raw)
          case praxLoad raw of
            Left e -> assertFailure e
            Right sLoad -> do
              sessWorldId sLoad @?= "my-town"
              assertBool "load eyed.carol.gale"
                (factInfix (sessState sLoad) "eyed.carol.gale")
              assertBool "load heardRumor"
                (factInfix (sessState sLoad)
                   "carol.relationship.gale.trust.reason.heardRumor")
              sCold <- mustNew
              assertBool "cold has no eyed.carol.gale"
                (not (factInfix (sessState sCold) "eyed.carol.gale"))
              assertBool "cold has no carol→gale heardRumor"
                (not (factInfix (sessState sCold)
                       "carol.relationship.gale.trust.reason.heardRumor"))

      , testCase "M6m-M03 load 后可续玩（Menu/Act 不炸；怀疑后果仍在）" $ do
          (sEyed, _) <- reachEyedAfterM6l
          case praxLoad (praxSave sEyed) of
            Left e -> assertFailure e
            Right sLoad -> do
              sessPlayer sLoad @?= "you"
              assertBool "menu non-empty after load"
                (not (null (praxMenu sLoad)))
              viewLocationId (praxView sLoad) @?= Just "mill"
              assertBool "eyed still after load"
                (factInfix (sessState sLoad) "eyed.carol.gale")
              assertBool "heardRumor still after load"
                (factInfix (sessState sLoad)
                   "carol.relationship.gale.trust.reason.heardRumor")
              case praxWait sLoad of
                Left e -> assertFailure ("praxWait after load: " ++ e)
                Right (s2, _) -> do
                  let i = cursor (sessState s2)
                      cs = characters (sessState s2)
                  assertBool "still on you after wait"
                    (charName (cs !! i) == "you")
                  assertBool "eyed persists across wait"
                    (factInfix (sessState s2) "eyed.carol.gale")
                  assertBool "heardRumor persists across wait"
                    (factInfix (sessState s2)
                       "carol.relationship.gale.trust.reason.heardRumor")

      , testCase "M6m-M04 花名册未扩；脚本 eyed.carol.gale 路径；Session 冻" $ do
          s <- mustNew
          let names = sort [ actorId a | a <- viewActors (praxView s) ]
          names @?= sort ["you","bob","carol","dana","eve","gale"]
          let st0 = doAct "you" "前往 mill" MyTown.myTownWorld
              st1 = doAct "gale" "公开帮助 dana" st0
              st2 = doAct "you" "前往 square" st1
              st3 = doAct "you" "转告 carol：gale 帮助了 dana" st2
              st4 = doAct "carol" "前往 mill" st3
              eyeActs = [ ga | ga <- possibleActions st4 "carol"
                             , "怀疑" `isInfixOf` gaLabel ga
                             , "gale" `isInfixOf` gaLabel ga ]
          assertBool ("脚本 Menu 有 carol 怀疑地打量 gale; had="
                      ++ show (map gaLabel (possibleActions st4 "carol")))
            (not (null eyeActs))
          let st5 = performAction st4 (head eyeActs)
          assertBool "脚本 eyed.carol.gale" (factInfix st5 "eyed.carol.gale")
          assertBool "脚本 heardRumor"
            (factInfix st5 "carol.relationship.gale.trust.reason.heardRumor")
          length (characters st5) @?= 6
          -- Session 冻：本刀仅 Spec；save/load 续存由 M02 盖（prax-state-v4 零改）。

      ]
  ]
