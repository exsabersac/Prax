-- | 亲属：基事实 + 派生闭包（规格 §2）。婚姻移动成员——折叠的回报浓缩为一行。
module Prax.Kin
  ( kinAxioms
  , wed
  , succession
  ) where

import           Prax.Query (Condition (..))
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
