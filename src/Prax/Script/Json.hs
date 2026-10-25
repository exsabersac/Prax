{-# LANGUAGE OverloadedStrings #-}
-- | "Prax.Script" 的 JSON 编解码（外部创作表面）。
--
-- @FromJSON@/@ToJSON@ 实例让剧本可从 JSON 进出；'Junction' 的解码是文档化的外部创作路径，
-- 因此 v40 卫生检查放在 'Prax.Script.compile' 消费点，而非智能构造器。

module Prax.Script.Json
  ( encodeScript
  , decodeScript
  , loadScript
  , saveScript
  ) where

import           Control.Applicative ((<|>))
import qualified Data.ByteString.Lazy as BL
import           Data.Aeson
import           Data.Aeson.Types (Parser)
import           Data.Maybe (isJust)

import           Prax.Query (Condition (..), CmpOp (..), CalcOp (..))
import           Prax.Types (Outcome (..), Want (..))
import           Prax.Script

-- Public API ------------------------------------------------------------------

-- | 把剧本序列化为 JSON（紧凑；可经美化管道）。
encodeScript :: Script -> BL.ByteString
encodeScript = encode

-- | 从 JSON 解析剧本，报告 aeson 错误。
decodeScript :: BL.ByteString -> Either String Script
decodeScript = eitherDecode

-- | 从 @.json@ 文件加载并解析剧本。
loadScript :: FilePath -> IO (Either String Script)
loadScript path = decodeScript <$> BL.readFile path

-- | 把剧本写入 @.json@ 文件。
saveScript :: FilePath -> Script -> IO ()
saveScript path = BL.writeFile path . encodeScript

-- Enum tags -------------------------------------------------------------------

cmpTag :: CmpOp -> String
cmpTag Lt = "lt"; cmpTag Lte = "lte"; cmpTag Gt = "gt"; cmpTag Gte = "gte"

parseCmp :: String -> Parser CmpOp
parseCmp "lt" = pure Lt; parseCmp "lte" = pure Lte
parseCmp "gt" = pure Gt; parseCmp "gte" = pure Gte
parseCmp s    = fail ("unknown comparison operator " ++ show s)

calcTag :: CalcOp -> String
calcTag Add = "add"; calcTag Sub = "sub"; calcTag Mul = "mul"; calcTag Mod = "mod"

parseCalc :: String -> Parser CalcOp
parseCalc "add" = pure Add; parseCalc "sub" = pure Sub; parseCalc "mul" = pure Mul
parseCalc "mod" = pure Mod
parseCalc s     = fail ("unknown calc operator " ++ show s)

-- Conditions ------------------------------------------------------------------

instance ToJSON Condition where
  toJSON c = case c of
    Match s               -> object [ "match"  .= s ]
    Not s                 -> object [ "not"    .= s ]
    Eq a b                -> object [ "eq"     .= [a, b] ]
    Neq a b               -> object [ "neq"    .= [a, b] ]
    Cmp op a b            -> object [ "cmp"    .= [cmpTag op, a, b] ]
    Calc r op a b         -> object [ "calc"   .= [r, calcTag op, a, b] ]
    Count r s             -> object [ "count"  .= [r, s] ]
    Subquery set find whr -> object [ "subquery" .=
                               object [ "set" .= set, "find" .= find, "where" .= whr ] ]
    Or clauses            -> object [ "or"     .= clauses ]
    Absent cs             -> object [ "absent" .= cs ]
    Exists cs             -> object [ "exists" .= cs ]

instance FromJSON Condition where
  parseJSON = withObject "Condition" $ \o ->
        (Match  <$> o .: "match")
    <|> (Not    <$> o .: "not")
    <|> triadOr2 o "eq"  Eq
    <|> triadOr2 o "neq" Neq
    <|> (do [op, a, b] <- o .: "cmp"; (\op' -> Cmp op' a b) <$> parseCmp op)
    <|> (do [r, op, a, b] <- o .: "calc"; (\op' -> Calc r op' a b) <$> parseCalc op)
    <|> triadOr2 o "count" Count
    <|> (o .: "subquery" >>= withObject "subquery"
           (\s -> Subquery <$> s .: "set" <*> s .: "find" <*> s .: "where"))
    <|> (Or     <$> o .: "or")
    <|> (Absent <$> o .: "absent")
    <|> (Exists <$> o .: "exists")
    where
      -- a two-element string array under key @k@, applied to a binary constructor
      triadOr2 o k f = do
        xs <- o .: k
        case xs of
          [a, b] -> pure (f a b)
          _      -> fail ("expected [a, b] under " ++ show k)

-- Outcomes --------------------------------------------------------------------

instance ToJSON Outcome where
  toJSON (Insert s)     = object [ "insert" .= s ]
  toJSON (Delete s)     = object [ "delete" .= s ]
  toJSON (InsertFor n s) = object [ "insertFor" .= object [ "rounds" .= n, "sentence" .= s ] ]
  toJSON (Call fn args) = object [ "call" .= object [ "fn" .= fn, "args" .= args ] ]
  toJSON (ForEach conds outs) =
    object [ "forEach" .= object [ "when" .= conds, "do" .= outs ] ]
  toJSON (Roll num den conds outs) =
    object [ "roll" .= object [ "num" .= num, "den" .= den, "when" .= conds, "do" .= outs ] ]

instance FromJSON Outcome where
  parseJSON = withObject "Outcome" $ \o ->
        (Insert <$> o .: "insert")
    <|> (Delete <$> o .: "delete")
    <|> (o .: "insertFor" >>= withObject "insertFor"
           (\f -> InsertFor <$> f .: "rounds" <*> f .: "sentence"))
    <|> (o .: "call" >>= withObject "call"
           (\c -> Call <$> c .: "fn" <*> c .: "args"))
    <|> (o .: "forEach" >>= withObject "forEach"
           (\f -> ForEach <$> f .: "when" <*> f .: "do"))
    <|> (o .: "roll" >>= withObject "roll"
           (\r -> Roll <$> r .: "num" <*> r .: "den" <*> r .: "when" <*> r .: "do"))

-- Wants -----------------------------------------------------------------------

instance ToJSON Want where
  toJSON (Want conds u) = object [ "when" .= conds, "utility" .= u ]

instance FromJSON Want where
  parseJSON = withObject "Want" $ \o -> Want <$> o .: "when" <*> o .: "utility"

-- Script AST ------------------------------------------------------------------

instance ToJSON CastMember where
  toJSON (CastMember n p ds ts) =
    object [ "name" .= n, "playable" .= p, "desires" .= ds, "traits" .= ts ]

instance FromJSON CastMember where
  parseJSON = withObject "CastMember" $ \o ->
    CastMember <$> o .: "name"
               <*> o .:? "playable" .!= False
               <*> o .:? "desires"  .!= []
               <*> o .:? "traits"   .!= []

instance ToJSON Beat where
  toJSON (Beat lbl spk cs es) =
    object $ [ "label" .= lbl, "when" .= cs, "effects" .= es ]
             ++ maybe [] (\s -> [ "speaker" .= s ]) spk

instance FromJSON Beat where
  parseJSON = withObject "Beat" $ \o ->
    Beat <$> o .:  "label"
         <*> o .:? "speaker"
         <*> o .:? "when"    .!= []
         <*> o .:? "effects" .!= []

instance ToJSON Junction where
  toJSON (Junction name to whn aft) =
    object $ [ "name" .= name, "when" .= whn ]
             ++ maybe [] (\t -> [ "to" .= t ]) to
             ++ maybe [] (\n -> [ "after" .= n ]) aft

instance FromJSON Junction where
  parseJSON = withObject "Junction" $ \o ->
    Junction <$> o .:  "name"
             <*> o .:? "to"
             <*> o .:? "when" .!= []
             <*> o .:? "after"

instance ToJSON Scene where
  toJSON (Scene sid op setup beats juncs) =
    object [ "id" .= sid, "opening" .= op, "setup" .= setup
           , "beats" .= beats, "junctions" .= juncs ]

-- | 对 @"memories"@ 字段响亮而非沉默：aeson 的泛型会静默忽略未知字段；此处显式拒绝过时键。
instance FromJSON Scene where
  parseJSON = withObject "Scene" $ \o -> do
    hasMemories <- isJust <$> (o .:? "memories" :: Parser (Maybe Value))
    if hasMemories
      then fail "Prax.Script.Json: Scene's \"memories\" field is no longer \
                \supported -- the memory feature was removed (spec v46); \
                \author scene content via setup/beats/junctions instead"
      else Scene <$> o .:  "id"
                 <*> o .:? "opening"   .!= ""
                 <*> o .:? "setup"     .!= []
                 <*> o .:? "beats"     .!= []
                 <*> o .:? "junctions" .!= []

instance ToJSON Script where
  toJSON (Script cast scenes start) =
    object [ "start" .= start, "cast" .= cast, "scenes" .= scenes ]

instance FromJSON Script where
  parseJSON = withObject "Script" $ \o ->
    Script <$> o .: "cast" <*> o .: "scenes" <*> o .: "start"
