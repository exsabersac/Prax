-- | 勒索：强制的曝光实例（规格 @docs/specs/2026-07-17-v49-coercion.md@；原杠杆模型
-- @docs/specs/2026-07-12-v30-blackmail-debt.md@ §「杠杆模型」）。
--
-- __勒索是一个 'Prax.Coerce.Coercion'，组合而非包装。__
-- 'shakedown' 保持其 v30 签名，但构建 'Prax.Coerce.Coercion' 记录并返回其
-- @'Prax.Coerce.coerce'@。四动作协议（threaten\/comply\/defy\/expose）、动机信念存入、
-- 被勒索标记、站立威胁惩罚门禁、以及惩罚性 'Desire' 全是原语的；勒索只提供 /内容/：
--
--   * __trigger__ —— 勒索者持有证据（@Actor.believes.\<pat\>@）且受害者共现（@pat@ 的第一个变量，
--     经世界共现模板重定向）。原语追加 @Neq victim Actor@ 与尚未被威胁门禁。
--   * __demand__ —— 债务（@Prax.Debt.owe@）：受害者用人情买沉默。再买守卫是原语的永久 @complied@
--     标记，非债务本身——永久因为 'shakedown' 传 @coComplianceLasts = Nothing@（且威胁传
--     @coThreatLasts = Nothing@）：勒索此实例是固定永久虚构（规格 v54），想要到期或连环榨取的世界
--     创作自己带 @Just n@ 寿命的 'Prax.Coerce.Coercion'。
--   * __punish__ —— 曝光：在共现非信者中种植证据（Rumor 的有源传闻形状）。原语前置站立威胁或违抗
--     可用性核心。
--   * __kernel__ —— 证据的信者。用普通信者名 @Believer@ 与 @pat@ 自身普通受害者变量创作；
--     'Prax.Coerce.coerce' 把它们 alpha-重命名进 @Prax@ 命名空间（@Believer@ → @PraxW@，受害者 →
--     @PraxD@），因此惩罚 want 对关于被威胁/违抗受害者证据的每个信者支付 @w@。信者按其角色命名
--     而非 @W@，以免同名次级证据变量在重命名下与之合并。
--
-- __威胁可信是因为勒索者真正持有其表白的惩罚欲望。__ 返回的 'Desire'（@punishes-\<id\>@）必须
-- 世界注册（'Prax.Engine.setDesires'）并携带（'Prax.Types.charDesires'）；它首先是动机 /威胁/ 的东西
-- （自递归——曝光一 ply 之外），且短视无动机角色的 'Prax.Planner.predictMove' 正确地不会预见它。
-- 见 "Prax.Coerce" 的注册契约。
--
-- 世界把四个生成动作槽进自身实践（形状镜像 "Prax.Project" 的 'Prax.Project.endeavor'）；想要定制
-- 标签文本的世界把它作为记录的标签字段传入。
module Prax.Blackmail
  ( shakedown
  ) where

import           Prax.Db (isVariable, pathNames)
import           Prax.Query (Condition (..))
import           Prax.Types (Action, Desire, Outcome (..), authoredPatClash)
import           Prax.Beliefs (beliefAbout)
import           Prax.Witness (CoPresence, asRole)
import           Prax.Debt (owe)
import           Prax.Coerce (Coercion (..), coerce)

