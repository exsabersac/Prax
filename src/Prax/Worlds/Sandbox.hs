-- | 轻量可玩沙盒世界：把节庆门禁 + factionStanding 的磨坊审判 / 教会异端 /
-- 婚入磨坊 / 债务买沉默弧收成独立世界（非 Village）。Village / GoldenDrive
-- 金标准不动；本模块演示已有 API 的可跑闭环，并以轻量 wants 驱动 NPC 自选节拍。

module Prax.Worlds.Sandbox
  ( sandboxWorld
  , playerName
  , sandboxAxioms
  , sandboxDesires
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters, setDesires, setSchedule)
import           Prax.Derive (Axiom)
import           Prax.Deontic (obligedClose)
import           Prax.Faction
  ( joins, factionStanding, appointLeader, isMember, isLeader, lacksMember )
import           Prax.Kin (kinAxioms)
import           Prax.Schedule (festival, duringFestival, outsideFestival)
import           Prax.Debt (owe, settle, lacksOwes, owes)

-- | 你是磨坊成员——可获知、控告、放逐；旁观教会弧与沉默债。玩家槽无 want。
playerName :: String
playerName = "you"

-- | 磨坊贼案站队 + 教会异端站队 + 亲属对称。
sandboxAxioms :: [Axiom]
sandboxAxioms =
  [ factionStanding "stole.Culprit.Victim" "thief"
  , factionStanding "blasphemed.Culprit.Victim" "heretic"
  ] ++ kinAxioms

-- | 命名欲望词汇：磨坊正义 / 教会审查 / 婚入磨坊 / 买沉默与撕毁协议。
sandboxDesires :: [Desire]
sandboxDesires =
  [ Desire "seeks-theft-truth"
      (Want [ Match "Owner.believes.stole.bob.carol" ] 6)
  , Desire "punishes-thief"
      (Want [ Match "denounced.Owner.bob" ] 8)
  , Desire "wants-exile-bob"
      (Want [ Match "exiled.bob" ] 12)
  , Desire "seeks-heresy-truth"
      (Want [ Match "Owner.believes.blasphemed.eve.gale" ] 6)
  , Desire "punishes-heretic"
      (Want [ Match "censured.Owner.eve" ] 8)
  , Desire "wants-exile-eve"
      (Want [ Match "exiled.eve" ] 12)
  , Desire "joins-mill"
      (Want [ Match "member.Owner!mill" ] 10)
  , Desire "buys-ira-silence"
      (Want [ Match "debt.ira.bob.favor" ] 14)
  , Desire "breaks-silence-deal"
      (Want [ Match "revoked.Owner.bob" ] 10)
  ]

millJustice :: [String]
millJustice = ["seeks-theft-truth", "punishes-thief", "wants-exile-bob"]

churchJustice :: [String]
churchJustice = ["seeks-heresy-truth", "punishes-heretic", "wants-exile-eve"]

iraJustice :: [String]
iraJustice = millJustice ++ ["breaks-silence-deal"]

-- 丰收节窗内控告 / 审查；窗外获知与放逐。
harvestFestival :: ScheduleRule
harvestFestival = festival "harvest" 3 1 []

-- 无动机者与玩家空档可等待，避免自由跑空白。
presenceP :: Practice
presenceP = practice
  { practiceId   = "presence"
  , practiceName = "waiting out the harvest"
  , roles        = []
  , actions =
      [ action "[Actor]: Wait a moment" [] [] ]
  }

-- | 磨坊审判：窗外获知 → 窗内控告（门禁于 regard，且无未结清沉默债）→ 窗外放逐。
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
          , lacksOwes "Actor" "bob" "favor"
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

-- | 债务买沉默 × 磨坊正义：贼在窗外向已站队证人买人情封口；
-- 债权人可撕毁协议（settle + revoked 叶），之后窗内可再控告。
millSilenceP :: Practice
millSilenceP = practice
  { practiceId   = "millSilence"
  , practiceName = "buying silence about the mill theft"
  , roles        = []
  , actions =
      [ action "[Actor]: buy [Creditor]'s silence about the theft"
          [ outsideFestival "harvest"
          , Match "regards.Creditor.Actor.thief"
          , lacksOwes "Creditor" "Actor" "favor"
          , Not "denounced.Creditor.Actor"
          , Not "revoked.Creditor.Actor"
          , Neq "Actor" "Creditor" ]
          (owe "Creditor" "Actor" "favor")
      , action "[Actor]: tear up [Debtor]'s silence deal"
          [ owes "Actor" "Debtor" "favor"
          , Not "revoked.Actor.Debtor" ]
          (settle "Actor" "Debtor" "favor"
            ++ [ Insert "revoked.Actor.Debtor" ])
      , action "[Actor]: repay [Creditor] for keeping silent"
          [ owes "Creditor" "Actor" "favor"
          , Not "revoked.Creditor.Actor" ]
          (settle "Creditor" "Actor" "favor")
      ]
  }

-- Cast: village-shaped names for narrative parity with Spec fixtures;
-- not the shipped Village world. Player has no wants; NPCs hold vocabulary desires.
-- ira is the mill witness bob tries to buy silence from (parallel to carol/dave justice).
cast :: [Character]
cast =
  [ character playerName
  , (character "bob")   { charDesires = ["buys-ira-silence"] }
  , (character "carol") { charDesires = millJustice }
  , (character "dave")  { charDesires = millJustice }
  , (character "fran")  { charDesires = "joins-mill" : millJustice }
  , character "eve"
  , (character "gale")  { charDesires = churchJustice }
  , (character "priest") { charDesires = churchJustice }
  , (character "ira")   { charDesires = iraJustice }
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
  , joins "ira" "mill"
  , appointLeader "priest" "church"
  , Insert "practice.presence"
  , Insert "practice.millTribunal"
  , Insert "practice.churchHeresy"
  , Insert "practice.millWed"
  , Insert "practice.millSilence"
  -- Outsider negatives already hold belief without regard (demo seeds).
  , Insert "eve.believes.stole.bob.carol"
  , Insert "bob.believes.blasphemed.eve.gale"
  ]

-- | 已调度、带 wants、可跑的沙盒世界。
sandboxWorld :: PraxState
sandboxWorld =
  setAxioms (obligedClose sandboxAxioms)
    (foldl (flip performOutcome) withPractices setup)
  where
    withPractices =
      setDesires sandboxDesires
        (setCharacters cast
          (definePractices
             [presenceP, millTribunalP, churchHeresyP, millWedP, millSilenceP]
             (setSchedule [harvestFestival] emptyState)))
