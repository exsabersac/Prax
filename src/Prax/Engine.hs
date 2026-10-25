-- | 解释器：注册实践、发现行动者的 affordance，以及把动作结果应用到世界
-- （含实践孵化与函数调用）。
--
-- @praxish.js@ 中 @Praxish.*@ 函数的类型化移植。全部操作是纯状态变换——planner
-- （"Prax.Planner"）利用这一点，推测性应用动作并直接丢弃结果，替换 Praxish 的
-- clone-and-undo。
module Prax.Engine
  ( definePractice
  , definePractices
  , defineFunctions
  , renderText
  , withDb
  , setAxioms
  , setDesires
  , setCharacters
  , setSchedule
  , seedDie
  , registerEngineRules
  , possibleActions
  , performAction
  , performOutcome
  , performCooked
  , groundOutcome
  , relevantDelta
  , monotoneInsert
  , groundedDeltaAnchors
  , currentTurn
  , roundBoundary
  ) where

import           Data.List (foldl', intercalate, isPrefixOf, nub, (\\))
import           Data.Maybe (listToMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import           Data.Set (Set)
import           Text.Read (readMaybe)

import           Prax.Db
import           Prax.Query (queryCooked, groundCondition, groundNames, CookedCondition(..), cookCondition)
import           Prax.Types
import           Prax.Derive (Axiom, axiomFootprint, axiomNegPatterns, axiomHeadPatterns, monotoneAxioms, cookAxioms, runCooked)
import           Prax.Relevance (improvableDesires, livenessOf, mayUnifySyms, evictionShadowNames, bearingTemplates)
import           Prax.Cooked (cookOutcome, cookPractice, cookFunctions, cookScheduleRule, groundCookedOutcome)
import           Prax.Rng (rollStep, seedBounds)
import           Prax.Sym (Sym, intern, symIsVar, symName)

-- | 重建派生词汇表。内部：每个变更 'practiceDefs'、'axioms'、'desires'、
-- 'characters'、'schedule' 或 'worldFns' 的助手必须以此结束。'cookedRules'
-- 仅从公理列表重煮（'cookAxioms'，无 census）——道义世界声明的任何 □-提升规则
-- （"Prax.Deontic.obligedClose"）已在 'axioms' 中，因此 retable 不决定任何提升。
-- 公理派生表（footprint\/axiomHeads\/negFootprint\/contMonotone）随后读该 'cookedRules'。
retable :: PraxState -> PraxState
retable st0 =
  let st = st0
        { cookedDefs     = Map.map cookPractice (practiceDefs st0)
        , cookedSchedule = map cookScheduleRule (schedule st0)
        , cookedWants   = Map.fromList
            [ (charName c, [ map cookCondition (wantConditions w) | w <- charWants c ])
            | c <- characters st0 ]
        , cookedDesires = Map.fromList
            [ (desireName d, map cookCondition (wantConditions (desireWant d)))
            | d <- desires st0 ] }
      st' = st { cookedRules = cookAxioms (axioms st0) }
  in st'
     { improvables  = improvableDesires st'
     , caresAbout   = bearingTemplates st'
     , liveness     = livenessOf st'
     , footprint    = axiomFootprint (cookedRules st')
     , axiomHeads   = axiomHeadPatterns (cookedRules st')
                      ++ [[intern "contradiction"]]
     , negFootprint = axiomNegPatterns (cookedRules st')
     , contMonotone = monotoneAxioms (cookedRules st') }

-- | 'relevantDelta' 的泛化：在已拆分、已 intern 的名字上运算——主 delta 的名字及其驱逐阴影
-- （各自已是名字列表）。热路径煮熟路径（'performCooked'）直接调用本函数——从不重解析或重 intern
-- 句子以找回它已有的 token。
relevantNames :: [Sym] -> [[Sym]] -> PraxState -> Bool
relevantNames names shadows st =
  any (\ns -> any (mayUnifySyms ns) (footprint st)) (names : shadows)

-- | 此落地 delta 能否改变公理所派生之物？保守：仅当句子——及其排他所驱逐的一切——
-- 与公理 footprint 中任何物均不可统一（may-unify）时为 False（v27 规格定理）。
-- False 是 'performOutcome' 跳过 'reclose' 的许可证。
relevantDelta :: String -> PraxState -> Bool
relevantDelta s = relevantNames (map fst toks) (evictionShadowNames toks)
  where toks = internTokens s

-- | 'monotoneInsert' 的泛化：在已拆分、已 intern 的 token 上运算。
monotoneToks :: [(Sym, Maybe Char)] -> PraxState -> Bool
monotoneToks toks st =
  contMonotone st
    && all ((/= Just '!') . snd) toks
    && not (any (mayUnifySyms (map fst toks)) (negFootprint st))

-- | 此插入可否走延续层：世界延续安全、插入不驱逐任何物、且不能击败任何物。
monotoneInsert :: String -> PraxState -> Bool
monotoneInsert s = monotoneToks (internTokens s)

-- | 延续层，原生在 token 上：经 'runCooked' 与状态预编译的 'cookedRules' 增长基并延续
-- *已闭合* 视图（一个新事实）——从不从 @toks@ 重建字符串。矛盾（⊥）回退到完整 'reclose'
-- 路径，从零到达同一 @"contradiction"@ 标记。
applyGrowToks :: [(Sym, Maybe Char)] -> PraxState -> PraxState
applyGrowToks toks st =
  case runCooked (cookedRules st) (insertToks toks (readView st)) (insertToks toks emptyDb) of
    Right v -> st { db = insertToks toks (db st), readView = v }
    Left _  -> withDb (insertToks toks) st

-- | 注册实践，并将其静态 @dataFacts@ 插入 @practiceData.<id>.@ 下。
definePractice :: Practice -> PraxState -> PraxState
definePractice p st
  | a : _ <- dupActions =
      error ("Prax.Engine.definePractice: practice " ++ show (practiceId p)
             ++ " declares two actions named " ++ show a
             ++ " -- action names are lookup keys (delta anchors, standing"
             ++ " intentions); rename one")
  | otherwise =
      retable (withDb (insertAll (map (prefix ++) (dataFacts p))) st)
        { practiceDefs = Map.insert (practiceId p) p (practiceDefs st) }
  where
    prefix = "practiceData." ++ practiceId p ++ "."
    names = map actionName (actions p)
    dupActions = [ n | (n, i) <- zip names [0 :: Int ..], n `elem` take i names ]

-- | 按序注册若干实践。
definePractices :: [Practice] -> PraxState -> PraxState
definePractices ps st = foldl' (flip definePractice) st ps

-- | 注册世界的函数——唯一归宿（'cookedFns'）。自 v47 起 'Practice' 不再携带函数：实践局部性是虚构，
-- 解析始终全局（'lookupCookedFn' 先胜搜索每个实践，'Call' 站点命名裸函数）。各煮入注册表并 retable，
-- 使函数池分析（'Prax.Relevance.producibleAtoms'、'improvableDesires'、'livenessOf'、'bearingTemplates'）
-- 看见词汇。重复 'fnName' 响亮报错——本批内或对照已注册集（v43 的两道每实践碰撞臂并入此检查：Map 不能静默持有重复，
-- 因此守卫使尝试响亮）。相对 'definePractices' 的次序无关：两 setter 各持久化自有字段（'cookedFns'\/'practiceDefs'），
-- 'retable' 读两者，谁最后跑都使每表一致。
defineFunctions :: [Function] -> PraxState -> PraxState
defineFunctions fs st
  | (fn : _) <- clashes =
      error ("Prax.Engine.defineFunctions: function " ++ show fn
             ++ " is already registered -- Call resolution is by bare name"
             ++ " (lookupCookedFn); rename one")
  | otherwise =
      retable st { worldFns  = worldFns st ++ fs
                 , cookedFns = Map.union (cookedFns st) (cookFunctions fs) }
  where
    newNames = map fnName fs
    existing = Map.keys (cookedFns st)
    clashes  = (newNames \\ nub newNames) ++ filter (`elem` existing) newNames

-- | 用绑定替换模板中的 @[Var]@ 占位符，未知占位符保持不动。
renderText :: String -> Bindings -> String
renderText template b = go template
  where
    go [] = []
    go ('[' : rest) =
      case break (== ']') rest of
        (name, ']' : after) ->
          maybe ('[' : name ++ "]") valToString (Map.lookup (intern name) b) ++ go after
        _ -> '[' : go rest      -- unterminated '['; emit literally
    go (c : rest) = c : go rest

-- | 重建缓存的闭合视图：经 'runCooked' 与预编译 'cookedRules'，在状态域 'axioms' 下前向链基 DB
-- （因此此约 5,400 次\/回合路径从不重煮公理集——'retable' 维护它，有门禁）。无公理时恰为 @db st@，
-- 未公理化世界不受影响且无代价。矛盾（@⊥@）表现为（仍一致的）基上可查询的 @contradiction@ 事实而非崩溃，
-- 以便世界或戏剧管理器可反应。内部：每个变更 'db' 或 'axioms' 的助手必须以此结束。
reclose :: PraxState -> PraxState
reclose st = st { readView = case runCooked (cookedRules st) (db st) (db st) of
                               Right closed -> closed
                               Left _       -> insert "contradiction" (db st) }

-- | 变更已构建状态事实基的唯一正当方式。
withDb :: (Db -> Db) -> PraxState -> PraxState
withDb f st = reclose st { db = f (db st) }

-- | 锁步将一 delta 应用到基 *与* 缓存视图——恰在 'relevantDelta' 答 False 时可靠
-- （delta 与闭包交换；v27 规格定理）。'reclose' 外唯一正当的 'readView' 写入。
applyDirect :: (Db -> Db) -> PraxState -> PraxState
applyDirect f st = st { db = f (db st), readView = f (readView st) }

-- | 变更已构建状态公理的唯一正当方式。先 retable（它维护 'cookedRules'），再 reclose：
-- reclose 的 'runCooked' 读 retable 刚设的 'cookedRules'，故缓存视图恰在该公理集下闭合。
-- 对公理集本身次序不敏感——'cookAxioms' 只读 'axioms'，因此无需生产者 setup 事实先于此调用。
setAxioms :: [Axiom] -> PraxState -> PraxState
setAxioms axs st = reclose (retable st { axioms = axs })

-- | 变更已构建状态欲望词汇的唯一正当方式。
setDesires :: [Desire] -> PraxState -> PraxState
setDesires ds st = retable st { desires = ds }

-- | 变更已构建状态角色阵容的唯一正当方式。
setCharacters :: [Character] -> PraxState -> PraxState
setCharacters cs st = retable st { characters = cs }

-- | 世界引擎调度的 *创作* 门（规格 v44）：安装创作的周期规则。这是调度规则创作卫生的唯一咽喉——
-- 每条规则的每个子句做 v40 拼接检查（'authoredVarClash' @["Actor"]@）：@Prax@ 命名空间留给引擎机械，
-- @Actor@ 留给行动者（调度规则根本无行动者）。其余（单段名、正周期、无重名、到期播种）是共享的
-- 'addScheduleRules' 核心，'registerEngineRules' 也共用。
setSchedule :: [ScheduleRule] -> PraxState -> PraxState
setSchedule rules st
  | (v : _) <- offenders =
      error ("Prax.Engine.setSchedule: a rule authors " ++ show v
             ++ " -- the Prax namespace is reserved for engine machinery, and Actor"
             ++ " is reserved for movers (a schedule rule has no actor at all)")
  | otherwise = addScheduleRules rules st
  where
    offenders = concat [ authoredVarClash ["Actor"] conds outs
                       | r <- rules, (conds, outs) <- srBody r ]

-- | 播种戏剧骰（规格 v50）：把 RNG 流起始位置装入引擎状态（'rngSeed'）。种子在流域外时响亮报错
-- （'Prax.Rng.seedBounds'——@0@ 与模的倍数是不动点，骰子总掷同一面）。世界在构建时调用一次
-- （种子是选择本通关命运的创作世界参数）；未播种世界的 'Roll' 是响亮错误，由
-- 'Prax.TypeCheck.SeedlessDraw' 静态捕获。
seedDie :: Integer -> PraxState -> PraxState
seedDie s st
  | s < lo || s > hi =
      error ("Prax.Engine.seedDie: seed " ++ show s ++ " lies outside the die's"
             ++ " domain [" ++ show lo ++ ", " ++ show hi ++ "] -- 0 and multiples"
             ++ " of the modulus are fixed points (a die that always rolls the"
             ++ " same face)")
  | otherwise = st { rngSeed = Just s }
  where (lo, hi) = seedBounds

-- | 引擎调度的 *编译器级* 门（规格 v46）：注册创作代码不能写的规则。编译后的 "Prax.Script" 故事规则
-- 由编译器生成、非创作——其子句携带编译器自有机械（'Prax.Script.compile' 已对其拼接的逐字作者片段做过卫生检查）——
-- 因此在此注册而非经 'setSchedule'。本门 *只* 省略 v40 拼接守卫：调用方是编译器级代码（'Prax.Script.compile'），
-- 正落在 v45 威胁模型内（仅机械可做的保留命名空间写入族），故 *设计上* 不带创作守卫。有意不从任何创作表面模块再导出。
-- 其余调度规则不变量仍成立（单段名、正周期、两门间无重名、到期播在一周期外）——共享 'addScheduleRules' 核心。
--
-- 除安装规则外，本门把所装名字 *记录* 到 'engineRuleNames'——保留族扫描（'Prax.TypeCheck'）查阅的出处，
-- 以便机械可写保留编译器族（规格 v53）。记录更新把 'addScheduleRules' 强制到 WHNF，因此其重名守卫仍在
-- *记录任何名字之前* 响亮触发（重复从不静默豁免）。
registerEngineRules :: [ScheduleRule] -> PraxState -> PraxState
registerEngineRules rules st =
  (addScheduleRules rules st)
    { engineRuleNames = engineRuleNames st ++ map srName rules }

-- | 把调度规则安装到世界，*追加* 到已注册者（两门写入同一全局键规则表）：存声明、煮镜像（'retable'），
-- 并把每条规则的下次到期播在完整一周期外（开局已饱约定——@currentTurn + srPeriod@，跨规则统一）。
-- 构建时响亮错误：单段规则名（多段名会破坏按名到期键控）、正周期、无重名——本批内 *与* 对照另一门已注册规则
-- 均检查（dues map 按名键控；碰撞会共享一个到期键），点名两门以便作者知道往哪看。
addScheduleRules :: [ScheduleRule] -> PraxState -> PraxState
addScheduleRules rules st
  | (r : _) <- filter ((/= 1) . length . pathNames . srName) rules =
      error ("Prax.Engine: schedule rule name must be a single segment: "
             ++ show (srName r))
  | (r : _) <- filter ((< 1) . srPeriod) rules =
      error ("Prax.Engine: schedule rule " ++ show (srName r)
             ++ " needs a positive period")
  | (n : _) <- clashes =
      error ("Prax.Engine: duplicate schedule-rule name " ++ show n
             ++ " would share one due key -- rule names are globally keyed across"
             ++ " both registration doors (Prax.Engine.setSchedule for authored"
             ++ " rules, Prax.Engine.registerEngineRules for compiler-level rules);"
             ++ " rename one")
  | otherwise =
      retable st { schedule = schedule st ++ rules
                 , scheduleDues = Map.union (scheduleDues st)
                     (Map.fromList
                        [ (srName r, currentTurn st + srPeriod r) | r <- rules ]) }
  where
    newNames = map srName rules
    existing = map srName (schedule st)
    clashes  = (newNames \\ nub newNames) ++ filter (`elem` existing) newNames

-- | 具名行动者当前可执行的全部动作，遍及每个已实例化实践及每个动作的每个满足绑定。条件
-- （与实践实例）对照 'readView' 求值，故派生事实对前置条件可见。实例统一与内部条件查询均跑在
-- 'cookedDefs' 缓存的预煮形式上——热循环从不重解析创作模式。
possibleActions :: PraxState -> String -> [GroundedAction]
possibleActions st actor =
  [ GroundedAction
      { gaPracticeId = pid
      , gaInstanceId = intercalate "." (map symName (groundNames inst (cpInstanceNames cp)))
      , gaActionId   = caName ca
      , gaBindings   = binding
      , gaLabel      = renderText (caName ca) binding
      }
  | pid <- childKeys "practice" view
  , Just cp <- [Map.lookup pid (cookedDefs st)]
  , inst <- unifySyms (cpInstanceNames cp) view (Map.singleton (intern "Actor") (VSym (intern actor)))
  , ca <- cpActions cp
  , binding <- queryCooked view (caConds ca) inst
  ]
  where view = readView st

-- | 经煮熟引擎按序应用落地动作的每个结果。
performAction :: PraxState -> GroundedAction -> PraxState
performAction st ga =
  case Map.lookup (gaPracticeId ga) (cookedDefs st) of
    Nothing -> st
    Just cp ->
      case filter ((== gaActionId ga) . caName) (cpActions cp) of
        (ca : _) -> foldl' (\s o -> performCooked (groundCookedOutcome (gaBindings ga) o) s)
                           st (caOuts ca)
        [] -> st

-- | 把已绑定变量代入结果的句子\/参数。
groundOutcome :: Outcome -> Bindings -> Outcome
groundOutcome (Insert s)          b = Insert (ground s b)
groundOutcome (Delete s)          b = Delete (ground s b)
groundOutcome (InsertFor n s)     b = InsertFor n (ground s b)
groundOutcome (Call fn args)      b = Call fn (map (`ground` b) args)
groundOutcome (ForEach conds outs) b =
  ForEach (map (groundCondition b) conds) (map (`groundOutcome` b) outs)
groundOutcome (Roll num den conds outs) b =
  Roll num den (map (groundCondition b) conds) (map (`groundOutcome` b) outs)

-- | 把单个已落地结果应用到状态——公开、面向字符串的入口，先煮再跑：一引擎，两门。
performOutcome :: Outcome -> PraxState -> PraxState
performOutcome o = performCooked (cookOutcome o)

-- | 把单个已落地煮熟结果应用到状态。与字符串 'performOutcome' 逐 case 对应：同一分类次序
-- （无关 → 单调插入延续 → reclose）、同一 'applyDirect'\/'applyGrowToks'\/'withDb' 路由、
-- 同一 spawn-runs-inits 语义、同一 'ForEach' 先快照再应用行为——仅解析移动：分类、孵化检测与
-- 插入\/撤回均跑在手中已有的名字上。
performCooked :: CookedOutcome -> PraxState -> PraxState
performCooked (CDelete toks) st0
  | relevantNames names shadows st = withDb (retractNames names) st
  | otherwise                      = applyDirect (retractNames names) st
  where
    -- A subtree delete takes its descendants' pending timers (spec v44):
    -- eagerly purge every expiry entry AT OR UNDER the deleted path (by
    -- name-prefix), so no later retract can fire on a fact already gone.
    st = st0 { expiries = Map.filterWithKey (\k _ -> not (names `isPrefixOf` map fst k))
                                            (expiries st0) }
    names = map fst toks
    shadows = evictionShadowNames toks
performCooked (CInsert toks) st0 =
  let -- A bare insert of a path CANCELS any pending expiry on it (spec v44's
      -- supersession law: a permanent assertion never dies on a stale timer).
      st = st0 { expiries = Map.delete toks (expiries st0) }
      names = map fst toks
      shadows = evictionShadowNames toks
      st' | not (relevantNames names shadows st) = applyDirect (insertToks toks) st
          | monotoneToks toks st                  = applyGrowToks toks st
          | otherwise                              = withDb (insertToks toks) st
  in case spawnedInstanceNames names st of
       Just (def, cp, roleVals) ->
         let roleBindings = Map.fromList (zip (map intern (roles def)) (map VSym roleVals))
         in foldl' (\s2 o -> performCooked (groundCookedOutcome roleBindings o) s2)
                   st' (cpInits cp)
       Nothing -> st'
performCooked (CInsertFor n toks) st =
  -- Insert now (through the ordinary CInsert path, so relevance/closure tiers
  -- and spawning all apply, and any stale timer on the path is cancelled),
  -- then arm a fresh expiry n round boundaries out. Re-inserting the exact
  -- path with a lifetime therefore REFRESHES the due (spec v44).
  let st' = performCooked (CInsert toks) st
  in st' { expiries = Map.insert toks (currentTurn st' + n) (expiries st') }
performCooked (CCall fn args) st =
  case lookupCookedFn fn st of
    Nothing -> st
    Just (params, cases) ->
      let paramBindings = Map.fromList (zip (map intern params) (map VSym args))
          firstMatch =
            [ (outs, res)
            | (conds, outs) <- cases
            , res <- take 1 (queryCooked (db st) conds paramBindings) ]
      in case firstMatch of
           ((outs, res) : _) ->
             foldl' (\s o -> performCooked (groundCookedOutcome res o) s) st outs
           [] -> st
performCooked (CForEach conds outs) st =
  let bs = queryCooked (readView st) conds Map.empty   -- snapshot: all bindings up front
  in foldl' (\s b -> foldl' (\s2 o -> performCooked (groundCookedOutcome b o) s2) s outs) st bs
performCooked (CRoll num den conds outs) st =
  case rngSeed st of
    Nothing -> error "Prax.Engine: Roll executed on an unseeded die \
                     \(a draw in a world that never called seedDie)"
    Just s  ->
      -- Advance the stream UNCONDITIONALLY (the frozen-die law: every draw
      -- spends one step, hit or miss), then roll on the advanced value — on a
      -- hit apply the body exactly as a CForEach (same snapshot semantics).
      let s'  = rollStep s
          st1 = st { rngSeed = Just s' }
      in if s' `mod` fromIntegral den < fromIntegral num
           then performCooked (CForEach conds outs) st1
           else st1

-- | 引擎时钟当前值——db 中唯一的 @turn@ 孩子（规格 v44）。缺失或非单独数值时响亮报错：时钟在
-- 'emptyState' 播种且仅由 'roundBoundary' 推进，故缺失是构建 bug，禁止沉默。
currentTurn :: PraxState -> Int
currentTurn st = case childKeys turnPath (db st) of
  [n] | Just i <- readMaybe n -> i
  ks -> error ("Prax.Engine.currentTurn: expected exactly one numeric " ++ show turnPath
               ++ " value in the db, found " ++ show ks)

-- | 一个回合边界（规格 v44）：推进时钟，触发到期失效（存在守卫：自播种以来精确事实已被驱逐的条目
-- 静默丢弃——无撤回、无重算），再按声明序触发到期调度规则，并从 *现在* 重装各周期边界。状态的纯函数；
-- 循环在轮转回绕时运行它（任务 2）。
--
-- 失效在规则 *之前* 触发有明确理由：寿命为 n 的事实在回合 onset..onset+n-1 存在，边界时 *消失*——
-- 若先规则，周期-1 规则可在事实恰到期的瞬间盖印信念（幽灵观察）。
roundBoundary :: PraxState -> PraxState
roundBoundary st0 = foldl' fireRule stExpired dueRules
  where
    now  = currentTurn st0 + 1
    -- Advance the clock on the ordinary insert path so relevance/closure tiers
    -- apply (turn!now excludes turn!prev — the @!@ is in the seeded fact).
    st   = performCooked (CInsert (internTokens (turnPath ++ "!" ++ show now))) st0
    (due, keep) = Map.partition (<= now) (expiries st)
    stExpired = foldl' expireOne (st { expiries = keep }) (Map.keys due)
    expireOne s toks
      | exists (tokensToSentence toks) (db s) = performCooked (CDelete toks) s
      | otherwise                             = s          -- evicted since: silent drop
    dueRules = [ r | r <- cookedSchedule st0
                   , Map.findWithDefault maxBound (csrName r) (scheduleDues st0) <= now ]
    fireRule s r =
      (foldl' (\s' (conds, outs) -> performCooked (CForEach conds outs) s') s (csrBody r))
        { scheduleDues = Map.insert (csrName r) (now + periodOf r) (scheduleDues s) }
    -- The rule's authored period, from the string-side schedule by name; a
    -- cooked rule with no string-side declaration is a construction bug.
    periodOf r = case [ srPeriod sr | sr <- schedule st0, srName sr == csrName r ] of
      (p : _) -> p
      []      -> error ("Prax.Engine.roundBoundary: no schedule rule named "
                        ++ show (csrName r) ++ " to resolve its period")

-- If inserting the sentence named by @names@ brings a not-yet-existing
-- practice instance into being, return its (string-side) definition, its
-- cooked form (for 'cpInits'), and the role values (still 'Sym's — the
-- caller builds 'Bindings' directly from them, no render/re-intern round
-- trip) — so its @init@ can run once.
spawnedInstanceNames :: [Sym] -> PraxState -> Maybe (Practice, CookedPractice, [Sym])
spawnedInstanceNames names st =
  case names of
    (p : pidSym : rest) | p == intern "practice" ->
      let pid = symName pidSym in do
        def <- Map.lookup pid (practiceDefs st)
        cp  <- Map.lookup pid (cookedDefs st)
        let roleVals = take (length (roles def)) rest
            instanceNames = p : pidSym : roleVals
        if length roleVals == length (roles def) && not (existedBefore instanceNames)
          then Just (def, cp, roleVals)
          else Nothing
    _ -> Nothing
  where
    -- The instance is newly spawned iff it did not exist before this insert.
    existedBefore ns = not (null (unifySyms ns (db st) Map.empty))

-- | 名为 @fn@ 的函数的参数与煮熟分支——在唯一注册表（'cookedFns'）中的普通查找。自 v47 起函数只有
-- 一个归宿（实践折叠先胜解析已去），故恰为 @Map.lookup fn (cookedFns st)@。
lookupCookedFn :: String -> PraxState -> Maybe ([String], [([CookedCondition], [CookedOutcome])])
lookupCookedFn fn st = Map.lookup fn (cookedFns st)

-- | 一个落地动作的结果可触及的插入\/删除锚点族——'performAction' 的效果，每次调用通过遍历
-- 'performAction' 自身执行的同一煮熟结果做静态限界。无法限界时为 @Nothing@：不可解析的 'CCall'；
-- 首段 *就是* 字面 @practice@ 的插入；或首段是非安全 ForEach 绑定器（'safeBinders'）的变量的插入——
-- 此类头可落地到 @practice@ 并孵化实例（'spawnedInstanceNames'），跑该实践的 'cpInits'、本步行不建模的
-- 任意后续结果。完全无字面段的路径同样不透明——它们不携带 'Prax.Relevance.mayUnifySyms' 的锚点证据。
-- 调用方（planner 的预测复用）把 @Nothing@ 当不透明：该节点及以下不复用。构造上保守：无论守卫是否会触发
-- 都包含 'CForEach' 体，安全绑定器头保留为 'mayUnifySyms' 通配锚；'CCall' 包含已解析函数的每个分支，
-- 像 'Prax.Relevance' 字符串侧原子行走一样有环守卫。
groundedDeltaAnchors :: PraxState -> GroundedAction -> Maybe [[Sym]]
groundedDeltaAnchors st ga = do
  cp <- Map.lookup (gaPracticeId ga) (cookedDefs st)
  ca <- listToMaybe [ a | a <- cpActions cp, caName a == gaActionId ga ]
  outcomeDeltaAnchors st [] (map (groundCookedOutcome (gaBindings ga)) (caOuts ca))

outcomeDeltaAnchors :: PraxState -> [String] -> [CookedOutcome] -> Maybe [[Sym]]
outcomeDeltaAnchors st visited = go' Set.empty
  where
    go' safe = fmap concat . traverse (go safe)
    go safe o = case o of
      CInsert toks ->
        let names = map fst toks
        in if mightSpawn safe names || unanchored names
             then Nothing
             else Just (names : evictionShadowNames toks)
      CInsertFor _ toks -> go safe (CInsert toks)   -- the deferred retract is
                                                    -- environment: same anchors as CInsert
      CDelete toks ->
        let names = map fst toks
        in if unanchored names
             then Nothing
             else Just (names : evictionShadowNames toks)
      CForEach conds os -> go' (safe `Set.union` safeBinders conds) os
      CRoll _ _ conds os -> go' (safe `Set.union` safeBinders conds) os
        -- the body may fire (the roll may hit): its anchors count, exactly as
        -- a CForEach's, and the roll's guard binds like a CForEach's
      CCall fn args
        | fn `elem` visited -> Just []
        | otherwise -> case lookupCookedFn fn st of
            Nothing -> Nothing
            Just (params, cases) ->
              let b = Map.fromList (zip (map intern params) (map VSym args))
              in fmap concat (traverse
                   (\(_, os) -> outcomeDeltaAnchors st (fn : visited)
                                  (map (groundCookedOutcome b) os))
                   cases)
    mightSpawn safe (n : _)
      | symIsVar n = not (n `Set.member` safe)
      | otherwise  = n == intern "practice"
    mightSpawn _ [] = False
    -- A path with no literal segment carries no anchor evidence at all —
    -- 'mayUnifySyms' would clear it against every read pattern (the
    -- anchored-literal rule discards evidence-free overlaps), so bounding it
    -- would license unsound reuse. Opaque instead. Well-formed facts always
    -- carry a literal predicate segment (the authored-world invariant), so
    -- this arm is unreachable in shipped worlds.
    unanchored = all symIsVar

-- | 可证明不能取值 @practice@ 的 ForEach 绑定器：在顶层正 'CMatch' 守卫的 *非首位* 绑定、
-- 且从不出现在任何此类守卫首位的变量。花费创作世界结构不变量（"Prax.Relevance" 头对谓词字面所声明的族，
-- 延伸到注册表根）：字面 @practice@ 根实践注册表路径，从不是实体、地点、值或 id 名——因此从事实
-- *内部* 读出的值永不可能是 @practice@，以此类绑定器为头的插入永不能到达 'spawnedInstanceNames'。
-- 有意收窄：'CExists'\/'CAbsent'\/'CNot' 不向外绑定，'COr' 分支可能使绑定器未绑定，子查询变量携带集合，
-- 且 *首位* 变量确实可对注册表统一 @practice@——那些都不产生安全绑定器，且 'CCall' 重置安全集
-- （调用作用域参数不是行动者的绑定）。不确定性保持不透明。
safeBinders :: [CookedCondition] -> Set Sym
safeBinders conds = Set.difference boundDeep firstPos
  where
    pats = [ p | CMatch p <- conds ]
    boundDeep = Set.fromList [ v | p <- pats, v <- drop 1 p, symIsVar v ]
    firstPos  = Set.fromList [ v | (v : _) <- pats, symIsVar v ]
