{-# OPTIONS_GHC -Wno-deprecations #-}
module Concordium.Types.DummyData where

import Data.FixedByteString as FBS
import System.Random

import Concordium.Crypto.VRF as VRF
import qualified Concordium.Crypto.SignatureScheme as Sig
import Concordium.Crypto.DummyData
import Concordium.Crypto.SHA256

import Concordium.Types
import Concordium.Types.Transactions
import Concordium.Types.Execution
import Concordium.ID.Types


{-# WARNING dummyblockPointer "Do not use in production." #-}
dummyblockPointer :: BlockHash
dummyblockPointer = Hash (FBS.pack (replicate 32 (fromIntegral (0 :: Word))))

{-# WARNING mateuszAccount "Do not use in production." #-}
mateuszAccount :: AccountAddress
mateuszAccount = accountAddressFrom 0

{-# WARNING alesAccount "Do not use in production." #-}
alesAccount :: AccountAddress
alesAccount = accountAddressFrom 1

{-# WARNING thomasAccount "Do not use in production." #-}
thomasAccount :: AccountAddress
thomasAccount = accountAddressFrom 2

{-# WARNING accountAddressFrom "Do not use in production." #-}
accountAddressFrom :: Int -> AccountAddress
accountAddressFrom n = fst (randomAccountAddress (mkStdGen n))

{-# WARNING accountAddressFromCred "Do not use in production." #-}
accountAddressFromCred :: CredentialDeploymentInformation -> AccountAddress
accountAddressFromCred = credentialAccountAddress . cdiValues

-- The expiry time is set to the same time as slot time, which is currently also 0.
-- If slot time increases, in order for tests to pass transaction expiry must also increase.
{-# WARNING dummyLowTransactionExpiryTime "Do not use in production." #-}
dummyLowTransactionExpiryTime :: TransactionExpiryTime
dummyLowTransactionExpiryTime = 0

{-# WARNING dummyMaxTransactionExpiryTime "Do not use in production." #-}
dummyMaxTransactionExpiryTime :: TransactionExpiryTime
dummyMaxTransactionExpiryTime = TransactionExpiryTime maxBound

{-# WARNING dummySlotTime "Do not use in production." #-}
dummySlotTime :: Timestamp
dummySlotTime = 0

{-# WARNING bakerElectionKey "Do not use in production." #-}
bakerElectionKey :: Int -> BakerElectionPrivateKey
bakerElectionKey n = fst (VRF.randomKeyPair (mkStdGen n))

{-# WARNING bakerSignKey "Do not use in production." #-}
bakerSignKey :: Int -> BakerSignPrivateKey
bakerSignKey n = fst (randomBlockKeyPair (mkStdGen n))

{-# WARNING bakerAggregationKey "Do not use in production." #-}
bakerAggregationKey :: Int -> BakerAggregationPrivateKey
bakerAggregationKey n = fst (randomBlsSecretKey (mkStdGen n))

{-# WARNING makeTransferTransaction "Dummy transaction, only use for testing." #-}
-- NB: The cost needs to be in-line with that defined in the scheduler.
makeTransferTransaction :: (Sig.KeyPair, AccountAddress) -> AccountAddress -> Amount -> Nonce -> BlockItem
makeTransferTransaction (fromKP, fromAddress) toAddress amount n =
  normalTransaction . fromBareTransaction 0 . signTransactionSingle fromKP header $ payload
    where
        header = TransactionHeader{
            thNonce = n,
            thSender = fromAddress,
            -- The cost needs to be in-line with that in the scheduler
            thEnergyAmount = 6 + 1 * 53 + 0,
            thExpiry = dummyMaxTransactionExpiryTime,
            thPayloadSize = payloadSize payload
        }
        payload = encodePayload (Transfer toAddress amount)
