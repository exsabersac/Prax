-- | 宿主嵌入表面（v66；v71 增强）：薄封装既有引擎入口，供外部循环调用——
-- @step@/@stepExact@ 推进一名行动者的选定动作；@inject@ 写入结果；
-- @queryFacts@/@queryView@ 只读扫描；@available@/@availableActions@ 列菜单。
-- 无新语义；有意保持符号、无外部模型。
-- v97：'checkpoint'/'restore' 薄封 Persist 存档。
-- v85：'queryChronicle'/'explainActor' 薄封编年史与检查器。
module Prax.Host
  ( step
  , stepExact
  , inject
  , queryFacts
  , queryView
  , available
  , availableActions
  , queryChronicle
  , explainActor
  , livingCast
  , checkpoint
  , restore
  ) where

import           Data.List (isInfixOf)

import           Prax.Db (dbToSentences)
import           Prax.Types (GroundedAction (..), Outcome, PraxState (..), Character (..), gaLabel, readView, livingCharacters)
import           Prax.Engine (performAction, performOutcome, possibleActions)
import           Prax.Chronicle (askChronicle)
import           Prax.Inspect (explain)
import           Prax.Persist (saveState, loadState)

-- | 当前角色可选动作标签（宿主菜单）。
available :: PraxState -> String -> [String]
available st actor = map gaLabel (possibleActions st actor)

-- | 完整落地动作列表（宿主需要绑定\/实例 id 时用）。
availableActions :: PraxState -> String -> [GroundedAction]
availableActions = possibleActions

-- | 执行 @actor@ 的第一个标签含 @needle@ 的动作；找不到则原样返回 @Left@。
step :: PraxState -> String -> String -> Either String PraxState
step st actor needle =
  case filter ((needle `isInfixOf`) . gaLabel) (possibleActions st actor) of
    (ga : _) -> Right (performAction st ga)
    []       -> Left ("Host.step: no action matching " ++ show needle
                      ++ " for " ++ actor
                      ++ "; had: " ++ show (available st actor))

-- | 精确标签匹配（整串相等），避免 infix 误伤。
stepExact :: PraxState -> String -> String -> Either String PraxState
stepExact st actor label =
  case filter ((== label) . gaLabel) (possibleActions st actor) of
    (ga : _) -> Right (performAction st ga)
    []       -> Left ("Host.stepExact: no action with exact label " ++ show label
                      ++ " for " ++ actor
                      ++ "; had: " ++ show (available st actor))

-- | 注入一串结果（叙事事件、导演指令等）。
inject :: PraxState -> [Outcome] -> PraxState
inject st outs = foldl (flip performOutcome) st outs

-- | 只读：基库句子（不含派生视图）。
queryFacts :: PraxState -> [String]
queryFacts = dbToSentences . db

-- | 只读：闭合视图句子（含派生）。
queryView :: PraxState -> [String]
queryView = dbToSentences . readView

-- | 编年史查询（只读）：转发 'Prax.Chronicle.askChronicle'。
queryChronicle :: PraxState -> String -> [String]
queryChronicle = askChronicle

-- | 动作检查器：对 @actor@ 解释标签含 @needle@ 的动作为何可用/阻塞。
explainActor :: PraxState -> String -> String -> [String]
explainActor = explain

-- | 当前存活阵容名（跳过 dead.*）。
livingCast :: PraxState -> [String]
livingCast = map charName . livingCharacters

-- | 把状态写入 @path@（JSON 格式，见 'Prax.Persist'）。
checkpoint :: FilePath -> PraxState -> IO ()
checkpoint = saveState

-- | 从 @path@ 恢复状态到新鲜 @world@ 模板上（与 'Prax.Persist.loadState' 同形）。
restore :: FilePath -> PraxState -> IO PraxState
restore = loadState
