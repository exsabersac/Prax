-- | 强制：作为内容无关原语的杠杆。
--
-- __威胁是由欲望使可信的条件意图。__ 'coerce' 生成四动作协议——threaten\/comply\/defy\/punish——
-- 以及表白意图的惩罚性 'Desire'，恰如 "Prax.Blackmail" 对其曝光实例所做，但把 /内容/
-- （什么使威胁可用、服从代价、惩罚做什么、以及勒索者对受罚状态看重什么）提升进 'Coercion' 记录。
-- 勒索是一个实例（"Prax.Blackmail"）；烧谷仓的保护费是另一个（见 @Prax.CoerceSpec@）。
--
-- __证据可选。__ 不像 'Prax.Blackmail.shakedown'（其 threaten 硬编码证据信念且动机计数信者），
-- 原语不拥有那些：触发（含如何到达受害者——当面威胁的共现、缺席时的信）是作者内容，惩罚核——
-- 勒索者看重的状态——是实例所命名的。持有证据的曝光与烧谷仓的报复是同一骨架配不同核。
--
-- __核变量法则。__ 作者写核（'coKernel'）时无 @Prax@ 命名空间变量（v40 拼接守护禁止它们出现在每个
-- 创作字段上）。核按 'coVictim' 的名引用受害者，按普通名引用任何新鲜量词（信者、目击者）。
-- 'coerce' 随后把核 alpha-重命名进 @Prax@ 命名空间，保留运算符（'namespaceKernel'）：受害者 →
-- @PraxD@，每个其他作者引入的、非机制接口名 @Owner@ 的自由变量 → @PraxW@、@PraxW2@、…按首次出现序。
-- 只有重命名后输出是 @Prax@ 命名空间的；作者从不写一个。
--
-- __可信性是三种世界状态（规格 v54 §2）。__ 'threaten' 自身种植受害者恐惧（机制拥有的
-- @believes.desires.\<E\>.punishes-\<id\>@ 存入）；区分情形的是创作世界状态，非标志：
--
--   * __真实__ —— 惩罚性 'Desire'（@punishes-\<id\>@）在世界词汇中注册（'Prax.Engine.setDesires'）
--     且被勒索者持有（'Prax.Types.charDesires'）。威胁是自动机的（v49 可信性）：被违抗时勒索者
--     实际选择惩罚。
--   * __虚张__ —— 已注册但未持有。因为存入是机制拥有的，且受害者被相信欲望解析过滤于 @desires st@
--     （注册词汇，非谁持有），受害者恐惧是真实的且与真实情形相同；勒索者不持惩罚 want，从不选择
--     punish。持有是分离两者的正创作行为——无需标志，且两者都是可检查世界状态。
--   * __事故__ —— 未注册的惩罚名两者皆非：被相信欲望解析悬空，威胁静默惰性。"Prax.TypeCheck" 的
--     'CoercionUnmotivated' 网恰好抓住这个——对注册欲望词汇中缺失之名的已存入 @punishes-*@ 信念——
--     因此真实/虚张对都是挣得的，非对无守卫省略的断言。
module Prax.Coerce
  ( Coercion(..)
  , coerce
  , namespaceKernel
  , punitivePrefix
  ) where

import           Data.List (nub)
import qualified Data.Map.Strict as Map

import           Prax.Db (isVariable, tokens, tokensToSentence)
import           Prax.Sym (intern)
import           Prax.Query (Condition (..), conditionVars)
import           Prax.Types (Action, Desire (..), Outcome (..), Want (..), action,
                             authoredVarClash, isPraxVar)
import           Prax.Beliefs (beliefAbout)

