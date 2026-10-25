-- | 创作检查器：「此动作为何不可用？」（Versu 的运行时检查器——「查明动作为何前置失败」）。
--
-- 动作的条件是从左到右求值的合取 @[Condition]@。'firstFailing' 找到其前缀清空绑定集的第一个
-- 条件——即裁定动作出局的那个——复活 Praxish 的 @killsPerStep@。'explain' 为动作可应用到的每个
-- 实践实例呈现它。复用查询求值器；无引擎变更。
module Prax.Inspect
  ( firstFailing
  , explain
  , explainMatching
  ) where

import           Data.List (intercalate, isInfixOf)
import qualified Data.Map.Strict as Map
import           Data.Maybe (listToMaybe)

import           Prax.Db (Bindings, Db, Val (..), childKeys, unify)
import           Prax.Query (Condition, query)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Engine (renderText)

-- | 求值序中合取首次无解之后的第一个条件——「此动作为何不可用？」的答案。
firstFailing :: Db -> [Condition] -> Bindings -> Maybe Condition
firstFailing d conds b0 =
  listToMaybe [ conds !! (k - 1)
              | k <- [1 .. length conds]
              , null (query d (take k conds) b0) ]

-- | 对 @actor@，解释名字含 @needle@ 的每个动作：对每个动作，报告 'firstFailing' 条件（若有）。
explain :: PraxState -> String -> String -> [String]
explain st actor needle =
  [ label ++ verdict
  | pid <- childKeys "practice" (db st)
  , Just def <- [Map.lookup pid (practiceDefs st)]
  , let instanceQuery = intercalate "." ("practice" : pid : roles def)
  , inst <- unify instanceQuery (db st) (Map.singleton (intern "Actor") (VSym (intern actor)))
  , a <- actions def
  , let label = renderText (actionName a) inst
  , needle `isInfixOf` label
  , let verdict = case firstFailing (db st) (actionConditions a) inst of
                    Nothing -> " — AVAILABLE"
                    Just c  -> " — blocked by: " ++ show c ]

-- | 过滤 'explain'：只保留含 @needle@ 的解释行。
explainMatching :: PraxState -> String -> String -> String -> [String]
explainMatching st actor label needle =
  filter (needle `isInfixOf`) (explain st actor label)
