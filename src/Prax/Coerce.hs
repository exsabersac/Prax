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
    -- * Condition smart constructors (fact-path duals)
  , isThreatened, lacksThreatened
  , hasThreatened
  , isDefied, lacksDefied
  , hasDefied
  , hasComplied, lacksComplied
  , hasExtorted, lacksExtorted
  , everThreatened, neverThreatened
  , everDefied, neverDefied
  , everComplied, neverComplied
  , everExtorted, neverExtorted
  , isBranded, lacksBranded, hasBranded
  , isBrandedHeretic, lacksBrandedHeretic, hasBrandedHeretic
  , isParaded, lacksParaded, hasParaded
  , isCried, lacksCried, hasCried
  , isDenounced, lacksDenounced, hasDenounced
  , isRallied, lacksRallied, hasRallied
  , isCensured, lacksCensured, hasCensured
  , isExiled, lacksExiled, hasExiled
  , isFled, lacksFled, hasFled
  , isReconciled, lacksReconciled, hasReconciled
  , isConfessed, lacksConfessed, hasConfessed
  , isRecanted, lacksRecanted, hasRecanted
  , isMarried, lacksMarried, hasMarried
  , isOstracized, lacksOstracized, hasOstracized
  , isAtoned, lacksAtoned, hasAtoned
  , isHungry, lacksHungry, hasHungry
  , isEyed, lacksEyed, hasEyed
  , isConfronted, lacksConfronted, hasConfronted
  , isWronged, lacksWronged, hasWronged
  , isAllied, lacksAllied, hasAllied
  , isResents, lacksResents, hasResents
  , isShortTempered, lacksShortTempered, hasShortTempered
  , isAppetite, lacksAppetite, hasAppetite
  ) where

import           Data.List (nub)
import qualified Data.Map.Strict as Map

import           Prax.Db (isVariable, tokens, tokensToSentence)
import           Prax.Sym (intern)
import           Prax.Query (Condition (..), conditionVars)
import           Prax.Types (Action, Desire (..), Outcome (..), Want (..), action,
                             authoredVarClash, isPraxVar)
import           Prax.Beliefs (beliefAbout)

-- | 胁迫：带内容槽的杠杆骨架（威胁欲望、服从、报复）。
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

-- | @coerce coercion@ 生成威胁\/服从\/报复欲望与动作。
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

-- | 生成的惩罚性欲望名前缀（@punishes-@）。
punitivePrefix :: String
punitivePrefix = "punishes-"

-- | 两种标记共享的标记插入选择器：@Just n@ 为有寿命，@Nothing@ 为永久。
lasting :: Maybe Int -> String -> Outcome
lasting Nothing  s = Insert s
lasting (Just n) s = InsertFor n s

-- | 把作者写的内核 α-换名为 @Prax@ 命名空间（卫生）。
namespaceKernel :: String -> [Condition] -> [Condition]
namespaceKernel victim conds = map (renameCond subst) conds
  where
    freeVars = nub (filter isVariable (concatMap conditionVars conds))
    others   = filter (\v -> v /= victim && v /= "Owner") freeVars
    m = Map.fromList ((victim, "PraxD") : zip others praxNames)
    praxNames = "PraxW" : [ "PraxW" ++ show n | n <- [2 :: Int ..] ]
    subst n = Map.findWithDefault n n m

-- | 对条件每个构造器应用名字替换。
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


-- ---------------------------------------------------------------------------
-- Condition smart constructors over the coerce fact conventions
-- (threatened.<id>.<extorter>.<victim>, defied.<id>.<victim>.<extorter>,
--  complied.<id>.<extorter>.<victim>, <extorter>.extorted.<victim>.<id>).
-- ---------------------------------------------------------------------------

segOk :: String -> Bool
segOk n = not (null n) && all (`notElem` (".!" :: String)) n

guardSeg :: String -> String -> String
guardSeg who n
  | segOk n = n
  | otherwise = error ("Prax.Coerce." ++ who ++ ": " ++ show n
                       ++ " must be a nonempty single path segment")

