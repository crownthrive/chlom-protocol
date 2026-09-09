#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{AuthorityClass, BasisPoints, Id32, RecordState, FULL_BASIS_POINTS, ZERO_ID};
    use codec::{Decode, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct OwnershipInterest {
        pub asset_id: Id32,
        pub asset_version_hash: Id32,
        pub holder_subject_id: Id32,
        pub interest_type: Id32,
        pub share_basis_points: BasisPoints,
        pub state: RecordState,
        pub authority_class: AuthorityClass,
        pub basis_instrument_hash: Option<Id32>,
        pub supersedes_interest_id: Option<Id32>,
        pub evidence_hash: Id32,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct RightsInstrument<BlockNumber> {
        pub asset_id: Id32,
        pub asset_version_hash: Id32,
        pub grantor_subject_id: Id32,
        pub grantee_subject_id: Id32,
        pub instrument_type: Id32,
        pub rights_scope_hash: Id32,
        pub excluded_scope_hash: Id32,
        pub territory_scope_hash: Id32,
        pub channel_scope_hash: Id32,
        pub exclusive: bool,
        pub transferable: bool,
        pub sublicensable: bool,
        pub commercial_use: bool,
        pub valid_from: Option<BlockNumber>,
        pub valid_until: Option<BlockNumber>,
        pub royalty_policy_id: Option<Id32>,
        pub state: RecordState,
        pub authority_class: AuthorityClass,
        pub governing_instrument_hash: Option<Id32>,
        pub supersedes_instrument_id: Option<Id32>,
        pub evidence_hash: Id32,
        pub terms_hash: Id32,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type RightsOrigin: EnsureOrigin<Self::RuntimeOrigin>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type OwnershipInterests<T: Config> =
        StorageMap<_, Blake2_128Concat, Id32, OwnershipInterest, OptionQuery>;

    #[pallet::storage]
    pub type OwnershipSupersededBy<T: Config> =
        StorageMap<_, Blake2_128Concat, Id32, Id32, OptionQuery>;

    #[pallet::storage]
    pub type RightsInstruments<T: Config> = StorageMap<
        _, Blake2_128Concat, Id32, RightsInstrument<BlockNumberFor<T>>, OptionQuery
    >;

    #[pallet::storage]
    pub type RightsSupersededBy<T: Config> =
        StorageMap<_, Blake2_128Concat, Id32, Id32, OptionQuery>;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        OwnershipInterestRecorded { interest_id: Id32, asset_id: Id32, holder_subject_id: Id32, state: RecordState, record_hash: Id32 },
        RightsInstrumentRecorded { instrument_id: Id32, asset_id: Id32, grantor_subject_id: Id32, grantee_subject_id: Id32, state: RecordState, record_hash: Id32 },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        InvalidShare,
        RecordAlreadyExists,
        SupersededRecordMissing,
        SupersededRecordMismatch,
        RecordAlreadySuperseded,
        ContractualStateRequiresD3,
        ContractualStateRequiresGoverningInstrument,
        InvalidTerm,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(45_000_000, 0))]
        pub fn record_ownership_interest(
            origin: OriginFor<T>,
            interest_id: Id32,
            asset_id: Id32,
            asset_version_hash: Id32,
            holder_subject_id: Id32,
            interest_type: Id32,
            share_basis_points: BasisPoints,
            state: RecordState,
            authority_class: AuthorityClass,
            basis_instrument_hash: Option<Id32>,
            supersedes_interest_id: Option<Id32>,
            evidence_hash: Id32,
            record_hash: Id32,
        ) -> DispatchResult {
            T::RightsOrigin::ensure_origin(origin)?;
            ensure!(interest_id != ZERO_ID && asset_id != ZERO_ID && asset_version_hash != ZERO_ID && holder_subject_id != ZERO_ID && interest_type != ZERO_ID && evidence_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(share_basis_points > 0 && u32::from(share_basis_points) <= FULL_BASIS_POINTS, Error::<T>::InvalidShare);
            ensure!(!OwnershipInterests::<T>::contains_key(interest_id), Error::<T>::RecordAlreadyExists);
            if matches!(state, RecordState::ContractuallyRecorded | RecordState::Operative) {
                ensure!(authority_class.permits(AuthorityClass::D3), Error::<T>::ContractualStateRequiresD3);
                ensure!(basis_instrument_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ContractualStateRequiresGoverningInstrument);
            }
            if let Some(prior_id) = supersedes_interest_id {
                let prior = OwnershipInterests::<T>::get(prior_id).ok_or(Error::<T>::SupersededRecordMissing)?;
                ensure!(prior.asset_id == asset_id, Error::<T>::SupersededRecordMismatch);
                ensure!(!OwnershipSupersededBy::<T>::contains_key(prior_id), Error::<T>::RecordAlreadySuperseded);
                OwnershipSupersededBy::<T>::insert(prior_id, interest_id);
            }
            let value = OwnershipInterest {
                asset_id,
                asset_version_hash,
                holder_subject_id,
                interest_type,
                share_basis_points,
                state,
                authority_class,
                basis_instrument_hash,
                supersedes_interest_id,
                evidence_hash,
                record_hash,
            };
            OwnershipInterests::<T>::insert(interest_id, value);
            Self::deposit_event(Event::OwnershipInterestRecorded { interest_id, asset_id, holder_subject_id, state, record_hash });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(55_000_000, 0))]
        pub fn record_rights_instrument(
            origin: OriginFor<T>,
            instrument_id: Id32,
            asset_id: Id32,
            asset_version_hash: Id32,
            grantor_subject_id: Id32,
            grantee_subject_id: Id32,
            instrument_type: Id32,
            rights_scope_hash: Id32,
            excluded_scope_hash: Id32,
            territory_scope_hash: Id32,
            channel_scope_hash: Id32,
            exclusive: bool,
            transferable: bool,
            sublicensable: bool,
            commercial_use: bool,
            valid_from: Option<BlockNumberFor<T>>,
            valid_until: Option<BlockNumberFor<T>>,
            royalty_policy_id: Option<Id32>,
            state: RecordState,
            authority_class: AuthorityClass,
            governing_instrument_hash: Option<Id32>,
            supersedes_instrument_id: Option<Id32>,
            evidence_hash: Id32,
            terms_hash: Id32,
            record_hash: Id32,
        ) -> DispatchResult {
            T::RightsOrigin::ensure_origin(origin)?;
            ensure!(instrument_id != ZERO_ID && asset_id != ZERO_ID && asset_version_hash != ZERO_ID && grantor_subject_id != ZERO_ID && grantee_subject_id != ZERO_ID && instrument_type != ZERO_ID && rights_scope_hash != ZERO_ID && evidence_hash != ZERO_ID && terms_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!RightsInstruments::<T>::contains_key(instrument_id), Error::<T>::RecordAlreadyExists);
            ensure!(!matches!((valid_from, valid_until), (Some(start), Some(end)) if end < start), Error::<T>::InvalidTerm);
            if matches!(state, RecordState::ContractuallyRecorded | RecordState::Operative) {
                ensure!(authority_class.permits(AuthorityClass::D3), Error::<T>::ContractualStateRequiresD3);
                ensure!(governing_instrument_hash.is_some_and(|value| value != ZERO_ID), Error::<T>::ContractualStateRequiresGoverningInstrument);
            }
            if let Some(prior_id) = supersedes_instrument_id {
                let prior = RightsInstruments::<T>::get(prior_id).ok_or(Error::<T>::SupersededRecordMissing)?;
                ensure!(prior.asset_id == asset_id, Error::<T>::SupersededRecordMismatch);
                ensure!(!RightsSupersededBy::<T>::contains_key(prior_id), Error::<T>::RecordAlreadySuperseded);
                RightsSupersededBy::<T>::insert(prior_id, instrument_id);
            }
            let value = RightsInstrument {
                asset_id,
                asset_version_hash,
                grantor_subject_id,
                grantee_subject_id,
                instrument_type,
                rights_scope_hash,
                excluded_scope_hash,
                territory_scope_hash,
                channel_scope_hash,
                exclusive,
                transferable,
                sublicensable,
                commercial_use,
                valid_from,
                valid_until,
                royalty_policy_id,
                state,
                authority_class,
                governing_instrument_hash,
                supersedes_instrument_id,
                evidence_hash,
                terms_hash,
                record_hash,
            };
            RightsInstruments::<T>::insert(instrument_id, value);
            Self::deposit_event(Event::RightsInstrumentRecorded { instrument_id, asset_id, grantor_subject_id, grantee_subject_id, state, record_hash });
            Ok(())
        }
    }

    impl<T: Config> Pallet<T> {
        pub fn rights_state(instrument_id: Id32) -> Option<RecordState> {
            RightsInstruments::<T>::get(instrument_id).map(|value| value.state)
        }
    }
}
