-- | 作为信念对象的心智。
--
-- 要相信关于心智的某事，心智必须可命名：世界声明命名的、@Owner@-参数化的 'Desire' 词汇，
-- 且动机信念是 v20 出处形状（@.seen@ \/ @.heard.\<src\>@ \/ @.presumed@）下议题
-- @desires.\<owner\>.\<name\>@ 上的普通信念——因此整个信息栈（八卦、谎言、倾诉、遗忘、派生）
-- 对心智不变地工作。未命名的 'charWants' want 无可相信的名字，因此固有地不可读（适合故事管理器的
-- 元层欲望）。共同知识是 /派生的/、可废止的：'professed' 传播角色公开持有的欲望；'conventional'
-- 假定人人有某欲望——甚至假定实际没有它的人（你期望陌生人是约定的，且可能错）。
module Prax.Minds
  ( wantFor
  , selfWants
  , believedDesires
  , believedWants
  , professed
  , conventional
  , cookedSelfWants
  , cookedDesiresFor
  ) where

import qualified Data.Map.Strict as Map

import           Prax.Db (Val (..), exists)
import           Prax.Query (Condition (..), groundCondition, CookedCondition, groundCookedCondition)
import           Prax.Sym (intern)
import           Prax.Types
import           Prax.Derive (Axiom, axiom)

-- | 为其所有者实例化欲望模板（把 @Self@ 落地为角色名）。
wantFor :: String -> Desire -> Want
wantFor owner (Desire _ (Want cs u)) =
  Want (map (groundCondition (Map.singleton (intern "Owner") (VSym (intern owner)))) cs) u

-- | 角色据以规划之物：其整颗心智——未遮盖的自有 want。
selfWants :: PraxState -> Character -> [Want]
selfWants st c =
  charWants c
    ++ [ wantFor (charName c) d
       | d <- desires st, desireName d `elem` charDesires c ]

-- | 预测者相信的词汇欲望（任何公开/约定来源）。
believedDesires :: PraxState -> Character -> Character -> [Desire]
believedDesires st p m =
  [ d | d <- desires st
      , exists (charName p ++ ".believes.desires." ++ charName m
                  ++ "." ++ desireName d) view ]
  where view = readView st

-- | 预测者对行动者的信念模型：每个信念中的欲望实例化为 want。
believedWants :: PraxState -> Character -> Character -> [Want]
believedWants st p m = map (wantFor (charName m)) (believedDesires st p m)

-- | 把欲望列表的预煮模板（'cookedDesires'）落地为角色。
cookedDesiresFor :: PraxState -> String -> [Desire] -> [([CookedCondition], Int)]
cookedDesiresFor st owner ds =
  [ ( map (groundCookedCondition ownerB) (Map.findWithDefault [] (desireName d) (cookedDesires st))
    , wantUtility (desireWant d) )
  | d <- ds ]
  where ownerB = Map.singleton (intern "Owner") (VSym (intern owner))

-- | 'selfWants' 的煮熟镜像：煮熟条件配效用。
cookedSelfWants :: PraxState -> Character -> [([CookedCondition], Int)]
cookedSelfWants st c =
  zip (Map.findWithDefault [] (charName c) (cookedWants st)) (map wantUtility (charWants c))
    ++ cookedDesiresFor st (charName c) [ d | d <- desires st, desireName d `elem` charDesires c ]

-- | 公开持有的欲望被每个人假定知晓。
professed :: Axiom
professed = axiom
  [ Match "professes.Owner.D", Match "character.P" ]
  [ "P.believes.desires.Owner.D.presumed" ]

-- | 约定欲望被每个人假定于每个人。
conventional :: Axiom
conventional = axiom
  [ Match "conventional.D", Match "character.P", Match "character.M" ]
  [ "P.believes.desires.M.D.presumed" ]
