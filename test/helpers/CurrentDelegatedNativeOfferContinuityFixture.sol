// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentArtistNativeOfferFixture.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import "../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamNativeRefundDelegatedClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";

/// @dev Actual current Artist/Governor/Core/Manager/Recorder/floor/Coordinator with original
/// NFTDelegation and threshold Safes. The external entropy provider remains the inherited service
/// fixture. Native offers have no independent pre-sale Manager preview: their selected gate reads
/// real active house intent and Manager admission. Only complete executions claim that coverage.
/// Negative carrier calls impersonate the real executor solely to expose the exact inner revert;
/// every commercial success and paired failure uses a complete threshold Safe envelope.
abstract contract CurrentDelegatedNativeOfferContinuityFixture is CurrentArtistNativeOfferFixture {
    uint256 internal constant NATIVE_CONTINUITY_VALUE = 1150;
    uint256 internal constant NATIVE_CONTINUITY_EXCESS = 50;
    bytes32 private constant NATIVE_CONTINUITY_REASON =
        keccak256("actual delegated native offer continuity");
    DelegationManagementContract internal nativeOfferDelegates;

    struct DelegatedNativePlan {
        ArtistNativeOfferPlan program;
        NativeOffer.Acceptance acceptance;
        OfficialSafe executorSafe;
        uint256 executorNonce;
        uint256 executorBalance;
        uint256 buyerBalance;
        bytes32 lifecycleHash;
        bytes input;
        bytes envelope;
    }

    function _deployDelegatedNativeOffers() internal {
        _deployJoinedCommerce();
        vm.deal(address(joinedCollaborator), 10 ether);
        vm.deal(address(this), 10 ether);
        nativeOfferDelegates = DelegationManagementContract(
            _artistArtifactCreate(
                "smart-contracts/integrations/delegation/NFTdelegation.sol:DelegationManagementContract",
                ""
            )
        );
        StreamNativeCuratedSaleBase.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = joinedRecorder;
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = IStreamArtistAttribution(address(artists));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600000, 50000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
        d.delegation = IStreamNativeRefundDelegatedClaims.DelegationDeployment(
            address(nativeOfferDelegates),
            2,
            NATIVE_CONTINUITY_REASON,
            IStreamGasParameterHost.GasParameterConfig(
                "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
            )
        );
        artistNativeOffers = StreamNativePrimaryOfferSale(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativePrimaryOfferSale.sol:StreamNativePrimaryOfferSale",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(artistNativeOffers));
        artistNativeOffers.transferOwnership(address(joinedCollaborator));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(artistNativeOffers),
            keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"),
            type(IStreamPreparedNativeSaleBinding).interfaceId,
            500000,
            address(artistNativeOffers).codehash,
            DEPLOYMENT_HASH,
            keccak256(artistNativeOffers.refundDelegationManifest()),
            "urn:stream:current:delegated-native-offer"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
        IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory c =
            artistNativeOffers.refundDelegationConfiguration();
        require(
            c.registry == address(nativeOfferDelegates)
                && c.registryCodeHash == address(nativeOfferDelegates).codehash
                && c.core == address(core) && c.moduleRegistry == address(registry)
                && c.moduleRegistryCodeHash == address(registry).codehash && c.usecase == 2
                && c.chainId == block.chainid
                && registry.moduleRecord(address(artistNativeOffers)).status
                    == ModuleRegistryStatus.ACTIVE
                && registry.moduleRecord(address(artistNativeOffers)).moduleManifestHash
                    == keccak256(artistNativeOffers.refundDelegationManifest())
                && artistNativeOffers.owner() == address(joinedCollaborator),
            "actual governed native offer and exact original delegation declaration"
        );
    }

    function _armDelegatedNativeOffer(bool selected, bool signer, bool delegatedExecutor)
        internal
        returns (DelegatedNativePlan memory p)
    {
        (p.program, p.acceptance) = _openArtistNativeOffer(selected, true);
        if (signer || delegatedExecutor) _grantDelegatedNativeOffer(p.program);
        p.executorSafe = delegatedExecutor ? joinedCollaborator : joinedBuyer;
        p.acceptance.authorization.executor = address(p.executorSafe);
        p.acceptance.sellerProof.signature =
            _joinedProof(joinedCollector, _nativeOfferSellerDigest(p.acceptance.authorization));
        if (signer) {
            p.acceptance.buyerProof = IStreamPrivateSaleAdapter.Signature(
                address(joinedCollaborator),
                2,
                _joinedProof(joinedCollaborator, _nativeOfferBuyerDigest(p.acceptance.offer))
            );
        }
        p.input = abi.encodeCall(artistNativeOffers.acceptPrimaryOffer, (p.acceptance));
        p.executorNonce = p.executorSafe.nonce();
        p.executorBalance = address(p.executorSafe).balance;
        p.buyerBalance = address(joinedBuyer).balance;
        p.lifecycleHash =
            keccak256(abi.encode(artistNativeOffers.preparedNativeSaleLifecycle(p.program.id)));
        p.envelope = _delegatedNativeEnvelope(
            p.executorSafe, address(artistNativeOffers), NATIVE_CONTINUITY_VALUE, p.input
        );
        _delegatedNativeUnused(p);
    }

    function _grantDelegatedNativeOffer(ArtistNativeOfferPlan memory p) internal {
        _joinedSafe(
            joinedBuyer,
            address(nativeOfferDelegates),
            0,
            abi.encodeCall(
                nativeOfferDelegates.registerDelegationAddress,
                (
                    address(core),
                    address(joinedCollaborator),
                    uint256(p.config.sale.endsAt),
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
            uint256 token
        ) = nativeOfferDelegates.globalDelegationHashes(key, 0);
        require(
            vault == address(joinedBuyer) && delegate == address(joinedCollaborator)
                && start <= block.timestamp && end == p.config.sale.endsAt && end > block.timestamp
                && allTokens && token == 0,
            "actual complete live Core-scoped grant at the original witness index"
        );
    }

    function _revokeDelegatedNativeOffer() internal {
        _joinedSafe(
            joinedBuyer,
            address(nativeOfferDelegates),
            0,
            abi.encodeCall(
                nativeOfferDelegates.revokeDelegationAddress,
                (address(core), address(joinedCollaborator), uint256(2))
            )
        );
    }

    /// @dev Buyer grant changes spend buyer Safe transaction nonces. Only buyer-owned envelopes
    /// need explicit refresh; the original commercial input and signatures remain unchanged.
    function _refreshDelegatedNativePayerEnvelope(DelegatedNativePlan memory p) internal {
        require(address(p.executorSafe) == address(joinedBuyer), "buyer envelope only");
        p.executorNonce = joinedBuyer.nonce();
        p.envelope = _delegatedNativeEnvelope(
            joinedBuyer, address(artistNativeOffers), NATIVE_CONTINUITY_VALUE, p.input
        );
    }

    function _delegatedNativeUnused(DelegatedNativePlan memory p) internal view {
        _nativeOfferUnused(p.program, p.acceptance);
        require(
            keccak256(abi.encode(artistNativeOffers.preparedNativeSaleLifecycle(p.program.id)))
                    == p.lifecycleHash && commerceFloor.firstSale(1).receiptHash == 0
                && keccak256(p.input)
                    == keccak256(
                        abi.encodeCall(artistNativeOffers.acceptPrimaryOffer, (p.acceptance))
                    ),
            "original lifecycle and complete commercial bytes retained without floor evidence"
        );
    }

    function _delegatedNativeFailure(DelegatedNativePlan memory p, bytes memory expected) internal {
        // The production carrier writes before checking delegation, so STATICCALL is not a
        // supported refusal probe. This real call must revert every tentative effect.
        vm.prank(address(p.executorSafe));
        (bool ok, bytes memory reason) =
            address(artistNativeOffers).call{ value: NATIVE_CONTINUITY_VALUE }(p.input);
        require(!ok && keccak256(reason) == keccak256(expected), "exact native carrier refusal");
        _delegatedNativeUnused(p);
        require(p.executorSafe.nonce() == p.executorNonce, "original executor transaction intact");
        uint256 balance = address(p.executorSafe).balance;
        (ok, reason) = address(p.executorSafe).call(p.envelope);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && p.executorSafe.nonce() == p.executorNonce
                && address(p.executorSafe).balance == balance,
            "same complete native Safe transaction rolls back its nonce and funds"
        );
        _delegatedNativeUnused(p);
    }

    function _completeDelegatedNativeOffer(DelegatedNativePlan memory p) internal {
        _delegatedNativeUnused(p);
        require(p.executorSafe.nonce() == p.executorNonce, "original executor nonce intact");
        vm.recordLogs();
        (bool ok, bytes memory result) = address(p.executorSafe).call(p.envelope);
        require(ok && abi.decode(result, (bool)), "actual threshold native closeout succeeds");
        _delegatedNativeReceipt(p.program, p.acceptance, vm.getRecordedLogs(), false);
        require(
            p.executorSafe.nonce() == p.executorNonce + 1
                && address(p.executorSafe).balance == p.executorBalance - NATIVE_CONTINUITY_VALUE
                && artistNativeOffers.refundableBalance(p.program.id, address(joinedBuyer))
                    == NATIVE_CONTINUITY_EXCESS
                && artistNativeOffers.totalBuyerLiabilities() == NATIVE_CONTINUITY_EXCESS
                && address(artistNativeOffers).balance == NATIVE_CONTINUITY_EXCESS
                && keccak256(
                    abi.encode(artistNativeOffers.preparedNativeSaleLifecycle(p.program.id))
                ) == p.lifecycleHash,
            "one original executor funds price plus reveal fee and buyer-only excess"
        );
        if (address(p.executorSafe) != address(joinedBuyer)) {
            require(
                address(joinedBuyer).balance == p.buyerBalance
                    && artistNativeOffers.refundableBalance(p.program.id, address(p.executorSafe))
                        == 0,
                "delegated funder does not acquire buyer credit or buyer ownership"
            );
        }
        bytes32 purchase = artistNativeOffers.purchaseIdFor(p.program.id, address(joinedBuyer), 1);
        _assertWaivedCommerceReceipt(
            address(joinedRecorder), artistNativeOffers.executionRecord(purchase).settlementKey, 1
        );
    }

    function _rejectNewDelegatedNativeOffer(DelegatedNativePlan memory p) internal {
        NativeOffer.Configuration memory next =
            abi.decode(abi.encode(p.program.config), (NativeOffer.Configuration));
        next.sale.startsAt = uint64(block.timestamp + 1);
        next.offerDigest = keccak256(abi.encode("new retired native offer", p.program.id));
        uint256 nonce = artistNativeOffers.nextSaleNonce();
        bytes32 newId = artistNativeOffers.saleIdFor(6, 1, next.sale.phaseId, nonce);
        bytes memory input =
            abi.encodeCall(artistNativeOffers.registerPrimaryOffer, (next, new bytes32[](0)));
        vm.prank(address(joinedCollaborator));
        (bool ok, bytes memory reason) = address(artistNativeOffers).call(input);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamNativeAuctionDelegation.DelegationManifestMismatch.selector
                        )
                    ),
            "new native registration retains ACTIVE-only original manifest admission"
        );
        bytes memory envelope =
            _delegatedNativeEnvelope(joinedCollaborator, address(artistNativeOffers), 0, input);
        uint256 ownerNonce = joinedCollaborator.nonce();
        (ok, reason) = address(joinedCollaborator).call(envelope);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollaborator.nonce() == ownerNonce
                && artistNativeOffers.nextSaleNonce() == nonce
                && artistNativeOffers.saleRecord(newId).configHash == 0,
            "real owner Safe cannot consume a new registration or nonce after deprecation"
        );
        _delegatedNativeUnused(p);
    }

    function _delegatedNativeEnvelope(
        OfficialSafe safe,
        address target,
        uint256 value,
        bytes memory input
    ) private returns (bytes memory) {
        bytes32 hash = safe.getTransactionHash(
            target, value, input, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                target,
                value,
                input,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, hash)
            )
        );
    }

    function _delegatedNativeIntent(ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q)
        private
        view
        returns (NativeOfferPrepared.Intent memory i)
    {
        i = _nativeOfferIntent(p, q);
        i.executor = q.authorization.executor;
    }

    function _delegatedNativeContentContext(ArtistNativeOfferPlan memory p)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(artistNativeOffers),
                p.id,
                p.config.contentId
            )
        );
    }

    // The existing full receipt oracle is retained below with actual executor/authorizer fields.

    function _delegatedNativeReceipt(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        Vm.Log[] memory logs,
        bool escrowed
    ) internal view returns (ArtistNativeOfferReceipt memory r) {
        bytes32 purchase = artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1);
        r.execution = artistNativeOffers.executionRecord(purchase);
        bytes32 key = r.execution.settlementKey;
        uint256 records;
        uint256 contents;
        uint256 revenues;
        uint256 accepted;
        uint256 sellerConsumed;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter == address(artistNativeOffers) && logs[n].topics.length == 3) {
                if (
                    logs[n].topics[0]
                        == keccak256("SaleAuthorizationConsumed(uint16,bytes32,bytes32,address)")
                ) {
                    require(
                        logs[n].topics[1] == p.id
                            && logs[n].topics[2] == _nativeOfferSellerDigest(q.authorization)
                            && keccak256(logs[n].data)
                                == keccak256(abi.encode(uint16(1), address(joinedCollector))),
                        "original seller consumption receipt"
                    );
                    ++sellerConsumed;
                } else if (
                    logs[n].topics[0]
                        == keccak256(
                            "OfferAccepted(uint16,bytes32,address,bytes32,uint256,address)"
                        )
                ) {
                    require(
                        logs[n].topics[1] == p.id
                            && address(uint160(uint256(logs[n].topics[2]))) == address(joinedBuyer)
                            && keccak256(logs[n].data)
                                == keccak256(
                                    abi.encode(
                                        uint16(1),
                                        p.config.offerDigest,
                                        ARTIST_NATIVE_OFFER_PRICE,
                                        address(0)
                                    )
                                ),
                        "original buyer acceptance receipt"
                    );
                    ++accepted;
                }
            }
            if (logs[n].emitter != address(joinedRecorder) || logs[n].topics.length < 3) continue;
            if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
                    )
            ) {
                require(
                    logs[n].topics.length == 4 && logs[n].data.length == 1152
                        && logs[n].topics[1] == key
                        && logs[n].topics[2]
                            == StreamPreparedNativeSettlementHash.saleKey(
                                address(joinedRecorder), address(artistNativeOffers), p.id, p.nonce
                            ),
                    "original offer revenue event identity"
                );
                (r.facts, r.intent) = abi.decode(
                    logs[n].data, (NativeOfferPrepared.Facts, NativeOfferPrepared.Intent)
                );
                require(
                    logs[n].topics[3] == StreamPreparedNativeSettlementHash.factsHash(r.facts),
                    "original facts event hash"
                );
                ++revenues;
            } else if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
                    )
            ) {
                require(
                    logs[n].topics.length == 3 && logs[n].data.length == 352
                        && logs[n].topics[1] == key,
                    "offer content event shape"
                );
                r.content = abi.decode(logs[n].data, (NativeOfferContent.Facts));
                require(
                    logs[n].topics[2] == StreamPreparedNativeContentHash.factsHash(r.content),
                    "offer content event hash"
                );
                ++contents;
            } else if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferRecorded(uint16,address,bytes32,bytes32,bytes32,uint256,bytes32,bytes32)"
                    )
            ) {
                require(
                    logs[n].topics.length == 4
                        && address(uint160(uint256(logs[n].topics[1])))
                            == address(artistNativeOffers) && logs[n].topics[2] == purchase
                        && logs[n].topics[3] == key
                        && keccak256(logs[n].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    p.id,
                                    p.nonce,
                                    p.config.offerDigest,
                                    _nativeOfferSellerDigest(q.authorization)
                                )
                            ),
                    "original dual digest offer receipt"
                );
                ++records;
            }
        }
        require(
            records == 1 && contents == 1 && revenues == 1 && accepted == 1 && sellerConsumed == 1
                && key != 0,
            "one committed offer-specific receipt"
        );
        require(
            keccak256(abi.encode(r.intent)) == keccak256(abi.encode(_delegatedNativeIntent(p, q))),
            "full original prepared intent"
        );
        NativeOfferPrepared.Facts memory expected = NativeOfferPrepared.Facts(
            address(artistNativeOffers),
            address(manager),
            address(joinedRecorder),
            address(joinedRecorder).codehash,
            1,
            p.config.sale.phaseId,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PREPARED_NATIVE_OFFER_INTENT_V1"),
                    block.chainid,
                    address(artistNativeOffers),
                    address(joinedRecorder),
                    r.intent
                )
            ),
            r.execution.operationRoot,
            r.execution.operationId,
            1,
            1,
            address(joinedBuyer),
            address(artistNativeOffers),
            address(joinedBuyer),
            keccak256(q.selection.tokenData),
            q.selection.mintCommitment,
            p.config.sale.mintPolicyHash,
            p.config.sale.mintPolicyHash
        );
        require(
            keccak256(abi.encode(r.facts)) == keccak256(abi.encode(expected)),
            "all original prepared facts"
        );
        NativeOfferContent.Facts memory content;
        content.operationRoot = r.execution.operationRoot;
        content.tokenDataHash = keccak256(q.selection.tokenData);
        if (p.leaf != 0) {
            content.gate = address(p.gate);
            content.gateCodeHash = address(p.gate).codehash;
            content.gateConfigHash = p.gate.gateConfigHash();
            content.manifestRoot = p.leaf;
            content.manifestHash = keccak256(p.gate.manifestBytes());
            content.counterId = p.counter;
            content.contentId = p.config.contentId;
            content.contentLeaf = p.leaf;
            content.contextHash = _delegatedNativeContentContext(p);
        } else {
            content.contextHash = StreamPreparedNativeSettlementHash.mintContext(
                address(manager), address(artistNativeOffers), r.facts.intentHash
            );
        }
        require(
            keccak256(abi.encode(r.content)) == keccak256(abi.encode(content)),
            "full selected or collection facts without invented content identity"
        );
        _delegatedNativeResult(p, q, r, escrowed);
        require(
            r.execution.saleId == p.id && r.execution.buyer == address(joinedBuyer)
                && r.execution.recipient == address(joinedBuyer) && r.execution.purchaseNonce == 1
                && r.execution.authorizationId == _nativeOfferId(p.config.offerDigest)
                && r.execution.authorizationDigest == _nativeOfferSellerDigest(q.authorization)
                && r.execution.contentLeaf == p.leaf
                && r.execution.tokenDataHash == content.tokenDataHash
                && r.execution.mintCommitment == q.selection.mintCommitment
                && r.execution.price == ARTIST_NATIVE_OFFER_PRICE && r.execution.tokenId == 1
                && r.execution.operationRoot != 0 && r.execution.operationId != 0,
            "complete original purchase execution"
        );
        require(
            artistNativeOffers.digestConsumed(r.execution.authorizationDigest)
                && !artistNativeOffers.digestRevoked(r.execution.authorizationDigest)
                && !artistNativeOffers.digestConsumed(p.config.offerDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), r.execution.authorizationId)
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), _nativeOfferId(r.execution.authorizationDigest)
                ) && ledger.isManagerOperationRootUsed(address(manager), r.execution.operationRoot)
                && ledger.counterValue(_nativeOfferCounter(p)) == 1,
            "independent seller store and original buyer Ledger key"
        );
        require(
            joinedRecorder.preparedNativeFactsHash(key)
                    == StreamPreparedNativeSettlementHash.factsHash(r.facts)
                && joinedRecorder.preparedNativeContentHash(key)
                    == StreamPreparedNativeContentHash.factsHash(content)
                && joinedRecorder.settlementConsumed(key)
                && IStreamPreparedNativeOfferSettlement(address(joinedRecorder))
                    .preparedNativeOfferConsumed(address(artistNativeOffers), purchase)
                && !joinedRecorder.preparedNativeSaleConsumed(
                    joinedRecorder.preparedNativeSaleKey(address(artistNativeOffers), p.id, p.nonce)
                ),
            "original offer recorder lane and hashes"
        );
        require(
            core.ownerOf(1) == address(joinedBuyer) && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1 && core.lastAllocatedTokenId() == 1
                && core.collectionNextSerial(1) == 2 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists
                && keccak256(core.tokenData(1)) == content.tokenDataHash
                && manager.nextOperationNonce() == 1
                && artistNativeOffers.nextPurchaseNonce(p.id, address(joinedBuyer)) == 2
                && artistNativeOffers.saleRecord(p.id).status == 4
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                    == 0
                && IStreamPreparedNativeOfferMint(address(manager))
                .activePreparedNativeOfferContent()
                .operationRoot == 0 && manager.activePreparedNativeMint().operationRoot == 0,
            "one token and terminal sale with temporary prepared state cleared"
        );
        require(
            joinedRecorder.totalOfficialSettled(address(0)) == ARTIST_NATIVE_OFFER_PRICE
                && entropy.revealFeeEscrow(1) == 100
                && wallet.balance == (escrowed ? 0 : ARTIST_NATIVE_OFFER_PRICE)
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == (escrowed ? ARTIST_NATIVE_OFFER_PRICE : 0),
            "exact PROFILE price and separate actual reveal fee"
        );
    }

    function _delegatedNativeResult(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        ArtistNativeOfferReceipt memory r,
        bool escrowed
    ) private view {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(artistNativeOffers);
        c.executor = q.authorization.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            p.id,
            PRIMARY_REVENUE_CLASS,
            0,
            1,
            1,
            p.nonce,
            address(joinedBuyer),
            address(joinedCollaborator),
            address(joinedBuyer),
            ARTIST_NATIVE_OFFER_PRICE,
            p.config.sale.expectedPrimaryPolicyHash
        );
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            artistNativeOffers.preparedNativeSaleLifecycle(p.id);
        c.lifecycleBinding.saleCreatedAt = lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamPreparedNativeSettlementHash.executionId(r.facts, r.intent),
            1,
            1,
            _nativeOfferSellerDigest(q.authorization)
        );
        c.orchestrationOrder = 2;
        c.mintManager = address(manager);
        c.operationIdentityCommitment = r.facts.operationRoot;
        c.operationId = r.facts.operationId;
        c.currentPolicyHash = p.config.sale.mintPolicyHash;
        c.boundPolicyHash = p.config.sale.mintPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            profile,
            wallet,
            0,
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash,
            factory.profileEntriesHash(profile)
        );
        c.saleExecutionHash = r.intent.saleExecutionHash;
        NativeOfferPurchase.Purchase memory purchase = NativeOfferPurchase.Purchase(
            p.id,
            p.nonce,
            artistNativeOffers.saleRecord(p.id).configHash,
            artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1),
            address(joinedBuyer),
            1,
            _nativeOfferId(p.config.offerDigest),
            q.buyerProof.authorizer,
            q.buyerProof.kind,
            0,
            p.config.offerDigest
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_OFFER_CANDIDATE_V1"),
                        block.chainid,
                        address(joinedRecorder),
                        r.facts,
                        r.content,
                        r.intent,
                        purchase,
                        c
                    )
                ),
                StreamPrimarySettlementHash.settlementKey(
                    address(joinedRecorder),
                    address(artistNativeOffers),
                    c.executionBinding.executionId
                ),
                profile,
                wallet,
                address(0),
                ARTIST_NATIVE_OFFER_PRICE,
                q.authorization.executor,
                c.executionBinding.executionId,
                escrowed,
                r.facts.operationRoot,
                p.config.sale.mintPolicyHash,
                p.config.sale.mintPolicyHash
            );
        require(
            r.execution.settlementKey == expected.settlementKey
                && keccak256(abi.encode(joinedRecorder.settlementResult(expected.settlementKey)))
                    == keccak256(abi.encode(expected)),
            "all twelve offer result fields and complete original candidate"
        );
    }

    function _delegatedNativeStatus(address module, ModuleRegistryStatus status) internal {
        // Every retained lifecycle must predate the tightening timestamp strictly.
        vm.warp(block.timestamp + 1);
        _delegatedNativeStatusNow(module, status);
    }

    function _delegatedNativeStatusNow(address module, ModuleRegistryStatus status) internal {
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
                _delegatedNativeRecordFacts(before_, before_.status, before_.revision),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _delegatedNativeRecordFacts(before_, status, before_.revision + 1),
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
                    NATIVE_CONTINUITY_REASON,
                    "urn:stream:current:delegated-native-offer-continuity"
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
                && _delegatedNativeRecordFacts(after_, status, after_.revision)
                    == _delegatedNativeRecordFacts(before_, status, before_.revision + 1)
                && chain == afterChain && count == afterCount,
            "actual Safe-governed status revision preserves original registration evidence"
        );
    }

    function _delegatedNativeRecordFacts(
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
