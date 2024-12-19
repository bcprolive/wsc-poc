{-# OPTIONS_GHC -Wno-unused-do-bind #-}
{-# OPTIONS_GHC -Wno-partial-type-signatures #-}
{-# LANGUAGE ImpredicativeTypes    #-}
{-# LANGUAGE OverloadedLabels      #-}
{-# LANGUAGE OverloadedRecordDot   #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE QualifiedDo           #-}
{-# LANGUAGE UndecidableInstances  #-}

module SmartTokens.Types.PTokenDirectory (
  DirectorySetNode (..),
  PDirectorySetNode (..),
  PBlacklistNode (..),
  isHeadNode,
  isTailNode,
  pemptyBSData,
  pemptyCSData,
  pmkDirectorySetNode,
  pisInsertedOnNode,
  pisInsertedNode,
  pletFieldsBlacklistNode,
  pisEmptyNode,
  BlacklistNode(..),
) where

import Data.Text qualified as T
import Generics.SOP qualified as SOP
import GHC.Stack (HasCallStack)
import Plutarch (Config (NoTracing))
import Plutarch.Builtin (pasByteStr, pasConstr, pasList, pforgetData, plistData)
import Plutarch.Core.PlutusDataList (DerivePConstantViaDataList (..),
                                     PlutusTypeDataList, ProductIsData (..))
import Plutarch.Core.Utils (pcond, pheadSingleton, pmkBuiltinList)
import Plutarch.DataRepr (PDataFields)
import Plutarch.DataRepr.Internal (DerivePConstantViaData (..), PDataRecord,
                                   PLabeledType ((:=)), PlutusTypeData)
import Plutarch.DataRepr.Internal.Field (HRec (..), Labeled (Labeled))
import Plutarch.Evaluate (unsafeEvalTerm)
import Plutarch.Internal qualified as PI
import Plutarch.Internal.Other (printScript)
import Plutarch.LedgerApi.V3 (PCredential, PCurrencySymbol)
import Plutarch.Lift (PConstantDecl, PUnsafeLiftDecl (PLifted))
import Plutarch.Prelude
import Plutarch.Unsafe (punsafeCoerce)
import PlutusLedgerApi.V3 (BuiltinByteString, Credential, CurrencySymbol)
import PlutusTx (Data (B, Constr), FromData, ToData, UnsafeFromData)
import SmartTokens.CodeLens (_printTerm)

data BlacklistNode =
  BlacklistNode {
    blnKey :: Credential,
    blnNext :: Credential
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (SOP.Generic)
  deriving
    (PlutusTx.ToData, PlutusTx.FromData, PlutusTx.UnsafeFromData) via (ProductIsData BlacklistNode)

deriving via (DerivePConstantViaData BlacklistNode PBlacklistNode)
  instance (PConstantDecl BlacklistNode)

newtype PBlacklistNode (s :: S)
  = PBlacklistNode
      ( Term
          s
          ( PDataRecord
              '[ "blnKey" ':= PByteString
               , "blnNext" ':= PByteString
               ]
          )
      )
  deriving stock (Generic)
  deriving anyclass (PlutusType, PDataFields, PIsData)

instance DerivePlutusType PBlacklistNode where
  type DPTStrat PBlacklistNode = PlutusTypeData

instance PUnsafeLiftDecl PBlacklistNode where
  type PLifted PBlacklistNode = BlacklistNode


type PBlacklistNodeHRec (s :: S) =
  HRec
    '[ '("key", Term s (PAsData PByteString))
     , '("next", Term s (PAsData PByteString))
     ]

-- | Helper function to extract fields from a 'PBlacklistNode' term.
-- >>> _printTerm $ unsafeEvalTerm NoTracing (pletFieldsBlacklistNode (unsafeEvalTerm NoTracing (pconstantData $ BlacklistNode { blnKey = "deadbeee", blnNext = "deadbeef" })) $ \fields -> fields.key)
-- "programs 1.0.0 (B #6465616462656565)"
pletFieldsBlacklistNode :: forall {s :: S} {r :: PType}. Term s (PAsData PBlacklistNode) -> (PBlacklistNodeHRec s -> Term s r) -> Term s r
pletFieldsBlacklistNode term = runTermCont $ do
  fields <- tcont $ plet $ pasList # pforgetData term
  let key_ = punsafeCoerce @_ @_ @(PAsData PByteString) $ phead # fields
      next_ = punsafeCoerce @_ @_ @(PAsData PByteString) $ pheadSingleton # (ptail # fields)
  tcont $ \f -> f $ HCons (Labeled @"key" key_) (HCons (Labeled @"next" next_) HNil)

data DirectorySetNode = DirectorySetNode
  { key :: CurrencySymbol
  , next :: CurrencySymbol
  , transferLogicScript  :: Credential
  , issuerLogicScript :: Credential
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (SOP.Generic)
  deriving
    (PlutusTx.ToData, PlutusTx.FromData, PlutusTx.UnsafeFromData) via (ProductIsData DirectorySetNode)

deriving via
  ( DerivePConstantViaDataList
      DirectorySetNode
      PDirectorySetNode
  )
  instance
    (PConstantDecl DirectorySetNode)

-- Optimization:
-- Use the following manual instances instead of the deriving via above if so that we can define key and next fields of type ByteString
-- We should discuss whether we want to prefer newtypes or primitive types for datum / redeemer fields going forward.
-- import Data.ByteString
-- import PlutusTx.Builtins qualified as Builtins
-- import PlutusTx.Builtins.Internal qualified as BI
-- import PlutusTx.Prelude (BuiltinByteString, fromBuiltin, toBuiltin)
-- instance PlutusTx.ToData DirectorySetNode where
--   toBuiltinData DirectorySetNode{key, next, transferLogicScript, issuerLogicScript} =
--     BI.mkList $ BI.mkCons (BI.mkB $ toBuiltin key) $ BI.mkCons (BI.mkB $ toBuiltin next) $ BI.mkCons (PlutusTx.toBuiltinData transferLogicScript) $ BI.mkCons (PlutusTx.toBuiltinData issuerLogicScript) $ BI.mkNilData BI.unitval

-- instance PlutusTx.FromData DirectorySetNode where
--   fromBuiltinData builtinData =
--     let fields = BI.snd $ BI.unsafeDataAsConstr builtinData
--         key = BI.head fields
--         fields1 = BI.tail fields
--         next = BI.head fields1
--         fields2 = BI.tail fields1
--         transferLogicScript = PlutusTx.unsafeFromBuiltinData $ BI.head fields2
--         fields3 = BI.tail fields2
--         issuerLogicScript = PlutusTx.unsafeFromBuiltinData $ BI.head fields3
--      in Just $ DirectorySetNode (fromBuiltin $ BI.unsafeDataAsB key) (fromBuiltin $ BI.unsafeDataAsB next) transferLogicScript issuerLogicScript


newtype PDirectorySetNode (s :: S)
  = PDirectorySetNode
      ( Term
          s
          ( PDataRecord
              '[ "key" ':= PCurrencySymbol
               , "next" ':= PCurrencySymbol
               , "transferLogicScript" ':= PCredential
               , "issuerLogicScript" ':= PCredential
               ]
          )
      )
  deriving stock (Generic)
  deriving anyclass (PlutusType, PIsData, PEq, PShow, PDataFields)

instance DerivePlutusType PDirectorySetNode where
  type DPTStrat _ = PlutusTypeDataList

instance PUnsafeLiftDecl PDirectorySetNode where
  type PLifted PDirectorySetNode = DirectorySetNode

isHeadNode :: ClosedTerm (PAsData PDirectorySetNode :--> PBool)
isHeadNode = plam $ \node ->
  pfield @"key" # node #== pemptyCSData

isTailNode :: ClosedTerm (PAsData PDirectorySetNode :--> PBool)
isTailNode = plam $ \node ->
  pfield @"next" # node #== pemptyCSData

{-|

>>> _printTerm $ unsafeEvalTerm NoTracing emptyNode
"program\n  1.0.0\n  (List\n     [ B #\n     , B #ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\n     , Constr 0 [B #]\n     , Constr 0 [B #] ])"
-}
emptyNode :: ClosedTerm (PAsData PDirectorySetNode)
emptyNode =
  let nullTransferLogicCred = pconstant (Constr 0 [PlutusTx.B ""])
      nullIssuerLogicCred = pconstant (Constr 0 [PlutusTx.B ""])
  in punsafeCoerce $ plistData # pmkBuiltinList [pforgetData pemptyBSData, pforgetData ptailNextData, nullTransferLogicCred, nullIssuerLogicCred]

pisEmptyNode :: ClosedTerm (PAsData PDirectorySetNode :--> PBool)
pisEmptyNode = plam $ \node ->
  node #== emptyNode

pemptyBSData :: ClosedTerm (PAsData PByteString)
pemptyBSData = unsafeEvalTerm NoTracing (punsafeCoerce (pconstant $ PlutusTx.B ""))

pemptyCSData :: ClosedTerm (PAsData PCurrencySymbol)
pemptyCSData = unsafeEvalTerm NoTracing (punsafeCoerce (pconstant $ PlutusTx.B ""))

ptailNextData  :: ClosedTerm (PAsData PCurrencySymbol)
ptailNextData = unsafeEvalTerm NoTracing (punsafeCoerce $ pdata (phexByteStr "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"))

pmkDirectorySetNode :: ClosedTerm (PAsData PByteString :--> PAsData PByteString :--> PAsData PCredential :--> PAsData PCredential :--> PAsData PDirectorySetNode)
pmkDirectorySetNode = phoistAcyclic $
  plam $ \key_ next_ transferLogicCred issuerLogicCred ->
    punsafeCoerce $ plistData # pmkBuiltinList [pforgetData key_, pforgetData next_, pforgetData transferLogicCred, pforgetData issuerLogicCred]

pisInsertedOnNode :: ClosedTerm (PAsData PByteString :--> PAsData PByteString :--> PAsData PCredential :--> PAsData PCredential :--> PAsData PDirectorySetNode :--> PBool)
pisInsertedOnNode = phoistAcyclic $
  plam $ \insertedKey coveringKey transferLogicCred issuerLogicCred outputNode ->
    let expectedDirectoryNode = pmkDirectorySetNode # coveringKey # insertedKey # transferLogicCred # issuerLogicCred
     in outputNode #== expectedDirectoryNode

-- pisInsertedNode :: ClosedTerm (PAsData PByteString :--> PAsData PByteString :--> PAsData PCredential :--> PAsData PCredential :--> PAsData PDirectorySetNode :--> PBool)
-- pisInsertedNode = phoistAcyclic $
--   plam $ \insertedKey coveringNext transferLogicCred issuerLogicCred outputNode ->
--     let expectedDirectoryNode = pmkDirectorySetNode # insertedKey # coveringNext # transferLogicCred # issuerLogicCred
--      in outputNode #== expectedDirectoryNode

pisInsertedNode :: ClosedTerm (PAsData PByteString :--> PAsData PByteString :--> PAsData PDirectorySetNode :--> PBool)
pisInsertedNode = phoistAcyclic $
  plam $ \insertedKey coveringNext outputNode ->
    pletFields @'["transferLogicScript", "issuerLogicScript"] outputNode $ \outputNodeDatumF ->
      let transferLogicCred_ = outputNodeDatumF.transferLogicScript
          issuerLogicCred_ = outputNodeDatumF.issuerLogicScript
          expectedDirectoryNode =
            pmkDirectorySetNode # insertedKey # coveringNext # pdeserializeCredential transferLogicCred_ # pdeserializeCredential issuerLogicCred_
      in outputNode #== expectedDirectoryNode

pdeserializeCredential :: Term s (PAsData PCredential) -> Term s (PAsData PCredential)
pdeserializeCredential term =
  plet (pasConstr # pforgetData term) $ \constrPair ->
    plet (pfstBuiltin # constrPair) $ \constrIdx ->
      pif (plengthBS # (pasByteStr # (pheadSingleton # (psndBuiltin # constrPair))) #== 28)
          (
            pcond
              [ ( constrIdx #== 0 , term)
              , ( constrIdx #== 1 , term)
              ]
              perror
          )
          perror
