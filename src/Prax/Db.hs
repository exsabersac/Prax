-- | 支撑 Praxis/Versu 的排他逻辑数据库。
--
-- 世界状态是 trie：@data Db = Db Bool Bool (IntMap Db)@，其中第一个 'Bool' 记录
-- 节点出边是否为 __排他__，第二个记录节点自身是否被 __断言__ 为事实（相对仅作为
-- 更深事实下的脚手架存在），'IntMap' 键是 interned 段 id（'Prax.Sym.symId'；规格
-- @docs/specs/2026-07-12-v29-interning.md@）。每个事实是由两个运算符构成的路径——
-- @.@（普通、多值下钻）与 @!@（排他：父节点恰好一个孩子）。查询对 @.@ 与 @!@ 同等对待，
-- 但区分现 /保留/ 在 trie 中（不只在插入时应用后遗忘），因此世界状态是忠实 Exclusion-Logic
-- 模型——这正是让 'Prax.EL.meet' 从冲突任一侧检测矛盾的原因。'dbToSentences' 展平标签
-- （供显示/匹配）；'dbToLabeledSentences' 再发出它们（供精确序列化）。
--
-- 创作/显示表面（@insert@、@unify@、@exists@、@dbToSentences@、@dbToLabeledSentences@、
-- @ground@、…）保持面向 String——入口 intern、出口渲染——因此世界、测试、'Prax.Persist'
-- 与 'Prax.Inspect' 不受表示变更影响。引擎自身在 'Prax.Sym.Sym' 上计算：'Val'\/'Bindings'
-- 原生携带符号，Sym 级核心（'insertToks'、'retractNames'、'unifySyms'、'groundTokens'、
-- 'tokensToSentence'）导出给已持有切分、interned token 的调用者（煮熟管线——"Prax.Cooked"、
-- "Prax.Query"、"Prax.Derive"），且不得再解析或再渲染。'Sym' id 按首次遭遇排序，因此依赖运行
-- （'Prax.Sym'）；凡旧代码观察 @Map String@ 字母迭代序之处（unify 的未绑定变量分支、'childKeys'），
-- 重写经按 'symName' 排序显式恢复名称序——id（遭遇）序永不可泄漏到候选序或输出。
--
-- 见 @docs/research/praxis-praxish-notes.md@ 与 Praxish @db.js@ 的对应，含纠正后的 @!@ 语义
-- （Praxish 自身的 @insert@ 有标记的丢数据 bug；我们实现论文规则）。
module Prax.Db
  ( Db(..)
  , emptyDb
  , dbExcl
  , dbAsserted
  , Val(..)
  , Bindings
  , valToString
  , valToSym
  , isVariable
  , insert
  , insertToks
  , insertAll
  , retract
  , retractNames
  , unify
  , unifyNames
  , unifySyms
  , unifyAll
  , ground
  , groundTokens
  , tokensToSentence
  , dbToSentences
  , dbToLabeledSentences
  , childKeys
  , exists
  , pathNames
  , tokens
  , internTokens
  ) where

import           Data.Bifunctor (first)
import           Data.Char (isUpper)
import           Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import           Data.List (sort, sortOn)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import           Prax.Sym (Sym, intern, symId, symIsVar, symName, symOfId)

-- | 世界状态：边为 interned 段的 trie。第一个 'Bool' 是节点的 __排他标志__——
-- 边为单值（@!@）时为 'True'；合法排他节点有一个孩子。第二个是节点的
-- __断言标志__——到此节点的路径自身作为事实插入时为 'True'，与是否还有孩子无关
-- （规格 @docs/specs/2026-07-15-v39-asserted-endpoints.md@）。__不变量__
-- （'retractNames' 建立并维护）：trie 从不包含未断言的无子节点——因此「节点存在」
-- 等价于「已断言，或有存活后代」，查询直接读存在性而不查阅该标志。
data Db = Db !Bool !Bool (IntMap Db)
  deriving (Eq, Show)

-- | 节点出边是否排他（@!@）。
dbExcl :: Db -> Bool
dbExcl (Db e _ _) = e

-- | 到节点的路径自身是否被断言为事实（相对仅作为通向更深事实的内部步骤存在）。
dbAsserted :: Db -> Bool
dbAsserted (Db _ a _) = a

