-- | 「我的小镇」MVP 世界：Village 减法瘦叉（非 Village 开关）。
--
-- 实践：@world@（移动/稍候）+ @town@（社交四 aff）。六 aff：前往、稍候、公开帮忙、
-- 说破、转告、怀疑。主弧帮忙 A；不做 shun/stole/earnBread/market/whisper/ostracize。
-- @worldId@ = \"my-town\"。
module Prax.Worlds.MyTown
  ( myTownWorld
  , playerName
  , worldId
  , together
  , trustHelpedMe
  , trustSawHelp
  , trustHeardRumor
  ) where

import           Prax.Query (Condition (..), CmpOp (..))
import           Prax.Types
import           Prax.Engine (definePractices, defineFunctions, performOutcome,
                              setCharacters, setSchedule, seedDie)
import           Prax.Core (coreFns, adjustScore)
import           Prax.Witness (CoPresence, observable, saw)
import           Prax.Rumor (gossip)
import           Prax.Schedule (sightRule)
import           Prax.Sight (sightedWithin)

-- | 会话 / 存档用世界 id。
worldId :: String
worldId = "my-town"

-- | 玩家角色名。
playerName :: String
playerName = "you"

-- | 信任幅度（可调常量）：被帮感激。
trustHelpedMe :: Int
trustHelpedMe = 5

-- | 信任幅度：说破亲见帮忙。
trustSawHelp :: Int
trustSawHelp = 5

-- | 信任幅度：听闻未亲见后的怀疑（负向）。
trustHeardRumor :: Int
trustHeardRumor = -5

-- | 同场：共享地点。
together :: CoPresence
together =
  [ Match "practice.world.world.at.Actor!P"
  , Match "practice.world.world.at.Witness!P"
  ]

myTownSighting :: [Condition]
myTownSighting =
  [ Match "practice.world.world.at.Seer!Spot"
  , Match "practice.world.world.at.Seen!Spot"
  ]

-- | 确定性骰种子（短弧测试用）。
myTownSeed :: Integer
myTownSeed = 2026

-- Places / movement -----------------------------------------------------------

worldP :: Practice
worldP = practice
  { practiceId = "world"
  , practiceName = "小镇存在"
  , roles = ["World"]
  , actions =
      [ action "[Actor]: 前往 [Place]"
          [ Match "practice.world.World.at.Actor!OtherPlace"
          , Match "practice.world.World.connected.OtherPlace.Place" ]
          [ Insert "practice.world.World.at.Actor!Place" ]
      , action "[Actor]: 稍候片刻"
          [ Match "practice.world.World.at.Actor!Place" ]
          []
      ]
  }

-- Social town practice --------------------------------------------------------

townP :: Practice
townP = practice
  { practiceId = "town"
  , practiceName = "小镇社交"
  , roles = ["Scene"]
  , actions =
      [ -- 公开帮忙：共场；外观 helped.Actor.Beneficiary（亲见仅同场）；
        -- 受益人对帮忙者 trust(+) helpedMe。默认弧 you→carol。
        -- M6g：Actor 自证 believes.helped.Actor.Beneficiary（无 .seen；可喂 gossip）。
        observable together "helped.Actor.Beneficiary" $
        action "[Actor]: 公开帮助 [Beneficiary]"
          [ Match "practice.world.world.at.Actor!P"
          , Match "practice.world.world.at.Beneficiary!P"
          , Neq "Beneficiary" "Actor"
          , Not "didHelp.Actor.Beneficiary" ]
          [ Insert "didHelp.Actor.Beneficiary"
          , Insert "Actor.believes.helped.Actor.Beneficiary"
          , adjustScore "Beneficiary" "Actor" "trust" trustHelpedMe "helpedMe" ]

        -- 说破：须亲见帮忙，且与 Helper 共场；trust(+) sawHelp。默认证人 bob。
      , action "[Actor]: 说破看见 [Helper] 帮助了 [Beneficiary]"
          [ saw "Actor" "helped.Helper.Beneficiary"
          , Match "practice.world.world.at.Actor!P"
          , Match "practice.world.world.at.Helper!P"
          , Not "spokeUp.Actor.Helper.Beneficiary" ]
          [ Insert "spokeUp.Actor.Helper.Beneficiary"
          , adjustScore "Actor" "Helper" "trust" trustSawHelp "sawHelp" ]

        -- 转告：有证据；Hearer∉{Actor,Helper}；信任门；不向已亲见者重复；不得写 .seen。
      , gossip together
          [ Absent [ Match "Actor.relationship.Hearer.trust.score!TrustScore"
                   , Cmp Lt "TrustScore" "0" ] ]
          "helped.Helper.Beneficiary"
          "[Actor]: 转告 [Hearer]：[Helper] 帮助了 [Beneficiary]"

        -- 怀疑：共场 ∧ heard∧¬seen ∧ 未打量过；trust(-) heardRumor。
        -- M6l：heard 与 ¬seen 同绑 Beneficiary（Exists 内）；裸 Absent 在 Target 另有
        -- .seen（NPC Helper 常见）时会误杀「听闻未亲见」的那条命题。
      , action "[Actor]: 怀疑地打量 [Target]"
          [ Match "practice.world.world.at.Actor!P"
          , Match "practice.world.world.at.Target!P"
          , Neq "Target" "Actor"
          , Exists
              [ Match "Actor.believes.helped.Target.Beneficiary.heard.Src"
              , Absent [ Match "Actor.believes.helped.Target.Beneficiary.seen" ] ]
          , Not "eyed.Actor.Target" ]
          [ Insert "eyed.Actor.Target"
          , adjustScore "Actor" "Target" "trust" trustHeardRumor "heardRumor" ]
      ]
  }

