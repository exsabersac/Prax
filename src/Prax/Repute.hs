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
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Derive (Axiom, axiom)
import           Prax.Types (authoredPatClash)

-- | Every observer with evidence of the deed regards its subject under @label@.
standing :: String -> String -> Axiom
standing pat = standingWith pat []

-- | 'standing', defeated by a base-fact pattern (which may use only the deed
-- pattern's variables — checked, loud error otherwise): derives only while
-- the defeater is absent.
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

-- | Condition: @observer@ regards @subject@ under @label@ (a derived fact —
-- usable in preconditions and wants, which read the closed view).
regardedAs :: String -> String -> String -> Condition
regardedAs observer subject label =
  Match ("regards." ++ observer ++ "." ++ subject ++ "." ++ label)

-- | @notorious.\<subject\>.\<label\>@ while at least @k@ distinct observers hold
-- the regard.
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
