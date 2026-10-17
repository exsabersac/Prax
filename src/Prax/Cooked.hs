-- | 结果语言的煮熟镜像——创作的世界一次编译为 token/名称形式。字符串仍是创作表面；它们停止
-- 作为计算表面（见 @docs/specs/2026-07-12-v28-cooked-world.md@）。煮熟条件侧
-- （'CookedCondition'、'cookCondition'、'groundNames'、'groundCookedCondition'）住在
-- "Prax.Query"——其唯一归宿——在此导入，不重导出；需要它的调用者直接导入 "Prax.Query"。
--
-- 'CookedOutcome'\/'CookedAction'\/'CookedPractice' 本身在 "Prax.Types" 中声明（不在此）：
-- 'Prax.Types.PraxState' 在其 'Prax.Types.cookedDefs' 字段嵌入 'Prax.Types.CookedPractice'，且
-- "Prax.Cooked" 已为 'Outcome'\/'Practice' 依赖 "Prax.Types"——双模块环，与 Task 1 条件侧同一形状。
-- 本模块只拥有转换函数；需要类型的调用者直接导入 "Prax.Types"（触及 'PraxState' 的每个模块已如此）。
module Prax.Cooked
  ( cookOutcome
  , groundCookedOutcome
  , cookPractice
  , cookFunctions
  , cookScheduleRule
  ) where

import qualified Data.Map.Strict as Map
import           Data.Map.Strict (Map)

import           Prax.Db (Bindings, groundTokens, internTokens)
import           Prax.Query (CookedCondition, cookCondition, groundCookedCondition, groundNames)
import           Prax.Sym (intern)
import           Prax.Types

-- | Compile an 'Outcome' to its cooked form (see 'CookedOutcome').
cookOutcome :: Outcome -> CookedOutcome
cookOutcome o = case o of
  Insert s          -> CInsert (internTokens s)
  Delete s          -> CDelete (internTokens s)
  InsertFor n s     -> CInsertFor n (internTokens s)
  Call fn args      -> CCall fn (map intern args)
  ForEach conds outs -> CForEach (map cookCondition conds) (map cookOutcome outs)
  Roll num den conds outs -> CRoll num den (map cookCondition conds) (map cookOutcome outs)

-- | Substitute bindings into a cooked outcome. 'CInsert'/'CDelete' reuse
-- 'Prax.Db.groundTokens' directly — no string rebuild; 'CCall' args are
-- single names, substituted the same way as 'groundNames'.
groundCookedOutcome :: Bindings -> CookedOutcome -> CookedOutcome
groundCookedOutcome b o = case o of
  CInsert toks        -> CInsert (groundTokens toks b)
  CDelete toks         -> CDelete (groundTokens toks b)
  CInsertFor n toks    -> CInsertFor n (groundTokens toks b)
  CCall fn args        -> CCall fn (groundNames b args)
  CForEach conds outs  -> CForEach (map (groundCookedCondition b) conds)
                                    (map (groundCookedOutcome b) outs)
  CRoll num den conds outs -> CRoll num den (map (groundCookedCondition b) conds)
                                            (map (groundCookedOutcome b) outs)

-- | Compile a 'Practice' to its cooked form (see 'CookedPractice'): every
-- action's conditions/outcomes and every init outcome precooked; the
-- instance-unification pattern (@practice.\<pid\>.\<Role1\>...@) pre-split
-- once. Functions live in the world registry, not on practices (spec v47) —
-- 'cookFunctions' cooks them.
cookPractice :: Practice -> CookedPractice
cookPractice p = CookedPractice
  { cpInstanceNames = map intern ("practice" : practiceId p : roles p)
    -- ^ Built as a segment list directly, not a dotted string reparsed by
    -- 'pathNames': a zero-role practice has 'roles' @[]@, and joining with
    -- @"."@ then re-splitting would leave a trailing separator with nothing
    -- after it -- illegal input to 'Prax.Db.tokens' (v43). The segment list
    -- has no such degenerate case to begin with.
  , cpActions = map cookAction (actions p)
  , cpInits   = map cookOutcome (initOutcomes p)
  }
  where
    cookAction a = CookedAction
      { caName  = actionName a
      , caConds = map cookCondition (actionConditions a)
      , caOuts  = map cookOutcome (actionOutcomes a)
      }

-- | Cook a function registry: each 'Function' keyed by 'fnName', paired with
-- its 'fnParams' and cooked cases — the shape 'lookupCookedFn' and the cooked
-- hot path ('Prax.Engine.performCooked') read, so neither falls back to a
-- string-side 'fnParams' lookup. A plain 'Map.fromList': 'Prax.Engine.defineFunctions'
-- guards uniqueness loudly before any duplicate 'fnName' could reach here, so
-- the Map never silently collapses one.
cookFunctions :: [Function]
              -> Map String ([String], [([CookedCondition], [CookedOutcome])])
cookFunctions fs = Map.fromList
  [ (fnName f, (fnParams f, [ (map cookCondition (caseConditions c), map cookOutcome (caseOutcomes c))
                            | c <- fnCases f ]))
  | f <- fs ]

-- | Compile a 'ScheduleRule' to its cooked form (see 'CookedScheduleRule'):
-- every body clause's conditions and outcomes precooked; the name carried
-- unchanged (a lookup key, never unified).
cookScheduleRule :: ScheduleRule -> CookedScheduleRule
cookScheduleRule r = CookedScheduleRule
  { csrName = srName r
  , csrBody = [ (map cookCondition conds, map cookOutcome outs)
              | (conds, outs) <- srBody r ]
  }