-- | 条件：@extorter@ 对 @victim@ 正持有 @sid@ 威胁标记。
isThreatened :: String -> String -> String -> Condition
isThreatened sid extorter victim =
  Match ("threatened." ++ guardSeg "isThreatened" sid
         ++ "." ++ guardSeg "isThreatened" extorter
         ++ "." ++ guardSeg "isThreatened" victim)

-- | 条件：无该威胁标记（@isThreatened@ 的 Not 对偶）。
lacksThreatened :: String -> String -> String -> Condition
lacksThreatened sid extorter victim =
  Not ("threatened." ++ guardSeg "lacksThreatened" sid
       ++ "." ++ guardSeg "lacksThreatened" extorter
       ++ "." ++ guardSeg "lacksThreatened" victim)

-- | 条件：@extorter@ 对 @victim@ 正持有 @sid@ 威胁标记（@isThreatened@ 同体；对齐 has* 命名）。
hasThreatened :: String -> String -> String -> Condition
hasThreatened = isThreatened

-- | 条件：@victim@ 已违抗 @extorter@ 的 @sid@ 威胁。
isDefied :: String -> String -> String -> Condition
isDefied sid victim extorter =
  Match ("defied." ++ guardSeg "isDefied" sid
         ++ "." ++ guardSeg "isDefied" victim
         ++ "." ++ guardSeg "isDefied" extorter)

-- | 条件：无该违抗标记。
lacksDefied :: String -> String -> String -> Condition
lacksDefied sid victim extorter =
  Not ("defied." ++ guardSeg "lacksDefied" sid
       ++ "." ++ guardSeg "lacksDefied" victim
       ++ "." ++ guardSeg "lacksDefied" extorter)

-- | 条件：@victim@ 已违抗 @extorter@ 的 @sid@ 威胁（@isDefied@ 同体；对齐 has* 命名）。
hasDefied :: String -> String -> String -> Condition
hasDefied = isDefied

-- | 条件：@victim@ 已向 @extorter@ 就 @sid@ 服从（买断）。
hasComplied :: String -> String -> String -> Condition
hasComplied sid extorter victim =
  Match ("complied." ++ guardSeg "hasComplied" sid
         ++ "." ++ guardSeg "hasComplied" extorter
         ++ "." ++ guardSeg "hasComplied" victim)

-- | 条件：无该服从标记。
lacksComplied :: String -> String -> String -> Condition
lacksComplied sid extorter victim =
  Not ("complied." ++ guardSeg "lacksComplied" sid
       ++ "." ++ guardSeg "lacksComplied" extorter
       ++ "." ++ guardSeg "lacksComplied" victim)

-- | 条件：@extorter@ 对 @victim@ 留有 @sid@ 勒索痕（threaten 永久存入）。
hasExtorted :: String -> String -> String -> Condition
hasExtorted extorter victim sid =
  Match (guardSeg "hasExtorted" extorter ++ ".extorted."
         ++ guardSeg "hasExtorted" victim ++ "."
         ++ guardSeg "hasExtorted" sid)

-- | 条件：无该勒索痕。
lacksExtorted :: String -> String -> String -> Condition
lacksExtorted extorter victim sid =
  Not (guardSeg "lacksExtorted" extorter ++ ".extorted."
       ++ guardSeg "lacksExtorted" victim ++ "."
       ++ guardSeg "lacksExtorted" sid)

-- | 条件：@sid@ 下存在任意威胁标记。
everThreatened :: String -> Condition
everThreatened sid =
  Exists [ Match ("threatened." ++ guardSeg "everThreatened" sid
                  ++ ".Extorter.Victim") ]

-- | 条件：@sid@ 下从未有过威胁标记。
neverThreatened :: String -> Condition
neverThreatened sid =
  Absent [ Match ("threatened." ++ guardSeg "neverThreatened" sid
                  ++ ".Extorter.Victim") ]

-- | 条件：@sid@ 下存在任意违抗标记。
everDefied :: String -> Condition
everDefied sid =
  Exists [ Match ("defied." ++ guardSeg "everDefied" sid
                  ++ ".Victim.Extorter") ]

