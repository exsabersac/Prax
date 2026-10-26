-- | 轻量可玩沙盒世界：节庆门禁 + factionStanding 的磨坊审判 / 教会异端 /
-- 婚入磨坊 / 债务买沉默 / 双节庆错峰市集喊冤 / 受害方叛逃和解 /
-- 沉默×叛逃×节庆复合门禁 / 臭名+愤怒市集声援 /
-- 站队胁迫招供（Coerce×factionStanding，默认未激活）/
-- 教会异端×磨坊正义同场双压（bob 双轨，默认未激活）/
-- 教会异端×沉默债（审查门禁 lacksOwes）/
-- 教会胁迫悔罪（Coerce×heretic 站队，默认未激活）/
-- 烙印游街（branded / brandedHeretic 叶门禁，默认未激活；want 词汇已备、默认不挂阵容）（非 Village）。
-- Village / GoldenDrive 金标准不动；以轻量 wants 驱动 NPC 自选节拍。

module Prax.Worlds.Sandbox
  ( sandboxWorld
  , playerName
  , sandboxAxioms
  , sandboxDesires
  , millJustice
  , churchJustice
  , bobHeresyJustice
  , iraJustice
  , millCry
  , squeezeDesireName
  , fearsBrandName
  , activateSqueeze
  , activateChurchBob
  , inquisitDesireName
  , fearsBrandHereticName
  , activateInquisit
  , activateParade
  , activateChurchParade
  , paradeDesireName
  , churchParadeDesireName
  , rallyDesireName
  , cryDesireName
  , fleeDesireName
  , returnDesireName
  , millSilenceDesireName
  , millBreakSilenceDesireName
  , churchSilenceDesireName
  , churchBreakSilenceDesireName
  , seeksTheftDesireName
  , punishesThiefDesireName
  , exileBobDesireName
  , seeksHeresyDesireName
  , punishesHereticDesireName
  , exileEveDesireName
  , seeksBobHeresyDesireName
  , punishesBobHereticDesireName
  , joinsMillDesireName
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
import           Prax.Debt (owe, settle, lacksOwes, owes, lacksRevoked)
import           Prax.Repute (notoriety, isNotorious)
import           Prax.Emotion (feelToward, angry, feelingToward)
import           Prax.Coerce (Coercion (..), coerce,
                              isBranded, lacksBranded,
                              isBrandedHeretic, lacksBrandedHeretic)

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

-- | 命名欲望词汇：磨坊正义 / 教会审查 / bob 异端双压 / 婚入磨坊 / 买沉默与撕毁 /
-- 教会异端沉默 / 教会胁迫悔罪 / 烙印游街（默认不挂阵容）。
sandboxDesires :: [Desire]
sandboxDesires =
  [ Desire seeksTheftDesireName
      (Want [ Match "Owner.believes.stole.bob.carol" ] 6)
  , Desire punishesThiefDesireName
      (Want [ Match "denounced.Owner.bob" ] 8)
  , Desire exileBobDesireName
      (Want [ Match "exiled.bob" ] 12)
  , Desire seeksHeresyDesireName
      (Want [ Match "Owner.believes.blasphemed.eve.gale" ] 6)
  , Desire punishesHereticDesireName
      (Want [ Match "censured.Owner.eve" ] 8)
  , Desire exileEveDesireName
      (Want [ Match "exiled.eve" ] 12)
  , Desire joinsMillDesireName
      (Want [ Match "member.Owner!mill" ] 10)
  , Desire millSilenceDesireName
      (Want [ Match "debt.ira.bob.favor" ] 14)
  , Desire millBreakSilenceDesireName
      (Want [ Match "revoked.Owner.bob" ] 10)
  , Desire cryDesireName
      (Want [ Match "cried.Owner.bob" ] 7)
  , Desire fleeDesireName
      (Want [ Match "fled.Owner" ] 9)
  , Desire returnDesireName
      (Want [ Match "reconciled.Owner" ] 11)
  , Desire rallyDesireName
      (Want [ Match "rallied.Owner.bob" ] 9)
  , squeezeDesire
  , fearsBrandDesire
  , Desire seeksBobHeresyDesireName
      (Want [ Match "Owner.believes.blasphemed.bob.gale" ] 6)
  , Desire punishesBobHereticDesireName
      -- 权重 9 > eve 审查 8 / 磨坊控告 8：双压种子上优先钉 bob 异端轨
      (Want [ Match "censured.Owner.bob" ] 9)
  , Desire churchSilenceDesireName
      -- eve 向已站队教会证人买人情封口（异端轨）
      (Want [ Match "debt.gale.Owner.church-favor" ] 14)
  , Desire churchBreakSilenceDesireName
      (Want [ Match "revoked.Owner.eve" ] 10)
  , inquisitDesire
  , fearsBrandHereticDesire
  -- 烙印游街 want（默认阵容不挂，免搅金轨迹；paradeSeed / Spec 覆盖）
  , Desire paradeDesireName
      (Want [ Match "paraded.Owner.bob" ] 10)
  , Desire churchParadeDesireName
      (Want [ Match "paraded.Owner.bob" ] 10)
  ]

millJustice :: [String]
millJustice = [seeksTheftDesireName, punishesThiefDesireName, exileBobDesireName]

churchJustice :: [String]
churchJustice = [seeksHeresyDesireName, punishesHereticDesireName, exileEveDesireName]

-- | 教会对 bob 的异端正义（复用 wants-exile-bob → 共享 exiled.bob）。
bobHeresyJustice :: [String]
bobHeresyJustice = [seeksBobHeresyDesireName, punishesBobHereticDesireName, exileBobDesireName]

iraJustice :: [String]
iraJustice = millJustice ++ [millBreakSilenceDesireName]

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
          , lacksOwes "Actor" "eve" "church-favor"
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

-- | 教会对 bob 的异端轨：与磨坊贼案共享 exiled.bob，形成同场双压竞速。
-- 默认不 Insert practice.churchBobHeresy（免搅既有 eve 异端金轨迹）；
-- activateChurchBob / dualPressureSeed 激活。
churchBobHeresyP :: Practice
churchBobHeresyP = practice
  { practiceId   = "churchBobHeresy"
  , practiceName = "the church tries bob's heresy around harvest"
  , roles        = []
  , actions =
      [ action "[Actor]: hear of bob's heresy"
          [ outsideFestival "harvest"
          , isMember "Actor" "church"
          , Not "Actor.believes.blasphemed.bob.gale" ]
          [ Insert "Actor.believes.blasphemed.bob.gale" ]
      , action "[Actor]: censure bob for heresy"
          [ duringFestival "harvest"
          , Match "regards.Actor.bob.heretic"
          , lacksOwes "Actor" "bob" "church-favor"
          , Not "censured.Actor.bob" ]
          [ Insert "censured.Actor.bob" ]
      , action "[Actor]: banish bob for heresy"
          [ outsideFestival "harvest"
          , isLeader "Actor" "church"
          , Match "censured.Actor.bob"
          , Not "exiled.bob" ]
          [ Insert "exiled.bob" ]
      ]
  }

-- | 激活教会-bob 异端实践（供 dualPressureSeed / 逐步测）。
activateChurchBob :: PraxState -> PraxState
activateChurchBob = performOutcome (Insert "practice.churchBobHeresy")

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
          , lacksRevoked "Creditor" "Actor"
          , Neq "Actor" "Creditor" ]
          (owe "Creditor" "Actor" "favor")
      , action "[Actor]: tear up [Debtor]'s silence deal"
          [ owes "Actor" "Debtor" "favor"
          , lacksRevoked "Actor" "Debtor" ]
          (settle "Actor" "Debtor" "favor"
            ++ [ Insert "revoked.Actor.Debtor" ])
      , action "[Actor]: repay [Creditor] for keeping silent"
          [ owes "Creditor" "Actor" "favor"
          , lacksRevoked "Creditor" "Actor" ]
          (settle "Creditor" "Actor" "favor")
      ]
  }

