-- | 模拟的核心数据类型：实践、动作、结果、角色，以及打包的解释器状态。
--
-- 实践/动作作为普通 Haskell 值创作（eDSL）。智能默认值（'practice'、'action'）
-- 使定义简洁——用记录语法覆盖字段，例如
--
-- > greet = practice
-- >   { practiceId = "greet", roles = ["Greeter", "Greeted"]
-- >   , actions = [ action "[Actor]: Greet [Other]"
-- >                   [Eq "Actor" "Greeter", Eq "Other" "Greeted"]
-- >                   [Delete "practice.greet.Actor.Other"] ] }
module Prax.Types
  ( Practice(..)
  , practice
  , Action(..)
  , action
  , Outcome(..)
  , outcomeVars
  , outcomeSents
  , authoredVarClash
  , authoredPatClash
  , isPraxVar
  , Function(..)
  , FnCase(..)
  , ScheduleRule(..)
  , CookedScheduleRule(..)
  , turnPath
  , CookedOutcome(..)
  , CookedAction(..)
  , CookedPractice(..)
  , Liveness(..)
  , Character(..)
  , character
  , Want(..)
  , Desire(..)
  , GroundedAction(..)
  , MotiveSignature(..)
  , Intention(..)
  , PraxState(..)
  , emptyState
  , deadSentence
  , livingCharacters
  ) where

import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import           Prax.Db (Bindings, Db, emptyDb, exists, insert, isVariable, pathNames)
import           Prax.Query (Condition, CookedCondition, conditionVars, condSents)
import           Prax.Derive (Axiom, CookedRule)
import           Prax.Sym (Sym, intern)

-- | 社会实践：按角色参数化的 affordance 包。
data Practice = Practice
  { practiceId   :: String        -- ^ 唯一 id；@practice.@ 下的 DB 键
  , practiceName :: String        -- ^ 显示模板（可含 @[Role]@）
  , roles        :: [String]      -- ^ 角色变量；实例键
  , actions      :: [Action]      -- ^ 向参与者提供的 affordance
  , dataFacts    :: [String]      -- ^ 静态事实，插入于 @practiceData.<id>.@ 下
  , initOutcomes :: [Outcome]     -- ^ 实例首次孵化时跑一次
  }
  deriving (Eq, Show)

-- | 全空实践；用记录语法覆盖字段。
practice :: Practice
practice = Practice
  { practiceId = "", practiceName = "", roles = []
  , actions = [], dataFacts = [], initOutcomes = [] }

-- | affordance：命名、带条件的结果包。
data Action = Action
  { actionName       :: String       -- ^ 显示模板；亦为动作 id
  , actionConditions :: [Condition]  -- ^ 前置条件（合取查询）
  , actionOutcomes   :: [Outcome]    -- ^ 执行时应用的效果
  }
  deriving (Eq, Show)

-- | 便利构造器：@action name conditions outcomes@。
action :: String -> [Condition] -> [Outcome] -> Action
action = Action

-- | 对世界的效果。单值槽的后置从不需要显式 remove——'Insert' 中的 @!@ 排他处理它。
data Outcome
  = Insert String            -- ^ 断言句子（可能孵化实践）
  | Delete String            -- ^ 撤回子树
  | InsertFor Int String
    -- ^ 断言会到期的句子：引擎在此插入后 @n@ 个回合边界撤回它（整棵子树，因此寿命应落在叶事实上）
    -- （规格 @docs/specs/2026-07-16-v44-the-schedule.md@）。用寿命再插入精确路径会刷新到期；
    -- 裸再插入则取消它（v44 的 supersession 法则）。整条煮熟管线与 'Insert' 完全一样骑乘——延期撤回是
    -- 环境，非行动者效果。
  | Call String [String]     -- ^ 按名用参数调用实践 'Function'
  | ForEach [Condition] [Outcome]
    -- ^ 量化效果：对条件的 /每个/ 绑定（对照闭合视图求值，入口时快照）应用子结果。
  | Roll Int Int [Condition] [Outcome]
    -- ^ 戏剧骰（规格 @docs/specs/2026-07-18-v50-machinery-state.md@）：
    -- @Roll num den conds outs@ __无条件__ 推进引擎 RNG 流（'Prax.Engine.rngSeed'）
    -- （冻结骰法则：每次抽取无论中否都消耗一步），然后在推进后的值上掷——若中
    -- （@advanced `mod` den < num@）则恰如 'ForEach' 应用 @conds@/@outs@（同一快照语义）。
    -- 'Prax.Rng.draw' 是构建它的创作表面；'Prax.Engine.performCooked' 对照引擎种子执行煮熟镜像
    -- （'CRoll'）。未播种状态上的 'Roll' 是大声错误（类型检查过的世界会播种骰）。
  deriving (Eq, Show)

