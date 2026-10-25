-- | 亲属：基事实 + 派生闭包（规格 §2）。婚姻移动成员——折叠的回报浓缩为一行。
-- v61：'divorce' 把既有「撤回婚姻」契约暴露为可创作动作（成员不变）。
-- v62：'birth'/'birthInto' 写入亲子事实；后者一并加入家庭派系。
-- v67：'bequeath' 持有物继承（镜像 succession 的死亡+亲子门禁，作用于 holds.<thing>!<holder>）。
-- v73：'setAge'/'ageAtLeast' —— 排他年龄叶，供成年门禁与未来长子继承。
-- v78：'primogeniture' —— 长子继承 office（无更年长存活兄弟姐妹）。
-- v87：'isChildOf'/'isSiblingOf'/'isMarriedTo' 关系条件。
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
  , primogeniture
  , isChildOf
  , isSiblingOf
  , isMarriedTo
  , neverMarried
  , everMarried
  , isParentOf
  , neverParent
  , everParent
  , isInLawOf
  , lacksChildOf
  , lacksSiblingOf
  , lacksMarriedTo
  , lacksInLawOf
  , everInLaw
  , neverInLaw
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

-- | 长子继承：死亡持有者的存活子女中，无人年龄更大时，Actor 取得 @office@。
-- 需事先 'setAge'；无年龄叶的兄弟姐妹不构成「更年长」障碍（Absent 匹配失败即放行）。
primogeniture :: String -> Action
primogeniture office
  | null office || any (`elem` (".!" :: String)) office =
      error ("primogeniture: office " ++ show office ++ " must be a single path segment")
  | otherwise = action ("[Actor]: claim " ++ office ++ " by primogeniture")
      [ Match ("holds." ++ office ++ "!H")
      , Match "dead.H"
      , Match "parent.H.Actor"
      , Match "age.Actor!AgeA"
      , Absent [ Match "parent.H.Sib"
               , Neq "Sib" "Actor"
               , Not "dead.Sib"
               , Match "age.Sib!AgeS"
               , Cmp Gt "AgeS" "AgeA" ]
      ]
      [ Insert ("holds." ++ office ++ "!Actor") ]

-- | 条件：@child@ 的父母为 @parent@。
isChildOf :: String -> String -> Condition
isChildOf child parent = Match ("parent." ++ parent ++ "." ++ child)

-- | 条件：@a@ 与 @b@ 为兄弟姐妹（读派生 @sibling@）。
isSiblingOf :: String -> String -> Condition
isSiblingOf a b = Match ("sibling." ++ a ++ "." ++ b)

-- | 条件：@a@ 与 @b@ 已婚（任一侧基事实经公理对称）。
isMarriedTo :: String -> String -> Condition
isMarriedTo a b = Match ("married." ++ a ++ "." ++ b)

-- | 条件：@who@ 无任何婚姻叶（未婚 / 已离后无现任）。
neverMarried :: String -> Condition
neverMarried who = Absent [ Match ("married." ++ who) ]

-- | 条件：@who@ 有至少一段婚姻叶（@neverMarried@ 的 Exists 对偶）。
everMarried :: String -> Condition
everMarried who = Exists [ Match ("married." ++ who) ]

-- | 条件：@parent@ 是 @child@ 的父母（'isChildOf' 的对偶）。
isParentOf :: String -> String -> Condition
isParentOf parent child = isChildOf child parent

-- | 条件：@who@ 无任何子女叶（非父母）。
neverParent :: String -> Condition
neverParent who = Absent [ Match ("parent." ++ who) ]

-- | 条件：@who@ 有至少一名子女（@neverParent@ 的 Exists 对偶）。
everParent :: String -> Condition
everParent who = Exists [ Match ("parent." ++ who) ]

-- | 条件：@a@ 是 @b@ 的姻亲（读派生 @inLaw@）。
isInLawOf :: String -> String -> Condition
isInLawOf a b = Match ("inLaw." ++ a ++ "." ++ b)

-- | 条件：@child@ 的父母不是 @parent@（@isChildOf@ 的 Not 对偶）。
lacksChildOf :: String -> String -> Condition
lacksChildOf child parent = Not ("parent." ++ parent ++ "." ++ child)

-- | 条件：@a@ 与 @b@ 非兄弟姐妹（@isSiblingOf@ 的 Not 对偶）。
lacksSiblingOf :: String -> String -> Condition
lacksSiblingOf a b = Not ("sibling." ++ a ++ "." ++ b)

-- | 条件：@a@ 与 @b@ 未婚（精确叶；与 @neverMarried@ 的任意婚姻 Absent 不同）。
lacksMarriedTo :: String -> String -> Condition
lacksMarriedTo a b = Not ("married." ++ a ++ "." ++ b)

-- | 条件：@a@ 不是 @b@ 的姻亲（@isInLawOf@ 的 Not 对偶）。
lacksInLawOf :: String -> String -> Condition
lacksInLawOf a b = Not ("inLaw." ++ a ++ "." ++ b)

-- | 条件：@who@ 有至少一名姻亲（派生 @inLaw.<who>.*@）。
everInLaw :: String -> Condition
everInLaw who = Exists [ Match ("inLaw." ++ who ++ ".Other") ]

-- | 条件：@who@ 无任何姻亲叶（@everInLaw@ 的 Absent 对偶）。
neverInLaw :: String -> Condition
neverInLaw who = Absent [ Match ("inLaw." ++ who ++ ".Other") ]
