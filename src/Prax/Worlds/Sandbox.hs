-- | 轻量可玩沙盒世界：节庆门禁 + factionStanding 的磨坊审判 / 教会异端 /
-- 婚入磨坊 / 债务买沉默 / 双节庆错峰市集喊冤 / 受害方叛逃和解 /
-- 沉默×叛逃×节庆复合门禁 / 臭名+愤怒市集声援 /
-- 站队胁迫招供（Coerce×factionStanding，默认未激活）（非 Village）。
-- Village / GoldenDrive 金标准不动；以轻量 wants 驱动 NPC 自选节拍。

module Prax.Worlds.Sandbox
  ( sandboxWorld
  , playerName
  , sandboxAxioms
  , sandboxDesires
  , millJustice
  , churchJustice
  , iraJustice
  , millCry
  , squeezeDesireName
  , fearsBrandName
  , activateSqueeze
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, setAxioms, setCharacters, setDesires, setSchedule)
import           Prax.Derive (Axiom)
import           Prax.Deontic (obligedClose)
import           Prax.Faction
  ( joins, factionStanding, appointLeader, isMember, isLeader, lacksMember
  , affiliate )
import           Prax.Kin (kinAxioms)
import           Prax.Schedule (festival, duringFestival, outsideFestival)
import           Prax.Debt (owe, settle, lacksOwes, owes)
import           Prax.Repute (notoriety, isNotorious)
import           Prax.Emotion (feelToward, angry, feelingToward)
import           Prax.Coerce (Coercion (..), coerce)

-- | 你是磨坊成员——可获知、控告、放逐；旁观教会弧与沉默债。玩家槽无 want。
playerName :: String
playerName = "you"

-- | 磨坊贼案站队 + 教会异端站队 + 亲属对称。
sandboxAxioms :: [Axiom]
sandboxAxioms =
  [ factionStanding "stole.Culprit.Victim" "thief"
  , factionStanding "blasphemed.Culprit.Victim" "heretic"
  , notoriety "thief" 2   -- ≥2 磨坊站队 → notorious.bob.thief，打开市集声援
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
  , Desire "cries-theft-at-market"
      (Want [ Match "cried.Owner.bob" ] 7)
  , Desire "flees-mill"
      (Want [ Match "fled.Owner" ] 9)
  , Desire "returns-to-mill"
      (Want [ Match "reconciled.Owner" ] 11)
  , Desire "rallies-against-thief"
      (Want [ Match "rallied.Owner.bob" ] 9)
  , squeezeDesire
  , fearsBrandDesire
  ]

millJustice :: [String]
millJustice = ["seeks-theft-truth", "punishes-thief", "wants-exile-bob"]

churchJustice :: [String]
churchJustice = ["seeks-heresy-truth", "punishes-heretic", "wants-exile-eve"]

iraJustice :: [String]
iraJustice = millJustice ++ ["breaks-silence-deal"]

-- 丰收节窗内控告 / 审查；窗外获知与放逐。周期 3、持续 1。
harvestFestival :: ScheduleRule
harvestFestival = festival "harvest" 3 1 []

-- 市集节与丰收错峰：周期 4、持续 1 → 回合 3 仅 harvest，回合 4 仅 market。
marketFestival :: ScheduleRule
marketFestival = festival "market" 4 1 []

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
          [ Insert "Actor.believes.stole.bob.carol"
          , feelToward "Actor" angry "bob" ]
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

-- | 市集喊冤：仅在 market 窗内、已站队磨坊成员可公开喊出贼名（与 harvest 控告错峰）。
marketCryP :: Practice
marketCryP = practice
  { practiceId   = "marketCry"
  , practiceName = "crying theft at the market booth"
  , roles        = []
  , actions =
      [ action "[Actor]: cry the theft at market"
          [ duringFestival "market"
          , Match "regards.Actor.bob.thief"
          , Not "cried.Actor.bob" ]
          [ Insert "cried.Actor.bob" ]
      ]
  }

-- | 臭名声援：market 窗内、已愤怒且 bob 达臭名阈值的角色可公开声援（旁观者介入）。
-- 主阵容默认不挂 rallies want（免搅 cry 金轨迹）；reputeSeed 覆盖后自由跑。
millRallyP :: Practice
millRallyP = practice
  { practiceId   = "millRally"
  , practiceName = "rallying the square against a notorious thief"
  , roles        = []
  , actions =
      [ action "[Actor]: rally the square against the thief"
          [ duringFestival "market"
          , isNotorious "bob" "thief"
          , feelingToward "Actor" angry "bob"
          , Not "rallied.Actor.bob" ]
          [ Insert "rallied.Actor.bob" ]
      ]
  }

