-- | 叠在 'Prax.Db.unify' 上的条件语言。
--
-- Praxish 的 @Praxish.query@ 的类型化重建（其 @praxish.js@ 把条件编码为空白切分字符串；我们改用
-- 'Condition' ADT）。查询是从左到右求值的合取条件列表，串过增长的变量绑定集（来自 'unify' 的
-- 列表单子非确定性）。
--
-- 操作数字符串遵循语言的变量约定：首字符大写的操作数是逻辑变量（对照当前绑定解析），否则是
-- 字面常量。当比较的操作数无法解析（未绑定变量）时，该绑定简单地未通过条件并被丢弃——DSL 的
-- 定义行为，匹配 Praxish（例如井字棋平局动作依赖它）。不能依赖运行时状态的结构错误（子查询
-- 嵌套在子查询内）大声崩溃。
--
-- 'Condition' 本身保持字符串创作（DSL 作者书写）；其煮熟镜像 'CookedCondition' 把每个操作数
-- 携带为 interned 'Prax.Sym.Sym'（规格 @docs/specs/2026-07-12-v29-interning.md@）——热求值器
-- （'queryCooked'）在查询时从不解析或再 intern 名称。
module Prax.Query
  ( CmpOp(..)
  , CalcOp(..)
  , Condition(..)
  , forAll
  , implies
  , groundCondition
  , conditionVars
  , condSents
  , query
  , satisfies
  , countSatisfying
  , CookedCondition(..)
  , cookCondition
  , cookedReadAnchors
  , groundNames
  , groundCookedCondition
  , queryCooked
  ) where

import           Data.List (nub)
import qualified Data.Map.Strict as Map
import           Text.Read (readMaybe)

import           Prax.Db
import           Prax.Sym (Sym, intern, symIsVar, symName)

-- | 数值比较运算符（@lt@、@lte@、@gt@、@gte@）。
data CmpOp = Lt | Lte | Gt | Gte
  deriving (Eq, Show)

-- | 'Calc' 的二元整数算子（@add@、@sub@、@mul@、@mod@；Praxish 有意省略除法以保持 DB 整数值——
-- 'Mod' 保留该理由，因为取模本身是整数）。
data CalcOp = Add | Sub | Mul | Mod
  deriving (Eq, Show)

-- | 查询中的单一条件。
data Condition
  = Match String
    -- ^ 裸逻辑句子；对照 DB 统一（扩展绑定）。
  | Not String
    -- ^ 失败即否定：当且仅当句子无匹配时保留绑定。
  | Eq String String
    -- ^ 兼作赋值的相等：若恰一操作数是未绑定变量，则绑定到另一操作数；若两者皆已知，当且仅当相等时保留。
  | Neq String String
    -- ^ 当且仅当两（可解析）操作数不同时保留绑定。
  | Cmp CmpOp String String
    -- ^ 两可解析操作数的数值比较。
  | Calc String CalcOp String String
    -- ^ @Calc result op lhs rhs@：把 @result@ 绑定到 @lhs op rhs@（整数）。
  | Count String String
    -- ^ @Count result setVar@：把 @result@ 绑定到集合值变量的大小。
  | Subquery
      { subSet   :: String     -- ^ 绑定到结果集合的变量
      , subFind  :: [String]   -- ^ 从每个子结果投影出的变量
      , subWhere :: [Condition] -- ^ 子查询的条件
      }
    -- ^ 跑嵌套查询并把 @subSet@ 绑定到投影行列表。
  | Or [[Condition]]
    -- ^ 析取：至少一个子句（各为合取）成立。/生成器/——它合并每个满足子句的（去重）绑定，因此析取前置条件
  -- 可从任一侧绑定变量。
  | Absent [Condition]
    -- ^ 整段合取上的失败即否定：当且仅当内部合取无解时保留绑定。把 'Not' 从单句推广到 @¬(compound)@——
  -- 例如 @Absent [Match "leader.X", Match "X.sex!male"]@ 是「没有男性领袖」（@¬∃@）。
  | Exists [Condition]
    -- ^ 'Absent' 的对偶：当且仅当内部合取 /有/ 解时保留绑定，丢弃见证（布尔 @∃@，既不泄漏也不在下游倍增绑定）。
  deriving (Eq, Show)