-- | Every name an outcome /mentions/ — a total walk over every constructor,
-- 'ForEach' recursing through both its guard conditions ('conditionVars')
-- and its nested outcomes. Declared here (not alongside 'conditionVars' in
-- "Prax.Query") because 'Outcome' lives here and "Prax.Types" already
-- depends on "Prax.Query" — the reverse dependency would cycle. The shared
-- home for reserved-variable guards ('Prax.Engine.setSchedule',
-- 'Prax.Rng.draw') and similar checks that need every name an outcome could
-- touch.
outcomeVars :: Outcome -> [String]
outcomeVars o = case o of
  Insert s       -> pathNames s
  Delete s       -> pathNames s
  InsertFor _ s  -> pathNames s
  Call _ as      -> as
  ForEach cs os  -> concatMap conditionVars cs ++ concatMap outcomeVars os
  Roll _ _ cs os -> concatMap conditionVars cs ++ concatMap outcomeVars os

-- | Every /sentence string/ an outcome list mentions — the raw authored paths
-- it inserts, deletes, or reads (a 'ForEach'\/'Roll' guard's own conditions
-- via 'condSents', its body recursively). The write-side companion to
-- "Prax.Query"'s 'condSents'; the shared home for path-family checks that need
-- the head segment of every path an outcome touches.
outcomeSents :: [Outcome] -> [String]
outcomeSents = concatMap go
  where
    go (Insert s)            = [s]
    go (Delete s)            = [s]
    go (InsertFor _ s)       = [s]
    go (Call _ _)            = []
    go (ForEach conds outs)  = condSents conds ++ outcomeSents outs
    go (Roll _ _ conds outs) = condSents conds ++ outcomeSents outs

-- | Names an author-supplied fragment MUST NOT use when a combinator splices
-- it into generated conditions (the v40 hygiene boundary). Two sources of
-- capture, one check: the @Prax@ namespace (ALL machinery variables live
-- there — see the spec; authors can never collide with them by accident) and
-- @forbiddenSplices@, names the combinator ITSELF also binds in the SAME
-- generated query (e.g. 'Prax.Confession.confess' grounds @Actor@\/@H@ — an
-- authored mark pattern reusing either would capture, so both are listed
-- here). @forbiddenSplices@ is a BLOCKLIST, not an allowlist: a name that is
-- neither Prax-prefixed nor in it is unrestricted — do not pass a
-- combinator's legitimate CONTRACT variables (e.g. 'Prax.Schedule.sightRule'\'s
-- @Seer@\/@Seen@\/@Spot@) expecting them to be exempted; the empty list @[]@
-- is how "nothing extra is forbidden" is spelled. Returns the offenders;
-- each combinator raises its own contextual error.
--
-- This walker and its siblings here are the AUTHORING-BOUNDARY side of the
-- v41 one-surface rule: they run at combinator boundaries, before cooking
-- exists, so they read the authored strings — authoring boundary = string;
-- world model = cooked ("Prax.Relevance").
authoredVarClash :: [String]      -- ^ forbiddenSplices: the combinator's OTHER bound names in this splice
                 -> [Condition] -> [Outcome] -> [String]
authoredVarClash forbiddenSplices conds outs =
  [ v | v <- vars, isPraxVar v || v `elem` forbiddenSplices ]
  where
    vars = filter isVariable (concatMap conditionVars conds
                              ++ concatMap outcomeVars outs)

