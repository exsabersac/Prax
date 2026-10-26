-- | 编年史家 / 显著性查询（Tier 3 宿主边界）：事件流上的派生摘要。
--
-- 不增加引擎机制——只读既有信念存款（"Prax.Witness"/"Prax.Rumor" 的
-- @.seen@\/@.heard.\<src\>@）与派生站队（"Prax.Repute" 的 @regards@\/@notorious@），
-- 向宿主游戏提供任务钩与「无人能见的涌现之答」查询表面。事实仍只活在 DB 中；
-- 本模块从不写入。
module Prax.Chronicle
  ( Provenance (..)
  , EventRecord (..)
  , TaskHook (..)
  , chronicleEvents
  , salientEvents
  , knowerCount
  , regardingHooks
  , notorietyHooks
  , summarize
  , askChronicle
  ) where

import           Data.List (foldl', intercalate, isPrefixOf, isSuffixOf, nub, sort)
import           Data.Maybe (mapMaybe)
import qualified Data.Map.Strict as Map

import           Prax.Db (Bindings, Db, dbToSentences, unify, valToString)
import           Prax.Sym (intern)
import           Prax.Types (PraxState (..), readView)

-- | 信念出处：直接目击，或具名来源的传闻。
data Provenance
  = Seen
  | Heard String
  deriving (Eq, Ord, Show)

-- | 某人对某事件的一条证据记录。
data EventRecord = EventRecord
  { erKnower     :: String
  , erEvent      :: String
  , erProvenance :: Provenance
  }
  deriving (Eq, Ord, Show)

-- | 宿主可挂接的任务钩：从站队 / 臭名派生，不声称新虚构真理。
data TaskHook
  = RegardHook String String String
    -- ^ observer, subject, label
  | NotoriousHook String String
    -- ^ subject, label
  deriving (Eq, Ord, Show)

-- | 扫描基库中所有 @\<who\>.believes.\<event\>.(seen|heard.\<src\>)@ 信念。
chronicleEvents :: Db -> [EventRecord]
chronicleEvents d = mapMaybe parseBelief (dbToSentences d)

parseBelief :: String -> Maybe EventRecord
parseBelief s =
  case breakOn ".believes." s of
    Nothing -> Nothing
    Just (who, rest)
      | null who || null rest -> Nothing
      | ".seen" `isSuffix` rest
      , let event = take (length rest - length ".seen") rest
      , not (null event)
        -> Just (EventRecord who event Seen)
      | Just (event, src) <- breakOnLast ".heard." rest
      , not (null event), not (null src)
      , '.' `notElem` src
        -> Just (EventRecord who event (Heard src))
      | otherwise -> Nothing

-- | 至少 @k@ 名不同知情者持有证据的事件（显著性阈值）。
salientEvents :: Int -> Db -> [(String, [EventRecord])]
salientEvents k d =
  [ (ev, rs) | (ev, rs) <- Map.toList grouped, length (nub (map erKnower rs)) >= k ]
  where
    grouped = foldl' ins Map.empty (chronicleEvents d)
    ins m r = Map.insertWith (++) (erEvent r) [r] m

-- | 对给定事件有证据的知情者人数。
knowerCount :: String -> Db -> Int
knowerCount event d =
  length $ nub [ erKnower r | r <- chronicleEvents d, erEvent r == event ]

lookupVal :: String -> Bindings -> Maybe String
lookupVal k b = valToString <$> Map.lookup (intern k) b

-- | 从闭合视图读取 @regards@ 派生站队，生成按观察者的任务钩。
regardingHooks :: PraxState -> [TaskHook]
regardingHooks st =
  [ RegardHook o s l
  | b <- unify "regards.O.S.L" (readView st) Map.empty
  , Just o <- [lookupVal "O" b]
  , Just s <- [lookupVal "S" b]
  , Just l <- [lookupVal "L" b]
  ]

-- | 从闭合视图读取 @notorious@，生成公共任务钩。
notorietyHooks :: PraxState -> [TaskHook]
notorietyHooks st =
  [ NotoriousHook s l
  | b <- unify "notorious.S.L" (readView st) Map.empty
  , Just s <- [lookupVal "S" b]
  , Just l <- [lookupVal "L" b]
  ]

-- | 人类可读摘要行（CLI / Inspect 接线）。
summarize :: PraxState -> [String]
summarize st =
  eventLines ++ regardLines ++ notoriousLines
  where
    d = db st
    eventLines =
      [ formatEvent ev rs
      | (ev, rs) <- sort (salientEvents 1 d) ]
    regardLines =
      [ o ++ " regards " ++ s ++ " as " ++ l
      | RegardHook o s l <- sort (regardingHooks st) ]
    notoriousLines =
      [ s ++ " is notorious as " ++ l
      | NotoriousHook s l <- sort (notorietyHooks st) ]

formatEvent :: String -> [EventRecord] -> String
formatEvent ev rs =
  ev ++ " (" ++ intercalate ", " (map fmt (sort rs)) ++ ")"
  where
    fmt r = case erProvenance r of
      Seen      -> erKnower r ++ " saw"
      Heard src -> erKnower r ++ " heard via " ++ src

-- | 涌现问答入口：宿主用关键词查询编年摘要。
--
-- 支持：@"who knows "++event@、@"what is notorious"@、@"regards of "++subject@、
-- @"salient "++show k@、@"feelings of "++who@、@"mood of "++who@、@"leads of "++faction@、@"affiliates of "++who@、@"members of "++faction@、@"debts of "++who@、
-- @"arc of "++who@、@"age of "++who@、@"siblings of "++who@、
-- @"branded of "++who@、@"revoked of "++who@、
-- @"confessed of "++who@、@"recanted of "++who@、@"ostracized of "++who@、@"exiled of "++who@、
-- @"denounced of "++who@、@"censured of "++who@、@"paraded of "++who@、
-- @"cried of "++who@、@"rallied of "++who@、@"fled of "++who@、@"reconciled of "++who@、@"married of "++who@、
-- @"eyed of "++who@、@"confronted of "++who@、@"atoned of "++who@、
-- @"wronged of "++who@、@"hungry of "++who@、
-- @"shortTempered of "++who@、@"appetite of "++who@、
-- @"resents of "++who@、@"allied of "++who@、
-- @"what is on the stall"@、@"what festivals"@。
askChronicle :: PraxState -> String -> [String]
askChronicle st q
  | Just event <- stripPrefix "who knows " q =
      let knowers = nub [ erKnower r | r <- chronicleEvents (db st), erEvent r == event ]
      in if null knowers
           then ["nobody is known to know " ++ event]
           else map (++ (" knows " ++ event)) (sort knowers)
  | q == "what is notorious" =
      let hs = notorietyHooks st
      in if null hs then ["nothing is notorious"]
         else [ s ++ " as " ++ l | NotoriousHook s l <- sort hs ]
  | Just subj <- stripPrefix "regards of " q =
      let hs = [ h | h@(RegardHook _ s _) <- regardingHooks st, s == subj ]
      in if null hs then ["nobody regards " ++ subj]
         else [ o ++ " as " ++ l | RegardHook o _ l <- sort hs ]
  | Just ks <- stripPrefix "salient " q
  , [(k, "")] <- reads ks =
      [ ev ++ " (" ++ show (length (nub (map erKnower rs))) ++ " knowers)"
      | (ev, rs) <- sort (salientEvents k (db st)) ]
  | Just who <- stripPrefix "debts of " q =
      let prefix = "debt."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 3
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no debts on record"]
         else rows
  | Just faction <- stripPrefix "leads of " q =
      -- dbToSentences 把 ! 展成 .；排他叶 leads.<faction>!<who> 显示为 leads.<faction>.<who>
      let prefix = "leads." ++ faction ++ "."
          ls = sort [ drop (length prefix) s
                    | s <- dbToSentences (db st), prefix `isPrefixOf` s
                    , '.' `notElem` drop (length prefix) s ]
      in if null ls then ["nobody leads " ++ faction]
         else map (++ (" leads " ++ faction)) ls
  | Just who <- stripPrefix "affiliates of " q =
      let prefix = "affiliate." ++ who ++ "."
          fs = sort [ drop (length prefix) s
                    | s <- dbToSentences (db st), prefix `isPrefixOf` s ]
      in if null fs then [who ++ " has no affiliates"]
         else map ((who ++ " affiliates ") ++) fs
  | Just faction <- stripPrefix "members of " q =
      -- member.<who>!<faction> 展成 member.<who>.<faction>
      let suffix = "." ++ faction
          ms = sort
            [ take (length rest - length suffix) rest
            | s <- dbToSentences (db st)
            , let pref = "member."
            , pref `isPrefixOf` s
            , let rest = drop (length pref) s
            , suffix `isSuffixOf` rest
            , let who = take (length rest - length suffix) rest
            , not (null who)
            , '.' `notElem` who ]
      in if null ms then ["nobody is a member of " ++ faction]
         else map (++ (" is a member of " ++ faction)) ms
  | Just who <- stripPrefix "feelings of " q =
      let prefix = who ++ ".feels."
          fs = sort [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s ]
      in if null fs then [who ++ " has no recorded feelings"]
         else fs
  | Just who <- stripPrefix "mood of " q =
      let prefix = "mood." ++ who ++ "."
          ms = sort [ drop (length prefix) s
                    | s <- dbToSentences (db st), prefix `isPrefixOf` s
                    , '.' `notElem` drop (length prefix) s ]
      in if null ms then [who ++ " has no baseline mood"]
         else map ((who ++ " mood ") ++) ms
  | Just who <- stripPrefix "arc of " q =
      let prefix = who ++ ".arc."
          stages = sort [ drop (length prefix) s
                        | s <- dbToSentences (db st), prefix `isPrefixOf` s
                        , '.' `notElem` drop (length prefix) s ]
      in if null stages then [who ++ " has no arc stage"]
         else map ((who ++ " arc ") ++) stages
  | Just who <- stripPrefix "age of " q =
      let prefix = "age." ++ who ++ "."
          ages = sort [ drop (length prefix) s
                      | s <- dbToSentences (db st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null ages then [who ++ " has no recorded age"]
         else map ((who ++ " age ") ++) ages
  | Just who <- stripPrefix "siblings of " q =
      let prefix = "sibling." ++ who ++ "."
          sibs = sort [ drop (length prefix) s
                      | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null sibs then [who ++ " has no known siblings"]
         else map ((who ++ " sibling ") ++) sibs
  | Just who <- stripPrefix "branded of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , let parts = splitDot s
                , length parts >= 2
                , "branded" `isPrefixOf` head parts
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no brand marks"]
         else rows
  | Just who <- stripPrefix "revoked of " q =
      let prefix = "revoked."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no revoked deals"]
         else rows
  | Just who <- stripPrefix "confessed of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , let parts = splitDot s
                , length parts >= 2
                , (head parts == "confessed" && (parts !! 1) == who)
                  || (head parts == who && (parts !! 1) == "confessed") ]
      in if null rows then [who ++ " has no confessions on record"]
         else rows
  | Just who <- stripPrefix "recanted of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("recanted." ++ who)
                  || ("recanted." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no recantation on record"]
         else rows
  | Just who <- stripPrefix "ostracized of " q =
      let prefix = "ostracized."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no ostracize marks"]
         else rows
  | Just who <- stripPrefix "exiled of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("exiled." ++ who)
                  || ("exiled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no exile mark"]
         else rows
  | Just who <- stripPrefix "denounced of " q =
      let prefix = "denounced."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no denounce marks"]
         else rows
  | Just who <- stripPrefix "censured of " q =
      let prefix = "censured."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no censure marks"]
         else rows
  | Just who <- stripPrefix "paraded of " q =
      let prefix = "paraded."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no parade marks"]
         else rows
  | Just who <- stripPrefix "cried of " q =
      let prefix = "cried."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no cry marks"]
         else rows
  | Just who <- stripPrefix "rallied of " q =
      let prefix = "rallied."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no rally marks"]
         else rows
  | Just who <- stripPrefix "fled of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("fled." ++ who)
                  || ("fled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no flee mark"]
         else rows
  | Just who <- stripPrefix "reconciled of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("reconciled." ++ who)
                  || ("reconciled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no reconcile mark"]
         else rows
  | Just who <- stripPrefix "married of " q =
      let prefix = "married."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no marriage marks"]
         else rows
  | Just who <- stripPrefix "eyed of " q =
      let prefix = "eyed."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no eye marks"]
         else rows
  | Just who <- stripPrefix "confronted of " q =
      let prefix = "confronted."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no confront marks"]
         else rows
  | Just who <- stripPrefix "atoned of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("atoned." ++ who)
                  || ("atoned." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no atonement on record"]
         else rows
  | Just who <- stripPrefix "wronged of " q =
      let prefix = "wronged."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no wrong marks"]
         else rows
  | Just who <- stripPrefix "hungry of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("hungry." ++ who)
                  || ("hungry." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no hunger mark"]
         else rows
  | Just who <- stripPrefix "shortTempered of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("shortTempered." ++ who)
                  || ("shortTempered." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no short-temper mark"]
         else rows
  | Just who <- stripPrefix "appetite of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , s == ("appetite." ++ who)
                  || ("appetite." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no appetite mark"]
         else rows
  | Just who <- stripPrefix "resents of " q =
      let rows = sort
            [ s | s <- dbToSentences (db st)
                , ("resents." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no resentment marks"]
         else rows
  | Just who <- stripPrefix "allied of " q =
      let prefix = "allied."
          rows = sort
            [ s | s <- dbToSentences (db st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no alliance marks"]
         else rows
  | q == "what is on the stall" =
      let rows = sort
            [ s | s <- dbToSentences (db st), "stall." `isPrefixOf` s ]
      in if null rows then ["the stall is empty"]
         else rows
  | q == "what festivals" =
      let rows = sort
            [ s | s <- dbToSentences (db st), "festival." `isPrefixOf` s ]
      in if null rows then ["no festivals are open"]
         else rows
  | otherwise = ["chronicle: unknown query " ++ show q]

-- helpers ----------------------------------------------------------------------

splitDot :: String -> [String]
splitDot = filter (not . null) . go
  where
    go s = case break (== '.') s of
      (a, '.' : b) -> a : go b
      (a, _)       -> [a]

breakOn :: String -> String -> Maybe (String, String)
breakOn sep str =
  case findSub str of
    Nothing -> Nothing
    Just i  -> Just (take i str, drop (i + length sep) str)
  where
    findSub s
      | sep `isPrefixOf` s = Just 0
      | null s             = Nothing
      | otherwise          = fmap (+ 1) (findSub (tail s))

breakOnLast :: String -> String -> Maybe (String, String)
breakOnLast sep str =
  case [ i | i <- [0 .. length str - length sep]
           , take (length sep) (drop i str) == sep ] of
    [] -> Nothing
    is -> let i = last is
          in Just (take i str, drop (i + length sep) str)

isSuffix :: String -> String -> Bool
isSuffix suf s = reverse suf `isPrefixOf` reverse s

stripPrefix :: String -> String -> Maybe String
stripPrefix pref s
  | pref `isPrefixOf` s = Just (drop (length pref) s)
  | otherwise           = Nothing
