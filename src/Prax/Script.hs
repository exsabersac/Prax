-- | Prompter-lite 场景创作层（Versu 的 Prompter，Nelson 2014）。
--
-- Prompter 让 Versu 作者把戏剧写成 /剧本/ —— @CAST@ 加 @scene@ 图——而非手写 Praxis 实践，这正是
-- 使 Blood & Laurels（126 场景）可达的原因。本模块把该表面重建为 /编译到既有引擎/ 的 eDSL。
-- 解释器无新物添加：'Script' 降为普通 'Practice'/'Character' 值（手写 "Prax.Worlds.Intrigue"
-- 使用的同一目标），因此每个引擎特性——核心模型、信念、FOL 欲望、阵容移除——都组合进来。
--
-- 模型（出自 Nelson 2014 与 Emily Short 的写作）：
--
--   * __playtext = CAST + scenes__；恰好一个场景在任一时刻为「当前」；
--   * __scene__ 有开场文本、@setup@（进入时断言的事实）、场景本地 __beats__ 体（对话/affordance，
--     仅在该场景当前时可用）、以及一个或多个 __junctions__（条件成立时触发的路由，或转到另一场景
--     或结束故事）；
--   * __character__ 直接携带其欲望（FOL 'Want's）。
--
-- 编译模型（规格 v46——/世界自身动力学安静触发；只有角色动作作为虚构呈现/）：
--
--   * 当前场景是单槽事实 @currentScene!\<id\>@；
--   * beats 成为 @beats@ 实践的动作，各门禁于 @currentScene!\<id\>@（+ @character.Actor@ 使只有
--     阵容成员可说话）以及 beat 自身条件；
--   * junctions 与结局编译为一条普通周期-1 引擎调度规则，@"story"@ ——按创作序的子句（场景声明序，
--     场景内 junction 声明序）——经内部 'Prax.Engine.registerEngineRules' 门注册（它携带
--     'Prax.Engine.setSchedule' 正当拒绝的 Prax 命名空间机制）。引擎在每回合边界安静触发它；
--     无故事管理器、无 actor；
--   * 结局复用循环与 "Prax.Stress" 已检测的引擎级 @ending.\<key\>@ 约定。
--
-- 'flowChart' 渲染场景图（Prompter 的标志性开发视图）；"Prax.Stress" 报告随机游玩到达哪些场景。
module Prax.Script
  ( -- * The AST
    Script(..)
  , CastMember(..)
  , Scene(..)
  , Beat(..)
  , Junction(..)
    -- * Smart constructors
  , member
  , player
  , wanting
  , concernedWith
  , withTraits
  , scene
  , beat
  , quip
  , goto
  , ending
  , after
  , timeout
    -- * Compilation and tooling
  , scriptPlayer
  , currentSceneOf
  , compile
  , flowChart
    -- * Compiler-owned fact families (reserved by "Prax.TypeCheck", spec v53)
  , scenePatienceFamily
  , currentScenePath
  ) where

import           Data.Char (isAlphaNum)
import           Data.List (find, group, sort, stripPrefix)
import qualified Data.Map.Strict as Map

import           Prax.Db (pathNames, unify, valToString)
import           Prax.Query (Condition (..), CmpOp (..), condSents)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Engine (definePractices, defineFunctions, performOutcome, setCharacters, registerEngineRules)
import           Prax.Core (coreFns)

-- The AST ---------------------------------------------------------------------

-- | 整部剧本：阵容、一组场景，以及开场场景。
data Script = Script
  { scriptCast  :: [CastMember]
  , scriptScenes :: [Scene]
  , scriptStart :: String          -- ^ 开场场景的 id
  }
  deriving (Eq, Show)

-- | 阵容中的角色，欲望写成 FOL 'Want'。角色 /素描/ 加上 'concernedWith'（关注编译为 want）
-- 与 'withTraits'（个性标签存为可查询事实）。
data CastMember = CastMember
  { castName     :: String
  , castPlayable :: Bool           -- ^ 标记玩家控制的角色
  , castDesires  :: [Want]
  , castTraits   :: [String]       -- ^ 个性标签 → @trait.\<who\>.\<t\>@ 事实
  }
  deriving (Eq, Show)

-- | 一个场景：分组单元。其 beat 仅在当前时可用；其 junction 是结束或移交另一场景的路径。
data Scene = Scene
  { sceneId      :: String
  , sceneOpening :: String         -- ^ 进入场景时显示的旁白
  , sceneSetup   :: [Outcome]      -- ^ 场景成为当前时断言的事实
  , sceneBeats   :: [Beat]
  , sceneJunctions :: [Junction]
  }
  deriving (Eq, Show)

