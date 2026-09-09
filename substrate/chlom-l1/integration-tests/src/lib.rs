#![cfg(test)]

use chlom_primitives::{
    AuthorityClass, DlaState, ExternalIssuanceState, LicenseStatus, OfferState, RecordState,
    SignalAction, TokenClassKind,
};
use frame_support::{assert_noop, assert_ok, derive_impl, parameter_types, BoundedVec};
use sp_runtime::BuildStorage;

type Block = frame_system::mocking::MockBlock<Test>;

#[frame_support::runtime]
mod runtime {
    #[runtime::runtime]
    #[runtime::derive(
        RuntimeCall,
        RuntimeEvent,
        RuntimeError,
        RuntimeOrigin,
        RuntimeFreezeReason,
        RuntimeHoldReason,
        RuntimeSlashReason,
        RuntimeLockId,
        RuntimeTask,
        RuntimeViewFunction
    )]
    pub struct Test;

    #[runtime::pallet_index(0)]
    pub type System = frame_system::Pallet<Test>;
    #[runtime::pallet_index(1)]
    pub type ChlomAuthority = pallet_chlom_authority::Pallet<Test>;
    #[runtime::pallet_index(2)]
    pub type ChlomIdentity = pallet_chlom_identity::Pallet<Test>;
    #[runtime::pallet_index(3)]
    pub type ChlomRights = pallet_chlom_rights::Pallet<Test>;
    #[runtime::pallet_index(4)]
    pub type ChlomLicensing = pallet_chlom_licensing::Pallet<Test>;
    #[runtime::pallet_index(5)]
    pub type ChlomSettlement = pallet_chlom_settlement::Pallet<Test>;
    #[runtime::pallet_index(6)]
    pub type ChlomTokenization = pallet_chlom_tokenization::Pallet<Test>;
    #[runtime::pallet_index(7)]
    pub type ChlomOracle = pallet_chlom_oracle::Pallet<Test>;
    #[runtime::pallet_index(8)]
    pub type ChlomCheckpoint = pallet_chlom_checkpoint::Pallet<Test>;
}

#[derive_impl(frame_system::config_preludes::TestDefaultConfig)]
impl frame_system::Config for Test {
    type Block = Block;
}

parameter_types! {
    pub const MaxLegs: u32 = 16;
}

impl pallet_chlom_authority::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type AdminOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_identity::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type AdminOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_rights::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type RightsOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_licensing::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type LicensingOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_settlement::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type SettlementOrigin = frame_system::EnsureRoot<u64>;
    type MaxLegs = MaxLegs;
}

impl pallet_chlom_tokenization::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type TokenOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_oracle::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type OracleOrigin = frame_system::EnsureRoot<u64>;
    type ReviewOrigin = frame_system::EnsureRoot<u64>;
}

impl pallet_chlom_checkpoint::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type CheckpointOrigin = frame_system::EnsureRoot<u64>;
    type AnchorOrigin = frame_system::EnsureRoot<u64>;
}

fn new_test_ext() -> sp_io::TestExternalities {
    frame_system::GenesisConfig::<Test>::default()
        .build_storage()
        .expect("test storage")
        .into()
}

fn id(value: u8) -> [u8; 32] {
    [value; 32]
}

