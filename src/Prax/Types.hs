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

-- | 结果 /提及/ 的每个名字——对每个构造器的全行走，含 'ForEach' 守卫与体、'Roll' 条件\/结果。
outcomeVars :: Outcome -> [String]
outcomeVars o = case o of
  Insert s       -> pathNames s
  Delete s       -> pathNames s
  InsertFor _ s  -> pathNames s
  Call _ as      -> as
  ForEach cs os  -> concatMap conditionVars cs ++ concatMap outcomeVars os
  Roll _ _ cs os -> concatMap conditionVars cs ++ concatMap outcomeVars os

-- | 结果列表提及的每个 /句子字符串/——原始创作路径（'Insert'\/'Delete'\/'InsertFor' 的句子，'Call' 忽略，
-- 递归经 'ForEach'\/'Roll'），相对 'outcomeVars' 的名字行走。
outcomeSents :: [Outcome] -> [String]
outcomeSents = concatMap go
  where
    go (Insert s)            = [s]
    go (Delete s)            = [s]
    go (InsertFor _ s)       = [s]
    go (Call _ _)            = []
    go (ForEach conds outs)  = condSents conds ++ outcomeSents outs
    go (Roll _ _ conds outs) = condSents conds ++ outcomeSents outs

-- | 当组合器把作者片段拼进引擎规则时，作者供给片段 *不得* 使用的名字——响亮拒绝碰撞（v40 卫生）。
authoredVarClash :: [String]      -- ^ forbiddenSplices：本拼接中组合器的 *其他* 已绑定名
                 -> [Condition] -> [Outcome] -> [String]
authoredVarClash forbiddenSplices conds outs =
  [ v | v <- vars, isPraxVar v || v `elem` forbiddenSplices ]
  where
    vars = filter isVariable (concatMap conditionVars conds
                              ++ concatMap outcomeVars outs)

-- | 针对非 'Condition' 的字符串模式参数的 'authoredVarClash'（例如 'Prax.Confession.confess' 的
-- mark\/deposit 模式、'Prax.Faction.factionStanding'、'Prax.Blackmail.shakedown' 与
-- 'Prax.Repute.standing' 的 evidence\/deed 模式）：同一双源、@forbiddenSplices@-是黑名单检查，
-- 在已拆分的 'Prax.Db.pathNames' 上而非 'conditionVars'\/'outcomeVars'——调用方自行提取名字
-- （并丢掉任何有意豁免者，例如 'Prax.Blackmail.shakedown' 自己的受害者变量）再调用。
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
    -- ^ 创作的周期规则声明（规格 v44）；声明序即触发序。默认无。由
    -- 'Prax.Engine.retable' 煮入 'cookedSchedule'。
  , engineRuleNames :: [String]
    -- ^ 经编译器门（'Prax.Engine.registerEngineRules'）而非创作门
    -- （'Prax.Engine.setSchedule'）安装的调度规则名——'Prax.TypeCheck' 查阅的出处，
    -- 以便机械可写保留编译器族（规格 v53）。
  , cookedSchedule :: [CookedScheduleRule]
    -- ^ 已编译的 'schedule'（'Prax.Cooked.cookScheduleRule'），由
    -- 'Prax.Engine.retable' 维护。自有煮熟表面，*不* 在 'cookedDefs' 中。
  , scheduleDues   :: Map String Int
    -- ^ 每条周期规则下次触发的回合边界（键为
    -- 'csrName'\/'srName'）。像 'cursor' 一样的运行时状态；加载时按名重关联（'Prax.Persist'）。
  , expiries       :: Map [(Sym, Maybe Char)] Int
    -- ^ 一次性失效队列（规格 v44）：精确标签路径 → 引擎撤回它的回合边界。按 *精确标签路径* 键控，
    -- 以便刷新与取消按路径查找条目。
  , predictionScope :: [Condition]  -- ^ planner 预测所覆盖的条件（默认无）
  , improvables :: [String]
    -- ^ 某些创作动作可能改善的欲望名
    -- （'Prax.Relevance.improvableDesires'）——与词汇表一起由
    -- 'Prax.Engine.definePractices' / 'setAxioms' / 'setDesires' 重建。
  , liveness :: Map String Liveness
    -- ^ 每个具名欲望的此刻已死配方（'Liveness'）——
    -- （'Prax.Relevance.livenessOf'）——与 'improvables' 一起由 'Prax.Engine.retable' 重建；
    -- planner 查阅它以跳过已死 want。
  , footprint :: [[Sym]]
    -- ^ 公理读写的预分词（'pathNames'）、预 intern 模式；与它们均不统一的落地 delta 与闭包交换
    -- （快路径）。
  , axiomHeads :: [[Sym]]
    -- ^ 每个可触发公理头的 intern 锚点
    -- （'Prax.Derive.axiomHeadPatterns'）加上 @contradiction@ 见证
    -- （当 delta 触发 ⊥ 时 'Prax.Engine.reclose' 插入）。供相关性使用。
  , negFootprint :: [[Sym]]
    -- ^ 预分词、预 intern 的否定体内部：在 'contMonotone' 世界中与这些均不统一的无 '!' 插入
    -- 只 *增加* 派生事实并走延续层。
  , contMonotone :: Bool
    -- ^ 本世界公理的 'Prax.Derive.monotoneAxioms'。
  , rngSeed :: Maybe Integer
    -- ^ 戏剧骰的流位置（规格 v50）：@Nothing@ = 未播种，@Just
    -- s@ = 当前 Lehmer 流值。引擎状态，非可查询世界事实——由 'Prax.Engine.seedDie' 设置。
  , readView     :: Db
    -- ^ 在公理下闭合的 db——每当状态构建时（惰性）建立，因此读取每状态共享一次闭包。变更 'db' 或
    -- 'axioms' *仅* 经 'Prax.Engine.withDb' / 'setAxioms'。
  }

-- | 空解释器状态（光标在第一行动者之前；时钟在回合 0；无实践、公理、欲望、角色、调度）。
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

-- | 死亡（与驱逐）由事实 @dead.\<name\>@ 表示。死者留在阵容列表中，但在轮转与前瞻中被跳过。
deadSentence :: String -> String
deadSentence name = "dead." ++ name

-- | 仍在场的角色（未标死亡）。供回合循环与 planner 使用，使被移除角色既不行动也不被规划围绕。
livingCharacters :: PraxState -> [Character]
livingCharacters st =
  [ c | c <- characters st, not (exists (deadSentence (charName c)) (db st)) ]
