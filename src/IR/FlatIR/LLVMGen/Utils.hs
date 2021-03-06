-- Copyright (c) 2015 Eric McCorkle.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- 3. Neither the name of the author nor the names of any contributors
--    may be used to endorse or promote products derived from this software
--    without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS''
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
-- USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
-- OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
{-# OPTIONS_GHC -Wall #-}

-- | Utility code for compiling to LLVM.  (This may be merged into
-- SimpleIR itself)
module IR.FlatIR.LLVMGen.Utils(
       booltype,
       getGlobalType,
       getGlobalMutability,
       getActualType
       ) where

import Data.Array.IArray
import Data.Graph.Inductive
import Data.Interval
import Data.Pos
import IR.FlatIR.Syntax

-- | The Flat IR type representing booleans.
booltype :: Pos -> Type
booltype p = IntType { intSigned = False, intSize = 1, intPos = p,
                       intIntervals = fromIntervalList [Interval 0 1] }

-- | Get the type of a global, constructing a function type if need
-- be.
getGlobalType :: Graph gr => Module gr -> Globalname -> Type
getGlobalType (Module { modGlobals = globals}) name =
  case globals ! name of
    Function { funcRetTy = retty, funcValTys = valtys,
               funcParams = params, funcPos = p } ->
      FuncType { funcTyRetTy = retty, funcTyPos = p,
                 funcTyArgTys = (map ((!) valtys) params) }
    GlobalVar { gvarTy = ty } -> ty

-- | Get the mutability of a global.  Note that all functions are
-- immutable.
getGlobalMutability :: Graph gr => Module gr -> Globalname -> Mutability
getGlobalMutability (Module { modGlobals = globals }) name =
  case globals ! name of
    GlobalVar { gvarMutability = mut } -> mut
    Function {} -> Immutable

-- | Chase down references and get a concrete type (if it
-- leads to an opaque type, then return the named type
getActualType :: Graph gr => Module gr -> Type -> Type
getActualType irmodule @ (Module { modTypes = types })
              idty @ (IdType { idName = tyname }) =
  case types ! tyname of
    (_, Just ty) -> getActualType irmodule ty
    _ -> idty
getActualType _ ty = ty
