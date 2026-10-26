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
-- 支持：@"who knows "++event@、@"what is notorious"@、@"regards of "++subject@、@"regards by "++who@、
-- @"salient "++show k@、@"feelings of "++who@、@"mood of "++who@、@"moods of "++who@、@"leads of "++faction@、@"leaders of "++faction@、@"affiliates of "++who@、@"members of "++faction@、@"debts of "++who@、@"creditors of "++who@、@"debtors of "++who@、@"creditors of "++who@、@"debtors of "++who@、
-- @"arc of "++who@、@"arcs of "++who@、@"age of "++who@、@"ages of "++who@、@"siblings of "++who@、@"parents of "++who@、@"children of "++who@、@"grandparents of "++who@、@"grandchildren of "++who@、@"in-laws of "++who@、@"spouses of "++who@、
-- @"branded of "++who@、@"revoked of "++who@、@"revokers of "++who@、@"revokees of "++who@、
-- @"confessed of "++who@、@"recanted of "++who@、@"ostracized of "++who@、@"ostracizers of "++who@、@"ostracizees of "++who@、@"exiled of "++who@、
-- @"denounced of "++who@、@"denouncers of "++who@、@"denouncees of "++who@、@"censured of "++who@、@"censurers of "++who@、@"censurees of "++who@、@"paraded of "++who@、@"paraders of "++who@、@"paradees of "++who@、
-- @"cried of "++who@、@"criers of "++who@、@"criees of "++who@、@"rallied of "++who@、@"ralliers of "++who@、@"ralliees of "++who@、@"fled of "++who@、@"reconciled of "++who@、@"married of "++who@、
-- @"eyed of "++who@、@"eyers of "++who@、@"eyees of "++who@、@"confronted of "++who@、@"confronters of "++who@、@"confrontees of "++who@、@"atoned of "++who@、
-- @"wronged of "++who@、@"wrongers of "++who@、@"wrongees of "++who@、@"hungry of "++who@、
-- @"shortTempered of "++who@、@"short-tempered of "++who@、@"appetite of "++who@、
-- @"resents of "++who@、@"resenters of "++who@、@"allied of "++who@、@"allies of "++who@、
-- @"what is on the stall"@、@"what festivals"@、
-- @"holding of "++who@、@"carrying of "++who@、
-- @"threatened of "++who@、@"threateners of "++who@、@"threatenees of "++who@、@"shunned of "++who@、@"shunners of "++who@、
-- @"locations of "++who@、@"occupants of "++place@、@"demanded of "++who@、@"demanders of "++who@、@"demandees of "++who@、
-- @"extorted of "++who@、@"extorters of "++who@、@"extortees of "++who@、@"complied of "++who@、@"compliers of "++who@、@"compliees of "++who@、@"defied of "++who@、@"defiers of "++who@、@"defiees of "++who@、
-- @"obligations of "++who@、@"breaches of "++who@、
-- @"lies of "++who@、@"liars of "++who@、@"chatted with "++who@、@"chatters of "++who@、@"traits of "++who@、
-- @"bonds of "++who@、@"bonders of "++who@、@"esteemed of "++who@、@"esteemers of "++who@、@"scorned of "++who@、@"scorners of "++who@、
-- @"beliefs of "++who@、@"projects of "++who@、
-- @"kin of "++who@、@"notorious of "++who@、
-- @"regards toward "++who@、@"what factions"@。
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
  | Just who <- stripPrefix "regards by " q =
      -- 对齐 Host regardsOf：观察者发出的站队原始叶。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("regards." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " regards nobody"]
         else rows
  | Just subj <- stripPrefix "regards of " q =
      let hs = [ h | h@(RegardHook _ s _) <- regardingHooks st, s == subj ]
      in if null hs then ["nobody regards " ++ subj]
         else [ o ++ " as " ++ l | RegardHook o _ l <- sort hs ]
  | Just ks <- stripPrefix "salient " q
  , [(k, "")] <- reads ks =
      [ ev ++ " (" ++ show (length (nub (map erKnower rs))) ++ " knowers)"
      | (ev, rs) <- sort (salientEvents k (db st)) ]
  | Just who <- stripPrefix "debts of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "debt."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 3
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no debts on record"]
         else rows
  | Just who <- stripPrefix "creditors of " q =
      -- 对齐 Host creditorsOf：读闭合视图；短语化债权人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "debt." `isPrefixOf` s
                , let rest = drop (length ("debt." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known creditors"]
         else [ c ++ " creditor of " ++ who
              | s <- rows
              , let rest = drop (length ("debt." :: String)) s
              , let c = head (splitDot rest) ]
  | Just who <- stripPrefix "debtors of " q =
      -- 对齐 Host debtorsOf：读闭合视图；短语化债务人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "debt." `isPrefixOf` s
                , let rest = drop (length ("debt." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , head parts == who ]
      in if null rows then [who ++ " has no known debtors"]
         else [ who ++ " creditor of " ++ d
              | s <- rows
              , let rest = drop (length ("debt." :: String)) s
              , let parts = splitDot rest
              , let d = parts !! 1 ]
  | Just faction <- stripPrefix "leaders of " q =
      -- 对齐 Host leadersOf / CLI leaders：与 leads of 同义。
      let prefix = "leads." ++ faction ++ "."
          ls = sort [ drop (length prefix) s
                    | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                    , '.' `notElem` drop (length prefix) s ]
      in if null ls then ["nobody leads " ++ faction]
         else map (++ (" leads " ++ faction)) ls
  | Just faction <- stripPrefix "leads of " q =
      -- 对齐 Host leadersOf：读闭合视图；! 展成 .
      let prefix = "leads." ++ faction ++ "."
          ls = sort [ drop (length prefix) s
                    | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                    , '.' `notElem` drop (length prefix) s ]
      in if null ls then ["nobody leads " ++ faction]
         else map (++ (" leads " ++ faction)) ls
  | Just who <- stripPrefix "affiliates of " q =
      -- 对齐 Host affiliatesOf：读闭合视图。
      let prefix = "affiliate." ++ who ++ "."
          fs = sort [ drop (length prefix) s
                    | s <- dbToSentences (readView st), prefix `isPrefixOf` s ]
      in if null fs then [who ++ " has no affiliates"]
         else map ((who ++ " affiliates ") ++) fs
  | Just faction <- stripPrefix "members of " q =
      -- 对齐 Host membersOf：读闭合视图；member.<who>!<faction> 展成 .
      let suffix = "." ++ faction
          ms = sort
            [ take (length rest - length suffix) rest
            | s <- dbToSentences (readView st)
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
      -- 对齐 Host feelingsOf：读闭合视图。
      let prefix = who ++ ".feels."
          fs = sort [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s ]
      in if null fs then [who ++ " has no recorded feelings"]
         else fs
  | Just who <- stripPrefix "moods of " q =
      -- 对齐 Host moodsOf：读闭合视图，返回原始叶。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("mood." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no mood marks"]
         else rows
  | Just who <- stripPrefix "mood of " q =
      -- 对齐 Host moodOf：读闭合视图。
      let prefix = "mood." ++ who ++ "."
          ms = sort [ drop (length prefix) s
                    | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                    , '.' `notElem` drop (length prefix) s ]
      in if null ms then [who ++ " has no baseline mood"]
         else map ((who ++ " mood ") ++) ms
  | Just who <- stripPrefix "arcs of " q =
      -- 对齐 Host arcsOf：读闭合视图，返回原始叶。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , (who ++ ".arc.") `isPrefixOf` s ]
      in if null rows then [who ++ " has no arc marks"]
         else rows
  | Just who <- stripPrefix "arc of " q =
      -- 对齐 Host arcOf：读闭合视图。
      let prefix = who ++ ".arc."
          stages = sort [ drop (length prefix) s
                        | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                        , '.' `notElem` drop (length prefix) s ]
      in if null stages then [who ++ " has no arc stage"]
         else map ((who ++ " arc ") ++) stages
  | Just who <- stripPrefix "ages of " q =
      -- 对齐 Host agesOf：读闭合视图，返回原始叶。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("age." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no age marks"]
         else rows
  | Just who <- stripPrefix "age of " q =
      -- 对齐 Host ageOf：读闭合视图。
      let prefix = "age." ++ who ++ "."
          ages = sort [ drop (length prefix) s
                      | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null ages then [who ++ " has no recorded age"]
         else map ((who ++ " age ") ++) ages
  | Just who <- stripPrefix "siblings of " q =
      -- 对齐 Host siblingsOf：读闭合视图；短语化客体名。
      let prefix = "sibling." ++ who ++ "."
          sibs = sort [ drop (length prefix) s
                      | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null sibs then [who ++ " has no known siblings"]
         else map ((who ++ " sibling ") ++) sibs
  | Just who <- stripPrefix "parents of " q =
      -- 对齐 Host parentsOf：读闭合视图；短语化父母名。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "parent." `isPrefixOf` s
                , let rest = drop (length ("parent." :: String)) s
                , let (p, after) = break (== '.') rest
                , not (null p)
                , drop 1 after == who ]
      in if null rows then [who ++ " has no known parents"]
         else [ p ++ " parent of " ++ who
              | s <- rows
              , let rest = drop (length ("parent." :: String)) s
              , let (p, _) = break (== '.') rest ]
  | Just who <- stripPrefix "children of " q =
      -- 对齐 Host childrenOf：读闭合视图；短语化子女名。
      let prefix = "parent." ++ who ++ "."
          kids = sort [ drop (length prefix) s
                      | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null kids then [who ++ " has no known children"]
         else map ((who ++ " parent of ") ++) kids
  | Just who <- stripPrefix "grandparents of " q =
      -- 对齐 Host grandparentsOf：读闭合视图；短语化祖父母名。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "grandparent." `isPrefixOf` s
                , let rest = drop (length ("grandparent." :: String)) s
                , let (g, after) = break (== '.') rest
                , not (null g)
                , drop 1 after == who ]
      in if null rows then [who ++ " has no known grandparents"]
         else [ g ++ " grandparent of " ++ who
              | s <- rows
              , let rest = drop (length ("grandparent." :: String)) s
              , let (g, _) = break (== '.') rest ]
  | Just who <- stripPrefix "grandchildren of " q =
      -- 对齐 Host grandchildrenOf：读闭合视图；短语化孙子女名。
      let prefix = "grandparent." ++ who ++ "."
          kids = sort [ drop (length prefix) s
                      | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                      , '.' `notElem` drop (length prefix) s ]
      in if null kids then [who ++ " has no known grandchildren"]
         else map ((who ++ " grandparent of ") ++) kids
  | Just who <- stripPrefix "in-laws of " q =
      -- 对齐 Host inLawsOf：读闭合视图；短语化姻亲名。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "inLaw." `isPrefixOf` s
                , let rest = drop (length ("inLaw." :: String)) s
                , let (x, after) = break (== '.') rest
                , not (null x)
                , drop 1 after == who ]
      in if null rows then [who ++ " has no known in-laws"]
         else [ x ++ " in-law of " ++ who
              | s <- rows
              , let rest = drop (length ("inLaw." :: String)) s
              , let (x, _) = break (== '.') rest ]
  | Just who <- stripPrefix "spouses of " q =
      -- 对齐 Host spousesOf：读闭合视图；短语化配偶名。
      let prefix = "married." ++ who ++ "."
          sps = sort [ drop (length prefix) s
                     | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                     , '.' `notElem` drop (length prefix) s ]
      in if null sps then [who ++ " has no known spouses"]
         else map ((who ++ " spouse ") ++) sps
  | Just who <- stripPrefix "branded of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 2
                , "branded" `isPrefixOf` head parts
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no brand marks"]
         else rows
  | Just who <- stripPrefix "revoked of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "revoked."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no revoked deals"]
         else rows
  | Just who <- stripPrefix "revokers of " q =
      -- 对齐 Host revokersOf：读闭合视图；短语化撕毁人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "revoked." `isPrefixOf` s
                , let rest = drop (length ("revoked." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known revokers"]
         else [ c ++ " revoker of " ++ who
              | s <- rows
              , let c = head (splitDot (drop (length ("revoked." :: String)) s)) ]
  | Just who <- stripPrefix "revokees of " q =
      -- 对齐 Host revokeesOf：读闭合视图；短语化被撕毁人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "revoked." `isPrefixOf` s
                , let rest = drop (length ("revoked." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known revokees"]
         else [ who ++ " revoker of " ++ d
              | s <- rows
              , let d = (splitDot (drop (length ("revoked." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "confessed of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 2
                , (head parts == "confessed" && (parts !! 1) == who)
                  || (head parts == who && (parts !! 1) == "confessed") ]
      in if null rows then [who ++ " has no confessions on record"]
         else rows
  | Just who <- stripPrefix "recanted of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("recanted." ++ who)
                  || ("recanted." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no recantation on record"]
         else rows
  | Just who <- stripPrefix "ostracized of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "ostracized."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no ostracize marks"]
         else rows
  | Just who <- stripPrefix "ostracizers of " q =
      -- 对齐 Host ostracizersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "ostracized." `isPrefixOf` s
                , let rest = drop (length ("ostracized." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known ostracizers"]
         else [ a ++ " ostracizer of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("ostracized." :: String)) s)) ]
  | Just who <- stripPrefix "ostracizees of " q =
      -- 对齐 Host ostracizeesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "ostracized." `isPrefixOf` s
                , let rest = drop (length ("ostracized." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known ostracizees"]
         else [ who ++ " ostracizer of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("ostracized." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "exiled of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("exiled." ++ who)
                  || ("exiled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no exile mark"]
         else rows
  | Just who <- stripPrefix "denounced of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "denounced."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no denounce marks"]
         else rows
  | Just who <- stripPrefix "denouncers of " q =
      -- 对齐 Host denouncersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "denounced." `isPrefixOf` s
                , let rest = drop (length ("denounced." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known denouncers"]
         else [ a ++ " denouncer of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("denounced." :: String)) s)) ]
  | Just who <- stripPrefix "denouncees of " q =
      -- 对齐 Host denounceesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "denounced." `isPrefixOf` s
                , let rest = drop (length ("denounced." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known denouncees"]
         else [ who ++ " denouncer of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("denounced." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "censured of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "censured."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no censure marks"]
         else rows
  | Just who <- stripPrefix "censurers of " q =
      -- 对齐 Host censurersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "censured." `isPrefixOf` s
                , let rest = drop (length ("censured." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known censurers"]
         else [ a ++ " censurer of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("censured." :: String)) s)) ]
  | Just who <- stripPrefix "censurees of " q =
      -- 对齐 Host censureesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "censured." `isPrefixOf` s
                , let rest = drop (length ("censured." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known censurees"]
         else [ who ++ " censurer of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("censured." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "paraded of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "paraded."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no parade marks"]
         else rows
  | Just who <- stripPrefix "paraders of " q =
      -- 对齐 Host paradersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "paraded." `isPrefixOf` s
                , let rest = drop (length ("paraded." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known paraders"]
         else [ a ++ " parader of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("paraded." :: String)) s)) ]
  | Just who <- stripPrefix "paradees of " q =
      -- 对齐 Host paradeesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "paraded." `isPrefixOf` s
                , let rest = drop (length ("paraded." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known paradees"]
         else [ who ++ " parader of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("paraded." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "cried of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "cried."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no cry marks"]
         else rows
  | Just who <- stripPrefix "criers of " q =
      -- 对齐 Host criersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "cried." `isPrefixOf` s
                , let rest = drop (length ("cried." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known criers"]
         else [ a ++ " crier of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("cried." :: String)) s)) ]
  | Just who <- stripPrefix "criees of " q =
      -- 对齐 Host crieesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "cried." `isPrefixOf` s
                , let rest = drop (length ("cried." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known criees"]
         else [ who ++ " crier of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("cried." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "rallied of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "rallied."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no rally marks"]
         else rows
  | Just who <- stripPrefix "ralliers of " q =
      -- 对齐 Host ralliersOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "rallied." `isPrefixOf` s
                , let rest = drop (length ("rallied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known ralliers"]
         else [ a ++ " rallier of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("rallied." :: String)) s)) ]
  | Just who <- stripPrefix "ralliees of " q =
      -- 对齐 Host rallieesOf：读闭合视图；短语化。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "rallied." `isPrefixOf` s
                , let rest = drop (length ("rallied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known ralliees"]
         else [ who ++ " rallier of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("rallied." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "fled of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("fled." ++ who)
                  || ("fled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no flee mark"]
         else rows
  | Just who <- stripPrefix "reconciled of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("reconciled." ++ who)
                  || ("reconciled." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no reconcile mark"]
         else rows
  | Just who <- stripPrefix "married of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "married."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no marriage marks"]
         else rows
  | Just who <- stripPrefix "eyed of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "eyed."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no eye marks"]
         else rows
  | Just who <- stripPrefix "eyers of " q =
      -- 对齐 Host eyersOf：读闭合视图；短语化目击人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "eyed." `isPrefixOf` s
                , let rest = drop (length ("eyed." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known eyers"]
         else [ a ++ " eyer of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("eyed." :: String)) s)) ]
  | Just who <- stripPrefix "eyees of " q =
      -- 对齐 Host eyeesOf：读闭合视图；短语化被目击人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "eyed." `isPrefixOf` s
                , let rest = drop (length ("eyed." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known eyees"]
         else [ who ++ " eyer of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("eyed." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "confronted of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "confronted."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no confront marks"]
         else rows
  | Just who <- stripPrefix "confronters of " q =
      -- 对齐 Host confrontersOf：读闭合视图；短语化对质人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "confronted." `isPrefixOf` s
                , let rest = drop (length ("confronted." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known confronters"]
         else [ a ++ " confronter of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("confronted." :: String)) s)) ]
  | Just who <- stripPrefix "confrontees of " q =
      -- 对齐 Host confronteesOf：读闭合视图；短语化被对质人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "confronted." `isPrefixOf` s
                , let rest = drop (length ("confronted." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known confrontees"]
         else [ who ++ " confronter of " ++ t
              | s <- rows
              , let t = (splitDot (drop (length ("confronted." :: String)) s)) !! 1 ]
  | Just who <- stripPrefix "atoned of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("atoned." ++ who)
                  || ("atoned." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no atonement on record"]
         else rows
  | Just who <- stripPrefix "wronged of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "wronged."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no wrong marks"]
         else rows
  | Just who <- stripPrefix "wrongers of " q =
      -- 对齐 Host wrongersOf：读闭合视图；短语化加害人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "wronged." `isPrefixOf` s
                , let rest = drop (length ("wronged." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known wrongers"]
         else [ o ++ " wronger of " ++ who
              | s <- rows
              , let rest = drop (length ("wronged." :: String)) s
              , let o = head (splitDot rest) ]
  | Just who <- stripPrefix "wrongees of " q =
      -- 对齐 Host wrongeesOf：读闭合视图；短语化受害人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "wronged." `isPrefixOf` s
                , let rest = drop (length ("wronged." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who ]
      in if null rows then [who ++ " has no known wrongees"]
         else [ who ++ " wronger of " ++ v
              | s <- rows
              , let rest = drop (length ("wronged." :: String)) s
              , let v = (splitDot rest) !! 1 ]
  | Just who <- stripPrefix "hungry of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("hungry." ++ who)
                  || ("hungry." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no hunger mark"]
         else rows
  | Just who <- stripPrefix "short-tempered of " q =
      -- 对齐 Host shortTemperedOf / CLI short-tempered 别名：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("shortTempered." ++ who)
                  || ("shortTempered." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no short-temper mark"]
         else rows
  | Just who <- stripPrefix "shortTempered of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("shortTempered." ++ who)
                  || ("shortTempered." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no short-temper mark"]
         else rows
  | Just who <- stripPrefix "appetite of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , s == ("appetite." ++ who)
                  || ("appetite." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no appetite mark"]
         else rows
  | Just who <- stripPrefix "resents of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("resents." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no resentment marks"]
         else rows
  | Just who <- stripPrefix "resenters of " q =
      -- 对齐 Host resentersOf：读闭合视图；短语化怨恨人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "resents." `isPrefixOf` s
                , let rest = drop (length ("resents." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known resenters"]
         else [ a ++ " resenter of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("resents." :: String)) s)) ]
  | Just who <- stripPrefix "allied of " q =
      -- 对齐 Host *Of：读闭合视图。
      let prefix = "allied."
          rows = sort
            [ s | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                , let rest = drop (length prefix) s
                , let parts = splitDot rest
                , length parts >= 2
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no alliance marks"]
         else rows
  | q == "what is on the stall" =
      -- 对齐 Host stallOf：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st), "stall." `isPrefixOf` s ]
      in if null rows then ["the stall is empty"]
         else rows
  | q == "what festivals" =
      -- 对齐 Host festivalsNamed：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st), "festival." `isPrefixOf` s ]
      in if null rows then ["no festivals are open"]
         else rows
  | Just who <- stripPrefix "allies of " q =
      -- 对齐 Host alliesOf：读闭合视图；短语化同盟名。
      let prefix = "allied." ++ who ++ "."
          als = sort [ drop (length prefix) s
                     | s <- dbToSentences (readView st), prefix `isPrefixOf` s
                     , '.' `notElem` drop (length prefix) s ]
      in if null als then [who ++ " has no known allies"]
         else map ((who ++ " ally ") ++) als
  | Just who <- stripPrefix "holding of " q =
      -- 对齐 Host holdingsOf：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("holding." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " holds nothing"]
         else rows
  | Just who <- stripPrefix "carrying of " q =
      -- 对齐 Host carryingsOf：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("carrying." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " carries nothing"]
         else rows
  | Just who <- stripPrefix "threatened of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "threatened." `isPrefixOf` s
                , let rest = drop (length ("threatened." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , (parts !! 1) == who || (parts !! 2) == who ]
      in if null rows then [who ++ " has no threat marks"]
         else rows
  | Just who <- stripPrefix "threateners of " q =
      -- 对齐 Host threatenersOf：读闭合视图；短语化施威胁人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "threatened." `isPrefixOf` s
                , let rest = drop (length ("threatened." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known threateners"]
         else [ e ++ " threatener of " ++ who
              | s <- rows
              , let rest = drop (length ("threatened." :: String)) s
              , let e = (splitDot rest) !! 1 ]
  | Just who <- stripPrefix "threatenees of " q =
      -- 对齐 Host threateneesOf：读闭合视图；短语化受威胁人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "threatened." `isPrefixOf` s
                , let rest = drop (length ("threatened." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known threatenees"]
         else [ who ++ " threatener of " ++ v
              | s <- rows
              , let rest = drop (length ("threatened." :: String)) s
              , let parts = splitDot rest
              , let v = parts !! 2 ]
  | Just who <- stripPrefix "shunned of " q =
      -- 对齐 Host shunnedOf：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("shunned." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has shunned no one"]
         else rows
  | Just who <- stripPrefix "shunners of " q =
      -- 对齐 Host shunnersOf：读闭合视图；短语化排斥人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "shunned." `isPrefixOf` s
                , let rest = drop (length ("shunned." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known shunners"]
         else [ a ++ " shunner of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("shunned." :: String)) s)) ]
  | Just who <- stripPrefix "locations of " q =
      -- 对齐 Host locationsOf：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("at." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no known location"]
         else rows
  | Just place <- stripPrefix "occupants of " q =
      -- 对齐 Host occupantsOf：读闭合视图；短语化在场角色。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "at." `isPrefixOf` s
                , let rest = drop (length ("at." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == place ]
      in if null rows then ["nobody is at " ++ place]
         else [ a ++ " at " ++ place
              | s <- rows
              , let a = head (splitDot (drop (length ("at." :: String)) s)) ]
  | Just who <- stripPrefix "demanded of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "demanded." `isPrefixOf` s
                , let rest = drop (length ("demanded." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , head parts == who || (parts !! 1) == who ]
      in if null rows then [who ++ " has no demand marks"]
         else rows
  | Just who <- stripPrefix "demanders of " q =
      -- 对齐 Host demandersOf：读闭合视图；短语化催收人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "demanded." `isPrefixOf` s
                , let rest = drop (length ("demanded." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known demanders"]
         else [ c ++ " demander of " ++ who
              | s <- rows
              , let rest = drop (length ("demanded." :: String)) s
              , let c = head (splitDot rest) ]
  | Just who <- stripPrefix "demandees of " q =
      -- 对齐 Host demandeesOf：读闭合视图；短语化被催收人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "demanded." `isPrefixOf` s
                , let rest = drop (length ("demanded." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , head parts == who ]
      in if null rows then [who ++ " has no known demandees"]
         else [ who ++ " demander of " ++ d
              | s <- rows
              , let rest = drop (length ("demanded." :: String)) s
              , let parts = splitDot rest
              , let d = parts !! 1 ]
  | Just who <- stripPrefix "extorted of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 4
                , parts !! 1 == "extorted"
                , head parts == who || (parts !! 2) == who ]
      in if null rows then [who ++ " has no extortion marks"]
         else rows
  | Just who <- stripPrefix "extorters of " q =
      -- 对齐 Host extortersOf：读闭合视图；短语化勒索人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 4
                , parts !! 1 == "extorted"
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known extorters"]
         else [ e ++ " extorter of " ++ who
              | s <- rows
              , let parts = splitDot s
              , let e = head parts ]
  | Just who <- stripPrefix "extortees of " q =
      -- 对齐 Host extorteesOf：读闭合视图；短语化被勒索人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 4
                , parts !! 1 == "extorted"
                , head parts == who ]
      in if null rows then [who ++ " has no known extortees"]
         else [ who ++ " extorter of " ++ v
              | s <- rows
              , let parts = splitDot s
              , let v = parts !! 2 ]
  | Just who <- stripPrefix "complied of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "complied." `isPrefixOf` s
                , let rest = drop (length ("complied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , (parts !! 1) == who || (parts !! 2) == who ]
      in if null rows then [who ++ " has no compliance marks"]
         else rows
  | Just who <- stripPrefix "compliers of " q =
      -- 对齐 Host compliersOf：读闭合视图；短语化顺从人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "complied." `isPrefixOf` s
                , let rest = drop (length ("complied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known compliers"]
         else [ v ++ " complier of " ++ who
              | s <- rows
              , let rest = drop (length ("complied." :: String)) s
              , let v = (splitDot rest) !! 2 ]
  | Just who <- stripPrefix "compliees of " q =
      -- 对齐 Host complieesOf：读闭合视图；短语化被顺从人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "complied." `isPrefixOf` s
                , let rest = drop (length ("complied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known compliees"]
         else [ who ++ " complier of " ++ e
              | s <- rows
              , let rest = drop (length ("complied." :: String)) s
              , let e = (splitDot rest) !! 1 ]
  | Just who <- stripPrefix "defied of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "defied." `isPrefixOf` s
                , let rest = drop (length ("defied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , (parts !! 1) == who || (parts !! 2) == who ]
      in if null rows then [who ++ " has no defiance marks"]
         else rows
  | Just who <- stripPrefix "defiers of " q =
      -- 对齐 Host defiersOf：读闭合视图；短语化违抗人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "defied." `isPrefixOf` s
                , let rest = drop (length ("defied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known defiers"]
         else [ v ++ " defier of " ++ who
              | s <- rows
              , let rest = drop (length ("defied." :: String)) s
              , let v = (splitDot rest) !! 1 ]
  | Just who <- stripPrefix "defiees of " q =
      -- 对齐 Host defieesOf：读闭合视图；短语化被违抗人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "defied." `isPrefixOf` s
                , let rest = drop (length ("defied." :: String)) s
                , let parts = splitDot rest
                , length parts >= 3
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known defiees"]
         else [ who ++ " defier of " ++ e
              | s <- rows
              , let rest = drop (length ("defied." :: String)) s
              , let e = (splitDot rest) !! 2 ]
  | Just who <- stripPrefix "obligations of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("obliged." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no obligations"]
         else rows
  | Just who <- stripPrefix "breaches of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("violated." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no breaches"]
         else rows
  | Just who <- stripPrefix "lies of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , (who ++ ".lied.") `isPrefixOf` s ]
      in if null rows then [who ++ " has no lie marks"]
         else rows
  | Just who <- stripPrefix "liars of " q =
      -- 对齐 Host liarsOf：读闭合视图；短语化撒谎人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 3
                , parts !! 1 == "lied"
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known liars"]
         else [ head (splitDot s) ++ " liar of " ++ who | s <- rows ]
  | Just who <- stripPrefix "chatted with " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , (who ++ ".chattedWith.") `isPrefixOf` s ]
      in if null rows then [who ++ " has chatted with no one"]
         else rows
  | Just who <- stripPrefix "chatters of " q =
      -- 对齐 Host chattersOf：读闭合视图；短语化聊天人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 3
                , parts !! 1 == "chattedWith"
                , parts !! 2 == who ]
      in if null rows then [who ++ " has no known chatters"]
         else [ a ++ " chatter of " ++ who
              | s <- rows
              , let a = head (splitDot s) ]
  | Just who <- stripPrefix "traits of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("trait." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no traits on record"]
         else rows
  | Just who <- stripPrefix "bonds of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("bond." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no bonds"]
         else rows
  | Just who <- stripPrefix "bonders of " q =
      -- 对齐 Host bondersOf：读闭合视图；短语化纽带人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "bond." `isPrefixOf` s
                , let rest = drop (length ("bond." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known bonders"]
         else [ a ++ " bonder of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("bond." :: String)) s)) ]
  | Just who <- stripPrefix "esteemed of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("esteemed." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has esteemed no one"]
         else rows
  | Just who <- stripPrefix "esteemers of " q =
      -- 对齐 Host esteemersOf：读闭合视图；短语化赞誉人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "esteemed." `isPrefixOf` s
                , let rest = drop (length ("esteemed." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known esteemers"]
         else [ a ++ " esteemer of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("esteemed." :: String)) s)) ]
  | Just who <- stripPrefix "scorned of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("scorned." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has scorned no one"]
         else rows
  | Just who <- stripPrefix "scorners of " q =
      -- 对齐 Host scornersOf：读闭合视图；短语化蔑视人。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "scorned." `isPrefixOf` s
                , let rest = drop (length ("scorned." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no known scorners"]
         else [ a ++ " scorner of " ++ who
              | s <- rows
              , let a = head (splitDot (drop (length ("scorned." :: String)) s)) ]
  | Just who <- stripPrefix "beliefs of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , (who ++ ".believes.") `isPrefixOf` s ]
      in if null rows then [who ++ " has no beliefs on record"]
         else rows
  | Just who <- stripPrefix "projects of " q =
      -- 对齐 Host *Of：读闭合视图。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , "practice." `isPrefixOf` s
                , let rest = drop (length ("practice." :: String)) s
                , let parts = splitDot rest
                , length parts >= 2
                , parts !! 1 == who ]
      in if null rows then [who ++ " has no project marks"]
         else rows
  | Just who <- stripPrefix "kin of " q =
      -- 对齐 Host *Of：读闭合视图。
      let kinHeads = ["married", "parent", "sibling", "inLaw", "grandparent"]
          rows = sort
            [ s | s <- dbToSentences (readView st)
                , let parts = splitDot s
                , length parts >= 3
                , head parts `elem` kinHeads
                , who `elem` drop 1 parts ]
      in if null rows then [who ++ " has no kin marks"]
         else rows
  | Just who <- stripPrefix "notorious of " q =
      -- 对齐 Host notoriousOf：读闭合视图（臭名多为派生叶）。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , ("notorious." ++ who ++ ".") `isPrefixOf` s ]
      in if null rows then [who ++ " has no notoriety marks"]
         else rows
  | Just target <- stripPrefix "regards toward " q =
      -- 对齐 Host regardsToward：闭合视图中指向 target 的 regards.*.target.*。
      let rows = sort
            [ s | s <- dbToSentences (readView st)
                , let pref = "regards."
                , pref `isPrefixOf` s
                , let rest = drop (length pref) s
                , let (who, afterWho) = break (== '.') rest
                , not (null who)
                , let after = drop 1 afterWho
                , let (tgt, afterTgt) = break (== '.') after
                , tgt == target
                , not (null (drop 1 afterTgt)) ]
      in if null rows then ["nobody regards " ++ target]
         else rows
  | q == "what factions" =
      -- 对齐 Host factionsNamed：member/affiliate/leads 上出现的派系名。
      let vs = dbToSentences (readView st)
          fromMember =
            [ fac
            | s <- vs
            , "member." `isPrefixOf` s
            , let rest = drop (length ("member." :: String)) s
            , let (who, fac) = splitLastDot rest
            , not (null who), not (null fac)
            , '.' `notElem` who, '.' `notElem` fac ]
          fromAffiliate =
            [ fac
            | s <- vs
            , "affiliate." `isPrefixOf` s
            , let rest = drop (length ("affiliate." :: String)) s
            , let (who, fac) = splitLastDot rest
            , not (null who), not (null fac)
            , '.' `notElem` who, '.' `notElem` fac ]
          fromLeads =
            [ fac
            | s <- vs
            , "leads." `isPrefixOf` s
            , let rest = drop (length ("leads." :: String)) s
            , let (fac, who) = break (== '.') rest
            , not (null fac), not (null (drop 1 who))
            , '.' `notElem` fac ]
          fs = sort (nub (fromMember ++ fromAffiliate ++ fromLeads))
      in if null fs then ["no factions are named"]
         else fs
  | otherwise = ["chronicle: unknown query " ++ show q]

-- helpers ----------------------------------------------------------------------

splitLastDot :: String -> (String, String)
splitLastDot s =
  case break (== '.') (reverse s) of
    (revFac, '.' : revWho) -> (reverse revWho, reverse revFac)
    _ -> (s, "")

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
