{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE StandaloneDeriving #-}

module Concordium.Types.Parameters where

import Control.Monad
import qualified Data.Aeson as AE
import Data.Aeson.Types
import Data.Aeson.TH
import Data.Ratio
import Data.Serialize
import Data.Word
import Data.Maybe
import Lens.Micro.Platform

import qualified Concordium.Crypto.SHA256 as Hash
import Concordium.ID.Parameters
import Concordium.Types
import Concordium.Types.HashableTo
import Concordium.Utils

-- |Chain cryptographic parameters.
type CryptographicParameters = GlobalContext

data MintPerSlotForCPV0 cpv where
  MintPerSlotForCPV0Some :: {_mpsMintPerSlot :: !MintRate} -> MintPerSlotForCPV0 'ChainParametersV0
  MintPerSlotForCPV0None :: MintPerSlotForCPV0 'ChainParametersV1

instance IsChainParametersVersion cpv => Serialize (MintPerSlotForCPV0 cpv) where
  put MintPerSlotForCPV0Some{..} = put _mpsMintPerSlot
  put MintPerSlotForCPV0None = return ()
  get = case chainParametersVersion @cpv of
    SCPV0 -> MintPerSlotForCPV0Some <$> get
    SCPV1 -> return MintPerSlotForCPV0None

-- |Lens for '_mpsMintPerSlot'
{-# INLINE mpsMintPerSlot #-}
mpsMintPerSlot :: Lens' (MintPerSlotForCPV0 'ChainParametersV0) MintRate
mpsMintPerSlot =
  lens _mpsMintPerSlot (\mps x -> mps{_mpsMintPerSlot = x})

deriving instance Eq (MintPerSlotForCPV0 cpv)
deriving instance Show (MintPerSlotForCPV0 cpv)

-- |The minting rate and the distribution of newly-minted GTU
-- among bakers, finalizers, and the foundation account.
-- It must be the case that
-- @_mdBakingReward + _mdFinalizationReward <= 1@.
-- The remaining amount is the platform development charge.
data MintDistribution cpv = MintDistribution {
    -- |Mint rate per slot
    _mdMintPerSlot :: !(MintPerSlotForCPV0 cpv),
    -- |BakingRewMintFrac: the fraction allocated to baker rewards
    _mdBakingReward :: !AmountFraction,
    -- |FinRewMintFrac: the fraction allocated to finalization rewards
    _mdFinalizationReward :: !AmountFraction
} deriving (Eq, Show)
makeClassy ''MintDistribution

instance ToJSON (MintDistribution cpv) where
  toJSON MintDistribution{..} = object (mintPerSlot ++ [
      "bakingReward" AE..= _mdBakingReward,
      "finalizationReward" AE..= _mdFinalizationReward
    ]) where
      mintPerSlot = case _mdMintPerSlot of
        MintPerSlotForCPV0Some{..} -> ["mintPerSlot" AE..= _mpsMintPerSlot]
        MintPerSlotForCPV0None -> []

instance IsChainParametersVersion cpv => FromJSON (MintDistribution cpv) where
  parseJSON = withObject "MintDistribution" $ \v -> do
    _mdMintPerSlot <- case chainParametersVersion @cpv of
      SCPV0 -> MintPerSlotForCPV0Some <$> v .: "mintPerSlot"
      SCPV1 -> return MintPerSlotForCPV0None

    _mdBakingReward <- v .: "bakingReward"
    _mdFinalizationReward <- v .: "finalizationReward"
    unless (isJust (_mdBakingReward `addAmountFraction` _mdFinalizationReward)) $ fail "Amount fractions exceed 100%"
    return MintDistribution{..}

instance IsChainParametersVersion cpv => Serialize (MintDistribution cpv) where
  put MintDistribution{..} = put _mdMintPerSlot >> put _mdBakingReward >> put _mdFinalizationReward
  get = do
    _mdMintPerSlot <- get
    _mdBakingReward <- get
    _mdFinalizationReward <- get
    unless (isJust (_mdBakingReward `addAmountFraction` _mdFinalizationReward)) $ fail "Amount fractions exceed 100%"
    return MintDistribution{..}

instance IsChainParametersVersion cpv => HashableTo Hash.Hash (MintDistribution cpv) where
  getHash = Hash.hash . encode

instance (Monad m, IsChainParametersVersion cpv) => MHashableTo m Hash.Hash (MintDistribution cpv)

-- |The distribution of block transaction fees among the block
-- baker, the GAS account, and the foundation account.  It
-- must be the case that @_tfdBaker + _tfdGASAccount <= 1@.
-- The remaining amount is the TransChargeFrac (paid to the
-- foundation account).
data TransactionFeeDistribution = TransactionFeeDistribution {
    -- |BakerTransFrac: the fraction allocated to the baker
    _tfdBaker :: !AmountFraction,
    -- |The fraction allocated to the GAS account
    _tfdGASAccount :: !AmountFraction
} deriving (Eq, Show)
makeClassy ''TransactionFeeDistribution

instance ToJSON TransactionFeeDistribution where
  toJSON TransactionFeeDistribution{..} = object [
      "baker" AE..= _tfdBaker,
      "gasAccount" AE..= _tfdGASAccount
    ]
instance FromJSON TransactionFeeDistribution where
  parseJSON = withObject "TransactionFeeDistribution" $ \v -> do
    _tfdBaker <- v .: "baker"
    _tfdGASAccount <- v .: "gasAccount"
    unless (isJust (_tfdBaker `addAmountFraction` _tfdGASAccount)) $ fail "Transaction fee fractions exceed 100%"
    return TransactionFeeDistribution{..}

instance Serialize TransactionFeeDistribution where
  put TransactionFeeDistribution{..} = put _tfdBaker >> put _tfdGASAccount
  get = do
    _tfdBaker <- get
    _tfdGASAccount <- get
    unless (isJust (_tfdBaker `addAmountFraction` _tfdGASAccount)) $ fail "Transaction fee fractions exceed 100%"
    return TransactionFeeDistribution{..}

instance HashableTo Hash.Hash TransactionFeeDistribution where
  getHash = Hash.hash . encode

instance Monad m => MHashableTo m Hash.Hash TransactionFeeDistribution

data GASRewards = GASRewards {
  -- |BakerPrevTransFrac: fraction paid to baker
  _gasBaker :: !AmountFraction,
  -- |FeeAddFinalisationProof: fraction paid for including a
  -- finalization proof in a block.
  _gasFinalizationProof :: !AmountFraction,
  -- |FeeAccountCreation: fraction paid for including each
  -- account creation transaction in a block.
  _gasAccountCreation :: !AmountFraction,
  -- |FeeUpdate: fraction paid for including an update
  -- transaction in a block.
  _gasChainUpdate :: !AmountFraction
} deriving (Eq, Show)
makeClassy ''GASRewards

$(deriveJSON AE.defaultOptions{AE.fieldLabelModifier = firstLower . drop 4} ''GASRewards)

instance Serialize GASRewards where
  put GASRewards{..} = do
    put _gasBaker
    put _gasFinalizationProof
    put _gasAccountCreation
    put _gasChainUpdate
  get = do
    _gasBaker <- get
    _gasFinalizationProof <- get
    _gasAccountCreation <- get
    _gasChainUpdate <- get
    return GASRewards{..}

instance HashableTo Hash.Hash GASRewards where
  getHash = Hash.hash . encode

instance Monad m => MHashableTo m Hash.Hash GASRewards

-- |Parameters affecting rewards.
-- It must be that @rpBakingRewMintFrac + rpFinRewMintFrac < 1@
data RewardParameters cpv = RewardParameters {
    -- |Distribution of newly-minted GTUs.
    _rpMintDistribution :: !(MintDistribution cpv),
    -- |Distribution of transaction fees.
    _rpTransactionFeeDistribution :: !TransactionFeeDistribution,
    -- |Rewards paid from the GAS account.
    _rpGASRewards :: !GASRewards
} deriving (Eq, Show)
makeClassy ''RewardParameters

instance HasMintDistribution (RewardParameters cpv) cpv where
  mintDistribution = rpMintDistribution

instance HasTransactionFeeDistribution (RewardParameters cpv) where
  transactionFeeDistribution = rpTransactionFeeDistribution

instance HasGASRewards (RewardParameters cpv) where
  gASRewards = rpGASRewards

instance AE.ToJSON (RewardParameters cpv) where
  toJSON RewardParameters{..} = object [
      "mintDistribution" AE..= _rpMintDistribution,
      "transactionFeeDistribution" AE..= _rpTransactionFeeDistribution,
      "gASRewards" AE..= _rpGASRewards
    ]

instance IsChainParametersVersion cpv => AE.FromJSON (RewardParameters cpv) where
  parseJSON = withObject "RewardParameters" $ \v -> do
    _rpMintDistribution <- v .: "mintDistribution"
    _rpTransactionFeeDistribution <- v .: "transactionFeeDistribution"
    _rpGASRewards <- v .: "gASRewards"
    return RewardParameters{..}

instance IsChainParametersVersion cpv => Serialize (RewardParameters cpv) where
  put RewardParameters{..} = do
    put _rpMintDistribution
    put _rpTransactionFeeDistribution
    put _rpGASRewards
  get = do
    _rpMintDistribution <- get
    _rpTransactionFeeDistribution <- get
    _rpGASRewards <- get
    return RewardParameters{..}


data ExchangeRates = ExchangeRates
    { -- |Euro:Energy rate.
      _erEuroPerEnergy :: !ExchangeRate,
      -- |uGTU:Euro rate.
      _erMicroGTUPerEuro :: !ExchangeRate,
      -- |uGTU:Energy rate.
      -- This is derived, but will be computed when the other
      -- rates are updated since it is more useful.
      _erEnergyRate :: !EnergyRate
    }
    deriving (Eq, Show)

instance Serialize ExchangeRates where
    put ExchangeRates{..} = do
        put _erEuroPerEnergy
        put _erMicroGTUPerEuro
    get = makeExchangeRates <$> get <*> get

makeExchangeRates ::
    -- |Euro:Energy rate
    ExchangeRate ->
    -- |uGTU:Euro rate
    ExchangeRate ->
    ExchangeRates
makeExchangeRates _erEuroPerEnergy _erMicroGTUPerEuro = ExchangeRates{..}
  where
    _erEnergyRate = computeEnergyRate _erMicroGTUPerEuro _erEuroPerEnergy

class HasExchangeRates t where
    exchangeRates :: Lens' t ExchangeRates
    euroPerEnergy :: Lens' t ExchangeRate
    euroPerEnergy = exchangeRates . lens _erEuroPerEnergy (\er epe -> er{_erEuroPerEnergy = epe, _erEnergyRate = computeEnergyRate (_erMicroGTUPerEuro er) epe})
    microGTUPerEuro :: Lens' t ExchangeRate
    microGTUPerEuro = exchangeRates . lens _erMicroGTUPerEuro (\er mgtupe -> er{_erMicroGTUPerEuro = mgtupe, _erEnergyRate = computeEnergyRate mgtupe (_erEuroPerEnergy er)})
    energyRate :: SimpleGetter t EnergyRate
    energyRate = exchangeRates . to _erEnergyRate

instance HasExchangeRates ExchangeRates where
    exchangeRates = id
    euroPerEnergy = lens _erEuroPerEnergy (\er epe -> er{_erEuroPerEnergy = epe, _erEnergyRate = computeEnergyRate (_erMicroGTUPerEuro er) epe})
    microGTUPerEuro = lens _erMicroGTUPerEuro (\er mgtupe -> er{_erMicroGTUPerEuro = mgtupe, _erEnergyRate = computeEnergyRate mgtupe (_erEuroPerEnergy er)})
    energyRate = to _erEnergyRate

-- |Euro:Energy rate parameter.
{-# INLINE erEuroPerEnergy #-}
erEuroPerEnergy :: Lens' ExchangeRates ExchangeRate
erEuroPerEnergy = lens _erEuroPerEnergy (\er epe -> er{_erEuroPerEnergy = epe, _erEnergyRate = computeEnergyRate (_erMicroGTUPerEuro er) epe})

-- |uGTU:Euro rate parameter.
{-# INLINE erMicroGTUPerEuro #-}
erMicroGTUPerEuro :: Lens' ExchangeRates ExchangeRate
erMicroGTUPerEuro = lens _erMicroGTUPerEuro (\er mgtupe -> er{_erMicroGTUPerEuro = mgtupe, _erEnergyRate = computeEnergyRate mgtupe (_erEuroPerEnergy er)})

-- |uGTU:Energy rate parameter (derived).
{-# INLINE erEnergyRate #-}
erEnergyRate :: SimpleGetter ExchangeRates EnergyRate
erEnergyRate = to _erEnergyRate

-- |Version-indexed type of cooldown parameters.
-- This is a newtype to provide instances of 'Eq' and 'Show'.
data CooldownParameters cpv where
    CooldownParametersV0 ::
        { -- |Number of additional epochs that bakers must cool down when
          -- removing stake. The cool-down will effectively be 2 epochs
          -- longer than this value, since at any given time, the bakers
          -- (and stakes) for the current and next epochs have already
          -- been determined.
          _cpBakerExtraCooldownEpochs :: Epoch
        } ->
        CooldownParameters 'ChainParametersV0
    CooldownParametersV1 ::
        { -- |Number of seconds that pool owners must cooldown
          -- when reducing their equity capital or closing the pool.
          _cpPoolOwnerCooldown :: !DurationSeconds,
          -- |Number of seconds that a delegator must cooldown
          -- when reducing their delegated stake.
          _cpDelegatorCooldown :: !DurationSeconds
        } ->
        CooldownParameters 'ChainParametersV1

instance ToJSON (CooldownParameters cpv) where
  toJSON CooldownParametersV0{..} =
        object [
            "bakerCooldownEpochs" AE..= _cpBakerExtraCooldownEpochs
        ]
  toJSON CooldownParametersV1{..} =
        object [
            "poolOwnerCooldown" AE..= _cpPoolOwnerCooldown,
            "delegatorCooldown" AE..= _cpDelegatorCooldown
        ]

parseCooldownParametersJSON :: forall cpv.  IsChainParametersVersion cpv => Value -> Parser (CooldownParameters cpv)
parseCooldownParametersJSON = case chainParametersVersion @cpv of
  SCPV0 -> withObject "CooldownParametersV0" $ \v -> CooldownParametersV0 <$> v .: "bakerCooldownEpochs"
  SCPV1 -> withObject "CooldownParametersV1" $ \v -> CooldownParametersV1 <$> v .: "poolOwnerCooldown"
                                                                          <*> v .: "delegatorCooldown"

instance IsChainParametersVersion cpv => FromJSON (CooldownParameters cpv) where
  parseJSON = parseCooldownParametersJSON


-- |Lens for '_cpBakerExtraCooldownEpochs'
{-# INLINE cpBakerExtraCooldownEpochs #-}
cpBakerExtraCooldownEpochs :: Lens' (CooldownParameters 'ChainParametersV0) Epoch
cpBakerExtraCooldownEpochs =
  lens _cpBakerExtraCooldownEpochs (\cp x -> cp{_cpBakerExtraCooldownEpochs = x})

-- |Lens for '_cpPoolOwnerCooldown'
{-# INLINE cpPoolOwnerCooldown #-}
cpPoolOwnerCooldown :: Lens' (CooldownParameters 'ChainParametersV1) DurationSeconds
cpPoolOwnerCooldown =
  lens _cpPoolOwnerCooldown (\cp x -> cp{_cpPoolOwnerCooldown = x})

-- |Lens for '_cpDelegatorCooldown'
{-# INLINE cpDelegatorCooldown #-}
cpDelegatorCooldown :: Lens' (CooldownParameters 'ChainParametersV1) DurationSeconds
cpDelegatorCooldown =
  lens _cpDelegatorCooldown (\cp x -> cp{_cpDelegatorCooldown = x})

deriving instance Eq (CooldownParameters cpv)
deriving instance Show (CooldownParameters cpv)

putCooldownParameters :: Putter (CooldownParameters cpv)
putCooldownParameters CooldownParametersV0{..} = do
        put _cpBakerExtraCooldownEpochs
putCooldownParameters CooldownParametersV1{..} = do
        put _cpPoolOwnerCooldown
        put _cpDelegatorCooldown

instance HashableTo Hash.Hash (CooldownParameters cpv) where
    getHash = Hash.hash . runPut . putCooldownParameters

instance Monad m => MHashableTo m Hash.Hash (CooldownParameters cpv)

getCooldownParameters :: forall cpv. IsChainParametersVersion cpv => Get (CooldownParameters cpv)
getCooldownParameters = case chainParametersVersion @cpv of
    SCPV0 -> CooldownParametersV0 <$> get
    SCPV1 -> CooldownParametersV1 <$> get <*> get

instance IsChainParametersVersion cpv => Serialize (CooldownParameters cpv) where
  put = putCooldownParameters
  get = getCooldownParameters

data TimeParameters cpv where
    TimeParametersV0 :: TimeParameters 'ChainParametersV0
    TimeParametersV1 :: {
         _tpRewardPeriodLength :: RewardPeriodLength,
         _tpMintPerPayday :: !MintRate
    } -> TimeParameters 'ChainParametersV1

-- |Lens for '_tpRewardPeriodLength'
{-# INLINE tpRewardPeriodLength #-}
tpRewardPeriodLength :: Lens' (TimeParameters 'ChainParametersV1) RewardPeriodLength
tpRewardPeriodLength =
  lens _tpRewardPeriodLength (\tp x -> tp{_tpRewardPeriodLength = x})


-- |Lens for '_tpMintPerPayday'
{-# INLINE tpMintPerPayday #-}
tpMintPerPayday :: Lens' (TimeParameters 'ChainParametersV1) MintRate
tpMintPerPayday =
  lens _tpMintPerPayday (\tp x -> tp{_tpMintPerPayday = x})

putTimeParameters :: Putter (TimeParameters cpv)
putTimeParameters TimeParametersV0 = return ()
putTimeParameters TimeParametersV1{..} = do
        put _tpRewardPeriodLength
        put _tpMintPerPayday

instance HashableTo Hash.Hash (TimeParameters cpv) where
    getHash = Hash.hash . runPut . putTimeParameters

instance Monad m => MHashableTo m Hash.Hash (TimeParameters cpv)

getTimeParameters :: forall cpv. IsChainParametersVersion cpv => Get (TimeParameters cpv)
getTimeParameters = case chainParametersVersion @cpv of
    SCPV0 -> return TimeParametersV0
    SCPV1 -> TimeParametersV1 <$> get <*> get

instance IsChainParametersVersion cpv => Serialize (TimeParameters cpv) where
  put = putTimeParameters
  get = getTimeParameters

instance ToJSON (TimeParameters 'ChainParametersV1) where
  toJSON TimeParametersV1{..} =
        object [
            "rewardPeriodLength" AE..= _tpRewardPeriodLength,
            "mintPerPayday" AE..= _tpMintPerPayday
        ]

instance FromJSON (TimeParameters 'ChainParametersV1) where
  parseJSON = withObject "TimeParametersV1" $ \v ->
    TimeParametersV1 <$> v .: "rewardPeriodLength" <*> v .: "mintPerPayday"

deriving instance Eq (TimeParameters cpv)
deriving instance Show (TimeParameters cpv)

-- |A range that includes both endpoints.
data InclusiveRange a = InclusiveRange {irMin :: !a, irMax :: !a}
    deriving (Eq, Show)

instance ToJSON a => ToJSON (InclusiveRange a) where
    toJSON InclusiveRange{..} =
        object [
            "min" AE..= irMin,
            "max" AE..= irMax
        ]

instance (FromJSON a, Ord a) => FromJSON (InclusiveRange a) where
    parseJSON = withObject "InclusiveRange" $ \v ->  do
      irMin <- v .: "min"
      irMax <- v .: "max"
      when (irMin > irMax) $ fail "Invalid interval. Left endpoint cannot be bigger than right endpoint."
      return InclusiveRange{..}

instance (Serialize a, Ord a) => Serialize (InclusiveRange a) where
    put InclusiveRange{..} = do
        put irMin
        put irMax
    get = do
        irMin <- get
        irMax <- get
        when (irMin > irMax) $ fail "Invalid interval. Left endpoint cannot be bigger than right endpoint."
        return InclusiveRange{..}

-- |Determine if a value is in a given 'InclusiveRange'.
isInRange :: Ord a => a -> InclusiveRange a -> Bool
isInRange v InclusiveRange{..} = irMin <= v && v <= irMax

closestInRange :: Ord a => a -> InclusiveRange a -> a
closestInRange v r
  | isInRange v r = v
  | v < irMin r = irMin r
  | otherwise = irMax r

-- |Ranges of allowed commission values that pools may choose from.
data CommissionRanges = CommissionRanges
    { -- |The range of allowed finalization commissions.
      _finalizationCommissionRange :: !(InclusiveRange AmountFraction),
      -- |The range of allowed baker commissions.
      _bakingCommissionRange :: !(InclusiveRange AmountFraction),
      -- |The range of allowed transaction commissions.
      _transactionCommissionRange :: !(InclusiveRange AmountFraction)
    }
    deriving (Eq, Show)
makeLenses ''CommissionRanges

instance Serialize CommissionRanges where
    put CommissionRanges{..} = do
        put _finalizationCommissionRange
        put _bakingCommissionRange
        put _transactionCommissionRange
    get = CommissionRanges <$> get <*> get <*> get

-- |Compute the maximum commission rates from commission ranges.
maximumCommissionRates :: CommissionRanges -> CommissionRates
maximumCommissionRates CommissionRanges{..} = CommissionRates {
        _finalizationCommission=irMax _finalizationCommissionRange,
        _bakingCommission=irMax _bakingCommissionRange,
        _transactionCommission=irMax _transactionCommissionRange
    }

type LeverageFactor = Ratio Word64

-- |Apply a leverage factor to a capital amount.
applyLeverageFactor :: LeverageFactor -> Amount -> Amount
applyLeverageFactor leverage (Amount amt) = Amount (truncate (leverage * (amt % 1)))

data PoolParameters cpv where
    PoolParametersV0 :: { -- |Minimum threshold required for registering as a baker.
      _ppBakerStakeThreshold :: Amount
    } -> PoolParameters 'ChainParametersV0
    PoolParametersV1 :: { -- |Commission rates charged by the L-pool.
      _ppLPoolCommissions :: !CommissionRates,
      -- |Bounds on the commission rates that may be charged by bakers.
      _ppCommissionBounds :: !CommissionRanges,
      -- |Minimum equity capital required for a new baker.
      _ppMinimumEquityCapital :: !Amount,
      -- |Maximum fraction of the total staked capital of that a new baker can have.
      _ppCapitalBound :: !AmountFraction,
      -- |The maximum leverage that a baker can have as a ratio of total stake
      -- to equity capital.
      _ppLeverageBound :: !LeverageFactor
    } -> PoolParameters 'ChainParametersV1

instance ToJSON (PoolParameters cpv) where
  toJSON PoolParametersV0{..} =
        object [
            "minimumThresholdForBaking" AE..= _ppBakerStakeThreshold
        ]
  toJSON PoolParametersV1{..} =
        object [
            "finalizationCommissionLPool" AE..= _finalizationCommission _ppLPoolCommissions,
            "bakingCommissionLPool" AE..= _bakingCommission _ppLPoolCommissions,
            "transactionCommissionLPool" AE..= _transactionCommission _ppLPoolCommissions,
            "finalizationCommissionRange" AE..= _finalizationCommissionRange _ppCommissionBounds,
            "bakingCommissionRange" AE..= _bakingCommissionRange _ppCommissionBounds,
            "transactionCommissionRange" AE..= _transactionCommissionRange _ppCommissionBounds,
            "minimumEquityCapital" AE..= _ppMinimumEquityCapital,
            "capitalBound" AE..= _ppCapitalBound,
            "leverageBound" AE..= _ppLeverageBound
        ]

parsePoolParametersJSON :: forall cpv. IsChainParametersVersion cpv => Value -> Parser (PoolParameters cpv)
parsePoolParametersJSON = case chainParametersVersion @cpv of
  SCPV0 -> withObject "PoolParametersV0" $ \v -> PoolParametersV0 <$> v .: "minimumThresholdForBaking"
  SCPV1 -> withObject "PoolParametersV1" $ \v -> do
    _finalizationCommission <- v .: "finalizationCommissionLPool"
    _bakingCommission <- v .: "bakingCommissionLPool"
    _transactionCommission <- v .: "transactionCommissionLPool"
    _finalizationCommissionRange <- v .: "finalizationCommissionRange"
    _bakingCommissionRange <- v .: "bakingCommissionRange"
    _transactionCommissionRange <- v .: "transactionCommissionRange"
    _ppMinimumEquityCapital <- v .: "minimumEquityCapital"
    _ppCapitalBound <- v .: "capitalBound"
    _ppLeverageBound <- v .: "leverageBound"
    let _ppLPoolCommissions = CommissionRates{..}
    let _ppCommissionBounds = CommissionRanges{..}
    return PoolParametersV1{..}

instance IsChainParametersVersion cpv => FromJSON (PoolParameters cpv) where
  parseJSON = parsePoolParametersJSON

-- |Lens for '_ppBakerStakeThreshold'
{-# INLINE ppBakerStakeThreshold #-}
ppBakerStakeThreshold :: Lens' (PoolParameters 'ChainParametersV0) Amount
ppBakerStakeThreshold =
  lens _ppBakerStakeThreshold (\pp x -> pp{_ppBakerStakeThreshold = x})

-- |Lens for '_ppLPoolCommissions'
{-# INLINE ppLPoolCommissions #-}
ppLPoolCommissions :: Lens' (PoolParameters 'ChainParametersV1) CommissionRates
ppLPoolCommissions =
  lens _ppLPoolCommissions (\pp x -> pp{_ppLPoolCommissions = x})

-- |Lens for '_ppCommissionBounds'
{-# INLINE ppCommissionBounds #-}
ppCommissionBounds :: Lens' (PoolParameters 'ChainParametersV1) CommissionRanges
ppCommissionBounds =
  lens _ppCommissionBounds (\pp x -> pp{_ppCommissionBounds = x})

-- |Lens for '_ppMinimumEquityCapital'
{-# INLINE ppMinimumEquityCapital #-}
ppMinimumEquityCapital :: Lens' (PoolParameters 'ChainParametersV1) Amount
ppMinimumEquityCapital =
  lens _ppMinimumEquityCapital (\pp x -> pp{_ppMinimumEquityCapital = x})

-- |Lens for '_ppCapitalBound'
{-# INLINE ppCapitalBound #-}
ppCapitalBound :: Lens' (PoolParameters 'ChainParametersV1) AmountFraction
ppCapitalBound =
  lens _ppCapitalBound (\pp x -> pp{_ppCapitalBound = x})

-- |Lens for '_ppLeverageBound'
{-# INLINE ppLeverageBound #-}
ppLeverageBound :: Lens' (PoolParameters 'ChainParametersV1) LeverageFactor
ppLeverageBound =
  lens _ppLeverageBound (\pp x -> pp{_ppLeverageBound = x})

putPoolParameters :: Putter (PoolParameters cpv)
putPoolParameters PoolParametersV0{..} = do
    put _ppBakerStakeThreshold
putPoolParameters PoolParametersV1{..} = do
        put _ppLPoolCommissions
        put _ppCommissionBounds
        put _ppMinimumEquityCapital
        put _ppCapitalBound
        put _ppLeverageBound

instance HashableTo Hash.Hash (PoolParameters cpv) where
    getHash = Hash.hash . runPut . putPoolParameters

instance Monad m => MHashableTo m Hash.Hash (PoolParameters cpv)

getPoolParameters :: forall cpv. IsChainParametersVersion cpv => Get (PoolParameters cpv)
getPoolParameters = case chainParametersVersion @cpv of
    SCPV0 -> PoolParametersV0 <$> get
    SCPV1 -> PoolParametersV1 <$> get <*> get <*> get <*> get <*> get

instance IsChainParametersVersion cpv => Serialize (PoolParameters cpv) where
  put = putPoolParameters
  get = getPoolParameters

deriving instance Eq (PoolParameters cpv)
deriving instance Show (PoolParameters cpv)

-- |Updatable chain parameters.
data ChainParameters' (cpv :: ChainParametersVersion) = ChainParameters
    { -- |Election difficulty parameter.
      _cpElectionDifficulty :: !ElectionDifficulty,
      -- |Exchange rates.
      _cpExchangeRates :: !ExchangeRates,
      -- |Cooldown parameters.
      _cpCooldownParameters :: !(CooldownParameters cpv),
      -- |Time parameters.
      _cpTimeParameters :: !(TimeParameters cpv),
      -- |LimitAccountCreation: the maximum number of accounts
      -- that may be created in one block.
      _cpAccountCreationLimit :: !CredentialsPerBlockLimit,
      -- |Reward parameters.
      _cpRewardParameters :: !(RewardParameters cpv),
      -- |Foundation account index.
      _cpFoundationAccount :: !AccountIndex,
      -- |Parameters for baker pools. Prior to P4, this is just the minimum stake threshold
      -- for becoming a baker.
      _cpPoolParameters :: !(PoolParameters cpv)
    }
    deriving (Eq, Show)

makeLenses ''ChainParameters'

type ChainParameters pv = ChainParameters' (ChainParametersVersionFor pv)

-- |Constructor for chain parameters.
makeChainParametersV0 ::
    -- |Election difficulty
    ElectionDifficulty ->
    -- |Euro:Energy rate
    ExchangeRate ->
    -- |uGTU:Euro rate
    ExchangeRate ->
    -- |Baker cooldown
    Epoch ->
    -- |Account creation limit
    CredentialsPerBlockLimit ->
    -- |Reward parameters
    RewardParameters 'ChainParametersV0 ->
    -- |Foundation account
    AccountIndex ->
    -- |Minimum threshold required for registering as a baker
    Amount ->
    ChainParameters' 'ChainParametersV0
makeChainParametersV0
    _cpElectionDifficulty
    _cpEuroPerEnergy
    _cpMicroGTUPerEuro
    _cpBakerExtraCooldownEpochs
    _cpAccountCreationLimit
    _cpRewardParameters
    _cpFoundationAccount
    _ppBakerStakeThreshold = ChainParameters{..}
      where
        _cpCooldownParameters = CooldownParametersV0{..}
        _cpTimeParameters = TimeParametersV0
        _cpPoolParameters = PoolParametersV0{..}
        _cpExchangeRates = makeExchangeRates _cpEuroPerEnergy _cpMicroGTUPerEuro

makeChainParametersV1 ::
    -- |Election difficulty
    ElectionDifficulty ->
    -- |Euro:Energy rate
    ExchangeRate ->
    -- |uGTU:Euro rate
    ExchangeRate ->
    -- |Number of seconds that pool owners must cooldown
    -- when reducing their equity capital or closing the pool.
    DurationSeconds ->
    -- |Number of seconds that a delegator must cooldown
    -- when reducing their delegated stake.
    DurationSeconds ->
    -- |Account creation limit
    CredentialsPerBlockLimit ->
    -- |Reward parameters
    RewardParameters 'ChainParametersV1 ->
    -- |Foundation account
    AccountIndex ->
    -- |Fraction of finalization rewards charged by the L-Pool.
    AmountFraction ->
    -- |Fraction of baking rewards charged by the L-pool.
    AmountFraction ->
    -- |Fraction of transaction rewards charged by the L-pool.
    AmountFraction ->
    -- |The range of allowed finalization commissions for normal pools.
    InclusiveRange AmountFraction ->
    -- |The range of allowed baker commissions for normal pools.
    InclusiveRange AmountFraction ->
    -- |The range of allowed transaction commissions for normal pools.
    InclusiveRange AmountFraction ->
    -- |Minimum equity capital required for a new baker.
    Amount ->
    -- |Maximum fraction of the total supply of that a new baker can have.
    AmountFraction ->
    -- |The maximum leverage that a baker can have as a ratio of total stake
    -- to equity capital.
    LeverageFactor ->
    -- |Length of a payday in epochs.
    RewardPeriodLength ->
    -- |Mint rate calculated per payday.
    MintRate ->
    ChainParameters' 'ChainParametersV1
makeChainParametersV1
    _cpElectionDifficulty
    _cpEuroPerEnergy
    _cpMicroGTUPerEuro
    _cpPoolOwnerCooldown
    _cpDelegatorCooldown
    _cpAccountCreationLimit
    _cpRewardParameters
    _cpFoundationAccount
    _finalizationCommission
    _bakingCommission
    _transactionCommission
    _finalizationCommissionRange
    _bakingCommissionRange
    _transactionCommissionRange
    _ppMinimumEquityCapital
    _ppCapitalBound
    _ppLeverageBound
    _tpRewardPeriodLength
    _tpMintPerPayday = ChainParameters{..}
      where
        _cpCooldownParameters = CooldownParametersV1{..}
        _cpTimeParameters = TimeParametersV1{..}
        _cpPoolParameters = PoolParametersV1{..}
        _cpExchangeRates = makeExchangeRates _cpEuroPerEnergy _cpMicroGTUPerEuro
        _ppLPoolCommissions = CommissionRates{..}
        _ppCommissionBounds = CommissionRanges{..}

instance HasExchangeRates (ChainParameters' cpv) where
    exchangeRates = cpExchangeRates

instance HasRewardParameters (ChainParameters' cpv) cpv where
    rewardParameters = cpRewardParameters

putChainParameters :: IsChainParametersVersion cpv => Putter (ChainParameters' cpv)
putChainParameters ChainParameters{..} = do
    put _cpElectionDifficulty
    put _cpExchangeRates
    putCooldownParameters _cpCooldownParameters
    putTimeParameters _cpTimeParameters
    put _cpAccountCreationLimit
    put _cpRewardParameters
    put _cpFoundationAccount
    putPoolParameters _cpPoolParameters

getChainParameters :: forall cpv. IsChainParametersVersion cpv => Get (ChainParameters' cpv)
getChainParameters = ChainParameters <$> get <*> get <*> getCooldownParameters <*> getTimeParameters <*> get <*> get <*> get <*> getPoolParameters

instance IsChainParametersVersion cpv => Serialize (ChainParameters' cpv) where
  put = putChainParameters
  get = getChainParameters

instance IsChainParametersVersion cpv => HashableTo Hash.Hash (ChainParameters' cpv) where
    getHash = Hash.hash . runPut . putChainParameters

instance (Monad m, IsChainParametersVersion cpv) => MHashableTo m Hash.Hash (ChainParameters' cpv)

parseJSONForCPV0 :: Value -> Parser (ChainParameters' 'ChainParametersV0)
parseJSONForCPV0 =
    withObject "ChainParameters" $ \v ->
        makeChainParametersV0
            <$> v .: "electionDifficulty"
            <*> v .: "euroPerEnergy"
            <*> v .: "microGTUPerEuro"
            <*> v .: "bakerCooldownEpochs"
            <*> v .: "accountCreationLimit"
            <*> v .: "rewardParameters"
            <*> v .: "foundationAccountIndex"
            <*> v .: "minimumThresholdForBaking"

parseJSONForCPV1 :: Value -> Parser (ChainParameters' 'ChainParametersV1)
parseJSONForCPV1 =
    withObject "ChainParametersV1" $ \v ->
        makeChainParametersV1
            <$> v .: "electionDifficulty"
            <*> v .: "euroPerEnergy"
            <*> v .: "microGTUPerEuro"
            <*> v .: "poolOwnerCooldown"
            <*> v .: "delegatorCooldown"
            <*> v .: "accountCreationLimit"
            <*> v .: "rewardParameters"
            <*> v .: "foundationAccountIndex"
            <*> v .: "finalizationCommissionLPool"
            <*> v .: "bakingCommissionLPool"
            <*> v .: "transactionCommissionLPool"
            <*> v .: "finalizationCommissionRange"
            <*> v .: "bakingCommissionRange"
            <*> v .: "transactionCommissionRange"
            <*> v .: "minimumEquityCapital"
            <*> v .: "capitalBound"
            <*> v .: "leverageBound"
            <*> v .: "rewardPeriodLength"
            <*> v .: "mintPerPayday"

instance forall cpv. IsChainParametersVersion cpv => FromJSON (ChainParameters' cpv) where
    parseJSON = case chainParametersVersion @cpv of
      SCPV0 -> parseJSONForCPV0
      SCPV1 -> parseJSONForCPV1

instance forall cpv. IsChainParametersVersion cpv => ToJSON (ChainParameters' cpv) where
    toJSON ChainParameters{..} = case chainParametersVersion @cpv of
      SCPV0 ->
        object
            [ "electionDifficulty" AE..= _cpElectionDifficulty,
              "euroPerEnergy" AE..= _erEuroPerEnergy _cpExchangeRates,
              "microGTUPerEuro" AE..= _erMicroGTUPerEuro _cpExchangeRates,
              "bakerCooldownEpochs" AE..= _cpBakerExtraCooldownEpochs _cpCooldownParameters,
              "accountCreationLimit" AE..= _cpAccountCreationLimit,
              "rewardParameters" AE..= _cpRewardParameters,
              "foundationAccountIndex" AE..= _cpFoundationAccount,
              "minimumThresholdForBaking" AE..= _ppBakerStakeThreshold _cpPoolParameters
            ]
      SCPV1 ->
        object
            [ "electionDifficulty" AE..= _cpElectionDifficulty,
              "euroPerEnergy" AE..= _erEuroPerEnergy _cpExchangeRates,
              "microGTUPerEuro" AE..= _erMicroGTUPerEuro _cpExchangeRates,
              "poolOwnerCooldown" AE..= _cpPoolOwnerCooldown _cpCooldownParameters,
              "delegatorCooldown" AE..= _cpDelegatorCooldown _cpCooldownParameters,
              "accountCreationLimit" AE..= _cpAccountCreationLimit,
              "rewardParameters" AE..= _cpRewardParameters,
              "foundationAccountIndex" AE..= _cpFoundationAccount,
              "finalizationCommissionLPool" AE..= _finalizationCommission (_ppLPoolCommissions _cpPoolParameters),
              "bakingCommissionLPool" AE..= _bakingCommission (_ppLPoolCommissions _cpPoolParameters),
              "transactionCommissionLPool" AE..= _transactionCommission (_ppLPoolCommissions _cpPoolParameters),
              "finalizationCommissionRange" AE..= _finalizationCommissionRange (_ppCommissionBounds _cpPoolParameters),
              "bakingCommissionRange" AE..= _bakingCommissionRange (_ppCommissionBounds _cpPoolParameters),
              "transactionCommissionRange" AE..= _transactionCommissionRange (_ppCommissionBounds _cpPoolParameters),
              "minimumEquityCapital" AE..= _ppMinimumEquityCapital _cpPoolParameters,
              "capitalBound" AE..= _ppCapitalBound _cpPoolParameters,
              "leverageBound" AE..= _ppLeverageBound _cpPoolParameters,
              "rewardPeriodLength" AE..= _tpRewardPeriodLength _cpTimeParameters,
              "mintPerPayday" AE..= _tpMintPerPayday _cpTimeParameters
            ]

-- |Parameters that affect finalization.
data FinalizationParameters = FinalizationParameters
    { -- |Number of levels to skip between finalizations.
      finalizationMinimumSkip :: BlockHeight,
      -- |Maximum size of the finalization committee; determines the minimum stake
      -- required to join the committee as @totalGTU / finalizationCommitteeMaxSize@.
      finalizationCommitteeMaxSize :: FinalizationCommitteeSize,
      -- |Base delay time used in finalization.
      finalizationWaitingTime :: Duration,
      -- |Factor used to shrink the finalization gap. Must be strictly between 0 and 1.
      finalizationSkipShrinkFactor :: Ratio Word64,
      -- |Factor used to grow the finalization gap. Must be strictly greater than 1.
      finalizationSkipGrowFactor :: Ratio Word64,
      -- |Factor for shrinking the finalization delay (i.e. number of descendent blocks
      -- required to be eligible as a finalization target).
      finalizationDelayShrinkFactor :: Ratio Word64,
      -- |Factor for growing the finalization delay when it takes more than one round
      -- to finalize a block.
      finalizationDelayGrowFactor :: Ratio Word64,
      -- |Whether to allow the delay to be 0. (This allows a block to be finalized as soon
      -- as it is baked.)
      finalizationAllowZeroDelay :: Bool
    }
    deriving (Eq, Show)

-- |Serialize 'FinalizationParameters' in the V3 GenesisData
-- format.
putFinalizationParametersGD3 :: Putter FinalizationParameters
putFinalizationParametersGD3 FinalizationParameters{..} = do
    put finalizationMinimumSkip
    put finalizationCommitteeMaxSize
    put finalizationWaitingTime
    put finalizationSkipShrinkFactor
    put finalizationSkipGrowFactor
    put finalizationDelayShrinkFactor
    put finalizationDelayGrowFactor
    put finalizationAllowZeroDelay

-- |Deserialize 'FinalizationParameters' in the V3 GenesisData
-- format
getFinalizationParametersGD3 :: Get FinalizationParameters
getFinalizationParametersGD3 = label "FinalizationParameters" $ do
    finalizationMinimumSkip <- get
    finalizationCommitteeMaxSize <- get
    finalizationWaitingTime <- get
    finalizationSkipShrinkFactor <- get
    unless (finalizationSkipShrinkFactor > 0 && finalizationSkipShrinkFactor < 1) $
        fail "skipShrinkFactor must be strictly between 0 and 1"
    finalizationSkipGrowFactor <- get
    unless (finalizationSkipGrowFactor > 1) $
        fail "skipGrowFactor must be strictly greater than 1"
    finalizationDelayShrinkFactor <- get
    unless (finalizationDelayShrinkFactor > 0 && finalizationDelayShrinkFactor < 1) $
        fail "delayShrinkFactor must be strictly between 0 and 1"
    finalizationDelayGrowFactor <- get
    unless (finalizationDelayGrowFactor > 1) $
        fail "delayGrowFactor must be strictly greater than 1"
    finalizationAllowZeroDelay <- get
    return FinalizationParameters{..}

instance FromJSON FinalizationParameters where
    parseJSON = withObject "FinalizationParameters" $ \v -> do
        finalizationMinimumSkip <- BlockHeight <$> v .: "minimumSkip"
        finalizationCommitteeMaxSize <- v .: "committeeMaxSize"
        finalizationWaitingTime <- v .: "waitingTime"
        finalizationIgnoreFirstWait <- v .:? "ignoreFirstWait" .!= True
        unless finalizationIgnoreFirstWait $
            fail "ignoreFirstWait must be true (or not specified)"
        finalizationOldStyleSkip <- v .:? "oldStyleSkip" .!= False
        when finalizationOldStyleSkip $
            fail "oldStyleSkip must be false (or not specified)"
        finalizationSkipShrinkFactor <- v .: "skipShrinkFactor"
        unless (finalizationSkipShrinkFactor > 0 && finalizationSkipShrinkFactor < 1) $
            fail "skipShrinkFactor must be strictly between 0 and 1"
        finalizationSkipGrowFactor <- v .: "skipGrowFactor"
        unless (finalizationSkipGrowFactor > 1) $
            fail "skipGrowFactor must be strictly greater than 1"
        finalizationDelayShrinkFactor <- v .: "delayShrinkFactor"
        unless (finalizationDelayShrinkFactor > 0 && finalizationDelayShrinkFactor < 1) $
            fail "delayShrinkFactor must be strictly between 0 and 1"
        finalizationDelayGrowFactor <- v .: "delayGrowFactor"
        unless (finalizationDelayGrowFactor > 1) $
            fail "delayGrowFactor must be strictly greater than 1"
        finalizationAllowZeroDelay <- v .:? "allowZeroDelay" .!= False
        return FinalizationParameters{..}