-- | @shakedown id copresence pat price w@ builds the exposure 'Coercion' and
-- returns @'coerce'@ of it: the threaten\/comply\/defy\/expose protocol and
-- the punitive 'Desire' it professes.
--
-- * @id@ — a single path segment scoping this shakedown's facts (the
--   primitive errors loudly otherwise), so more than one may coexist.
-- * @copresence@ — the world's co-presence template ("Prax.Witness"),
--   relating @Actor@ to whichever role it is retargeted onto.
-- * @pat@ — the evidence pattern, e.g. @\"stole.V.loaf\"@; its __first__
--   variable is the victim (mirrors 'Prax.Deceit.lie'\'s convention — loud
--   error if @pat@ names no one).
-- * @price@ — the debt content the victim pays to buy silence (e.g.
--   @\"favor\"@; "Prax.Debt" composes it into a real debt\/obligation).
-- * @w@ — the extorter's punitive weight: utility per believer of @pat@ once
--   the threat is live or has been defied.
shakedown :: String        -- ^ id (single path segment)
          -> CoPresence    -- ^ co-presence template
          -> String        -- ^ evidence pattern; first variable = victim
          -> String        -- ^ the price (debt content)
          -> Int           -- ^ punitive weight
          -> (Desire, [Action])
shakedown sid copresence pat price w
  | (bad : _) <- offenders =
      error ("shakedown: evidence pattern " ++ show pat
             ++ " names a secondary variable " ++ show bad
             ++ ", but Owner (the punitive desire's extorter, which the kernel"
             ++ " rename leaves untouched) and Hearer (expose's own audience)"
             ++ " are frame roles the evidence pattern is spliced beside — a"
             ++ " secondary variable bearing either name would silently merge"
             ++ " with the frame's binding; pick a different name for anyone"
             ++ " besides the victim")
  | otherwise = coerce blackmail
  where
    -- The victim is pat's first variable (loud error if pat names no one).
    victim = case filter isVariable (pathNames pat) of
      (v : _) -> v
      []      -> error ("shakedown: evidence pattern " ++ show pat
                        ++ " names no one (a threat needs a victim)")

    -- The instance guard, reasoned against the primitive's own field guards.
    -- pat is spliced into THREE frames: threaten's trigger (Actor = extorter),
    -- expose's punish (Actor = extorter, Hearer = audience), and the punitive
    -- kernel (Owner = extorter, the victim renamed to PraxD). The primitive
    -- already forbids the @Prax@ namespace on every field, and — because the
    -- kernel carries @pat@ — its kernel guard forbids @Actor@ and @E@ there.
    -- What the primitive CANNOT catch for @pat@ is @Owner@ (the kernel rename
    -- deliberately exempts the mechanism interface name, so a secondary
    -- @Owner@ would pass through and capture the desire's extorter) and
    -- @Hearer@ (expose's frame legitimately binds it as the audience, so
    -- naming it there is a merge, not a capture the punish guard flags). Those
    -- two the instance adds; the rest the primitive owns.
    offenders = authoredPatClash ["Owner", "Hearer"]
                  (filter (/= victim) (pathNames pat))

    blackmail = Coercion
      { coId            = sid
      , coVictim        = victim
        -- the extorter holds evidence, the victim is co-present
      , coTrigger       = Match (beliefAbout "Actor" pat) : asRole victim copresence
      , coThreatenLabel = "[Actor]: threaten [" ++ victim ++ "] with what you know"
      , coDemandLabel   = "[Actor]: buy [E]'s silence"
      , coDemand        = owe "E" "Actor" price
      , coPunishLabel   = "[Actor]: expose [" ++ victim ++ "] to [Hearer]"
        -- expose to a co-present hearer who doesn't already believe; the
        -- primitive prepends the standing-threat-or-defiance availability core
      , coPunishWhen    = Match (beliefAbout "Actor" pat)
                          : asRole "Hearer" copresence
                          ++ [ Neq "Hearer" "Actor"
                             , Neq "Hearer" victim
                             , Not (beliefAbout "Hearer" pat) ]
        -- Rumor's sourced-hearsay plant
      , coPunishOuts    = [ Insert (beliefAbout "Hearer" pat ++ ".heard.Actor") ]
        -- believers of the evidence, authored plain; coerce lifts Believer ->
        -- PraxW and the victim -> PraxD (a descriptive name, so a secondary
        -- evidence variable never collides with the believer under the rename).
        -- LOAD-BEARING for the instance guard (v49 review M1): pat flowing
        -- into coKernel is what makes the primitive's kernel guard reject a
        -- secondary evidence variable named Actor or E — the instance list
        -- below adds only Owner/Hearer. If pat ever stops flowing here, the
        -- Actor/E coverage goes with it.
      , coKernel        = [ Match (beliefAbout "Believer" pat) ]
      , coWeight        = w
        -- Blackmail the INSTANCE is a fixed fiction: permanent threats,
        -- permanent purchase (spec v54 §"the shakedown decision"). A world
        -- wanting an expiring or serial blackmail authors its own 'Coercion'
        -- directly — the primitive, not the instance, is the expressiveness
        -- home. The :17 permanence prose is true BECAUSE of this hardcode.
      , coThreatLasts     = Nothing
      , coComplianceLasts = Nothing
      }
