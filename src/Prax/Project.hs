-- | 事业（Endeavors）：作为部件集的长视界行为。
--
-- 项目 __类型__ 是创作词汇（像实践、事迹与欲望）；项目 __实例__ 在已处置角色的 planner 选择承担
-- 动作时涌现。追求是计数所有者完成部件的命名 'Desire' ——无实例时 __休眠__（零绑定、零效用），
-- 这是已处置角色永久携带它、承担打开它的方式：带条件 wants /就是/ 可注入 wants。
--
-- 进展本身有回报（每完成部件 +w——创作权重是此角色对此类工作的投入程度），因此视界长度无关：
-- 每个下一步部件对普通 planner 局部可见。agent 追求因为追求有回报，非因为 planner 从手段导出目的——
-- 无论如何是对承诺的更真模型。
--
-- 计划是部件集合，非线性链：部件独立并行完成，且成功不必全部。无单一数字编码进展，因此完成部件
-- 事实集是主状态——线性光标已去。拓扑以两种方式创作：'partAfter' 命名必须先完成的兄弟部件
-- （经验证、私有编译的依赖边），'partNeeds' 携带世界资源与真正阈值门禁（原始条件——账本族上的
-- @Subquery@\/@Count@\/@Cmp@ 表达「任 5 中 3 完成时触发」）。收官部件的 'partAfter' 命名
-- 必需部件；可选部件挂在旁边，各取时 +w，从不阻塞。
--
-- 完成部件写入按部件完成账本（@practice.\<pid\>.Owner.did.\<partName\>@）——正当基础设施，
-- 非世界可见虚构：带并行/可选部件时进展是集合，统一账本族是一个 'Want' 唯一诚实的可计数形式。
-- 账本条目兼作一次守卫，因此每个部件每实例触发一次（声明边界——可重复/计数部件已搁置）。完成应
-- 为世界可见虚构的部件也经 'partYields' 写真实事迹（@swept.Actor@，被目击）——账本与虚构是
-- 分职的分离事实。
--
-- 因为追求是命名欲望，项目是心智理论内容（"Prax.Minds"）：谁开始相信你追求一个，就预测你下一个
-- 可用部件。把 'Prax.Witness.witnessed' 放进 'partYields' 使部件公开。
module Prax.Project
  ( Part (..)
  , endeavor
  ) where

import           Data.List (nub, (\\))

import           Prax.Query (Condition (..))
import           Prax.Types

-- | One moving part of the work: its ledger key, action label, the sibling
-- parts it depends on, what the world must provide, and what completing it
-- does to the world (beyond writing the ledger).
data Part = Part
  { partName   :: String       -- ^ single path segment; the ledger key
  , partLabel  :: String       -- ^ action label
  , partAfter  :: [String]     -- ^ dependency edges: sibling part names
  , partNeeds  :: [Condition]  -- ^ world resources; threshold gates
  , partYields :: [Outcome]
  }

-- | An authored endeavor: the undertake action (for the world to slot into
-- one of its own practices), the part-set practice, and the named pursuit
-- desire (for the world's vocabulary). One instance per owner; a finished
-- instance persists as the record of the work.
--
-- The undertake and the parts live in /different/ practices, so an endeavor
-- owner must not be 'charBoundTo' a single practice — a bound character could
-- undertake but never complete a part (or vice versa). Only bodiless
-- mechanism characters are ever bound; keep it that way for owners.
--
-- Every 'partAfter' name is validated against the actual part set — a dangling
-- or misspelled edge is a LOUD construction error, as is a name that forms or
-- feeds a cycle (the whole endeavor would be silently unreachable). The
-- fact-path convention is PRIVATE: the compiler builds the ledger conditions
-- itself, so a typo'd edge cannot fail silently as a never-available part.
endeavor :: String        -- ^ project id (a single path segment)
         -> Int           -- ^ pursuit weight: +w per completed part
         -> String        -- ^ undertake label
         -> [Condition]   -- ^ undertake gate (may be @[]@)
         -> [Part]
         -> (Action, Practice, Desire)
endeavor pid w ulabel gate parts
  | null parts =
      error ("endeavor: " ++ show pid ++ " has no parts (an endeavor is work)")
  | any (`elem` (".!" :: String)) pid =
      error ("endeavor: id " ++ show pid ++ " must be a single path segment")
  | (n : _) <- [ n | n <- names, any (`elem` (".!" :: String)) n ] =
      error ("endeavor " ++ show pid ++ ": part name " ++ show n
             ++ " must be a single path segment (it keys the ledger)")
  | (n : _) <- names \\ nub names =
      error ("endeavor " ++ show pid ++ ": duplicate part name " ++ show n)
  | ((p, e) : _) <- [ (partName p, e) | p <- parts
                    , e <- partAfter p, e `notElem` names ] =
      error ("endeavor " ++ show pid ++ ": part " ++ show p
             ++ " depends on " ++ show e ++ ", which is not a part")
  | (v : _) <- concat [ authoredVarClash [] (partNeeds p) (partYields p)
                      | p <- parts ] =
      error ("endeavor " ++ show pid ++ ": part authors " ++ show v
             ++ " -- the Prax namespace is reserved")
  | (n : _) <- filter (`notElem` reachable) names =
      error ("endeavor " ++ show pid ++ ": part " ++ show n
             ++ " is unreachable (its dependency edges form or feed a cycle)")
  | otherwise = (undertake, proj, pursuit)
  where
    names = map partName parts
    -- Transitive reachability from the edge-free roots (fixpoint). A part is
    -- reachable iff all its edges point to reachable parts; a graph with no
    -- edge-free node contains a cycle, and every cycle participant or
    -- dependent is unreachable — so reachability from the roots IS complete
    -- cycle detection.
    reachable = go [ partName p | p <- parts, null (partAfter p) ]
      where
        go acc =
          let acc' = nub (acc ++ [ partName p | p <- parts
                                 , all (`elem` acc) (partAfter p) ])
          in if length acc' == length acc then acc else go acc'
    inst suffix = "practice." ++ pid ++ suffix
    ledger n = inst (".Owner.did." ++ n)
    undertake = action ulabel (gate ++ [ Not (inst ".Actor") ])
                  [ Insert (inst ".Actor") ]
    -- No instance-fact Match and no init seed: instance existence and Owner's
    -- binding ride the practice-instance ENUMERATION (the undertake fact's
    -- trie node — 'Prax.Engine.possibleActions' unifies the practice's
    -- instance names against it), so a part's gate needs only ownership, its
    -- once-guard, its edges, and its needs.
    partAction p = action (partLabel p)
      ([ Eq "Actor" "Owner", Not (ledger (partName p)) ]
       ++ [ Match (ledger d) | d <- partAfter p ]
       ++ partNeeds p)
      (Insert (ledger (partName p)) : partYields p)
    proj = practice
      { practiceId   = pid
      , practiceName = "[Owner] pursues " ++ pid
      , roles        = ["Owner"]
      , initOutcomes = []
      , actions      = map partAction parts }
    pursuit = Desire ("pursues-" ++ pid)
                (Want [ Match (inst ".Owner.did.P") ] w)