-- World -----------------------------------------------------------------------

myTownWorld :: PraxState
myTownWorld =
  seedDie myTownSeed
    (foldl (flip performOutcome) base setup)
      { predictionScope = [ Or [ together, sightedWithin 2 ] ] }
  where
    roster =
      [ (character "you")
          { charWants =
              [ Want [ Match "practice.world.world.at.you!square" ] 1 ] }
      , (character "bob")
          { charWants =
              [ -- square 弱留驻；持 .seen 后 mill 权重更高
                Want [ Match "practice.world.world.at.bob!square" ] 1
                -- 主弧：亲见帮忙后愿意说破（种子 you→carol）
              , Want [ Match "spokeUp.bob.you.carol" ] 5
                -- ① 持 helped.you.carol.seen 后 Want at.mill > at.square
              , Want [ Match "bob.believes.helped.you.carol.seen"
                     , Match "practice.world.world.at.bob!mill" ] 3
                -- ② Village 式转告：想让 dana 从自己听说（≥5）
              , Want [ Match "dana.believes.helped.you.carol.heard.bob" ] 5
                -- M6c：对称转告 eve（仅钉 dana 不够）
              , Want [ Match "eve.believes.helped.you.carol.heard.bob" ] 5
                -- M6p：持 heard.carol（gale→dana）后赴 mill + eyed.bob.gale（对称 M6l）
              , Want [ Match "bob.believes.helped.gale.dana.heard.carol"
                     , Match "practice.world.world.at.bob!mill" ] 3
              , Want [ Match "eyed.bob.gale" ] 5
                -- M6r：Village 式二源听闻 → carol（≥5，对称 M6n carol→bob）
              , Want [ Match "carol.believes.helped.gale.dana.heard.bob" ] 5 ] }
      , (character "carol")
          { charWants =
              [ Want [ Match "practice.world.world.at.carol!square" ] 1
                -- M6l：持 heard.you（gale→dana）后赴 mill + eyed.carol.gale（对称 M6c）
              , Want [ Match "carol.believes.helped.gale.dana.heard.you"
                     , Match "practice.world.world.at.carol!mill" ] 3
              , Want [ Match "eyed.carol.gale" ] 5
                -- M6n：Village 式二传谣 → bob（≥5，优先于 mill=3；对称 bob→dana）
              , Want [ Match "bob.believes.helped.gale.dana.heard.carol" ] 5
                -- M6v：Village 式二源听闻 → eve（you→carol；≥5，对称 M6r bob→carol）
              , Want [ Match "eve.believes.helped.you.carol.heard.carol" ] 5 ] }
      , (character "dana")
          { charWants =
              [ Want [ Match "practice.world.world.at.dana!mill" ] 1
              , Want [ Match "eyed.dana.T" ] 5 ] }
      , (character "eve")
          { charWants =
              [ Want [ Match "practice.world.world.at.eve!mill" ] 1
                -- M6c：对称 dana 的怀疑 Want
              , Want [ Match "eyed.eve.T" ] 5
                -- M6z：Village 式再传谣 → dana（you→carol；≥5，对称 M6v carol→eve / M6r bob→carol）
              , Want [ Match "dana.believes.helped.you.carol.heard.eve" ] 5 ] }
      , (character "gale")
          { charWants =
              [ Want [ Match "practice.world.world.at.gale!mill" ] 1
                -- M6f：共场公开帮助 dana；门控 you@mill（>at.mill），
                -- 避免开局在 square 燃尽 didHelp 导致亲见落空
              , Want [ Match "practice.world.world.at.you!mill"
                     , Match "didHelp.gale.dana" ] 5 ] }
      ]
    base = setSchedule [ sightRule myTownSighting ]
             (setCharacters roster
                (defineFunctions coreFns
                   (definePractices [worldP, townP] emptyState)))
    setup =
      [ Insert "practice.town.here"
      , Insert "practice.world.world.connected.square.mill"
      , Insert "practice.world.world.connected.mill.square"
      , Insert "practice.world.world.at.you!square"
      , Insert "practice.world.world.at.bob!square"
      , Insert "practice.world.world.at.carol!square"
      , Insert "practice.world.world.at.dana!mill"
      , Insert "practice.world.world.at.eve!mill"
      , Insert "practice.world.world.at.gale!mill"
      ]