-- | A coercion: the leverage skeleton with its content in named fields.
data Coercion = Coercion
  { coId            :: String       -- ^ single path segment; scopes this coercion's facts
  , coVictim        :: String       -- ^ the victim role variable (see the reserved set)
  , coTrigger       :: [Condition]  -- ^ what makes threatening available, INCLUDING how
                                    -- the victim is reached (co-presence, a letter, …).
                                    -- Must BIND the victim.
  , coThreatenLabel :: String       -- ^ display template for the threaten action
  , coDemandLabel   :: String       -- ^ display template for the comply action
  , coDemand        :: [Outcome]    -- ^ what compliance does
  , coPunishLabel   :: String       -- ^ display template for the punish action
  , coPunishWhen    :: [Condition]  -- ^ EXTRA punish availability (the core gate is
                                    -- mechanism-owned: a standing threat or a defiance)
  , coPunishOuts    :: [Outcome]    -- ^ what punishment does
  , coKernel        :: [Condition]  -- ^ what the extorter VALUES about the punished
                                    -- state, authored with plain variable names
  , coWeight        :: Int          -- ^ the extorter's punitive weight
  , coThreatLasts     :: Maybe Int  -- ^ Nothing = a standing threat (permanent marker);
                                    -- @Just n@ = the threat marker retracts n boundaries
                                    -- after threaten (the DEFIED arm is untouched).
  , coComplianceLasts :: Maybe Int  -- ^ Nothing = bought silence stays bought (permanent
                                    -- @complied@ marker); @Just n@ = the marker expires and
                                    -- the racket cycles — one purchase per bought period.
  }