-- | 全称量化：对 @guard@ 的每个绑定，@body@ 成立（@∀ x. guard(x) → body(x)@）。定义为「不存在使 @body@
-- 失败的 @guard@-绑定」。例如 @forAll [Match "patron.X"] [Match "happy.X"]@。
forAll :: [Condition] -> [Condition] -> Condition
forAll guard body = Absent (guard ++ [Absent body])

-- | 实质蕴涵 @a → b@（命题：从当前绑定看 @a@ 不可满足，或 @b@ 成立）。
implies :: [Condition] -> [Condition] -> Condition
implies a b = Or [ [Absent a], b ]

-- | 把绑定代入条件的每个句子\/操作数。绑定中不存在的变量留给查询去量化。
groundCondition :: Bindings -> Condition -> Condition
groundCondition b c = case c of
  Match s          -> Match (ground s b)
  Not s            -> Not (ground s b)
  Eq x y           -> Eq (ground x b) (ground y b)
  Neq x y          -> Neq (ground x b) (ground y b)
  Cmp op x y       -> Cmp op (ground x b) (ground y b)
  Calc r op x y    -> Calc (ground r b) op (ground x b) (ground y b)
  Count r s        -> Count (ground r b) (ground s b)
  Subquery s f w   -> Subquery (ground s b) (map (`ground` b) f) (map (groundCondition b) w)
  Or clauses       -> Or (map (map (groundCondition b)) clauses)
  Absent cs        -> Absent (map (groundCondition b) cs)
  Exists cs        -> Exists (map (groundCondition b) cs)

-- | 条件 /提及/ 的每个名字——对每个构造器的全行走，含子查询内部（对其所绑定之物的过近似：例如
-- 'Eq'\/'Neq'\/'Cmp'\/'Calc'\/'Count' 操作数是名字，未必是变量）。
conditionVars :: Condition -> [String]
conditionVars c = case c of
  Match s          -> pathNames s
  Not s            -> pathNames s
  Absent cs        -> concatMap conditionVars cs
  Exists cs        -> concatMap conditionVars cs
  Or cls           -> concatMap (concatMap conditionVars) cls
  Subquery v f w   -> v : f ++ concatMap conditionVars w
  Eq a b           -> [a, b]
  Neq a b          -> [a, b]
  Cmp _ a b        -> [a, b]
  Calc v _ a b     -> [v, a, b]
  Count v s        -> [v, s]

-- | 条件列表提及的每个 /句子字符串/——原始创作路径（'Match'\/'Not' 操作数，递归经
-- 'Absent'\/'Exists'\/'Or'\/'Subquery'），相对于 'conditionVars' 的名字行走。
condSents :: [Condition] -> [String]
condSents = concatMap go
  where
    go (Match s)        = [s]
    go (Not s)          = [s]
    go (Absent cs)      = condSents cs
    go (Exists cs)      = condSents cs
    go (Or clauses)     = concatMap condSents clauses
    go (Subquery _ _ w) = condSents w
    go _                = []

-- | 'Condition' 的煮熟镜像：每个操作数在煮时预 intern 为 'Sym'——'Match'\/'Not' 的句子预拆分
-- （'Prax.Db.pathNames'）并 intern；其他构造器的名字操作数同样。热路径查询从不重解析创作句子。
data CookedCondition
  = CMatch [Sym]
  | CNot [Sym]
  | CEq Sym Sym
  | CNeq Sym Sym
  | CCmp CmpOp Sym Sym
  | CCalc Sym CalcOp Sym Sym
  | CCount Sym Sym
  | CSubquery Sym [Sym] [CookedCondition]
  | COr [[CookedCondition]]
  | CAbsent [CookedCondition]
  | CExists [CookedCondition]
  deriving (Eq, Show)

