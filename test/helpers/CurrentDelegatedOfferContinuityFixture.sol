// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentArtistERC20OfferFixture.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamERC20OfferMint.sol";

/// @dev Support for retained primary-offer delegation cases in the actual current graph.
/// No test cases or production exceptions are introduced here. Commercial calls use original
/// threshold Safes. Caller impersonation is confined to separately labelled read-only controls
/// that expose the Manager and selected gate behind the carrier's earlier refusal.
abstract contract CurrentDelegatedERC20OfferContinuityFixture is CurrentArtistERC20OfferFixture {
    bytes32 private constant DELEGATED_CONTINUITY_REASON =
        keccak256("current delegated offer continuity");

    struct DelegatedERC20Plan {
        ERC20OfferPlan program;
        OfferE20.Acceptance acceptance;
        PrimaryE20.ERC20SettlementCandidate candidate;
        PrimaryE20.PaymentIntent intent;
        IStreamMintManager.MintBatch batch;
        StreamERC20OfferMintTypes.GateData transcript;
        OfficialSafe executorSafe;
        uint256 executorNonce;
        bytes paymentInput;
        bytes envelope;
    }

    /// @dev Call _deployArtistERC20Offers once before arming a plan. The original offer is
    /// registered and Artist-consented while ACTIVE; token approval is not held sale revenue.
    function _armDelegatedERC20Offer(bool selected, bool delegatedSigner, bool delegatedExecutor)
        internal
        returns (DelegatedERC20Plan memory p)
    {
        (p.program, p.acceptance) = _openArtistERC20Offer(selected, true);
        if (delegatedSigner || delegatedExecutor) _grantDelegatedERC20Offer(p.program);
        p.executorSafe = delegatedExecutor ? joinedCollaborator : joinedBuyer;
        p.acceptance.authorization.executor = address(p.executorSafe);
        p.acceptance.sellerProof.signature =
            _joinedProof(joinedCollector, _erc20SellerDigest(p.acceptance.authorization));
        if (delegatedSigner) {
            p.acceptance.buyerProof = OfferPrivate.Signature(
                address(joinedCollaborator),
                2,
                _joinedProof(joinedCollaborator, _erc20BuyerDigest(p.acceptance.offer))
            );
        }
        p.candidate = artistOffers.previewExecution(p.acceptance);
        (p.batch, p.transcript) = _delegatedERC20Transcript(p.program, p.acceptance);
        _assertDelegatedERC20Transcript(p);
        if (delegatedExecutor) {
            p.intent = _erc20Intent(p.program);
            bytes memory proof = _joinedProof(joinedBuyer, _erc20IntentDigest(p.intent));
            p.paymentInput = abi.encodeCall(
                offerPayment.settleERC20PrimarySaleWithIntent,
                (p.candidate, p.intent, proof, abi.encode(p.acceptance))
            );
        } else {
            p.paymentInput = abi.encodeCall(
                offerPayment.settleERC20PrimarySaleByPayer, (p.candidate, abi.encode(p.acceptance))
            );
        }
        p.executorNonce = p.executorSafe.nonce();
        p.envelope = _erc20SafePayload(p.executorSafe, p.paymentInput);
        _assertDelegatedERC20Unused(p);
    }

    function _grantDelegatedERC20Offer(ERC20OfferPlan memory p) internal {
        _joinedSafe(
            joinedBuyer,
            address(offerDelegates),
            0,
            abi.encodeCall(
                offerDelegates.registerDelegationAddress,
                (
                    address(core),
                    address(joinedCollaborator),
                    uint256(p.config.endsAt),
                    uint256(2),
                    true,
                    uint256(0)
                )
            )
        );
        bytes32 key = keccak256(
            abi.encodePacked(
                address(joinedBuyer), address(core), address(joinedCollaborator), uint256(2)
            )
        );
        (
            address vault,
            address delegate,
            uint256 start,
            uint256 end,
            bool allTokens,
            uint256 tokenId
        ) = offerDelegates.globalDelegationHashes(key, 0);
        require(
            vault == address(joinedBuyer) && delegate == address(joinedCollaborator)
                && start <= block.timestamp && end == p.config.endsAt && end > block.timestamp
                && allTokens && tokenId == 0,
            "original NFTDelegation complete current Core-scoped row"
        );
    }

    function _revokeDelegatedERC20Offer() internal {
        _joinedSafe(
            joinedBuyer,
            address(offerDelegates),
            0,
            abi.encodeCall(
                offerDelegates.revokeDelegationAddress,
                (address(core), address(joinedCollaborator), uint256(2))
            )
        );
    }

    /// @dev Grant repair spends the payer Safe's transaction nonce. An exact original envelope
    /// survives only when a different delegated executor owns that envelope. For payer execution,
    /// explicitly sign a new transaction while retaining every commercial proof and input byte.
    function _refreshDelegatedERC20PayerEnvelope(DelegatedERC20Plan memory p) internal {
        require(address(p.executorSafe) == address(joinedBuyer), "payer envelope refresh only");
        p.executorNonce = joinedBuyer.nonce();
        p.envelope = _erc20SafePayload(joinedBuyer, p.paymentInput);
    }

    function _assertDelegatedERC20Unused(DelegatedERC20Plan memory p) internal view {
        _assertERC20OfferUnused(p.program, p.acceptance, p.candidate, p.intent.nonce);
        require(
            keccak256(abi.encode(artistOffers.saleLifecycleBinding(p.program.id)))
                    == keccak256(abi.encode(p.candidate.lifecycleBinding))
                && p.candidate.lifecycleBinding.paymentAdapter == address(offerPayment)
                && commerceFloor.firstSale(1).receiptHash == 0,
            "original lifecycle and payment remain bound without a floor receipt"
        );
    }

    function _delegatedERC20CarrierFailure(DelegatedERC20Plan memory p, bytes memory expected)
        internal
    {
        _delegatedERC20ReadFailure(
            address(artistOffers),
            abi.encodeCall(artistOffers.previewExecution, (p.acceptance)),
            expected
        );
        _assertDelegatedERC20Unused(p);
    }

    function _delegatedERC20ManagerFailure(DelegatedERC20Plan memory p, bytes memory expected)
        internal
    {
        bytes memory input = abi.encodeCall(
            IStreamERC20OfferMint.previewERC20OfferMintOperation, (p.batch, p.transcript)
        );
        // Read-only isolation of the second boundary; no mocked authorization or execution.
        vm.prank(address(artistOffers));
        _delegatedERC20ReadFailure(address(manager), input, expected);
        _assertDelegatedERC20Unused(p);
    }

    function _delegatedERC20GateFailure(DelegatedERC20Plan memory p, bytes memory expected)
        internal
    {
        require(address(p.program.gate) != address(0), "selected gate control only");
        bytes memory input = abi.encodeCall(
            p.program.gate.validateERC20OfferBatch,
            (address(manager), address(artistOffers), p.batch, p.transcript)
        );
        // Read-only isolation of the same signature worker under the real selected gate.
        vm.prank(address(manager));
        _delegatedERC20ReadFailure(address(p.program.gate), input, expected);
        _assertDelegatedERC20Unused(p);
    }

    function _delegatedERC20EnvelopeFailure(DelegatedERC20Plan memory p) internal {
        require(p.executorSafe.nonce() == p.executorNonce, "original transaction nonce intact");
        _erc20SafeFailure(p.executorSafe, p.envelope);
        _assertDelegatedERC20Unused(p);
    }

    function _completeDelegatedERC20Offer(DelegatedERC20Plan memory p) internal {
        require(p.executorSafe.nonce() == p.executorNonce, "original transaction nonce intact");
        require(
            keccak256(abi.encode(artistOffers.previewExecution(p.acceptance)))
                == keccak256(abi.encode(p.candidate)),
            "original complete candidate survives retained closeout"
        );
        _assertDelegatedERC20Transcript(p);
        _erc20SafeSuccess(p.executorSafe, p.envelope);
        _assertERC20OfferExecuted(p.program, p.acceptance, p.candidate);
        _assertWaivedCommerceReceipt(address(joinedRecorder), _erc20OfferKey(p.candidate));
        require(p.executorSafe.nonce() == p.executorNonce + 1, "one original Safe execution");
        if (address(p.executorSafe) != address(joinedBuyer)) {
            require(
                offerPayment.isPaymentIntentNonceUsed(address(joinedBuyer), p.intent.nonce),
                "distinct original payer intent consumed exactly at successful settlement"
            );
        }
    }

    function _delegatedERC20ReadFailure(address target, bytes memory input, bytes memory expected)
        private
        view
    {
        (bool ok, bytes memory reason) = target.staticcall(input);
        require(
            !ok && keccak256(reason) == keccak256(expected), "exact isolated delegation refusal"
        );
    }

    /// @dev Construct from the original independently signed terms, never by exposing a carrier
    /// internal. Cross-check the resulting transcript against its original real preview below.
    function _delegatedERC20Transcript(ERC20OfferPlan memory p, OfferE20.Acceptance memory q)
        private
        view
        returns (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d)
    {
        b.collectionId = p.config.collectionId;
        b.phaseId = p.config.phaseId;
        b.payer = p.config.buyer;
        b.authorizer = q.buyerProof.authorizer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = p.config.buyer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = p.config.buyer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = q.selection.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = q.selection.mintCommitment;
        b.expectedPolicyHash = p.config.mintPolicyHash;
        b.authorizationId = StreamMintTicketHash.authorizationId(_erc20BuyerDigest(q.offer));
        b.contextHash = p.leaf == 0
            ? _erc20SellerDigest(q.authorization)
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                    block.chainid,
                    address(artistOffers),
                    p.id,
                    q.selection.content.contentId
                )
            );
        d = StreamERC20OfferMintTypes.GateData(
            q.authorization.executor,
            q.selection.content,
            q.authorization,
            q.sellerProof,
            q.offer,
            q.buyerProof,
            q.signerDelegation,
            q.executorDelegation
        );
    }

    function _assertDelegatedERC20Transcript(DelegatedERC20Plan memory p) internal {
        // These are read controls for separately reaching Manager/gate with their actual callers.
        vm.prank(address(artistOffers));
        (bytes32 root, bytes32[] memory ids) = IStreamERC20OfferMint(address(manager))
            .previewERC20OfferMintOperation(p.batch, p.transcript);
        require(
            root == p.candidate.operationIdentityCommitment && ids.length == 1
                && ids[0] == p.candidate.operationId,
            "independent transcript reproduces original complete Manager operation identity"
        );
        if (address(p.program.gate) == address(0)) return;
        vm.prank(address(manager));
        IStreamMintGate.GateResult memory r = p.program.gate
            .validateERC20OfferBatch(address(manager), address(artistOffers), p.batch, p.transcript);
        bytes32 expectedHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_RESULT_V1"),
                p.program.gate.gateConfigHash(),
                _erc20SellerDigest(p.acceptance.authorization),
                _erc20BuyerDigest(p.acceptance.offer),
                p.batch.expectedPolicyHash,
                keccak256(abi.encode(p.transcript))
            )
        );
        require(
            r.authorizationId == p.batch.authorizationId
                && r.authorizer == p.acceptance.buyerProof.authorizer
                && r.authorizerKind == p.acceptance.buyerProof.kind && r.nullifiers.length == 0
                && r.maxQuantity == 1 && r.gateHash == expectedHash,
            "all selected gate result fields retain the actual house and original offer proofs"
        );
    }

    function _delegatedOfferStatus(address module, ModuleRegistryStatus status) internal {
        // Every retained lifecycle must predate the tightening timestamp strictly.
        vm.warp(block.timestamp + 1);
        _delegatedOfferStatusNow(module, status);
    }

    function _delegatedOfferStatusNow(address module, ModuleRegistryStatus status) internal {
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
                _delegatedOfferRecordFacts(before_, before_.status, before_.revision),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _delegatedOfferRecordFacts(before_, status, before_.revision + 1),
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
                (
                    module,
                    status,
                    DELEGATED_CONTINUITY_REASON,
                    "urn:stream:current:delegated-offer-continuity"
                )
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
                && _delegatedOfferRecordFacts(after_, status, after_.revision)
                    == _delegatedOfferRecordFacts(before_, status, before_.revision + 1)
                && chain == afterChain && count == afterCount,
            "actual Safe-governed status revision preserves original registration evidence"
        );
    }

    function _delegatedOfferRecordFacts(
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
