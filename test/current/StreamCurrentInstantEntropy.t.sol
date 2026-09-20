// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentInstantEntropyFixture.sol";

/// @notice Nine actual-current INSTANT/floor recipes; joined runtime remains pending.
contract StreamCurrentInstantEntropyTest is CurrentInstantEntropyFixture {
    function testActualInstantPolicyConsentConfigureSeparateFreezeAndGovernanceReplay() public {
        _constructInstant();
        _configureInstant(true, true, true);
    }

    function testActualSafeInstantPaidMintOnlyRegistersWithZeroFeeAndFullSaleCredit() public {
        _constructInstant();
        _configureInstant(true, true, false);
        _paid(true, false, false);
    }

    function testSameBlockRequestRefusesThenIdenticalSafeRequestFinalizesWithExactProvenance()
        public
    {
        _constructInstant();
        _configureInstant(true, true, false);
        _paid(true, false, false);
        _requestAfterSameBlockRefusal();
    }

    function testPrivateInstantPolicyRefusesThenActualRequesterAdmissionEnablesExactSafeRetry()
        public
    {
        _constructInstant();
        _configureInstant(true, false, false);
        _paid(true, false, false);
        _privateRequesterAdmission();
    }

    function testOriginalSafeNonceAndValueAuthorizationRefusalsPreservePaidMintRetry() public {
        _constructInstant();
        _configureInstant(true, true, false);
        _paid(true, false, true);
    }

    function testFinalizedInstantRequestReplayPreservesOriginalSeedAndClosedCredits() public {
        _constructInstant();
        _configureInstant(true, true, false);
        _paid(true, false, false);
        _requestReplay();
    }

    function testActualInstantNotRequiredPaidMintHasNoDrawSeedFeeOrRequest() public {
        _constructInstant();
        _configureInstant(false, true, false);
        _paid(false, false, false);
        _notRequiredRefusal();
    }

    function testRejectedActualInstantMintDeliveryRollsBackAndExactSafeRetryRegisters() public {
        _constructInstant();
        _configureInstant(true, true, false);
        _paid(true, true, false);
    }

    function testActualFloorUnboundUndeclaredRefusalsAndExactSafePaidRetry() public {
        _constructInstant();
        _configureInstant(true, true, false);
        _floorRefusalsThenExactPaidRetry();
    }
}
