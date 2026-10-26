{-# LANGUAGE OverloadedStrings #-}
-- | 浏览器可达的 Session JSON-lines 桥（M2 前、wasm 前）。
-- 每行一个 JSON 请求，回一行 JSON 响应；状态在进程内 IORef。
-- 协议：new / view / menu / act / wait / save / load / quit
module Main (main) where

import           Control.Concurrent.MVar (MVar, newMVar, modifyMVar, readMVar, swapMVar)
import           Control.Exception (SomeException, try)
import           Data.Aeson (FromJSON (..), ToJSON (..), Value, decodeStrict',
                             eitherDecodeStrict', encode, object, withObject,
                             (.:), (.:?), (.=))
import           Data.Aeson.Key (fromString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as BL
import           Data.Maybe (fromMaybe)
import           System.IO (BufferMode (..), hFlush, hSetBuffering, isEOF, stdin, stdout)

import           Prax.Session

data Req = Req
  { reqOp       :: String
  , reqWorldId  :: Maybe String
  , reqActionId :: Maybe String
  , reqRaw      :: Maybe String
  }

instance FromJSON Req where
  parseJSON = withObject "Req" $ \o ->
    Req <$> o .: "op"
        <*> o .:? "worldId"
        <*> o .:? "actionId"
        <*> o .:? "raw"

okFields :: [(String, Value)] -> BL.ByteString
okFields kvs = encode (object (("ok" .= True) : [ fromString k .= v | (k, v) <- kvs ]))

errObj :: String -> String -> BL.ByteString
errObj e msg = encode (object ["ok" .= False, "error" .= e, "message" .= msg])

writeLine :: BL.ByteString -> IO ()
writeLine bs = BL.hPut stdout bs >> BS.hPut stdout (BSC.singleton '\n') >> hFlush stdout

main :: IO ()
main = do
  hSetBuffering stdin LineBuffering
  hSetBuffering stdout LineBuffering
  slot <- newMVar (Nothing :: Maybe Session)
  loop slot

loop :: MVar (Maybe Session) -> IO ()
loop slot = do
  eof <- isEOF
  if eof
    then pure ()
    else do
      line <- BS.hGetLine stdin
      if BS.null line
        then loop slot
        else do
          out <- handleLine slot line
          writeLine out
          -- quit 后退出
          case decodeStrict' line of
            Just (Req { reqOp = "quit" }) -> pure ()
            _ -> loop slot

handleLine :: MVar (Maybe Session) -> BS.ByteString -> IO BL.ByteString
handleLine slot line =
  case eitherDecodeStrict' line of
    Left e -> pure (errObj "bad_json" e)
    Right req -> do
      r <- try (dispatch slot req) :: IO (Either SomeException BL.ByteString)
      case r of
        Left ex -> pure (errObj "exception" (show ex))
        Right bs -> pure bs

dispatch :: MVar (Maybe Session) -> Req -> IO BL.ByteString
dispatch slot req = case reqOp req of
  "new" -> case praxNew (fromMaybe "my-town" (reqWorldId req)) of
    Left e -> pure (errObj "praxNew" e)
    Right s -> do
      _ <- swapMVar slot (Just s)
      pure $ okFields
        [ ("worldId", toJSON (sessWorldId s))
        , ("playerId", toJSON (sessPlayer s))
        , ("view", toJSON (praxView s))
        , ("menu", toJSON (praxMenu s))
        ]
  "view" -> withSess slot $ \s ->
    pure $ okFields [("view", toJSON (praxView s))]
  "menu" -> withSess slot $ \s ->
    pure $ okFields [("menu", toJSON (praxMenu s))]
  "act" -> case reqActionId req of
    Nothing -> pure (errObj "missing_actionId" "act 需要 actionId")
    Just aid -> modifyMVar slot $ \ms -> case ms of
      Nothing -> pure (Nothing, errObj "no_session" "尚未 praxNew")
      Just s -> case praxAct s aid of
        Left e -> pure (Just s, errObj "praxAct" e)
        Right (s', ar) ->
          pure ( Just s'
               , okFields
                   [ ("accepted", toJSON True)
                   , ("narrative", toJSON (actNarrative ar))
                   , ("view", toJSON (actView ar))
                   , ("menu", toJSON (actMenu ar))
                   ]
               )
  "wait" -> modifyMVar slot $ \ms -> case ms of
    Nothing -> pure (Nothing, errObj "no_session" "尚未 praxNew")
    Just s -> case praxWait s of
      Left e -> pure (Just s, errObj "praxWait" e)
      Right (s', ar) ->
        pure ( Just s'
             , okFields
                 [ ("accepted", toJSON True)
                 , ("narrative", toJSON (actNarrative ar))
                 , ("view", toJSON (actView ar))
                 , ("menu", toJSON (actMenu ar))
                 ]
             )
  "save" -> withSess slot $ \s ->
    pure $ okFields [("save", toJSON (praxSave s))]
  "load" -> case reqRaw req of
    Nothing -> pure (errObj "missing_raw" "load 需要 raw")
    Just raw -> case praxLoad raw of
      Left e -> pure (errObj "praxLoad" e)
      Right s -> do
        _ <- swapMVar slot (Just s)
        pure $ okFields
          [ ("worldId", toJSON (sessWorldId s))
          , ("playerId", toJSON (sessPlayer s))
          , ("view", toJSON (praxView s))
          , ("menu", toJSON (praxMenu s))
          ]
  "quit" -> pure (okFields [("bye", toJSON True)])
  other -> pure (errObj "unknown_op" ("未知 op: " ++ other))

withSess :: MVar (Maybe Session) -> (Session -> IO BL.ByteString) -> IO BL.ByteString
withSess slot f = do
  ms <- readMVar slot
  case ms of
    Nothing -> pure (errObj "no_session" "尚未 praxNew")
    Just s  -> f s
