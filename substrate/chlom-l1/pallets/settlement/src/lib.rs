#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use chlom_primitives::{split_by_basis_points, BasisPoints, Id32, FULL_BASIS_POINTS, ZERO_ID};
    use codec::{Decode, DecodeWithMemTracking, Encode, MaxEncodedLen};
    use frame_support::{pallet_prelude::*, traits::EnsureOrigin, BoundedVec};
    use frame_system::pallet_prelude::*;
    use scale_info::TypeInfo;
    use sp_runtime::RuntimeDebug;
    use sp_std::vec::Vec;

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct SplitLeg {
        pub leg_id: Id32,
        pub beneficiary_subject_id: Id32,
        pub allocation_role: Id32,
        pub basis_points: BasisPoints,
        pub conditions_hash: Id32,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    #[scale_info(skip_type_params(MaxLegs))]
    pub struct RevenuePolicy<MaxLegs: Get<u32>> {
        pub calculation_basis: Id32,
        pub currency_id: Id32,
        pub legal_tax_review_hash: Id32,
        pub money_movement_authorized: bool,
        pub legs: BoundedVec<SplitLeg, MaxLegs>,
        pub record_hash: Id32,
    }

    #[derive(Clone, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
    pub struct SettlementPreview {
        pub policy_id: Id32,
        pub source_object_id: Id32,
        pub gross_amount: u128,
        pub currency_id: Id32,
        pub allocation_root: Id32,
        pub money_moved: bool,
        pub record_hash: Id32,
    }

    #[pallet::config]
    pub trait Config: frame_system::Config {
        #[allow(deprecated)]
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
        type SettlementOrigin: EnsureOrigin<Self::RuntimeOrigin>;
        #[pallet::constant]
        type MaxLegs: Get<u32>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    #[pallet::storage]
    pub type RevenuePolicies<T: Config> =
        StorageMap<_, Blake2_128Concat, Id32, RevenuePolicy<T::MaxLegs>, OptionQuery>;

    #[pallet::storage]
    pub type SettlementPreviews<T: Config> =
        StorageMap<_, Blake2_128Concat, Id32, SettlementPreview, OptionQuery>;

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        RevenuePolicyRecorded { policy_id: Id32, leg_count: u32, record_hash: Id32 },
        SettlementPreviewCalculated { preview_id: Id32, policy_id: Id32, gross_amount: u128, currency_id: Id32, allocation_root: Id32, money_moved: bool },
    }

    #[pallet::error]
    pub enum Error<T> {
        InvalidIdentifier,
        PolicyAlreadyExists,
        PreviewAlreadyExists,
        EmptyPolicy,
        UnbalancedPolicy,
        MoneyMovementForbidden,
        PolicyMissing,
        CurrencyMismatch,
        ArithmeticFailure,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        #[pallet::call_index(0)]
        #[pallet::weight(Weight::from_parts(55_000_000, 0))]
        pub fn record_revenue_policy(
            origin: OriginFor<T>,
            policy_id: Id32,
            calculation_basis: Id32,
            currency_id: Id32,
            legal_tax_review_hash: Id32,
            money_movement_authorized: bool,
            legs: BoundedVec<SplitLeg, T::MaxLegs>,
            record_hash: Id32,
        ) -> DispatchResult {
            T::SettlementOrigin::ensure_origin(origin)?;
            ensure!(policy_id != ZERO_ID && calculation_basis != ZERO_ID && currency_id != ZERO_ID && legal_tax_review_hash != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!RevenuePolicies::<T>::contains_key(policy_id), Error::<T>::PolicyAlreadyExists);
            ensure!(!legs.is_empty(), Error::<T>::EmptyPolicy);
            ensure!(!money_movement_authorized, Error::<T>::MoneyMovementForbidden);
            let mut total: u32 = 0;
            for leg in legs.iter() {
                ensure!(leg.leg_id != ZERO_ID && leg.beneficiary_subject_id != ZERO_ID && leg.allocation_role != ZERO_ID, Error::<T>::InvalidIdentifier);
                total = total.saturating_add(u32::from(leg.basis_points));
            }
            ensure!(total == FULL_BASIS_POINTS, Error::<T>::UnbalancedPolicy);
            let leg_count = legs.len() as u32;
            RevenuePolicies::<T>::insert(policy_id, RevenuePolicy {
                calculation_basis,
                currency_id,
                legal_tax_review_hash,
                money_movement_authorized,
                legs,
                record_hash,
            });
            Self::deposit_event(Event::RevenuePolicyRecorded { policy_id, leg_count, record_hash });
            Ok(())
        }

        #[pallet::call_index(1)]
        #[pallet::weight(Weight::from_parts(60_000_000, 0))]
        pub fn preview_settlement(
            origin: OriginFor<T>,
            preview_id: Id32,
            policy_id: Id32,
            source_object_id: Id32,
            gross_amount: u128,
            currency_id: Id32,
            record_hash: Id32,
        ) -> DispatchResult {
            T::SettlementOrigin::ensure_origin(origin)?;
            ensure!(preview_id != ZERO_ID && policy_id != ZERO_ID && source_object_id != ZERO_ID && currency_id != ZERO_ID && record_hash != ZERO_ID, Error::<T>::InvalidIdentifier);
            ensure!(!SettlementPreviews::<T>::contains_key(preview_id), Error::<T>::PreviewAlreadyExists);
            let policy = RevenuePolicies::<T>::get(policy_id).ok_or(Error::<T>::PolicyMissing)?;
            ensure!(policy.currency_id == currency_id, Error::<T>::CurrencyMismatch);
            ensure!(!policy.money_movement_authorized, Error::<T>::MoneyMovementForbidden);
            let basis_points: Vec<BasisPoints> = policy.legs.iter().map(|leg| leg.basis_points).collect();
            let allocations = split_by_basis_points(gross_amount, &basis_points).ok_or(Error::<T>::ArithmeticFailure)?;
            let allocation_root = sp_io::hashing::blake2_256(&(policy_id, source_object_id, gross_amount, currency_id, allocations).encode());
            SettlementPreviews::<T>::insert(preview_id, SettlementPreview {
                policy_id,
                source_object_id,
                gross_amount,
                currency_id,
                allocation_root,
                money_moved: false,
                record_hash,
            });
            Self::deposit_event(Event::SettlementPreviewCalculated {
                preview_id,
                policy_id,
                gross_amount,
                currency_id,
                allocation_root,
                money_moved: false,
            });
            Ok(())
        }
    }
}
