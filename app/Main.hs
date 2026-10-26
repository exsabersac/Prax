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
import qualified Prax.Worlds.Sandbox as Sandbox
import           Prax.Chronicle (askChronicle, summarize)
import           Prax.Host (practiceNames, castNames, livingCast, deadCast, queryViewMatching, queryMatching, availableMatching, livingMatching, membersOf, affiliatesOf, leadersOf, regardsOf, regardsToward, factionsNamed, debtsOf, creditorsOf, debtorsOf, obligationsOf, breachesOf, feelingsOf, liesOf, chattedWithOf, traitsOf, moodsOf, bondsOf, kinOf, notoriousOf, esteemedOf, scornedOf, beliefsOf, arcsOf, agesOf, projectsOf, demandedOf, demandersOf, demandeesOf, festivalsOf, locationsOf, holdingOf, carryingOf, shunnedOf, threatenedOf, extortedOf, compliedOf, defiedOf, brandedOf, revokedOf, confessedOf, recantedOf, ostracizedOf, exiledOf, denouncedOf, censuredOf, paradedOf, criedOf, ralliedOf, fledOf, reconciledOf, marriedOf, eyedOf, confrontedOf, atonedOf, wrongedOf, hungryOf, shortTemperedOf, appetiteOf, resentsOf, alliedOf, stallOf, siblingsOf, parentsOf, childrenOf, grandparentsOf, grandchildrenOf, inLawsOf, spousesOf, explainActor)

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
worldNamed ("sandbox" : _)  = ("the harvest/market sandbox", Sandbox.sandboxWorld, Sandbox.playerName)
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
        (w : qs) | w `elem` ["village","bar","feud","intrigue","play","dm","audience","sandbox"]
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

