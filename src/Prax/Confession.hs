-- | 坦白与赦免（规格 @docs/specs/2026-07-12-v32-confession.md@）。
-- 标记转换，永不删除；坦白经普通传闻通道自我牵连；赦免是可拒绝的第二方授予；
-- 赦免者的耐心是他们所知道的（按 regarder、凭记忆永久、由八卦与坦白同样喂养）。
module Prax.Confession
  ( confess
  , absolve
  , incorrigible
  ) where

import           Prax.Db (isVariable, pathNames, tokens, tokensToSentence)
import           Prax.Sym (intern)
import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Types (Action, Outcome (..), action, authoredPatClash)
import           Prax.Derive (Axiom, axiom)
import           Prax.Beliefs (beliefAbout)
import           Prax.Witness (CoPresence, asRole)

segOk :: String -> Bool
segOk n = not (null n) && all (`notElem` (".!" :: String)) n

-- | 向同场听者告白 *一桩* 行为（一个标记绑定）；听者可赦免。
confess :: String -> String -> CoPresence -> String -> String -> String -> Action
confess kind verb copresence markPat depositPat label
  | not (segOk kind) =
      error ("confess: mark kind " ++ show kind ++ " must be a single path segment")
  | not (segOk verb) =
      error ("confess: discharge verb " ++ show verb ++ " must be a single path segment")
  | (v : _) <- authoredPatClash ["H", "Hearer", "Actor"] (pathNames markPat) =
      error ("confess: mark pattern " ++ show markPat ++ " reserves variable " ++ show v
             ++ " (the mark's hearer slot / the action's own roles, or the Prax"
             ++ " namespace)")
  | (v : _) <- authoredPatClash ["Hearer"] (pathNames depositPat) =
      error ("confess: deposit pattern " ++ show depositPat ++ " reserves variable "
             ++ show v ++ " (the confession's own audience role, or the Prax namespace)")
  | (v : _) <- ungroundable =
      error ("confess: deposit pattern " ++ show depositPat ++ " variable " ++ show v
             ++ " is not grounded by the mark (only Actor, H, and " ++ show markPat
             ++ "'s own variables are available) -- an ungroundable deposit would"
             ++ " insert a variable-bearing fact")
  | otherwise = action label conds outs
  where
    liedPath      = "Actor." ++ kind ++ ".H." ++ markPat
    confessedPath = "Actor." ++ verb ++ ".H." ++ markPat
    groundedVars  = "Actor" : "H" : filter isVariable (pathNames markPat)
    ungroundable  = [ v | v <- filter isVariable (pathNames depositPat)
                        , v `notElem` groundedVars ]
    conds = Match liedPath
          : asRole "Hearer" copresence
         ++ [ Neq "Hearer" "Actor" ]
    outs  = [ Delete liedPath
            , Insert confessedPath
            , Insert (beliefAbout "Hearer" depositPat ++ ".heard.Actor") ]

-- | 给予赦免：为该主体插入世界的击败者（通常清除恶名站队）。
absolve :: String -> String -> String -> String -> Action
absolve defeater pat incLabel label
  | not (segOk defeater) || not (segOk incLabel) =
      error ("absolve: defeater/label must be single path segments: "
             ++ show (defeater, incLabel))
  | (v : _) <- authoredPatClash ["Actor"] (pathNames pat) =
      error ("absolve: event pattern " ++ show pat ++ " reserves variable " ++ show v)
  | otherwise = case filter isVariable (pathNames pat) of
      [] -> error ("absolve: event pattern " ++ show pat
                   ++ " names no one (the FIRST variable is the confessor)")
      (confessor : _) -> action label
        [ Match (beliefAbout "Actor" pat ++ ".heard." ++ confessor)
        , Neq "Actor" confessor
        , Not ("regards.Actor." ++ confessor ++ "." ++ incLabel)
        , Not (defeater ++ "." ++ confessor) ]
        [ Insert (defeater ++ "." ++ confessor) ]

-- | 耐心即知识：信徒在重复冒犯后 regard 冒犯者为不可救药。
incorrigible :: String -> Int -> String -> Axiom
incorrigible pat k label
  | not (segOk label) =
      error ("incorrigible: label " ++ show label ++ " must be a single path segment")
  | (v : _) <- authoredPatClash [] (pathNames pat) =
      error ("incorrigible: pattern " ++ show pat ++ " reserves variable " ++ show v
             ++ " -- the Prax namespace is reserved for the axiom's own machinery")
  | otherwise = case filter isVariable (pathNames pat) of
      [] -> error ("incorrigible: pattern " ++ show pat ++ " names no offender")
      [_] -> error ("incorrigible: pattern " ++ show pat
                    ++ " has no deed variables to count (a single-variable pattern"
                    ++ " admits only one possible instance; a k > 1 threshold could"
                    ++ " never fire, and k <= 1 needs no threshold at all)")
      (offender : rest)
        | (v : _) <- [ d | d <- witnessNames, d `elem` (offender : rest) ] ->
            error ("incorrigible: pattern " ++ show pat ++ " variable " ++ show v
                   ++ " collides with the outer witness-naming convention"
                   ++ " (a deed variable named <name>0 shadowing another"
                   ++ " variable named <name>)")
        | otherwise -> axiom
            [ Match ("PraxW.believes." ++ witnessPat)
            , Subquery "PraxDs" rest [ Match ("PraxW.believes." ++ pat) ]
            , Count "PraxN" "PraxDs"
            , Cmp Gte "PraxN" (show k) ]
            [ "regards.PraxW." ++ offender ++ "." ++ label ]
        where
          witnessNames = map (++ "0") rest
          witnessPat = tokensToSentence
            [ (intern (if name `elem` rest then name ++ "0" else name), op)
            | (name, op) <- tokens pat ]
