{-# LANGUAGE BangPatterns #-}

-- | Interned 路径段（规格 @docs/specs/2026-07-12-v29-interning.md@）。
--
-- FastString 风格的进程全局 intern 池：在一次运行内，'intern' 可观察地是纯函数。任何 'Sym'
-- 数值身份永不可序列化、渲染进输出、或跨进程比较——所有可观察文本经 'symName'。Id 按首次遭遇
-- 排序，因此按设计依赖运行。
--
-- 变量性打包进 id 奇偶——变量段（首字母大写，引擎既有约定）intern 为奇数，常量偶数——因此
-- 'symIsVar'（统一中最热谓词）是位测试。
module Prax.Sym
  ( Sym
  , intern
  , symName
  , symIsVar
  , symId
  , symOfId
  ) where

import           Data.Char (isUpper)
import           Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import           System.IO.Unsafe (unsafePerformIO)

newtype Sym = Sym Int
  deriving (Eq, Ord)

-- Debug rendering only; never parsed, never in goldens.
instance Show Sym where
  show s = "\8249" ++ symName s ++ "\8250"

data Pool = Pool !(Map.Map String Sym) !(IntMap.IntMap String) !Int !Int

poolRef :: IORef Pool
poolRef = unsafePerformIO (newIORef (Pool Map.empty IntMap.empty 0 1))
{-# NOINLINE poolRef #-}

-- | intern 一段：全、幂等、可观察纯（全局池）。
intern :: String -> Sym
intern !name =
  unsafePerformIO (atomicModifyIORef' poolRef step)
  where
    step pool@(Pool fwd rev nextE nextO) =
      case Map.lookup name fwd of
        Just s  -> (pool, s)
        Nothing ->
          let varish = case name of { (c : _) -> isUpper c; [] -> False }
              i  = if varish then nextO else nextE
              s  = Sym i
          in ( Pool (Map.insert name s fwd) (IntMap.insert i name rev)
                    (if varish then nextE else nextE + 2)
                    (if varish then nextO + 2 else nextO)
             , s )
{-# NOINLINE intern #-}

-- | 符号所命名的段。外来 id 响亮报错。
symName :: Sym -> String
symName (Sym !i) = unsafePerformIO $ do
  Pool _ rev _ _ <- readIORef poolRef
  case IntMap.lookup i rev of
    Just n  -> pure n
    Nothing -> error ("symName: unknown symbol id " ++ show i)
{-# NOINLINE symName #-}

-- | 此段是否为逻辑变量？位测试——见模块头奇偶约定。
symIsVar :: Sym -> Bool
symIsVar (Sym i) = odd i

-- | 原始 intern id，供 'Prax.Db' 需要 Int 键处使用。
symId :: Sym -> Int
symId (Sym i) = i

-- | 从原始 id 重建 'Sym'——读侧，配对 'symId'。
symOfId :: Int -> Sym
symOfId !i = unsafePerformIO $ do
  Pool _ rev _ _ <- readIORef poolRef
  case IntMap.lookup i rev of
    Just _  -> pure (Sym i)
    Nothing -> error ("symOfId: unknown symbol id " ++ show i)
{-# NOINLINE symOfId #-}
