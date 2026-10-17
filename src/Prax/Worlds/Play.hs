-- | 场景创作戏剧世界（`prax play` / `prax flow`）。

module Prax.Worlds.Play
  ( playScript
  , playWorld
  , playerName
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types
import           Prax.Core (adjustScore, setBond, warmth)
import           Prax.Emotion (feelToward, pleased)
import           Prax.Script

-- | 玩家是诗人 Marcus。
playerName :: String
playerName = "marcus"

-- | 整集作为剧本。
playScript :: Script
playScript = Script
  { scriptStart = "confidence"
  , scriptCast =
      [ player "marcus"
      , member "artus"
      , member "cassia" `wanting` [ Want [ Match (deadSentence "artus") ] 100 ]
      ]
  , scriptScenes = [ confidence, banquet ]
  }

-- Act I — Cassia lets Marcus in on the plot; that opens the way to the banquet.
confidence :: Scene
confidence = (scene "confidence")
  { sceneOpening = "A quiet portico. Cassia draws Marcus aside."
  , sceneBeats =
      [ quip "cassia" "[Actor]: confide the plot against artus to marcus"
          [ Not "confided" ]
          [ Insert "confided"
          , Insert "marcusKnows"
          , adjustScore "marcus" "cassia" warmth 5 "sharedASecret" ]
      ]
  , sceneJunctions =
      [ goto "toBanquet" "banquet" [ Match "confided" ] ]
  }

-- Act II — the poisoning plays out; whoever acts first fixes the ending.
banquet :: Scene
banquet = (scene "banquet")
  { sceneOpening = "The banquet hall. Artus reclines, oblivious, wine in hand."
  , sceneBeats =
      [ quip "cassia" "[Actor]: slip poison into artus's cup"
          [ Not (deadSentence "artus"), Absent [ Match "foiled" ] ]
          [ Insert "poisoned.artus.byCassia"
          , Insert (deadSentence "artus") ]

      , quip "marcus" "[Actor]: warn artus that cassia means to kill him"
          [ Match "marcusKnows", Not (deadSentence "artus"), Absent [ Match "foiled" ] ]
          [ Insert "foiled"
          , adjustScore "artus" "marcus" warmth 30 "savedMyLife"
          , feelToward "artus" pleased "marcus" ]

      , quip "marcus" "[Actor]: poison artus with your own hand"
          [ Match "marcusKnows", Not (deadSentence "artus"), Absent [ Match "foiled" ] ]
          [ Insert "poisoned.artus.byMarcus"
          , Insert (deadSentence "artus") ]

      -- Romance: warm to the conspirator you now share a secret with (orthogonal
      -- to the killing — it neither foils nor causes it).
      , quip "marcus" "[Actor]: warm to cassia's charms"
          [ Match "marcusKnows", Not "bond.marcus.cassia!lovers" ]
          [ setBond "marcus" "cassia" "lovers"
          , adjustScore "marcus" "cassia" warmth 15 "sweptUp"
          , feelToward "marcus" pleased "cassia" ]
      ]
  , sceneJunctions =
      [ ending "betrayal"   [ Match "poisoned.artus.byCassia" ]
      , ending "loyalty"    [ Match "foiled" ]
      , ending "complicity" [ Match "poisoned.artus.byMarcus" ]
      ]
  }

-- | 已编译、可运行的世界。
playWorld :: PraxState
playWorld = compile playScript
