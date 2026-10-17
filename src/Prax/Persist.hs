-- | 持久化：存档/读档运行中的会话（Versu——「序列化与反序列化世界状态是平凡的」）。
--
-- 全部可变状态是事实数据库、回合光标、站立意图、引擎调度的运行时半边——按规则的下次到期与
-- 一次性到期队列（规格 @docs/specs/2026-07-16-v44-the-schedule.md@）——以及戏剧骰的流位置
-- （@rngSeed@，规格 v50）。实践、角色、wants 与调度声明是代码（世界的规则），因此存档只捕获
-- @db@ + @cursor@ + @intentions@ + @scheduleDues@ + @expiries@ + @rngSeed@，并重载到同一种类的
-- 新鲜构建世界上（世界提供 dues 按名称再关联到的规则体）。事实序列化为句子（每行一句，经
-- @dbToLabeledSentences@ / @insertAll@）；意图、dues、expiries 与种子在各自标注行上序列化
-- （下方），因此往返精确。@rngseed@ 行仅对已播种状态发出——未播种世界的存档无该行，重载为
-- 'Nothing'。
module Prax.Persist
  ( serializeState
  , deserializeState
  , saveState
  , loadState
  , formatVersion
  ) where

import           Data.List (isPrefixOf)
import qualified Data.Map.Strict as Map
import           Text.Read (readMaybe)

import           Prax.Db (Val (..), dbToLabeledSentences, emptyDb, insertAll,
                          internTokens, tokensToSentence)
import           Prax.Types (GroundedAction (..), Intention (..),
                              MotiveSignature (..), PraxState (..),
                              ScheduleRule (..))
import           Prax.Engine (withDb)
import           Prax.Sym (intern, symName)

-- | A 'Val' crossing the file boundary as text, since interned symbols are
-- process-local (spec @docs/specs/2026-07-12-v29-interning.md@) — every
-- 'Prax.Sym.Sym' is written by name and re-interned on load.
data ValRepr = RS String | RN Integer | RT [[String]] deriving (Show, Read)

reprVal :: Val -> ValRepr
reprVal (VSym s)  = RS (symName s)
reprVal (VNum n)  = RN n
reprVal (VSet xs) = RT (map (map symName) xs)

unreprVal :: ValRepr -> Val
unreprVal (RS s)  = VSym (intern s)
unreprVal (RN n)  = VNum n
unreprVal (RT xs) = VSet (map (map intern) xs)

type GaRepr = (String, String, String, [(String, ValRepr)], String)
type IntentRepr = (Maybe GaRepr, ([String], [Int], [String], [(String, String)]))

reprIntention :: Intention -> IntentRepr
reprIntention (Intention mga sig) =
  ( fmap (\ga -> ( gaPracticeId ga, gaInstanceId ga, gaActionId ga
                 , [ (symName k, reprVal v) | (k, v) <- Map.toList (gaBindings ga) ]
                 , gaLabel ga )) mga
  , (msBearing sig, msSatisfaction sig, msLiveDesires sig, msKnownMotives sig) )

unreprIntention :: IntentRepr -> Intention
unreprIntention (mga, (b, s, l, m)) =
  Intention
    (fmap (\(pid, iid, aid, bs, lbl) -> GroundedAction pid iid aid
             (Map.fromList [ (intern k, unreprVal v) | (k, v) <- bs ]) lbl) mga)
    (MotiveSignature b s l m)

-- | The save-format tag, first line of every serialized state. Bump it when the
-- line format below changes OR when the same bytes would carry different meaning
-- under the current world model (a Script save's fact vocabulary is part of that
-- model); 'deserializeState' rejects any other tag loudly — no silent misparse
-- of a save whose facts a freshly-constructed world no longer interprets.
formatVersion :: String
formatVersion = "prax-state v4"