-- | 把 'Condition' 编译为其煮熟形式（见 'CookedCondition'）。
cookCondition :: Condition -> CookedCondition
cookCondition c = case c of
  Match s          -> CMatch (map intern (pathNames s))
  Not s            -> CNot (map intern (pathNames s))
  Eq x y           -> CEq (intern x) (intern y)
  Neq x y          -> CNeq (intern x) (intern y)
  Cmp op x y       -> CCmp op (intern x) (intern y)
  Calc r op x y    -> CCalc (intern r) op (intern x) (intern y)
  Count r s        -> CCount (intern r) (intern s)
  Subquery s f w   -> CSubquery (intern s) (map intern f) (map cookCondition w)
  Or clauses       -> COr (map (map cookCondition) clauses)
  Absent cs        -> CAbsent (map cookCondition cs)
  Exists cs        -> CExists (map cookCondition cs)

-- | 代入单个符号：当且仅当它 'symIsVar' 且已绑定（经 'valToSym'）时替换，否则原样。Sym 级规则
-- 'Prax.Db.groundTokens' 按 token 应用。
substSym :: Bindings -> Sym -> Sym
substSym b n
  | symIsVar n = maybe n valToSym (Map.lookup n b)
  | otherwise  = n

-- | 把绑定代入符号列表——无字符串往返。
groundNames :: Bindings -> [Sym] -> [Sym]
groundNames b = map (substSym b)

-- | 把绑定代入煮熟条件，镜像 'groundCondition'。
groundCookedCondition :: Bindings -> CookedCondition -> CookedCondition
groundCookedCondition b c = case c of
  CMatch ns        -> CMatch (groundNames b ns)
  CNot ns          -> CNot (groundNames b ns)
  CEq x y          -> CEq (substSym b x) (substSym b y)
  CNeq x y         -> CNeq (substSym b x) (substSym b y)
  CCmp op x y      -> CCmp op (substSym b x) (substSym b y)
  CCalc r op x y   -> CCalc (substSym b r) op (substSym b x) (substSym b y)
  CCount r s       -> CCount (substSym b r) (substSym b s)
  CSubquery s f w  -> CSubquery (substSym b s) (map (substSym b) f) (map (groundCookedCondition b) w)
  COr clauses      -> COr (map (map (groundCookedCondition b)) clauses)
  CAbsent cs       -> CAbsent (map (groundCookedCondition b) cs)
  CExists cs       -> CExists (map (groundCookedCondition b) cs)

-- | 煮熟条件查询在任意极性可查阅的每个 DB 路径——含 Or\/Absent\/Exists\/Subquery 内。构造上完整：
-- CEq\/CNeq\/CCmp\/CCalc 比较已绑定值（不读 DB）；CCount 读集合变量（已是值）。仅匹配形构造器贡献锚点。
cookedReadAnchors :: [CookedCondition] -> [[Sym]]
cookedReadAnchors = concatMap go
  where
    go c = case c of
      CMatch p         -> [p]
      CNot p           -> [p]
      COr clauses      -> concatMap cookedReadAnchors clauses
      CAbsent cs       -> cookedReadAnchors cs
      CExists cs       -> cookedReadAnchors cs
      CSubquery _ _ ws -> cookedReadAnchors ws
      CEq {}           -> []
      CNeq {}          -> []
      CCmp {}          -> []
      CCalc {}         -> []
      CCount {}        -> []

-- | 从起始绑定求值合取条件列表，产出满足全部条件的每个一致绑定。
query :: Db -> [Condition] -> Bindings -> [Bindings]
query = queryWith False

-- | 煮熟条件查询入口：等价于 'query'，但每个操作数已是 intern 的 'Sym'（见 'CookedCondition'）——热路径
-- 从不重解析或重 intern 创作句子。
queryCooked :: Db -> [CookedCondition] -> Bindings -> [Bindings]
queryCooked = queryCookedWith False

