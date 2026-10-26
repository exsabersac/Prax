module Prax.DebtSpec (tests) where

import           Control.Exception (ErrorCall, evaluate, try)
import           Data.Either (isLeft)
import           Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import           Test.Tasty (TestTree, testGroup)
import           Test.Tasty.HUnit (testCase, assertBool, (@?=))

import           Prax.Db (exists, dbToSentences)
import           Prax.Query (Condition (..), satisfies)
import           Prax.Types
import           Prax.Engine (definePractices, performOutcome, possibleActions, performAction, setAxioms, setCharacters)
import           Prax.Deontic (oblige, discharge, obligationPath, breach)
import           Prax.Witness (CoPresence, observable)
import           Prax.Repute (standingUnless)
import           Prax.Debt

applyAll :: PraxState -> [Outcome] -> PraxState
applyAll = foldl (flip performOutcome)

-- The tale: cora lends dell a favor. When dell stiffs her, cora calls it in
-- (co-present) — a witnessed default sours dell's standing with whoever was
-- there to see it; an unwitnessed one leaves no such trace. Repaying settles
-- the debt AND the standing, though the witness's own memory never clears.
together :: CoPresence
together = [ Match "at.Actor!P", Match "at.Witness!P" ]

demand :: Action
demand = observable together "violated.dell.defaulted" $
  action "[Actor]: demand dell repay the favor"
    [ owes "Actor" "dell" "favor"
    , Match "at.Actor!P", Match "at.dell!P"
    , Not "demanded.Actor.dell.favor" ]
    [ Insert "demanded.Actor.dell.favor"
    , breach "dell" "defaulted" ]

repay :: Action
repay = action "[Actor]: dell repays cora the favor"
  [ Eq "Actor" "dell", owes "cora" "Actor" "favor" ]
  (settle "cora" "dell" "favor"
    ++ [ Insert "atoned.dell", Delete "violated.dell.defaulted" ])

debtPractice :: Practice
debtPractice = practice
  { practiceId = "debt", roles = ["R"]
  , actions = [ demand, repay ] }

-- @witnessPresent@ toggles whether ren shares cora and dell's square (versus
-- being off at the mill) when the default happens.
mkWorld :: Bool -> PraxState
mkWorld witnessPresent =
  setAxioms [ standingUnless "violated.Debtor.defaulted" "atoned.Debtor" "deadbeat" ]
    (foldl (flip performOutcome) base setup)
  where
    base = setCharacters (map character ["cora", "dell", "ren"])
             (definePractices [debtPractice] emptyState)
    setup =
      [ Insert "practice.debt.here" ]
      ++ owe "cora" "dell" "favor"
      ++ [ Insert "at.cora!square", Insert "at.dell!square"
         , Insert ("at.ren!" ++ if witnessPresent then "square" else "mill") ]

witnessedWorld :: PraxState
witnessedWorld = mkWorld True

aloneWorld :: PraxState
aloneWorld = mkWorld False

-- Perform the named actor's action whose label mentions @needle@.
doAct :: String -> String -> PraxState -> PraxState
doAct who needle st =
  case [ ga | ga <- possibleActions st who, needle `isInfixOf` gaLabel ga ] of
    (ga : _) -> performAction st ga
    []       -> error ("no action for " ++ who ++ " matching " ++ show needle
                       ++ "; had: " ++ show (map gaLabel (possibleActions st who)))

