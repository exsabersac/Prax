-- | 派系：一条成员脊骨（规格 docs/specs/2026-07-12-v31-faction-kin.md §1）。
-- 成员是基、单槽事实——@member.\<who\>!\<faction\>@——且 @!@ 即是语义：加入、叛逃、婚入
-- 都是同一排他覆盖。基 @allied.*@ 事实仍是合法词汇（并非每个联盟都是成员）；'comrades'
-- 派生额外的。
module Prax.Faction
  ( memberPath
  , joins
  , comrades
  , factionStanding
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..), authoredPatClash)
import           Prax.Derive (Axiom, axiom)
import           Prax.Db (isVariable, pathNames)

-- | @member.\<who\>!\<faction\>@（单槽：主要效忠）。
memberPath :: String -> String -> String
memberPath who faction
  | bad who || bad faction =
      error ("Faction: names must be nonempty single path segments (no '.' or '!'): "
             ++ show (who, faction))
  | otherwise = "member." ++ who ++ "!" ++ faction
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 加入（或叛逃至，或嫁入）派系：一次排他覆盖。
joins :: String -> String -> Outcome
joins who faction = Insert (memberPath who faction)

-- | 共享成员派生同盟——宿怨旧基事实的一般化。
comrades :: Axiom
comrades = axiom
  [ Match "member.X!F", Match "member.Y!F", Neq "X" "Y" ]
  [ "allied.X.Y" ]

-- | 面向 K-纪律世界的信念门禁派系声望：对同志的冒犯触发派系内站队。
factionStanding :: String -> String -> Axiom
factionStanding pat label =
  case filter isVariable (pathNames pat) of
    (offender : victim : _)
      | (bad : _) <- authoredPatClash [] (pathNames pat) ->
          error ("factionStanding: pattern " ++ show pat ++ " uses " ++ show bad
                 ++ " -- the Prax namespace is reserved for the axiom's own"
                 ++ " join variables")
      | otherwise -> axiom
          [ Match ("PraxW.believes." ++ pat)
          , Match ("member." ++ victim ++ "!PraxF")
          , Match "member.PraxW!PraxF"
          , Neq "PraxW" offender ]
          [ "regards.PraxW." ++ offender ++ "." ++ label ]
    _ -> error ("factionStanding: pattern " ++ show pat
                ++ " must name an offender and a victim variable, in that order")
