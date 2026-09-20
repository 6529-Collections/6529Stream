// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDelegatedNativeOfferContinuityFixture.sol";

/// @notice Original native primary offers retain genuine delegated authority during deprecation.
/// @dev Source/type evidence only until native execution. Both actual Manager signature paths and
/// the selected gate are exercised by complete purchases; no unsupported pre-sale preview is used.
contract StreamCurrentDelegatedNativeOfferContinuityTest is
    CurrentDelegatedNativeOfferContinuityFixture
{
    function setUp() public {
        _deployDelegatedNativeOffers();
    }

    function testCurrentCollectionOfferRetainsDelegatedSignerAndExecutorAfterDeprecation() public {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(false, true, true);
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedNativeOffer(p);
        require(
            registry.moduleRecord(address(artistNativeOffers)).status
                == ModuleRegistryStatus.DEPRECATED,
            "no reactivation required"
        );
    }

    function testCurrentSelectedOfferRetainsDelegatedSignerAndExecutorThroughActualGate() public {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(true, true, true);
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedNativeOffer(p);
    }

    function testCurrentRevokedGrantRestoresExactDelegatedSafeEnvelopeAndBothOriginalProofs()
        public
    {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(true, true, true);
        bytes32 exact = keccak256(p.envelope);
        uint256 buyerNonce = joinedBuyer.nonce();
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        _revokeDelegatedNativeOffer();
        _delegatedNativeFailure(
            p,
            abi.encodeWithSelector(
                StreamNativeAuctionDelegation.DelegationReadFailed.selector,
                address(nativeOfferDelegates)
            )
        );
        _grantDelegatedNativeOffer(p.program);
        require(
            joinedBuyer.nonce() == buyerNonce + 2 && p.executorSafe.nonce() == p.executorNonce
                && keccak256(p.envelope) == exact,
            "buyer grant repair leaves distinct executor's exact original envelope untouched"
        );
        _completeDelegatedNativeOffer(p);
    }

    function testCurrentIncidentBlocksOriginalOfferAndDelayedDeprecationRetriesExactSafe() public {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(true, true, true);
        bytes32 exact = keccak256(p.envelope);
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.INCIDENT_REVOKED);
        _delegatedNativeFailure(
            p,
            abi.encodeWithSelector(
                StreamPreparedNativeSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(artistNativeOffers)
            )
        );
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        require(keccak256(p.envelope) == exact, "repair preserves original signed transaction");
        _completeDelegatedNativeOffer(p);
    }

    function testCurrentDirectBuyerClosesOriginalDeprecatedOfferWhileNewRegistrationIsRefused()
        public
    {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(false, false, false);
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        _rejectNewDelegatedNativeOffer(p);
        _completeDelegatedNativeOffer(p);
    }

    function testCurrentDirectBuyerRefreshesOnlyEnvelopeAfterDelegatedSignerGrantRepair() public {
        DelegatedNativePlan memory p = _armDelegatedNativeOffer(false, true, false);
        bytes32 commercial = keccak256(p.input);
        bytes32 original = keccak256(p.envelope);
        _delegatedNativeStatus(address(artistNativeOffers), ModuleRegistryStatus.DEPRECATED);
        _revokeDelegatedNativeOffer();
        require(joinedBuyer.nonce() == p.executorNonce + 1, "buyer revocation spends its own nonce");
        _refreshDelegatedNativePayerEnvelope(p);
        _delegatedNativeFailure(
            p,
            abi.encodeWithSelector(
                StreamNativeAuctionDelegation.DelegationReadFailed.selector,
                address(nativeOfferDelegates)
            )
        );
        _grantDelegatedNativeOffer(p.program);
        require(joinedBuyer.nonce() == p.executorNonce + 1, "buyer repair spends another own nonce");
        _refreshDelegatedNativePayerEnvelope(p);
        require(
            keccak256(p.input) == commercial && keccak256(p.envelope) != original,
            "all original offer proofs survive but payer signs the correctly refreshed transaction"
        );
        _completeDelegatedNativeOffer(p);
    }
}
