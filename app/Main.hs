-- | Interactive CLI for the storyworlds: round-robin turns, NPCs act
-- autonomously, and on the player's turn a numbered action menu is offered
-- (Versu's \"act / more\" interface). Choose a world on the command line:
-- @prax@ (the bar, default) or @prax intrigue@ (the dramatic episode).
module Main (main) where

import           Data.List (isSuffixOf)
import           Data.Maybe (listToMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.ByteString.Lazy.Char8 as BLC
import           System.Environment (getArgs)
import           System.Exit (exitFailure)
import           System.IO (BufferMode (NoBuffering), hPutStrLn, hSetBuffering, isEOF, stderr, stdout)
import           Text.Read (readMaybe)

import           Prax.Db (Bindings, unify, valToString)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Engine (performAction)
import           Prax.Planner (candidateActions)
import           Prax.Loop (advance, npcAct)
import           Prax.Stress
import           Prax.Persist (saveState, loadState, formatVersion)
import           Prax.TypeCheck (TypeError (..), typeCheck)
import           Prax.Script (Script, compile, flowChart, scriptPlayer, currentScenePath)
import           Prax.Script.Json (encodeScript, loadScript)
import qualified Prax.Worlds.Bar as Bar
import qualified Prax.Worlds.Intrigue as Intrigue
import qualified Prax.Worlds.Play as Play
import qualified Prax.Worlds.Feud as Feud
import qualified Prax.Worlds.Audience as Audience
import qualified Prax.Worlds.Village as Village
import           Prax.Chronicle (askChronicle, summarize)
import           Prax.Host (practiceNames, castNames, livingCast, deadCast, membersOf, affiliatesOf, leadersOf, regardsOf, regardsToward, factionsNamed)

-- How many plies of lookahead the NPCs use.
lookaheadDepth :: Int
lookaheadDepth = 2

-- Where an in-game save is written / resumed from.
saveFile :: FilePath
saveFile = "prax.save"

-- A world by name, for both playing and stress-testing.
worldNamed :: [String] -> (String, PraxState, String)
worldNamed ("intrigue" : _) = ("Intrigue (Rome)", Intrigue.intrigueWorld, Intrigue.playerName)
worldNamed ("play" : _)     = ("the conspiracy (a play)", Play.playWorld, Play.playerName)
worldNamed ("dm" : _)       = ("the bar, and you direct it", Bar.barDirectorWorld, Bar.directorName)
worldNamed ("feud" : _)     = ("the feud (emergent sandbox)", Feud.feudWorld, Feud.playerName)
worldNamed ("audience" : _) = ("the royal audience", Audience.audienceWorld, Audience.playerName)
worldNamed ("village" : _)  = ("the village", Village.villageWorld, Village.playerName)
worldNamed _                = ("a night at the bar", Bar.barWorld, Bar.playerName)

-- @prax stress [world]@ — a QA report over many random all-AI playthroughs.
runStress :: [String] -> IO ()
runStress args = do
  let (name, world, _) = worldNamed args
      r = stressTest 200 50 (Just currentScenePath) world
  putStrLn ("stress-testing " ++ name ++ " — 200 random runs, cap 50 turns")
  putStrLn ("  endings:   " ++ show (Map.toList (srEndings r)))
  putStrLn ("  coverage:  " ++ show (Set.size (srCoverage r)) ++ " distinct actions fired")
  if Map.null (srVisited r)
    then pure ()
    else putStrLn ("  scenes:    " ++ show (Map.toList (srVisited r)) ++ " (runs visiting each)")
  putStrLn ("  dead ends: " ++ show (srDeadEnds r))
  putStrLn ("  no ending: " ++ show (srNoEnding r) ++ " / " ++ show (srRuns r) ++ " runs")

-- @prax chronicle [world] [query...]@ — Tier-3 salience surface over beliefs/standing.
-- With no query, prints the full summarize; otherwise joins remaining args as one askChronicle query.
runChronicle :: [String] -> IO ()
runChronicle args = do
  let (worldArgs, queryArgs) = case args of
        (w : qs) | w `elem` ["village","bar","feud","intrigue","play","dm","audience"]
                 -> ([w], qs)
        qs       -> ([], qs)
      (_, world, _) = worldNamed worldArgs
  if null queryArgs
    then mapM_ putStrLn (summarize world)
    else mapM_ putStrLn (askChronicle world (unwords queryArgs))

-- @prax worlds@ — enumerate built-in storyworld names (documented CLI surface).
-- | List top-level practice ids for a named built-in world.
runPractices :: [String] -> IO ()
runPractices ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (practiceNames st)

-- | List cast names for a named built-in world (@living@ = survivors only).
runCast :: [String] -> IO ()
runCast ("living" : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (livingCast st)
runCast ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (castNames st)

-- | List dead cast names for a named built-in world.
runDead :: [String] -> IO ()
runDead ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (deadCast st)

-- | List members of a faction: @prax members <faction> <world>@.
runMembers :: [String] -> IO ()
runMembers (faction : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (membersOf st faction)
runMembers _ = putStrLn "usage: prax members <faction> <world>"

-- | List affiliates of a character: @prax affiliates <who> <world>@.
runAffiliates :: [String] -> IO ()
runAffiliates (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (affiliatesOf st who)
runAffiliates _ = putStrLn "usage: prax affiliates <who> <world>"

-- | List leaders of a faction: @prax leaders <faction> <world>@.
runLeaders :: [String] -> IO ()
runLeaders (faction : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (leadersOf st faction)
runLeaders _ = putStrLn "usage: prax leaders <faction> <world>"

-- | List faction names present in a world's closed view.
runFactions :: [String] -> IO ()
runFactions ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (factionsNamed st)

-- | List regards: @prax regards <who> <world>@ (outgoing);
-- @prax regards toward <target> <world>@ (incoming leaves).
runRegards :: [String] -> IO ()
runRegards ("toward" : target : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (regardsToward st target)
runRegards (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (regardsOf st who)
runRegards _ = putStrLn "usage: prax regards <who> <world> | prax regards toward <target> <world>"

runWorlds :: IO ()
runWorlds = mapM_ putStrLn
  [ "bar        — a night at the bar (default)"
  , "dm         — the bar, and you direct it"
  , "village    — the village"
  , "feud       — the feud (emergent sandbox)"
  , "intrigue   — Intrigue (Rome)"
  , "play       — the conspiracy (a play)"
  , "audience   — the royal audience"
  ]

-- @prax check [world]@ — static well-formedness report for a world.
runCheck :: [String] -> IO ()
runCheck args = do
  let (name, world, _) = worldNamed args
  case typeCheck world of
    [] -> putStrLn ("well-formed: " ++ name)
    es -> do putStrLn (name ++ " — " ++ show (length es) ++ " problem(s):")
             mapM_ (putStrLn . ("  - " ++) . describe) es
  where
    describe (UnboundVar w v s) =
      "unbound variable " ++ v ++ " in \"" ++ s ++ "\" (" ++ w ++ ")"
    describe (CardinalityClash slot) =
      "relation " ++ slot ++ " is used both single-valued (!) and multi-valued (.)"
    describe (UndefinedRef w n) =
      "undefined reference " ++ n ++ " (" ++ w ++ ")"
    describe (SortConflict w d) =
      "sort conflict at " ++ w ++ ": " ++ d
    describe (ReservedFamily fam w s) =
      "reserved family " ++ fam ++ ": " ++ show s ++ " (" ++ w
        ++ ") -- engine-owned; authored code may not touch it"
    describe SeedlessDraw =
      "draw used but the die is unseeded: seed it with Prax.Engine.seedDie when building the world"
    describe (DeadCondition w s) =
      "dead condition \"" ++ s ++ "\" (" ++ w
        ++ "): no action, initial fact, or axiom head can ever produce a match"
    describe (DeonticUnclosed s) =
      "unclosed obligation rule \"" ++ s ++ "\": this world can invoke an"
        ++ " obligation but did not declare its □-closure -- wrap its axioms in"
        ++ " Prax.Deontic.obligedClose"
    describe (CoercionUnmotivated n) =
      "unmotivated coercion \"" ++ n ++ "\": a threat deposits this punitive"
        ++ " belief but no such desire is registered, so the threat is silently"
        ++ " inert -- register it with Prax.Engine.setDesires (hold it or not is"
        ++ " the genuine/bluff choice)"

-- CLI usage (also shown by @prax help@ / @-h@ / @--help@).
usageText :: String
usageText = unlines
  [ "prax — interactive storyworlds"
  , ""
  , "Play a world:"
  , "  prax                      bar (default)"
  , "  prax village|feud|intrigue|play|dm|audience"
  , "  prax <world> resume       continue from prax.save"
  , ""
  , "Tools:"
  , "  prax check [world]                 static well-formedness"
  , "  prax stress [world]                stress-test trajectories"
  , "  prax chronicle [world] [query…]    read-only salience / events"
  , "  prax worlds                        list built-in storyworlds"
  , "  prax version                       persist format / build label"
  , "  prax practices <world>             list top-level practice ids"
  , "  prax cast [living] <world>         list cast (or living only)"
  , "  prax dead <world>                  list dead cast names"
  , "  prax members <faction> <world>     list faction members"
  , "  prax affiliates <who> <world>      list character affiliates"
  , "  prax leaders <faction> <world>     list faction leaders"
  , "  prax factions <world>              list faction names in view"
  , "  prax regards <who>|<toward t> <world>  list regards leaves"
  , "  prax flow [file.json]              scene flowchart"
  , "  prax dump-play                     emit built-in play JSON"
  , "  prax play <file.json>              play a script file"
  , "  prax help | -h | --help            this message"
  ]


main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  args <- getArgs
  case args of
    ("help":_)        -> putStr usageText
    ("-h":_)          -> putStr usageText
    ("--help":_)      -> putStr usageText
    ("stress" : rest) -> runStress rest
    ("check" : rest)  -> runCheck rest
    ("chronicle" : rest) -> runChronicle rest
    ("worlds" : _)    -> runWorlds
    ("version" : _)   -> putStrLn formatVersion
    ("practices" : ws) -> runPractices ws
    ("cast" : ws)      -> runCast ws
    ("dead" : ws)      -> runDead ws
    ("members" : ws)   -> runMembers ws
    ("affiliates" : ws) -> runAffiliates ws
    ("leaders" : ws)   -> runLeaders ws
    ("factions" : ws)  -> runFactions ws
    ("regards" : ws)   -> runRegards ws
    ("dump-play" : _) -> BLC.putStrLn (encodeScript Play.playScript)
    ("flow" : rest)   -> do scr <- scriptFrom rest; putStr (flowChart scr)
    ("play" : file : _) | ".json" `isSuffixOf` file -> playFile file
    _                 -> play args

-- A play-script from a @.json@ file argument if given, else the built-in one.
scriptFrom :: [String] -> IO Script
scriptFrom args = case [ f | f <- args, ".json" `isSuffixOf` f ] of
  (f : _) -> loadOrDie f
  []      -> pure Play.playScript

-- Load a play-script or exit loudly (no silent fallback).
loadOrDie :: FilePath -> IO Script
loadOrDie f = do
  r <- loadScript f
  case r of
    Right s -> pure s
    Left e  -> do hPutStrLn stderr ("could not load " ++ f ++ ": " ++ e)
                  exitFailure

-- Play a script loaded from a file.
playFile :: FilePath -> IO ()
playFile file = do
  scr <- loadOrDie file
  let title = "prax — " ++ file
  putStrLn (replicate (length title + 4) '=')
  putStrLn ("  " ++ title)
  putStrLn (replicate (length title + 4) '=')
  loop (scriptPlayer scr) (compile scr)

play :: [String] -> IO ()
play args = do
  let (title, blurb, world, player) = case args of
        ("intrigue" : _) ->
          ( "prax — Intrigue (Rome)"
          , "You are Marcus, the poet. The others act on their own."
          , Intrigue.intrigueWorld, Intrigue.playerName )
        ("play" : _) ->
          ( "prax — the conspiracy (a play)"
          , "You are Marcus. The scene plays out around you (see `prax flow`)."
          , Play.playWorld, Play.playerName )
        ("dm" : _) ->
          ( "prax — you direct the evening"
          , "You are the drama manager: nudge the autonomous cast (ada, bex, cai)."
          , Bar.barDirectorWorld, Bar.directorName )
        ("feud" : _) ->
          ( "prax — the feud (emergent sandbox)"
          , "You are Alice. One wrong, and a feud assembles itself — make amends to dissolve it."
          , Feud.feudWorld, Feud.playerName )
        ("audience" : _) ->
          ( "prax — the royal audience"
          , "You are the envoy. Flatter the king, then petition — before the moment (or the Duke) passes."
          , Audience.audienceWorld, Audience.playerName )
        ("village" : _) ->
          ( "prax — the village"
          , "You are a villager. What you see — and what you miss — decides what you can do."
          , Village.villageWorld, Village.playerName )
        _ ->
          ( "prax — a night at the bar"
          , "You are 'you'. Others act on their own."
          , Bar.barWorld, Bar.playerName )
  putStrLn (replicate (length title + 4) '=')
  putStrLn ("  " ++ title)
  putStrLn (replicate (length title + 4) '=')
  putStrLn blurb
  world' <- if "resume" `elem` args
              then do putStrLn ("(resumed from " ++ saveFile ++ ")")
                      loadState saveFile world
              else pure world
  loop player world'

-- The first reached ending, if any (an @ending.\<key\>@ fact).
endingOf :: PraxState -> Maybe String
endingOf st =
  listToMaybe [ e | b <- unify "ending.E" (db st) Map.empty
                  , Just e <- [valToString <$> Map.lookup (intern "E") b] ]

loop :: String -> PraxState -> IO ()
loop player st =
  case endingOf st of
    Just e -> do
      putStrLn ""
      putStrLn "=============================="
      putStrLn ("  THE END — " ++ e)
      putStrLn "=============================="
    Nothing -> do
      let (actor, st1) = advance st
      if charName actor == player
        then playerTurn player st st1 actor   -- `st` is the pre-advance save point
        else do
          let (mga, st2) = npcAct lookaheadDepth actor st1
          case mga of
            Just ga -> putStrLn ("  " ++ gaLabel ga)
            Nothing -> pure ()   -- idle NPCs stay quiet
          loop player st2

-- @savePoint@ is the state *before* advancing to the player, so resuming from it
-- replays the advance and lands back on the player's turn.
playerTurn :: String -> PraxState -> PraxState -> Character -> IO ()
playerTurn player savePoint st actor = do
  putStrLn ""
  putStrLn "-------------------- scene --------------------"
  putStr (renderScene st)
  let acts = playerActions st actor
  putStrLn ("Your move (" ++ charName actor ++ "):")
  mapM_ (\(i, a) -> putStrLn ("  " ++ show i ++ ") " ++ gaLabel a))
        (zip [1 :: Int ..] acts)
  putStrLn "  m) wait and let others act"
  putStrLn "  s) save    q) quit"
  choice <- prompt
  case choice of
    Quit -> putStrLn "Bye."
    Wait -> loop player st
    Save -> do
      saveState saveFile savePoint
      putStrLn ("(saved to " ++ saveFile ++ ")")
      playerTurn player savePoint st actor
    Pick i
      | i >= 1 && i <= length acts -> do
          let ga = acts !! (i - 1)
          putStrLn ("> " ++ gaLabel ga)
          loop player (performAction st ga)
      | otherwise -> do
          putStrLn "No such option."
          playerTurn player savePoint st actor

-- The player already has `m` to pass, so pure no-op actions (empty outcomes,
-- e.g. the world's "Wait a moment") are noise in the menu. They remain
-- available to NPCs, who need a "do nothing" affordance to avoid being forced
-- to act. Hide them from the player only. Uses 'candidateActions' so a
-- practice-bound player (e.g. the drama manager) is offered only the affordances
-- of its bound practice.
playerActions :: PraxState -> Character -> [GroundedAction]
playerActions st actor = filter (not . isNoOp) (candidateActions st actor)
  where
    isNoOp ga = case Map.lookup (gaPracticeId ga) (practiceDefs st) of
      Just def | (a : _) <- filter ((== gaActionId ga) . actionName) (actions def)
                 -> null (actionOutcomes a)
      _          -> False

data Choice = Quit | Wait | Save | Pick Int

prompt :: IO Choice
prompt = do
  putStr "> "
  eof <- isEOF
  if eof
    then pure Quit
    else do
      line <- getLine
      pure $ case words line of
        ["q"] -> Quit
        ["s"] -> Save
        ["m"] -> Wait
        [tok] | Just n <- readMaybe tok -> Pick n
        _     -> Pick (-1)

-- Scene rendering ---------------------------------------------------------------

renderScene :: PraxState -> String
renderScene st =
  unlines (map ("  - " ++)
            (act ++ locations ++ orders ++ held ++ tipsy ++ bell
              ++ deaths ++ grudges ++ shuns ++ regardsL ++ notorietyL ++ atonedL
              ++ chats ++ pending ++ trouble
              ++ arcs ++ beliefs ++ moods ++ feelings))
  where
    -- read the *closed* view, so derived facts (e.g. propagated enmity) are shown
    rows sentence = unify sentence (readView st) Map.empty
    val k b = valToString <$> Map.lookup (intern k) (b :: Bindings)

    -- derived (or authored) social structure in the emergent sandbox
    grudges =
      [ who ++ " resents " ++ target
      | b <- rows "resents.Who.Target"
      , Just who <- [val "Who" b], Just target <- [val "Target" b] ]
    shuns =
      [ who ++ " is shunning " ++ target
      | b <- rows "shunned.Who.Target"
      , Just who <- [val "Who" b], Just target <- [val "Target" b] ]

    -- derived standing (reputation) and its public consequences
    regardsL =
      [ who ++ " regards " ++ target ++ " as a " ++ lbl
      | b <- rows "regards.Who.Target.Label"
      , Just who <- [val "Who" b], Just target <- [val "Target" b]
      , Just lbl <- [val "Label" b] ]
    notorietyL =
      [ who ++ " is notorious as a " ++ lbl
      | b <- rows "notorious.Who.Label"
      , Just who <- [val "Who" b], Just lbl <- [val "Label" b] ]
    atonedL =
      [ who ++ " has made amends"
      | b <- rows "atoned.Who"
      , Just who <- [val "Who" b] ]

    -- the current act, in a play-script world
    act =
      [ "the scene: " ++ s
      | b <- rows (currentScenePath ++ ".S"), Just s <- [val "S" b] ]

    locations =
      [ who ++ " is at the " ++ place
      | b <- rows "practice.world.world.at.Who!Place"
      , Just who <- [val "Who" b], Just place <- [val "Place" b] ]

    orders =
      [ who ++ " is waiting for a " ++ bev
      | b <- rows "practice.tendBar.Pl.Bartender.customer.Who!order!Bev"
      , Just who <- [val "Who" b], Just bev <- [val "Bev" b] ]

    held =
      [ who ++ " has a " ++ bev ++ " in hand"
      | b <- rows "practice.tendBar.Pl.Bartender.customer.Who!beverage!Bev"
      , Just who <- [val "Who" b], Just bev <- [val "Bev" b] ]

    tipsy =
      [ who ++ " is looking tipsy"
      | b <- rows "person.Who.tipsy", Just who <- [val "Who" b] ]

    bell =
      [ "the bar is busy — " ++ b' ++ " rang the bell"
      | b <- rows "practice.tendBar.Pl.Bartender.rang", Just b' <- [val "Bartender" b] ]

    -- who has died / been removed from play
    deaths =
      [ who ++ " is dead"
      | b <- rows "dead.Who", Just who <- [val "Who" b] ]

    -- ongoing conversations and their current topic
    chats =
      [ a ++ " and " ++ bb ++ " are chatting (" ++ topic ++ ")"
      | b <- rows "practice.converse.A.B.topic.T"
      , Just a <- [val "A" b], Just bb <- [val "B" b], Just topic <- [val "T" b] ]

    -- pending reactions / obligations
    pending =
      [ gd ++ " hasn't returned " ++ gr ++ "'s greeting"
      | b <- rows "practice.respondGreet.Gr.Gd"
      , Just gr <- [val "Gr" b], Just gd <- [val "Gd" b] ]
      ++
      [ p ++ " owes " ++ bt ++ " a tip"
      | b <- rows "practice.settleUp.P.B"
      , Just p <- [val "P" b], Just bt <- [val "B" b] ]

    -- norm violations and disapproval
    trouble =
      [ w ++ " broke a norm (" ++ n ++ ")"
      | b <- rows "violated.W.N", Just w <- [val "W" b], Just n <- [val "N" b] ]
      ++
      [ ol ++ " disapproves of " ++ off
      | b <- rows "practice.disapproval.Off.Ol"
      , Just off <- [val "Off" b], Just ol <- [val "Ol" b] ]

    -- a character's inner arc (their evening's through-line)
    arcPhrase "hopeful"   = "hopeful"
    arcPhrase "belonging" = "at home here"
    arcPhrase "lonely"    = "out of place"
    arcPhrase s           = s
    arcs =
      [ who ++ " feels " ++ arcPhrase stage
      | b <- rows "Who.arc!Stage"
      , Just who <- [val "Who" b]
      , who `elem` map charName (characters st)  -- a real character's arc, not a practice.arc.<who> instance
      , Just stage <- [val "Stage" b] ]

    -- beliefs that diverge from the truth (here: believed grudges)
    beliefs =
      [ who ++ " believes " ++ subj ++ " resents them"
      | b <- rows "Who.believes.resentedBy.Subj.yes"
      , Just who <- [val "Who" b], Just subj <- [val "Subj" b] ]

    moods =
      [ who ++ " feels " ++ feeling ++ " toward " ++ target
      | b <- rows "Who.feels.Feeling.toward.Target"
      , Just who <- [val "Who" b], Just feeling <- [val "Feeling" b]
      , Just target <- [val "Target" b] ]

    feelings =
      [ a ++ "'s warmth toward " ++ bb ++ ": " ++ score
      | b <- rows "A.relationship.B.warmth.score!N"
      , Just a <- [val "A" b], Just bb <- [val "B" b], Just score <- [val "N" b] ]