-- | Serialize the mutable state (@cursor@ + standing intentions + all facts)
-- to text, with @!@/@.@ labels so the reload rebuilds the exclusion structure
-- exactly. Intention lines are prefixed @"intention "@; since fact sentences
-- are dot-paths with no spaces, that prefix cannot collide with a fact line
-- (the same disambiguation the @"cursor "@ header already relies on).
serializeState :: PraxState -> String
serializeState st =
  unlines
    ( formatVersion
    : ("cursor " ++ show (cursor st))
    : maybe [] (\s -> [ "rngseed " ++ show s ]) (rngSeed st)
    ++ [ "intention " ++ name ++ " " ++ show (reprIntention i)
      | (name, i) <- Map.toList (intentions st) ]
    ++ [ "due " ++ name ++ " " ++ show turn
       | (name, turn) <- Map.toList (scheduleDues st) ]
    ++ [ "expiry " ++ show turn ++ " " ++ tokensToSentence toks
       | (toks, turn) <- Map.toList (expiries st) ]
    ++ dbToLabeledSentences (db st)
    )

-- | Rebuild a saved state onto @world@ (a fresh world of the same kind, which
-- supplies the practice definitions and cast). Crashes loudly on malformed
-- input, including a malformed intention line, and on a save from another
-- format era (a version tag other than 'formatVersion').
deserializeState :: String -> PraxState -> PraxState
deserializeState text world =
  case lines text of
    (v : hd : rest)
      | v == formatVersion, ["cursor", n] <- words hd, Just c <- readMaybe n ->
          let labelled       = ["intention ", "due ", "expiry ", "rngseed "]
              intentionLines = filter ("intention " `isPrefixOf`) rest
              dueLines       = filter ("due " `isPrefixOf`) rest
              expiryLines    = filter ("expiry " `isPrefixOf`) rest
              factLines      = filter (\l -> not (any (`isPrefixOf` l) labelled)) rest
              newIntentions  = Map.fromList (map parseIntentionLine intentionLines)
              newDues        = Map.fromList (map parseDueLine dueLines)
              newExpiries    = Map.fromList (map parseExpiryLine expiryLines)
              newSeed        = case filter ("rngseed " `isPrefixOf`) rest of
                                 []      -> Nothing
                                 (l : _) -> Just (parseSeedLine l)
          in (withDb (const (insertAll (filter (not . null) factLines) emptyDb)) world)
               { cursor = c, intentions = newIntentions
               , scheduleDues = newDues, expiries = newExpiries, rngSeed = newSeed }
    (v : _)
      | v /= formatVersion ->
          error ("Prax.Persist.deserializeState: unsupported save format "
                 ++ show v ++ " (expected " ++ show formatVersion ++ ")")
    _ -> error "Prax.Persist.deserializeState: malformed save (expected the format header, then 'cursor <n>')"
  where
    parseIntentionLine line =
      case break (== ' ') (drop (length "intention ") line) of
        (name, ' ' : reprText)
          | Just repr <- readMaybe reprText -> (name, unreprIntention repr)
        _ -> error ("Prax.Persist.deserializeState: malformed intention line: " ++ line)
    -- Dues re-associate to the world's declared rules BY NAME; an unknown name
    -- is a loud error (a save from a world whose schedule has since changed).
    parseDueLine line =
      case words (drop (length "due ") line) of
        [name, turnStr]
          | Just t <- readMaybe turnStr ->
              if any ((== name) . srName) (schedule world)
                then (name, t)
                else error ("Prax.Persist.deserializeState: due for unknown schedule rule "
                            ++ show name ++ " (not declared in the reloaded world)")
        _ -> error ("Prax.Persist.deserializeState: malformed due line: " ++ line)
    -- Expiry: @expiry <turn> <labeled-sentence>@ (turn first; paths never
    -- contain spaces, so the fixed-field split is unambiguous).
    parseExpiryLine line =
      case words (drop (length "expiry ") line) of
        [turnStr, sent]
          | Just t <- readMaybe turnStr -> (internTokens sent, t)
        _ -> error ("Prax.Persist.deserializeState: malformed expiry line: " ++ line)
    -- The die's stream position: @rngseed <n>@, at most one, emitted only for a
    -- seeded state. A malformed value is a loud error, never a silent Nothing.
    parseSeedLine line =
      case words (drop (length "rngseed ") line) of
        [nStr] | Just n <- readMaybe nStr -> n
        _ -> error ("Prax.Persist.deserializeState: malformed rngseed line: " ++ line)

-- | Save a session to a file.
saveState :: FilePath -> PraxState -> IO ()
saveState path = writeFile path . serializeState

-- | Load a session from a file onto a fresh @world@.
loadState :: FilePath -> PraxState -> IO PraxState
loadState path world = deserializeState <$> readFile path <*> pure world
