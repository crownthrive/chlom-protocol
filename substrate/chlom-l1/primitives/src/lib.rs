#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::vec::Vec;
use codec::{Decode, DecodeWithMemTracking, Encode, MaxEncodedLen};
use scale_info::TypeInfo;
use sp_runtime::RuntimeDebug;

pub type Id32 = [u8; 32];
pub type BasisPoints = u16;
pub type Amount = u128;
pub const FULL_BASIS_POINTS: u32 = 10_000;
pub const ZERO_ID: Id32 = [0u8; 32];

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum AuthorityClass {
    D0,
    D1,
    D2,
    D3,
}

impl AuthorityClass {
    pub const fn rank(self) -> u8 {
        match self {
            Self::D0 => 0,
            Self::D1 => 1,
            Self::D2 => 2,
            Self::D3 => 3,
        }
    }

    pub const fn permits(self, required: Self) -> bool {
        self.rank() >= required.rank()
    }
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum RecordState {
    Draft,
    Asserted,
    UnderReview,
    VerifiedForWorkflow,
    ContractuallyRecorded,
    Operative,
    Suspended,
    Revoked,
    Expired,
    Superseded,
    Disputed,
    Retired,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum DlaState {
    Hold,
    EligibleInternal,
    EligiblePublic,
    Paused,
    Retired,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum LicenseStatus {
    Pending,
    Active,
    Suspended,
    Revoked,
    Expired,
    Superseded,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum OfferState {
    Draft,
    StagedInternal,
    Published,
    Paused,
    Closed,
    Revoked,
    Superseded,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum TokenClassKind {
    UniqueAsset,
    SmartLicense,
    ProvenanceCertificate,
    OwnershipCertificate,
    Entitlement,
    NonTransferableCredential,
    MultiEdition,
    UtilityCandidate,
    GovernanceCandidate,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum ExternalIssuanceState {
    ProductionGated,
    TestnetEligible,
    ProductionEligible,
    Suspended,
    Retired,
}

#[derive(Clone, Copy, Decode, DecodeWithMemTracking, Encode, Eq, MaxEncodedLen, PartialEq, RuntimeDebug, TypeInfo)]
pub enum SignalAction {
    Observe,
    Review,
    TemporaryQuarantineRecommended,
    SuspensionReviewRecommended,
    NoAction,
}

pub fn split_by_basis_points(total: Amount, legs: &[BasisPoints]) -> Option<Vec<Amount>> {
    if legs.is_empty() {
        return None;
    }
    let sum: u32 = legs.iter().map(|value| u32::from(*value)).sum();
    if sum != FULL_BASIS_POINTS {
        return None;
    }

    let mut remaining = total;
    let mut allocations = Vec::with_capacity(legs.len());
    for (index, basis_points) in legs.iter().enumerate() {
        let amount = if index + 1 == legs.len() {
            remaining
        } else {
            total
                .checked_mul(u128::from(*basis_points))?
                .checked_div(u128::from(FULL_BASIS_POINTS))?
        };
        remaining = remaining.checked_sub(amount)?;
        allocations.push(amount);
    }
    Some(allocations)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn split_is_balanced_and_remainder_safe() {
        let result = split_by_basis_points(101, &[7_000, 2_000, 1_000]).expect("balanced");
        assert_eq!(result, vec![70, 20, 11]);
        assert_eq!(result.iter().sum::<u128>(), 101);
    }

    #[test]
    fn split_rejects_unbalanced_policy() {
        assert!(split_by_basis_points(100, &[5_000, 4_999]).is_none());
    }
}
