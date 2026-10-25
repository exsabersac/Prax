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
  , endeavorCrew
  , enlist
  , unenlist
  , abandon
  , part
  ) where

import           Data.List (nub, (\\))

import           Prax.Query (Condition (..))
import           Prax.Types

-- | 工作的一个活动部分：其账本键、动作与完成结果。
data Part = Part
  { partName   :: String       -- ^ single path segment; the ledger key
  , partLabel  :: String       -- ^ action label
  , partAfter  :: [String]     -- ^ dependency edges: sibling part names
  , partNeeds  :: [Condition]  -- ^ world resources; threshold gates
  , partYields :: [Outcome]
  }

-- | 部件智能构造器：校验 @name@ 为单路径段（类型综合仍属研究层；此处仅防呆构造）。
part :: String -> String -> [String] -> [Condition] -> [Outcome] -> Part
part name label after needs yields
  | null name || any (`elem` (".!" :: String)) name =
      error ("part: name " ++ show name ++ " must be a single path segment")
  | otherwise = Part name label after needs yields

-- | 创作的事业：承接动作（对行动者）加上各部分，完成记入账本。
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

-- | 放弃进行中的事业实例：子树删除 @practice.<pid>.Actor@（账本一并清除），
-- 重新打开承接。与 ProjectSpec 已钉死的拆卸／进食周期契约相同——本组合子只是把
-- 该拆卸暴露为可创作动作。
-- v72：'endeavorCrew'/'enlist' —— 合作项目：部件门禁于 crew 事实，合伙人可推进同一 Owner 账本。
-- v83：'unenlist' —— Owner 将 Partner 移出 crew。
abandon :: String  -- ^ project id (single path segment)
        -> String  -- ^ action label
        -> Action
abandon pid label
  | null pid || any (`elem` (".!" :: String)) pid =
      error ("abandon: id " ++ show pid ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("practice." ++ pid ++ ".Actor") ]
      [ Delete ("practice." ++ pid ++ ".Actor") ]

-- | 合作事业：承接者写入 @practice.<pid>.Actor@ 与 @.crew.Actor@（自己入队）；
-- 部件门禁 @practice.<pid>.Owner.crew.Actor@，因此 'enlist' 的合伙人可推进同一 Owner 账本。
-- 追求欲望仍计数 Owner 账本——合作是共享进展，非第二实例。
endeavorCrew :: String -> Int -> String -> [Condition] -> [Part]
             -> (Action, Practice, Desire)
endeavorCrew pid w ulabel gate parts
  | null parts =
      error ("endeavorCrew: " ++ show pid ++ " has no parts (an endeavor is work)")
  | any (`elem` (".!" :: String)) pid =
      error ("endeavorCrew: id " ++ show pid ++ " must be a single path segment")
  | (n : _) <- [ n | n <- names, any (`elem` (".!" :: String)) n ] =
      error ("endeavorCrew " ++ show pid ++ ": part name " ++ show n
             ++ " must be a single path segment (it keys the ledger)")
  | (n : _) <- names \\ nub names =
      error ("endeavorCrew " ++ show pid ++ ": duplicate part name " ++ show n)
  | ((p, e) : _) <- [ (partName p, e) | p <- parts
                    , e <- partAfter p, e `notElem` names ] =
      error ("endeavorCrew " ++ show pid ++ ": part " ++ show p
             ++ " depends on " ++ show e ++ ", which is not a part")
  | (v : _) <- concat [ authoredVarClash [] (partNeeds p) (partYields p)
                      | p <- parts ] =
      error ("endeavorCrew " ++ show pid ++ ": part authors " ++ show v
             ++ " -- the Prax namespace is reserved")
  | (n : _) <- filter (`notElem` reachable) names =
      error ("endeavorCrew " ++ show pid ++ ": part " ++ show n
             ++ " is unreachable (its dependency edges form or feed a cycle)")
  | otherwise = (undertake, proj, pursuit)
  where
    names = map partName parts
    reachable = go [ partName p | p <- parts, null (partAfter p) ]
      where
        go acc =
          let acc' = nub (acc ++ [ partName p | p <- parts
                                 , all (`elem` acc) (partAfter p) ])
          in if length acc' == length acc then acc else go acc'
    inst suffix = "practice." ++ pid ++ suffix
    ledger n = inst (".Owner.did." ++ n)
    undertake = action ulabel (gate ++ [ Not (inst ".Actor") ])
                  [ Insert (inst ".Actor")
                  , Insert (inst ".Actor.crew.Actor") ]
    partAction p = action (partLabel p)
      ([ Match (inst ".Owner.crew.Actor"), Not (ledger (partName p)) ]
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

-- | Owner 邀请同场 Partner 入队：写入 @practice.<pid>.Actor.crew.Partner@。
enlist :: String -> String -> Action
enlist pid label
  | null pid || any (`elem` (".!" :: String)) pid =
      error ("enlist: id " ++ show pid ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("practice." ++ pid ++ ".Actor")
      , Match "at.Actor!P"
      , Match "at.Partner!P"
      , Neq "Actor" "Partner"
      , Not ("practice." ++ pid ++ ".Actor.crew.Partner") ]
      [ Insert ("practice." ++ pid ++ ".Actor.crew.Partner") ]

-- | Owner 将 Partner 移出本事业 crew。
unenlist :: String -> String -> Action
unenlist pid label
  | null pid || any (`elem` (".!" :: String)) pid =
      error ("unenlist: id " ++ show pid ++ " must be a single path segment")
  | otherwise = action label
      [ Match ("practice." ++ pid ++ ".Actor")
      , Match ("practice." ++ pid ++ ".Actor.crew.Partner")
      , Neq "Partner" "Actor" ]
      [ Delete ("practice." ++ pid ++ ".Actor.crew.Partner") ]
