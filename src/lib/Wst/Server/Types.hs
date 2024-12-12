{-# LANGUAGE TypeOperators      #-}
{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass     #-}


{- | This module contains the relevant types for the server.
 -}
module Wst.Server.Types (
  API,
  InitParams(..),
  UpdateParams(..),
  TransferToUserParams(..),
  TransferToIssuerParams(..),
  QueryAddressParams(..),
  QueryAllSanctionedAddressesParams(..)
) where

import Servant.API (Description, Get, JSON, NoContent,
                    Post, ReqBody,
                    type (:>), (:<|>) (..), Capture)
import Data.Aeson (FromJSON)
import GHC.Generics (Generic)
import Data.Aeson.Types (ToJSON)

type API =
  "healthcheck" :> Description "Is the server alive?" :> Get '[JSON] NoContent
  :<|> "init-merkle-tree" :> Description "Initialize a new Merkle tree." :> ReqBody '[JSON] String :> Post '[JSON] String
  :<|> "update-merkle-tree" :> Description "Update the Merkle tree." :> ReqBody '[JSON] String :> Post '[JSON] String -- This might need to be broken down further
  :<|> "transfer-to-user" :> Description "Transfer tokens to a user." :> ReqBody '[JSON] String :> Post '[JSON] String
  :<|> "transfer-to-issuer" :> Description "Transfer tokens to an issuer." :> ReqBody '[JSON] String :> Post '[JSON] String
  :<|> "address" :> Description "Query the balance of an address." :> Capture "address" String :> Get '[JSON] String
  :<|> "all-sanctioned-addresses" :> Description "Query all sanctioned addresses." :> Get '[JSON] String


data InitParams = InitParams {
  ipName :: String
} deriving stock (Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data UpdateParams = UpdateParams {
  upName :: String
}

data TransferToUserParams = TransferToUserParams {
  ttpName :: String
}

data TransferToIssuerParams = TransferToIssuerParams {
  ttipName :: String
}

data QueryAddressParams = QueryAddressParams {
  qapName :: String
}

data QueryAllSanctionedAddressesParams = QueryAllSanctionedAddressesParams {
  qasapName :: String
}
