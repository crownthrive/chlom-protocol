#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{Id32, ZERO_ID};
    use codec::{Decode, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct CheckpointRecord {
        pub start_sequence_id: u64,
        pub end_sequence_id: u64,
        pub event_count: u32,
        pub first_event_hash: Id32,
        pub last_event_hash: Id32,
        pub previous_checkpoint_root: Option<Id32>,
        pub merkle_root: Id32,
        pub signature_hash: Id32,
        pub signature_verified: bool,
        pub raw_private_evidence_included: bool,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct AnchorIntent {
        pub checkpoint_id: Id32,
        pub root: Id32,
        pub target_family: Id32,
        pub target_network: Id32,
        pub production_gated: bool,
        pub raw_private_evidence_included: bool,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct AnchorReceipt {
        pub intent_id: Id32,
        pub root: Id32,
        pub provider_id: Id32,
        pub network_id: Id32,
        pub transaction_ref_hash: Id32,
        pub block_ref_hash: Id32,
        pub provider_receipt_hash: Id32,
        pub provider_readback_verified: bool,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type CheckpointOrigin: EnsureOrigin<Self::RuntimeOrigin>;
        type AnchorOrigin: EnsureOrigin<Self::RuntimeOrigin>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type Checkpoints<T: Config> = StorageMap<_, Blake2_128Concat, Id32, CheckpointRecord, OptionQuery>;
    #[pallet::storage]
    pub type CheckpointHead<T: Config> = StorageValue<_, Id32, OptionQuery>;
    #[pallet::storage]
    pub type AnchorIntents<T: Config> = StorageMap<_, Blake2_128Concat, Id32, AnchorIntent, OptionQuery>;
    #[pallet::storage]
    pub type AnchorReceipts<T: Config> = StorageMap<_, Blake2_128Concat, Id32, AnchorReceipt, OptionQuery>;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        CheckpointRecorded { checkpoint_id: Id32, start_sequence_id: u64, end_sequence_id: u64, event_count: u32, merkle_root: Id32, signature_verified: bool },
        AnchorIntentRecorded { intent_id: Id32, checkpoint_id: Id32, root: Id32, production_gated: bool },
        AnchorReceiptRecorded { receipt_id: Id32, intent_id: Id32, root: Id32, provider_readback_verified: bool },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        InvalidRange,
        RecordAlreadyExists,
        PriorCheckpointMissing,
        PriorCheckpointMismatch,
        CheckpointMissing,
        IntentMissing,
        RootMismatch,
        PrivateEvidenceForbidden,
        SignatureRequired,
        ProviderReadbackRequired,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(45_000_000, 0))]
        pub fn record_checkpoint(
            origin: OriginFor<T>,
            checkpoint_id: Id32,
            start_sequence_id: u64,
            end_sequence_id: u64,
            event_count: u32,
            first_event_hash: Id32,
            last_event_hash: Id32,
            previous_checkpoint_root: Option<Id32>,
            merkle_root: Id32,
            signature_hash: Id32,
            signature_verified: bool,
            raw_private_evidence_included: bool,
            record_hash: Id32,
        ) -> DispatchResult {
            T::CheckpointOrigin::ensure_origin(origin)?;
            ensure!(checkpoint_id != ZERO_ID && first_event_hash != ZERO_ID && last_event_hash != ZERO_ID && merkle_root != ZERO_ID && signature_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(start_sequence_id > 0 && end_sequence_id >= start_sequence_id && event_count > 0, Error::<T>::InvalidRange);
            ensure!(!Checkpoints::<T>::contains_key(checkpoint_id), Error::<T>::RecordAlreadyExists);
            ensure!(signature_verified, Error::<T>::SignatureRequired);
            ensure!(!raw_private_evidence_included, Error::<T>::PrivateEvidenceForbidden);
            match CheckpointHead::<T>::get() {
                None => ensure!(previous_checkpoint_root.is_none(), Error::<T>::PriorCheckpointMismatch),
                Some(prior_id) => {
                    let prior = Checkpoints::<T>::get(prior_id).ok_or(Error::<T>::PriorCheckpointMissing)?;
                    ensure!(start_sequence_id > prior.end_sequence_id, Error::<T>::InvalidRange);
                    ensure!(previous_checkpoint_root == Some(prior.merkle_root), Error::<T>::PriorCheckpointMismatch);
                },
            }
            Checkpoints::<T>::insert(checkpoint_id, CheckpointRecord {
                start_sequence_id,
                end_sequence_id,
                event_count,
                first_event_hash,
                last_event_hash,
                previous_checkpoint_root,
                merkle_root,
                signature_hash,
                signature_verified,
                raw_private_evidence_included,
                record_hash,
            });
            CheckpointHead::<T>::put(checkpoint_id);
            Self::deposit_event(Event::CheckpointRecorded { checkpoint_id, start_sequence_id, end_sequence_id, event_count, merkle_root, signature_verified });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(35_000_000, 0))]
        pub fn record_anchor_intent(
            origin: OriginFor<T>,
            intent_id: Id32,
            checkpoint_id: Id32,
            target_family: Id32,
            target_network: Id32,
            production_gated: bool,
            raw_private_evidence_included: bool,
            record_hash: Id32,
        ) -> DispatchResult {
            T::AnchorOrigin::ensure_origin(origin)?;
            ensure!(intent_id != ZERO_ID && checkpoint_id != ZERO_ID && target_family != ZERO_ID && target_network != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!AnchorIntents::<T>::contains_key(intent_id), Error::<T>::RecordAlreadyExists);
            ensure!(!raw_private_evidence_included, Error::<T>::PrivateEvidenceForbidden);
            let checkpoint = Checkpoints::<T>::get(checkpoint_id).ok_or(Error::<T>::CheckpointMissing)?;
            AnchorIntents::<T>::insert(intent_id, AnchorIntent {
                checkpoint_id,
                root: checkpoint.merkle_root,
                target_family,
                target_network,
                production_gated,
                raw_private_evidence_included,
                record_hash,
            });
            Self::deposit_event(Event::AnchorIntentRecorded { intent_id, checkpoint_id, root: checkpoint.merkle_root, production_gated });
            Ok(())
        }

        #[pallet::call_index(2)]
        #[pallet::weight(Weight::from_parts(40_000_000, 0))]
        pub fn record_anchor_receipt(
            origin: OriginFor<T>,
            receipt_id: Id32,
            intent_id: Id32,
            provider_id: Id32,
            network_id: Id32,
            transaction_ref_hash: Id32,
            block_ref_hash: Id32,
            provider_receipt_hash: Id32,
            provider_readback_verified: bool,
            record_hash: Id32,
        ) -> DispatchResult {
            T::AnchorOrigin::ensure_origin(origin)?;
            ensure!(receipt_id != ZERO_ID && intent_id != ZERO_ID && provider_id != ZERO_ID && network_id != ZERO_ID && transaction_ref_hash != ZERO_ID && block_ref_hash != ZERO_ID && provider_receipt_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!AnchorReceipts::<T>::contains_key(receipt_id), Error::<T>::RecordAlreadyExists);
            ensure!(provider_readback_verified, Error::<T>::ProviderReadbackRequired);
            let intent = AnchorIntents::<T>::get(intent_id).ok_or(Error::<T>::IntentMissing)?;
            AnchorReceipts::<T>::insert(receipt_id, AnchorReceipt {
                intent_id,
                root: intent.root,
                provider_id,
                network_id,
                transaction_ref_hash,
                block_ref_hash,
                provider_receipt_hash,
                provider_readback_verified,
                record_hash,
            });
            Self::deposit_event(Event::AnchorReceiptRecorded { receipt_id, intent_id, root: intent.root, provider_readback_verified });
            Ok(())
        }
    }
}