-- | 一个 beat：场景内角色可说的对白行或可采取的 affordance。@beatSpeaker (Just c)@ 限制为角色 @c@
-- （Prompter quip 由具名行动者说出）；@Nothing@ 对任意阵容成员开放。其条件与效果是普通引擎
-- 'Condition'\'Outcome'，因此 "Prax.Core"/"Prax.Beliefs" 智能构造器可直接落入。
data Beat = Beat
  { beatLabel   :: String
  , beatSpeaker :: Maybe String
  , beatConds   :: [Condition]
  , beatEffects :: [Outcome]
  }
  deriving (Eq, Show)

-- | 一个 junction：离开场景的路由，一旦 @junctionWhen@ 成立 *且*（若设了 'junctionAfter'）
-- 自进入场景起至少经过那么多引擎回合，就由引擎 @"story"@ 调度规则在回合边界触发。
-- @junctionTo (Just s)@ 转到场景 @s@；@Nothing@ 以 @junctionName@ 为结局键结束故事。
--
-- @junctionWhen@ 始终 100% 是作者内容——与 v44 修复前设计不同，从不携带拼接机械，因此 'compile'
-- 可用与 'sceneSetup' 相同的 v40 卫生守卫统一校验，无论 'Junction' 如何构建（Haskell 智能构造器、
-- 原始构造器，或从 JSON 解码——见 "Prax.Script.Json" 的 @FromJSON Junction@，本模块文档化的外部创作表面）。
-- 超时机械——'setupOf' 武装、'storyClause' 以 @Not@ 读取的耐心标记（'scenePatiencePath'）——在编译时
-- 从 'junctionAfter' 展开，因此从不出现在作者可见数据中。
data Junction = Junction
  { junctionName  :: String
  , junctionTo    :: Maybe String
  , junctionWhen  :: [Condition]
  , junctionAfter :: Maybe Int    -- ^ 仅在进入场景后 >= 这么多回合才触发
  }
  deriving (Eq, Show)

-- Smart constructors ----------------------------------------------------------

-- | 无欲望的非玩家阵容成员（用 'wanting' 覆盖）。
member :: String -> CastMember
member n = CastMember { castName = n, castPlayable = False, castDesires = [], castTraits = [] }

-- | 玩家控制的阵容成员。
player :: String -> CastMember
player n = (member n) { castPlayable = True }

