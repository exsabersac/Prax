-- | 宿主嵌入表面（v66；v71 增强）：薄封装既有引擎入口，供外部循环调用——
-- @step@/@stepExact@ 推进一名行动者的选定动作；@inject@ 写入结果；
-- @queryFacts@/@queryView@ 只读扫描；@available@/@availableActions@ 列菜单。
-- 无新语义；有意保持符号、无外部模型。
-- v97：'checkpoint'/'restore' 薄封 Persist 存档。
-- v85：'queryChronicle'/'explainActor' 薄封编年史与检查器。
-- v109：'queryMatching'/'queryViewMatching' 批量过滤；'factDelta' 事件订阅钩底物（两态差分）。
-- v158：'regardsOf' 枚举闭合视图中某人发出的站队叶。
module Prax.Host
  ( step
  , stepExact
  , inject
  , queryFacts
  , queryView
  , queryMatching
  , queryViewMatching
  , factDelta
  , factDeltaMatching
  , available
  , availableMatching
  , availableActions
  , queryChronicle
  , queryChronicleMatching
  , explainActor
  , explainActorMatching
  , castNames
  , livingCast
  , deadCast
  , livingMatching
  , practiceNames
  , regardsOf
  , membersOf
  , affiliatesOf
  , leadersOf
  , checkpoint
  , restore
  ) where

import           Data.List (isInfixOf, isPrefixOf, sort, (\\))
import qualified Data.Map.Strict as Map

import           Prax.Db (dbToSentences, exists)
import           Prax.Types (GroundedAction (..), Outcome, PraxState (..), Character (..), gaLabel, readView, livingCharacters)
import           Prax.Engine (performAction, performOutcome, possibleActions)
import           Prax.Chronicle (askChronicle)
import           Prax.Inspect (explain, explainMatching)
import           Prax.Persist (saveState, loadState)

-- | 当前角色可选动作标签（宿主菜单）。
available :: PraxState -> String -> [String]
available st actor = map gaLabel (possibleActions st actor)

-- | 过滤菜单：标签含 @needle@ 的可用动作。
availableMatching :: PraxState -> String -> String -> [String]
availableMatching st actor needle =
  filter (needle `isInfixOf`) (available st actor)

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

-- | 当前已定义实践 id（读 'practiceDefs'，非实例事实）。
practiceNames :: PraxState -> [String]
practiceNames st = Map.keys (practiceDefs st)




-- | 只读：闭合视图句子（含派生）。
queryView :: PraxState -> [String]
queryView = dbToSentences . readView

-- | 批量过滤：基库句子中含 @needle@ 的子集（宿主订阅/调试）。
queryMatching :: PraxState -> String -> [String]
queryMatching st needle = filter (needle `isInfixOf`) (queryFacts st)

-- | 批量过滤：闭合视图句子中含 @needle@ 的子集。
queryViewMatching :: PraxState -> String -> [String]
queryViewMatching st needle = filter (needle `isInfixOf`) (queryView st)

-- | 两态事实差分：@(added, removed)@ —— 宿主事件订阅钩的薄底物
-- （对 @inject@/@step@ 前后各拍一次即可）。
factDelta :: PraxState -> PraxState -> ([String], [String])
factDelta before after =
  let a = queryFacts after
      b = queryFacts before
  in (a \\ b, b \\ a)

-- | 过滤 'factDelta'：只保留增/删两侧含 @needle@ 的事实。
factDeltaMatching :: String -> PraxState -> PraxState -> ([String], [String])
factDeltaMatching needle before after =
  let (added, removed) = factDelta before after
      keep = filter (needle `isInfixOf`)
  in (keep added, keep removed)

-- | 编年史查询（只读）：转发 'Prax.Chronicle.askChronicle'。
queryChronicle :: PraxState -> String -> [String]
queryChronicle = askChronicle

-- | 过滤编年史答：只保留含 @needle@ 的行。
queryChronicleMatching :: PraxState -> String -> String -> [String]
queryChronicleMatching st q needle =
  filter (needle `isInfixOf`) (queryChronicle st q)

-- | 动作检查器：对 @actor@ 解释标签含 @needle@ 的动作为何可用/阻塞。
explainActor :: PraxState -> String -> String -> [String]
explainActor = explain

-- | 过滤 'explainActor'：只保留含 @needle@ 的解释行。
explainActorMatching :: PraxState -> String -> String -> String -> [String]
explainActorMatching = explainMatching

-- | 当前存活阵容名（跳过 dead.*）。
-- | 全阵容名（含死者）。
castNames :: PraxState -> [String]
castNames = map charName . characters

livingCast :: PraxState -> [String]
livingCast = map charName . livingCharacters

-- | 当前阵容中已标记 @dead.<name>@ 的角色名。
deadCast :: PraxState -> [String]
deadCast st =
  [ charName c
  | c <- characters st
  , exists ("dead." ++ charName c) (db st)
  ]

-- | 过滤存活阵容：名含 @needle@ 的角色。
livingMatching :: PraxState -> String -> [String]
livingMatching st needle = filter (needle `isInfixOf`) (livingCast st)

-- | 闭合视图中 @who@ 发出的站队叶（@regards.<who>.*@）。
regardsOf :: PraxState -> String -> [String]
regardsOf st who =
  filter (("regards." ++ who ++ ".") `isPrefixOf`) (queryView st)

-- | 闭合视图中主成员属于 @faction@ 的角色名（@member.<who>.<faction>@；
-- 排他 @!@ 在视图句子中展成 @.@）。
membersOf :: PraxState -> String -> [String]
membersOf st faction = sort
  [ who
  | s <- queryView st
  , let pref = "member."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, fac) = splitLastDot rest
  , fac == faction
  , not (null who)
  , '.' `notElem` who
  ]
  where
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中 @who@ 的次级归属派系名（@affiliate.<who>.<faction>@）。
affiliatesOf :: PraxState -> String -> [String]
affiliatesOf st who =
  let pref = "affiliate." ++ who ++ "."
  in sort
       [ drop (length pref) s
       | s <- queryView st, pref `isPrefixOf` s
       , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中领导 @faction@ 的角色名（@leads.<faction>.<who>@；
-- 排他 @!@ 在视图句子中展成 @.@）。
leadersOf :: PraxState -> String -> [String]
leadersOf st faction =
  let pref = "leads." ++ faction ++ "."
  in sort
       [ drop (length pref) s
       | s <- queryView st, pref `isPrefixOf` s
       , '.' `notElem` drop (length pref) s ]

-- | 把状态写入 @path@（JSON 格式，见 'Prax.Persist'）。
checkpoint :: FilePath -> PraxState -> IO ()
checkpoint = saveState

-- | 从 @path@ 恢复状态到新鲜 @world@ 模板上（与 'Prax.Persist.loadState' 同形）。
restore :: FilePath -> PraxState -> IO PraxState
restore = loadState
