-- | 债务：带受益人的义务。
--
-- "Prax.Deontic" 的义务已携带义务承担者（@obliged.\<who\>.\<content\>@），但不点名义务欠谁。
-- 债务正是那义务 /加上/ 受益人：新事实 @debt.\<creditor\>.\<debtor\>.\<content\>@ 坐在
-- （未修改的）义务旁边，因此其余道义机制（'Prax.Deontic.fulfilled'、'Prax.Deontic.inBreach'、
-- 'Prax.Deontic.breach'、…）对 @content@ 恰如创作般继续工作——债务是 Deontic 上的薄词汇，
-- 非并行机制。
--
-- __分层原样延续__（Deontic 的规则，在此重述）：@content@ 是 /简单项/，一个句子，永非复合
-- @∧@\/@∨@\/@→@ ——它本身可以是点路径（例如 @"repaid.dell.cora.coin"@），只是永非分离义务的合取。
-- 此处大声守护的，用既定段习语（"Prax.Project" 的 @endeavor@、"Prax.Persona"）：
-- @creditor@\/@debtor@ 名必须是单路径段（无 @.@ 或 @!@）——与 @content@ 不同，这些命名一方而非职责，
-- 点号方名会静默误解析事实的四部分形状。
module Prax.Debt
  ( debtPath
  , owe
  , settle
  , owes
  , lacksOwes
  , forgive
  , callIn
  , isOwed
  , hasCreditorClaim
  , lacksCreditorClaim
  , neverOwed
  , everOwed
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), action)
import           Prax.Deontic (oblige, discharge, breach)

-- | 债务的 DB 路径：@debt.\<creditor\>.\<debtor\>.\<content\>@。多段名响亮拒绝。
debtPath :: String -> String -> String -> String
debtPath creditor debtor content
  | any (`elem` (".!" :: String)) creditor =
      error ("Prax.Debt.debtPath: creditor " ++ show creditor
             ++ " must be a single path segment (no '.' or '!')")
  | any (`elem` (".!" :: String)) debtor =
      error ("Prax.Debt.debtPath: debtor " ++ show debtor
             ++ " must be a single path segment (no '.' or '!')")
  | otherwise = "debt." ++ creditor ++ "." ++ debtor ++ "." ++ content

-- | @owe creditor debtor content@——债务人现欠债权人：债务事实加上双方动机。
owe :: String -> String -> String -> [Outcome]
owe creditor debtor content =
  [ Insert (debtPath creditor debtor content), oblige debtor content ]

-- | @settle creditor debtor content@——债务结清：删除债务事实并清除相关动机。
settle :: String -> String -> String -> [Outcome]
settle creditor debtor content =
  [ Delete (debtPath creditor debtor content), discharge debtor content ]

-- | 条件：@debtor@ 当前欠 @creditor@ @content@。
owes :: String -> String -> String -> Condition
owes creditor debtor content = Match (debtPath creditor debtor content)

-- | 条件：@debtor@ 当前不欠 @creditor@ @content@（@owes@ 的 Not 对偶）。
lacksOwes :: String -> String -> String -> Condition
lacksOwes creditor debtor content = Not (debtPath creditor debtor content)

-- | 债权人赦免：门禁于 @debt.Actor.Debtor.<content>@，删除债务并 discharge 债务人义务。
forgive :: String -> String -> Action
forgive content label
  | null content =
      error ("forgive: content must be nonempty")
  | otherwise = action label
      [ Match ("debt.Actor.Debtor." ++ content) ]
      [ Delete ("debt.Actor.Debtor." ++ content)
      , discharge "Debtor" content ]

-- | 催债：债权人标记已催，并对债务人记一次 @breachLabel@ 违约（薄骑 'Prax.Deontic.breach'）。
-- 门禁于未结清债务且尚未催过；站队/目击由创作方另行叠加。
callIn :: String -> String -> String -> Action
callIn content breachLabel label
  | null content =
      error ("callIn: content must be nonempty")
  | null breachLabel || any (`elem` (".!" :: String)) breachLabel =
      error ("callIn: breachLabel must be a single path segment")
  | otherwise = action label
      [ Match ("debt.Actor.Debtor." ++ content)
      , Not ("demanded.Actor.Debtor." ++ content) ]
      [ Insert ("demanded.Actor.Debtor." ++ content)
      , breach "Debtor" breachLabel ]

-- | 条件：@debtor@ 欠任何人任何内容（存在量词于债权人与内容）。
isOwed :: String -> Condition
isOwed debtor = Exists [ Match ("debt.Creditor." ++ debtor ++ ".Content") ]

-- | 条件：@creditor@ 对任何人持有债权。
hasCreditorClaim :: String -> Condition
hasCreditorClaim creditor = Exists [ Match ("debt." ++ creditor ++ ".Debtor.Content") ]

-- | 条件：@creditor@ 对任何人无债权主张。
lacksCreditorClaim :: String -> Condition
lacksCreditorClaim creditor =
  Absent [ Match ("debt." ++ creditor ++ ".Debtor.Content") ]

-- | 条件：@debtor@ 当前不欠任何人任何内容（@isOwed@ 对偶）。
neverOwed :: String -> Condition
neverOwed debtor = Absent [ Match ("debt.Creditor." ++ debtor ++ ".Content") ]

-- | 条件：@debtor@ 欠任何人任何内容（@isOwed@ 同体；对齐 ever* 命名）。
everOwed :: String -> Condition
everOwed = isOwed