-- | 条件：@sid@ 下从未有过违抗标记。
neverDefied :: String -> Condition
neverDefied sid =
  Absent [ Match ("defied." ++ guardSeg "neverDefied" sid
                  ++ ".Victim.Extorter") ]

-- | 条件：@sid@ 下存在任意服从标记。
everComplied :: String -> Condition
everComplied sid =
  Exists [ Match ("complied." ++ guardSeg "everComplied" sid
                  ++ ".Extorter.Victim") ]

-- | 条件：@sid@ 下从未有过服从标记。
neverComplied :: String -> Condition
neverComplied sid =
  Absent [ Match ("complied." ++ guardSeg "neverComplied" sid
                  ++ ".Extorter.Victim") ]

-- | 条件：@sid@ 下存在任意勒索痕（@Extorter.extorted.Victim.<sid>@）。
everExtorted :: String -> Condition
everExtorted sid =
  Exists [ Match ("Extorter.extorted.Victim." ++ guardSeg "everExtorted" sid) ]

-- | 条件：@sid@ 下从未有过勒索痕。
neverExtorted :: String -> Condition
neverExtorted sid =
  Absent [ Match ("Extorter.extorted.Victim." ++ guardSeg "neverExtorted" sid) ]

-- | 条件：@who@ 已烙贼印（@branded.<who>@；Sandbox millSqueeze 惩罚核）。
isBranded :: String -> Condition
isBranded who =
  Match ("branded." ++ guardSeg "isBranded" who)

-- | 条件：无贼烙印。
lacksBranded :: String -> Condition
lacksBranded who =
  Not ("branded." ++ guardSeg "lacksBranded" who)

-- | 条件：已烙贼印（@isBranded@ 同体；对齐 has* 命名）。
hasBranded :: String -> Condition
hasBranded = isBranded

-- | 条件：@who@ 已烙异端印（@brandedHeretic.<who>@；Sandbox churchInquisit 惩罚核）。
isBrandedHeretic :: String -> Condition
isBrandedHeretic who =
  Match ("brandedHeretic." ++ guardSeg "isBrandedHeretic" who)

-- | 条件：无异端烙印。
lacksBrandedHeretic :: String -> Condition
lacksBrandedHeretic who =
  Not ("brandedHeretic." ++ guardSeg "lacksBrandedHeretic" who)

-- | 条件：已烙异端印（@isBrandedHeretic@ 同体；对齐 has* 命名）。
hasBrandedHeretic :: String -> Condition
hasBrandedHeretic = isBrandedHeretic


-- | 条件：@actor@ 已对 @target@ 游街（@paraded.<actor>.<target>@；Sandbox brand parade）。
isParaded :: String -> String -> Condition
isParaded actor target =
  Match ("paraded." ++ guardSeg "isParaded" actor
         ++ "." ++ guardSeg "isParaded" target)

-- | 条件：无该游街叶（@isParaded@ 的 Not 对偶）。
lacksParaded :: String -> String -> Condition
lacksParaded actor target =
  Not ("paraded." ++ guardSeg "lacksParaded" actor
       ++ "." ++ guardSeg "lacksParaded" target)

-- | 条件：已对 target 游街（@isParaded@ 同体；对齐 has* 命名）。
hasParaded :: String -> String -> Condition
hasParaded = isParaded


-- | 条件：@actor@ 已对 @target@ 市集喊冤（@cried.<actor>.<target>@；Sandbox marketCry）。
isCried :: String -> String -> Condition
isCried actor target =
  Match ("cried." ++ guardSeg "isCried" actor
         ++ "." ++ guardSeg "isCried" target)

-- | 条件：无该喊冤叶（@isCried@ 的 Not 对偶）。
lacksCried :: String -> String -> Condition
lacksCried actor target =
  Not ("cried." ++ guardSeg "lacksCried" actor
       ++ "." ++ guardSeg "lacksCried" target)

-- | 条件：已对 target 市集喊冤（@isCried@ 同体；对齐 has* 命名）。
hasCried :: String -> String -> Condition
hasCried = isCried