-- | 教会异端×沉默债：异端在窗外向已站队教会证人买人情封口；
-- 债权人可撕毁协议，之后窗内审查门禁（lacksOwes）再开。
-- 与磨坊沉默同形，但触发 regards.*.heretic、堵住 censure 而非 denounce。
churchSilenceP :: Practice
churchSilenceP = practice
  { practiceId   = "churchSilence"
  , practiceName = "buying silence about church heresy"
  , roles        = []
  , actions =
      [ action "[Actor]: buy [Creditor]'s silence about the heresy"
          [ outsideFestival "harvest"
          , Match "regards.Creditor.Actor.heretic"
          , lacksOwes "Creditor" "Actor" "church-favor"
          , Not "censured.Creditor.Actor"
          , lacksRevoked "Creditor" "Actor"
          , Neq "Actor" "Creditor" ]
          (owe "Creditor" "Actor" "church-favor")
      , action "[Actor]: tear up [Debtor]'s heresy silence deal"
          [ owes "Actor" "Debtor" "church-favor"
          , lacksRevoked "Actor" "Debtor" ]
          (settle "Actor" "Debtor" "church-favor"
            ++ [ Insert "revoked.Actor.Debtor" ])
      , action "[Actor]: repay [Creditor] for keeping heresy silent"
          [ owes "Creditor" "Actor" "church-favor"
          , lacksRevoked "Creditor" "Actor" ]
          (settle "Creditor" "Actor" "church-favor")
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
  , coPunishWhen    = [ lacksBranded "Mark" ]
  , coPunishOuts    = [ Insert "branded.Mark" ]
  , coKernel        = [ isBranded "Mark" ]
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
  Desire fearsBrandName (Want [ isBranded "Owner" ] (-12))

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

-- | 教会胁迫悔罪：已 factionStanding 站队的教会成员可胁迫异端悔罪；违抗则烙异端印。
-- 默认不 Insert practice.churchInquisit（免搅既有金轨迹）；inquisitSeed / activateInquisit 激活。
-- 与 churchBobHeresy / churchHeresy 交错：窗外可胁，窗内仍可审查，窗外领袖放逐。
churchInquisitCoercion :: Coercion
churchInquisitCoercion = Coercion
  { coId            = "inquisit"
  , coVictim        = "Mark"
  , coTrigger       =
      [ Match "regards.Actor.Mark.heretic"
      , isMember "Actor" "church"
      ]
  , coThreatenLabel = "[Actor]: squeeze [Mark] for a recantation"
  , coDemandLabel   = "[Actor]: recant the heresy to [E]"
  , coDemand        = [ Insert "recanted.Actor" ]
  , coPunishLabel   = "[Actor]: brand [Mark] as unrepentant heretic"
  , coPunishWhen    = [ lacksBrandedHeretic "Mark" ]
  , coPunishOuts    = [ Insert "brandedHeretic.Mark" ]
  , coKernel        = [ isBrandedHeretic "Mark" ]
  , coWeight        = 10
  , coThreatLasts     = Nothing
  , coComplianceLasts = Nothing
  }

inquisitDesire :: Desire
inquisitActs :: [Action]
(inquisitDesire, inquisitActs) = coerce churchInquisitCoercion

inquisitDesireName :: String
inquisitDesireName = desireName inquisitDesire

fearsBrandHereticName :: String
fearsBrandHereticName = "fears-brand-heretic"

fearsBrandHereticDesire :: Desire
fearsBrandHereticDesire =
  Desire fearsBrandHereticName (Want [ isBrandedHeretic "Owner" ] (-12))

churchInquisitP :: Practice
churchInquisitP = practice
  { practiceId   = "churchInquisit"
  , practiceName = "squeezing a regarded heretic for recantation"
  , roles        = []
  , actions      = inquisitActs
  }

-- | 激活教会胁迫悔罪实践（供 inquisitSeed / 逐步测）。
activateInquisit :: PraxState -> PraxState
activateInquisit = performOutcome (Insert "practice.churchInquisit")


-- | 磨坊烙印游街 want 名（默认阵容不挂）。
seeksTheftDesireName :: String
seeksTheftDesireName = "seeks-theft-truth"

punishesThiefDesireName :: String
punishesThiefDesireName = "punishes-thief"

exileBobDesireName :: String
exileBobDesireName = "wants-exile-bob"

seeksHeresyDesireName :: String
seeksHeresyDesireName = "seeks-heresy-truth"

punishesHereticDesireName :: String
punishesHereticDesireName = "punishes-heretic"

exileEveDesireName :: String
exileEveDesireName = "wants-exile-eve"

seeksBobHeresyDesireName :: String
seeksBobHeresyDesireName = "seeks-bob-heresy"

punishesBobHereticDesireName :: String
punishesBobHereticDesireName = "punishes-bob-heretic"

joinsMillDesireName :: String
joinsMillDesireName = "joins-mill"

millSilenceDesireName :: String
millSilenceDesireName = "buys-ira-silence"

millBreakSilenceDesireName :: String
millBreakSilenceDesireName = "breaks-silence-deal"

churchSilenceDesireName :: String
churchSilenceDesireName = "buys-church-silence"

churchBreakSilenceDesireName :: String
churchBreakSilenceDesireName = "breaks-church-silence"

fleeDesireName :: String
fleeDesireName = "flees-mill"

returnDesireName :: String
returnDesireName = "returns-to-mill"

cryDesireName :: String
cryDesireName = "cries-theft-at-market"

rallyDesireName :: String
rallyDesireName = "rallies-against-thief"

paradeDesireName :: String
paradeDesireName = "parades-branded-thief"

-- | 教会异端烙印游街 want 名（默认阵容不挂；inquisit 轨钉 bob）。
churchParadeDesireName :: String
churchParadeDesireName = "parades-branded-heretic"

-- | 烙印游街：已站队磨坊成员可对已 branded 的贼公开游街（叠 branded 叶，非新原语）。
-- 默认不 Insert practice.millBrandParade；activateParade / Spec 激活。
-- Want 见 paradeDesireName；主阵容默认不挂（免搅金轨迹）。
millBrandParadeP :: Practice
millBrandParadeP = practice
  { practiceId   = "millBrandParade"
  , practiceName = "parading a branded thief through the square"
  , roles        = []
  , actions =
      [ action "[Actor]: parade [T] as branded thief"
          [ Match "regards.Actor.T.thief"
          , isMember "Actor" "mill"
          , isBranded "T"
          , Not "paraded.Actor.T" ]
          [ Insert "paraded.Actor.T" ]
      ]
  }

-- | 激活烙印游街实践（供 Spec / 交叉弧）。
activateParade :: PraxState -> PraxState
activateParade = performOutcome (Insert "practice.millBrandParade")

-- | 异端烙印游街：已站队教会成员可对已 brandedHeretic 公开游街（叠 paraded 叶）。
-- 默认不 Insert practice.churchBrandParade；activateChurchParade / Spec 激活。
-- Want 见 churchParadeDesireName；主阵容默认不挂。
churchBrandParadeP :: Practice
churchBrandParadeP = practice
  { practiceId   = "churchBrandParade"
  , practiceName = "parading a branded heretic through the square"
  , roles        = []
  , actions =
      [ action "[Actor]: parade [T] as branded heretic"
          [ Match "regards.Actor.T.heretic"
          , isMember "Actor" "church"
          , isBrandedHeretic "T"
          , Not "paraded.Actor.T" ]
          [ Insert "paraded.Actor.T" ]
      ]
  }

-- | 激活异端烙印游街实践（供 Spec / 交叉弧）。
activateChurchParade :: PraxState -> PraxState
activateChurchParade = performOutcome (Insert "practice.churchBrandParade")

-- Cast: village-shaped names for narrative parity with Spec fixtures;
-- not the shipped Village world. Player has no wants; NPCs hold vocabulary desires.
-- ira is the mill witness bob tries to buy silence from (parallel to carol/dave justice).
-- mill 证人另挂市集喊冤 want（权重 7 < 控告 8：harvest 窗优先控告，market 窗才喊）。
millCry :: [String]
millCry = millJustice ++ [cryDesireName]

iraCry :: [String]
iraCry = iraJustice ++ [cryDesireName]

cast :: [Character]
cast =
  [ character playerName
  , (character "bob")   { charDesires = ["buys-ira-silence"] }
  , (character "carol") { charDesires = millCry }
  , (character "dave")  { charDesires = millCry }
  , (character "fran")  { charDesires = joinsMillDesireName : millCry }
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
  , Insert "practice.churchSilence"
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
             [ presenceP, millTribunalP, churchHeresyP, churchBobHeresyP
             , millWedP, millSilenceP, churchSilenceP, marketCryP
             , millAllegianceP, millRallyP, millSqueezeP, churchInquisitP
             , millBrandParadeP, churchBrandParadeP ]
             (setSchedule [harvestFestival, marketFestival] emptyState)))
