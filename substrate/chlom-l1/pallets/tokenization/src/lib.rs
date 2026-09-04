#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{ExternalIssuanceState, Id32, TokenClassKind, ZERO_ID};
    use codec::{Decode, DecodeWithMemTracking, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub enum TokenEventType {
        CandidateRegistered,
        TestnetMintConfirmed,
        ProductionMintConfirmed,
        TransferConfirmed,
        Suspended,
        Revoked,
        BurnConfirmed,
        ProviderFailure,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct TokenClass {
        pub kind: TokenClassKind,
        pub transferable: bool,
        pub rights_semantics_hash: Id32,
        pub legal_approved_public: bool,
        pub issuance_state: ExternalIssuanceState,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct ChainAdapter {
        pub network_id: Id32,
        pub implementation_hash: Id32,
        pub testnet_allowed: bool,
        pub production_certified: bool,
        pub provider_readback_required: bool,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct TokenizedObject {
        pub token_class_id: Id32,
        pub source_object_type: Id32,
        pub source_object_id: Id32,
        pub source_version_hash: Id32,
        pub canonical_asset_id: Option<Id32>,
        pub dla_id: Option<Id32>,
        pub entitlement_id: Option<Id32>,
        pub initial_holder_subject_id: Id32,
        pub metadata_hash: Id32,
        pub rights_semantics_hash: Id32,
        pub external_chain_transaction: bool,
        pub raw_private_evidence_embedded: bool,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct TokenEventRecord {
        pub tokenized_object_id: Id32,
        pub event_type: TokenEventType,
        pub from_subject_id: Option<Id32>,
        pub to_subject_id: Option<Id32>,
        pub chain_adapter_id: Option<Id32>,
        pub contract_ref_hash: Option<Id32>,
        pub token_id_hash: Option<Id32>,
        pub provider_receipt_hash: Option<Id32>,
        pub rights_effect_hash: Id32,
        pub provider_readback_verified: bool,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type TokenOrigin: EnsureOrigin<Self::RuntimeOrigin>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type TokenClasses<T: Config> = StorageMap<_, Blake2_128Concat, Id32, TokenClass, OptionQuery>;
    #[pallet::storage]
    pub type ChainAdapters<T: Config> = StorageMap<_, Blake2_128Concat, Id32, ChainAdapter, OptionQuery>;
    #[pallet::storage]
    pub type TokenizedObjects<T: Config> = StorageMap<_, Blake2_128Concat, Id32, TokenizedObject, OptionQuery>;
    #[pallet::storage]
    pub type TokenEvents<T: Config> = StorageMap<_, Blake2_128Concat, Id32, TokenEventRecord, OptionQuery>;
    #[pallet::storage]
    pub type LatestTokenEvent<T: Config> = StorageMap<_, Blake2_128Concat, Id32, Id32, OptionQuery>;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        TokenClassRecorded { token_class_id: Id32, kind: TokenClassKind, issuance_state: ExternalIssuanceState, record_hash: Id32 },
        ChainAdapterRecorded { chain_adapter_id: Id32, network_id: Id32, testnet_allowed: bool, production_certified: bool, record_hash: Id32 },
        TokenizedObjectRegistered { tokenized_object_id: Id32, token_class_id: Id32, initial_holder_subject_id: Id32, record_hash: Id32 },
        TokenEventRecorded { token_event_id: Id32, tokenized_object_id: Id32, event_type: TokenEventType, provider_readback_verified: bool, record_hash: Id32 },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        RecordAlreadyExists,
        TokenClassMissing,
        TokenizedObjectMissing,
        ChainAdapterMissing,
        TestnetAdapterNotCertified,
        ProductionMintNotCertified,
        TransferForbidden,
        ProviderReceiptRequired,
        PriorProviderMintRequired,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(35_000_000, 0))]
        pub fn record_token_class(
            origin: OriginFor<T>,
            token_class_id: Id32,
            kind: TokenClassKind,
            transferable: bool,
            rights_semantics_hash: Id32,
            legal_approved_public: bool,
            issuance_state: ExternalIssuanceState,
            record_hash: Id32,
        ) -> DispatchResult {
            T::TokenOrigin::ensure_origin(origin)?;
            ensure!(token_class_id != ZERO_ID && rights_semantics_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!TokenClasses::<T>::contains_key(token_class_id), Error::<T>::RecordAlreadyExists);
            if matches!(kind, TokenClassKind::NonTransferableCredential | TokenClassKind::Entitlement | TokenClassKind::ProvenanceCertificate) {
                ensure!(!transferable, Error::<T>::TransferForbidden);
            }
            TokenClasses::<T>::insert(token_class_id, TokenClass {
                kind,
                transferable,
                rights_semantics_hash,
                legal_approved_public,
                issuance_state,
                record_hash,
            });
            Self::deposit_event(Event::TokenClassRecorded { token_class_id, kind, issuance_state, record_hash });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(35_000_000, 0))]
        pub fn record_chain_adapter(
            origin: OriginFor<T>,
            chain_adapter_id: Id32,
            network_id: Id32,
            implementation_hash: Id32,
            testnet_allowed: bool,
            production_certified: bool,
            provider_readback_required: bool,
            record_hash: Id32,
        ) -> DispatchResult {
            T::TokenOrigin::ensure_origin(origin)?;
            ensure!(chain_adapter_id != ZERO_ID && network_id != ZERO_ID && implementation_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!ChainAdapters::<T>::contains_key(chain_adapter_id), Error::<T>::RecordAlreadyExists);
            ChainAdapters::<T>::insert(chain_adapter_id, ChainAdapter {
                network_id,
                implementation_hash,
                testnet_allowed,
                production_certified,
                provider_readback_required,
                record_hash,
            });
            Self::deposit_event(Event::ChainAdapterRecorded { chain_adapter_id, network_id, testnet_allowed, production_certified, record_hash });
            Ok(())
        }

        #[pallet::call_index(2)]
        #[pallet::weight(Weight::from_parts(45_000_000, 0))]
        pub fn register_tokenized_object(
            origin: OriginFor<T>,
            tokenized_object_id: Id32,
            token_class_id: Id32,
            source_object_type: Id32,
            source_object_id: Id32,
            source_version_hash: Id32,
            canonical_asset_id: Option<Id32>,
            dla_id: Option<Id32>,
            entitlement_id: Option<Id32>,
            initial_holder_subject_id: Id32,
            metadata_hash: Id32,
            record_hash: Id32,
        ) -> DispatchResult {
            T::TokenOrigin::ensure_origin(origin)?;
            ensure!(tokenized_object_id != ZERO_ID && token_class_id != ZERO_ID && source_object_type != ZERO_ID && source_object_id != ZERO_ID && source_version_hash != ZERO_ID && initial_holder_subject_id != ZERO_ID && metadata_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!TokenizedObjects::<T>::contains_key(tokenized_object_id), Error::<T>::RecordAlreadyExists);
            let class = TokenClasses::<T>::get(token_class_id).ok_or(Error::<T>::TokenClassMissing)?;
            TokenizedObjects::<T>::insert(tokenized_object_id, TokenizedObject {
                token_class_id,
                source_object_type,
                source_object_id,
                source_version_hash,
                canonical_asset_id,
                dla_id,
                entitlement_id,
                initial_holder_subject_id,
                metadata_hash,
                rights_semantics_hash: class.rights_semantics_hash,
                external_chain_transaction: false,
                raw_private_evidence_embedded: false,
                record_hash,
            });
            Self::deposit_event(Event::TokenizedObjectRegistered { tokenized_object_id, token_class_id, initial_holder_subject_id, record_hash });
            Ok(())
        }

        #[pallet::call_index(3)]
        #[pallet::weight(Weight::from_parts(55_000_000, 0))]
        pub fn record_provider_event(
            origin: OriginFor<T>,
            token_event_id: Id32,
            tokenized_object_id: Id32,
            event_type: TokenEventType,
            from_subject_id: Option<Id32>,
            to_subject_id: Option<Id32>,
            chain_adapter_id: Option<Id32>,
            contract_ref_hash: Option<Id32>,
            token_id_hash: Option<Id32>,
            provider_receipt_hash: Option<Id32>,
            rights_effect_hash: Id32,
            record_hash: Id32,
        ) -> DispatchResult {
            T::TokenOrigin::ensure_origin(origin)?;
            ensure!(token_event_id != ZERO_ID && tokenized_object_id != ZERO_ID && rights_effect_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!TokenEvents::<T>::contains_key(token_event_id), Error::<T>::RecordAlreadyExists);
            let object = TokenizedObjects::<T>::get(tokenized_object_id).ok_or(Error::<T>::TokenizedObjectMissing)?;
            let class = TokenClasses::<T>::get(object.token_class_id).ok_or(Error::<T>::TokenClassMissing)?;
            let mut provider_verified = false;
            match event_type {
                TokenEventType::CandidateRegistered | TokenEventType::Suspended | TokenEventType::Revoked => {},
                TokenEventType::ProviderFailure => {
                    ensure!(provider_receipt_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ProviderReceiptRequired);
                },
                TokenEventType::TestnetMintConfirmed => {
                    let adapter_id = chain_adapter_id.ok_or(Error::<T>::ChainAdapterMissing)?;
                    let adapter = ChainAdapters::<T>::get(adapter_id).ok_or(Error::<T>::ChainAdapterMissing)?;
                    ensure!(adapter.testnet_allowed, Error::<T>::TestnetAdapterNotCertified);
                    ensure!(provider_receipt_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ProviderReceiptRequired);
                    provider_verified = true;
                },
                TokenEventType::ProductionMintConfirmed => {
                    let adapter_id = chain_adapter_id.ok_or(Error::<T>::ChainAdapterMissing)?;
                    let adapter = ChainAdapters::<T>::get(adapter_id).ok_or(Error::<T>::ChainAdapterMissing)?;
                    ensure!(adapter.production_certified && class.legal_approved_public && class.issuance_state == ExternalIssuanceState::ProductionEligible, Error::<T>::ProductionMintNotCertified);
                    ensure!(provider_receipt_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ProviderReceiptRequired);
                    provider_verified = true;
                },
                TokenEventType::TransferConfirmed => {
                    ensure!(class.transferable, Error::<T>::TransferForbidden);
                    let prior_id = LatestTokenEvent::<T>::get(tokenized_object_id).ok_or(Error::<T>::PriorProviderMintRequired)?;
                    let prior = TokenEvents::<T>::get(prior_id).ok_or(Error::<T>::PriorProviderMintRequired)?;
                    ensure!(matches!(prior.event_type, TokenEventType::TestnetMintConfirmed | TokenEventType::ProductionMintConfirmed | TokenEventType::TransferConfirmed), Error::<T>::PriorProviderMintRequired);
                    ensure!(provider_receipt_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ProviderReceiptRequired);
                    provider_verified = true;
                },
                TokenEventType::BurnConfirmed => {
                    ensure!(provider_receipt_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ProviderReceiptRequired);
                    provider_verified = true;
                },
            }
            TokenEvents::<T>::insert(token_event_id, TokenEventRecord {
                tokenized_object_id,
                event_type,
                from_subject_id,
                to_subject_id,
                chain_adapter_id,
                contract_ref_hash,
                token_id_hash,
                provider_receipt_hash,
                rights_effect_hash,
                provider_readback_verified: provider_verified,
                record_hash,
            });
            LatestTokenEvent::<T>::insert(tokenized_object_id, token_event_id);
            Self::deposit_event(Event::TokenEventRecorded { token_event_id, tokenized_object_id, event_type, provider_readback_verified: provider_verified, record_hash });
            Ok(())
        }
    }
}
