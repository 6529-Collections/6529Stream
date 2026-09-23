// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDelegatedOfferContinuityFixture.sol";
import {
    StreamNativeAuctionDelegation as OfferDelegation
} from "../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import "../../smart-contracts/domains/revenue/StreamSettlementAdmission.sol";

/// @notice Original actual-current primary offers retain delegated execution after retirement.
/// @dev These are atomic offers, not pre-funded token custody. Positive commercial/governance
/// operations use genuine threshold Safes; explicit caller-sensitive reads separately reach the
/// original Manager and selected gate. No storage, callback or registry read substitutions.
contract StreamCurrentDelegatedERC20OfferContinuityTest is
    CurrentDelegatedERC20OfferContinuityFixture
{
    function setUp() public {
        _deployArtistERC20Offers();
    }

    function testCurrentDelegatedERC20OpenOfferRetainsBothOriginalDeprecatedModules() public {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(false, true, true);
        _delegatedOfferStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _rejectNewDelegatedOffer(
            p,
            abi.encodeWithSelector(
                StreamSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(offerPayment)
            )
        );
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _rejectNewDelegatedOffer(
            p, abi.encodeWithSelector(OfferDelegation.DelegationManifestMismatch.selector)
        );
        _completeDelegatedERC20Offer(p);
        _assertOriginalModulesDeprecated();
    }

    function testCurrentDelegatedERC20SelectedOfferClosesThroughActualManagerAndGate() public {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _delegatedOfferStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _assertDelegatedERC20Transcript(p);
        _completeDelegatedERC20Offer(p);
        require(
            registry.moduleRecord(address(p.program.gate)).status == ModuleRegistryStatus.ACTIVE,
            "retained house keeps its original active selected gate"
        );
        _assertOriginalModulesDeprecated();
    }

    function testCurrentDelegatedERC20ExecutorOnlyRetainsDirectBuyerProof() public {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(false, false, true);
        require(
            p.acceptance.buyerProof.authorizer == address(joinedBuyer),
            "original direct buyer signer"
        );
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDelegatedERC20SignerOnlyRepairUsesFreshPayerEnvelopeAndOriginalProofs()
        public
    {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, false);
        bytes32 originalInput = keccak256(p.paymentInput);
        bytes32 originalEnvelope = keccak256(p.envelope);
        uint256 payerNonce = joinedBuyer.nonce();
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _revokeDelegatedERC20Offer();
        require(
            joinedBuyer.nonce() == payerNonce + 1, "payer grant transaction spends its own nonce"
        );
        _allDelegatedReadFailures(p, _missingGrant());
        // A fresh payer transaction is required even for the refusal after its own revocation.
        _refreshDelegatedERC20PayerEnvelope(p);
        bytes32 refusedEnvelope = keccak256(p.envelope);
        _delegatedERC20EnvelopeFailure(p);
        _grantDelegatedERC20Offer(p.program);
        _refreshDelegatedERC20PayerEnvelope(p);
        require(
            joinedBuyer.nonce() == payerNonce + 2 && keccak256(p.paymentInput) == originalInput
                && keccak256(p.envelope) != originalEnvelope
                && keccak256(p.envelope) != refusedEnvelope,
            "only payer transaction envelope changes; original commercial and settlement bytes retained"
        );
        _completeDelegatedERC20Offer(p);
        require(joinedBuyer.nonce() == payerNonce + 3, "grant revoke, repair and one settlement");
    }

    function testCurrentDelegatedERC20GrantRepairRetriesIdenticalExecutorSafeEnvelope() public {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        bytes32 originalEnvelope = keccak256(p.envelope);
        bytes32 originalInput = keccak256(p.paymentInput);
        uint256 payerNonce = joinedBuyer.nonce();
        uint256 callerNonce = joinedCollaborator.nonce();
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _revokeDelegatedERC20Offer();
        _allDelegatedReadFailures(p, _missingGrant());
        _delegatedERC20EnvelopeFailure(p);
        _grantDelegatedERC20Offer(p.program);
        require(
            joinedBuyer.nonce() == payerNonce + 2 && joinedCollaborator.nonce() == callerNonce
                && keccak256(p.envelope) == originalEnvelope
                && keccak256(p.paymentInput) == originalInput,
            "independent payer repair preserves executor envelope and original payer intent exactly"
        );
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDelegatedERC20IncidentHouseRepairsThroughDelayedDeprecatedLifecycle()
        public
    {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.INCIDENT_REVOKED);
        _allDelegatedReadFailures(p, _moduleNotAdmitted(address(artistOffers)));
        // Payment's ordinary lifecycle admission rejects before its callback. The separate read
        // controls above prove the carrier and worker refusals, not an invented inner Safe trace.
        _delegatedERC20EnvelopeFailure(p);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDelegatedERC20OriginalPaymentIncidentBlocksEachRetainedReadBoundary()
        public
    {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _delegatedOfferStatus(address(offerPayment), ModuleRegistryStatus.INCIDENT_REVOKED);
        _allDelegatedReadFailures(p, _moduleNotAdmitted(address(offerPayment)));
        _delegatedERC20EnvelopeFailure(p);
        _delegatedOfferStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDelegatedERC20EqualCreationDeprecationRefusesUntilGenuineLaterTransition()
        public
    {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(false, true, true);
        vm.warp(p.candidate.lifecycleBinding.saleCreatedAt);
        _delegatedOfferStatusNow(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        require(
            registry.moduleRecord(address(artistOffers)).statusUpdatedAt
                == p.candidate.lifecycleBinding.saleCreatedAt,
            "real equal timestamp boundary"
        );
        _allDelegatedReadFailures(p, _moduleNotAdmitted(address(artistOffers)));
        _delegatedERC20EnvelopeFailure(p);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.ACTIVE);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDelegatedERC20TokenSpecificGrantCannotReplaceOriginalAllTokenGrant()
        public
    {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, true, true);
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _revokeDelegatedERC20Offer();
        _joinedSafe(
            joinedBuyer,
            address(offerDelegates),
            0,
            abi.encodeCall(
                offerDelegates.registerDelegationAddress,
                (
                    address(core),
                    address(joinedCollaborator),
                    uint256(p.program.config.endsAt),
                    uint256(2),
                    false,
                    uint256(42)
                )
            )
        );
        _allDelegatedReadFailures(
            p,
            abi.encodeWithSelector(
                OfferDelegation.DelegationNotFound.selector,
                address(joinedBuyer),
                address(joinedCollaborator)
            )
        );
        _delegatedERC20EnvelopeFailure(p);
        _revokeDelegatedERC20Offer();
        _grantDelegatedERC20Offer(p.program);
        _completeDelegatedERC20Offer(p);
    }

    function testCurrentDirectERC20BuyerKeepsExistingRetainedOfferBypass() public {
        DelegatedERC20Plan memory p = _armDelegatedERC20Offer(true, false, false);
        require(
            p.acceptance.buyerProof.authorizer == address(joinedBuyer)
                && p.acceptance.authorization.executor == address(joinedBuyer),
            "both direct identities"
        );
        _delegatedOfferStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _delegatedOfferStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _completeDelegatedERC20Offer(p);
    }

    function _allDelegatedReadFailures(DelegatedERC20Plan memory p, bytes memory expected) private {
        _delegatedERC20CarrierFailure(p, expected);
        _delegatedERC20ManagerFailure(p, expected);
        if (address(p.program.gate) != address(0)) _delegatedERC20GateFailure(p, expected);
    }

    function _missingGrant() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            OfferDelegation.DelegationReadFailed.selector, address(offerDelegates)
        );
    }

    function _moduleNotAdmitted(address module) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            StreamSettlementAdmission.SettlementModuleNotAdmitted.selector, module
        );
    }

    function _assertOriginalModulesDeprecated() private view {
        require(
            registry.moduleRecord(address(artistOffers)).status == ModuleRegistryStatus.DEPRECATED
                && registry.moduleRecord(address(offerPayment)).status
                    == ModuleRegistryStatus.DEPRECATED,
            "closeout does not reactivate original modules"
        );
    }

    function _rejectNewDelegatedOffer(DelegatedERC20Plan memory p, bytes memory expected) private {
        OfferE20.Configuration memory next =
            abi.decode(abi.encode(p.program.config), (OfferE20.Configuration));
        next.startsAt = uint64(block.timestamp + 1);
        next.offerDigest =
            keccak256(abi.encode("prohibited new delegated offer", p.program.id, block.timestamp));
        uint256 nonce = artistOffers.nextSaleNonce();
        bytes32 newId = artistOffers.saleIdFor(next.collectionId, next.phaseId, nonce);
        bytes memory input =
            abi.encodeCall(artistOffers.registerPrimaryOffer, (next, new bytes32[](0)));
        // Caller-only negative isolation; actual Safe refusal follows without changing its nonce.
        vm.prank(address(joinedCollaborator));
        (bool ok, bytes memory reason) = address(artistOffers).call(input);
        require(
            !ok && keccak256(reason) == keccak256(expected), "new registration remains ACTIVE-only"
        );
        bytes32 hash = joinedCollaborator.getTransactionHash(
            address(artistOffers),
            0,
            input,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            joinedCollaborator.nonce()
        );
        bytes memory envelope = abi.encodeCall(
            joinedCollaborator.execTransaction,
            (
                address(artistOffers),
                uint256(0),
                input,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, hash)
            )
        );
        _erc20SafeFailure(joinedCollaborator, envelope);
        require(
            artistOffers.nextSaleNonce() == nonce && artistOffers.saleRecord(newId).status == 0
                && artistOffers.saleLifecycleBinding(newId).paymentAdapter == address(0),
            "new sale creates no lifecycle, status or consumed nonce"
        );
        _assertDelegatedERC20Unused(p);
    }
}
