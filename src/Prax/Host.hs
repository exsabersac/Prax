-- | 宿主嵌入表面（v66；v71 增强）：薄封装既有引擎入口，供外部循环调用——
-- @step@/@stepExact@ 推进一名行动者的选定动作；@inject@ 写入结果；
-- @queryFacts@/@queryView@ 只读扫描；@available@/@availableActions@ 列菜单。
-- 无新语义；有意保持符号、无外部模型。
-- v97：'checkpoint'/'restore' 薄封 Persist 存档。
-- v85：'queryChronicle'/'explainActor' 薄封编年史与检查器。
-- v109：'queryMatching'/'queryViewMatching' 批量过滤；'factDelta' 事件订阅钩底物（两态差分）。
-- v158：'regardsOf' 枚举闭合视图中某人发出的站队叶。
-- v197：'obligationsOf' 枚举闭合视图中某人的义务叶。
-- v203：'breachesOf' 枚举闭合视图中某人的违规叶。
-- v208：'feelingsOf'/'liesOf'/'chattedWithOf' 枚举情感/谎言/聊天叶。
-- v211：'traitsOf'/'moodsOf'/'bondsOf'/'kinOf'/'notoriousOf' 枚举性格/心境/纽带/亲属/恶名叶。
-- v217：'esteemedOf'/'scornedOf'/'beliefsOf' 枚举赞誉/蔑视/信念叶。
-- v225：'arcsOf'/'agesOf'/'projectsOf' 枚举弧阶段/年龄/事业叶。
-- v231：'demandedOf'/'festivalsOf' 催收叶与节庆叶。
-- v244：'holdingOf'/'carryingOf'/'shunnedOf' 持有/携带/排斥叶。
-- v523：'holdersOf'/'carriersOf' 持有/携带物品侧叶。
-- v515：'occupantsOf' 位置目标侧叶（at.*.<place>）。
-- v534：'affiliatorsOf' 派系次级归属人侧（affiliate.*.<faction>）。
-- v544：'practitionersOf' 实践 id 侧叶（practice.<pid>.*）。
-- v547：'believersOf' 信念内容侧叶（*.believes.<prop>…）。
-- v550：'notorietiesOf' 恶名标签侧叶（notorious.*.<label>）。
-- v553：'traitedOf' 性格标签侧叶（trait.*.<trait>）。
-- v556：'moodedOf' 心境标签侧叶（mood.*.<mood>）。
-- v566：'arcedOf'/'agedOf' 弧阶段/年龄值侧叶。
-- v569：'bondedOf'/'feltOf' 纽带标签/感受标签侧叶。
-- v572：'esteemsOf'/'scornsOf' 赞誉/蔑视标签侧叶。
-- v249：'threatenedOf'/'extortedOf' 胁迫/勒索叶。
-- v258：'compliedOf'/'defiedOf' 顺从/违抗叶。
-- v281：'brandedOf'/'revokedOf' 烙印/撕毁协议叶（Sandbox 胁迫/沉默债）。
-- v284：'confessedOf'/'recantedOf'/'ostracizedOf'/'exiledOf' 招供/悔罪/放逐/流放叶。
-- v287：'denouncedOf'/'censuredOf'/'paradedOf' 控告/审查/游街叶（Sandbox）。
-- v290：'criedOf'/'ralliedOf' 市集喊冤/声援叶。
-- v291：'fledOf'/'reconciledOf'/'marriedOf' 叛逃/和解/婚入叶。
-- v311：'stallOf' 货摊存货叶（Village stall.<item>）。
-- v293：'eyedOf'/'confrontedOf'/'atonedOf' 目击/对质/赎罪叶（Village）。
-- v295：'wrongedOf'/'hungryOf' 冤屈/饥饿叶（Feud / Village）。
-- v297：'shortTemperedOf'/'appetiteOf' 暴脾气/胃口叶（Village）。
-- v299：'resentsOf' 怨恨叶（Feud 派生）。
-- v301：'alliedOf' 同盟叶（Feud）。
-- v423：'siblingsOf' 兄弟姐妹叶（对齐 Chronicle siblings of）。
-- v429：'parentsOf'/'childrenOf' 亲子叶（parent.<p>.<c>）。
-- v445：'grandparentsOf'/'grandchildrenOf'/'inLawsOf' 祖孙/姻亲叶。
-- v456：'spousesOf' 婚偶叶（married.<who>.* 主体侧）。
-- v458：'creditorsOf'/'debtorsOf' 债权/债务方叶（debt.<c>.<d>.*）。
-- v472：'demandersOf'/'demandeesOf' 催收方叶（demanded.<c>.<d>.*）。
-- v481：'threatenersOf'/'threateneesOf'/'extortersOf'/'extorteesOf' 胁迫/勒索方叶。
-- v488：'compliersOf'/'complieesOf'/'defiersOf'/'defieesOf' 顺从/违抗方叶。
-- v495：'wrongersOf'/'wrongeesOf' 冤屈方叶（wronged.<o>.<v>）。
-- v497：'eyersOf'/'eyeesOf'/'confrontersOf'/'confronteesOf' 目击/对质方叶。
-- v512：'ostracizersOf'..'paradeesOf' 放逐/控告/审查/游街方叶。
-- v514：'criersOf'/'crieesOf'/'ralliersOf'/'rallieesOf' 喊冤/声援方叶。
-- v516：'alliesOf' 同盟主体侧叶（对齐 spousesOf）。
-- v525：'resentersOf' 怨恨目标侧叶（resents.*.<who>）。
-- v527：'shunnersOf' 排斥目标侧叶（shunned.*.<who>）。
-- v531：'esteemersOf' 被赞誉侧叶（esteemed.*.<who>.*）。
-- v533：'scornersOf' 被蔑视侧叶（scorned.*.<who>.*）。
-- v540：'bondersOf' 纽带对象侧叶（bond.*.<who>.*）。
-- v542：'liarsOf' 谎言听者侧叶（*.lied.<who>.*）。
-- v504：'chattersOf' 聊天对象侧叶（*.chattedWith.<who>）。
-- v499：'revokersOf'/'revokeesOf' 撕毁协议方叶。
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
  , affiliatorsOf
  , leadersOf
  , regardsToward
  , factionsNamed
  , debtsOf
  , creditorsOf
  , debtorsOf
  , obligationsOf
  , breachesOf
  , feelingsOf
  , feltOf
  , liesOf
  , liarsOf
  , chattedWithOf
  , chattersOf
  , traitsOf
  , traitedOf
  , moodsOf
  , moodedOf
  , bondsOf
  , bondersOf
  , bondedOf
  , kinOf
  , siblingsOf
  , parentsOf
  , childrenOf
  , grandparentsOf
  , grandchildrenOf
  , inLawsOf
  , spousesOf
  , notoriousOf
  , notorietiesOf
  , esteemedOf
  , esteemersOf
  , esteemsOf
  , scornedOf
  , scornersOf
  , scornsOf
  , beliefsOf
  , believersOf
  , arcsOf
  , arcedOf
  , agesOf
  , agedOf
  , projectsOf
  , practitionersOf
  , demandedOf
  , demandersOf
  , demandeesOf
  , festivalsOf
  , locationsOf
  , occupantsOf
  , holdingOf
  , holdersOf
  , carryingOf
  , carriersOf
  , shunnedOf
  , shunnersOf
  , threatenedOf
  , threatenersOf
  , threateneesOf
  , extortedOf
  , extortersOf
  , extorteesOf
  , compliedOf
  , compliersOf
  , complieesOf
  , defiedOf
  , defiersOf
  , defieesOf
  , brandedOf
  , revokedOf
  , revokersOf
  , revokeesOf
  , confessedOf
  , recantedOf
  , ostracizedOf
  , ostracizersOf
  , ostracizeesOf
  , exiledOf
  , denouncedOf
  , denouncersOf
  , denounceesOf
  , censuredOf
  , censurersOf
  , censureesOf
  , paradedOf
  , paradersOf
  , paradeesOf
  , criedOf
  , criersOf
  , crieesOf
  , ralliedOf
  , ralliersOf
  , rallieesOf
  , fledOf
  , reconciledOf
  , marriedOf
  , eyedOf
  , eyersOf
  , eyeesOf
  , confrontedOf
  , confrontersOf
  , confronteesOf
  , atonedOf
  , wrongedOf
  , wrongersOf
  , wrongeesOf
  , hungryOf
  , shortTemperedOf
  , appetiteOf
  , resentsOf
  , resentersOf
  , alliedOf
  , alliesOf
  , stallOf
  , checkpoint
  , restore
  ) where

