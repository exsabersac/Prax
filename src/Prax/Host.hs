-- | 宿主嵌入表面（v66）：薄封装既有引擎入口，供外部循环调用——
-- @step@ 推进一名行动者的选定动作；@inject@ 写入结果；@queryFacts@ 只读扫描基库。
-- 无新语义；有意保持符号、无外部模型。
module Prax.Host
  ( step
  , inject
  , queryFacts
  , available
  ) where

import           Data.List (isInfixOf)

import           Prax.Db (dbToSentences)
import           Prax.Types (GroundedAction (..), Outcome, PraxState (..), gaLabel)
import           Prax.Engine (performAction, performOutcome, possibleActions)

-- | 当前角色可选动作标签（宿主菜单）。
available :: PraxState -> String -> [String]
available st actor = map gaLabel (possibleActions st actor)

-- | 执行 @actor@ 的第一个标签含 @needle@ 的动作；找不到则原样返回 @Left@。
step :: PraxState -> String -> String -> Either String PraxState
step st actor needle =
  case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st actor) of
    (ga : _) -> Right (performAction st ga)
    []       -> Left ("Host.step: no action matching " ++ show needle
                      ++ " for " ++ actor
                      ++ "; had: " ++ show (available st actor))

-- | 注入一串结果（叙事事件、导演指令等）。
inject :: PraxState -> [Outcome] -> PraxState
inject st outs = foldl (flip performOutcome) st outs

-- | 只读：基库句子（不含派生视图）。
queryFacts :: PraxState -> [String]
queryFacts = dbToSentences . db