-- | 条件：@actor@ 已控告 @target@（@denounced.<actor>.<target>@；Sandbox millJustice）。
isDenounced :: String -> String -> Condition
isDenounced actor target =
  Match ("denounced." ++ guardSeg "isDenounced" actor
         ++ "." ++ guardSeg "isDenounced" target)

-- | 条件：无该控告叶。
lacksDenounced :: String -> String -> Condition
lacksDenounced actor target =
  Not ("denounced." ++ guardSeg "lacksDenounced" actor
       ++ "." ++ guardSeg "lacksDenounced" target)

-- | 条件：已控告 target（@isDenounced@ 同体；对齐 has* 命名）。
hasDenounced :: String -> String -> Condition
hasDenounced = isDenounced

-- | 条件：@actor@ 已市集声援 @target@（@rallied.<actor>.<target>@；Sandbox marketRally）。
isRallied :: String -> String -> Condition
isRallied actor target =
  Match ("rallied." ++ guardSeg "isRallied" actor
         ++ "." ++ guardSeg "isRallied" target)

-- | 条件：无该声援叶。
lacksRallied :: String -> String -> Condition
lacksRallied actor target =
  Not ("rallied." ++ guardSeg "lacksRallied" actor
       ++ "." ++ guardSeg "lacksRallied" target)

-- | 条件：已市集声援 target（@isRallied@ 同体；对齐 has* 命名）。
hasRallied :: String -> String -> Condition
hasRallied = isRallied


-- | 条件：@actor@ 已审查 @target@（@censured.<actor>.<target>@；Sandbox churchHeresy）。
isCensured :: String -> String -> Condition
isCensured actor target =
  Match ("censured." ++ guardSeg "isCensured" actor
         ++ "." ++ guardSeg "isCensured" target)

-- | 条件：无该审查叶。
lacksCensured :: String -> String -> Condition
lacksCensured actor target =
  Not ("censured." ++ guardSeg "lacksCensured" actor
       ++ "." ++ guardSeg "lacksCensured" target)

-- | 条件：已审查 target（@isCensured@ 同体；对齐 has* 命名）。
hasCensured :: String -> String -> Condition
hasCensured = isCensured

-- | 条件：@who@ 已被放逐（@exiled.<who>@；Sandbox mill/church exile）。
isExiled :: String -> Condition
isExiled who =
  Match ("exiled." ++ guardSeg "isExiled" who)

-- | 条件：无放逐叶。
lacksExiled :: String -> Condition
lacksExiled who =
  Not ("exiled." ++ guardSeg "lacksExiled" who)

-- | 条件：已被放逐（@isExiled@ 同体；对齐 has* 命名）。
hasExiled :: String -> Condition
hasExiled = isExiled


-- | 条件：@who@ 已叛逃（@fled.<who>@；Sandbox millAllegiance）。
isFled :: String -> Condition
isFled who =
  Match ("fled." ++ guardSeg "isFled" who)

-- | 条件：无叛逃叶。
lacksFled :: String -> Condition
lacksFled who =
  Not ("fled." ++ guardSeg "lacksFled" who)

-- | 条件：已叛逃（@isFled@ 同体；对齐 has* 命名）。
hasFled :: String -> Condition
hasFled = isFled

-- | 条件：@who@ 已和解回队（@reconciled.<who>@；Sandbox millAllegiance）。
isReconciled :: String -> Condition
isReconciled who =
  Match ("reconciled." ++ guardSeg "isReconciled" who)

-- | 条件：无和解叶。
lacksReconciled :: String -> Condition
lacksReconciled who =
  Not ("reconciled." ++ guardSeg "lacksReconciled" who)

-- | 条件：已和解回队（@isReconciled@ 同体；对齐 has* 命名）。
hasReconciled :: String -> Condition
hasReconciled = isReconciled


-- | 条件：@who@ 已招供（@confessed.<who>@；Sandbox millSqueeze demand）。
isConfessed :: String -> Condition
isConfessed who =
  Match ("confessed." ++ guardSeg "isConfessed" who)

