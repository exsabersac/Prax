-- | 宿怨世界：派系与亲属的涌现派生演示。

module Prax.Worlds.Feud
  ( feudWorld
  , bigFeud
  , feudAxioms
  , playerName
  ) where

import           Prax.Query
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters)
import           Prax.Derive (Axiom, axiom)
import           Prax.Faction (joins, comrades, factionStanding)
import           Prax.Kin (kinAxioms)

-- | 你是 Alice——冒犯者。
playerName :: String
playerName = "alice"

-- Domain knowledge, authored once. Reads see the forward-chained closure.
feudAxioms :: [Axiom]
feudAxioms =
  [ axiom [ Match "allied.X.Y" ]                     [ "allied.Y.X" ]    -- alliances are mutual
  , axiom [ Match "wronged.X.Y" ]                    [ "resents.Y.X" ]   -- the wronged resent the wrongdoer
  , axiom [ Match "resents.A.B", Match "allied.A.C" ][ "resents.C.B" ]   -- the enemy of my ally is my enemy
  , comrades                                                             -- shared membership derives allied (Prax.Faction)
  , factionStanding "wronged.Offender.Victim" "feudbreaker"               -- v93: 派系内对同志之怨的信念门禁站队
  ]

-- The one place everyone shares. Affordances key off /derived/ enmity.
societyP :: Practice
societyP = practice
  { practiceId   = "society"
  , practiceName = "the company keeps its grudges"
  , roles        = ["Room"]
  , actions =
      [ -- available only to someone who resents the target — and @resents@ is
        -- almost always a derived fact, not an authored one
        action "[Actor]: shun [Target]"
          [ Match "resents.Actor.Target"
          , Neq "Actor" "Target"
          , Not "shunned.Actor.Target" ]
          [ Insert "shunned.Actor.Target" ]

        -- the wrongdoer can make amends: retracting the base wrong dissolves every
        -- resentment derived from it (defeasibility as a game move)
      , action "[Actor]: make amends with [Target]"
          [ Match "wronged.Actor.Target" ]
          [ Delete "wronged.Actor.Target" ]
      ]
  }

-- Cast -------------------------------------------------------------------------

-- Someone who acts on their grudges: wants to shun anyone they (come to) resent.
grudgeBearer :: String -> Character
grudgeBearer n = (character n)
  { charWants = [ Want [ Match ("shunned." ++ n ++ ".Target") ] 5 ] }

alice :: Character
alice = (character playerName)
  { charWants = [ Want [ Match "shunned.Other.alice" ] (-10) ] }  -- dislikes being shunned

-- | 设置沙箱：三条域规则 + 一条义务闭合。
feudWorld :: PraxState
feudWorld =
  setAxioms (feudAxioms ++ kinAxioms) (foldl (flip performOutcome) withPractices setup)
  where
    withPractices =
      setCharacters
        [ alice, grudgeBearer "bob", grudgeBearer "carol", grudgeBearer "dave"
        , grudgeBearer "esme" ]
        (definePractices [ societyP ] emptyState)
    setup =
      [ Insert "practice.society.here"
      , Insert "wronged.alice.bob"      -- the single authored grievance
      , Insert "bob.believes.wronged.alice.bob"  -- lived grievance → factionStanding feed
      , Insert "carol.believes.wronged.alice.bob"
      , Insert "dave.believes.wronged.alice.bob"
      , joins "bob" "kestrel"
      , joins "carol" "kestrel"
      , joins "dave" "kestrel"
      , joins "esme" "wren"
      ]

-- | 放大的宿怨（供规模演示\/基准）：@n@ 户。
bigFeud :: Int -> PraxState
bigFeud n =
  setAxioms feudAxioms (foldl (flip performOutcome) withPractices setup)
  where
    names = [ "a" ++ show i | i <- [1 .. n] ]
    withPractices =
      setCharacters (alice : map grudgeBearer names)
        (definePractices [ societyP ] emptyState)
    setup =
      [ Insert "practice.society.here"
      , Insert "wronged.alice.a1" ]
      ++ [ Insert ("allied.a" ++ show i ++ ".a" ++ show (i + 1)) | i <- [1 .. n - 1] ]
