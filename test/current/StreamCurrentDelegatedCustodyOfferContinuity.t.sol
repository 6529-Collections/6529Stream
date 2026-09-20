// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDelegatedCustodyOfferContinuityFixture.sol";

/// @notice Actual-current secondary delegated offers retain original custody lifecycle admission.
/// @dev The buyer alone executes and funds; a delegate signs only its original offer. Native runtime
/// and transaction capacity remain separate evidence from these authored current-stack regressions.
contract StreamCurrentDelegatedCustodyOfferContinuityTest is
    CurrentDelegatedCustodyOfferContinuityFixture
{
    function setUp() public {
        _deployDelegatedCustodyOffers();
    }

    function testCurrentDeprecatedDelegatedCustodyOfferTransfersOriginalPaidTokenWithIndependentSafes()
        public
    {
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        _custodyDelegateCannotExecute(p);
        _custodyComplete(p);
        require(
            registry.moduleRecord(address(custodyOffers)).status == ModuleRegistryStatus.DEPRECATED,
            "no reactivation for original offer"
        );
    }

    function testCurrentDirectBuyerOfferClosesDeprecatedWhileNewRegistrationRemainsDenied() public {
        CustodyOfferPlan memory p = _armCustodyOffer(false);
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        _custodyRejectNew(p);
        _custodyComplete(p);
    }

    function testCurrentCustodyBuyerGrantRepairRefreshesOnlyItsSafeEnvelopeAndKeepsAllOriginalProofs()
        public
    {
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        bytes32 originalInput = keccak256(p.input);
        bytes32 originalEnvelope = keccak256(p.envelope);
        uint256 buyerNonce = joinedBuyer.nonce();
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        _custodyRevokeGrant();
        _custodyRebuild(p);
        _custodyFailure(
            p,
            abi.encodeWithSelector(
                CustodyDelegation.DelegationReadFailed.selector, address(custodyDelegates)
            )
        );
        bytes32 rejectedEnvelope = keccak256(p.envelope);
        _custodyGrant(p, true);
        _custodyRebuild(p);
        require(
            joinedBuyer.nonce() == buyerNonce + 2 && keccak256(p.input) == originalInput
                && keccak256(p.envelope) != originalEnvelope
                && keccak256(p.envelope) != rejectedEnvelope,
            "buyer grant writes require fresh transaction nonce but never new sale proofs"
        );
        _custodyComplete(p);
    }

    function testCurrentCustodyIncidentRepairRetriesIdenticalBuyerSafeAfterDelayedDeprecation()
        public
    {
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        bytes32 original = keccak256(p.envelope);
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.INCIDENT_REVOKED);
        _custodyFailure(
            p, abi.encodeWithSelector(CustodyPrivate.PrivateSaleModuleNotAdmitted.selector)
        );
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        require(
            keccak256(p.envelope) == original,
            "separate Governor repair preserves exact buyer transaction"
        );
        _custodyComplete(p);
    }

    function testCurrentCustodyDelegateCannotReplaceOwnerProofOrAllTokenGrantAndAllThreeDigestsRetry()
        public
    {
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        bytes32 originalInput = keccak256(p.input);
        bytes memory originalOwnerSignature = p.ownerSignature;
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        p.ownerSignature = _joinedProof(custodyDelegate, p.grantDigest);
        _custodyRebuild(p);
        _custodyFailure(
            p,
            abi.encodeWithSelector(
                CustodyPrivate.PrivateSaleAuthorityInvalid.selector, address(joinedCollector)
            )
        );
        p.ownerSignature = originalOwnerSignature;
        _custodyRevokeGrant();
        _custodyGrant(p, false);
        _custodyRebuild(p);
        _custodyFailure(
            p,
            abi.encodeWithSelector(
                CustodyDelegation.DelegationNotFound.selector,
                address(joinedBuyer),
                address(custodyDelegate)
            )
        );
        _custodyRevokeGrant();
        _custodyGrant(p, true);
        _custodyRebuild(p);
        require(
            keccak256(p.input) == originalInput,
            "original seller buyer and owner proof bytes restored exactly"
        );
        _custodyComplete(p);
    }

    function testCurrentEarnedCustodyProceedsAndBuyerExcessExitDuringIncidentWithoutLiveGrant()
        public
    {
        CustodyOfferPlan memory p = _armCustodyOffer(true);
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.DEPRECATED);
        _custodyComplete(p);
        _custodyStatus(address(custodyOffers), ModuleRegistryStatus.INCIDENT_REVOKED);
        _custodyRevokeGrant();
        bytes memory input = abi.encodeCall(
            custodyOffers.claimRefundFor,
            (p.id, address(joinedBuyer), CustodyClaims.DelegationWitness(false, 0))
        );
        vm.prank(address(custodyDelegate));
        (bool ok, bytes memory out) = address(custodyOffers).call(input);
        require(
            !ok
                && keccak256(out)
                    == keccak256(
                        abi.encodeWithSelector(
                            CustodyDelegation.DelegationReadFailed.selector,
                            address(custodyDelegates)
                        )
                    ),
            "revoked delegate cannot trigger buyer claim"
        );
        _custodySafeFailure(custodyDelegate, _custodyEnvelope(custodyDelegate, 0, input));
        _custodyClaim(p, joinedCollector, CUSTODY_OFFER_PRICE - CUSTODY_OFFER_ROYALTY);
        _custodyClaim(p, joinedBuyer, CUSTODY_OFFER_EXCESS);
        require(
            custodyOffers.totalLiabilities() == 0 && address(custodyOffers).balance == 0
                && core.ownerOf(1) == address(joinedBuyer)
                && registry.moduleRecord(address(custodyOffers)).status
                    == ModuleRegistryStatus.INCIDENT_REVOKED,
            "earned original claims neither reactivate sale nor repeat custody or royalty"
        );
    }
}
