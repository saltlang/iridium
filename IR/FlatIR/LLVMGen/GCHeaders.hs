-- Copyright (c) 2013 Eric McCorkle.
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation; either version 2 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
-- 02110-1301 USA
{-# OPTIONS_GHC -Wall -Werror #-}

-- | This module contains code for generating GC header declarations.
-- This generates global data that will ultimately be used by the GC
-- system to traverse objects.
module IR.FlatIR.LLVMGen.GCHeaders(
       genGCHeaders
       ) where

import Data.Array.IArray
import Data.Array.Unboxed(UArray)
import Data.Graph.Inductive.Graph
import Data.Traversable
import IR.FlatIR.Syntax
import Prelude hiding (mapM_, mapM, foldr, foldl, sequence)

import qualified LLVM.Core as LLVM
import qualified IR.GC.Types as GC

mobilityStr :: GC.Mobility -> String
mobilityStr GC.Mobile = "mobile"
mobilityStr GC.Immobile = "immobile"

mutabilityStr :: GC.Mutability -> String
mutabilityStr GC.Immutable = "const"
mutabilityStr GC.WriteOnce = "writeonce"
mutabilityStr GC.Mutable = "mutable"

-- | Generate an array mapping GCHeaders to llvm globals declarations
-- that will be defined by the GC implementation system.
genGCHeaders :: Graph gr =>
                Module gr
             -- ^ The FlatIR module being compiled
             -> LLVM.ModuleRef
             -- ^ The LLVM Module being created
             -> LLVM.ContextRef
             -- ^ The LLVM Context handle
             -> UArray Typename LLVM.TypeRef
             -- ^ An array mapping Typenames to LLVM type handles
             -> IO (Array GCHeader LLVM.ValueRef)
             -- ^ An array mapping GCHeaders to LLVM global variable handles
genGCHeaders (Module { modTypes = types, modGCHeaders = gcheaders })
             llvmmod ctx _ =
  let
    mapfun :: LLVM.TypeRef -> (Typename, GC.Mobility, GC.Mutability) ->
              IO LLVM.ValueRef
    mapfun hdrty (tname, mob, mut) =
      let
        (str, _) = types ! tname
        name = "core.gc.typedesc." ++ str ++ "." ++
          mobilityStr mob ++ "." ++ mutabilityStr mut
      in do
        val <- LLVM.addGlobal llvmmod hdrty name
        LLVM.setGlobalConstant val True
        LLVM.setLinkage val LLVM.LinkerPrivateLinkage
        return val
  in do
    hdrty <- LLVM.structCreateNamed ctx "core.gc.typedesc"
    mapM (mapfun hdrty) gcheaders