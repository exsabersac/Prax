-- | 派生声誉：地位从不存储，只从观察者证据派生。
--
-- @regards.\<observer\>.\<subject\>.\<label\>@ 是公理派生事实，直接读自观察者证据（目击或传闻），
-- 因此免费继承信息不对称，并在其支持消解时瞬间消解。
--
-- 地位由 __赎罪而非失忆__ 击败：'standingUnless' 用 /基事实/ 击败者守卫派生（例如
-- @atoned.\<culprit\>@）——一次插入同时消解每个派生 regard，而每个信念（事迹记忆）持续。
-- 击败者必须只命名基事实，从不命名派生头，保持闭包分层。
--
-- 'notoriety' 把佐证变成 /全局/ 派生事实：@notorious.\<subject\>.\<label\>@ 在至少 @k@ 个不同
-- 观察者持有 regard 时成立——跨不动点回合计数派生事实。阈值是带声明含义的创作世界参数
-- （「全村皆知」）。
--
-- 约定（如 "Prax.Rumor"）：事迹模式的 __第一个__ 变量是主体（地位所指之人）。
module Prax.Repute
  ( standing
  , standingUnless
  , regardedAs
  , notoriety
  , scornStanding
  , esteemStanding
  , scornDesire
  , esteemDesire
  , isNotorious
  , lacksNotorious
  , hasScorned
  , lacksScorned
  , everNotorious
  , neverNotorious
  , hasEsteemed
  , lacksEsteemed
  , everEsteemed
  , neverEsteemed
  , everScorned
  , neverScorned
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Derive (Axiom, axiom)
import           Prax.Types (Action, Desire (..), Want (..), Outcome (..), action, authoredPatClash)
import           Prax.Core (adjustScore)

-- | 每个对行为有证据的观察者都将其 regard 为主体。
standing :: String -> String -> Axiom
standing pat = standingWith pat []

-- | 'standing'，被基事实模式击败（存在时溶解派生 regard）。
standingUnless :: String -> String -> String -> Axiom
standingUnless pat defeater = standingWith pat [ Not (checkedDefeater pat defeater) ]

-- A defeater may use only the deed pattern's variables: negation-as-failure
-- would silently turn any OTHER variable into a global existential guard
-- (one unrelated fact dissolving everyone's standing).
checkedDefeater :: String -> String -> String
checkedDefeater pat defeater
  | all (`elem` patVars) defVars = defeater
  | otherwise = error ("standingUnless: defeater " ++ show defeater
                       ++ " uses variables outside the deed pattern "
                       ++ show pat ++ " (would defeat globally, not per-subject)")
  where
    patVars = filter isVariable (pathNames pat)
    defVars = filter isVariable (pathNames defeater)

standingWith :: String -> [Condition] -> String -> Axiom
standingWith pat extra label
  | (v : _) <- authoredPatClash ["Regarder"] (pathNames pat) =
      error ("standing: deed pattern " ++ show pat ++ " reserves variable " ++ show v
             ++ " -- the Prax namespace and Regarder (the axiom's own observer"
             ++ " join variable) are both reserved")
  | otherwise = axiom (Match ("Regarder.believes." ++ pat) : extra)
        [ "regards.Regarder." ++ subjectOf pat ++ "." ++ label ]

-- | 条件：@observer@ 在 @label@ 下 regard @subject@。
regardedAs :: String -> String -> String -> Condition
regardedAs observer subject label =
  Match ("regards." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | 当至少 @n@ 名观察者 regard 主体时，@notorious.\<subject\>.\<label\>@ 成立。
notoriety :: String -> Int -> Axiom
notoriety label k =
  axiom [ Match ("regards.W0.T." ++ label)
        , Subquery "Rs" ["W"] [ Match ("regards.W.T." ++ label) ]
        , Count "N" "Rs"
        , Cmp Gte "N" (show k) ]
        [ "notorious.T." ++ label ]

-- The deed pattern's first variable: who the standing is about.
subjectOf :: String -> String
subjectOf pat = case filter isVariable (pathNames pat) of
  (v : _) -> v
  []      -> error ("standing: deed pattern " ++ show pat
                    ++ " names no one (a standing is about someone)")

-- 站队的分数效果反应 -----------------------------------------------------------

segOk :: String -> Bool
segOk n = not (null n) && all (`notElem` (".!" :: String)) n

-- | 站队的分数效果反应：观察者一旦 regard 主体，可一次性调整关系分（默认轻蔑）。
-- 与 "Prax.Reactions" 同风格——普通实践动作，门禁于派生 @regards@，一次守卫防止反复扣分。
-- 世界须已 'Prax.Engine.defineFunctions' 注册 'Prax.Core.coreFns'。
scornStanding :: String  -- ^ standing label (e.g. "thief")
              -> String  -- ^ relationship role (warmth / respect / trust …)
              -> Int     -- ^ score delta (typically negative)
              -> String  -- ^ reason token (single path segment)
              -> Action
scornStanding label role delta reason
  | not (segOk label) =
      error ("scornStanding: label " ++ show label ++ " must be a single path segment")
  | not (segOk role) =
      error ("scornStanding: role " ++ show role ++ " must be a single path segment")
  | not (segOk reason) =
      error ("scornStanding: reason " ++ show reason ++ " must be a single path segment")
  | otherwise = action ("[Actor]: scorn [T] as " ++ label)
      [ regardedAs "Actor" "T" label
      , Neq "T" "Actor"
      , Not ("scorned.Actor.T." ++ label) ]
      [ Insert ("scorned.Actor.T." ++ label)
      , adjustScore "Actor" "T" role delta reason ]

-- | 正向对应：regard 为褒义标签时抬分（一次）。
esteemStanding :: String -> String -> Int -> String -> Action
esteemStanding label role delta reason
  | not (segOk label) =
      error ("esteemStanding: label " ++ show label ++ " must be a single path segment")
  | not (segOk role) =
      error ("esteemStanding: role " ++ show role ++ " must be a single path segment")
  | not (segOk reason) =
      error ("esteemStanding: reason " ++ show reason ++ " must be a single path segment")
  | otherwise = action ("[Actor]: esteem [T] as " ++ label)
      [ regardedAs "Actor" "T" label
      , Neq "T" "Actor"
      , Not ("esteemed.Actor.T." ++ label) ]
      [ Insert ("esteemed.Actor.T." ++ label)
      , adjustScore "Actor" "T" role delta reason ]

-- | NPC 自动取 scorn 的欲望：在仍 regard 且尚未 scorn 时想完成 scorn。
scornDesire :: String -> String -> Int -> Desire
scornDesire who label w
  | not (segOk label) =
      error ("scornDesire: label " ++ show label ++ " must be a single path segment")
  | otherwise = Desire ("scorns-" ++ label)
      (Want [ Match ("scorned." ++ who ++ ".T." ++ label)
            , Match ("regards." ++ who ++ ".T." ++ label) ] w)

-- | NPC 自动取 esteem 的欲望：在仍 regard 且尚未 esteem 时想完成 esteem。
esteemDesire :: String -> String -> Int -> Desire
esteemDesire who label w
  | not (segOk label) =
      error ("esteemDesire: label " ++ show label ++ " must be a single path segment")
  | otherwise = Desire ("esteems-" ++ label)
      (Want [ Match ("esteemed." ++ who ++ ".T." ++ label)
            , Match ("regards." ++ who ++ ".T." ++ label) ] w)

-- | 条件：@subject@ 在 @label@ 下恶名昭著。
isNotorious :: String -> String -> Condition
isNotorious subject label = Match ("notorious." ++ subject ++ "." ++ label)

-- | 条件：@observer@ 已对 @subject@ 以 @label@ 表达过 esteem（@esteemed@ 一次守卫叶）。
hasEsteemed :: String -> String -> String -> Condition
hasEsteemed observer subject label =
  Match ("esteemed." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | 条件：@observer@ 尚未对 @subject@ 以 @label@ 表达 esteem（@hasEsteemed@ 对偶）。
lacksEsteemed :: String -> String -> String -> Condition
lacksEsteemed observer subject label =
  Not ("esteemed." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | 条件：@subject@ 在 @label@ 下非恶名昭著（@isNotorious@ 的 Not 对偶）。
lacksNotorious :: String -> String -> Condition
lacksNotorious subject label = Not ("notorious." ++ subject ++ "." ++ label)

-- | 条件：@observer@ 已对 @subject@ 以 @label@ 表达过 scorn。
hasScorned :: String -> String -> String -> Condition
hasScorned observer subject label =
  Match ("scorned." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | 条件：@observer@ 尚未对 @subject@ 以 @label@ 表达 scorn。
lacksScorned :: String -> String -> String -> Condition
lacksScorned observer subject label =
  Not ("scorned." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | 条件：@subject@ 在任一标签下恶名昭著。
everNotorious :: String -> Condition
everNotorious subject = Exists [ Match ("notorious." ++ subject ++ ".Label") ]

-- | 条件：@subject@ 在任何标签下皆非恶名。
neverNotorious :: String -> Condition
neverNotorious subject = Absent [ Match ("notorious." ++ subject ++ ".Label") ]

-- | 条件：@observer@ 曾对任何人表达过 esteem。
everEsteemed :: String -> Condition
everEsteemed observer = Exists [ Match ("esteemed." ++ observer ++ ".Subject.Label") ]

-- | 条件：@observer@ 从未表达过 esteem（@everEsteemed@ 的 Absent 对偶）。
neverEsteemed :: String -> Condition
neverEsteemed observer = Absent [ Match ("esteemed." ++ observer ++ ".Subject.Label") ]

-- | 条件：@observer@ 曾对任何人表达过 scorn。
everScorned :: String -> Condition
everScorned observer = Exists [ Match ("scorned." ++ observer ++ ".Subject.Label") ]

-- | 条件：@observer@ 从未表达过 scorn（@everScorned@ 的 Absent 对偶）。
neverScorned :: String -> Condition
neverScorned observer = Absent [ Match ("scorned." ++ observer ++ ".Subject.Label") ]
