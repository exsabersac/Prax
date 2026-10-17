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

-- | Binary integer operators for 'Calc' (@add@, @sub@, @mul@, @mod@; Praxish
-- omits division deliberately to keep the DB integer-valued — 'Mod'
-- preserves that rationale, since modulo is itself integral. 'Mod' uses
-- Haskell's @mod@: the result carries the divisor's sign, so it is
-- non-negative for a positive modulus (e.g. @(-3) \`mod\` 5 == 2@).
data CalcOp = Add | Sub | Mul | Mod
  deriving (Eq, Show)

-- | 查询中的单一条件。
data Condition
  = Match String
    -- ^ A bare logic sentence; unified against the DB (extends bindings).
  | Not String
    -- ^ Negation as failure: keep the binding iff the sentence has no match.
  | Eq String String
    -- ^ Equality that doubles as assignment: if exactly one operand is an
    -- unbound variable, bind it to the other; if both are known, keep iff equal.
  | Neq String String
    -- ^ Keep the binding iff the two (resolvable) operands differ.
  | Cmp CmpOp String String
    -- ^ Numeric comparison of two resolvable operands.
  | Calc String CalcOp String String
    -- ^ @Calc result op lhs rhs@: bind @result@ to @lhs op rhs@ (integers).
  | Count String String
    -- ^ @Count result setVar@: bind @result@ to the size of a set-valued var.
  | Subquery
      { subSet   :: String     -- ^ variable to bind to the resulting set
      , subFind  :: [String]   -- ^ variables projected out of each sub-result
      , subWhere :: [Condition] -- ^ the sub-query's conditions
      }
    -- ^ Run a nested query and bind @subSet@ to the list of projected rows.
  | Or [[Condition]]
    -- ^ Disjunction: at least one clause (each a conjunction) holds. A
    -- /generator/ — it unions the (deduplicated) bindings from every satisfying
    -- clause, so a disjunctive precondition can bind variables from either side.
  | Absent [Condition]
    -- ^ Negation-as-failure over a whole conjunction: keep the binding iff the
    -- inner conjunction has no solution. Generalizes 'Not' from a single
    -- sentence to @¬(compound)@ — e.g. @Absent [Match "leader.X", Match "X.sex!male"]@
    -- is "there is no male leader" (@¬∃@).
  | Exists [Condition]
    -- ^ Dual of 'Absent': keep the binding iff the inner conjunction /has/ a
    -- solution, discarding the witnesses (a boolean @∃@ that neither leaks nor
    -- multiplies bindings downstream).
  deriving (Eq, Show)

-- | Universal quantification: for every binding of @guard@, @body@ holds
-- (@∀ x. guard(x) → body(x)@). Defined as "there is no @guard@-binding for which
-- @body@ fails". E.g. @forAll [Match "patron.P"] [Match "P.hasDrink"]@ = "every
-- patron has a drink".
forAll :: [Condition] -> [Condition] -> Condition
forAll guard body = Absent (guard ++ [Absent body])

-- | Material implication @a → b@ (propositional: either @a@ is unsatisfiable
-- from the current binding, or @b@ holds).
implies :: [Condition] -> [Condition] -> Condition
implies a b = Or [ [Absent a], b ]

-- | Substitute bindings into every sentence/operand of a condition. Variables
-- not present in the bindings are left for the query to quantify.
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

-- | Every name a condition /mentions/ — a total walk over every constructor,
-- including subquery internals (an over-approximation of what it binds: e.g.
-- 'Eq'\/'Neq'\/'Cmp'\/'Calc'\/'Count' operands are listed whether they are
-- variables or literal constants). The shared home for reserved-variable
-- guards ('Prax.Engine.setSchedule', 'Prax.Rng.draw') and similar checks that
-- need every name a condition could touch, not just its free variables.
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

-- | Every /sentence string/ a condition list mentions — the raw authored paths
-- ('Match'\/'Not' operands, recursing through 'Absent'\/'Exists'\/'Or'\/
-- 'Subquery'), as opposed to 'conditionVars''s split-and-flattened names. The
-- shared home for path-family checks that must inspect the head segment (e.g.
-- 'Prax.TypeCheck''s reserved-family scan and 'Prax.Script''s patience-marker
-- namespace guard).
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

-- | The cooked mirror of 'Condition': every operand is pre-interned to a
-- 'Sym' at cook time — 'Match'\/'Not''s sentence is pre-split
-- ('Prax.Db.pathNames') and interned; every other constructor's name
-- operands (variable or constant) are interned the same way. 'evalCookedCond'
-- never parses or interns a name at query time.
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

-- | Compile a 'Condition' to its cooked form (see 'CookedCondition').
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

-- | Substitute a single symbol: replaced iff it 'symIsVar' and bound (via
-- 'valToSym'), otherwise left as-is. The Sym-level rule 'Prax.Db.groundTokens'
-- applies per token.
substSym :: Bindings -> Sym -> Sym
substSym b n
  | symIsVar n = maybe n valToSym (Map.lookup n b)
  | otherwise  = n

-- | Substitute bindings into a list of symbols — no string round trip.
groundNames :: Bindings -> [Sym] -> [Sym]
groundNames b = map (substSym b)

-- | Substitute bindings into a cooked condition, mirroring 'groundCondition'.
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

-- | Every DB path a cooked-condition query can consult, at any polarity —
-- including inside Or\/Absent\/Exists\/Subquery. Complete by construction:
-- CEq\/CNeq\/CCmp\/CCalc compare already-bound values and CCount measures a
-- bound set (produced by a CSubquery, whose inner conditions ARE walked), so
-- none of them reads a path this walk misses.
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

-- | Evaluate a conjunctive list of conditions from a starting binding, yielding
-- every consistent binding that satisfies them all.
query :: Db -> [Condition] -> Bindings -> [Bindings]
query = queryWith False

-- | The cooked-condition query entry: equivalent to 'query' but every
-- operand is already an interned 'Sym' (see 'CookedCondition') — the hot
-- path never re-parses or re-interns an authored sentence/name.
queryCooked :: Db -> [CookedCondition] -> Bindings -> [Bindings]
queryCooked = queryCookedWith False

-- | True iff the conditions are satisfiable from the given binding.
satisfies :: Db -> [Condition] -> Bindings -> Bool
satisfies db conds b = not (null (query db conds b))

-- | Number of consistent bindings satisfying the conditions (used for utility
-- scoring: a want scores once per satisfying instantiation).
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
