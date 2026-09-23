// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistERC20OfferFixture.sol";
import {
    StreamNativeAuctionDelegation
} from "../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import { StreamSaleConsent } from "../../smart-contracts/domains/mint/StreamSaleConsent.sol";
import "../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementAdmission.sol";
import "../../smart-contracts/domains/revenue/StreamSettlementAdmission.sol";

/// @notice Governed retirement retains original paid settlement identities across actual Safes.
/// @dev Source/ABI evidence only until the shared native campaign executes this host. The inherited
/// graph uses real current Artist, governance, Core, Manager, Ledger, Recorder, floor and entropy
/// Coordinator; only the ERC20 asset and external entropy provider are service fixtures. Successful
/// payment, bidding, consent and governance use original threshold Safes. Disclosed negative
/// controls impersonate existing Safe/adapter callers only to isolate exact admission errors; each
/// failure is also checked through the actual host and/or signed Safe envelope. No storage edits or
/// callback mocks are used. Stored consent timestamps are the real writer's observed block time.
contract StreamCurrentSettlementContinuityTest is CurrentArtistERC20OfferFixture {
    bytes32 private constant CONTINUITY_REASON = keccak256("current settlement continuity");

    function setUp() public {
        _deployArtistERC20Offers();
    }

    function testCurrentNativeFundedAuctionClosesThroughDeprecatedOriginalHouseAndRecorder()
        public
    {
        bytes32 id = _continuityAuction();
        bytes32 originalBinding = _recorderBinding();
        bytes32 originalAuction = keccak256(abi.encode(joinedHouse.auction(id)));
        _continuityStatus(address(joinedHouse), ModuleRegistryStatus.DEPRECATED);
        _continuityStatus(address(joinedRecorder), ModuleRegistryStatus.DEPRECATED);
        _nativePending(id, originalAuction, originalBinding);
        IStreamNativeEnglishAuction.Auction memory original = joinedHouse.auction(id);
        _rejectNewConsent(address(joinedHouse), original.saleId, original.configHash);
        bytes memory envelope = _continuityEnvelope(
            joinedCollector, address(joinedHouse), abi.encodeCall(joinedHouse.settle, (id))
        );
        vm.recordLogs();
        _erc20SafeSuccess(joinedCollector, envelope);
        _nativeCompleted(id, originalBinding, vm.getRecordedLogs());
        require(
            registry.moduleRecord(address(joinedHouse)).status == ModuleRegistryStatus.DEPRECATED
                && registry.moduleRecord(address(joinedRecorder)).status
                    == ModuleRegistryStatus.DEPRECATED,
            "original retained settlement requires no module reactivation"
        );
    }

    function testCurrentNativeRecorderIncidentRestoresExactSafeCloseoutAfterDelayedDeprecation()
        public
    {
        bytes32 id = _continuityAuction();
        bytes32 originalBinding = _recorderBinding();
        bytes32 originalAuction = keccak256(abi.encode(joinedHouse.auction(id)));
        bytes memory input = abi.encodeCall(joinedHouse.settle, (id));
        bytes memory envelope = _continuityEnvelope(joinedCollector, address(joinedHouse), input);
        uint256 collectorNonce = joinedCollector.nonce();
        uint256 collectorBalance = address(joinedCollector).balance;
        _continuityStatus(address(joinedRecorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        _continuityFailure(
            address(joinedHouse),
            input,
            abi.encodeWithSelector(
                StreamPreparedNativeSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(joinedRecorder)
            )
        );
        _erc20SafeFailure(joinedCollector, envelope);
        _nativePending(id, originalAuction, originalBinding);
        _continuityStatus(address(joinedRecorder), ModuleRegistryStatus.DEPRECATED);
        require(
            joinedCollector.nonce() == collectorNonce
                && address(joinedCollector).balance == collectorBalance,
            "independent Governor repair spends neither buyer nonce nor held bid"
        );
        vm.recordLogs();
        _erc20SafeSuccess(joinedCollector, envelope);
        _nativeCompleted(id, originalBinding, vm.getRecordedLogs());
        require(joinedCollector.nonce() == collectorNonce + 1, "identical original envelope once");
    }

    function testCurrentERC20DeprecatedSaleAndPaymentRejectNewRegistrationButCloseOriginalOffer()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(false, true);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        bytes memory envelope = _erc20SafePayload(
            joinedBuyer,
            abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
        );
        _continuityStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _rejectNewOffer(
            p,
            address(offerPayment),
            abi.encodeWithSelector(
                StreamSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(offerPayment)
            )
        );
        _continuityStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        _rejectNewOffer(
            p,
            address(artistOffers),
            abi.encodeWithSelector(
                StreamNativeAuctionDelegation.DelegationManifestMismatch.selector
            )
        );
        _rejectNewConsent(address(artistOffers), p.id, artistOffers.saleRecord(p.id).configHash);
        _assertERC20OfferUnused(p, q, c, bytes32(0));
        _originalOfferLifecycle(p, c);
        require(
            keccak256(abi.encode(artistOffers.previewExecution(q))) == keccak256(abi.encode(c)),
            "original candidate and all proof domains survive both retirements"
        );
        _erc20SafeSuccess(joinedBuyer, envelope);
        _assertERC20OfferExecuted(p, q, c);
        _assertWaivedCommerceReceipt(address(joinedRecorder), _erc20OfferKey(c));
        _originalOfferLifecycle(p, c);
    }

    function testCurrentERC20PaymentIncidentRestoresOriginalDelegatedSafeIntentAfterDelayedRepair()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(false, true);
        _erc20DelegateExecutor(p, q);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        PrimaryE20.PaymentIntent memory intent = _erc20Intent(p);
        bytes memory proof = _joinedProof(joinedBuyer, _erc20IntentDigest(intent));
        bytes memory envelope = _erc20SafePayload(
            joinedCollaborator,
            abi.encodeCall(
                offerPayment.settleERC20PrimarySaleWithIntent, (c, intent, proof, abi.encode(q))
            )
        );
        uint256 payerNonce = joinedBuyer.nonce();
        uint256 callerNonce = joinedCollaborator.nonce();
        _continuityStatus(address(offerPayment), ModuleRegistryStatus.INCIDENT_REVOKED);
        (bool ok, bytes memory reason) =
            address(artistOffers).staticcall(abi.encodeCall(artistOffers.previewExecution, (q)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamSettlementAdmission.SettlementModuleNotAdmitted.selector,
                            address(offerPayment)
                        )
                    ),
            "real sale preview identifies the original incident Payment"
        );
        _erc20SafeFailure(joinedCollaborator, envelope);
        _assertERC20OfferUnused(p, q, c, intent.nonce);
        _continuityStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        _originalOfferLifecycle(p, c);
        require(
            joinedBuyer.nonce() == payerNonce && joinedCollaborator.nonce() == callerNonce
                && keccak256(abi.encode(artistOffers.previewExecution(q)))
                    == keccak256(abi.encode(c)),
            "Governor repair preserves payer intent and executor's exact signed transaction"
        );
        _erc20SafeSuccess(joinedCollaborator, envelope);
        _assertERC20OfferExecuted(p, q, c);
        _assertWaivedCommerceReceipt(address(joinedRecorder), _erc20OfferKey(c));
        require(
            offerPayment.isPaymentIntentNonceUsed(address(joinedBuyer), intent.nonce)
                && joinedBuyer.nonce() == payerNonce
                && joinedCollaborator.nonce() == callerNonce + 1 && joinedCollector.nonce() == 0,
            "payer and seller SafeMessage proofs stay distinct from executor transaction nonce"
        );
    }

    function testCurrentAdmittedReplacementPaymentCannotInheritOriginalOfferOrSafeAllowance()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(false, true);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        bytes memory input =
            abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)));
        bytes memory originalEnvelope = _erc20SafePayload(joinedBuyer, input);
        uint256 payerNonce = joinedBuyer.nonce();
        StreamERC20PrimarySettlementAdapter replacement = _replacementPayment();
        _continuityStatus(address(offerPayment), ModuleRegistryStatus.DEPRECATED);
        require(
            address(replacement) != address(offerPayment)
                && address(replacement.primarySaleSettlement()) == address(joinedRecorder)
                && registry.moduleRecord(address(replacement)).status == ModuleRegistryStatus.ACTIVE
                && c.executor == address(joinedBuyer)
                && c.lifecycleBinding.paymentAdapter == address(offerPayment),
            "additional genuinely admitted Payment shares Recorder but not original lifecycle"
        );
        // Negative control only: matching the real executor isolates the wrong pinned adapter.
        vm.prank(address(joinedBuyer));
        _continuityFailure(
            address(replacement),
            input,
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.InvalidPaymentCandidate.selector
            )
        );
        _erc20SafeFailure(
            joinedBuyer, _continuityEnvelope(joinedBuyer, address(replacement), input)
        );
        _assertERC20OfferUnused(p, q, c, bytes32(0));
        _originalOfferLifecycle(p, c);
        require(
            replacement.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE
                && offerToken.allowance(address(joinedBuyer), address(replacement)) == 0
                && offerToken.balanceOf(address(replacement)) == 0
                && joinedBuyer.nonce() == payerNonce,
            "substitute neither inherits approval nor consumes original Safe or payment state"
        );
        _erc20SafeSuccess(joinedBuyer, originalEnvelope);
        _assertERC20OfferExecuted(p, q, c);
        _assertWaivedCommerceReceipt(address(joinedRecorder), _erc20OfferKey(c));
        require(
            offerToken.allowance(address(joinedBuyer), address(replacement)) == 0
                && offerToken.balanceOf(address(replacement)) == 0
                && replacement.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "retained original Payment alone settles after additional module admission"
        );
    }

    function testCurrentRetainedConsentRejectsEqualDeprecationTimeAndIncidentWithoutNewProof()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) =
            _openArtistERC20Offer(false, false);
        // Record consent after the sale's creation, in the same block as immediate deprecation.
        _erc20ArtistConsent(p);
        bytes32 configHash = artistOffers.saleRecord(p.id).configHash;
        (, bytes32 recordHash) = artists.isSaleConsented(1, p.id, configHash);
        OfferConsent.Record memory record = artists.saleConsentRecord(recordHash);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        require(
            record.signedAt == block.timestamp
                && c.lifecycleBinding.saleCreatedAt < record.signedAt,
            "real writer time isolates consent cutoff from older original sale lifecycle"
        );
        bytes memory envelope = _erc20SafePayload(
            joinedBuyer,
            abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
        );
        _continuityStatusNow(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        require(
            registry.moduleRecord(address(artistOffers)).statusUpdatedAt == record.signedAt,
            "consent does not strictly predate deprecation"
        );
        _rejectedRetainedConsent(p, q, c, envelope);
        _continuityStatus(address(artistOffers), ModuleRegistryStatus.ACTIVE);
        _continuityStatus(address(artistOffers), ModuleRegistryStatus.INCIDENT_REVOKED);
        _rejectedRetainedConsent(p, q, c, envelope);
        _rejectNewConsent(address(artistOffers), p.id, configHash);
        _continuityStatus(address(artistOffers), ModuleRegistryStatus.DEPRECATED);
        require(
            keccak256(abi.encode(artists.saleConsentRecord(recordHash)))
                == keccak256(abi.encode(record)),
            "governed repair preserves exact old consent"
        );
        _erc20SafeSuccess(joinedBuyer, envelope);
        _assertERC20OfferExecuted(p, q, c);
        _assertWaivedCommerceReceipt(address(joinedRecorder), _erc20OfferKey(c));
    }

    function _rejectedRetainedConsent(
        ERC20OfferPlan memory p,
        OfferE20.Acceptance memory q,
        PrimaryE20.ERC20SettlementCandidate memory c,
        bytes memory envelope
    ) private {
        bytes memory input = abi.encodeCall(
            artists.requireSaleConsent, (uint256(1), p.id, artistOffers.saleRecord(p.id).configHash)
        );
        // Caller-sensitive negative control isolates Artist's real retained adapter rejection.
        vm.prank(address(artistOffers));
        _continuityFailure(
            address(artists),
            input,
            abi.encodeWithSelector(OfferConsent.InvalidSaleAdapter.selector, address(artistOffers))
        );
        _continuityFailure(
            address(artistOffers),
            abi.encodeCall(artistOffers.previewExecution, (q)),
            abi.encodeWithSelector(
                StreamSaleConsent.SaleConsentNotSatisfied.selector,
                address(artists),
                uint256(1),
                p.id
            )
        );
        _erc20SafeFailure(joinedBuyer, envelope);
        _assertERC20OfferUnused(p, q, c, bytes32(0));
    }

    function _rejectNewConsent(address adapter, bytes32 saleId, bytes32 configHash) private {
        OfferConsent.Consent memory terms = OfferConsent.Consent(1, adapter, saleId, configHash);
        (, bytes32 previous) = artists.isSaleConsented(1, saleId, configHash);
        bytes32 originalRecord = keccak256(abi.encode(artists.saleConsentRecord(previous)));
        uint256 nonce = artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce;
        T.Authorization memory authorization =
            T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes memory input =
            abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (terms, authorization));
        // New evidence must remain ACTIVE-only even when an old matched record can close out.
        vm.prank(address(joinedArtist));
        _continuityFailure(
            address(artists),
            input,
            abi.encodeWithSelector(OfferConsent.InvalidSaleAdapter.selector, adapter)
        );
        _erc20SafeFailure(joinedArtist, _continuityEnvelope(joinedArtist, address(artists), input));
        (, bytes32 after_) = artists.isSaleConsented(1, saleId, configHash);
        require(
            after_ == previous
                && keccak256(abi.encode(artists.saleConsentRecord(previous))) == originalRecord
                && artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce == nonce,
            "denied new consent preserves original record, latest lookup and Artist nonce"
        );
    }

    function _continuityAuction() private returns (bytes32 id) {
        entropy.updateRevealFeePerToken(1, 100);
        this.joinedSnapshotSetup(0);
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
        id = this.joinedCreateAuction();
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        OfferConsent.Consent memory terms =
            OfferConsent.Consent(1, address(joinedHouse), a.saleId, a.configHash);
        T.Authorization memory authorization = T.Authorization(
            artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce,
            uint64(block.timestamp + 1 days),
            ""
        );
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (terms, authorization))
        );
        (bool approved, bytes32 consentHash) = artists.isSaleConsented(1, a.saleId, a.configHash);
        OfferConsent.Record memory consent = artists.saleConsentRecord(consentHash);
        require(
            artists.saleConsentScope(1) == 1 && approved && consent.signer == address(joinedArtist)
                && consent.artistId == fixtureArtistId
                && keccak256(abi.encode(consent.terms)) == keccak256(abi.encode(terms)),
            "actual Artist Safe operation16 admits original native sale before real bid"
        );
        _joinedBid(id);
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
    }

    function _recorderBinding() private view returns (bytes32) {
        (address recorder, bytes32 codeHash, uint64 boundAt, uint64 revision) =
            manager.preparedNativeRecorder();
        require(
            recorder == address(joinedRecorder) && codeHash == recorder.codehash && boundAt != 0
                && revision != 0,
            "actual Manager once-bound original Recorder"
        );
        return keccak256(abi.encode(recorder, codeHash, boundAt, revision));
    }

    function _nativePending(bytes32 id, bytes32 originalAuction, bytes32 originalBinding)
        private
        view
    {
        StreamSaleTemplate.Selection memory selected = _joinedSelection();
        require(
            keccak256(abi.encode(joinedHouse.auction(id))) == originalAuction
                && _recorderBinding() == originalBinding && joinedHouse.auction(id).status == 1
                && joinedHouse.auction(id).settlementKey == 0
                && joinedHouse.totalLiveBidDeposits() == JOINED_PRICE + 100
                && joinedHouse.totalBuyerLiabilities() == JOINED_PRICE + 100
                && address(joinedHouse).balance == JOINED_PRICE + 100,
            "entire original auction, winner, held price and reveal fee remain pending"
        );
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 0
                && entropy.revealFeeEscrow(1) == 0
                && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0
                && !factory.profileExists(selected.profileId) && selected.wallet.code.length == 0
                && commerceFloor.firstSale(1).receiptHash == 0,
            "no mint, profile, official receipt, fee escrow or conservation first sale was consumed"
        );
    }

    function _nativeCompleted(bytes32 id, bytes32 originalBinding, Vm.Log[] memory logs)
        private
        view
    {
        _joinedReceipt(id, logs);
        StreamSaleTemplate.Selection memory selected = _joinedSelection();
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        PrimaryE20.PrimarySettlementResult memory r =
            joinedRecorder.settlementResult(a.settlementKey);
        require(
            _recorderBinding() == originalBinding && a.status == 3 && a.tokenId == 1
                && core.ownerOf(1) == address(joinedCollector) && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1 && core.pendingPreparedMintTokenId() == 0
                && entropy.revealFeeEscrow(1) == 100 && joinedHouse.totalLiveBidDeposits() == 0
                && joinedHouse.totalBuyerLiabilities() == 0 && address(joinedHouse).balance == 0,
            "original prepared mint consumes held bid and reserves its real reveal fee once"
        );
        require(
            r.settlementKey == a.settlementKey && r.asset == address(0) && r.amount == JOINED_PRICE
                && r.profileId == selected.profileId && r.wallet == selected.wallet && r.escrowed
                && r.operationIdentityCommitment == royalties.royaltySnapshot(1).operationRoot
                && joinedRecorder.settlementConsumed(a.settlementKey)
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE
                && revenueEscrow.totalOwed(address(0)) == JOINED_PRICE
                && address(revenueEscrow).balance == JOINED_PRICE
                && factory.profileExists(selected.profileId)
                && !factory.splitWalletExists(selected.profileId)
                && selected.wallet.code.length == 0,
            "genuinely earned original template revenue remains owed at undeployed wallet"
        );
        _assertWaivedCommerceReceipt(address(joinedRecorder), a.settlementKey, 1);
    }

    function _rejectNewOffer(ERC20OfferPlan memory p, address deniedModule, bytes memory expected)
        private
    {
        // ABI copy keeps the retained original configuration and signatures untouched.
        OfferE20.Configuration memory next =
            abi.decode(abi.encode(p.config), (OfferE20.Configuration));
        next.startsAt = uint64(block.timestamp + 1);
        next.endsAt = p.config.endsAt;
        next.offerDigest = keccak256(abi.encode("new prohibited offer", deniedModule, p.id));
        uint256 nonce = artistOffers.nextSaleNonce();
        bytes32 newId = artistOffers.saleIdFor(next.collectionId, next.phaseId, nonce);
        bytes memory input =
            abi.encodeCall(artistOffers.registerPrimaryOffer, (next, new bytes32[](0)));
        // Negative control only: actual owner identity isolates the module admission rejection.
        vm.prank(address(joinedCollaborator));
        _continuityFailure(address(artistOffers), input, expected);
        _erc20SafeFailure(
            joinedCollaborator,
            _continuityEnvelope(joinedCollaborator, address(artistOffers), input)
        );
        require(
            artistOffers.nextSaleNonce() == nonce && artistOffers.saleRecord(newId).status == 0
                && artistOffers.saleRecord(newId).configHash == 0
                && artistOffers.saleLifecycleBinding(newId).paymentAdapter == address(0),
            "forbidden new registration restores nonce, tentative configuration and lifecycle"
        );
    }

    function _originalOfferLifecycle(
        ERC20OfferPlan memory p,
        PrimaryE20.ERC20SettlementCandidate memory c
    ) private view {
        require(
            keccak256(abi.encode(artistOffers.saleLifecycleBinding(p.id)))
                    == keccak256(abi.encode(c.lifecycleBinding))
                && c.lifecycleBinding.paymentAdapter == address(offerPayment),
            "original immutable offer creation and Payment binding retained"
        );
    }

    function _replacementPayment() private returns (StreamERC20PrimarySettlementAdapter next) {
        next = StreamERC20PrimarySettlementAdapter(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter",
                abi.encode(joinedRecorder, address(0), bytes32(0))
            )
        );
        _assertDeployableProductionInstance(address(next));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(next),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            500000,
            address(next).codehash,
            DEPLOYMENT_HASH,
            OFFER_DELEGATION_BASE,
            "urn:stream:current:continuity:additional-payment"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
    }

    function _continuityEnvelope(OfficialSafe safe, address target, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes32 hash = safe.getTransactionHash(
            target, 0, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                target,
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, hash)
            )
        );
    }

    function _continuityFailure(address target, bytes memory input, bytes memory expected) private {
        (bool ok, bytes memory reason) = target.call(input);
        require(
            !ok && keccak256(reason) == keccak256(expected), "exact underlying continuity error"
        );
    }

    function _continuityStatus(address module, ModuleRegistryStatus status) private {
        // Every retained lifecycle must predate the tightening timestamp strictly.
        vm.warp(block.timestamp + 1);
        _continuityStatusNow(module, status);
    }

    function _continuityStatusNow(address module, ModuleRegistryStatus status) private {
        StreamModuleRecord memory before_ = registry.moduleRecord(module);
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        bytes32 scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                module
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _continuityRecordFacts(before_, before_.status, before_.revision),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _continuityRecordFacts(before_, status, before_.revision + 1),
                registry.moduleCount(),
                chain,
                count
            )
        );
        uint8 actionClass = uint8(status) > uint8(before_.status) ? 0 : 1;
        GovernanceActionRequest memory request = _governanceRequest(
            actionClass,
            address(registry),
            abi.encodeCall(
                registry.setModuleStatus,
                (module, status, CONTINUITY_REASON, "urn:stream:current:settlement-continuity")
            ),
            scope,
            oldHash,
            newHash
        );
        bytes32 id = _scheduleAsGovernor(request);
        if (actionClass == 1) {
            require(request.notBefore >= block.timestamp + 48 hours, "actual delayed loosening");
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                    id,
                    request.notBefore
                )
            );
            executor.executeGovernanceAction(id, request.callData);
        }
        vm.warp(request.notBefore);
        _executeAsGovernor(id, request.callData);
        StreamModuleRecord memory after_ = registry.moduleRecord(module);
        (bytes32 afterChain, uint64 afterCount) = registry.registrationChainHash();
        require(
            after_.status == status && after_.revision == before_.revision + 1
                && after_.registeredAt == before_.registeredAt
                && after_.statusUpdatedAt == block.timestamp
                && _continuityRecordFacts(after_, status, after_.revision)
                    == _continuityRecordFacts(before_, status, before_.revision + 1)
                && chain == afterChain && count == afterCount,
            "actual Safe-governed status revision preserves original registration evidence"
        );
    }

    function _continuityRecordFacts(
        StreamModuleRecord memory r,
        ModuleRegistryStatus status,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.runtimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }
}