-- | 条件：无招供叶。
lacksConfessed :: String -> Condition
lacksConfessed who =
  Not ("confessed." ++ guardSeg "lacksConfessed" who)

-- | 条件：已招供（@isConfessed@ 同体；对齐 has* 命名）。
hasConfessed :: String -> Condition
hasConfessed = isConfessed

-- | 条件：@who@ 已悔罪（@recanted.<who>@；Sandbox churchInquisit demand）。
isRecanted :: String -> Condition
isRecanted who =
  Match ("recanted." ++ guardSeg "isRecanted" who)

-- | 条件：无悔罪叶。
lacksRecanted :: String -> Condition
lacksRecanted who =
  Not ("recanted." ++ guardSeg "lacksRecanted" who)

-- | 条件：已悔罪（@isRecanted@ 同体；对齐 has* 命名）。
hasRecanted :: String -> Condition
hasRecanted = isRecanted


-- | 条件：@a@ 与 @b@ 已婚入同盟（@married.<a>.<b>@；Sandbox millWed）。
isMarried :: String -> String -> Condition
isMarried a b =
  Match ("married." ++ guardSeg "isMarried" a
         ++ "." ++ guardSeg "isMarried" b)

-- | 条件：无该婚入叶。
lacksMarried :: String -> String -> Condition
lacksMarried a b =
  Not ("married." ++ guardSeg "lacksMarried" a
       ++ "." ++ guardSeg "lacksMarried" b)

-- | 条件：与 b 已婚入同盟（@isMarried@ 同体；对齐 has* 命名）。
hasMarried :: String -> String -> Condition
hasMarried = isMarried

-- | 条件：@actor@ 已放逐排斥 @target@（@ostracized.<actor>.<target>@）。
isOstracized :: String -> String -> Condition
isOstracized actor target =
  Match ("ostracized." ++ guardSeg "isOstracized" actor
         ++ "." ++ guardSeg "isOstracized" target)

-- | 条件：无该排斥叶。
lacksOstracized :: String -> String -> Condition
lacksOstracized actor target =
  Not ("ostracized." ++ guardSeg "lacksOstracized" actor
       ++ "." ++ guardSeg "lacksOstracized" target)

-- | 条件：已放逐排斥 target（@isOstracized@ 同体；对齐 has* 命名）。
hasOstracized :: String -> String -> Condition
hasOstracized = isOstracized


-- | 条件：@who@ 已赎罪（@atoned.<who>@；Village standingUnless 击败者）。
isAtoned :: String -> Condition
isAtoned who =
  Match ("atoned." ++ guardSeg "isAtoned" who)

-- | 条件：无赎罪叶。
lacksAtoned :: String -> Condition
lacksAtoned who =
  Not ("atoned." ++ guardSeg "lacksAtoned" who)

-- | 条件：已赎罪（@isAtoned@ 同体；对齐 has* 命名）。
hasAtoned :: String -> Condition
hasAtoned = isAtoned

-- | 条件：@who@ 饥饿（@hungry.<who>@；Village）。
isHungry :: String -> Condition
isHungry who =
  Match ("hungry." ++ guardSeg "isHungry" who)

-- | 条件：无饥饿叶。
lacksHungry :: String -> Condition
lacksHungry who =
  Not ("hungry." ++ guardSeg "lacksHungry" who)

-- | 条件：饥饿（@isHungry@ 同体；对齐 has* 命名）。
hasHungry :: String -> Condition
hasHungry = isHungry


-- | 条件：@actor@ 已目击疑心 @target@（@eyed.<actor>.<target>@；Village）。
isEyed :: String -> String -> Condition
isEyed actor target =
  Match ("eyed." ++ guardSeg "isEyed" actor
         ++ "." ++ guardSeg "isEyed" target)

-- | 条件：无该目击叶。
lacksEyed :: String -> String -> Condition
lacksEyed actor target =
  Not ("eyed." ++ guardSeg "lacksEyed" actor
       ++ "." ++ guardSeg "lacksEyed" target)

