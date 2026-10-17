-- | 作为引擎状态的播种戏剧骰（规格 @docs/specs/2026-07-18-v50-machinery-state.md@）：
-- Lehmer 流住在 'Prax.Types.rngSeed' 中，非事实基，且 'draw' 是唯一创作表面。本模块保留
-- 全部骰子数学——Park & Miller MINSTD 常量、单步推进（'rollStep'）、以及种子域边界
-- （'seedBounds'，由 'Prax.Engine.seedDie' 消费）；'draw' 把创作赔率编译为
-- 'Prax.Engine.performCooked' 对照引擎流执行的一等 'Roll' 结果。这是戏剧骰，非统计库：
-- MINSTD 流的低位足以决定脾气是否爆发，此处无物适合密码学或仿真科学。
module Prax.Rng
  ( draw
  , rollStep
  , seedBounds
  ) where

import           Prax.Query (Condition)
import           Prax.Types

-- Park & Miller (1988), "Random number generators: good ones are hard to
-- find" — the MINSTD minimal standard. Mechanism with published provenance,
-- fixed here, never tuned: the AUTHORED numbers are 'draw''s odds.
lehmerA, lehmerM :: Integer
lehmerA = 16807
lehmerM = 2147483647   -- 2^31 - 1

-- | 一步 Lehmer：推进后的流值。掷骰基底 *就是* 此推进值（冻结骰法则：每次抽取花费一步，无论命中与否）。
rollStep :: Integer -> Integer
rollStep s = (s * lehmerA) `mod` lehmerM

-- | 种子的有效域，含端点：严格介于 0 与模之间（两端是不动点）。
seedBounds :: (Integer, Integer)
seedBounds = (1, lehmerM - 1)

-- | 「以概率 num\/den，在 conds 也成立处，应用 outs。」作者表面；编译为 'Roll' 结果。未播种世界响亮错误。
draw :: Int -> Int -> [Condition] -> [Outcome] -> [Outcome]
draw num den conds outs
  | num <= 0 || num >= den =
      error ("Prax.Rng: draw odds " ++ show num ++ "/" ++ show den
             ++ " must satisfy 0 < num < den")
  | (v : _) <- offenders =
      error ("Prax.Rng: draw body authors " ++ show v
             ++ " -- the Prax namespace is reserved for the die's own machinery")
  | otherwise = [ Roll num den conds outs ]
  where
    offenders = authoredVarClash [] conds outs
