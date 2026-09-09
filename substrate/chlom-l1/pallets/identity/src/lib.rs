#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{Id32, RecordState, ZERO_ID};
    use codec::{Decode, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct IdentityVersion<BlockNumber> {
        pub version: u32,
        pub did_hash: Id32,
        pub fingerprint_hash: Id32,
        pub controller_subject_id: Id32,
        pub settlement_route_hash: Option<Id32>,
        pub state: RecordState,
        pub valid_from: BlockNumber,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct CredentialVersion<BlockNumber> {
        pub version: u32,
        pub subject_id: Id32,
        pub credential_type: Id32,
        pub issuer_subject_id: Id32,
        pub claim_hash: Id32,
        pub non_transferable: bool,
        pub state: RecordState,
        pub valid_until: Option<BlockNumber>,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type AdminOrigin: EnsureOrigin<Self::RuntimeOrigin>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type IdentityHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;

    #[pallet::storage]
    pub type IdentityVersions<T: Config> = StorageDoubleMap<
        _, Blake2_128Concat, Id32, Blake2_128Concat, u32,
        IdentityVersion<BlockNumberFor<T>>, OptionQuery
    >;

    #[pallet::storage]
    pub type CredentialHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;

    #[pallet::storage]
    pub type CredentialVersions<T: Config> = StorageDoubleMap<
        _, Blake2_128Concat, Id32, Blake2_128Concat, u32,
        CredentialVersion<BlockNumberFor<T>>, OptionQuery
    >;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        IdentityVersionRecorded { subject_id: Id32, version: u32, did_hash: Id32, fingerprint_hash: Id32, state: RecordState, record_hash: Id32 },
        CredentialVersionRecorded { credential_id: Id32, subject_id: Id32, version: u32, state: RecordState, non_transferable: bool, record_hash: Id32 },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        InvalidVersion,
        PreviousHashMismatch,
        VersionAlreadyExists,
        TransferableIdentityCredentialForbidden,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(35_000_000, 0))]
        pub fn record_identity_version(
            origin: OriginFor<T>,
            subject_id: Id32,
            version: u32,
            did_hash: Id32,
            fingerprint_hash: Id32,
            controller_subject_id: Id32,
            settlement_route_hash: Option<Id32>,
            state: RecordState,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::AdminOrigin::ensure_origin(origin)?;
            ensure!(subject_id != ZERO_ID && did_hash != ZERO_ID && fingerprint_hash != ZERO_ID && controller_subject_id != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!IdentityVersions::<T>::contains_key(subject_id, version), Error::<T>::VersionAlreadyExists);
            match IdentityHeads::<T>::get(subject_id) {
                None => ensure!(version == 1 && previous_record_hash.is_none(), Error::<T>::InvalidVersion),
                Some(head) => {
                    ensure!(version == head.saturating_add(1), Error::<T>::InvalidVersion);
                    let prior = IdentityVersions::<T>::get(subject_id, head).ok_or(Error::<T>::InvalidVersion)?;
                    ensure!(previous_record_hash == Some(prior.record_hash), Error::<T>::PreviousHashMismatch);
                },
            }
            let value = IdentityVersion {
                version,
                did_hash,
                fingerprint_hash,
                controller_subject_id,
                settlement_route_hash,
                state,
                valid_from: frame_system::Pallet::<T>::block_number(),
                previous_record_hash,
                record_hash,
            };
            IdentityVersions::<T>::insert(subject_id, version, value);
            IdentityHeads::<T>::insert(subject_id, version);
            Self::deposit_event(Event::IdentityVersionRecorded { subject_id, version, did_hash, fingerprint_hash, state, record_hash });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(35_000_000, 0))]
        pub fn record_credential_version(
            origin: OriginFor<T>,
            credential_id: Id32,
            version: u32,
            subject_id: Id32,
            credential_type: Id32,
            issuer_subject_id: Id32,
            claim_hash: Id32,
            non_transferable: bool,
            state: RecordState,
            valid_until: Option<BlockNumberFor<T>>,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::AdminOrigin::ensure_origin(origin)?;
            ensure!(credential_id != ZERO_ID && subject_id != ZERO_ID && credential_type != ZERO_ID && issuer_subject_id != ZERO_ID && claim_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(non_transferable, Error::<T>::TransferableIdentityCredentialForbidden);
            ensure!(!CredentialVersions::<T>::contains_key(credential_id, version), Error::<T>::VersionAlreadyExists);
            match CredentialHeads::<T>::get(credential_id) {
                None => ensure!(version == 1 && previous_record_hash.is_none(), Error::<T>::InvalidVersion),
                Some(head) => {
                    ensure!(version == head.saturating_add(1), Error::<T>::InvalidVersion);
                    let prior = CredentialVersions::<T>::get(credential_id, head).ok_or(Error::<T>::InvalidVersion)?;
                    ensure!(previous_record_hash == Some(prior.record_hash), Error::<T>::PreviousHashMismatch);
                },
            }
            let value = CredentialVersion {
                version,
                subject_id,
                credential_type,
                issuer_subject_id,
                claim_hash,
                non_transferable,
                state,
                valid_until,
                previous_record_hash,
                record_hash,
            };
            CredentialVersions::<T>::insert(credential_id, version, value);
            CredentialHeads::<T>::insert(credential_id, version);
            Self::deposit_event(Event::CredentialVersionRecorded { credential_id, subject_id, version, state, non_transferable, record_hash });
            Ok(())
        }
    }

    impl<T: Config> Pallet<T> {
        pub fn current_identity(subject_id: Id32) -> Option<IdentityVersion<BlockNumberFor<T>>> {
            let version = IdentityHeads::<T>::get(subject_id)?;
            IdentityVersions::<T>::get(subject_id, version)
        }
    }
}