import           Data.List (intercalate, isInfixOf, isPrefixOf, nub, sort, (\\))
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

-- | 闭合视图中次级归属 @faction@ 的角色名（@affiliate.<who>.<faction>@）。
affiliatorsOf :: PraxState -> String -> [String]
affiliatorsOf st faction = sort
  [ who
  | s <- queryView st
  , let pref = "affiliate."
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
-- | 闭合视图中指向 @target@ 的站队叶（@regards.<who>.<target>.<label>@）。
regardsToward :: PraxState -> String -> [String]
regardsToward st target = sort
  [ s
  | s <- queryView st
  , let pref = "regards."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, afterWho) = break (== '.') rest
  , not (null who)
  , let after = drop 1 afterWho
  , let (tgt, afterTgt) = break (== '.') after
  , tgt == target
  , not (null (drop 1 afterTgt))  -- label nonempty
  ]

-- | 闭合视图中出现的派系名（来自 @member.*.<f>@、@affiliate.*.<f>@、@leads.<f>.*@）。
factionsNamed :: PraxState -> [String]
factionsNamed st = sort (nub (fromMember ++ fromAffiliate ++ fromLeads))
  where
    vs = queryView st
    fromMember =
      [ fac
      | s <- vs
      , "member." `isPrefixOf` s
      , let rest = drop (length ("member." :: String)) s
      , let (who, fac) = splitLastDot rest
      , not (null who), not (null fac)
      , '.' `notElem` who, '.' `notElem` fac
      ]
    fromAffiliate =
      [ fac
      | s <- vs
      , "affiliate." `isPrefixOf` s
      , let rest = drop (length ("affiliate." :: String)) s
      , let (who, fac) = splitLastDot rest
      , not (null who), not (null fac)
      , '.' `notElem` who, '.' `notElem` fac
      ]
    fromLeads =
      [ fac
      | s <- vs
      , "leads." `isPrefixOf` s
      , let rest = drop (length ("leads." :: String)) s
      , let (fac, who) = break (== '.') rest
      , not (null fac)
      , let w = drop 1 who
      , not (null w), '.' `notElem` w
      ]
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中与 @who@ 相关的债务叶（债权人或债务人一侧；@debt.<creditor>.<debtor>.<content>@）。
debtsOf :: PraxState -> String -> [String]
debtsOf st who = sort
  [ s
  | s <- queryView st
  , "debt." `isPrefixOf` s
  , let rest = drop (length ("debt." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为债务人的债叶（@debt.<creditor>.<who>.*@）。
creditorsOf :: PraxState -> String -> [String]
creditorsOf st who = sort
  [ s
  | s <- queryView st
  , "debt." `isPrefixOf` s
  , let rest = drop (length ("debt." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为债权人的债叶（@debt.<who>.<debtor>.*@）。
debtorsOf :: PraxState -> String -> [String]
debtorsOf st who = sort
  [ s
  | s <- queryView st
  , "debt." `isPrefixOf` s
  , let rest = drop (length ("debt." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的义务叶（@obliged.<who>.*@，含 whenAt 作用域）。
-- 与 Deontic.obligationsOf（返回内容后缀、读基库）对照：此处返回完整叶、读闭合视图，对齐 debtsOf/regardsOf。
obligationsOf :: PraxState -> String -> [String]
obligationsOf st who =
  sort [ s | s <- queryView st, ("obliged." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的违规叶（@violated.<who>.*@）。
breachesOf :: PraxState -> String -> [String]
breachesOf st who =
  sort [ s | s <- queryView st, ("violated." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的情感叶（@<who>.feels.*@）。
feelingsOf :: PraxState -> String -> [String]
feelingsOf st who =
  sort [ s | s <- queryView st, (who ++ ".feels.") `isPrefixOf` s ]

-- | 闭合视图中感受为 @feeling@ 的叶（@<who>.feels.<feeling>@）。
feltOf :: PraxState -> String -> [String]
feltOf st feeling = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 3
  , parts !! 1 == "feels"
  , intercalate "." (drop 2 parts) == feeling
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的谎言标记叶（@<who>.lied.*@）。
liesOf :: PraxState -> String -> [String]
liesOf st who =
  sort [ s | s <- queryView st, (who ++ ".lied.") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为听者的谎言叶（@<liar>.lied.<who>.*@）。
liarsOf :: PraxState -> String -> [String]
liarsOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 3
  , parts !! 1 == "lied"
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的聊天叶（@<who>.chattedWith.*@）。
chattedWithOf :: PraxState -> String -> [String]
chattedWithOf st who =
  sort [ s | s <- queryView st, (who ++ ".chattedWith.") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为聊天对象的叶（@<actor>.chattedWith.<who>@）。
chattersOf :: PraxState -> String -> [String]
chattersOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 3
  , parts !! 1 == "chattedWith"
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的性格叶（@trait.<who>.*@）。
traitsOf :: PraxState -> String -> [String]
traitsOf st who =
  sort [ s | s <- queryView st, ("trait." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中性格标签为 @trait@ 的叶（@trait.<who>.<trait>@）。
traitedOf :: PraxState -> String -> [String]
traitedOf st trait = sort
  [ s
  | s <- queryView st
  , let pref = "trait."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, lab) = splitLastDot rest
  , lab == trait
  , not (null who)
  , '.' `notElem` who
  ]
  where
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中 @who@ 的基线心境叶（@mood.<who>.*@；排他 @!@ 展成 @.@）。
moodsOf :: PraxState -> String -> [String]
moodsOf st who =
  sort [ s | s <- queryView st, ("mood." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中心境标签为 @mood@ 的叶（@mood.<who>.<mood>@）。
moodedOf :: PraxState -> String -> [String]
moodedOf st mood = sort
  [ s
  | s <- queryView st
  , let pref = "mood."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, lab) = splitLastDot rest
  , lab == mood
  , not (null who)
  , '.' `notElem` who
  ]
  where
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中与 @who@ 相关的公开纽带叶（@bond.<who>.*@ 一侧）。
bondsOf :: PraxState -> String -> [String]
bondsOf st who =
  sort [ s | s <- queryView st, ("bond." ++ who ++ ".") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为纽带对象的叶（@bond.<actor>.<who>[.<label>]@）。
bondersOf :: PraxState -> String -> [String]
bondersOf st who = sort
  [ s
  | s <- queryView st
  , "bond." `isPrefixOf` s
  , let rest = drop (length ("bond." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中纽带标签为 @label@ 的叶（@bond.<a>.<b>.<label>@）。
bondedOf :: PraxState -> String -> [String]
bondedOf st label = sort
  [ s
  | s <- queryView st
  , "bond." `isPrefixOf` s
  , let rest = drop (length ("bond." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , intercalate "." (drop 2 parts) == label
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的亲属叶（married/parent/sibling/inLaw/grandparent 任一侧）。
kinOf :: PraxState -> String -> [String]
kinOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 3
  , head parts `elem` kinHeads
  , who `elem` drop 1 parts
  ]
  where
    kinHeads = ["married", "parent", "sibling", "inLaw", "grandparent"]
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主体的兄弟姐妹叶（@sibling.<who>.*@；对齐 Chronicle @"siblings of "@）。
siblingsOf :: PraxState -> String -> [String]
siblingsOf st who =
  sort [ s | s <- queryView st
           , let pref = "sibling." ++ who ++ "."
           , pref `isPrefixOf` s
           , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中 @who@ 的父母叶（@parent.<p>.<who>@）。
parentsOf :: PraxState -> String -> [String]
parentsOf st who = sort
  [ s
  | s <- queryView st
  , "parent." `isPrefixOf` s
  , let rest = drop (length ("parent." :: String)) s
  , let (p, after) = break (== '.') rest
  , not (null p)
  , drop 1 after == who
  ]

-- | 闭合视图中 @who@ 的子女叶（@parent.<who>.<c>@）。
childrenOf :: PraxState -> String -> [String]
childrenOf st who =
  sort [ s | s <- queryView st
           , let pref = "parent." ++ who ++ "."
           , pref `isPrefixOf` s
           , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中 @who@ 的祖父母叶（@grandparent.<g>.<who>@）。
grandparentsOf :: PraxState -> String -> [String]
grandparentsOf st who = sort
  [ s
  | s <- queryView st
  , "grandparent." `isPrefixOf` s
  , let rest = drop (length ("grandparent." :: String)) s
  , let (g, after) = break (== '.') rest
  , not (null g)
  , drop 1 after == who
  ]

-- | 闭合视图中 @who@ 的孙子女叶（@grandparent.<who>.<c>@）。
grandchildrenOf :: PraxState -> String -> [String]
grandchildrenOf st who =
  sort [ s | s <- queryView st
           , let pref = "grandparent." ++ who ++ "."
           , pref `isPrefixOf` s
           , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中作为 @who@ 姻亲的叶（@inLaw.<x>.<who>@）。
inLawsOf :: PraxState -> String -> [String]
inLawsOf st who = sort
  [ s
  | s <- queryView st
  , "inLaw." `isPrefixOf` s
  , let rest = drop (length ("inLaw." :: String)) s
  , let (x, after) = break (== '.') rest
  , not (null x)
  , drop 1 after == who
  ]

-- | 闭合视图中 @who@ 作为主体的婚偶叶（@married.<who>.*@；对齐 Chronicle @"spouses of "@）。
spousesOf :: PraxState -> String -> [String]
spousesOf st who =
  sort [ s | s <- queryView st
           , let pref = "married." ++ who ++ "."
           , pref `isPrefixOf` s
           , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中 @who@ 的恶名叶（@notorious.<who>.*@）。
notoriousOf :: PraxState -> String -> [String]
notoriousOf st who =
  sort [ s | s <- queryView st, ("notorious." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中恶名标签为 @label@ 的叶（@notorious.<who>.<label>@）。
notorietiesOf :: PraxState -> String -> [String]
notorietiesOf st label = sort
  [ s
  | s <- queryView st
  , let pref = "notorious."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, lab) = splitLastDot rest
  , lab == label
  , not (null who)
  , '.' `notElem` who
  ]
  where
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中 @who@ 发出的赞誉叶（@esteemed.<who>.*@）。
esteemedOf :: PraxState -> String -> [String]
esteemedOf st who =
  sort [ s | s <- queryView st, ("esteemed." ++ who ++ ".") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为被赞誉方的叶（@esteemed.<observer>.<who>[.<label>]@）。
esteemersOf :: PraxState -> String -> [String]
esteemersOf st who = sort
  [ s
  | s <- queryView st
  , "esteemed." `isPrefixOf` s
  , let rest = drop (length ("esteemed." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中赞誉标签为 @label@ 的叶（@esteemed.<a>.<b>.<label>@）。
esteemsOf :: PraxState -> String -> [String]
esteemsOf st label = sort
  [ s
  | s <- queryView st
  , "esteemed." `isPrefixOf` s
  , let rest = drop (length ("esteemed." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , intercalate "." (drop 2 parts) == label
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 发出的蔑视叶（@scorned.<who>.*@）。
scornedOf :: PraxState -> String -> [String]
scornedOf st who =
  sort [ s | s <- queryView st, ("scorned." ++ who ++ ".") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为被蔑视方的叶（@scorned.<observer>.<who>[.<label>]@）。
scornersOf :: PraxState -> String -> [String]
scornersOf st who = sort
  [ s
  | s <- queryView st
  , "scorned." `isPrefixOf` s
  , let rest = drop (length ("scorned." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中蔑视标签为 @label@ 的叶（@scorned.<a>.<b>.<label>@）。
scornsOf :: PraxState -> String -> [String]
scornsOf st label = sort
  [ s
  | s <- queryView st
  , "scorned." `isPrefixOf` s
  , let rest = drop (length ("scorned." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , intercalate "." (drop 2 parts) == label
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的信念叶（@<who>.believes.*@）。
beliefsOf :: PraxState -> String -> [String]
beliefsOf st who =
  sort [ s | s <- queryView st, (who ++ ".believes.") `isPrefixOf` s ]

-- | 闭合视图中信念内容含 @prop@ 的叶（@*.believes.<prop>…@）。
believersOf :: PraxState -> String -> [String]
believersOf st prop =
  let marker = ".believes." ++ prop
  in sort [ s | s <- queryView st, marker `isInfixOf` s ]

-- | 闭合视图中 @who@ 的弧阶段叶（@<who>.arc.*@；排他 @!@ 展成 @.@）。
arcsOf :: PraxState -> String -> [String]
arcsOf st who =
  sort [ s | s <- queryView st, (who ++ ".arc.") `isPrefixOf` s ]

-- | 闭合视图中弧阶段为 @stage@ 的叶（@<who>.arc.<stage>@）。
arcedOf :: PraxState -> String -> [String]
arcedOf st stage = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 3
  , parts !! 1 == "arc"
  , intercalate "." (drop 2 parts) == stage
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的年龄叶（@age.<who>.*@）。
agesOf :: PraxState -> String -> [String]
agesOf st who =
  sort [ s | s <- queryView st, ("age." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中年龄值为 @n@ 的叶（@age.<who>.<n>@）。
agedOf :: PraxState -> String -> [String]
agedOf st n = sort
  [ s
  | s <- queryView st
  , let pref = "age."
  , pref `isPrefixOf` s
  , let rest = drop (length pref) s
  , let (who, lab) = splitLastDot rest
  , lab == n
  , not (null who)
  , '.' `notElem` who
  ]
  where
    splitLastDot s =
      case break (== '.') (reverse s) of
        (rf, '.' : rw) -> (reverse rw, reverse rf)
        (rf, _)        -> ("", reverse rf)

-- | 闭合视图中与 @who@ 相关的事业实例叶（@practice.<pid>.<who>.*@，含 crew/did）。
projectsOf :: PraxState -> String -> [String]
projectsOf st who = sort
  [ s
  | s <- queryView st
  , "practice." `isPrefixOf` s
  , let rest = drop (length ("practice." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中实践 @pid@ 下的角色相关叶（@practice.<pid>.*@）。
practitionersOf :: PraxState -> String -> [String]
practitionersOf st pid =
  let pref = "practice." ++ pid ++ "."
  in sort [ s | s <- queryView st, pref `isPrefixOf` s ]

-- | 闭合视图中与 @who@ 相关的催收叶（债权人或债务人；@demanded.<creditor>.<debtor>.<content>@）。
demandedOf :: PraxState -> String -> [String]
demandedOf st who = sort
  [ s
  | s <- queryView st
  , "demanded." `isPrefixOf` s
  , let rest = drop (length ("demanded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为被催收方的叶（@demanded.<creditor>.<who>.*@）。
demandersOf :: PraxState -> String -> [String]
demandersOf st who = sort
  [ s
  | s <- queryView st
  , "demanded." `isPrefixOf` s
  , let rest = drop (length ("demanded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为催收方的叶（@demanded.<who>.<debtor>.*@）。
demandeesOf :: PraxState -> String -> [String]
demandeesOf st who = sort
  [ s
  | s <- queryView st
  , "demanded." `isPrefixOf` s
  , let rest = drop (length ("demanded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中开放的节庆叶（@festival.*@）。
festivalsOf :: PraxState -> [String]
festivalsOf st =
  sort [ s | s <- queryView st, "festival." `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的位置叶（@at.<who>.*@）。
locationsOf :: PraxState -> String -> [String]
locationsOf st who =
  sort [ s | s <- queryView st, ("at." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中位于 @place@ 的角色叶（@at.<who>.<place>@；! 展成 .）。
occupantsOf :: PraxState -> String -> [String]
occupantsOf st place = sort
  [ s
  | s <- queryView st
  , "at." `isPrefixOf` s
  , let rest = drop (length ("at." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == place
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的持有叶（@holding.<who>.*@）。
holdingOf :: PraxState -> String -> [String]
holdingOf st who =
  sort [ s | s <- queryView st, ("holding." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中持有 @item@ 的角色叶（@holding.<who>.<item>@）。
holdersOf :: PraxState -> String -> [String]
holdersOf st item = sort
  [ s
  | s <- queryView st
  , "holding." `isPrefixOf` s
  , let rest = drop (length ("holding." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == item
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的携带叶（@carrying.<who>.*@）。
carryingOf :: PraxState -> String -> [String]
carryingOf st who =
  sort [ s | s <- queryView st, ("carrying." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中携带 @item@ 的角色叶（@carrying.<who>.<item>@）。
carriersOf :: PraxState -> String -> [String]
carriersOf st item = sort
  [ s
  | s <- queryView st
  , "carrying." `isPrefixOf` s
  , let rest = drop (length ("carrying." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == item
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 发出的排斥叶（@shunned.<who>.*@）。
shunnedOf :: PraxState -> String -> [String]
shunnedOf st who =
  sort [ s | s <- queryView st, ("shunned." ++ who ++ ".") `isPrefixOf` s ]


-- | 闭合视图中 @who@ 作为被排斥方的叶（@shunned.<actor>.<who>@）。
shunnersOf :: PraxState -> String -> [String]
shunnersOf st who = sort
  [ s
  | s <- queryView st
  , "shunned." `isPrefixOf` s
  , let rest = drop (length ("shunned." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的威胁叶（@threatened.<sid>.<extorter>.<victim>@，任一侧）。
threatenedOf :: PraxState -> String -> [String]
threatenedOf st who = sort
  [ s
  | s <- queryView st
  , "threatened." `isPrefixOf` s
  , let rest = drop (length ("threatened." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , (parts !! 1) == who || (parts !! 2) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为受威胁方的叶（@threatened.<sid>.<extorter>.<who>@）。
threatenersOf :: PraxState -> String -> [String]
threatenersOf st who = sort
  [ s
  | s <- queryView st
  , "threatened." `isPrefixOf` s
  , let rest = drop (length ("threatened." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为施威胁方的叶（@threatened.<sid>.<who>.<victim>@）。
threateneesOf :: PraxState -> String -> [String]
threateneesOf st who = sort
  [ s
  | s <- queryView st
  , "threatened." `isPrefixOf` s
  , let rest = drop (length ("threatened." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的勒索痕（@<extorter>.extorted.<victim>.<sid>@，任一侧）。
extortedOf :: PraxState -> String -> [String]
extortedOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 4
  , parts !! 1 == "extorted"
  , head parts == who || (parts !! 2) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被勒索方的痕（@<extorter>.extorted.<who>.<sid>@）。
extortersOf :: PraxState -> String -> [String]
extortersOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 4
  , parts !! 1 == "extorted"
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为勒索方的痕（@<who>.extorted.<victim>.<sid>@）。
extorteesOf :: PraxState -> String -> [String]
extorteesOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 4
  , parts !! 1 == "extorted"
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的顺从叶（@complied.<sid>.<extorter>.<victim>@，任一侧）。
compliedOf :: PraxState -> String -> [String]
compliedOf st who = sort
  [ s
  | s <- queryView st
  , "complied." `isPrefixOf` s
  , let rest = drop (length ("complied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , (parts !! 1) == who || (parts !! 2) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被顺从方的叶（@complied.<sid>.<who>.<victim>@）。
compliersOf :: PraxState -> String -> [String]
compliersOf st who = sort
  [ s
  | s <- queryView st
  , "complied." `isPrefixOf` s
  , let rest = drop (length ("complied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为顺从方的叶（@complied.<sid>.<extorter>.<who>@）。
complieesOf :: PraxState -> String -> [String]
complieesOf st who = sort
  [ s
  | s <- queryView st
  , "complied." `isPrefixOf` s
  , let rest = drop (length ("complied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的违抗叶（@defied.<sid>.<victim>.<extorter>@，任一侧）。
defiedOf :: PraxState -> String -> [String]
defiedOf st who = sort
  [ s
  | s <- queryView st
  , "defied." `isPrefixOf` s
  , let rest = drop (length ("defied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , (parts !! 1) == who || (parts !! 2) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]



-- | 闭合视图中 @who@ 作为被违抗方的叶（@defied.<sid>.<victim>.<who>@）。
defiersOf :: PraxState -> String -> [String]
defiersOf st who = sort
  [ s
  | s <- queryView st
  , "defied." `isPrefixOf` s
  , let rest = drop (length ("defied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 2 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为违抗方的叶（@defied.<sid>.<who>.<extorter>@）。
defieesOf :: PraxState -> String -> [String]
defieesOf st who = sort
  [ s
  | s <- queryView st
  , "defied." `isPrefixOf` s
  , let rest = drop (length ("defied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 3
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的烙印叶（@branded.<who>@ / @brandedHeretic.<who>@ 等 branded* 前缀）。
brandedOf :: PraxState -> String -> [String]
brandedOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 2
  , "branded" `isPrefixOf` head parts
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的撕毁协议叶（@revoked.<creditor>.<debtor>@，任一侧）。
revokedOf :: PraxState -> String -> [String]
revokedOf st who = sort
  [ s
  | s <- queryView st
  , "revoked." `isPrefixOf` s
  , let rest = drop (length ("revoked." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]




-- | 闭合视图中 @who@ 作为被撕毁方的叶（@revoked.<creditor>.<who>@）。
revokersOf :: PraxState -> String -> [String]
revokersOf st who = sort
  [ s
  | s <- queryView st
  , "revoked." `isPrefixOf` s
  , let rest = drop (length ("revoked." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为撕毁方的叶（@revoked.<who>.<debtor>@）。
revokeesOf :: PraxState -> String -> [String]
revokeesOf st who = sort
  [ s
  | s <- queryView st
  , "revoked." `isPrefixOf` s
  , let rest = drop (length ("revoked." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的招供叶（@confessed.<who>@ 或 @<who>.confessed.@* Village 形）。
confessedOf :: PraxState -> String -> [String]
confessedOf st who = sort
  [ s
  | s <- queryView st
  , let parts = splitDots s
  , length parts >= 2
  , (head parts == "confessed" && (parts !! 1) == who)
    || (head parts == who && (parts !! 1) == "confessed")
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的悔罪叶（@recanted.<who>@）。
recantedOf :: PraxState -> String -> [String]
recantedOf st who =
  sort [ s | s <- queryView st, s == ("recanted." ++ who)
              || ("recanted." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中与 @who@ 相关的放逐叶（@ostracized.<actor>.<target>@，任一侧）。
ostracizedOf :: PraxState -> String -> [String]
ostracizedOf st who = sort
  [ s
  | s <- queryView st
  , "ostracized." `isPrefixOf` s
  , let rest = drop (length ("ostracized." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被方的叶（@ostracized.<actor>.<who>@）。
ostracizersOf :: PraxState -> String -> [String]
ostracizersOf st who = sort
  [ s
  | s <- queryView st
  , "ostracized." `isPrefixOf` s
  , let rest = drop (length ("ostracized." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@ostracized.<who>.<target>@）。
ostracizeesOf :: PraxState -> String -> [String]
ostracizeesOf st who = sort
  [ s
  | s <- queryView st
  , "ostracized." `isPrefixOf` s
  , let rest = drop (length ("ostracized." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的流放叶（@exiled.<who>@）。
exiledOf :: PraxState -> String -> [String]
exiledOf st who =
  sort [ s | s <- queryView st, s == ("exiled." ++ who)
              || ("exiled." ++ who ++ ".") `isPrefixOf` s ]



-- | 闭合视图中与 @who@ 相关的控告叶（@denounced.<actor>.<target>@，任一侧）。
denouncedOf :: PraxState -> String -> [String]
denouncedOf st who = sort
  [ s
  | s <- queryView st
  , "denounced." `isPrefixOf` s
  , let rest = drop (length ("denounced." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被方的叶（@denounced.<actor>.<who>@）。
denouncersOf :: PraxState -> String -> [String]
denouncersOf st who = sort
  [ s
  | s <- queryView st
  , "denounced." `isPrefixOf` s
  , let rest = drop (length ("denounced." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@denounced.<who>.<target>@）。
denounceesOf :: PraxState -> String -> [String]
denounceesOf st who = sort
  [ s
  | s <- queryView st
  , "denounced." `isPrefixOf` s
  , let rest = drop (length ("denounced." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的审查叶（@censured.<actor>.<target>@，任一侧）。
censuredOf :: PraxState -> String -> [String]
censuredOf st who = sort
  [ s
  | s <- queryView st
  , "censured." `isPrefixOf` s
  , let rest = drop (length ("censured." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被方的叶（@censured.<actor>.<who>@）。
censurersOf :: PraxState -> String -> [String]
censurersOf st who = sort
  [ s
  | s <- queryView st
  , "censured." `isPrefixOf` s
  , let rest = drop (length ("censured." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@censured.<who>.<target>@）。
censureesOf :: PraxState -> String -> [String]
censureesOf st who = sort
  [ s
  | s <- queryView st
  , "censured." `isPrefixOf` s
  , let rest = drop (length ("censured." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的游街叶（@paraded.<actor>.<target>@，任一侧）。
paradedOf :: PraxState -> String -> [String]
paradedOf st who = sort
  [ s
  | s <- queryView st
  , "paraded." `isPrefixOf` s
  , let rest = drop (length ("paraded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]




-- | 闭合视图中 @who@ 作为被方的叶（@paraded.<actor>.<who>@）。
paradersOf :: PraxState -> String -> [String]
paradersOf st who = sort
  [ s
  | s <- queryView st
  , "paraded." `isPrefixOf` s
  , let rest = drop (length ("paraded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@paraded.<who>.<target>@）。
paradeesOf :: PraxState -> String -> [String]
paradeesOf st who = sort
  [ s
  | s <- queryView st
  , "paraded." `isPrefixOf` s
  , let rest = drop (length ("paraded." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的市集喊冤叶（@cried.<actor>.<target>@，任一侧）。
criedOf :: PraxState -> String -> [String]
criedOf st who = sort
  [ s
  | s <- queryView st
  , "cried." `isPrefixOf` s
  , let rest = drop (length ("cried." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被方的叶（@cried.<actor>.<who>@）。
criersOf :: PraxState -> String -> [String]
criersOf st who = sort
  [ s
  | s <- queryView st
  , "cried." `isPrefixOf` s
  , let rest = drop (length ("cried." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@cried.<who>.<target>@）。
crieesOf :: PraxState -> String -> [String]
crieesOf st who = sort
  [ s
  | s <- queryView st
  , "cried." `isPrefixOf` s
  , let rest = drop (length ("cried." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的市集声援叶（@rallied.<actor>.<target>@，任一侧）。
ralliedOf :: PraxState -> String -> [String]
ralliedOf st who = sort
  [ s
  | s <- queryView st
  , "rallied." `isPrefixOf` s
  , let rest = drop (length ("rallied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被方的叶（@rallied.<actor>.<who>@）。
ralliersOf :: PraxState -> String -> [String]
ralliersOf st who = sort
  [ s
  | s <- queryView st
  , "rallied." `isPrefixOf` s
  , let rest = drop (length ("rallied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主动方的叶（@rallied.<who>.<target>@）。
rallieesOf :: PraxState -> String -> [String]
rallieesOf st who = sort
  [ s
  | s <- queryView st
  , "rallied." `isPrefixOf` s
  , let rest = drop (length ("rallied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的叛逃叶（@fled.<who>@）。
fledOf :: PraxState -> String -> [String]
fledOf st who =
  sort [ s | s <- queryView st, s == ("fled." ++ who)
              || ("fled." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的和解叶（@reconciled.<who>@）。
reconciledOf :: PraxState -> String -> [String]
reconciledOf st who =
  sort [ s | s <- queryView st, s == ("reconciled." ++ who)
              || ("reconciled." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中与 @who@ 相关的婚入叶（@married.<a>.<b>@，任一侧）。
marriedOf :: PraxState -> String -> [String]
marriedOf st who = sort
  [ s
  | s <- queryView st
  , "married." `isPrefixOf` s
  , let rest = drop (length ("married." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]



-- | 闭合视图中与 @who@ 相关的目击疑心叶（@eyed.<actor>.<target>@，任一侧）。
eyedOf :: PraxState -> String -> [String]
eyedOf st who = sort
  [ s
  | s <- queryView st
  , "eyed." `isPrefixOf` s
  , let rest = drop (length ("eyed." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被目击方的叶（@eyed.<actor>.<who>@）。
eyersOf :: PraxState -> String -> [String]
eyersOf st who = sort
  [ s
  | s <- queryView st
  , "eyed." `isPrefixOf` s
  , let rest = drop (length ("eyed." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为目击方的叶（@eyed.<who>.<target>@）。
eyeesOf :: PraxState -> String -> [String]
eyeesOf st who = sort
  [ s
  | s <- queryView st
  , "eyed." `isPrefixOf` s
  , let rest = drop (length ("eyed." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中与 @who@ 相关的对质叶（@confronted.<actor>.<target>@，任一侧）。
confrontedOf :: PraxState -> String -> [String]
confrontedOf st who = sort
  [ s
  | s <- queryView st
  , "confronted." `isPrefixOf` s
  , let rest = drop (length ("confronted." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为被对质方的叶（@confronted.<actor>.<who>@）。
confrontersOf :: PraxState -> String -> [String]
confrontersOf st who = sort
  [ s
  | s <- queryView st
  , "confronted." `isPrefixOf` s
  , let rest = drop (length ("confronted." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为对质方的叶（@confronted.<who>.<target>@）。
confronteesOf :: PraxState -> String -> [String]
confronteesOf st who = sort
  [ s
  | s <- queryView st
  , "confronted." `isPrefixOf` s
  , let rest = drop (length ("confronted." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的赎罪叶（@atoned.<who>@）。
atonedOf :: PraxState -> String -> [String]
atonedOf st who =
  sort [ s | s <- queryView st, s == ("atoned." ++ who)
              || ("atoned." ++ who ++ ".") `isPrefixOf` s ]



-- | 闭合视图中与 @who@ 相关的冤屈叶（@wronged.<offender>.<victim>@，任一侧；Feud）。
wrongedOf :: PraxState -> String -> [String]
wrongedOf st who = sort
  [ s
  | s <- queryView st
  , "wronged." `isPrefixOf` s
  , let rest = drop (length ("wronged." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中 @who@ 作为受害方的冤屈叶（@wronged.<offender>.<who>@）。
wrongersOf :: PraxState -> String -> [String]
wrongersOf st who = sort
  [ s
  | s <- queryView st
  , "wronged." `isPrefixOf` s
  , let rest = drop (length ("wronged." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为加害方的冤屈叶（@wronged.<who>.<victim>@）。
wrongeesOf :: PraxState -> String -> [String]
wrongeesOf st who = sort
  [ s
  | s <- queryView st
  , "wronged." `isPrefixOf` s
  , let rest = drop (length ("wronged." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 的饥饿叶（@hungry.<who>@；Village）。
hungryOf :: PraxState -> String -> [String]
hungryOf st who =
  sort [ s | s <- queryView st, s == ("hungry." ++ who)
              || ("hungry." ++ who ++ ".") `isPrefixOf` s ]



-- | 闭合视图中 @who@ 的暴脾气叶（@shortTempered.<who>@；Village）。
shortTemperedOf :: PraxState -> String -> [String]
shortTemperedOf st who =
  sort [ s | s <- queryView st, s == ("shortTempered." ++ who)
              || ("shortTempered." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的胃口叶（@appetite.<who>@；Village）。
appetiteOf :: PraxState -> String -> [String]
appetiteOf st who =
  sort [ s | s <- queryView st, s == ("appetite." ++ who)
              || ("appetite." ++ who ++ ".") `isPrefixOf` s ]



-- | 闭合视图中 @who@ 作为怨恨主体的叶（@resents.<who>.<target>@；Feud）。
resentsOf :: PraxState -> String -> [String]
resentsOf st who = sort
  [ s
  | s <- queryView st
  , ("resents." ++ who ++ ".") `isPrefixOf` s
  ]





-- | 闭合视图中 @who@ 作为怨恨目标的叶（@resents.<actor>.<who>@）。
resentersOf :: PraxState -> String -> [String]
resentersOf st who = sort
  [ s
  | s <- queryView st
  , "resents." `isPrefixOf` s
  , let rest = drop (length ("resents." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , parts !! 1 == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]

-- | 闭合视图中 @who@ 作为主体的同盟叶（@allied.<who>.*@；对齐 spousesOf / Chronicle @"allies of "@）。
alliesOf :: PraxState -> String -> [String]
alliesOf st who =
  sort [ s | s <- queryView st
           , let pref = "allied." ++ who ++ "."
           , pref `isPrefixOf` s
           , '.' `notElem` drop (length pref) s ]

-- | 闭合视图中与 @who@ 相关的同盟叶（@allied.<a>.<b>@ 任一侧；Feud）。
alliedOf :: PraxState -> String -> [String]
alliedOf st who = sort
  [ s
  | s <- queryView st
  , "allied." `isPrefixOf` s
  , let rest = drop (length ("allied." :: String)) s
  , let parts = splitDots rest
  , length parts >= 2
  , head parts == who || (parts !! 1) == who
  ]
  where
    splitDots :: String -> [String]
    splitDots s = case break (== '.') s of
      (a, '.' : b) -> a : splitDots b
      (a, _)       -> [a | not (null a)]


-- | 闭合视图中货摊存货叶（@stall.<item>@；Village 金轨迹，对象叶形）。
stallOf :: PraxState -> [String]
stallOf st =
  sort [ s | s <- queryView st, "stall." `isPrefixOf` s ]

checkpoint :: FilePath -> PraxState -> IO ()
checkpoint = saveState

-- | 从 @path@ 恢复状态到新鲜 @world@ 模板上（与 'Prax.Persist.loadState' 同形）。
restore :: FilePath -> PraxState -> IO PraxState
restore = loadState
