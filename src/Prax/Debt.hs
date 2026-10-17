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
  ) where

import           Prax.Query (Condition (..))
import           Prax.Types (Outcome (..))
import           Prax.Deontic (oblige, discharge)

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
