// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeCuratedFixedPriceSale.sol";
import "../../smart-contracts/domains/mint/StreamNativeCuratedPrivateSale.sol";
import "../../smart-contracts/domains/mint/StreamNativeCuratedContentGate.sol";
import "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import "../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import {
    StreamArtistSaleTypes as SaleConsent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../smart-contracts/interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";

/// @dev External recipient fault only; all protocol contracts retain their original runtime.
contract CurrentCuratedPurchaseRecipient is IERC721Receiver {
    bool public accepting;

    function accept() external {
        accepting = true;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(accepting, "curated recipient rejects");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual Artist/Core/Manager/Ledger/recorder graph with separate curated sale products.
/// @dev Reuses original artifact construction and governance, not the typed curated fixture.
/// Artist, owner, seller, buyer and governor are distinct official Safes. Only the external
/// entropy service and explicitly rejecting delivery recipient are test boundaries.
abstract contract CurrentArtistCuratedPurchaseFixture is CurrentDynamicRoyaltyCommerceFixture {
    uint256 internal constant CURATED_PRICE = 1000;
    bytes32 internal constant CURATED_GATE_VERSION = keccak256("NATIVE_CURATED_PURCHASE_GATE_V1");
    StreamNativeCuratedFixedPriceSale internal artistFixed;
    StreamNativeCuratedPrivateSale internal artistPrivate;
    uint256 private purchasePlanNonce;

    struct PurchasePlan {
        StreamNativeCuratedSaleBase host;
        StreamNativeCuratedContentGate gate;
        Curated.Configuration config;
        Curated.SelectionWindows windows;
        bytes32 id;
        uint256 nonce;
        bytes32 counter;
        bytes32[2] leaves;
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    /// @dev Re-read after cheatcode-driven governance warps without an inlined timestamp cache.
    function curatedPurchaseTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _deployArtistCuratedPurchases() internal {
        _deployJoinedCommerce();
        StreamNativeCuratedSaleBase.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = joinedRecorder;
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = IStreamArtistAttribution(address(artists));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600_000, 50_000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200_000, 50_000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 100_000, 2
        );
        artistFixed = StreamNativeCuratedFixedPriceSale(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeCuratedFixedPriceSale.sol:StreamNativeCuratedFixedPriceSale",
                    abi.encode(d)
                ))
        );
        artistPrivate = StreamNativeCuratedPrivateSale(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeCuratedPrivateSale.sol:StreamNativeCuratedPrivateSale",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(artistFixed));
        _assertDeployableProductionInstance(address(artistPrivate));
        artistFixed.transferOwnership(address(joinedCollaborator));
        artistPrivate.transferOwnership(address(joinedCollaborator));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = _purchaseHostRegistration(address(artistFixed));
        records[1] = _purchaseHostRegistration(address(artistPrivate));
        _purchaseRegister(records);
        require(
            address(artistFixed) != address(artistPrivate)
                && address(artistFixed.primarySaleSettlement()) == address(joinedRecorder)
                && address(artistPrivate.primarySaleSettlement()) == address(joinedRecorder),
            "separate original products share the actual bound recorder"
        );
    }

    function _purchaseHostRegistration(address host)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            host,
            keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"),
            type(IStreamPreparedNativeSaleBinding).interfaceId,
            500_000,
            host.codehash,
            DEPLOYMENT_HASH,
            keccak256(abi.encode("actual Artist curated product", host)),
            "urn:stream:current:artist-curated-product"
        );
    }

    function _purchaseRegister(StreamModuleRegistration[] memory records) private {
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
        for (uint256 i; i < records.length; ++i) {
            StreamModuleRecord memory admitted = registry.moduleRecord(records[i].module);
            require(
                admitted.status == ModuleRegistryStatus.ACTIVE
                    && admitted.runtimeCodeHash == records[i].module.codehash,
                "actual Safe-governed admission"
            );
        }
    }

    function _purchasePlan(StreamNativeCuratedSaleBase host, uint8 kind, bool committed)
        internal
        returns (PurchasePlan memory p)
    {
        p.host = host;
        p.nonce = host.nextSaleNonce();
        p.config.phaseId = keccak256(abi.encode("actual Artist curated phase", ++purchasePlanNonce));
        p.id = host.saleIdFor(kind, 1, p.config.phaseId, p.nonce);
        p.counter = keccak256(abi.encode("actual content lifetime cap", p.id));
        StreamPreparedNativeContentTypes.Row[] memory rows =
            new StreamPreparedNativeContentTypes.Row[](2);
        for (uint256 i; i < 2; ++i) {
            rows[i] = StreamPreparedNativeContentTypes.Row(
                bytes32(i), keccak256(_purchaseArtwork(i)), "urn:stream:actual-curated-preview"
            );
            p.leaves[i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_LEAF_V1"),
                            block.chainid,
                            address(host),
                            p.id,
                            rows[i].contentId,
                            rows[i].tokenDataHash
                        )
                    )
                )
            );
        }
        p.gate = StreamNativeCuratedContentGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamNativeCuratedContentGate.sol:StreamNativeCuratedContentGate",
                abi.encode(
                    address(manager),
                    address(host),
                    p.id,
                    uint256(1),
                    p.config.phaseId,
                    p.counter,
                    rows
                )
            )
        );
        _assertDeployableProductionInstance(address(p.gate));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(p.gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            CURATED_GATE_VERSION,
            type(IStreamMintGate).interfaceId,
            800_000,
            address(p.gate).codehash,
            DEPLOYMENT_HASH,
            p.gate.gateConfigHash(),
            "urn:stream:current:artist-curated-manifest"
        );
        _purchaseRegister(records);
        bytes32 root = p.leaves[0] < p.leaves[1]
            ? keccak256(abi.encodePacked(p.leaves[0], p.leaves[1]))
            : keccak256(abi.encodePacked(p.leaves[1], p.leaves[0]));
        StreamPreparedNativeContentTypes.Publication memory publication = p.gate.publication();
        require(
            keccak256(abi.encode(publication))
                    == keccak256(
                        abi.encode(
                            StreamPreparedNativeContentTypes.Publication(
                                block.chainid,
                                address(manager),
                                address(host),
                                p.id,
                                1,
                                p.config.phaseId,
                                root,
                                keccak256(abi.encode(rows)),
                                p.counter
                            )
                        )
                    ) && p.gate.itemCount() == 2
                && keccak256(p.gate.manifestBytes()) == keccak256(abi.encode(rows)),
            "complete original content publication"
        );
        _configurePurchasePhase(p);
        uint64 starts = this.curatedPurchaseTime() + 1;
        p.windows = Curated.SelectionWindows(
            starts, starts + 1 hours, starts + 2 hours, starts + 1 days, starts + 2 days
        );
        p.config.collectionId = 1;
        p.config.price = CURATED_PRICE;
        p.config.poster = address(joinedCollaborator);
        p.config.startsAt = starts;
        p.config.endsAt = p.windows.revealClose;
        p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
        p.config.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        p.config.primaryPolicyMode = committed ? 1 : 0;
        p.config.contentManifestRoot = root;
    }

    function _configurePurchasePhase(PurchasePlan memory p) private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256(abi.encode("actual content cap1", p.id))
        );
        IStreamMintManager.MintGateConfig memory g = IStreamMintManager.MintGateConfig(
            address(p.gate),
            p.gate.gateConfigHash(),
            address(p.gate).codehash,
            keccak256(abi.encode(CURATED_GATE_VERSION, p.gate.gateConfigHash())),
            0,
            800_000
        );
        IStreamMintManager.MintPhaseConfig memory c = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("actual Artist content terms"),
            keccak256("actual Artist content metadata")
        );
        address[] memory enabled = new address[](0);
        _purchasePolicy(
            p.config.phaseId,
            manager.previewPhasePolicyHash(1, p.config.phaseId, c, g, ids, counters, enabled)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(manager.configurePhase, (1, p.config.phaseId, c, g, ids, counters))
        );
        enabled = new address[](1);
        enabled[0] = address(p.host);
        _purchasePolicy(
            p.config.phaseId,
            manager.previewPhasePolicyHash(1, p.config.phaseId, c, g, ids, counters, enabled)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(manager.setPhaseExecutor, (1, p.config.phaseId, address(p.host), true))
        );
        artists.requireMintConsent(
            1, p.config.phaseId, manager.phasePolicyHash(1, p.config.phaseId)
        );
    }

    function _purchaseAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            artists.artistAuthorizationState(fixtureArtistId, bytes32(0), 0).nextUnusedNonce,
            this.curatedPurchaseTime() + 1 days,
            ""
        );
    }

    function _purchasePolicy(bytes32 phase, bytes32 hash) private {
        T.PolicyConsent memory p = T.PolicyConsent(1, phase, hash);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordPolicyConsent, (p, _purchaseAuthorization()))
        );
    }

    function _purchaseConsent(PurchasePlan memory p) internal {
        bytes32 configHash = p.host.saleRecord(p.id).configHash;
        SaleConsent.Consent memory terms = SaleConsent.Consent(1, address(p.host), p.id, configHash);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent, (terms, _purchaseAuthorization())
            )
        );
        (bool consented, bytes32 hash) = artists.isSaleConsented(1, p.id, configHash);
        SaleConsent.Record memory r = artists.saleConsentRecord(hash);
        require(
            consented && r.artistId == fixtureArtistId && r.signer == address(joinedArtist)
                && r.terms.saleAdapter == address(p.host) && r.terms.saleId == p.id
                && r.terms.saleConfigHash == configHash,
            "actual operation16 binds original sale and Safe Artist"
        );
    }

    function _openFixedPurchase(bool committed, bool consent)
        internal
        returns (PurchasePlan memory p)
    {
        p = _purchasePlan(artistFixed, 0, committed);
        Curated.FixedConfiguration memory c;
        c.sale = p.config;
        c.mode = committed ? Curated.SelectionMode.COMMIT_REVEAL : Curated.SelectionMode.PUBLIC;
        c.differentiatedContent = committed;
        c.publicSelectionDisclosure = !committed;
        if (committed) c.windows = p.windows;
        _joinedSafe(
            joinedCollaborator,
            address(artistFixed),
            0,
            abi.encodeCall(artistFixed.registerCuratedFixedSale, (c))
        );
        require(
            artistFixed.saleRecord(p.id).configHash == artistFixed.fixedConfigurationHash(c)
                && artistFixed.saleRecord(p.id).saleNonce == p.nonce,
            "owner Safe registers original immutable sale"
        );
        if (consent) _purchaseConsent(p);
        vm.warp(p.config.startsAt);
    }

    function _openPrivatePurchase(uint256 index)
        internal
        returns (PurchasePlan memory p, Curated.Selection memory chosen)
    {
        p = _purchasePlan(artistPrivate, 5, false);
        _joinedSafe(
            joinedCollaborator,
            address(artistPrivate),
            0,
            abi.encodeCall(
                artistPrivate.configureCollectionSigner,
                (
                    uint256(1),
                    address(joinedCollector),
                    uint8(2),
                    keccak256("actual Safe seller evidence"),
                    true
                )
            )
        );
        Curated.CollectionSigner memory member =
            artistPrivate.collectionSigner(1, address(joinedCollector), 2);
        Curated.PrivateConfiguration memory c;
        c.sale = p.config;
        c.buyer = address(joinedBuyer);
        c.contentId = bytes32(index);
        c.tokenDataHash = keccak256(_purchaseArtwork(index));
        c.signer = address(joinedCollector);
        c.signerKind = 2;
        c.signerEvidenceHash = member.evidenceHash;
        c.signerRevision = member.revision;
        c.signerAuthority = member.authority;
        chosen = _purchaseSelection(p, index, address(joinedBuyer), 1);
        _joinedSafe(
            joinedCollaborator,
            address(artistPrivate),
            0,
            abi.encodeCall(artistPrivate.registerCuratedPrivateSale, (c, chosen.content.proof))
        );
        require(
            artistPrivate.saleRecord(p.id).configHash == artistPrivate.privateConfigurationHash(c),
            "original private config"
        );
        _purchaseConsent(p);
        vm.warp(p.config.startsAt);
    }

    function _purchaseArtwork(uint256 index) internal pure returns (bytes memory) {
        return index == 0 ? bytes("") : bytes("actual Artist selected work");
    }

    function _purchaseSelection(
        PurchasePlan memory p,
        uint256 index,
        address recipient,
        uint256 nonce
    ) internal pure returns (Curated.Selection memory s) {
        s.content.contentId = bytes32(index);
        s.tokenData = _purchaseArtwork(index);
        s.content.tokenDataHash = keccak256(s.tokenData);
        s.content.proof = new bytes32[](1);
        s.content.proof[0] = p.leaves[index == 0 ? 1 : 0];
        s.recipient = recipient;
        s.purchaseNonce = nonce;
        s.mintCommitment = keccak256(abi.encode("actual curated commitment", p.id, index));
    }

    function _purchaseCounter(PurchasePlan memory p, uint256 index)
        internal
        view
        returns (bytes32)
    {
        bytes32 context = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(p.host),
                p.id,
                bytes32(index)
            )
        );
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            p.config.phaseId,
            p.counter,
            address(joinedBuyer),
            address(joinedBuyer),
            address(p.host),
            address(0),
            context
        );
        return manager.previewCounterValueKey(1, p.config.phaseId, p.counter, subject);
    }

    function _purchaseSafePayload(address host, uint256 value, bytes memory data)
        internal
        returns (bytes memory)
    {
        bytes32 hash = joinedBuyer.getTransactionHash(
            host, value, data, 0, 0, 0, 0, address(0), address(0), joinedBuyer.nonce()
        );
        return abi.encodeCall(
            joinedBuyer.execTransaction,
            (
                host,
                value,
                data,
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

    function _purchaseFailed(bytes memory exact) internal {
        uint256 nonce = joinedBuyer.nonce();
        uint256 balance = address(joinedBuyer).balance;
        (bool ok, bytes memory reason) = address(joinedBuyer).call(exact);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedBuyer.nonce() == nonce && address(joinedBuyer).balance == balance,
            "failed signed Safe envelope rolls back"
        );
    }

    function _purchaseSucceeded(bytes memory exact) internal {
        uint256 nonce = joinedBuyer.nonce();
        (bool ok, bytes memory result) = address(joinedBuyer).call(exact);
        require(
            ok && abi.decode(result, (bool)) && joinedBuyer.nonce() == nonce + 1,
            "original signed Safe envelope succeeds"
        );
    }

    function _assertPurchaseExecution(PurchasePlan memory p, Curated.Selection memory chosen)
        internal
        view
        returns (Curated.ExecutionRecord memory e)
    {
        bytes32 purchase = p.host.purchaseIdFor(p.id, address(joinedBuyer), chosen.purchaseNonce);
        e = p.host.executionRecord(purchase);
        require(
            e.saleId == p.id && e.buyer == address(joinedBuyer) && e.recipient == chosen.recipient
                && e.purchaseNonce == chosen.purchaseNonce
                && e.contentLeaf == p.leaves[uint256(chosen.content.contentId)]
                && e.tokenDataHash == chosen.content.tokenDataHash
                && e.mintCommitment == chosen.mintCommitment
                && core.ownerOf(e.tokenId) == chosen.recipient
                && keccak256(core.tokenData(e.tokenId)) == e.tokenDataHash,
            "original buyer recipient work and token"
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory receipt =
            joinedRecorder.settlementResult(e.settlementKey);
        require(
            receipt.amount == CURATED_PRICE && receipt.wallet == wallet
                && receipt.profileId == profile && receipt.asset == address(0)
                && receipt.executor == address(joinedBuyer)
                && receipt.operationIdentityCommitment == e.operationRoot
                && receipt.candidateCommitment != 0 && receipt.settlementKey == e.settlementKey
                && receipt.executionId != 0 && !receipt.escrowed
                && receipt.currentPolicyHash == p.config.mintPolicyHash
                && receipt.boundPolicyHash == p.config.mintPolicyHash
                && ledger.isManagerOperationRootUsed(address(manager), e.operationRoot)
                && ledger.isManagerAuthorizationUsed(address(manager), e.authorizationId)
                && ledger.counterValue(_purchaseCounter(p, uint256(chosen.content.contentId))) == 1,
            "real official receipt joins the exact Ledger root authorization and content debit"
        );
        require(
            IStreamPreparedNativeContentPurchaseSettlement(address(joinedRecorder))
                .preparedNativeContentPurchaseConsumed(address(p.host), purchase)
            && !joinedRecorder.preparedNativeSaleConsumed(
                joinedRecorder.preparedNativeSaleKey(address(p.host), p.id, p.nonce)
            ) && joinedRecorder.preparedNativeContentHash(e.settlementKey) != 0
            && joinedRecorder.preparedNativeFactsHash(e.settlementKey) != 0
            && manager.preparedNativeContentAdmission() == 0
            && manager.activePreparedNativeContent().operationRoot == 0
            && core.pendingPreparedMintTokenId() == 0,
            "per-purchase records preserve creation identity and clear temporary admission"
        );
    }

    function _assertPurchaseBlank(PurchasePlan memory p, Curated.Selection memory chosen)
        internal
        view
    {
        bytes32 purchase = p.host.purchaseIdFor(p.id, address(joinedBuyer), chosen.purchaseNonce);
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionNextSerial(1) == 1 && core.collectionMintedEver(1) == 0
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists
                && core.tokenData(1).length == 0 && manager.nextOperationNonce() == 0
                && manager.preparedNativeContentAdmission() == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && ledger.counterValue(_purchaseCounter(p, uint256(chosen.content.contentId))) == 0
                && p.host.executionRecord(purchase).operationRoot == 0
                && !IStreamPreparedNativeContentPurchaseSettlement(address(joinedRecorder))
                    .preparedNativeContentPurchaseConsumed(address(p.host), purchase)
                && wallet.balance == 0 && revenueEscrow.totalOwed(address(0)) == 0
                && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && entropy.revealFeeEscrow(1) == 0,
            "no token operation payment fee or purchase receipt survives"
        );
    }

    function _privatePurchaseAuthorization(PurchasePlan memory p, Curated.Selection memory chosen)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        address[] memory recipients = new address[](1);
        recipients[0] = address(p.host);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = chosen.recipient;
        bytes[] memory data = new bytes[](1);
        data[0] = chosen.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = chosen.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(p.host);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.phaseId;
        a.saleId = p.id;
        a.saleKind = 5;
        a.revenueClass = PRIMARY_REVENUE_CLASS;
        a.expectedPrimaryPolicyHash = p.config.expectedPrimaryPolicyHash;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = address(joinedBuyer);
        a.executor = address(joinedBuyer);
        a.unitPrice = CURATED_PRICE;
        a.quantity = 1;
        a.contentSelectionHash = p.leaves[uint256(chosen.content.contentId)];
        a.policyHash = p.config.mintPolicyHash;
        a.nonce = keccak256(abi.encode("actual Safe private original nonce", p.id));
        a.deadline = p.config.endsAt;
    }

    function _privatePurchaseDigest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(artistPrivate)
            )
        );
        bytes32 typeHash = keccak256(
            "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
        );
        bytes32 digest =
            keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
        require(
            digest
                == StreamPrivateSaleHash.digest(
                    block.chainid,
                    address(artistPrivate),
                    StreamPrivateSaleHash.authorizationBody(a)
                ),
            "literal original full sale authorization domain and fields"
        );
        return digest;
    }
}
