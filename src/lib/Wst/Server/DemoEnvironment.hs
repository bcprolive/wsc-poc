{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-| A single route that returns the blockfrost API key used on the backend.
(not ideal to expose it like this, but we are pressed for time!)
-}
module Wst.Server.DemoEnvironment(
  DemoEnvRoute,
  DemoEnvironment(..),
  runDemoEnvRoute,
  previewNetworkDemoEnvironment
) where

import Cardano.Api qualified as C
import Control.Lens ((&), (?~))
import Data.Aeson (FromJSON (..), ToJSON (..))
import Data.Aeson qualified as JSON
import Data.OpenApi (OpenApiType (OpenApiString), ToParamSchema (..),
                     ToSchema (..))
import Data.OpenApi.Lens qualified as L
import Data.OpenApi.Schema qualified as Schema
import Data.OpenApi.SchemaOptions qualified as SchemaOptions
import Data.Proxy (Proxy (..))
import Data.String (IsString (..))
import Data.Text (Text)
import GHC.Generics (Generic)
import Servant.API (Get, JSON, (:>))
import Servant.Server (ServerT)
import Wst.JSON.Utils qualified as JSON
import Wst.Server.Types (SerialiseAddress (..))

{-| Demo environment route
-}
type DemoEnvRoute = "api" :> "v1" :> "demo-environment" :> Get '[JSON] DemoEnvironment

runDemoEnvRoute :: Applicative m => Text -> ServerT DemoEnvRoute m
runDemoEnvRoute = pure . previewNetworkDemoEnvironment

{-| Seed phrase
-}
newtype WalletSeedPhrase = WalletSeedPhrase Text
  deriving newtype (ToJSON, FromJSON, IsString, ToSchema)
  deriving stock (Eq, Show)

instance ToParamSchema WalletSeedPhrase where
  toParamSchema _proxy =
    mempty
      & L.type_ ?~ OpenApiString
      & L.description ?~ "21-word seed phrase"

{-| Seed phrases of the demo accounts + the blockfrost key and base URL
-}
data DemoEnvironment =
  DemoEnvironment
    { daMintAuthority    :: WalletSeedPhrase
    , daUserA            :: WalletSeedPhrase
    , daUserB            :: WalletSeedPhrase
    , daBlockfrostUrl    :: Text
    , daBlockfrostKey    :: Text
    , daMintingPolicy    :: Text
    , daTokenName        :: Text
    , daTransferLogicAddress :: SerialiseAddress (C.Address C.ShelleyAddr)
    , daProgLogicBaseHash :: Text
    , daNetwork :: Network
    , daExplorerUrl :: Text
    }
    deriving stock (Eq, Show, Generic)

instance ToJSON DemoEnvironment where
  toJSON = JSON.genericToJSON jsonOptions2
  toEncoding = JSON.genericToEncoding jsonOptions2

instance FromJSON DemoEnvironment where
  parseJSON = JSON.genericParseJSON jsonOptions2

instance ToSchema DemoEnvironment where
  declareNamedSchema = Schema.genericDeclareNamedSchema (SchemaOptions.fromAesonOptions jsonOptions2)

defAddr :: SerialiseAddress (C.Address C.ShelleyAddr)
defAddr =
  maybe (error "address") SerialiseAddress
  $ C.deserialiseAddress (C.proxyToAsType Proxy)
      "addr_test1qq986m3uel86pl674mkzneqtycyg7csrdgdxj6uf7v7kd857kquweuh5kmrj28zs8czrwkl692jm67vna2rf7xtafhpqk3hecm"

data Network =
  Mainnet | Preview | Preprod | Custom
    deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

instance ToParamSchema Network where
  toParamSchema _proxy =
    mempty
      & L.type_ ?~ OpenApiString
      & L.description ?~ "Network name. One of [Mainnet, Preview, Preprod, Custom]"

previewNetworkDemoEnvironment :: Text -> DemoEnvironment
previewNetworkDemoEnvironment daBlockfrostKey
  = DemoEnvironment
  { daMintAuthority = "problem alert infant glance toss gospel tonight sheriff match else hover upset chicken desert anxiety cliff moment song large seed purpose chalk loan onion"
  , daUserA         = "during dolphin crop lend pizza guilt hen earn easy direct inhale deputy detect season army inject exhaust apple hard front bubble emotion short portion"
  , daUserB         = "silver legal flame powder fence kiss stable margin refuse hold unknown valid wolf kangaroo zero able waste jewel find salad sadness exhibit hello tape"
  , daBlockfrostUrl = "https://cardano-preview.blockfrost.io/api/v0"
  , daBlockfrostKey
  , daMintingPolicy = "b34a184f1f2871aa4d33544caecefef5242025f45c3fa5213d7662a9"
  , daTokenName     = "575354"
  , daTransferLogicAddress = defAddr
  , daProgLogicBaseHash = "fca77bcce1e5e73c97a0bfa8c90f7cd2faff6fd6ed5b6fec1c04eefa"
  , daNetwork = Preview
  , daExplorerUrl = "https://preview.cexplorer.io/tx"
  }

jsonOptions2 :: JSON.Options
jsonOptions2 = JSON.customJsonOptions 2
