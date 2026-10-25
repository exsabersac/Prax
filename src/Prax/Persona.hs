-- | 性格即行为，非目标（规格 @docs/specs/2026-07-11-v25-persona-design.md@）。
--
-- 特质是命名的（多为负）欲望包，覆盖承载者 /自身/ 行为标记——@honest@ 给每个你自己的 @lied@
-- 标记（"Prax.Deceit"）定价。承载者可做任何事：逆特质行为携带负效用，从不禁止，算术即含义
-- （「她的诚实压过恶意，恰是所写的边距」）。因为标记落入 planner 评价的同一状态，威慑无需前瞻；
-- 且因为特质欲望是命名词汇（"Prax.Minds"），/被相信的/ 气质在预测中与被相信动机对冲——知道某人诚实
-- 改变你对他们的期望，不只是他们做什么。
--
-- 目标包有意不是特质：目标是不需包的普通欲望。特质说你愿意如何行动，而非你追求什么。
-- v74：'bearFromRegard' —— 累犯站队派生特质事实（再犯入性格）。
module Prax.Persona
  ( Trait (..)
  , personaVocabulary
  , bearing
  , transparent
  , cast
  , bearFromRegard
  , hasTrait
  , lacksTrait
  , everTrait
  , neverTrait
  ) where

import           Data.List (nub, (\\))

import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Derive (Axiom, axiom)

-- | 具名的行为估值包。名必须是单段路径段（用作欲望名）。
data Trait = Trait
  { traitName    :: String
  , traitDesires :: [Desire]  -- ^ valuations over the bearer's own conduct-marks
  }
  deriving (Eq, Show)

-- | 特质列表向世界词汇贡献的欲望。重复名响亮报错。
personaVocabulary :: [Trait] -> [Desire]
personaVocabulary traits =
  case names \\ nub names of
    (d : _) -> error ("personaVocabulary: duplicate desire name " ++ show d)
    []      -> ds
  where
    ds    = concatMap traitDesires traits
    names = map desireName ds

-- | 赋予角色一种特质：他们按名持有其每个欲望。
bearing :: Trait -> Character -> Character
bearing t c = c { charDesires = charDesires c ++ map desireName (traitDesires t) }

-- | 性情写在袖口：每个角色假定持有者持有其特质欲望（透明）。
transparent :: Axiom
transparent = axiom
  [ Match "trait.M.T", Match "traitDesire.T.D", Match "character.P" ]
  [ "P.believes.desires.M.D.presumed" ]

-- | 在手写基角色上的确定性阵容装配：每名角色带上所列特质并贡献 setup 结果。
cast :: [Trait] -> [(Character, [Trait])] -> ([Character], [Outcome])
cast traits roster
  | (bad : _) <- [ n | n <- tnames, null n || any (`elem` (".!" :: String)) n ] =
      error ("cast: trait name " ++ show bad
             ++ " must be a nonempty single path segment (no '.' or '!')")
  | (dup : _) <- tnames \\ nub tnames =
      error ("cast: duplicate trait " ++ show dup)
  | (stray : _) <- [ traitName t | (_, ts) <- roster, t <- ts
                                 , traitName t `notElem` tnames ] =
      error ("cast: trait " ++ show stray ++ " is borne but not in the trait"
             ++ " list (its valuations would be silently illegible)")
  | otherwise =
      ( [ foldl (flip bearing) c ts | (c, ts) <- roster ]
      , [ Insert ("traitDesire." ++ traitName t ++ "." ++ desireName d)
        | t <- traits, d <- traitDesires t ]
        ++ [ Insert ("character." ++ charName c) | (c, _) <- roster ]
        ++ [ Insert ("trait." ++ charName c ++ "." ++ traitName t)
           | (c, ts) <- roster, t <- ts ] )
  where tnames = map traitName traits

-- | 累犯入性格：任何人将 @O@ 视为 @label@ 时，派生 @trait.O.<traitName>@。
-- 创作方可再经 'transparent' / 欲望词汇读该特质；本公理只种事实。
bearFromRegard :: String -> String -> Axiom
bearFromRegard label traitName
  | bad label || bad traitName =
      error ("bearFromRegard: label and trait must be single path segments: "
             ++ show (label, traitName))
  | otherwise = axiom
      [ Match ("regards.W.O." ++ label) ]
      [ "trait.O." ++ traitName ]
  where bad n = null n || any (`elem` (".!" :: String)) n

-- | 条件：@who@ 持有特质 @trait@。
hasTrait :: String -> String -> Condition
hasTrait who trait = Match ("trait." ++ who ++ "." ++ trait)

-- | 条件：@who@ 不持有特质 @trait@。
lacksTrait :: String -> String -> Condition
lacksTrait who trait = Not ("trait." ++ who ++ "." ++ trait)

-- | 条件：@who@ 持有任一性格叶。
everTrait :: String -> Condition
everTrait who = Exists [ Match ("trait." ++ who ++ ".Trait") ]

-- | 条件：@who@ 无任何性格叶。
neverTrait :: String -> Condition
neverTrait who = Absent [ Match ("trait." ++ who ++ ".Trait") ]