#[test]
fn rights_before_tokens_end_to_end() {
    new_test_ext().execute_with(|| {
        System::set_block_number(1);

        assert_ok!(ChlomAuthority::record_grant_version(
            RuntimeOrigin::root(), id(1), id(2), 1, AuthorityClass::D3, true, None, None, id(3)
        ));
        assert_ok!(ChlomIdentity::record_identity_version(
            RuntimeOrigin::root(), id(1), 1, id(4), id(5), id(1), Some(id(6)),
            RecordState::VerifiedForWorkflow, None, id(7)
        ));

        assert_noop!(
            ChlomRights::record_ownership_interest(
                RuntimeOrigin::root(), id(10), id(11), id(12), id(1), id(13), 10_000,
                RecordState::ContractuallyRecorded, AuthorityClass::D2, Some(id(14)), None,
                id(15), id(16)
            ),
            pallet_chlom_rights::Error::<Test>::ContractualStateRequiresD3
        );

        assert_ok!(ChlomRights::record_ownership_interest(
            RuntimeOrigin::root(), id(10), id(11), id(12), id(1), id(13), 10_000,
            RecordState::ContractuallyRecorded, AuthorityClass::D3, Some(id(14)), None,
            id(15), id(16)
        ));
        assert_ok!(ChlomRights::record_rights_instrument(
            RuntimeOrigin::root(), id(20), id(11), id(12), id(1), id(21), id(22), id(23),
            id(24), id(25), id(26), false, true, false, true, Some(1), Some(100),
            Some(id(27)), RecordState::Operative, AuthorityClass::D3, Some(id(28)), None,
            id(29), id(30), id(31)
        ));

        assert_ok!(ChlomLicensing::record_dla_version(
            RuntimeOrigin::root(), id(40), 1, id(11), id(12), id(20), RecordState::Operative,
            id(41), id(42), DlaState::EligiblePublic, RecordState::UnderReview, None, id(43)
        ));
        assert_ok!(ChlomLicensing::record_license_version(
            RuntimeOrigin::root(), id(44), 1, id(40), id(45), id(1), id(46), id(47), id(48),
            Some(100), LicenseStatus::Active, true, None, id(49)
        ));
        assert_ok!(ChlomLicensing::record_lex_offer_version(
            RuntimeOrigin::root(), id(50), 1, id(40), id(51), id(1), id(52), id(53), 100,
            id(54), OfferState::Published, true, Some(100), None, id(55)
        ));
        assert_ok!(ChlomLicensing::record_entitlement_version(
            RuntimeOrigin::root(), id(56), 1, id(44), id(46), id(57), id(58),
            RecordState::Operative, Some(100), None, id(59)
        ));

        let legs: BoundedVec<_, MaxLegs> = vec![
            pallet_chlom_settlement::SplitLeg { leg_id: id(60), beneficiary_subject_id: id(1), allocation_role: id(61), basis_points: 7_000, conditions_hash: id(62) },
            pallet_chlom_settlement::SplitLeg { leg_id: id(63), beneficiary_subject_id: id(64), allocation_role: id(65), basis_points: 2_000, conditions_hash: id(66) },
            pallet_chlom_settlement::SplitLeg { leg_id: id(67), beneficiary_subject_id: id(68), allocation_role: id(69), basis_points: 1_000, conditions_hash: id(70) },
        ].try_into().expect("bounded legs");
        assert_ok!(ChlomSettlement::record_revenue_policy(
            RuntimeOrigin::root(), id(71), id(72), id(73), id(74), false, legs, id(75)
        ));
        assert_ok!(ChlomSettlement::preview_settlement(
            RuntimeOrigin::root(), id(76), id(71), id(50), 101, id(73), id(77)
        ));
        assert!(!pallet_chlom_settlement::SettlementPreviews::<Test>::get(id(76))
            .expect("preview").money_moved);

        assert_ok!(ChlomTokenization::record_token_class(
            RuntimeOrigin::root(), id(80), TokenClassKind::SmartLicense, true, id(81), false,
            ExternalIssuanceState::ProductionGated, id(82)
        ));
        assert_ok!(ChlomTokenization::register_tokenized_object(
            RuntimeOrigin::root(), id(83), id(80), id(84), id(40), id(43), Some(id(11)),
            Some(id(40)), Some(id(56)), id(46), id(85), id(86)
        ));
        let object = pallet_chlom_tokenization::TokenizedObjects::<Test>::get(id(83)).expect("object");
        assert!(!object.external_chain_transaction);
        assert!(!object.raw_private_evidence_embedded);

        assert_ok!(ChlomOracle::report_signal(
            RuntimeOrigin::root(), id(90), id(91), id(92), id(83), id(93), 9_000, 10_000,
            SignalAction::SuspensionReviewRecommended, id(94), id(95), Some((id(96), AuthorityClass::D3))
        ));
        let case = pallet_chlom_oracle::ReviewCases::<Test>::get(id(96)).expect("case");
        assert!(!case.consequential_action_taken);

        assert_ok!(ChlomCheckpoint::record_checkpoint(
            RuntimeOrigin::root(), id(100), 1, 12, 12, id(101), id(102), None, id(103),
            id(104), true, false, id(105)
        ));
        assert_ok!(ChlomCheckpoint::record_anchor_intent(
            RuntimeOrigin::root(), id(106), id(100), id(107), id(108), true, false, id(109)
        ));
    });
}