-- | 条件：已目击疑心 target（@isEyed@ 同体；对齐 has* 命名）。
hasEyed :: String -> String -> Condition
hasEyed = isEyed

-- | 条件：@actor@ 已对质 @target@（@confronted.<actor>.<target>@；Village）。
isConfronted :: String -> String -> Condition
isConfronted actor target =
  Match ("confronted." ++ guardSeg "isConfronted" actor
         ++ "." ++ guardSeg "isConfronted" target)

-- | 条件：无该对质叶。
lacksConfronted :: String -> String -> Condition
lacksConfronted actor target =
  Not ("confronted." ++ guardSeg "lacksConfronted" actor
       ++ "." ++ guardSeg "lacksConfronted" target)

-- | 条件：已对质 target（@isConfronted@ 同体；对齐 has* 命名）。
hasConfronted :: String -> String -> Condition
hasConfronted = isConfronted


-- | 条件：@offender@ 冤屈了 @victim@（@wronged.<offender>.<victim>@；Feud）。
isWronged :: String -> String -> Condition
isWronged offender victim =
  Match ("wronged." ++ guardSeg "isWronged" offender
         ++ "." ++ guardSeg "isWronged" victim)

-- | 条件：无该冤屈叶。
lacksWronged :: String -> String -> Condition
lacksWronged offender victim =
  Not ("wronged." ++ guardSeg "lacksWronged" offender
       ++ "." ++ guardSeg "lacksWronged" victim)

-- | 条件：冤屈了 victim（@isWronged@ 同体；对齐 has* 命名）。
hasWronged :: String -> String -> Condition
hasWronged = isWronged

-- | 条件：@a@ 与 @b@ 同盟（@allied.<a>.<b>@；Faction comrades / Feud）。
isAllied :: String -> String -> Condition
isAllied a b =
  Match ("allied." ++ guardSeg "isAllied" a
         ++ "." ++ guardSeg "isAllied" b)

-- | 条件：无该同盟叶。
lacksAllied :: String -> String -> Condition
lacksAllied a b =
  Not ("allied." ++ guardSeg "lacksAllied" a
       ++ "." ++ guardSeg "lacksAllied" b)

-- | 条件：与 b 同盟（@isAllied@ 同体；对齐 has* 命名）。
hasAllied :: String -> String -> Condition
hasAllied = isAllied


-- | 条件：@who@ 怨恨 @target@（@resents.<who>.<target>@；Feud）。
isResents :: String -> String -> Condition
isResents who target =
  Match ("resents." ++ guardSeg "isResents" who
         ++ "." ++ guardSeg "isResents" target)

-- | 条件：无该怨恨叶。
lacksResents :: String -> String -> Condition
lacksResents who target =
  Not ("resents." ++ guardSeg "lacksResents" who
       ++ "." ++ guardSeg "lacksResents" target)

-- | 条件：怨恨 target（@isResents@ 同体；对齐 has* 命名）。
hasResents :: String -> String -> Condition
hasResents = isResents

-- | 条件：@who@ 暴脾气（@shortTempered.<who>@；Village）。
isShortTempered :: String -> Condition
isShortTempered who =
  Match ("shortTempered." ++ guardSeg "isShortTempered" who)

-- | 条件：无暴脾气叶。
lacksShortTempered :: String -> Condition
lacksShortTempered who =
  Not ("shortTempered." ++ guardSeg "lacksShortTempered" who)

-- | 条件：暴脾气（@isShortTempered@ 同体；对齐 has* 命名）。
hasShortTempered :: String -> Condition
hasShortTempered = isShortTempered

-- | 条件：@who@ 有胃口（@appetite.<who>@；Village）。
isAppetite :: String -> Condition
isAppetite who =
  Match ("appetite." ++ guardSeg "isAppetite" who)

-- | 条件：无胃口叶。
lacksAppetite :: String -> Condition
lacksAppetite who =
  Not ("appetite." ++ guardSeg "lacksAppetite" who)

-- | 条件：有胃口（@isAppetite@ 同体；对齐 has* 命名）。
hasAppetite :: String -> Condition
hasAppetite = isAppetite

