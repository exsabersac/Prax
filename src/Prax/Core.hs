-- | 核心模型：关系（Versu 论文 §X）。
--
-- Versu 把 agent 的情感与关系状态称作「不同实践据以通信的通道」。它是普通 DB 状态——
-- 本模块不增加新引擎机制，只在 "Prax.Engine" 之上提供可复用的约定标准库：
--
--   * 关系评价是数值、多重、不对称的，并携带理由
--     (@A.relationship.B.Role.score!N@, @A.relationship.B.Role.reason!Why@)；
--   * 公开「纽带」是对称的（@bond.A.B!State@ 双向写入）。
--
-- 情感已迁至 "Prax.Emotion"（规格 2026-07-15-v38）：共存的情节 @feels@ 事实替换了本模块
-- 单槽、自动覆盖的 @mood!@/@priorMood@ 机制，后者随其最后消费者（酒吧迁移）一并删除。
--
-- 读-改-写部件（先播种再累积分数）作为 'Function'（'coreFns'）提供一次，复用
-- "Prax.Worlds.Bar" 中饮酒计数器已证明的同一 @Call@/@Calc@ 机制。用
-- 'Prax.Engine.defineFunctions' 注册 'coreFns'，使下方智能构造器可用。
module Prax.Core
  ( -- * 注册库
    coreFns
    -- * 关系角色
  , warmth, respect
    -- * 效果（智能构造的 Outcome）
  , adjustScore
  , setBond
    -- * 条件
  , scoreAtLeast
  ) where

import           Data.Char (toUpper)

import           Prax.Query (Condition (..), CmpOp (..), CalcOp (..))
import           Prax.Types

-- 关系角色（评价维度）-----------------------------------------------------------

-- | 评价维度示例。关系可在任意数量的这些维度上、每个方向独立地被评判。
warmth, respect :: String
warmth  = "warmth"
respect = "respect"

-- 效果（智能构造的 Outcome）----------------------------------------------------

-- | 将 @a@ 对 @b@ 在 @role@ 上的评价调整 @delta@（首次互动则播种），并记录 @reason@。
-- 负 delta 使关系变冷。
adjustScore :: String -> String -> String -> Int -> String -> Outcome
adjustScore a b role delta reason =
  Call "prax_adjustScore" [a, b, role, show delta, reason]

-- | 设定 @a@ 与 @b@ 之间的对称公开纽带（例如 @"friends"@）。
setBond :: String -> String -> String -> Outcome
setBond a b st = Call "prax_setBond" [a, b, st]

-- 条件 -------------------------------------------------------------------------

-- | 要求 @a@ 对 @b@ 在 @role@ 上的评价至少为 @n@。绑定角色特定的分数变量
-- （跨不同角色可安全组合）。
scoreAtLeast :: String -> String -> String -> Int -> [Condition]
scoreAtLeast a b role n =
  [ Match (a ++ ".relationship." ++ b ++ "." ++ role ++ ".score!" ++ v)
  , Cmp Gte v (show n)
  ]
  where v = "Score" ++ capitalize role

-- | 角色名首字母大写，用于生成按角色区分的绑定变量（如 ScoreWarmth）。
capitalize :: String -> String
capitalize []       = []
capitalize (c : cs) = toUpper c : cs

-- 库函数（注册后由 Call 按名调用）------------------------------------------------

-- | 可复用的核心模型函数。用 'Prax.Engine.defineFunctions' 注册；动作按名调用时找到它们。
coreFns :: [Function]
coreFns = [adjustScoreFn, setBondFn]

-- 若已有分数则加 Delta；首次互动则用 Delta 播种分数。
adjustScoreFn :: Function
adjustScoreFn = Function "prax_adjustScore" ["A", "B", "Role", "Delta", "Reason"]
  [ FnCase [ Match "A.relationship.B.Role.score!N", Calc "M" Add "N" "Delta" ]
      [ Insert "A.relationship.B.Role.score!M"
      , Insert "A.relationship.B.Role.reason!Reason" ]
  , FnCase []
      [ Insert "A.relationship.B.Role.score!Delta"
      , Insert "A.relationship.B.Role.reason!Reason" ]
  ]

-- 一次写入双向对称纽带。
setBondFn :: Function
setBondFn = Function "prax_setBond" ["A", "B", "State"]
  [ FnCase [] [ Insert "bond.A.B!State", Insert "bond.B.A!State" ] ]
