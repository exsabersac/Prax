-- | 秘密与欺骗：管理已知内容。
--
-- __隐瞒是创作，非机制。__ 'conceal' 是 want 无人相信某事件；planner 前瞻已模拟目击存入
-- （"Prax.Witness"），因此珍视秘密的 agent /经规划/ 避免被看见——等房间空落在效用之外。
--
-- __谎言是无证据断言。__ 'lie' 镜像 'Prax.Rumor.gossip'，带两个反转：说话者必须持有 /无/ 证据
-- （若他们听说自己的谎返回，谎言动作消失，普通八卦出现），且捏造主体从世界提供的条件绑定
-- （你 /能/ 嫁祸谁）而非从信念。效果与八卦相同——受骗者持有真传闻，与真相不可区分，且整个
-- 谣言/声誉栈对虚假未修改地级联。
--
-- __谎言标记撒谎者。__ 唯一残余是撒谎者自身记忆——@\<liar\>.lied.\<hearer\>.\<event\>@，
-- 像所有心智状态一样根于其名下：自有、可遗忘（对其根一次 'Delete'）、随承载者消亡。有意无客观记录：
-- 历史仅经其留下的标记持续，真相可变得不可恢复。洗清若曾创作，经标记承载者流动（坦白、证词），
-- 从不经查阅账本。标记现在买到的是良心：负向评价你自己 @lied@ 标记的特质（"Prax.Persona"）是不撒谎的理由。
module Prax.Deceit
  ( conceal
  , lie
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..))
import           Prax.Types (Action, Outcome (..), Want (..), action, authoredVarClash, authoredPatClash)
import           Prax.Beliefs (beliefAbout)
import           Prax.Witness (CoPresence, asRole)

-- | 无人相信 @event@ 的欲望——秘密值多少由权重给出。
conceal :: String -> Int -> Want
conceal event k
  | any isVariable (pathNames event) =
      error ("conceal: event " ++ show event
             ++ " must be variable-free (a concealment want quantifies over"
             ++ " observers, not deeds)")
  | otherwise = Want [ Absent [ Match (beliefAbout "Anyone" event) ] ] k

-- | 一个动作：向同场听者断言你无证据的事件（捏造）。
lie :: CoPresence   -- ^ who can be told
    -> [Condition]  -- ^ the world's gate (may be @[]@)
    -> [Condition]  -- ^ fabrication: binds the pattern's variables
    -> String       -- ^ event pattern, e.g. @"stole.Culprit.loaf"@
    -> String       -- ^ action label
    -> Action
lie copresence gate fabrication pat label
  | (v : _) <- offenders =
      error ("Prax.Deceit.lie: " ++ show v ++ " in an authored gate, fabrication,"
             ++ " or event pattern -- the Prax namespace is reserved for machinery")
  | otherwise =
      action label conds
        [ Insert (beliefAbout "Hearer" pat ++ ".heard.Actor")
          -- the liar's own memory of the deed — a mark on their psyche, rooted
          -- under their name like all mental state; there is no world ledger
        , Insert ("Actor.lied.Hearer." ++ pat) ]
  where
    offenders = authoredVarClash [] (gate ++ fabrication) [] ++ authoredPatClash [] (pathNames pat)
    subject = case filter isVariable (pathNames pat) of
      (v : _) -> v
      []      -> error ("lie: event pattern " ++ show pat
                        ++ " names no one (a lie is about someone)")
    conds =
      fabrication
      ++ [ Neq subject "Actor"
         , Absent [ Match (beliefAbout "Actor" pat) ] ]   -- no evidence: what makes it a lie
      ++ asRole "Hearer" copresence
      ++ [ Neq "Hearer" "Actor"
         , Neq "Hearer" subject
         , Absent [ Match (beliefAbout "Hearer" pat ++ ".seen") ]
         , Not (beliefAbout "Hearer" pat ++ ".heard.Actor") ]
      ++ gate
