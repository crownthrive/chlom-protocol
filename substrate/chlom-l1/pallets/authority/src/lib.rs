#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{AuthorityClass, Id32, ZERO_ID};
    use codec::{Decode, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct GrantKey {
        pub subject_id: Id32,
        pub role_id: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct AuthorityGrant<BlockNumber> {
        pub version: u32,
        pub class: AuthorityClass,
        pub active: bool,
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
    pub type GrantHeads<T: Config> =
        StorageMap<_, Blake2_128Concat, GrantKey, u32, OptionQuery>;

    #[pallet::storage]
    pub type GrantVersions<T: Config> = StorageDoubleMap<
        _,
        Blake2_128Concat,
        GrantKey,
        Blake2_128Concat,
        u32,
        AuthorityGrant<BlockNumberFor<T>>,
        OptionQuery,
    >;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        AuthorityVersionRecorded {
            subject_id: Id32,
            role_id: Id32,
            version: u32,
            class: AuthorityClass,
            active: bool,
            record_hash: Id32,
        },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        InvalidVersion,
        PreviousHashMismatch,
        VersionAlreadyExists,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(25_000_000, 0))]
        pub fn record_grant_version(
            origin: OriginFor<T>,
            subject_id: Id32,
            role_id: Id32,
            version: u32,
            class: AuthorityClass,
            active: bool,
            valid_until: Option<BlockNumberFor<T>>,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::AdminOrigin::ensure_origin(origin)?;
            ensure!(subject_id != ZERO_ID && role_id != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            let key = GrantKey { subject_id, role_id };
            ensure!(!GrantVersions::<T>::contains_key(&key, version), Error::<T>::VersionAlreadyExists);
            match GrantHeads::<T>::get(&key) {
                None => {
                    ensure!(version == 1 && previous_record_hash.is_none(), Error::<T>::InvalidVersion);
                },
                Some(head) => {
                    ensure!(version == head.saturating_add(1), Error::<T>::InvalidVersion);
                    let prior = GrantVersions::<T>::get(&key, head).ok_or(Error::<T>::InvalidVersion)?;
                    ensure!(previous_record_hash == Some(prior.record_hash), Error::<T>::PreviousHashMismatch);
                },
            }
            let grant = AuthorityGrant {
                version,
                class,
                active,
                valid_until,
                previous_record_hash,
                record_hash,
            };
            GrantVersions::<T>::insert(&key, version, grant);
            GrantHeads::<T>::insert(&key, version);
            Self::deposit_event(Event::AuthorityVersionRecorded {
                subject_id,
                role_id,
                version,
                class,
                active,
                record_hash,
            });
            Ok(())
        }
    }

    impl<T: Config> Pallet<T> {
        pub fn active_class(subject_id: Id32, role_id: Id32) -> Option<AuthorityClass> {
            let key = GrantKey { subject_id, role_id };
            let head = GrantHeads::<T>::get(&key)?;
            let grant = GrantVersions::<T>::get(&key, head)?;
            if !grant.active {
                return None;
            }
            if grant.valid_until.is_some_and(|until| frame_system::Pallet::<T>::block_number() > until) {
                return None;
            }
            Some(grant.class)
        }
    }
}