emptyDb :: Db
emptyDb = Db False False IntMap.empty

-- | 逻辑变量可绑定到的值。'unify' 只产生 'VSym'（trie 键是符号）；'VNum' 与 'VSet'
-- 来自 "Prax.Query" 中的查询运算符（@calc@、子查询）。
data Val
  = VSym !Sym
  | VNum !Integer
  | VSet ![[Sym]]
  deriving (Eq, Show)

-- | 逻辑变量符号到绑定值的映射——引擎原生计算所用的表示（规格
-- @docs/specs/2026-07-12-v29-interning.md@）；字符串只出现在创作/显示边界。
type Bindings = Map Sym Val

-- | 按 Praxish 的 @DB.ground@/@String()@ 强制方式渲染值：集合塌成不透明 @\<Set(n)\>@ 标记
-- （它们不打算被落地进句子）。
valToString :: Val -> String
valToString (VSym s) = symName s
valToString (VNum n) = show n
valToString (VSet xs) = "<Set(" ++ show (length xs) ++ ")>"

-- | 在落地 Sym-token 位置时值所替换成的符号（'groundTokens'）：已绑定 'VSym' 原样返回（无渲染/重 intern
-- 往返）；其他 'Val' 经 'valToString' 渲染再 intern。构造上与 'valToString' 一致——'Prax.Sym.intern' 是
-- 幂等的，且 'valToString' 对 'VSym' 恰发出 'symName'。
valToSym :: Val -> Sym
valToSym (VSym s) = s
valToSym v         = intern (valToString v)

-- | 路径段当且仅当首字符大写时为变量（Praxish 的 @DB.isVariable@ 约定）。
isVariable :: String -> Bool
isVariable (c:_) = isUpper c
isVariable []    = False

-- Split off leading/trailing ASCII whitespace.
trim :: String -> String
trim = f . f where f = reverse . dropWhile (`elem` " \t\n\r")

-- | 把句子分词为 @(name, punctuationAfterName)@ 对，保留每个名后的运算符（供 'ground' 使用，它必须重发出它们）。
-- 尾随运算符（句子以 @.@\/@!@ 而非名结尾）响亮拒绝：那会把叶的排他标志经无孩子路径设置，留下无断言无孩子节点，
-- 破坏 v39 不变量（规格 @docs/specs/2026-07-15-v39-asserted-endpoints.md@）。
tokens :: String -> [(String, Maybe Char)]
tokens s0 = go (trim s0)
  where
    go [] = []
    go s =
      let (name, rest) = span (\c -> c /= '.' && c /= '!') s
      in case rest of
           []   -> [(name, Nothing)]
           [op] -> error ("Prax.Db.tokens: trailing operator " ++ show op
                          ++ " in " ++ show s0
                          ++ " -- a sentence ends in a name, not an operator")
           (op : more) -> (name, Just op) : go more

-- | 'tokens'，并 intern 每段名——每条计算路径所建基的 Sym 级入口：把创作句子解析成引擎实际统一\/落地\/插入所对的 token。
internTokens :: String -> [(Sym, Maybe Char)]
internTokens = map (first intern) . tokens

-- | 仅名字（两运算符同等对待），用于匹配与撤回。
parseNames :: String -> [String]
parseNames = map fst . tokens

-- | 把句子拆成段名（@.@ 与 @!@ 皆为分隔符）。
pathNames :: String -> [String]
pathNames = parseNames

-- | 把句子插入数据库，带修正后的排他规则。
--
-- 名 @n@ 后的 @!@ 表示 @n@ 单值：插入后 @n@ 恰有一个孩子——下一段。通过清除 @n@ 的 /其他/ 孩子、
-- 同时保留幸存孩子的既有子树来强制（Praxish bug：它擦掉整个子树）。叶节点在插入路径末端被断言
-- （规格 v39）：路径上的祖先是脚手架；仅端点是事实。
insert :: String -> Db -> Db
insert = insertToks . internTokens