-- | 当且仅当条件从给定绑定可满足时为真。
satisfies :: Db -> [Condition] -> Bindings -> Bool
satisfies db conds b = not (null (query db conds b))

-- | 满足条件的一致绑定数（用于效用打分：want 对每个满足实例计分一次）。
countSatisfying :: Db -> [Condition] -> Bindings -> Int
countSatisfying db conds b = length (query db conds b)

-- The Bool flag marks whether we are already inside a subquery (subqueries may
-- not nest).
queryWith :: Bool -> Db -> [Condition] -> Bindings -> [Bindings]
queryWith inSub db conds b0 = foldl step [b0] conds
  where
    step matches cond = case cond of
      -- parse the pattern once per condition, not once per binding
      Match s -> let names = pathNames s
                 in concatMap (unifyNames names db) matches
      Not s   -> let names = pathNames s
                 in concatMap (\b -> [ b | null (unifyNames names db b) ]) matches
      _       -> concatMap (evalCond inSub db cond) matches

evalCond :: Bool -> Db -> Condition -> Bindings -> [Bindings]
evalCond _ db (Match s) b = unify s db b
evalCond _ db (Not s)   b = [b | null (unify s db b)]

evalCond _ _ (Eq lhs rhs) b =
  case (resolveName b lhs, resolveName b rhs) of
    (Just l, Just r)   -> [b | valToSym l == valToSym r]
    (Just l, Nothing)  -> [Map.insert (intern rhs) l b]   -- rhs is an unbound variable
    (Nothing, Just r)  -> [Map.insert (intern lhs) r b]   -- lhs is an unbound variable
    (Nothing, Nothing) -> []                              -- unresolvable: fail the binding

evalCond _ _ (Neq lhs rhs) b =
  case (resolveName b lhs, resolveName b rhs) of
    (Just l, Just r) -> [b | valToSym l /= valToSym r]
    _                -> []

evalCond _ _ (Cmp op lhs rhs) b =
  case (resolveName b lhs >>= num, resolveName b rhs >>= num) of
    (Just l, Just r) -> [b | applyCmp op l r]
    _                -> []

evalCond _ _ (Calc result op lhs rhs) b =
  case (resolveName b lhs >>= num, resolveName b rhs >>= num) of
    (Just l, Just r) -> [Map.insert (intern result) (VNum (applyCalc op l r)) b]
    _                -> []

evalCond _ _ (Count result setVar) b =
  case resolveName b setVar of
    Just (VSet xs) -> [Map.insert (intern result) (VNum (fromIntegral (length xs))) b]
    _              -> []

evalCond inSub db (Subquery setVar find conds) b
  | inSub = error "Prax.Query: subquery nested inside a subquery"
  | otherwise =
      let results = queryWith True db conds b
          rows = [ [ maybe (intern lvar) valToSym (Map.lookup (intern lvar) r) | lvar <- find ]
                 | r <- results ]
      in [Map.insert (intern setVar) (VSet rows) b]

evalCond inSub db (Or clauses) b =
  nub (concat [ queryWith inSub db clause b | clause <- clauses ])
evalCond inSub db (Absent conds) b = [ b | null  (queryWith inSub db conds b) ]
evalCond inSub db (Exists conds) b = [ b | not (null (queryWith inSub db conds b)) ]

-- The cooked mirror of 'queryWith': same fold, same left-to-right threading,
-- same 'CMatch'/'CNot' hoist-per-condition (already split and interned, so
-- no parsing or interning needed here at all).
queryCookedWith :: Bool -> Db -> [CookedCondition] -> Bindings -> [Bindings]
queryCookedWith inSub db conds b0 = foldl step [b0] conds
  where
    step matches cond = case cond of
      CMatch names -> concatMap (unifySyms names db) matches
      CNot names   -> concatMap (\b -> [ b | null (unifySyms names db b) ]) matches
      _            -> concatMap (evalCookedCond inSub db cond) matches