tests :: TestTree
tests = testGroup "Prax.Debt"
  [ testGroup "fact conventions"
    [ testCase "debtPath is debt.<creditor>.<debtor>.<content>" $
        debtPath "cora" "dell" "favor" @?= "debt.cora.dell.favor"
    , testCase "owes matches the debt fact" $
        owes "cora" "dell" "favor" @?= Match "debt.cora.dell.favor"
    , testCase "owe asserts the debt fact and Deontic's oblige, in one call" $
        owe "cora" "dell" "favor"
          @?= [ Insert "debt.cora.dell.favor", oblige "dell" "favor" ]
    , testCase "settle retracts the debt fact and Deontic's discharge" $
        settle "cora" "dell" "favor"
          @?= [ Delete "debt.cora.dell.favor", discharge "dell" "favor" ]
    ]

  , testGroup "lifecycle: owe creates BOTH facts; settle removes BOTH"
    [ testCase "owe inserts the debt fact and the obligation; settle removes both" $ do
        let content = "repaid.dell.cora.coin"
            owed = applyAll emptyState (owe "cora" "dell" content)
        assertBool "debt fact"
          (exists "debt.cora.dell.repaid.dell.cora.coin" (db owed))
        assertBool "obligation fact"
          (exists (obligationPath "dell" content) (db owed))
        let settled = applyAll owed (settle "cora" "dell" content)
        assertBool "debt fact gone"
          (not (exists "debt.cora.dell.repaid.dell.cora.coin" (db settled)))
        assertBool "obligation gone"
          (not (exists (obligationPath "dell" content) (db settled)))
    ]

  , testGroup "guards"
    [ testCase "a dotted creditor name errors loudly" $ do
        r <- try (evaluate (length (debtPath "cor.a" "dell" "favor")))
        assertBool "dotted creditor is an error" (isLeft (r :: Either ErrorCall Int))
    , testCase "a punctuated debtor name errors loudly" $ do
        r <- try (evaluate (length (debtPath "cora" "de!l" "favor")))
        assertBool "punctuated debtor is an error" (isLeft (r :: Either ErrorCall Int))
    ]

  , testGroup "demand -> deadbeat: belief-gated standing, defeated by settling"
    [ testCase "an unwitnessed default derives no third-party regard" $ do
        let st = doAct "cora" "demand" aloneWorld
        assertBool "the world records the breach" (exists "violated.dell.defaulted" (db st))
        assertBool "ren, elsewhere, holds no belief of it"
          (not (exists "ren.believes.violated.dell.defaulted.seen" (db st)))
        assertBool "and so derives no THIRD-PARTY deadbeat regard"
          (not (exists "regards.ren.dell.deadbeat" (readView st)))
        assertBool "dell is unavoidably co-present at his own default, so he still\
                   \ witnesses (and regards) himself — belief-gating is per observer,\
                   \ not a blanket suppression"
          (exists "regards.dell.dell.deadbeat" (readView st))

    , testCase "a witnessed default derives deadbeat standing for the witness" $ do
        let st = doAct "cora" "demand" witnessedWorld
        assertBool "ren saw it"
          (exists "ren.believes.violated.dell.defaulted.seen" (db st))
        assertBool "ren regards dell a deadbeat"
          (exists "regards.ren.dell.deadbeat" (readView st))

    , testCase "settling (atoned-shaped) defeats the standing; the witness's memory persists" $ do
        let st1 = doAct "cora" "demand" witnessedWorld
            st2 = doAct "dell" "repays" st1
        assertBool "settled: the debt is gone"
          (not (exists "debt.cora.dell.favor" (db st2)))
        assertBool "no regard survives settling"
          (not (exists "regards.ren.dell.deadbeat" (readView st2)))
        assertBool "ren still remembers the default"
          (exists "ren.believes.violated.dell.defaulted.seen" (db st2))
    ]

  , testCase "isOwed / hasCreditorClaim existentials" $ do
      isOwed "bob" @?= Exists [ Match "debt.Creditor.bob.Content" ]
      hasCreditorClaim "ana" @?= Exists [ Match "debt.ana.Debtor.Content" ]

  , testCase "forgive clears debt and obligation as creditor action" $ do
      let forgiveP = practice
            { practiceId = "mercy"
            , roles = []
            , actions = [ forgive "favor" "[Actor]: forgive [Debtor] the favor" ]
            }
          st0 = definePractices [forgiveP]
                  (foldl (flip performOutcome) emptyState
                    (Insert "practice.mercy" : owe "cora" "dell" "favor"))
      assertBool "owed" (exists "debt.cora.dell.favor" (db st0))
      assertBool "obliged" (exists "obliged.dell.favor" (db st0))
      let st1 = case filter (("forgive" `isInfixOf`) . gaLabel) (possibleActions st0 "cora") of
                  (ga:_) -> performAction st0 ga
                  [] -> error "no forgive"
      assertBool "debt gone" (not (exists "debt.cora.dell.favor" (db st1)))
      assertBool "obligation gone" (not (exists "obliged.dell.favor" (db st1)))


  , testCase "callIn marks demanded and breaches debtor" $ do
      let callP = practice
            { practiceId = "ledger"
            , roles = []
            , actions = [ callIn "favor" "defaulted" "[Actor]: call in [Debtor]'s favor" ]
            }
          st0 = definePractices [callP]
                  (foldl (flip performOutcome) emptyState
                    (Insert "practice.ledger" : owe "cora" "dell" "favor"))
      let st1 = case filter (("call in" `isInfixOf`) . gaLabel) (possibleActions st0 "cora") of
                  (ga:_) -> performAction st0 ga
                  [] -> error "no callIn"
      assertBool "demanded" (exists "demanded.cora.dell.favor" (db st1))
      assertBool "breached" (exists "violated.dell.defaulted" (db st1)
                              || exists "breached.dell.defaulted" (db st1)
                              || any ("defaulted" `isInfixOf`) (dbToSentences (db st1)))

  , testCase "neverOwed is Absent of any creditor/content debt leaf" $
      neverOwed "dell" @?= Absent [ Match "debt.Creditor.dell.Content" ]
  , testCase "everOwed aliases isOwed" $
      everOwed "dell" @?= isOwed "dell"

  , testCase "lacksCreditorClaim is Absent of creditor subtree" $
      lacksCreditorClaim "ada" @?= Absent [ Match "debt.ada.Debtor.Content" ]


  , testCase "lacksOwes is Not of owes path" $
      lacksOwes "cora" "dell" "favor" @?= Not "debt.cora.dell.favor"
  
  , testCase "isDemanded / lacksDemanded pin demanded path" $ do
      isDemanded "ana" "ben" "favor" @?= Match "demanded.ana.ben.favor"
      lacksDemanded "ana" "ben" "favor" @?= Not "demanded.ana.ben.favor"

  , testCase "everDemanded / neverDemanded are Exists/Absent over demanded.*.<debtor>.*" $ do
      everDemanded "ben" @?= Exists [ Match "demanded.Creditor.ben.Content" ]
      neverDemanded "ben" @?= Absent [ Match "demanded.Creditor.ben.Content" ]
  , testCase "hasOwes / hasOwed / hasDemanded aliases" $ do
      hasOwes "ana" "ben" "favor" @?= owes "ana" "ben" "favor"
      hasOwed "ben" @?= isOwed "ben"
      hasDemanded "ana" "ben" "favor" @?= isDemanded "ana" "ben" "favor"

  , testCase "hasRevoked / lacksRevoked duals over revoked.<creditor>.<debtor>" $ do
      hasRevoked "ira" "bob" @?= Match "revoked.ira.bob"
      lacksRevoked "ira" "bob" @?= Not "revoked.ira.bob"


  , testCase "owes / lacksOwes evaluate on a lent-then-settled world" $ do
      let owed = applyAll emptyState (owe "cora" "dell" "favor")
      assertBool "owes holds" (satisfies (db owed) [owes "cora" "dell" "favor"] Map.empty)
      assertBool "lacksOwes fails while owed"
        (not (satisfies (db owed) [lacksOwes "cora" "dell" "favor"] Map.empty))
      let settled = applyAll owed (settle "cora" "dell" "favor")
      assertBool "lacksOwes after settle"
        (satisfies (db settled) [lacksOwes "cora" "dell" "favor"] Map.empty)
      assertBool "owes gone after settle"
        (not (satisfies (db settled) [owes "cora" "dell" "favor"] Map.empty))

  , testCase "hasRevoked / lacksRevoked evaluate after revoke Insert" $ do
      let st = applyAll emptyState [Insert "revoked.ira.bob"]
      assertBool "hasRevoked" (satisfies (db st) [hasRevoked "ira" "bob"] Map.empty)
      assertBool "lacksRevoked fails"
        (not (satisfies (db st) [lacksRevoked "ira" "bob"] Map.empty))
      let clean = emptyState
      assertBool "lacksRevoked on clean"
        (satisfies (db clean) [lacksRevoked "ira" "bob"] Map.empty)


  , testCase "isDemanded / lacksDemanded evaluate after demand action" $ do
      let st = doAct "cora" "demand" aloneWorld
      assertBool "isDemanded"
        (satisfies (db st) [isDemanded "cora" "dell" "favor"] Map.empty)
      assertBool "lacksDemanded fails"
        (not (satisfies (db st) [lacksDemanded "cora" "dell" "favor"] Map.empty))
      assertBool "lacksDemanded on seed"
        (satisfies (db aloneWorld) [lacksDemanded "cora" "dell" "favor"] Map.empty)


  , testCase "neverOwed / everDemanded evaluate on clean vs demanded world" $ do
      assertBool "neverOwed on empty"
        (satisfies (db emptyState) [neverOwed "dell"] Map.empty)
      let owed = applyAll emptyState (owe "cora" "dell" "favor")
      assertBool "neverOwed fails while owed"
        (not (satisfies (db owed) [neverOwed "dell"] Map.empty))
      let st = doAct "cora" "demand" aloneWorld
      assertBool "everDemanded after demand"
        (satisfies (db st) [everDemanded "dell"] Map.empty)

  , testCase "everOwed / neverDemanded / hasCreditorClaim evaluate on worlds" $ do
      assertBool "neverDemanded on empty"
        (satisfies (db emptyState) [neverDemanded "dell"] Map.empty)
      let owed = applyAll emptyState (owe "cora" "dell" "favor")
      assertBool "everOwed while owed"
        (satisfies (db owed) [everOwed "dell"] Map.empty)
      assertBool "hasCreditorClaim"
        (satisfies (db owed) [hasCreditorClaim "cora"] Map.empty)
      assertBool "lacksCreditorClaim fails"
        (not (satisfies (db owed) [lacksCreditorClaim "cora"] Map.empty))
      assertBool "lacksCreditorClaim on empty"
        (satisfies (db emptyState) [lacksCreditorClaim "cora"] Map.empty)
      assertBool "neverDemanded on aloneWorld seed"
        (satisfies (db aloneWorld) [neverDemanded "dell"] Map.empty)
      let st = doAct "cora" "demand" aloneWorld
      assertBool "neverDemanded fails after demand"
        (not (satisfies (db st) [neverDemanded "dell"] Map.empty))

  , testCase "isOwed / hasOwed / hasOwes / hasDemanded evaluate on worlds" $ do
      assertBool "isOwed fails on empty"
        (not (satisfies (db emptyState) [isOwed "dell"] Map.empty))
      let owed = applyAll emptyState (owe "cora" "dell" "favor")
      assertBool "isOwed" (satisfies (db owed) [isOwed "dell"] Map.empty)
      assertBool "hasOwed" (satisfies (db owed) [hasOwed "dell"] Map.empty)
      assertBool "hasOwes"
        (satisfies (db owed) [hasOwes "cora" "dell" "favor"] Map.empty)
      let st = doAct "cora" "demand" aloneWorld
      assertBool "hasDemanded"
        (satisfies (db st) [hasDemanded "cora" "dell" "favor"] Map.empty)
      assertBool "everOwed fails on empty"
        (not (satisfies (db emptyState) [everOwed "dell"] Map.empty))

  ]
