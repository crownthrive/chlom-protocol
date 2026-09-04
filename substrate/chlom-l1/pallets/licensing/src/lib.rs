#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{DlaState, Id32, LicenseStatus, OfferState, RecordState, ZERO_ID};
    use codec::{Decode, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct DlaVersion {
        pub version: u32,
        pub asset_id: Id32,
        pub asset_version_hash: Id32,
        pub rights_instrument_id: Id32,
        pub rights_state: RecordState,
        pub evidence_readiness_hash: Id32,
        pub policy_binding_hash: Id32,
        pub offerability: DlaState,
        pub tokenization_state: RecordState,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct LicenseVersion<BlockNumber> {
        pub version: u32,
        pub dla_id: Id32,
        pub license_type: Id32,
        pub issuer_subject_id: Id32,
        pub holder_subject_id: Id32,
        pub jurisdiction_scope_hash: Id32,
        pub terms_hash: Id32,
        pub expires_at: Option<BlockNumber>,
        pub status: LicenseStatus,
        pub transferable: bool,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct LexOfferVersion<BlockNumber> {
        pub version: u32,
        pub dla_id: Id32,
        pub license_template_hash: Id32,
        pub licensor_subject_id: Id32,
        pub offered_scope_hash: Id32,
        pub excluded_scope_hash: Id32,
        pub price: u128,
        pub currency_id: Id32,
        pub state: OfferState,
        pub provider_activation_verified: bool,
        pub valid_until: Option<BlockNumber>,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct EntitlementVersion<BlockNumber> {
        pub version: u32,
        pub license_id: Id32,
        pub holder_subject_id: Id32,
        pub granted_scope_hash: Id32,
        pub obligations_hash: Id32,
        pub state: RecordState,
        pub valid_until: Option<BlockNumber>,
        pub previous_record_hash: Option<Id32>,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type LicensingOrigin: EnsureOrigin<Self::RuntimeOrigin>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type DlaHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;
    #[pallet::storage]
    pub type DlaVersions<T: Config> = StorageDoubleMap<_, Blake2_128Concat, Id32, Blake2_128Concat, u32, DlaVersion, OptionQuery>;
    #[pallet::storage]
    pub type LicenseHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;
    #[pallet::storage]
    pub type LicenseVersions<T: Config> = StorageDoubleMap<_, Blake2_128Concat, Id32, Blake2_128Concat, u32, LicenseVersion<BlockNumberFor<T>>, OptionQuery>;
    #[pallet::storage]
    pub type OfferHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;
    #[pallet::storage]
    pub type OfferVersions<T: Config> = StorageDoubleMap<_, Blake2_128Concat, Id32, Blake2_128Concat, u32, LexOfferVersion<BlockNumberFor<T>>, OptionQuery>;
    #[pallet::storage]
    pub type EntitlementHeads<T: Config> = StorageMap<_, Blake2_128Concat, Id32, u32, OptionQuery>;
    #[pallet::storage]
    pub type EntitlementVersions<T: Config> = StorageDoubleMap<_, Blake2_128Concat, Id32, Blake2_128Concat, u32, EntitlementVersion<BlockNumberFor<T>>, OptionQuery>;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        DlaVersionRecorded { dla_id: Id32, version: u32, asset_id: Id32, offerability: DlaState, record_hash: Id32 },
        LicenseVersionRecorded { license_id: Id32, version: u32, holder_subject_id: Id32, status: LicenseStatus, record_hash: Id32 },
        LexOfferVersionRecorded { offer_id: Id32, version: u32, dla_id: Id32, state: OfferState, record_hash: Id32 },
        EntitlementVersionRecorded { entitlement_id: Id32, version: u32, license_id: Id32, holder_subject_id: Id32, state: RecordState, record_hash: Id32 },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        InvalidVersion,
        PreviousHashMismatch,
        VersionAlreadyExists,
        DlaMissing,
        DlaNotEligible,
        RightsNotReady,
        LicenseMissing,
        LicenseNotActive,
        InvalidStatusTransition,
        OfferNotEligible,
        PublicOfferRequiresProviderReadback,
        InvalidTerm,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(50_000_000, 0))]
        pub fn record_dla_version(
            origin: OriginFor<T>,
            dla_id: Id32,
            version: u32,
            asset_id: Id32,
            asset_version_hash: Id32,
            rights_instrument_id: Id32,
            rights_state: RecordState,
            evidence_readiness_hash: Id32,
            policy_binding_hash: Id32,
            offerability: DlaState,
            tokenization_state: RecordState,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::LicensingOrigin::ensure_origin(origin)?;
            ensure!(dla_id != ZERO_ID && asset_id != ZERO_ID && asset_version_hash != ZERO_ID && rights_instrument_id != ZERO_ID && evidence_readiness_hash != ZERO_ID && policy_binding_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!DlaVersions::<T>::contains_key(dla_id, version), Error::<T>::VersionAlreadyExists);
            match offerability {
                DlaState::EligiblePublic => ensure!(matches!(rights_state, RecordState::ContractuallyRecorded | RecordState::Operative), Error::<T>::RightsNotReady),
                DlaState::EligibleInternal => ensure!(matches!(rights_state, RecordState::VerifiedForWorkflow | RecordState::ContractuallyRecorded | RecordState::Operative), Error::<T>::RightsNotReady),
                _ => {},
            }
            Self::validate_version(DlaHeads::<T>::get(dla_id), version, previous_record_hash, |head| DlaVersions::<T>::get(dla_id, head).map(|value| value.record_hash))?;
            DlaVersions::<T>::insert(dla_id, version, DlaVersion {
                version,
                asset_id,
                asset_version_hash,
                rights_instrument_id,
                rights_state,
                evidence_readiness_hash,
                policy_binding_hash,
                offerability,
                tokenization_state,
                previous_record_hash,
                record_hash,
            });
            DlaHeads::<T>::insert(dla_id, version);
            Self::deposit_event(Event::DlaVersionRecorded { dla_id, version, asset_id, offerability, record_hash });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(55_000_000, 0))]
        pub fn record_license_version(
            origin: OriginFor<T>,
            license_id: Id32,
            version: u32,
            dla_id: Id32,
            license_type: Id32,
            issuer_subject_id: Id32,
            holder_subject_id: Id32,
            jurisdiction_scope_hash: Id32,
            terms_hash: Id32,
            expires_at: Option<BlockNumberFor<T>>,
            status: LicenseStatus,
            transferable: bool,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::LicensingOrigin::ensure_origin(origin)?;
            ensure!(license_id != ZERO_ID && dla_id != ZERO_ID && license_type != ZERO_ID && issuer_subject_id != ZERO_ID && holder_subject_id != ZERO_ID && jurisdiction_scope_hash != ZERO_ID && terms_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            let dla = Self::current_dla(dla_id).ok_or(Error::<T>::DlaMissing)?;
            if matches!(status, LicenseStatus::Active) {
                ensure!(matches!(dla.offerability, DlaState::EligibleInternal | DlaState::EligiblePublic), Error::<T>::DlaNotEligible);
                ensure!(!expires_at.is_some_and(|until| until < frame_system::Pallet::<T>::block_number()), Error::<T>::InvalidTerm);
            }
            ensure!(!LicenseVersions::<T>::contains_key(license_id, version), Error::<T>::VersionAlreadyExists);
            let prior = LicenseHeads::<T>::get(license_id).and_then(|head| LicenseVersions::<T>::get(license_id, head));
            if let Some(ref value) = prior {
                ensure!(Self::valid_status_transition(value.status, status), Error::<T>::InvalidStatusTransition);
            }
            Self::validate_version(LicenseHeads::<T>::get(license_id), version, previous_record_hash, |head| LicenseVersions::<T>::get(license_id, head).map(|value| value.record_hash))?;
            LicenseVersions::<T>::insert(license_id, version, LicenseVersion {
                version,
                dla_id,
                license_type,
                issuer_subject_id,
                holder_subject_id,
                jurisdiction_scope_hash,
                terms_hash,
                expires_at,
                status,
                transferable,
                previous_record_hash,
                record_hash,
            });
            LicenseHeads::<T>::insert(license_id, version);
            Self::deposit_event(Event::LicenseVersionRecorded { license_id, version, holder_subject_id, status, record_hash });
            Ok(())
        }

        #[pallet::call_index(2)]
        #[pallet::weight(Weight::from_parts(50_000_000, 0))]
        pub fn record_lex_offer_version(
            origin: OriginFor<T>,
            offer_id: Id32,
            version: u32,
            dla_id: Id32,
            license_template_hash: Id32,
            licensor_subject_id: Id32,
            offered_scope_hash: Id32,
            excluded_scope_hash: Id32,
            price: u128,
            currency_id: Id32,
            state: OfferState,
            provider_activation_verified: bool,
            valid_until: Option<BlockNumberFor<T>>,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::LicensingOrigin::ensure_origin(origin)?;
            ensure!(offer_id != ZERO_ID && dla_id != ZERO_ID && license_template_hash != ZERO_ID && licensor_subject_id != ZERO_ID && offered_scope_hash != ZERO_ID && currency_id != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            let dla = Self::current_dla(dla_id).ok_or(Error::<T>::DlaMissing)?;
            match state {
                OfferState::Published => {
                    ensure!(matches!(dla.offerability, DlaState::EligiblePublic), Error::<T>::OfferNotEligible);
                    ensure!(provider_activation_verified, Error::<T>::PublicOfferRequiresProviderReadback);
                },
                OfferState::StagedInternal => ensure!(matches!(dla.offerability, DlaState::EligibleInternal | DlaState::EligiblePublic), Error::<T>::OfferNotEligible),
                _ => {},
            }
            ensure!(!valid_until.is_some_and(|until| until < frame_system::Pallet::<T>::block_number()), Error::<T>::InvalidTerm);
            ensure!(!OfferVersions::<T>::contains_key(offer_id, version), Error::<T>::VersionAlreadyExists);
            Self::validate_version(OfferHeads::<T>::get(offer_id), version, previous_record_hash, |head| OfferVersions::<T>::get(offer_id, head).map(|value| value.record_hash))?;
            OfferVersions::<T>::insert(offer_id, version, LexOfferVersion {
                version,
                dla_id,
                license_template_hash,
                licensor_subject_id,
                offered_scope_hash,
                excluded_scope_hash,
                price,
                currency_id,
                state,
                provider_activation_verified,
                valid_until,
                previous_record_hash,
                record_hash,
            });
            OfferHeads::<T>::insert(offer_id, version);
            Self::deposit_event(Event::LexOfferVersionRecorded { offer_id, version, dla_id, state, record_hash });
            Ok(())
        }

        #[pallet::call_index(3)]
        #[pallet::weight(Weight::from_parts(45_000_000, 0))]
        pub fn record_entitlement_version(
            origin: OriginFor<T>,
            entitlement_id: Id32,
            version: u32,
            license_id: Id32,
            holder_subject_id: Id32,
            granted_scope_hash: Id32,
            obligations_hash: Id32,
            state: RecordState,
            valid_until: Option<BlockNumberFor<T>>,
            previous_record_hash: Option<Id32>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::LicensingOrigin::ensure_origin(origin)?;
            ensure!(entitlement_id != ZERO_ID && license_id != ZERO_ID && holder_subject_id != ZERO_ID && granted_scope_hash != ZERO_ID && obligations_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            if matches!(state, RecordState::Operative | RecordState::ContractuallyRecorded) {
                ensure!(Self::is_license_active(license_id), Error::<T>::LicenseNotActive);
            }
            ensure!(!EntitlementVersions::<T>::contains_key(entitlement_id, version), Error::<T>::VersionAlreadyExists);
            Self::validate_version(EntitlementHeads::<T>::get(entitlement_id), version, previous_record_hash, |head| EntitlementVersions::<T>::get(entitlement_id, head).map(|value| value.record_hash))?;
            EntitlementVersions::<T>::insert(entitlement_id, version, EntitlementVersion {
                version,
                license_id,
                holder_subject_id,
                granted_scope_hash,
                obligations_hash,
                state,
                valid_until,
                previous_record_hash,
                record_hash,
            });
            EntitlementHeads::<T>::insert(entitlement_id, version);
            Self::deposit_event(Event::EntitlementVersionRecorded { entitlement_id, version, license_id, holder_subject_id, state, record_hash });
            Ok(())
        }
    }

    impl<T: Config> Pallet<T> {
        fn validate_version<F>(head: Option<u32>, version: u32, previous_record_hash: Option<Id32>, prior_hash: F) -> DispatchResult
        where
            F: FnOnce(u32) -> Option<Id32>,
        {
            match head {
                None => ensure!(version == 1 && previous_record_hash.is_none(), Error::<T>::InvalidVersion),
                Some(current) => {
                    ensure!(version == current.saturating_add(1), Error::<T>::InvalidVersion);
                    ensure!(previous_record_hash == prior_hash(current), Error::<T>::PreviousHashMismatch);
                },
            }
            Ok(())
        }

        fn valid_status_transition(from: LicenseStatus, to: LicenseStatus) -> bool {
            use LicenseStatus::*;
            match from {
                Revoked | Expired | Superseded => matches!(to, Revoked | Expired | Superseded),
                Suspended => matches!(to, Suspended | Active | Revoked | Expired | Superseded),
                Pending => matches!(to, Pending | Active | Suspended | Revoked | Expired | Superseded),
                Active => matches!(to, Active | Suspended | Revoked | Expired | Superseded),
            }
        }

        pub fn current_dla(dla_id: Id32) -> Option<DlaVersion> {
            let version = DlaHeads::<T>::get(dla_id)?;
            DlaVersions::<T>::get(dla_id, version)
        }

        pub fn current_license(license_id: Id32) -> Option<LicenseVersion<BlockNumberFor<T>>> {
            let version = LicenseHeads::<T>::get(license_id)?;
            LicenseVersions::<T>::get(license_id, version)
        }

        pub fn is_license_active(license_id: Id32) -> bool {
            Self::current_license(license_id).is_some_and(|license| {
                license.status == LicenseStatus::Active
                    && !license.expires_at.is_some_and(|until| frame_system::Pallet::<T>::block_number() > until)
            })
        }
    }
}
