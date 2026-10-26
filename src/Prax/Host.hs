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
-- v249：'threatenedOf'/'extortedOf' 胁迫/勒索叶。
-- v258：'compliedOf'/'defiedOf' 顺从/违抗叶。
-- v281：'brandedOf'/'revokedOf' 烙印/撕毁协议叶（Sandbox 胁迫/沉默债）。
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
  , regardsToward
  , factionsNamed
  , debtsOf
  , obligationsOf
  , breachesOf
  , feelingsOf
  , liesOf
  , chattedWithOf
  , traitsOf
  , moodsOf
  , bondsOf
  , kinOf
  , notoriousOf
  , esteemedOf
  , scornedOf
  , beliefsOf
  , arcsOf
  , agesOf
  , projectsOf
  , demandedOf
  , festivalsOf
  , locationsOf
  , holdingOf
  , carryingOf
  , shunnedOf
  , threatenedOf
  , extortedOf
  , compliedOf
  , defiedOf
  , brandedOf
  , revokedOf
  , checkpoint
  , restore
  ) where

import           Data.List (isInfixOf, isPrefixOf, nub, sort, (\\))
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

-- | 闭合视图中 @who@ 的谎言标记叶（@<who>.lied.*@）。
liesOf :: PraxState -> String -> [String]
liesOf st who =
  sort [ s | s <- queryView st, (who ++ ".lied.") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的聊天叶（@<who>.chattedWith.*@）。
chattedWithOf :: PraxState -> String -> [String]
chattedWithOf st who =
  sort [ s | s <- queryView st, (who ++ ".chattedWith.") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的性格叶（@trait.<who>.*@）。
traitsOf :: PraxState -> String -> [String]
traitsOf st who =
  sort [ s | s <- queryView st, ("trait." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的基线心境叶（@mood.<who>.*@；排他 @!@ 展成 @.@）。
moodsOf :: PraxState -> String -> [String]
moodsOf st who =
  sort [ s | s <- queryView st, ("mood." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中与 @who@ 相关的公开纽带叶（@bond.<who>.*@ 一侧）。
bondsOf :: PraxState -> String -> [String]
bondsOf st who =
  sort [ s | s <- queryView st, ("bond." ++ who ++ ".") `isPrefixOf` s ]

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

-- | 闭合视图中 @who@ 的恶名叶（@notorious.<who>.*@）。
notoriousOf :: PraxState -> String -> [String]
notoriousOf st who =
  sort [ s | s <- queryView st, ("notorious." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 发出的赞誉叶（@esteemed.<who>.*@）。
esteemedOf :: PraxState -> String -> [String]
esteemedOf st who =
  sort [ s | s <- queryView st, ("esteemed." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 发出的蔑视叶（@scorned.<who>.*@）。
scornedOf :: PraxState -> String -> [String]
scornedOf st who =
  sort [ s | s <- queryView st, ("scorned." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的信念叶（@<who>.believes.*@）。
beliefsOf :: PraxState -> String -> [String]
beliefsOf st who =
  sort [ s | s <- queryView st, (who ++ ".believes.") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的弧阶段叶（@<who>.arc.*@；排他 @!@ 展成 @.@）。
arcsOf :: PraxState -> String -> [String]
arcsOf st who =
  sort [ s | s <- queryView st, (who ++ ".arc.") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的年龄叶（@age.<who>.*@）。
agesOf :: PraxState -> String -> [String]
agesOf st who =
  sort [ s | s <- queryView st, ("age." ++ who ++ ".") `isPrefixOf` s ]

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

-- | 闭合视图中开放的节庆叶（@festival.*@）。
festivalsOf :: PraxState -> [String]
festivalsOf st =
  sort [ s | s <- queryView st, "festival." `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的位置叶（@at.<who>.*@）。
locationsOf :: PraxState -> String -> [String]
locationsOf st who =
  sort [ s | s <- queryView st, ("at." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的持有叶（@holding.<who>.*@）。
holdingOf :: PraxState -> String -> [String]
holdingOf st who =
  sort [ s | s <- queryView st, ("holding." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 的携带叶（@carrying.<who>.*@）。
carryingOf :: PraxState -> String -> [String]
carryingOf st who =
  sort [ s | s <- queryView st, ("carrying." ++ who ++ ".") `isPrefixOf` s ]

-- | 闭合视图中 @who@ 发出的排斥叶（@shunned.<who>.*@）。
shunnedOf :: PraxState -> String -> [String]
shunnedOf st who =
  sort [ s | s <- queryView st, ("shunned." ++ who ++ ".") `isPrefixOf` s ]

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

checkpoint :: FilePath -> PraxState -> IO ()
checkpoint = saveState

-- | 从 @path@ 恢复状态到新鲜 @world@ 模板上（与 'Prax.Persist.loadState' 同形）。
restore :: FilePath -> PraxState -> IO PraxState
restore = loadState
