-- | 派系：一条成员脊骨（规格 docs/specs/2026-07-12-v31-faction-kin.md §1）。
-- 成员是基、单槽事实——@member.\<who\>!\<faction\>@——且 @!@ 即是语义：加入、叛逃、婚入
-- 都是同一排他覆盖。基 @allied.*@ 事实仍是合法词汇（并非每个联盟都是成员）；'comrades'
-- 派生额外的。v65：'affiliate' 是 *多值* 次级归属（@affiliate.who.faction@），与主效忠并列——
-- 清偿「多重归属」而不拆掉 @member.!@ 脊骨。v69：'appointLeader' 排他派系领导（@leads.<faction>!<who>@），职衔以外领导。
module Prax.Faction
  ( memberPath
  , joins
  , comrades
  , factionStanding
  , affiliate
  , unaffiliate
  , affiliates
  , lacksAffiliate
  , affiliateComrades
  , appointLeader
  , deposeLeader
  , isLeader
  , lacksLeader
  , transferLeadership
  , isMember
  , lacksMember
  , regardsAs
  , lacksRegard
  , everRegards
  , neverRegards
  , everMember
  , neverMember
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), action, authoredPatClash)
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

-- | 次级归属路径（多值，非排他）：@affiliate.<who>.<faction>@。
affiliatePath :: String -> String -> String
affiliatePath who faction
  | bad who || bad faction =
      error ("affiliate: names must be nonempty single path segments: "
             ++ show (who, faction))
  | otherwise = "affiliate." ++ who ++ "." ++ faction
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 加入次级归属（可多重；不覆盖 'joins' 主效忠）。
affiliate :: String -> String -> Outcome
affiliate who faction = Insert (affiliatePath who faction)

-- | 解除一次次级归属。
unaffiliate :: String -> String -> Outcome
unaffiliate who faction = Delete (affiliatePath who faction)

-- | 条件：@who@ 次级归属于 @faction@。
affiliates :: String -> String -> Condition
affiliates who faction = Match (affiliatePath who faction)

-- | 条件：@who@ 无次级归属 @faction@。
lacksAffiliate :: String -> String -> Condition
lacksAffiliate who faction = Not (affiliatePath who faction)

-- | 共享次级归属亦派生同盟（与主成员 'comrades' 并列）。
affiliateComrades :: Axiom
affiliateComrades = axiom
  [ Match "affiliate.X.F", Match "affiliate.Y.F", Neq "X" "Y" ]
  [ "allied.X.Y" ]

-- | 派系领导路径（排他）：@leads.<faction>!<who>@ —— 一派一首领，`!` 覆盖。
leaderPath :: String -> String -> String
leaderPath faction who
  | bad faction || bad who =
      error ("appointLeader: names must be nonempty single path segments: "
             ++ show (faction, who))
  | otherwise = "leads." ++ faction ++ "!" ++ who
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 任命 @who@ 为 @faction@ 首领（覆盖前任）。
appointLeader :: String -> String -> Outcome
appointLeader who faction = Insert (leaderPath faction who)

-- | 罢免：删除 @leads.<faction>@ 子树。
deposeLeader :: String -> Outcome
deposeLeader faction
  | null faction || any (`elem` (".!" :: String)) faction =
      error ("deposeLeader: faction " ++ show faction ++ " must be a single path segment")
  | otherwise = Delete ("leads." ++ faction)

-- | 条件：@who@ 现为 @faction@ 首领。
isLeader :: String -> String -> Condition
isLeader who faction = Match ("leads." ++ faction ++ "!" ++ who)


-- | 条件：@who@ 不是 @faction@ 的领袖。
lacksLeader :: String -> String -> Condition
lacksLeader who faction = Not (leaderPath faction who)

-- | 禅让：现任首领（Actor）将 @faction@ 领导权交给同派 @Heir@（须已有主成员）。
transferLeadership :: String -> String -> Action
transferLeadership faction label
  | null faction || any (`elem` (".!" :: String)) faction =
      error ("transferLeadership: faction " ++ show faction ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("leads." ++ faction ++ "!Actor")
      , Match ("member.Heir!" ++ faction)
      , Neq "Heir" "Actor" ]
      [ Insert ("leads." ++ faction ++ "!Heir") ]

-- | 条件：@who@ 主成员属于 @faction@。
isMember :: String -> String -> Condition
isMember who faction = Match (memberPath who faction)

-- | 条件：@who@ 非 @faction@ 主成员（@isMember@ 对偶）。
lacksMember :: String -> String -> Condition
lacksMember who faction = Not (memberPath who faction)


-- | 条件：@who@ 视 @target@ 为 @label@（@regards.<who>.<target>.<label>@）。
regardsAs :: String -> String -> String -> Condition
regardsAs who target label
  | bad who || bad target || bad label =
      error ("regardsAs: names must be nonempty single path segments: "
             ++ show (who, target, label))
  | otherwise = Match ("regards." ++ who ++ "." ++ target ++ "." ++ label)
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 条件：无该站队叶（@regardsAs@ 的 Not 对偶）。
lacksRegard :: String -> String -> String -> Condition
lacksRegard who target label
  | bad who || bad target || bad label =
      error ("lacksRegard: names must be nonempty single path segments: "
             ++ show (who, target, label))
  | otherwise = Not ("regards." ++ who ++ "." ++ target ++ "." ++ label)
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 条件：@who@ 对任何人持有任意站队标签。
everRegards :: String -> Condition
everRegards who
  | null who || any (`elem` (".!" :: String)) who =
      error ("everRegards: who " ++ show who ++ " must be a single path segment")
  | otherwise = Exists [ Match ("regards." ++ who ++ ".Target.Label") ]

-- | 条件：@who@ 对任何人无站队标签。
neverRegards :: String -> Condition
neverRegards who
  | null who || any (`elem` (".!" :: String)) who =
      error ("neverRegards: who " ++ show who ++ " must be a single path segment")
  | otherwise = Absent [ Match ("regards." ++ who ++ ".Target.Label") ]

-- | 条件：@who@ 属于任一派系（存在 @member.<who>!<Faction>@）。
everMember :: String -> Condition
everMember who = Exists [ Match ("member." ++ who ++ "!Faction") ]

-- | 条件：@who@ 不属于任何派系。
neverMember :: String -> Condition
neverMember who = Absent [ Match ("member." ++ who ++ "!Faction") ]
