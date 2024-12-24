{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Wst.Offchain.Scripts (
  protocolParamsMintingScript,
  protocolParamsSpendingScript,
  directoryNodeMintingScript,
  directoryNodeSpendingScript,
  programmableLogicMintingScript,
  programmableLogicBaseScript,
  programmableLogicGlobalScript,

  -- Transfer logic
  permissionedTransferScript,
  freezeAndSezieTransferScript,
  blacklistMintingScript,
  blacklistSpendingScript,

  -- * Always suceeds
  alwaysSucceedsScript,

  -- Utils
  scriptPolicyIdV3
  )
  where

import Cardano.Api qualified as C
import Cardano.Api.Shelley qualified as C
import Convex.PlutusLedger.V1 (transCredential, transPolicyId, transPubKeyHash,
                               transStakeCredential)
import Convex.PlutusLedger.V3 (transTxOutRef)
import Plutarch (ClosedTerm, Config (..), LogLevel (..), TracingMode (..), (#))
import Plutarch.Builtin (pdata, pforgetData)
import Plutarch.ByteString (PByteString)
import Plutarch.Lift (pconstant)
import Plutarch.Script (serialiseScript)
import SmartTokens.Contracts.AlwaysYields (palwaysSucceed)
import SmartTokens.Contracts.ExampleTransferLogic (mkFreezeAndSeizeTransfer,
                                                   mkPermissionedTransfer)
import SmartTokens.Contracts.Issuance (mkProgrammableLogicMinting)
import SmartTokens.Contracts.ProgrammableLogicBase (mkProgrammableLogicBase,
                                                    mkProgrammableLogicGlobal)
import SmartTokens.Contracts.ProtocolParams (alwaysFailScript,
                                             mkPermissionedMinting,
                                             mkProtocolParametersMinting)
import SmartTokens.Core.Scripts (tryCompile)
import SmartTokens.LinkedList.MintDirectory (mkDirectoryNodeMP)
import SmartTokens.LinkedList.SpendDirectory (pmkDirectorySpending)

tracingConfig :: Config
tracingConfig = Tracing LogInfo DoTracingAndBinds

prodConfig :: Config
prodConfig = NoTracing

-- Protocol params

-- | The minting script for the protocol parameters NFT, takes initial TxIn for
-- one shot mint
protocolParamsMintingScript :: C.TxIn -> C.PlutusScript C.PlutusScriptV3
protocolParamsMintingScript txIn =
  let script = tryCompile prodConfig $ mkProtocolParametersMinting # pdata (pconstant $ transTxOutRef txIn)
  in C.PlutusScriptSerialised $ serialiseScript script

-- | The spending script for the protocol parameters NFT parameterized by ""
-- nonce
protocolParamsSpendingScript :: C.PlutusScript C.PlutusScriptV3
protocolParamsSpendingScript =
  let script = tryCompile prodConfig $ alwaysFailScript # pforgetData (pdata (pconstant "" :: ClosedTerm PByteString))
  in C.PlutusScriptSerialised $ serialiseScript script

-- | The minting script for the directory node tokens, takes initial TxIn for
-- symbol uniqueness across instances
directoryNodeMintingScript :: C.TxIn -> C.PlutusScript C.PlutusScriptV3
directoryNodeMintingScript txIn =
  let script = tryCompile tracingConfig $ mkDirectoryNodeMP # pdata (pconstant $ transTxOutRef txIn)
  in C.PlutusScriptSerialised $ serialiseScript script

-- | The spending script for the directory node tokens, parameterized by the
-- policy id of the protocol parameters NFT.
directoryNodeSpendingScript :: C.PolicyId -> C.PlutusScript C.PlutusScriptV3
directoryNodeSpendingScript paramsPolId =
  let script = tryCompile prodConfig $ pmkDirectorySpending # pdata (pconstant $ transPolicyId paramsPolId)
  in C.PlutusScriptSerialised $ serialiseScript script

-- TODO: can we change the signature to just take the param policy id?
programmableLogicMintingScript :: C.PaymentCredential -> C.StakeCredential -> C.PolicyId -> C.PlutusScript C.PlutusScriptV3
programmableLogicMintingScript progLogicBaseSpndingCred mintingCred nodePolId =
  let script = tryCompile tracingConfig
               $ mkProgrammableLogicMinting
                  # pdata (pconstant $ transCredential progLogicBaseSpndingCred)
                  # pdata (pconstant $ transPolicyId nodePolId)
                  # pdata (pconstant $ transStakeCredential mintingCred)
  in C.PlutusScriptSerialised $ serialiseScript script

programmableLogicBaseScript :: C.StakeCredential -> C.PlutusScript C.PlutusScriptV3 -- Parameterized by the stake cred of the global script
programmableLogicBaseScript globalCred =
  let script = tryCompile prodConfig $ mkProgrammableLogicBase # pdata (pconstant $ transStakeCredential globalCred)
  in C.PlutusScriptSerialised $ serialiseScript script

programmableLogicGlobalScript :: C.PolicyId -> C.PlutusScript C.PlutusScriptV3 -- Parameterized by the CS holding protocol params datum
programmableLogicGlobalScript paramsPolId =
  let script = tryCompile tracingConfig $ mkProgrammableLogicGlobal # pdata (pconstant $ transPolicyId paramsPolId)
  in C.PlutusScriptSerialised $ serialiseScript script

permissionedTransferScript :: C.Hash C.PaymentKey -> C.PlutusScript C.PlutusScriptV3
permissionedTransferScript cred =
  let script = tryCompile prodConfig $ mkPermissionedTransfer # pdata (pconstant $ transPubKeyHash cred)
  in C.PlutusScriptSerialised $ serialiseScript script

freezeAndSezieTransferScript :: C.PolicyId -> C.PlutusScript C.PlutusScriptV3
freezeAndSezieTransferScript blacklistPolicyId =
  -- TODO: maybe mkFreezeAndSeizeTransfer should be called mkFreezeTransfer as
  -- seizing is handled separately
  let script = tryCompile prodConfig $ mkFreezeAndSeizeTransfer # pdata (pconstant $ transPolicyId blacklistPolicyId)
  in C.PlutusScriptSerialised $ serialiseScript script

blacklistMintingScript :: C.Hash C.PaymentKey -> C.PlutusScript C.PlutusScriptV3
blacklistMintingScript cred =
  let script = tryCompile prodConfig $ mkPermissionedMinting # pdata (pconstant $ transPubKeyHash cred)
  in C.PlutusScriptSerialised $ serialiseScript script

blacklistSpendingScript :: C.Hash C.PaymentKey -> C.PlutusScript C.PlutusScriptV3
blacklistSpendingScript cred =
  let script = tryCompile prodConfig $ mkPermissionedTransfer # pdata (pconstant $ transPubKeyHash cred)
  in C.PlutusScriptSerialised $ serialiseScript script

{-| 'C.PlutusScript C.PlutusScriptV3' that always succeeds. Can be used for minting, withdrawal, spending, etc.
-}
alwaysSucceedsScript :: C.PlutusScript C.PlutusScriptV3
alwaysSucceedsScript =
  C.PlutusScriptSerialised $ serialiseScript $ tryCompile prodConfig palwaysSucceed

-- Utilities
scriptPolicyIdV3 :: C.PlutusScript C.PlutusScriptV3 -> C.PolicyId
scriptPolicyIdV3 = C.scriptPolicyId . C.PlutusScript C.PlutusScriptV3