-- | 插入已 intern 的 token——Sym 级核心：'insert' 是 @insertToks . internTokens@；煮熟热路径（'Prax.Engine'）
-- 一次构建 token（煮时或在 delta 站点经 'internTokens'）并直接调用本函数，从不重解析或重 intern 句子。
insertToks :: [(Sym, Maybe Char)] -> Db -> Db
insertToks [] (Db e _ m) = Db e True m           -- the endpoint IS a fact: mark it asserted
insertToks ((n, op) : rest) (Db e a m) =
  let i = symId n
      Db _ aOld existing = IntMap.findWithDefault emptyDb i m
      -- @n@'s node is exclusive iff this insert reaches it via a @!@ operator.
      childExcl = op == Just '!'
      cleared = case (op, rest) of
        (Just '!', (nextSym, _) : _) ->
          -- Exclusion: n keeps only the next child, with its subtree intact.
          IntMap.filterWithKey (\k _ -> k == symId nextSym) existing
        _ -> existing
      -- The exclusion flag is overwritten per insert (label-faithful, as
      -- before); the child's asserted mark @aOld@ is carried through the
      -- traversal untouched, so inserting a deeper fact through an asserted
      -- ancestor never unmarks it.
      child' = insertToks rest (Db childExcl aOld cleared)
  in Db e a (IntMap.insert i child' m)

-- | 从左到右插入多个句子。
insertAll :: [String] -> Db -> Db
insertAll ss db = foldl (flip insert) db ss

-- | 撤回：删除路径命名的子树，然后急切剪枝删除留下的每个无断言且无孩子的祖先。
--
-- __不变量__（规格 @docs/specs/2026-07-15-v39-asserted-endpoints.md@）：
-- trie 从不含无断言无孩子节点。断言标志是白名单；剪枝是其维护者。急切剪枝（相对惰性）使
-- 'dbToSentences'/'dbToLabeledSentences' 保持简单，并保证 'Prax.EL.leq'/'meet' 所见的每个节点都有信息负载。
retract :: String -> Db -> Db
retract = retractNames . map intern . parseNames

-- | 句子已拆成 intern 名的 'retract'——供已持有它们的调用方（如煮熟结果）使用，且不得重解析\/重 intern。
retractNames :: [Sym] -> Db -> Db
retractNames [] db = db
retractNames [n] (Db e a m) = Db e a (IntMap.delete (symId n) m)
retractNames (n : ns) (Db e a m) =
  case IntMap.lookup (symId n) m of
    Nothing    -> Db e a m
    Just child ->
      let child' = retractNames ns child
      in if prunable child'
           then Db e a (IntMap.delete (symId n) m)
           else Db e a (IntMap.insert (symId n) child' m)
  where prunable (Db _ asserted cm) = not asserted && IntMap.null cm

-- | 句子已拆成名的 'unify'——供对照许多绑定集求值同一模式的调用方（'Prax.Query' 把解析提升出该循环）。
-- intern 模式名，然后直接委托 'unifySyms'——'Bindings' 已是 Sym 键，故无字符串侧绑定查找。
unifyNames :: [String] -> Db -> Bindings -> [Bindings]
unifyNames names = unifySyms (map intern names)

-- | Sym 级统一核心：经 'IntMap' 查找下降 trie，用奇偶位测试（'Prax.Sym.symIsVar'）做最热谓词。
-- 未绑定变量在当前子树的所有孩子上分支。
--
-- __次序危害__：'IntMap.toList' 产出 id（首次遇见）序，跨运行变化；调用方若依赖绑定序必须显式稳定化
-- （'Prax.Query.queryCooked' 在 'CSubquery' 收集上按名排序）。本函数有意保持遇见序——热路径上排序会昂贵。
unifySyms :: [Sym] -> Db -> Bindings -> [Bindings]
unifySyms syms db0 bindings =
  map snd (foldl step [(db0, bindings)] syms)
  where
    step worlds sym = concatMap (descend sym) worlds
    descend sym (Db _ _ m, b)
      | symIsVar sym =
          case Map.lookup sym b of
            Just v  -> case IntMap.lookup (symId (valToSym v)) m of
                         Just sub -> [(sub, b)]
                         Nothing  -> []
            Nothing ->
              [ (sub, Map.insert sym (VSym (symOfId k)) b)
              | (k, sub) <- sortOn (symName . symOfId . fst) (IntMap.toList m) ]
      | otherwise =
          case IntMap.lookup (symId sym) m of
            Just sub -> [(sub, b)]
            Nothing  -> []

-- | 在既有 @bindings@ 下对照数据库统一一个句子，产出每个一致扩展。未绑定大写段在当前子树所有键上分支
-- （模式匹配核心的列表单子非确定性）；已绑定变量或常量沿键下降。
unify :: String -> Db -> Bindings -> [Bindings]
unify sentence = unifyNames (parseNames sentence)

-- | 合取统一句子列表，贯穿绑定。
unifyAll :: [String] -> Db -> [Bindings]
unifyAll sentences db = foldl step [Map.empty] sentences
  where step bss s = concatMap (unify s db) bss

-- | token 级 'ground'：把绑定代入已拆分、已 intern 的 token。'Prax.Derive.closure' 对每个绑定落地每个公理头一次——
-- 每闭包对头模板分词一次，而非每绑定一次。
--
-- __不变量：__ 代入值作为符号替换其 token；运算符（@.@/@!@）保留自原 token 流。
groundTokens :: [(Sym, Maybe Char)] -> Bindings -> [(Sym, Maybe Char)]
groundTokens toks b = [ (value n, op) | (n, op) <- toks ]
  where
    value n
      | symIsVar n = maybe n valToSym (Map.lookup n b)
      | otherwise  = n

-- | 把 intern 的 token 重发为句子（'internTokens' 的逆，至多修剪）。
tokensToSentence :: [(Sym, Maybe Char)] -> String
tokensToSentence = concatMap emit
  where emit (name, mop) = symName name ++ maybe "" pure mop

-- | 把已绑定变量代回句子，保留 @.@/@!@。
ground :: String -> Bindings -> String
ground sentence b = tokensToSentence (groundTokens (internTokens sentence) b)

-- | 常量点分路径处节点正下方的键，按名排序，路径缺失则为 @[]@。用于枚举已实例化实践。显式排序恢复旧
-- String 键 trie 下 @Map.keys@ 免费给出的东西：'IntMap.keys' 产出 id（遇见）序，跨运行不稳定。
childKeys :: String -> Db -> [String]
childKeys path db = case walk (map intern (parseNames path)) db of
  Just (Db _ _ m) -> sort (map (symName . symOfId) (IntMap.keys m))
  Nothing         -> []
  where
    walk [] d = Just d
    walk (n : ns) (Db _ _ m) = IntMap.lookup (symId n) m >>= walk ns

-- | 给定常量路径上是否存在任何节点。
exists :: String -> Db -> Bool
exists path db = not (null (unify path db Map.empty))

-- | 枚举数据库中的事实，排序，以 @.@ 连接。压平 @.@/@!@ 区分；用于显示、匹配与测试。最终 'sort' 在完全渲染的字符串上操作，
-- 因此无论喂给它的（运行相关）'IntMap' 遍历序如何都安全。
--
-- 事实是 *断言* 端点及其祖先脚手架路径上的断言内部节点（规格 v39）。无断言无孩子节点由 'retract' 的急切剪枝排除。
dbToSentences :: Db -> [String]
dbToSentences = sort . go
  where
    go (Db _ _ m)
      | IntMap.null m = []
      | otherwise     = concatMap expand (IntMap.toList m)
    expand (k, child@(Db _ a cm))
      | IntMap.null cm = [name]
      | a              = name : map ((name ++ ".") ++) (go child)
      | otherwise      = map ((name ++ ".") ++) (go child)
      where name = symName (symOfId k)

-- | 类似 'dbToSentences' 但 __标签忠实__：当父节点排他时每边重发为 @!@，否则 @.@。'insertAll' 的逆——精确序列化
-- （'Prax.Persist'）的基础：断言内部节点在其后代旁发出自有裸标签路径，因此往返保留端点 *与* 脚手架断言。
dbToLabeledSentences :: Db -> [String]
dbToLabeledSentences = sort . go
  where
    go (Db _ _ m) = concat
      [ case go child of
          []   -> [name]
          subs -> [ name ++ sep (dbExcl child) ++ s | s <- subs ]
                  ++ [ name | dbAsserted child ]
      | (k, child) <- IntMap.toList m, let name = symName (symOfId k) ]
    sep e = if e then "!" else "."