-- | 受害方叛逃与和解：离开磨坊溶解 factionStanding；再加入恢复站队与门禁。
millAllegianceP :: Practice
millAllegianceP = practice
  { practiceId   = "millAllegiance"
  , practiceName = "abandoning and returning to the mill"
  , roles        = []
  , actions =
      [ action "[Actor]: abandon the mill for the guild"
          [ isMember "Actor" "mill"
          , Match "Actor.believes.stole.bob.Actor"
          , Not "fled.Actor" ]
          [ Insert "fled.Actor"
          , joins "Actor" "guild" ]
      , action "[Actor]: return to the mill in reconciliation"
          [ Match "fled.Actor"
          , lacksMember "Actor" "mill"
          , Not "reconciled.Actor" ]
          [ Insert "reconciled.Actor"
          , joins "Actor" "mill" ]
      ]
  }


-- | 站队胁迫招供：已 factionStanding 站队的磨坊成员可胁迫贼招供；违抗则烙印。
-- 默认不 Insert practice.millSqueeze（免搅既有金轨迹）；coerceSeed / activateSqueeze 激活。
millSqueezeCoercion :: Coercion
millSqueezeCoercion = Coercion
  { coId            = "squeeze"
  , coVictim        = "Mark"
  , coTrigger       =
      [ Match "regards.Actor.Mark.thief"
      , isMember "Actor" "mill"
      ]
  , coThreatenLabel = "[Actor]: squeeze [Mark] for a confession"
  , coDemandLabel   = "[Actor]: confess the theft to [E]"
  , coDemand        = [ Insert "confessed.Actor" ]
  , coPunishLabel   = "[Actor]: brand [Mark] as unrepentant"
  , coPunishWhen    = [ Not "branded.Mark" ]
  , coPunishOuts    = [ Insert "branded.Mark" ]
  , coKernel        = [ Match "branded.Mark" ]
  , coWeight        = 10
  , coThreatLasts     = Nothing
  , coComplianceLasts = Nothing
  }

squeezeDesire :: Desire
squeezeActs :: [Action]
(squeezeDesire, squeezeActs) = coerce millSqueezeCoercion

squeezeDesireName :: String
squeezeDesireName = desireName squeezeDesire

fearsBrandName :: String
fearsBrandName = "fears-brand"

fearsBrandDesire :: Desire
fearsBrandDesire =
  Desire fearsBrandName (Want [ Match "branded.Owner" ] (-12))

millSqueezeP :: Practice
millSqueezeP = practice
  { practiceId   = "millSqueeze"
  , practiceName = "squeezing a regarded thief for confession"
  , roles        = []
  , actions      = squeezeActs
  }

-- | 激活站队胁迫实践（供 coerceSeed / 逐步测）：Insert practice + 不改角色 want。
activateSqueeze :: PraxState -> PraxState
activateSqueeze = performOutcome (Insert "practice.millSqueeze")

-- Cast: village-shaped names for narrative parity with Spec fixtures;
-- not the shipped Village world. Player has no wants; NPCs hold vocabulary desires.
-- ira is the mill witness bob tries to buy silence from (parallel to carol/dave justice).
-- mill 证人另挂市集喊冤 want（权重 7 < 控告 8：harvest 窗优先控告，market 窗才喊）。
millCry :: [String]
millCry = millJustice ++ ["cries-theft-at-market"]

iraCry :: [String]
iraCry = iraJustice ++ ["cries-theft-at-market"]

cast :: [Character]
cast =
  [ character playerName
  , (character "bob")   { charDesires = ["buys-ira-silence"] }
  , (character "carol") { charDesires = millCry }
  , (character "dave")  { charDesires = millCry }
  , (character "fran")  { charDesires = "joins-mill" : millCry }
  , character "eve"
  , (character "gale")  { charDesires = churchJustice }
  , (character "priest") { charDesires = churchJustice }
  , (character "ira")   { charDesires = iraCry }
  -- kyle：仅次级归属磨坊，主效忠 guild；信念种子不派生站队（affiliate 负例）。
  , (character "kyle")  { charDesires = [] }
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
  , joins "kyle" "guild"
  , affiliate "kyle" "mill"
  , appointLeader "priest" "church"
  , Insert "practice.presence"
  , Insert "practice.millTribunal"
  , Insert "practice.churchHeresy"
  , Insert "practice.millWed"
  , Insert "practice.millSilence"
  , Insert "practice.marketCry"
  , Insert "practice.millAllegiance"
  , Insert "practice.millRally"
  -- Outsider / affiliate negatives already hold belief without regard (demo seeds).
  , Insert "eve.believes.stole.bob.carol"
  , Insert "bob.believes.blasphemed.eve.gale"
  , Insert "kyle.believes.stole.bob.carol"
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
             [ presenceP, millTribunalP, churchHeresyP, millWedP, millSilenceP
             , marketCryP, millAllegianceP, millRallyP, millSqueezeP ]
             (setSchedule [harvestFestival, marketFestival] emptyState)))
