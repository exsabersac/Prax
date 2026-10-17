-- | Exclusion Logic 的格，出自 Evans 的 DEON 2010 论文（§1.5–1.6；精炼于
-- @docs/research/deon-notes.md@）。这是派生层（"Prax.Derive"）所建基的忠实形式核心，
-- 也是未来静态类型检查器（LEDGER #8）将复用的基底。
--
-- 论文在 /labeled rooted trees/（LRTs，Def 2）中解释表达式：边为 @!@（「唯一孩子」——排他）
-- 或 @*@（「多者之一」——多值）的树。我们的 'Prax.Db.Db' /正是/这样的树——每个节点携带
-- 排他标志（'Prax.Db.dbExcl'）——因此格直接在其上运算，无损失。
--
--   * 'meet' — 最大下界 @⊓@（Def 8），即模型合取；@Nothing@ 是论文的 @⊥@
--     （Def 7 不相容）：在任一侧操作数为排他的节点上，两者对孩子意见不一。
--     这从冲突任一侧 /精确/ 检测矛盾。
--   * 'leq' — 信息序 @≤@（Def 6）：@a `leq` b@ 当且仅当 @a@ 携带至少与 @b@ 一样多的信息
--     （@b@ 的全部结构、边标签至少同样具体，@Excl ≤ Multi@）；即 @a@ 蕴涵 @b@。
--
-- 并 @⊔@（Def 9）仅一般蕴涵测试（#8）需要，有意省略。
module Prax.EL
  ( meet
  , leq
  ) where

import           Control.Monad (foldM)
import qualified Data.IntMap.Strict as IntMap

import           Prax.Db (Db (..))

-- | 最大下界 @⊓@（Def 8）——两模型的合取。@Nothing@ 是论文的 @⊥@：在某节点对 /任一侧/
-- 操作数排他时，两者对孩子意见不一（Def 7 不相容）。否则合并孩子（递归 meet 共享子树），
-- 且若任一侧标记则节点排他（更具体标签胜，@Excl ≤ Multi@）。
--
-- Assertedness（规格 @docs/specs/2026-07-15-v39-asserted-endpoints.md@）按点扩展为
-- __析取__：节点在 meet 中被断言当且仅当在 /任一侧/ 操作数中被断言，因为 meet 合取两模型的事实，
-- 任一侧断言的路径是合取的事实。这是保持 meet 为断言操作数下界——@meet a b `leq` a@——的选择
-- （见 'leq'）；此处若用合取会丢掉标记并破坏该法则。
meet :: Db -> Db -> Maybe Db
meet (Db e1 a1 k1) (Db e2 a2 k2) = do
  merged <- foldM ins k1 (IntMap.toList k2)
  let e = e1 || e2
      a = a1 || a2
  if e && IntMap.size merged > 1
    then Nothing                          -- exclusive node forced to two children ⇒ ⊥
    else Just (Db e a merged)
  where
    ins acc (k, v2) = case IntMap.lookup k acc of
      Nothing -> Just (IntMap.insert k v2 acc)
      Just v1 -> do v <- meet v1 v2; Just (IntMap.insert k v acc)

-- | 信息序 @≤@（Def 6）：@a `leq` b@ 当且仅当 @a@ 有 @b@ 的每条边，标签至少同样具体
-- （@Excl ≤ Multi@），递归地——即 @a@ 蕴涵 @b@。
--
-- Assertedness 恰如排他标签进入：若 @b@ 把节点断言为事实，@a@ 也必须断言它
-- （@aa || not ab@）——断言路径严格多于仅作脚手架，因此被断言事实蕴涵其未断言脚手架，
-- 反之不然（镜像 @Excl ≤ Multi@，@Multi ⋠ Excl@）。
leq :: Db -> Db -> Bool
leq (Db ea aa ka) (Db eb ab kb) =
  (ea || not eb) && (aa || not ab) && all present (IntMap.toList kb)
  where
    present (k, bChild) = case IntMap.lookup k ka of
      Nothing     -> False
      Just aChild -> leq aChild bChild
