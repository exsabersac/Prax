-- | 轻量可玩沙盒世界：把节庆门禁 + factionStanding 的磨坊审判 / 教会异端 /
-- 婚入磨坊弧收成独立世界（非 Village）。Village / GoldenDrive 金标准不动；
-- 本模块仅演示已有 API 的可跑闭环。

module Prax.Worlds.Sandbox
  ( sandboxWorld
  , playerName
  , sandboxAxioms
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters, setSchedule)
import           Prax.Derive (Axiom)
import           Prax.Deontic (obligedClose)
import           Prax.Faction
  ( joins, factionStanding, appointLeader, isMember, isLeader, lacksMember )
import           Prax.Kin (kinAxioms)
import           Prax.Schedule (festival, duringFestival, outsideFestival)

-- | 你是磨坊成员——可获知、控告、放逐；旁观教会弧。
playerName :: String
playerName = "you"

-- | 磨坊贼案站队 + 教会异端站队 + 亲属对称。
sandboxAxioms :: [Axiom]
sandboxAxioms =
  [ factionStanding "stole.Culprit.Victim" "thief"
  , factionStanding "blasphemed.Culprit.Victim" "heretic"
  ] ++ kinAxioms

-- 丰收节窗内控告 / 审查；窗外获知与放逐。
harvestFestival :: ScheduleRule
harvestFestival = festival "harvest" 3 1 []

-- | 磨坊审判：窗外获知 → 窗内控告（门禁于 regard）→ 窗外放逐。
millTribunalP :: Practice
millTribunalP = practice
  { practiceId   = "millTribunal"
  , practiceName = "the mill holds tribunal at harvest"
  , roles        = []
  , actions =
      [ action "[Actor]: learn of the theft"
          [ outsideFestival "harvest"
          , isMember "Actor" "mill"
          , Not "Actor.believes.stole.bob.carol" ]
          [ Insert "Actor.believes.stole.bob.carol" ]
      , action "[Actor]: denounce the thief"
          [ duringFestival "harvest"
          , Match "regards.Actor.bob.thief"
          , Not "denounced.Actor.bob" ]
          [ Insert "denounced.Actor.bob" ]
      , action "[Actor]: exile the thief"
          [ outsideFestival "harvest"
          , Match "denounced.Actor.bob"
          , Not "exiled.bob" ]
          [ Insert "exiled.bob" ]
      ]
  }

-- | 教会异端：窗外听闻 → 窗内审查 → 窗外仅领袖放逐。
churchHeresyP :: Practice
churchHeresyP = practice
  { practiceId   = "churchHeresy"
  , practiceName = "the church tries heresy around harvest"
  , roles        = []
  , actions =
      [ action "[Actor]: hear the blasphemy"
          [ outsideFestival "harvest"
          , isMember "Actor" "church"
          , Not "Actor.believes.blasphemed.eve.gale" ]
          [ Insert "Actor.believes.blasphemed.eve.gale" ]
      , action "[Actor]: censure the heretic"
          [ duringFestival "harvest"
          , Match "regards.Actor.eve.heretic"
          , Not "censured.Actor.eve" ]
          [ Insert "censured.Actor.eve" ]
      , action "[Actor]: exile the heretic"
          [ outsideFestival "harvest"
          , isLeader "Actor" "church"
          , Match "censured.Actor.eve"
          , Not "exiled.eve" ]
          [ Insert "exiled.eve" ]
      ]
  }

-- | 婚入磨坊：非磨坊成员嫁给磨坊配偶 → 主成员切换，打开 factionStanding。
millWedP :: Practice
millWedP = practice
  { practiceId   = "millWed"
  , practiceName = "weddings that move allegiance into the mill"
  , roles        = []
  , actions =
      [ action "[Actor]: wed into the mill beside [Spouse]"
          [ isMember "Spouse" "mill"
          , lacksMember "Actor" "mill"
          , Not "married.Actor.Spouse"
          , Neq "Actor" "Spouse" ]
          [ Insert "married.Actor.Spouse"
          , Insert "member.Actor!mill" ]
      ]
  }

-- Cast: village-shaped names for narrative parity with Spec fixtures;
-- not the shipped Village world.
cast :: [Character]
cast =
  [ character playerName
  , character "bob"
  , character "carol"
  , character "dave"
  , character "fran"
  , character "eve"
  , character "gale"
  , character "priest"
  ]

setup :: [Outcome]
setup =
  [ joins "bob" "guild"
  , joins "carol" "mill"
  , joins "dave" "mill"
  , joins playerName "mill"
  , joins "fran" "guild"
  , joins "eve" "outsiders"
  , joins "gale" "church"
  , joins "priest" "church"
  , appointLeader "priest" "church"
  , Insert "practice.millTribunal"
  , Insert "practice.churchHeresy"
  , Insert "practice.millWed"
  -- Outsider negatives already hold belief without regard (demo seeds).
  , Insert "eve.believes.stole.bob.carol"
  , Insert "bob.believes.blasphemed.eve.gale"
  ]

-- | 已调度、可跑的沙盒世界。
sandboxWorld :: PraxState
sandboxWorld =
  setAxioms (obligedClose sandboxAxioms)
    (foldl (flip performOutcome) withPractices setup)
  where
    withPractices =
      setCharacters cast
        (definePractices [millTribunalP, churchHeresyP, millWedP]
           (setSchedule [harvestFestival] emptyState))