-- | 给阵容成员欲望：@member "cassia" \`wanting\` [Want …]@。
wanting :: CastMember -> [Want] -> CastMember
wanting c ws = c { castDesires = castDesires c ++ ws }

-- | 素描角色的 __关注__：每个 @(dimension, weight)@ 追加一条 want——希望在该维度上被正面看待——
-- 对每个在 @dimension@ 上对其评价高于零的他人 @+weight@（自然正\/负边界；权重作者供给，无魔法常量）。
-- 与 'wanting' 组合。
concernedWith :: CastMember -> [(String, Int)] -> CastMember
concernedWith c pairs = c { castDesires = castDesires c ++ map want pairs }
  where
    want (dim, w) = Want
      [ Match ("Other.relationship." ++ castName c ++ "." ++ dim ++ ".score!N")
      , Neq "Other" (castName c)
      , Cmp Gt "N" "0" ] w

-- | 给角色个性 __特质__——存为可查询 @trait.\<who\>.\<t\>@ 事实（可用于前置条件）。有意 /不/ 编译为行为：
-- 无源指定特质→欲望映射。
withTraits :: CastMember -> [String] -> CastMember
withTraits c ts = c { castTraits = castTraits c ++ ts }

-- | 给定 id 的空场景；用记录语法填字段。
scene :: String -> Scene
scene sid = Scene
  { sceneId = sid, sceneOpening = "", sceneSetup = []
  , sceneBeats = [], sceneJunctions = [] }

-- | 对任意阵容成员开放的 beat：@beat label conditions effects@。
beat :: String -> [Condition] -> [Outcome] -> Beat
beat lbl = Beat lbl Nothing

-- | 由具名角色说出的 beat：@quip speaker label conditions effects@。
quip :: String -> String -> [Condition] -> [Outcome] -> Beat
quip spk lbl = Beat lbl (Just spk)

-- | 转移 junction：@goto name toScene when@。@when@ 在 'compile' 时校验（与每个其他 junction 统一，
-- 无论如何构建）而非此处：构造器级守卫可被任何不经 'goto' 构建 'Junction' 的创作表面绕过——尤其
-- "Prax.Script.Json" 的 @FromJSON Junction@——因此 v40 卫生检查改放在实际消费点。
goto :: String -> String -> [Condition] -> Junction
goto name to conds = Junction name (Just to) conds Nothing

-- | 结局 junction：@ending name when@（结局键 = @name@）。
ending :: String -> [Condition] -> Junction
ending name conds = Junction name Nothing conds Nothing

-- | 耐心标记族（规格 v50）：场景 @sid@ 的定时 junction @j@ 携带事实 @scenePatience.\<sid\>.\<j\>@，
-- 进入场景时以寿命 @n@ 插入（'setupOf'），@n@ 个边界后由 v44 失效调度撤回。耐心 *耗尽*（标记缺失）时
-- junction 触发。编译器机械，非虚构：仅由 'setupOf' 产生，仅由故事规则读取。作者不可触及——'compile'
-- 拒绝任何以此为头的创作条件或结果（碰撞洞）。
scenePatienceFamily :: String
scenePatienceFamily = "scenePatience"

-- | 场景 @sid@ 定时 junction @jname@ 的耐心标记。
scenePatiencePath :: String -> String -> String
scenePatiencePath sid jname = scenePatienceFamily ++ "." ++ sid ++ "." ++ jname

-- | __定时转移__：@after name n toScene@——当前场景经过 @n@ 回合后移交 @toScene@（Prompter 超时转移）。
after :: String -> Int -> String -> Junction
after name n to = Junction name (Just to) [] (Just n)

-- | __超时结局__：@timeout name n@——在场景中经过 @n@ 回合后以键 @name@ 结束故事（Prompter 的 @timeout_conclusion@）。
timeout :: String -> Int -> Junction
timeout name n = Junction name Nothing [] (Just n)

-- Compilation -----------------------------------------------------------------

-- | 玩家控制的角色（第一个标为 @playable@ 的阵容成员）。
scriptPlayer :: Script -> String
scriptPlayer scr = case [ castName c | c <- scriptCast scr, castPlayable c ] of
  (p : _) -> p
  []      -> error "Prax.Script.scriptPlayer: no playable cast member"

-- | 当前场景事实族（规格 v46）：单槽事实 @currentScene!\<id\>@ 命名活动场景。编译器对该字面的唯一归宿——
-- 本模块每个 @currentScene@ 站点（以及 @app/Main.hs@ 中两处原始读取）都经此路由。编译器发出且字面收尾，
-- 恰好一个正当写入者（@"story"@ 规则的转移插入，以及 'compile' 的开场场景 setup），因此 'Prax.TypeCheck'
-- 保留它（规格 v53）：任何创作表面不可写入。
currentScenePath :: String
currentScenePath = "currentScene"

-- | 当前活动场景的 id（若有）。
currentSceneOf :: PraxState -> Maybe String
currentSceneOf st =
  case [ v | b <- unify (currentScenePath ++ ".S") (db st) Map.empty
           , Just v <- [valToString <$> Map.lookup (intern "S") b] ] of
    (s : _) -> Just s
    []      -> Nothing

-- | 把 'Script' 编译成可运行的 'PraxState'。在消费点（统一覆盖每条构建路径——Haskell 智能构造器、
-- 原始构造器或 JSON 解码）对五种创作过错响亮报错：
--
--   * 同一场景内两 junction 同名——每个定时 junction 键控自有耐心标记（'scenePatiencePath'），故名须唯一
--     （同名 junction 无论如何都是创作歧义）；
--   * 定时 junction 带 @junctionAfter (Just n)@ 且 @n < 1@——零延迟「定时」junction 只是普通 junction（规格 v50 §2）；
--   * 创作条件或结果以 'scenePatienceFamily' 为头，出现在 'compile' 消费的五列表任一中（'sceneSetup'、
--     'junctionWhen'、beat 条件、beat 效果、阵容欲望条件）——该族归编译器（碰撞洞）；
--   * 'sceneSetup' 或 'junctionWhen' 创作 Prax 命名空间变量（v40 卫生边界；这些拼进故事规则）。
compile :: Script -> PraxState
compile scr
  | (sid, jn) : _ <- duplicateJunctionNames =
      error ("Prax.Script.compile: scene " ++ show sid ++ " has two junctions named "
             ++ show jn ++ " -- junction names must be unique within a scene "
             ++ "(each timed junction keys its own patience marker)")
  | (sid, jn, n) : _ <- zeroDelayJunctions =
      error ("Prax.Script.compile: scene " ++ show sid ++ "'s junction " ++ show jn
             ++ " has a timed delay of " ++ show n
             ++ " -- a timed junction needs at least one round (n=0 is a plain junction)")
  | (site, s) : _ <- scenePatienceOffenders =
      error ("Prax.Script.compile: " ++ site ++ " authors " ++ show s
             ++ " -- the " ++ show scenePatienceFamily
             ++ " family is reserved for the timed-junction machinery")
  | (sid, v) : _ <- sceneSetupOffenders =
      error ("Prax.Script.compile: scene " ++ show sid ++ "'s setup authors " ++ show v
             ++ " -- the Prax namespace is reserved for engine machinery")
  | (sid, jn, v) : _ <- junctionWhenOffenders =
      error ("Prax.Script.compile: scene " ++ show sid ++ "'s junction " ++ show jn
             ++ " authors " ++ show v
             ++ " -- the Prax namespace is reserved for engine machinery")
  | otherwise = foldl (flip performOutcome) (registerEngineRules [storyRule] base) setup
  where
    scenes = scriptScenes scr
    duplicateJunctionNames =
      [ (sceneId s, jn) | s <- scenes, jn <- repeated (map junctionName (sceneJunctions s)) ]
    zeroDelayJunctions =
      [ (sceneId s, junctionName j, n)
      | s <- scenes, j <- sceneJunctions s, Just n <- [junctionAfter j], n < 1 ]
    scenePatienceOffenders =
      [ (site, s) | (site, ss) <- authoredSentenceSites
      , s <- ss, headSegment s == Just scenePatienceFamily ]
    -- Every authored condition/outcome list 'compile' consumes, labelled — the
    -- scenePatience sweep is ENUMERATED here, not inherited from the v40
    -- hygiene sweep below (which covers only sceneSetup + junctionWhen); beat
    -- conditions, beat effects, and cast-desire conditions are the three lists
    -- newly swept for the patience-family guard.
    authoredSentenceSites =
         [ ("scene " ++ show (sceneId s) ++ "'s setup", outcomeSents (sceneSetup s))
         | s <- scenes ]
      ++ [ ("scene " ++ show (sceneId s) ++ "'s junction " ++ show (junctionName j) ++ " condition"
           , condSents (junctionWhen j)) | s <- scenes, j <- sceneJunctions s ]
      ++ [ ("scene " ++ show (sceneId s) ++ "'s beat " ++ show (beatLabel b) ++ " condition"
           , condSents (beatConds b)) | s <- scenes, b <- sceneBeats s ]
      ++ [ ("scene " ++ show (sceneId s) ++ "'s beat " ++ show (beatLabel b) ++ " effect"
           , outcomeSents (beatEffects b)) | s <- scenes, b <- sceneBeats s ]
      ++ [ ("cast member " ++ show (castName c) ++ "'s desire", condSents (wantConditions w))
         | c <- scriptCast scr, w <- castDesires c ]
    repeated xs = [ x | (x : _ : _) <- group (sort xs) ]
    headSegment s = case pathNames s of { (h : _) -> Just h; [] -> Nothing }
    sceneSetupOffenders =
      [ (sceneId s, v) | s <- scenes, v <- authoredVarClash [] [] (sceneSetup s) ]
    junctionWhenOffenders =
      [ (sceneId s, junctionName j, v)
      | s <- scenes, j <- sceneJunctions s, v <- authoredVarClash [] (junctionWhen j) [] ]

    base = setCharacters castChars
             (defineFunctions coreFns (definePractices [beatsP] emptyState))

    beatsP = practice
      { practiceId = "beats", practiceName = "scene dialogue", roles = ["Stage"]
      , actions = concatMap compileBeats scenes }

    -- Junctions and endings are the world's own dynamics, not a character's
    -- action, so they compile to ONE plain period-1 schedule rule the engine
    -- fires silently at each round boundary — clauses in authored order (scenes
    -- in declaration order, a scene's junctions in declaration order). Each
    -- clause's own gates self-mask: the transition's @currentScene@ eviction
    -- masks same-scene doubles, and @Absent ending@ masks everything after an
    -- ending. The fold is eager, forward-only, and order-sensitive: a clause
    -- is re-queried against the PRECEDING clause's post-state (not the
    -- boundary's start state), so a transition can cascade straight into a
    -- later-declared scene's own junction firing in the same boundary —
    -- including an ending right after a cross-scene transition — but never
    -- into an earlier-declared scene's clause, whose turn in the fold has
    -- already passed. Carries Prax-namespaced machinery ('setupOf''s scene
    -- entry — the patience markers a timed destination arms), so it registers
    -- through the engine door, not 'setSchedule'.
    storyRule = ScheduleRule "story" 1
      [ storyClause (sceneId s) j | s <- scenes, j <- sceneJunctions s ]

    -- A timed junction fires when its patience has RUN OUT: the marker that
    -- 'setupOf' armed on scene entry (lifetime n) has expired, so 'Not' the
    -- marker path holds. The v44 boundary order (expiries before rules)
    -- retracts the marker at entry+n exactly when this clause first becomes
    -- eligible.
    storyClause sid j =
      ( [ Match (currentScenePath ++ "!" ++ sid)
        , Absent [ Match "ending.E" ] ]
        ++ junctionWhen j
        ++ maybe [] (\_ -> [ Not (scenePatiencePath sid (junctionName j)) ]) (junctionAfter j)
      , case junctionTo j of
          Just next -> Insert (currentScenePath ++ "!" ++ next) : setupOf next
          Nothing   -> [ Insert ("ending!" ++ junctionName j) ] )

    compileBeats s = map (compileBeat (sceneId s)) (sceneBeats s)
    -- A quip is a *specific* speaker's action, so its compiled id bakes the
    -- speaker into the "[Actor]" slot: two speakers sharing the display text
    -- "[Actor]: flatter the king" become distinct actions ("duke: …" vs
    -- "envoy: …") and dispatch (which is by action id) can't cross them. The
    -- rendered label is unchanged, since "[Actor]" would render to the speaker
    -- anyway. Speaker-less beats keep their label verbatim.
    compileBeat sid b = action (maybe id bakeActor (beatSpeaker b) (beatLabel b))
      ( [ Match (currentScenePath ++ "!" ++ sid), Match "character.Actor" ]
        ++ maybe [] (\spk -> [Eq "Actor" spk]) (beatSpeaker b)
        ++ beatConds b )
      (beatEffects b)

    -- Substitute a concrete speaker for every "[Actor]" token in a label.
    bakeActor spk = go
      where
        go [] = []
        go s@(c:cs) = case stripPrefix "[Actor]" s of
                        Just rest -> spk ++ go rest
                        Nothing   -> c : go cs

    -- Scene entry arms one patience marker per timed junction of the scene
    -- (spec v50): @InsertFor n scenePatience.<sid>.<j>@ — a plain literal
    -- insert whose lifetime IS the delay, retracted n boundaries later by the
    -- v44 expiry schedule. Re-entry refreshes the marker (v44's supersession
    -- law resets the clock, as re-stamping did). Runs on all three entry paths
    -- (compile-time start, transition, re-entry) because every path threads
    -- through 'setupOf'.
    setupOf sid = case find ((== sid) . sceneId) scenes of
      Nothing -> []
      Just s  ->
        [ InsertFor n (scenePatiencePath sid (junctionName j))
        | j <- sceneJunctions s, Just n <- [junctionAfter j] ]
        ++ sceneSetup s

    castChars = [ (character (castName c)) { charWants = castDesires c }
                | c <- scriptCast scr ]

    setup =
      [ Insert "practice.beats.stage" ]
      ++ [ Insert ("character." ++ castName c) | c <- scriptCast scr ]
      ++ [ Insert ("trait." ++ castName c ++ "." ++ t)
         | c <- scriptCast scr, t <- castTraits c ]
      ++ [ Insert (currentScenePath ++ "!" ++ scriptStart scr) ]
      ++ setupOf (scriptStart scr)

-- Tooling ---------------------------------------------------------------------

-- | 把场景图渲染为 Mermaid @graph TD@（Prompter 自动生成的流程图）：@start@ 节点进入开场场景，
-- 每场景一节点，每 junction 一条标号边——到目标场景，或到终端结局节点。
flowChart :: Script -> String
flowChart scr = unlines $
  [ "graph TD"
  , "  _start((start)) --> " ++ nodeId (scriptStart scr) ]
  ++ concatMap sceneLines (scriptScenes scr)
  where
    sceneLines s =
      ("  " ++ nodeId (sceneId s) ++ "[\"" ++ sceneId s ++ "\"]")
        : map (edge (sceneId s)) (sceneJunctions s)
    edge from j = case junctionTo j of
      Just to -> "  " ++ nodeId from ++ " -->|" ++ junctionName j ++ "| "
                   ++ nodeId to
      Nothing -> "  " ++ nodeId from ++ " -->|" ++ junctionName j ++ "| "
                   ++ "_end_" ++ nodeId (junctionName j)
                   ++ "((" ++ junctionName j ++ "))"
    -- Mermaid node ids must be identifier-like; keep display text in the labels.
    nodeId = map (\c -> if isAlphaNum c then c else '_')