-- | 'authoredVarClash' for string-pattern arguments that are not
-- 'Condition's (e.g. 'Prax.Confession.confess'\'s mark\/deposit patterns,
-- 'Prax.Faction.factionStanding'\'s, 'Prax.Blackmail.shakedown'\'s, and
-- 'Prax.Repute.standing'\'s evidence\/deed patterns): same two-source,
-- @forbiddenSplices@-is-a-blocklist check, over already-split
-- 'Prax.Db.pathNames' instead of 'conditionVars'\/'outcomeVars' — callers
-- extract the names themselves (and drop any they mean to exempt, e.g.
-- 'Prax.Blackmail.shakedown'\'s own victim variable) before calling.
authoredPatClash :: [String] -> [String] -> [String]
authoredPatClash forbiddenSplices names =
  [ v | v <- filter isVariable names, isPraxVar v || v `elem` forbiddenSplices ]

isPraxVar :: String -> Bool
isPraxVar ('P':'r':'a':'x':_:_) = True
isPraxVar _                     = False

-- | 命名函数：守卫条件效果（例如胜负检查）。第一个条件成立的 case 运行；其余跳过。
data Function = Function
  { fnName   :: String
  , fnParams :: [String]
  , fnCases  :: [FnCase]
  }
  deriving (Eq, Show)

data FnCase = FnCase
  { caseConditions :: [Condition]
  , caseOutcomes   :: [Outcome]
  }
  deriving (Eq, Show)

-- | 引擎回合计数器路径族——树中 @turn@ 的唯一拼写（规格 @docs/specs/2026-07-16-v44-the-schedule.md@）。
-- 引擎维护 @turn!N@；调度规则体可读它为事实（@Match "turn!Now"@）。在 'emptyState' 自身播种
-- @turn!0@，因此每条路径（世界、Script 编译、fixture）在任何读取前都有时钟。
turnPath :: String
turnPath = "turn"

-- | 一条循环引擎调度规则（规格 v44）：每 'srPeriod' 个回合边界，对照世界落地各子句条件并按绑定
-- 应用其结果。体可读时钟（'turnPath'）为事实。
data ScheduleRule = ScheduleRule
  { srName   :: String   -- ^ 单段；持久化再关联键
  , srPeriod :: Int      -- ^ 触发间隔的回合边界数（创作含义）
  , srBody   :: [([Condition], [Outcome])]
  }
  deriving (Eq, Show)

-- | 'Outcome' 的煮熟镜像（见 @docs/specs/2026-07-12-v28-cooked-world.md@、
-- @docs/specs/2026-07-12-v29-interning.md@ 与构建它们的 'Prax.Cooked.cookOutcome'）：
-- 'Insert'/'Delete' 携带已切分为 @(符号, 名后标点)@ token 的句子（'Prax.Db.internTokens'）；
-- 'CCall' 的 @fn@ 保持 String（@cookedFns@ 登记查找键，从不统一）而其 @args@ 已 intern；
-- 'CForEach' 递归。声明在此而非 "Prax.Cooked"，因为下方 'PraxState' 嵌入 'CookedPractice'
-- （由这些构建），且 "Prax.Cooked" 为本模块的 'Outcome'\/'Practice' 依赖——这些是无依赖
-- "Prax.Cooked" 的纯镜像形状；转换函数（'Prax.Cooked.cookOutcome'、'Prax.Cooked.cookPractice'）住在那里。
data CookedOutcome
  = CInsert [(Sym, Maybe Char)]
  | CDelete [(Sym, Maybe Char)]
  | CInsertFor Int [(Sym, Maybe Char)]
    -- ^ 'InsertFor' 的煮熟镜像：断言 token 并入队 @n@ 个回合边界后的撤回（'Prax.Engine.performCooked'）。
  | CCall String [Sym]
  | CForEach [CookedCondition] [CookedOutcome]
  | CRoll Int Int [CookedCondition] [CookedOutcome]
    -- ^ 'Roll' 的煮熟镜像（规格 v50）：推进引擎种子，在推进后的值上掷，中则把体当 'CForEach' 应用
    -- （'Prax.Engine.performCooked'）。
  deriving (Eq, Show)

-- | 'Action' 的煮熟镜像：'actionConditions'\/'actionOutcomes' 预煮；'caName' 原样携带 'actionName'
-- （显示模板，非模式——查询/统一机制从不重解析，故无需煮）。
data CookedAction = CookedAction
  { caName  :: String
  , caConds :: [CookedCondition]
  , caOuts  :: [CookedOutcome]
  }
  deriving (Eq, Show)

-- | 'Practice' 的煮熟镜像：'Prax.Engine.possibleActions' 与 'Prax.Engine.performAction' 所需的一切，
-- 由 'Prax.Cooked.cookPractice' 预编译一次并缓存在 'PraxState' 的 'cookedDefs'。
data CookedPractice = CookedPractice
  { cpInstanceNames :: [Sym]
    -- ^ @practice.\<pid\>.\<Role1\>...\<RoleN\>@ 的 interned 'Prax.Db.pathNames'，
    -- 每世界预计算一次，避免每次 'possibleActions' 再切分（与再 intern）。
  , cpActions :: [CookedAction]
  , cpInits   :: [CookedOutcome]
  }
  deriving (Eq, Show)

-- | 'ScheduleRule' 的煮熟镜像（'Prax.Cooked.cookScheduleRule'）：体子句预煮，名原样携带
-- （持久化再关联键与字符串侧 'srPeriod' 查找键）。住在自身煮熟表面（'PraxState' 的 'cookedSchedule'），
-- 不在 'cookedDefs'：行动者不能取调度规则，它们不出现在候选集中。
data CookedScheduleRule = CookedScheduleRule
  { csrName :: String
  , csrBody :: [([CookedCondition], [CookedOutcome])]
  }
  deriving (Eq, Show)

-- | planner 死-现在测试的按欲望状态检查配方（规格 @docs/specs/2026-07-13-v33-live-relevance.md@），
-- 由 'Prax.Relevance.livenessOf' 每世界计算一次（声明在此，旁于 'CookedPractice'，因为 'PraxState'
-- 嵌入它——与该类型自身 haddock 同一理由）。'FloorCheck'：负 want 类在其自身 Owner-落地条件零绑定时
-- 处于地板（任何东西都不可改善）——无条件健全，计数零是最小。'GateCheck'：正 want 类在任何环境门禁
-- 合取（无创作结果插入、无公理派生的基事实族）为空时不能获得绑定。'AlwaysLive'：无便宜状态测试适用——
-- 静态裁决单独成立。
--
-- 保守性注记：门禁仅在可证明安全时移除工作；@Or@\/@Absent@\/@Exists@ 合取永不当门禁（只有顶层
-- 正 @Match@），且任何不确定（公理可派生候选、不可解析结果、带 @Subquery@\/@Count@\/@Calc@ 的 want）
-- 保持欲望为 'AlwaysLive'。
data Liveness
  = FloorCheck                    -- ^ 负：检查欲望自身条件
  | GateCheck [[CookedCondition]] -- ^ 正：每个内列表是一个门禁合取（煮熟、Owner 模板）
  | AlwaysLive
  deriving (Eq, Show)

-- | 角色/agent。Wants 驱动自主选择；绑定实践的角色只在其绑定实践内行动（例如环境点唱机）。
data Character = Character
  { charName    :: String
  , charWants   :: [Want]
  , charDesires :: [String]       -- ^ 此角色持有的词汇 'Desire' 名
  , charBoundTo :: Maybe String   -- ^ 把动作限制到此实践 id
  }
  deriving (Eq, Show)

-- | 无 wants、无 desires、无绑定的角色。
character :: String -> Character
character n = Character
  { charName = n, charWants = [], charDesires = [], charBoundTo = Nothing }

-- | 欲望：其每个满足实例化都把 'wantUtility' 加到候选未来世界效用上的查询（Versu §IX-A）。
data Want = Want
  { wantConditions :: [Condition]
  , wantUtility    :: Int
  }
  deriving (Eq, Show)

-- | 可命名欲望：条件可使用保留变量 @Owner@ 的 'Want'，按角色实例化（'Prax.Minds.wantFor'）。
-- 给欲望命名正是使它成为可能信念对象的原因。
data Desire = Desire
  { desireName :: String
  , desireWant :: Want
  }
  deriving (Eq, Show)

-- | 引擎产出的完全落地、可执行动作。
data GroundedAction = GroundedAction
  { gaPracticeId :: String
  , gaInstanceId :: String
  , gaActionId   :: String     -- ^ 源 'actionName'（查找键）
  , gaBindings   :: Bindings   -- ^ 用于落地的 Actor + 角色 + 查询绑定
  , gaLabel      :: String     -- ^ 渲染显示文本
  }
  deriving (Eq, Show)

-- | /想要重新审议/ 的输入（规格 @docs/specs/2026-07-13-v35-intentions.md@，经修订）：我能做的
-- 我在意的事（带 want 的模板——完整落地相等曾使机制惰性，已测；陈旧性改由 npcAct 的站立-仍提供
-- 检查阻止）、我过得如何（按 want 满足计数，'selfWants' 序——计数而非加权和，因此两轮廓不能互相掩盖）、
-- 什么在驱动我（自身活欲望：静态可改善且非死-现在）、以及我所知的动机（被相信动机事实，"Prax.Minds"
-- 所读的族）。在角色自身回合对照上次审议做相等比较。
data MotiveSignature = MotiveSignature
  { msBearing      :: [String]
    -- ^ 当前提供的 /带 want/ affordance 模板：既在现在落地（'Prax.Planner.candidateActions'）
    -- 又列在角色 'bearing' 表中的动作身份。触及我在意之事的机会打断我；无关的来来往往不。
    -- （站立动作有效性由 'Prax.Loop.npcAct' 单独检查——移动选择很少 bearing，但一经执行仍须过期。）
  , msSatisfaction :: [Int]
  , msLiveDesires  :: [String]
  , msKnownMotives :: [(String, String)]  -- (他人, 欲望名)
  }
  deriving (Eq, Show)

-- | 站立意图：上次审议所选动作（或选择什么都不做）及其所基于的动机签名。
data Intention = Intention
  { intentAct   :: Maybe GroundedAction
  , intentBasis :: MotiveSignature
  }
  deriving (Eq, Show)

-- | 运行中模拟所需的全部状态。
data PraxState = PraxState
  { db           :: Db
  , practiceDefs :: Map String Practice
  , cookedDefs   :: Map String CookedPractice
    -- ^ 'practiceDefs' 编译为煮熟/token 形式（'Prax.Cooked.cookPractice'），由维护
    -- 'improvables'\/'footprint' 的同一 Engine 助手（'Prax.Engine.retable'）锁步重建。
  , worldFns  :: [Function]                 -- ^ 创作登记册（构建时词汇）
  , cookedFns :: Map String ([String], [([CookedCondition], [CookedOutcome])])
    -- ^ 由 'Prax.Engine.defineFunctions' 煮一次；'Call' 解析读取的唯一归宿
    -- （'Prax.Engine.lookupCookedFn'）。按 'fnName' 键控；唯一性是 setter 的大声守护，
    -- 因此 Map 从不静默折叠重复。函数无实践局部性——解析总是全局的（规格 2026-07-17-v47）。
  , characters   :: [Character]
  , cookedWants :: Map String [[CookedCondition]]
    -- ^ 每个角色的 'charWants' 条件预煮，每 want 一项，与 'charWants' 同序——按 'charName' 键控。
    -- 由 'Prax.Engine.setCharacters'（retable）维护；与 'charWants' 效用按构造配对
    -- （同一源列表、同一顺序——从不独立重排或过滤）。
  , cookedDesires :: Map String [CookedCondition]
    -- ^ 每个词汇 'Desire' 的（Owner 模板）条件预煮一次——按 'desireName' 键控，与谁持有无关。
    -- 由 'Prax.Engine.retable' 与 'cookedDefs' 一并维护。
  , cursor       :: Int          -- ^ 上一行动者的轮转下标
  , caresAbout :: Map String [String]
    -- ^ 按角色：其创作结果可能触及自身 wants 或 desires 的 affordance 模板
    -- （'Prax.Relevance.bearingTemplates'）——'MotiveSignature' 的机会相关半边。
    -- 由 'Prax.Engine.retable' 维护。
  , intentions :: Map String Intention
    -- ^ 每个角色的站立意图（'Prax.Loop.npcAct'——重新审议语义，规格 2026-07-13-v35）。
    -- 像 'cursor' 的运行时状态：起始为空（每个角色第一回合都审议），从不派生，
    -- 从不被 'Prax.Engine.retable' 触碰。
  , axioms       :: [Axiom]
    -- ^ 世界所声明的公理列表——含闭包，非仅创作规则。'Prax.Engine.setAxioms' 原样存储传入内容；
    -- 道义世界传入其规则的 'Prax.Deontic.obligedClose'，因此 □-提升双生作为普通成员与创作规则并列。
    -- 读取看见此集的前向链闭包（'readView'）；默认无。
  , cookedRules  :: [CookedRule]
    -- ^ 'axioms' 预编译（'Prax.Derive.cookAxioms'）——体模式切分、头预分词。道义世界声明的
    -- 任何 □-提升规则（'Prax.Deontic.obligedClose'）已在 'axioms' 中，因此在此像其他规则一样煮。
    -- 由 'Prax.Engine.retable' 维护，由 'Prax.Engine.reclose'\/'Prax.Engine.applyGrowToks' 中的
    -- 'Prax.Derive.runCooked' 消费，使闭包循环每回合约 5,400 次调用从不重煮公理集。
  , sorts        :: [(String, [String])]  -- ^ sort → 成员常量，供类型检查器（默认无）
  , desires      :: [Desire]      -- ^ 可命名欲望词汇（默认无）
  , schedule       :: [ScheduleRule]
    -- ^ Authored recurring-rule declarations (spec v44); declaration order is
    -- firing order. Default none. Cooked into 'cookedSchedule' by
    -- 'Prax.Engine.retable'.
  , engineRuleNames :: [String]
    -- ^ The names of the schedule rules installed through the compiler door
    -- ('Prax.Engine.registerEngineRules') rather than the authoring door
    -- ('Prax.Engine.setSchedule') — provenance the reserved-family scan
    -- ('Prax.TypeCheck') consults to exempt them: machinery MAY write reserved
    -- families ("Prax.Script"'s @"story"@ rule writes @currentScene@), which is
    -- v45's charter (the family of reserved-namespace writes only mechanism may
    -- make). Written only by the engine door; dup-free because rule names are
    -- globally unique across both doors ('addScheduleRules''s guard).
  , cookedSchedule :: [CookedScheduleRule]
    -- ^ 'schedule' compiled ('Prax.Cooked.cookScheduleRule'), maintained by
    -- 'Prax.Engine.retable'. Its own cooked surface, NOT in 'cookedDefs'.
  , scheduleDues   :: Map String Int
    -- ^ Per recurring rule, the next round boundary it fires at (keyed by
    -- 'csrName'\/'srName'). Runtime state like 'cursor'; re-associated by name
    -- on load ('Prax.Persist').
  , expiries       :: Map [(Sym, Maybe Char)] Int
    -- ^ The one-shot expiry queue (spec v44): exact labeled path → the round
    -- boundary at which the engine retracts it. Keyed by EXACT LABELED PATH so
    -- refresh and cancel find entries by path. Runtime state.
  , predictionScope :: [Condition]  -- ^ conditions the planner predicts over (default none)
  , improvables :: [String]
    -- ^ Names of desires some authored action may improve
    -- ('Prax.Relevance.improvableDesires') — rebuilt with the vocabulary
    -- ('Prax.Engine.definePractices' / 'setAxioms' / 'setDesires'); the
    -- planner skips predictions over models with no improvable desire.
  , liveness :: Map String Liveness
    -- ^ Each named desire's dead-now recipe ('Liveness') —
    -- ('Prax.Relevance.livenessOf') — rebuilt with the vocabulary alongside
    -- 'improvables' by 'Prax.Engine.retable'; the planner consults it to
    -- skip state-dead predictions for desires the static filter has already
    -- let through.
  , footprint :: [[Sym]]
    -- ^ Pre-tokenized ('pathNames'), pre-interned patterns the axioms read
    -- or write; a ground delta unifying none of them commutes with closure
    -- (fast path).
  , axiomHeads :: [[Sym]]
    -- ^ Interned anchors of every axiom head that can fire
    -- ('Prax.Derive.axiomHeadPatterns') plus the @contradiction@ witness
    -- ('Prax.Engine.reclose' inserts it when a delta trips ⊥). Maintained by
    -- 'Prax.Engine.retable'; consumed by the planner's prediction-reuse cone:
    -- a path delta that feeds any axiom ('footprint') can change derived
    -- facts only in these families.
  , negFootprint :: [[Sym]]
    -- ^ Pre-tokenized, pre-interned negated body interiors: a '!'-free
    -- insert unifying none of these (in a 'contMonotone' world) only ADDS
    -- derived facts and takes the continuation tier.
  , contMonotone :: Bool
    -- ^ 'Prax.Derive.monotoneAxioms' of this world's axioms.
  , rngSeed :: Maybe Integer
    -- ^ The drama die's stream position (spec v50): @Nothing@ = unseeded, @Just
    -- s@ = the current Lehmer-stream value. Engine state, not a queryable world
    -- fact — set by 'Prax.Engine.seedDie', advanced by 'Prax.Engine.performCooked'
    -- on each 'CRoll'. 'Integer' matches the db's Calc arithmetic domain
    -- exactly, so the residence move off the fact base is byte-identical.
    -- Runtime state like 'cursor'; carried across saves by 'Prax.Persist'.
  , readView     :: Db
    -- ^ The db closed under the axioms — established (lazily) whenever the
    -- state is built, so reads share one closure per state. Change 'db' or
    -- 'axioms' ONLY through 'Prax.Engine.withDb' / 'Prax.Engine.setAxioms',
    -- which rebuild it; a raw record update of either leaves this stale.
  }

-- | An empty interpreter state (cursor before the first actor). The engine's
-- clock is seeded @turn!0@ here — construction, not world setup — so every
-- path (worlds, Script compile, fixtures) carries a clock before anything
-- reads it (spec v44).
emptyState :: PraxState
emptyState = PraxState
  { db = insert (turnPath ++ "!0") emptyDb
  , practiceDefs = Map.empty, cookedDefs = Map.empty
  , worldFns = [], cookedFns = Map.empty, characters = []
  , cookedWants = Map.empty, cookedDesires = Map.empty, cursor = -1
  , caresAbout = Map.empty, intentions = Map.empty
  , axioms = [], cookedRules = [], sorts = [], desires = [], predictionScope = []
  , schedule = [], engineRuleNames = [], cookedSchedule = [], scheduleDues = Map.empty, expiries = Map.empty
  , improvables = [], liveness = Map.empty, footprint = []
  , axiomHeads = [[intern "contradiction"]]
  , negFootprint = [], contMonotone = True
  , rngSeed = Nothing
  , readView = insert (turnPath ++ "!0") emptyDb }

-- | Death (and eviction) are represented by the fact @dead.\<name\>@. A dead
-- character stays in the cast list but is skipped in turn-taking and lookahead.
deadSentence :: String -> String
deadSentence name = "dead." ++ name

-- | The characters still in play (not marked dead). Used by the turn loop and
-- the planner so a removed character neither acts nor is planned around.
livingCharacters :: PraxState -> [Character]
livingCharacters st =
  [ c | c <- characters st, not (exists (deadSentence (charName c)) (db st)) ]
