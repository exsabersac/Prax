-- | 亲属：基事实 + 派生闭包（规格 §2）。婚姻移动成员——折叠的回报浓缩为一行。
-- v61：'divorce' 把既有「撤回婚姻」契约暴露为可创作动作（成员不变）。
-- v62：'birth'/'birthInto' 写入亲子事实；后者一并加入家庭派系。
-- v67：'bequeath' 持有物继承（镜像 succession 的死亡+亲子门禁，作用于 holds.<thing>!<holder>）。
-- v73：'setAge'/'ageAtLeast' —— 排他年龄叶，供成年门禁与未来长子继承。
module Prax.Kin
  ( kinAxioms
  , wed
  , divorce
  , birth
  , birthInto
  , succession
  , bequeath
  , setAge
  , ageAtLeast
  ) where

import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Types (Action, Outcome (..), action)
import           Prax.Derive (Axiom, axiom)
import           Prax.Faction (joins)

-- | 婚姻对称、兄弟姐妹、祖父母、姻亲——全部派生，全部由成员脊骨驱动。
kinAxioms :: [Axiom]
kinAxioms =
  [ axiom [ Match "married.A.B" ]                        [ "married.B.A" ]
  , axiom [ Match "parent.P.X", Match "parent.P.Y"
          , Neq "X" "Y" ]                                [ "sibling.X.Y" ]
  , axiom [ Match "parent.G.P", Match "parent.P.C" ]     [ "grandparent.G.C" ]
  , axiom [ Match "married.A.B", Match "parent.P.A" ]    [ "inLaw.P.B" ]
  , axiom [ Match "married.A.B", Match "sibling.A.S" ]   [ "inLaw.S.B" ]
  ]

-- | @wed joiner faction spouse@：婚姻事实加上加入者的成员写入（嫁入即加入）。
wed :: String -> String -> String -> [Outcome]
wed joiner faction spouse
  | bad joiner || bad spouse =
      error ("wed: joiner and spouse must be single path segments (no '.' or '!'): "
             ++ show (joiner, spouse))
  | otherwise =
      [ Insert ("married." ++ joiner ++ "." ++ spouse)
      , joins joiner faction ]
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 离婚：撤回婚姻双边（基事实任一方向皆可），成员不变——与 KinSpec 溶解契约相同，
-- 现为可创作动作。门禁于 @married.Actor.Spouse@（视图双侧均可匹配）。
divorce :: String -> Action
divorce label = action label
  [ Match "married.Actor.Spouse" ]
  [ Delete "married.Actor.Spouse"
  , Delete "married.Spouse.Actor" ]

-- | 出生：写入 @parent.<parent>.<child>@。名须单路径段。
birth :: String -> String -> [Outcome]
birth parent child
  | bad parent || bad child =
      error ("birth: parent and child must be single path segments (no '.' or '!'): "
             ++ show (parent, child))
  | otherwise = [ Insert ("parent." ++ parent ++ "." ++ child) ]
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 出生并加入家庭派系：亲子事实 + 'Prax.Faction.joins'。
birthInto :: String -> String -> String -> [Outcome]
birthInto parent child faction =
  birth parent child ++ [ joins child faction ]

-- | 继承为排他：死者持有者的任何子女可主张；`!` 覆盖保证单一继承。
succession :: String -> Action
succession office
  | null office || any (`elem` (".!" :: String)) office =
      error ("succession: office " ++ show office ++ " must be a single path segment")
  | otherwise = action ("[Actor]: claim the office of " ++ office)
      [ Match ("office." ++ office ++ "!H")
      , Match "dead.H"
      , Match "parent.H.Actor"
      , Neq "Actor" "H" ]
      [ Insert ("office." ++ office ++ "!Actor") ]

-- | 持有物继承：死者持有者的子女可主张 @holds.<thing>!<holder>@；`!` 覆盖保证单一继承人。
-- 与 'succession' 同形，但作用于普通持有物而非 office。
bequeath :: String -> Action
bequeath thing
  | null thing || any (`elem` (".!" :: String)) thing =
      error ("bequeath: thing " ++ show thing ++ " must be a single path segment")
  | otherwise = action ("[Actor]: claim the holding " ++ thing)
      [ Match ("holds." ++ thing ++ "!H")
      , Match "dead.H"
      , Match "parent.H.Actor"
      , Neq "Actor" "H" ]
      [ Insert ("holds." ++ thing ++ "!Actor") ]

-- | 排他年龄：@age.<who>!<n>@。
setAge :: String -> Int -> Outcome
setAge who n
  | null who || any (`elem` (".!" :: String)) who =
      error ("setAge: who " ++ show who ++ " must be a single path segment")
  | n < 0 = error ("setAge: age " ++ show n ++ " must be >= 0")
  | otherwise = Insert ("age." ++ who ++ "!" ++ show n)

-- | 条件：@who@ 年龄 >= @n@（读排他叶）。
ageAtLeast :: String -> Int -> [Condition]
ageAtLeast who n =
  [ Match ("age." ++ who ++ "!AgeN")
  , Cmp Gte "AgeN" (show n) ]