-- The cooked mirror of 'evalCond': case-for-case, recursing through the
-- cooked evaluator with the same in-subquery flag semantics.
evalCookedCond :: Bool -> Db -> CookedCondition -> Bindings -> [Bindings]
evalCookedCond _ db (CMatch names) b = unifySyms names db b
evalCookedCond _ db (CNot names)   b = [b | null (unifySyms names db b)]

evalCookedCond _ _ (CEq lhs rhs) b =
  case (resolve b lhs, resolve b rhs) of
    (Just l, Just r)   -> [b | valToSym l == valToSym r]
    (Just l, Nothing)  -> [Map.insert rhs l b]
    (Nothing, Just r)  -> [Map.insert lhs r b]
    (Nothing, Nothing) -> []

evalCookedCond _ _ (CNeq lhs rhs) b =
  case (resolve b lhs, resolve b rhs) of
    (Just l, Just r) -> [b | valToSym l /= valToSym r]
    _                -> []

evalCookedCond _ _ (CCmp op lhs rhs) b =
  case (resolve b lhs >>= num, resolve b rhs >>= num) of
    (Just l, Just r) -> [b | applyCmp op l r]
    _                -> []

evalCookedCond _ _ (CCalc result op lhs rhs) b =
  case (resolve b lhs >>= num, resolve b rhs >>= num) of
    (Just l, Just r) -> [Map.insert result (VNum (applyCalc op l r)) b]
    _                -> []

evalCookedCond _ _ (CCount result setVar) b =
  case resolve b setVar of
    Just (VSet xs) -> [Map.insert result (VNum (fromIntegral (length xs))) b]
    _              -> []

evalCookedCond inSub db (CSubquery setVar find conds) b
  | inSub = error "Prax.Query: subquery nested inside a subquery"
  | otherwise =
      let results = queryCookedWith True db conds b
          rows = [ [ maybe lvar valToSym (Map.lookup lvar r) | lvar <- find ]
                 | r <- results ]
      in [Map.insert setVar (VSet rows) b]

evalCookedCond inSub db (COr clauses) b =
  nub (concat [ queryCookedWith inSub db clause b | clause <- clauses ])
evalCookedCond inSub db (CAbsent conds) b = [ b | null  (queryCookedWith inSub db conds b) ]
evalCookedCond inSub db (CExists conds) b = [ b | not (null (queryCookedWith inSub db conds b)) ]

-- Resolve a String operand: interns it, then resolves as a Sym (see
-- 'resolve'). The uncooked ('Condition') evaluator's only interning site —
-- the cooked evaluator never needs it, its operands are already 'Sym's.
resolveName :: Bindings -> String -> Maybe Val
resolveName b = resolve b . intern

-- Resolve an operand: an uppercase-initial symbol is a variable (look it up
-- in the bindings), otherwise it is a literal constant. Returns Nothing for
-- an unbound variable.
resolve :: Bindings -> Sym -> Maybe Val
resolve b s
  | symIsVar s = Map.lookup s b
  | otherwise  = Just (VSym s)

-- Numbers intern like any other segment: a numeric literal is a constant
-- Sym, rendered back to text (via 'symName') only where the arithmetic
-- itself genuinely needs a String to parse.
num :: Val -> Maybe Integer
num (VNum n) = Just n
num (VSym s) = readMaybe (symName s)
num (VSet _) = Nothing

applyCmp :: CmpOp -> Integer -> Integer -> Bool
applyCmp Lt  = (<)
applyCmp Lte = (<=)
applyCmp Gt  = (>)
applyCmp Gte = (>=)

applyCalc :: CalcOp -> Integer -> Integer -> Integer
applyCalc Add = (+)
applyCalc Sub = (-)
applyCalc Mul = (*)
applyCalc Mod = mod
