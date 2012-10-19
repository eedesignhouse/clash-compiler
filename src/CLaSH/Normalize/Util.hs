module CLaSH.Normalize.Util where

import qualified Data.HashMap.Lazy as HashMap
import qualified Data.Label.PureM as LabelM
import qualified Data.List as      List
import Unbound.LocallyNameless     (aeq,embed)

import CLaSH.Core.DataCon (dataConInstArgTys)
import CLaSH.Core.Term    (Term(..),TmName)
import CLaSH.Core.TyCon   (TyCon(..),tyConDataCons)
import CLaSH.Core.Type    (isFunTy)
import CLaSH.Core.TypeRep (Type(..))
import CLaSH.Core.Util    (Gamma,collectArgs)
import CLaSH.Core.Var     (Var(..),Id)
import CLaSH.Normalize.Types
import CLaSH.Rewrite.Types
import CLaSH.Rewrite.Util

isBoxTy ::
  Type
  -> Bool
isBoxTy (TyConApp tc tys) = any (\t -> isBoxTy t || isFunTy t) (conArgs tc tys)
isBoxTy _                 = False

conArgs :: TyCon -> [Type] -> [Type]
conArgs tc tys = bigUnionTys $ map (flip dataConInstArgTys tys)
               $ tyConDataCons tc
  where
    bigUnionTys :: [[Type]] -> [Type]
    bigUnionTys []   = []
    bigUnionTys tyss = foldl1 (List.unionBy aeq) tyss

alreadyInlined ::
  TmName
  -> NormalizeMonad Bool
alreadyInlined f = do
  cf <- LabelM.gets curFun
  inlinedHM <- LabelM.gets inlined
  case HashMap.lookup cf inlinedHM of
    Nothing -> do
      return False
    Just inlined' -> do
      if (f `elem` inlined')
        then return True
        else do
          return False

commitNewInlined :: NormRewrite
commitNewInlined _ e = R $ liftR $ do
  cf <- LabelM.gets curFun
  nI <- LabelM.gets newInlined
  inlinedHM <- LabelM.gets inlined
  case HashMap.lookup cf inlinedHM of
    Nothing -> LabelM.modify inlined (HashMap.insert cf nI)
    Just hm -> LabelM.modify inlined (HashMap.adjust (`List.union` nI) cf)
  LabelM.puts newInlined []
  return e

fvs2bvs ::
  Gamma
  -> [TmName]
  -> [Id]
fvs2bvs gamma = map (\n -> Id n (embed $ gamma HashMap.! n))

isSimple ::
  Term
  -> Bool
isSimple (Var _)     = True
isSimple (Literal _) = True
isSimple (Data _)    = True
isSimple e@(App _ _)
  | (Data _, args) <- collectArgs e = all (either isSimple (const True)) args
isSimple _ = False