-- | @coerce coercion@ generates the threaten\/comply\/defy\/punish protocol
-- and the punitive 'Desire' it professes. The 'Desire' must be registered and
-- held (see the module haddock's registration contract).
--
-- Guards, all loud:
--
--   * 'coId' is a single path segment (no @.@\/@!@).
--   * 'coVictim' is not a reserved name — @Actor@\/@E@ (the generated actions'
--     own extorter\/victim roles), @Owner@ (the punitive desire's extorter),
--     @Hearer@, or the @Prax@ namespace. This also CLOSES a latent hole a
--     derive-and-filter design left open: a victim named @Actor@ would have
--     produced an unsatisfiable @Neq Actor Actor@ threaten, silently.
--   * the v40 splice guards on every authored field, each forbidding the
--     names that would CAPTURE in that field's own generated query — which is
--     frame-relative, not uniform: the trigger's own frame already binds
--     Actor to the extorter, so the trigger may name Actor (an
--     evidence-holding condition on the extorter, say); the Prax namespace
--     is reserved on every field regardless of frame.
coerce :: Coercion -> (Desire, [Action])
coerce co
  | any (`elem` (".!" :: String)) sid =
      error ("coerce: id " ++ show sid
             ++ " must be a single path segment (no '.' or '!')")
  | victim `elem` ["Actor", "E", "Owner", "Hearer"] || isPraxVar victim =
      error ("coerce: victim variable " ++ show victim
             ++ " is reserved — Actor and E (the generated actions' own extorter"
             ++ " and victim roles), Owner (the punitive desire's extorter),"
             ++ " Hearer, and the Prax namespace are all mechanism-owned;"
             ++ " pick another name for the victim")
  | (bad : _) <- triggerClash =
      error ("coerce: trigger names " ++ show bad
             ++ ", but the Prax namespace is reserved for the mechanism's own"
             ++ " post-rename output; the trigger may name Actor (the extorter"
             ++ " — its own frame variable, e.g. an evidence-holding condition),"
             ++ " the victim (" ++ show victim ++ "), or any of its own"
             ++ " fresh variables")
  | (bad : _) <- demandClash =
      error ("coerce: demand names " ++ show bad
             ++ ", but in the comply query the victim is Actor and the extorter"
             ++ " is E; the victim variable " ++ show victim
             ++ " is unbound there — refer to the victim as Actor")
  | (bad : _) <- punishClash =
      error ("coerce: punish names " ++ show bad
             ++ ", but E is the victim's frame (comply/defy); the punish query's"
             ++ " extorter is Actor and its victim is " ++ show victim)
  | (bad : _) <- kernelClash =
      error ("coerce: kernel names " ++ show bad
             ++ ", but the kernel's frame is the punitive desire — its extorter"
             ++ " is Owner and its victim is renamed to PraxD; Actor/E and the"
             ++ " Prax namespace are not the kernel's to write")
  | otherwise = (punitive, [threaten, comply, defy, punish])
  where
    sid    = coId co
    victim = coVictim co

    -- Each authored field forbids exactly the mechanism names that would
    -- CAPTURE (silently unify with a name the author didn't intend) in its
    -- OWN generated query. The trigger is the one field where Actor is
    -- already the author's own frame variable (the extorter performing
    -- threaten) rather than something the mechanism binds out from under
    -- them, so naming it — e.g. an evidence-holding condition on the
    -- extorter — is a legitimate frame reference, not a capture; E never
    -- appears in the threaten query at all, so forbidding it would be inert.
    -- Only the Prax namespace (checked automatically by 'authoredVarClash')
    -- is reserved here. comply/defy bind Actor (victim) and E (extorter),
    -- punish binds Actor (extorter) and the literal victim, the desire binds
    -- Owner and PraxD — those guards forbid the frame-unbound names below.
    triggerClash = authoredVarClash [] (coTrigger co) []
    demandClash  = authoredVarClash [victim] [] (coDemand co)
    punishClash  = authoredVarClash ["E"] (coPunishWhen co) (coPunishOuts co)
    kernelClash  = authoredVarClash ["Actor", "E"] (coKernel co) []

    -- Fact conventions, id-scoped so multiple coercions coexist.
    threatPath  extorter v = "threatened." ++ sid ++ "." ++ extorter ++ "." ++ v
    defiedPath  v extorter = "defied." ++ sid ++ "." ++ v ++ "." ++ extorter
    compliedPath extorter v = "complied." ++ sid ++ "." ++ extorter ++ "." ++ v

    punitiveName = punitivePrefix ++ sid

    -- Actor is the extorter. The threat IS the communication of conditional
    -- intent: the marker (lifetime = 'coThreatLasts', spec §1), the
    -- motive-belief deposit (over the same channel confiding and lying ride),
    -- and the extorter's own mark. The deposit and the extorted mark stay
    -- PERMANENT: they record the attempt, not the threat's currency.
    threaten = action (coThreatenLabel co)
      ( coTrigger co
        ++ [ Neq victim "Actor"
           , Not (threatPath "Actor" victim) ] )
      [ lasting (coThreatLasts co) (threatPath "Actor" victim)
      , Insert (beliefAbout victim ("desires.Actor." ++ punitiveName) ++ ".heard.Actor")
      , Insert ("Actor.extorted." ++ victim ++ "." ++ sid) ]

    -- The victim buys off the threat: they are Actor, the extorter is E. The
    -- complied marker's lifetime is 'coComplianceLasts' (spec §1): Nothing
    -- makes it PERMANENT — one purchase per (id, extorter, victim) ever, so a
    -- renewed threat after compliance extracts nothing; @Just n@ expires it
    -- after n boundaries, so the racket cycles and one purchase holds per
    -- bought period. Buying protects the purse (no second extraction while it
    -- stands), never the person — the extorter's betrayal-vs-wait is ordinary
    -- 'Prax.Planner' scoring, enforced by no marker.
    comply = action (coDemandLabel co)
      [ Match (threatPath "E" "Actor"), Not (compliedPath "E" "Actor") ]
      ( coDemand co
        ++ [ lasting (coComplianceLasts co) (compliedPath "E" "Actor")
           , Delete (threatPath "E" "Actor") ] )

    defy = action "[Actor]: defy [E]"
      [ Match (threatPath "E" "Actor") ]
      [ Insert (defiedPath "Actor" "E")
      , Delete (threatPath "E" "Actor") ]

    -- The extorter punishes a STANDING threat or a defiance — gating on
    -- defiance alone would make stalling safe forever. Actor is the extorter.
    punish = action (coPunishLabel co)
      ( Or [ [ Match (threatPath "Actor" victim) ]
           , [ Match (defiedPath victim "Actor") ] ]
        : coPunishWhen co )
      (coPunishOuts co)

    -- The punitive desire pays coWeight per (victim, valued-state) pair: the
    -- Or clause (victim = PraxD, extorter = Owner) joins the renamed kernel on
    -- PraxD. Owner-templated, instantiated per holder ('Prax.Minds.wantFor').
    punitive = Desire punitiveName
      (Want ( Or [ [ Match (defiedPath "PraxD" "Owner") ]
                 , [ Match (threatPath "Owner" "PraxD") ] ]
              : namespaceKernel victim (coKernel co) )
            (coWeight co))

-- | The generated punitive desire's name prefix (@punishes-@). The one home
-- both the mechanism (which builds @punishes-\<id\>@) and the well-formedness
-- checker ("Prax.TypeCheck", which recognizes a deposited punitive belief by
-- it) read — the v51\/v53 checker-imports-the-vocabulary precedent.
punitivePrefix :: String
punitivePrefix = "punishes-"

-- | The marker-insert selector shared by BOTH markers (the threat and the
-- @complied@ mark): Nothing compiles to a permanent 'Insert' (byte-identical
-- to the shipped default — 'Outcome' derives Eq), @Just n@ to v44's
-- boundary-exact 'InsertFor' (retraction at the nth 'Prax.Engine.roundBoundary',
-- delete-purges-pending, persistence via dues, all inherited). @n@ is the
-- author's fictional lifetime decision, exactly like every 'InsertFor' since
-- v44 — not a heuristic.
lasting :: Maybe Int -> String -> Outcome
lasting Nothing  s = Insert s
lasting (Just n) s = InsertFor n s

-- | Alpha-rename an author-written kernel into the @Prax@ namespace,
-- op-preservingly (generalizing 'Prax.Blackmail'\'s @renameVictim@ from one
-- victim to the whole free-variable frame). The @victim@ variable → @PraxD@;
-- every other free variable, in first-appearance order and excluding the
-- mechanism interface name @Owner@, → @PraxW@, @PraxW2@, …. Renaming is by
-- NAME, applied uniformly through every 'Condition' constructor — so a
-- binder ('Subquery'\'s set\/find variables) and its interior uses move
-- together, and 'Match'\/'Not' pattern segments round-trip through 'tokens'
-- so each segment's following @.@\/@!@ operator is preserved.
namespaceKernel :: String -> [Condition] -> [Condition]
namespaceKernel victim conds = map (renameCond subst) conds
  where
    freeVars = nub (filter isVariable (concatMap conditionVars conds))
    others   = filter (\v -> v /= victim && v /= "Owner") freeVars
    m = Map.fromList ((victim, "PraxD") : zip others praxNames)
    praxNames = "PraxW" : [ "PraxW" ++ show n | n <- [2 :: Int ..] ]
    subst n = Map.findWithDefault n n m

-- | Apply a name substitution through every constructor of a 'Condition'.
-- 'Match'\/'Not' sentences are split via 'tokens', each segment name mapped,
-- and rejoined via 'tokensToSentence' — never a naive string substitution
-- that could corrupt @.@\/@!@ punctuation.
renameCond :: (String -> String) -> Condition -> Condition
renameCond f = go
  where
    go c = case c of
      Match s          -> Match (renameSentence s)
      Not s            -> Not (renameSentence s)
      Eq x y           -> Eq (f x) (f y)
      Neq x y          -> Neq (f x) (f y)
      Cmp op x y       -> Cmp op (f x) (f y)
      Calc r op x y    -> Calc (f r) op (f x) (f y)
      Count r s        -> Count (f r) (f s)
      Subquery s fnd w -> Subquery (f s) (map f fnd) (map go w)
      Or clauses       -> Or (map (map go) clauses)
      Absent cs        -> Absent (map go cs)
      Exists cs        -> Exists (map go cs)
    renameSentence s = tokensToSentence [ (intern (f name), op) | (name, op) <- tokens s ]
