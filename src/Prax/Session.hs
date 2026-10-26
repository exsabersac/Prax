{-# LANGUAGE OverloadedStrings #-}
-- | 会话编排层（「我的小镇」M1）：稳定导出 @praxNew@/@praxView@/@praxMenu@/@praxAct@/
-- @praxSave@/@praxLoad@（及可选 @praxWait@），供 CLI 与日后 web 薄封同源使用。
--
-- == 契约 v0.1.1
--
-- * __praxAct__ = CLI 玩家整回合：'performAction'（玩家选中动作）后，
--   'advance'\/'npcAct' 直至再次 @actor == player@。深度与边界策略对齐
--   @app\/Main.hs@（@lookaheadDepth = 2@；回绕边界在 'Prax.Loop.advance' 内）。
--   裸 'Prax.Host.step' __不__导出。
-- * __Menu__ 源 = CLI 同款 'candidateActions'，并藏空 outcome（稍候等纯 no-op）。
-- * __Menu.action.id__ = canonical string @ga:v1:…@，编码
--   @(practiceId, instanceId, actionId, bindings)@，对齐 Persist @GaRepr@ 的可逆
--   表示（不含 label）。__Act 禁止靠 label__。
-- * __View__ 做世界投影：从 @practice.world.world.at.\<who\>!\<place\>@ 投到
--   @locationId@ \/ @actors[].here@；不把原始 EL 路径甩给调用方。
-- * __Save__：JSON meta（@format:"prax-state-v4"@, @worldId@）+ Persist 文本 @blob@；
--   Load 用 @worldId@ 取模板再 'deserializeState'。
module Prax.Session
  ( Session (..)
  , SessionView (..)
  , SessionActor (..)
  , MenuItem (..)
  , ActResult (..)
  , SaveMeta (..)
  , lookaheadDepth
  , praxNew
  , praxView
  , praxMenu
  , praxAct
  , praxWait
  , praxSave
  , praxLoad
  , encodeActionId
  , decodeActionId
  , worldTemplate
  , playerActions
  , ensurePlayerTurn
  , trustNarrativeLines
  ) where

import           Data.Aeson (FromJSON (..), ToJSON (..), object, withObject,
                             (.:), (.=), encode, eitherDecode)
import qualified Data.ByteString.Lazy.Char8 as BLC
import           Data.List (isPrefixOf, stripPrefix)
import qualified Data.Map.Strict as Map
import           Data.Maybe (mapMaybe)
import           Text.Read (readMaybe)

import           Prax.Db (Val (..), dbToLabeledSentences, dbToSentences)
import           Prax.Sym (symName)
import           Prax.Types
import           Prax.Engine (performAction)
import           Prax.Planner (candidateActions)
import           Prax.Loop (advance, npcAct)
import           Prax.Persist (serializeState, deserializeState)
import qualified Prax.Worlds.MyTown as MyTown

-- | 与 @app/Main.hs@ 一致的 NPC 审议深度。
lookaheadDepth :: Int
lookaheadDepth = 2

-- | 一次可序列化会话：世界 id + 玩家名 + 当前引擎状态（已停在玩家回合上）。
data Session = Session
  { sessWorldId :: String
  , sessPlayer  :: String
  , sessState   :: PraxState
  }

data SessionActor = SessionActor
  { actorId   :: String
  , actorHere :: Maybe String
  } deriving (Eq, Show)

data SessionView = SessionView
  { viewWorldId       :: String
  , viewPlayer        :: String
  , viewLocationId    :: Maybe String
  , viewLocationLabel :: Maybe String
  , viewActors        :: [SessionActor]
  } deriving (Eq, Show)

data MenuItem = MenuItem
  { menuActionId   :: String
  , menuLabel      :: String
  , menuPracticeId :: String
  , menuActionName :: String
  } deriving (Eq, Show)

data ActResult = ActResult
  { actNarrative :: [String]
  , actView      :: SessionView
  , actMenu      :: [MenuItem]
  } deriving (Eq, Show)

-- | Save 外壳的 meta 字段（blob 另列）。
data SaveMeta = SaveMeta
  { saveFormat  :: String
  , saveWorldId :: String
  , saveBlob    :: String
  } deriving (Eq, Show)

instance ToJSON SessionActor where
  toJSON a = object
    [ "id"   .= actorId a
    , "here" .= actorHere a
    ]

instance FromJSON SessionActor where
  parseJSON = withObject "SessionActor" $ \o ->
    SessionActor <$> o .: "id" <*> o .: "here"

instance ToJSON SessionView where
  toJSON v = object
    [ "worldId"       .= viewWorldId v
    , "player"        .= viewPlayer v
    , "locationId"    .= viewLocationId v
    , "locationLabel" .= viewLocationLabel v
    , "actors"        .= viewActors v
    ]

instance FromJSON SessionView where
  parseJSON = withObject "SessionView" $ \o ->
    SessionView <$> o .: "worldId" <*> o .: "player"
                <*> o .: "locationId" <*> o .: "locationLabel"
                <*> o .: "actors"

instance ToJSON MenuItem where
  toJSON m = object
    [ "actionId"   .= menuActionId m
    , "label"      .= menuLabel m
    , "practiceId" .= menuPracticeId m
    , "actionName" .= menuActionName m
    ]

instance FromJSON MenuItem where
  parseJSON = withObject "MenuItem" $ \o ->
    MenuItem <$> o .: "actionId" <*> o .: "label"
             <*> o .: "practiceId" <*> o .: "actionName"

instance ToJSON ActResult where
  toJSON r = object
    [ "narrative" .= actNarrative r
    , "view"      .= actView r
    , "menu"      .= actMenu r
    ]

instance FromJSON ActResult where
  parseJSON = withObject "ActResult" $ \o ->
    ActResult <$> o .: "narrative" <*> o .: "view" <*> o .: "menu"

instance ToJSON SaveMeta where
  toJSON s = object
    [ "format"  .= saveFormat s
    , "worldId" .= saveWorldId s
    , "blob"    .= saveBlob s
    ]

instance FromJSON SaveMeta where
  parseJSON = withObject "SaveMeta" $ \o ->
    SaveMeta <$> o .: "format" <*> o .: "worldId" <*> o .: "blob"

-- | 已知世界模板（M1：仅 my-town）。
worldTemplate :: String -> Either String (PraxState, String)
worldTemplate wid
  | wid == MyTown.worldId = Right (MyTown.myTownWorld, MyTown.playerName)
  | otherwise = Left ("Prax.Session: unknown worldId " ++ show wid)

-- | 开新局并推进到玩家首次可行动回合。
praxNew :: String -> Either String Session
praxNew wid = do
  (world, player) <- worldTemplate wid
  pure (Session wid player (ensurePlayerTurn player world))

-- | 若尚未轮到玩家，则 'advance'\/'npcAct' 直至玩家回合；已在玩家回合则原样返回。
-- 对齐 CLI：存档若停在玩家身上则不得再 advance（否则会跳过玩家）。
ensurePlayerTurn :: String -> PraxState -> PraxState
ensurePlayerTurn player st
  | onPlayer st = st
  | otherwise   = goBudget (max 64 (length (characters st) * 4)) st
  where
    onPlayer s =
      let i = cursor s
          cs = characters s
      in i >= 0 && i < length cs && charName (cs !! i) == player
    goBudget 0 s = s
    goBudget k s =
      let (actor, s1) = advance s
      in if charName actor == player
           then s1
           else let (_, s2) = npcAct lookaheadDepth actor s1
                in goBudget (k - 1) s2

-- | 世界投影视图（地点从 at 事实提取）。
praxView :: Session -> SessionView
praxView (Session wid player st) =
  let locs = locationIndex st
      hereOf who = Map.lookup who locs
      playerLoc = hereOf player
  in SessionView
       { viewWorldId       = wid
       , viewPlayer        = player
       , viewLocationId    = playerLoc
       , viewLocationLabel = playerLoc
       , viewActors =
           [ SessionActor (charName c) (hereOf (charName c))
           | c <- characters st ]
       }

-- | 解析 @practice.world.world.at.<who>!<place>@（标签忠实）→ who ↦ place。
locationIndex :: PraxState -> Map.Map String String
locationIndex st =
  Map.fromList $ mapMaybe parseAt (dbToLabeledSentences (db st))
  where
    pref = "practice.world.world.at."
    parseAt s
      | pref `isPrefixOf` s =
          let rest = drop (length pref) s
          in case break (== '!') rest of
               (who, '!' : place) | not (null who), not (null place) ->
                 Just (who, place)
               _ -> Nothing
      | otherwise = Nothing

-- | 玩家菜单（藏空 outcome；id 为 ga:v1 canonical）。
praxMenu :: Session -> [MenuItem]
praxMenu (Session _ player st) =
  case filter ((== player) . charName) (characters st) of
    (actor : _) -> map toItem (playerActions st actor)
    []          -> []
  where
    toItem ga = MenuItem
      { menuActionId   = encodeActionId ga
      , menuLabel      = gaLabel ga
      , menuPracticeId = gaPracticeId ga
      , menuActionName = gaActionId ga
      }

-- | 与 CLI @playerActions@ 同源：'candidateActions' 去掉空 outcome。
playerActions :: PraxState -> Character -> [GroundedAction]
playerActions st actor = filter (not . isNoOp) (candidateActions st actor)
  where
    isNoOp ga = case Map.lookup (gaPracticeId ga) (practiceDefs st) of
      Just def | (a : _) <- filter ((== gaActionId ga) . actionName) (actions def)
                 -> null (actionOutcomes a)
      _          -> False

-- | 玩家整回合：按 actionId 执行 + NPC 推进直至再轮到玩家。
praxAct :: Session -> String -> Either String (Session, ActResult)
praxAct (Session wid player st) aid =
  case filter ((== player) . charName) (characters st) of
    [] -> Left "Prax.Session.praxAct: player not in cast"
    (actor : _) ->
      case filter ((== aid) . encodeActionId) (playerActions st actor) of
        [] -> Left ("Prax.Session.praxAct: unknown actionId " ++ show aid)
        (ga : _) ->
          let before = dbToSentences (db st)
              st1 = performAction st ga
              (narr0, st2) = runUntilPlayer player [gaLabel ga] st1
              narr = narr0 ++ trustNarrativeLines before (dbToSentences (db st2))
              sess' = Session wid player st2
              result = ActResult narr (praxView sess') (praxMenu sess')
          in Right (sess', result)

-- | 玩家稍候（对齐 CLI @m@）：不行动，让 NPC 推进直至再轮到玩家。
praxWait :: Session -> Either String (Session, ActResult)
praxWait (Session wid player st) =
  let before = dbToSentences (db st)
      (narr0, st2) = runUntilPlayer player [] st
      narr = narr0 ++ trustNarrativeLines before (dbToSentences (db st2))
      sess' = Session wid player st2
  in Right (sess', ActResult narr (praxView sess') (praxMenu sess'))

-- | 本回合新增的 @*.relationship.*.trust.reason.*@ → 中文可读行（不扩 View）。
-- 供 Act.narrative 感知 trust/闲话后果；通用（不限 my-town）。
trustNarrativeLines :: [String] -> [String] -> [String]
trustNarrativeLines before after =
  mapMaybe reasonLine [ s | s <- after, s `notElem` before ]
  where
    reasonLine s = case parseTrustReason s of
      Just (who, target, reason) -> Just (renderTrust who target reason)
      Nothing -> Nothing

    parseTrustReason s =
      case split1 ".relationship." s of
        Just (who, rest) ->
          case split1 ".trust.reason." rest of
            Just (target, reason)
              | all (not . null) [who, target, reason]
                , all (/= '.') reason
                -> Just (who, target, reason)
            _ -> Nothing
        Nothing -> Nothing

    split1 sep xs =
      let go pref rem_
            | null rem_ = Nothing
            | Just suf <- stripPrefix sep rem_ = Just (reverse pref, suf)
            | otherwise = go (head rem_ : pref) (tail rem_)
      in go [] xs

    renderTrust who target reason = case reason of
      "helpedMe"   -> who ++ " 对 " ++ target ++ " 的信任上调（helpedMe）"
      "sawHelp"    -> who ++ " 对 " ++ target ++ " 的信任上调（sawHelp）"
      "heardRumor" -> who ++ " 对 " ++ target ++ " 的信任下调（heardRumor／怀疑）"
      _            -> who ++ " 对 " ++ target ++ " 的信任变化（" ++ reason ++ "）"

-- | 从「玩家刚行动后 / 刚选择稍候」的状态推进 NPC，直到再次轮到玩家。
-- 与 @app/Main.hs@ @loop@ 一致：每次先 'advance'，非玩家则 'npcAct'；
-- 停下时 cursor 已落在玩家身上。
runUntilPlayer :: String -> [String] -> PraxState -> ([String], PraxState)
runUntilPlayer player acc0 = go (reverse acc0)
  where
    go acc st =
      let (actor, st1) = advance st
      in if charName actor == player
           then (reverse acc, st1)
           else let (mga, st2) = npcAct lookaheadDepth actor st1
                    acc' = maybe acc (\ga -> gaLabel ga : acc) mga
                in go acc' st2

-- | Save：JSON meta + Persist blob。
praxSave :: Session -> String
praxSave (Session wid _ st) =
  BLC.unpack $ encode SaveMeta
    { saveFormat  = "prax-state-v4"
    , saveWorldId = wid
    , saveBlob    = serializeState st
    }

-- | Load：校验 format + worldId，模板上 deserialize，并确保落在玩家回合。
praxLoad :: String -> Either String Session
praxLoad raw = do
  meta <- case eitherDecode (BLC.pack raw) of
            Left e  -> Left ("Prax.Session.praxLoad: JSON " ++ e)
            Right m -> Right (m :: SaveMeta)
  if saveFormat meta /= "prax-state-v4"
    then Left ("Prax.Session.praxLoad: unsupported format " ++ show (saveFormat meta))
    else do
      (world, player) <- worldTemplate (saveWorldId meta)
      let st0 = deserializeState (saveBlob meta) world
          st1 = ensurePlayerTurn player st0
      pure (Session (saveWorldId meta) player st1)

-- ---------------------------------------------------------------------------
-- action.id = ga:v1 canonical（对齐 Persist GaRepr，不含 label）
-- ---------------------------------------------------------------------------

-- | 与 Persist 内部一致的 Val 文本化（符号用名，非 id）。
data ValRepr = RS String | RN Integer | RT [[String]]
  deriving (Eq, Show, Read)

reprVal :: Val -> ValRepr
reprVal (VSym s)  = RS (symName s)
reprVal (VNum n)  = RN n
reprVal (VSet xs) = RT (map (map symName) xs)

type GaKey = (String, String, String, [(String, ValRepr)])

-- | @ga:v1:@ ++ Show GaKey。
encodeActionId :: GroundedAction -> String
encodeActionId ga =
  "ga:v1:" ++ show
    ( gaPracticeId ga
    , gaInstanceId ga
    , gaActionId ga
    , [ (symName k, reprVal v) | (k, v) <- Map.toList (gaBindings ga) ]
    )

-- | 解析 canonical id；失败则 Left。
decodeActionId :: String -> Either String GaKey
decodeActionId s
  | "ga:v1:" `isPrefixOf` s =
      case readMaybe (drop (length ("ga:v1:" :: String)) s) of
        Just key -> Right key
        Nothing  -> Left ("Prax.Session.decodeActionId: malformed payload in " ++ show s)
  | otherwise = Left ("Prax.Session.decodeActionId: missing ga:v1: prefix in " ++ show s)

