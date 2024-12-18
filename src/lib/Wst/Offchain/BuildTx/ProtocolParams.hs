{-# LANGUAGE OverloadedStrings #-}

module Wst.Offchain.BuildTx.ProtocolParams (
  mintProtocolParams
) where

import Cardano.Api qualified as C
import Cardano.Api.Shelley qualified as C
import Convex.BuildTx (MonadBuildTx, mintPlutus, prependTxOut,
                       spendPublicKeyOutput)
import Convex.Class (MonadBlockchain (..))
import Convex.PlutusLedger.V1 (unTransAssetName)
import Convex.Scripts (toHashableScriptData)
import Convex.Utils qualified as Utils
import GHC.Exts (IsList (..))
import PlutusLedgerApi.V3 qualified as P
import Wst.Offchain.Scripts (protocolParamsMintingScript,
                             protocolParamsSpendingScript, scriptPolicyIdV3)

protocolParamsToken :: C.AssetName
protocolParamsToken = unTransAssetName $ P.TokenName "ProtocolParamsNFT"

mintProtocolParams :: forall era a m. (C.IsBabbageBasedEra era, MonadBuildTx era m, P.ToData a, C.HasScriptLanguageInEra C.PlutusScriptV3 era, MonadBlockchain era m) => a -> C.TxIn -> m ()
mintProtocolParams d txIn = Utils.inBabbage @era $ do
  netId <- queryNetworkId
  let
      mintingScript = protocolParamsMintingScript txIn

      val = C.TxOutValueShelleyBased C.shelleyBasedEra $ C.toLedgerValue @era C.maryBasedEra
            $ fromList [(C.AssetId (scriptPolicyIdV3 mintingScript) protocolParamsToken, 1)]

      addr =
        C.makeShelleyAddressInEra
          C.shelleyBasedEra
          netId
          (C.PaymentCredentialByScript $ C.hashScript $ C.PlutusScript C.PlutusScriptV3 protocolParamsSpendingScript)
          C.NoStakeAddress

      -- Should contain directoryNodeCS and progLogicCred fields
      dat = C.TxOutDatumInline C.babbageBasedEra $ toHashableScriptData d

      output :: C.TxOut C.CtxTx era
      output = C.TxOut addr val dat C.ReferenceScriptNone

  spendPublicKeyOutput txIn
  mintPlutus mintingScript () protocolParamsToken 1
  prependTxOut output