-- | List debt leaves involving a character: @prax debts <who> <world>@.
runDebts :: [String] -> IO ()
runDebts (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (debtsOf st who)
runDebts _ = putStrLn "usage: prax debts <who> <world>"

runCreditors :: [String] -> IO ()
runCreditors (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (creditorsOf st who)
runCreditors _ = putStrLn "usage: prax creditors <who> <world>"

runDebtors :: [String] -> IO ()
runDebtors (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (debtorsOf st who)
runDebtors _ = putStrLn "usage: prax debtors <who> <world>"

-- | List obligation leaves for a character: @prax obligations <who> <world>@.
runObligations :: [String] -> IO ()
runObligations (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (obligationsOf st who)
runObligations _ = putStrLn "usage: prax obligations <who> <world>"

-- | List breach leaves for a character: @prax breaches <who> <world>@.
runBreaches :: [String] -> IO ()
runBreaches (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (breachesOf st who)
runBreaches _ = putStrLn "usage: prax breaches <who> <world>"

-- | List feeling leaves: @prax feelings <who> <world>@.
runFeelings :: [String] -> IO ()
runFeelings (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (feelingsOf st who)
runFeelings _ = putStrLn "usage: prax feelings <who> <world>"

-- | List lie-mark leaves: @prax lies <who> <world>@.
runLies :: [String] -> IO ()
runLies (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (liesOf st who)
runLies _ = putStrLn "usage: prax lies <who> <world>"

-- | List chattedWith leaves: @prax chatted <who> <world>@.
runChatted :: [String] -> IO ()
runChatted (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (chattedWithOf st who)
runChatted _ = putStrLn "usage: prax chatted <who> <world>"

-- | List trait leaves: @prax traits <who> <world>@.
runTraits :: [String] -> IO ()
runTraits (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (traitsOf st who)
runTraits _ = putStrLn "usage: prax traits <who> <world>"

-- | List mood leaves: @prax moods <who> <world>@.
runMoods :: [String] -> IO ()
runMoods (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (moodsOf st who)
runMoods _ = putStrLn "usage: prax moods <who> <world>"

-- | List bond leaves: @prax bonds <who> <world>@.
runBonds :: [String] -> IO ()
runBonds (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (bondsOf st who)
runBonds _ = putStrLn "usage: prax bonds <who> <world>"

-- | List kin leaves: @prax kin <who> <world>@.
runKin :: [String] -> IO ()
runKin (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (kinOf st who)
runKin _ = putStrLn "usage: prax kin <who> <world>"

-- | List notoriety leaves: @prax notorious <who> <world>@.
runNotorious :: [String] -> IO ()
runNotorious (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (notoriousOf st who)
runNotorious _ = putStrLn "usage: prax notorious <who> <world>"

runEsteemed :: [String] -> IO ()
runEsteemed (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (esteemedOf st who)
runEsteemed _ = putStrLn "usage: prax esteemed <who> <world>"

runScorned :: [String] -> IO ()
runScorned (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (scornedOf st who)
runScorned _ = putStrLn "usage: prax scorned <who> <world>"

runBeliefs :: [String] -> IO ()
runBeliefs (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (beliefsOf st who)
runBeliefs _ = putStrLn "usage: prax beliefs <who> <world>"

runArcs :: [String] -> IO ()
runArcs (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (arcsOf st who)
runArcs _ = putStrLn "usage: prax arcs <who> <world>"

runAges :: [String] -> IO ()
runAges (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (agesOf st who)
runAges _ = putStrLn "usage: prax ages <who> <world>"

runProjects :: [String] -> IO ()
runProjects (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (projectsOf st who)
runProjects _ = putStrLn "usage: prax projects <who> <world>"

runDemanded :: [String] -> IO ()
runDemanded (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (demandedOf st who)
runDemanded _ = putStrLn "usage: prax demanded <who> <world>"

runDemanders :: [String] -> IO ()
runDemanders (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (demandersOf st who)
runDemanders _ = putStrLn "usage: prax demanders <who> <world>"

runDemandees :: [String] -> IO ()
runDemandees (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (demandeesOf st who)
runDemandees _ = putStrLn "usage: prax demandees <who> <world>"

runFestivals :: [String] -> IO ()
runFestivals ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (festivalsOf st)

runStall :: [String] -> IO ()
runStall ws =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (stallOf st)

runLocations :: [String] -> IO ()
runLocations (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (locationsOf st who)
runLocations _ = putStrLn "usage: prax locations <who> <world>"

runHolding :: [String] -> IO ()
runHolding (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (holdingOf st who)
runHolding _ = putStrLn "usage: prax holding <who> <world>"

runCarrying :: [String] -> IO ()
runCarrying (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (carryingOf st who)
runCarrying _ = putStrLn "usage: prax carrying <who> <world>"

runShunned :: [String] -> IO ()
runShunned (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (shunnedOf st who)
runShunned _ = putStrLn "usage: prax shunned <who> <world>"

runThreatened :: [String] -> IO ()
runThreatened (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (threatenedOf st who)
runThreatened _ = putStrLn "usage: prax threatened <who> <world>"

runExtorted :: [String] -> IO ()
runExtorted (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (extortedOf st who)
runExtorted _ = putStrLn "usage: prax extorted <who> <world>"

runComplied :: [String] -> IO ()
runComplied (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (compliedOf st who)
runComplied _ = putStrLn "usage: prax complied <who> <world>"

runDefied :: [String] -> IO ()
runDefied (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (defiedOf st who)
runDefied _ = putStrLn "usage: prax defied <who> <world>"

runBranded :: [String] -> IO ()
runBranded (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (brandedOf st who)
runBranded _ = putStrLn "usage: prax branded <who> <world>"

runRevoked :: [String] -> IO ()
runRevoked (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (revokedOf st who)
runRevoked _ = putStrLn "usage: prax revoked <who> <world>"

runConfessed :: [String] -> IO ()
runConfessed (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (confessedOf st who)
runConfessed _ = putStrLn "usage: prax confessed <who> <world>"

runRecanted :: [String] -> IO ()
runRecanted (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (recantedOf st who)
runRecanted _ = putStrLn "usage: prax recanted <who> <world>"

runOstracized :: [String] -> IO ()
runOstracized (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (ostracizedOf st who)
runOstracized _ = putStrLn "usage: prax ostracized <who> <world>"

runExiled :: [String] -> IO ()
runExiled (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (exiledOf st who)
runExiled _ = putStrLn "usage: prax exiled <who> <world>"

runDenounced :: [String] -> IO ()
runDenounced (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (denouncedOf st who)
runDenounced _ = putStrLn "usage: prax denounced <who> <world>"

runCensured :: [String] -> IO ()
runCensured (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (censuredOf st who)
runCensured _ = putStrLn "usage: prax censured <who> <world>"

runParaded :: [String] -> IO ()
runParaded (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (paradedOf st who)
runParaded _ = putStrLn "usage: prax paraded <who> <world>"

runCried :: [String] -> IO ()
runCried (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (criedOf st who)
runCried _ = putStrLn "usage: prax cried <who> <world>"

runRallied :: [String] -> IO ()
runRallied (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (ralliedOf st who)
runRallied _ = putStrLn "usage: prax rallied <who> <world>"

runFled :: [String] -> IO ()
runFled (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (fledOf st who)
runFled _ = putStrLn "usage: prax fled <who> <world>"

runReconciled :: [String] -> IO ()
runReconciled (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (reconciledOf st who)
runReconciled _ = putStrLn "usage: prax reconciled <who> <world>"

runMarried :: [String] -> IO ()
runMarried (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (marriedOf st who)
runMarried _ = putStrLn "usage: prax married <who> <world>"

runEyed :: [String] -> IO ()
runEyed (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (eyedOf st who)
runEyed _ = putStrLn "usage: prax eyed <who> <world>"

runConfronted :: [String] -> IO ()
runConfronted (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (confrontedOf st who)
runConfronted _ = putStrLn "usage: prax confronted <who> <world>"

runAtoned :: [String] -> IO ()
runAtoned (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (atonedOf st who)
runAtoned _ = putStrLn "usage: prax atoned <who> <world>"

runWronged :: [String] -> IO ()
runWronged (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (wrongedOf st who)
runWronged _ = putStrLn "usage: prax wronged <who> <world>"

runHungry :: [String] -> IO ()
runHungry (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (hungryOf st who)
runHungry _ = putStrLn "usage: prax hungry <who> <world>"

runShortTempered :: [String] -> IO ()
runShortTempered (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (shortTemperedOf st who)
runShortTempered _ = putStrLn "usage: prax short-tempered <who> <world>"

runAppetite :: [String] -> IO ()
runAppetite (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (appetiteOf st who)
runAppetite _ = putStrLn "usage: prax appetite <who> <world>"

runResents :: [String] -> IO ()
runResents (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (resentsOf st who)
runResents _ = putStrLn "usage: prax resents <who> <world>"

runAllied :: [String] -> IO ()
runAllied (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (alliedOf st who)
runAllied _ = putStrLn "usage: prax allied <who> <world>"

runSiblings :: [String] -> IO ()
runSiblings (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (siblingsOf st who)
runSiblings _ = putStrLn "usage: prax siblings <who> <world>"

runParents :: [String] -> IO ()
runParents (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (parentsOf st who)
runParents _ = putStrLn "usage: prax parents <who> <world>"

runChildren :: [String] -> IO ()
runChildren (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (childrenOf st who)
runChildren _ = putStrLn "usage: prax children <who> <world>"

runGrandparents :: [String] -> IO ()
runGrandparents (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (grandparentsOf st who)
runGrandparents _ = putStrLn "usage: prax grandparents <who> <world>"

runGrandchildren :: [String] -> IO ()
runGrandchildren (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (grandchildrenOf st who)
runGrandchildren _ = putStrLn "usage: prax grandchildren <who> <world>"

runInLaws :: [String] -> IO ()
runInLaws (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (inLawsOf st who)
runInLaws _ = putStrLn "usage: prax in-laws <who> <world>"

runSpouses :: [String] -> IO ()
runSpouses (who : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (spousesOf st who)
runSpouses _ = putStrLn "usage: prax spouses <who> <world>"

runExplain :: [String] -> IO ()
runExplain (actor : needle : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (explainActor st actor needle)
runExplain _ = putStrLn "usage: prax explain <actor> <needle> <world>"

runView :: [String] -> IO ()
runView (needle : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (queryViewMatching st needle)
runView _ = putStrLn "usage: prax view <needle> <world>"

runFacts :: [String] -> IO ()
runFacts (needle : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (queryMatching st needle)
runFacts _ = putStrLn "usage: prax facts <needle> <world>"

runAvailable :: [String] -> IO ()
runAvailable (who : needle : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (availableMatching st who needle)
runAvailable _ = putStrLn "usage: prax available <who> <needle> <world>"

runLivingMatch :: [String] -> IO ()
runLivingMatch (needle : ws) =
  let (_, st, _) = worldNamed ws
  in mapM_ putStrLn (livingMatching st needle)
runLivingMatch _ = putStrLn "usage: prax living <needle> <world>"

runWorlds :: IO ()
runWorlds = mapM_ putStrLn
  [ "bar        — a night at the bar (default)"
  , "dm         — the bar, and you direct it"
  , "village    — the village"
  , "feud       — the feud (emergent sandbox)"
  , "intrigue   — Intrigue (Rome)"
  , "play       — the conspiracy (a play)"
  , "audience   — the royal audience"
  , "sandbox    — harvest/market festivals + factionStanding + silence/defection sandbox"
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
  , "  prax village|feud|intrigue|play|dm|audience|sandbox"
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
  , "  prax debts <who> <world>               list debt leaves involving who"
  , "  prax obligations <who> <world>         list obligation leaves for who"
  , "  prax breaches <who> <world>            list violation leaves for who"
  , "  prax feelings <who> <world>            list feeling leaves for who"
  , "  prax lies <who> <world>                list lie-mark leaves for who"
  , "  prax chatted <who> <world>             list chattedWith leaves for who"
  , "  prax traits <who> <world>              list trait leaves for who"
  , "  prax moods <who> <world>               list mood leaves for who"
  , "  prax bonds <who> <world>               list bond leaves for who"
  , "  prax kin <who> <world>                 list kin leaves involving who"
  , "  prax notorious <who> <world>           list notoriety leaves for who"
  , "  prax esteemed <who> <world>            list esteemed leaves for who"
  , "  prax scorned <who> <world>             list scorned leaves for who"
  , "  prax beliefs <who> <world>             list belief leaves for who"
  , "  prax arcs <who> <world>                list arc stage leaves for who"
  , "  prax ages <who> <world>                list age leaves for who"
  , "  prax projects <who> <world>            list practice instance leaves for who"
  , "  prax demanded <who> <world>            list demand leaves involving who"
  , "  prax festivals <world>                 list open festival leaves"
  , "  prax stall <world>                     list stall.<item> inventory leaves"
  , "  prax locations <who> <world>           list at.<who>.* location leaves"
  , "  prax holding <who> <world>             list holding.<who>.* leaves"
  , "  prax carrying <who> <world>            list carrying.<who>.* leaves"
  , "  prax shunned <who> <world>             list shunned.<who>.* leaves"
  , "  prax threatened <who> <world>          list threatened leaves involving who"
  , "  prax extorted <who> <world>            list extorted leaves involving who"
  , "  prax complied <who> <world>            list complied leaves involving who"
  , "  prax defied <who> <world>              list defied leaves involving who"
  , "  prax branded <who> <world>             list branded* leaves for who"
  , "  prax revoked <who> <world>             list revoked leaves involving who"
  , "  prax confessed <who> <world>           list confessed leaves for who"
  , "  prax recanted <who> <world>            list recanted leaves for who"
  , "  prax ostracized <who> <world>          list ostracized leaves involving who"
  , "  prax exiled <who> <world>              list exiled leaves for who"
  , "  prax denounced <who> <world>           list denounced leaves involving who"
  , "  prax censured <who> <world>            list censured leaves involving who"
  , "  prax paraded <who> <world>             list paraded leaves involving who"
  , "  prax cried <who> <world>               list cried leaves involving who"
  , "  prax rallied <who> <world>             list rallied leaves involving who"
  , "  prax fled <who> <world>                list fled leaves for who"
  , "  prax reconciled <who> <world>          list reconciled leaves for who"
  , "  prax married <who> <world>             list married leaves involving who"
  , "  prax eyed <who> <world>                list eyed leaves involving who"
  , "  prax confronted <who> <world>          list confronted leaves involving who"
  , "  prax atoned <who> <world>              list atoned leaves for who"
  , "  prax wronged <who> <world>             list wronged leaves involving who"
  , "  prax hungry <who> <world>              list hungry leaves for who"
  , "  prax short-tempered <who> <world>      list shortTempered leaves for who"
  , "  prax appetite <who> <world>            list appetite leaves for who"
  , "  prax resents <who> <world>             list resents leaves for who"
  , "  prax allied <who> <world>              list allied leaves involving who"
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
    ("debts" : ws)     -> runDebts ws
    ("creditors" : ws) -> runCreditors ws
    ("debtors" : ws)   -> runDebtors ws
    ("obligations" : ws) -> runObligations ws
    ("breaches" : ws)  -> runBreaches ws
    ("feelings" : ws) -> runFeelings ws
    ("lies" : ws)     -> runLies ws
    ("chatted" : ws)  -> runChatted ws
    ("traits" : ws)   -> runTraits ws
    ("moods" : ws)    -> runMoods ws
    ("bonds" : ws)    -> runBonds ws
    ("kin" : ws)      -> runKin ws
    ("notorious" : ws) -> runNotorious ws
    ("esteemed" : ws) -> runEsteemed ws
    ("scorned" : ws)  -> runScorned ws
    ("beliefs" : ws)  -> runBeliefs ws
    ("arcs" : ws)     -> runArcs ws
    ("ages" : ws)     -> runAges ws
    ("projects" : ws) -> runProjects ws
    ("demanded" : ws) -> runDemanded ws
    ("demanders" : ws) -> runDemanders ws
    ("demandees" : ws) -> runDemandees ws
    ("festivals" : ws) -> runFestivals ws
    ("stall" : ws)     -> runStall ws
    ("locations" : ws) -> runLocations ws
    ("holding" : ws)   -> runHolding ws
    ("carrying" : ws)  -> runCarrying ws
    ("shunned" : ws)   -> runShunned ws
    ("threatened" : ws) -> runThreatened ws
    ("extorted" : ws)  -> runExtorted ws
    ("complied" : ws)  -> runComplied ws
    ("defied" : ws)    -> runDefied ws
    ("branded" : ws)   -> runBranded ws
    ("revoked" : ws)   -> runRevoked ws
    ("confessed" : ws) -> runConfessed ws
    ("recanted" : ws)  -> runRecanted ws
    ("ostracized" : ws) -> runOstracized ws
    ("exiled" : ws)    -> runExiled ws
    ("denounced" : ws) -> runDenounced ws
    ("censured" : ws)  -> runCensured ws
    ("paraded" : ws)   -> runParaded ws
    ("cried" : ws)     -> runCried ws
    ("rallied" : ws)   -> runRallied ws
    ("fled" : ws)      -> runFled ws
    ("reconciled" : ws) -> runReconciled ws
    ("married" : ws)   -> runMarried ws
    ("eyed" : ws)      -> runEyed ws
    ("confronted" : ws) -> runConfronted ws
    ("atoned" : ws)    -> runAtoned ws
    ("wronged" : ws)   -> runWronged ws
    ("hungry" : ws)    -> runHungry ws
    ("short-tempered" : ws) -> runShortTempered ws
    ("appetite" : ws)  -> runAppetite ws
    ("resents" : ws)   -> runResents ws
    ("allied" : ws)    -> runAllied ws
    ("siblings" : ws)  -> runSiblings ws
    ("parents" : ws)   -> runParents ws
    ("children" : ws)  -> runChildren ws
    ("grandparents" : ws) -> runGrandparents ws
    ("grandchildren" : ws) -> runGrandchildren ws
    ("in-laws" : ws)   -> runInLaws ws
    ("spouses" : ws)   -> runSpouses ws
    ("view" : ws)      -> runView ws
    ("facts" : ws)     -> runFacts ws
    ("available" : ws) -> runAvailable ws
    ("living" : ws)    -> runLivingMatch ws
    ("explain" : ws)   -> runExplain ws
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
        ("sandbox" : _) ->
          ( "prax — the harvest/market sandbox"
          , "You are a mill hand. Learn, denounce at harvest, exile after — or watch the church try heresy."
          , Sandbox.sandboxWorld, Sandbox.playerName )
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
