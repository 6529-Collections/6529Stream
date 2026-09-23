// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import "../../smart-contracts/domains/auctions/StreamNativeAuctionContentGate.sol";
import {
    StreamPreparedNativeContentTypes as AuctionContent
} from "../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as PN
} from "../../smart-contracts/interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPreparedNativeSettlementHash
} from "../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementHash.sol";
import {
    StreamPrimarySettlementHash
} from "../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import {
    StreamNativeSettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamPreparedNativeContentHash
} from "../../smart-contracts/domains/mint/StreamPreparedNativeContentHash.sol";
import {
    StreamArtistSaleTypes as AST
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistSaleAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import {
    IStreamArtistAuthorizationRevocation
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";

/// @dev Actual current authority, Artist, gate, mint, revenue and entropy graph. The inherited
/// external entropy provider is a double. No shared fixture or production runtime is replaced.
abstract contract CurrentArtistCuratedAuctionFixture is CurrentDynamicRoyaltyCommerceFixture {
    bytes32 internal constant CURATED_AUCTION_PHASE = keccak256("actual Artist curated auction");
    bytes32 internal constant CURATED_AUCTION_COUNTER =
        keccak256("actual Artist selected work cap");
    bytes32 internal constant CURATED_AUCTION_VERSION = keccak256("actual curated gate version");
    bytes32 internal constant CURATED_AUCTION_MANIFEST =
        keccak256("actual curated gate registration");

    struct CuratedAuctionPlan {
        IStreamNativeEnglishAuction.Configuration config;
        AuctionContent.Selection selection;
        StreamNativeAuctionContentGate gate;
        bytes artwork;
        uint256 nonce;
        bytes32 saleId;
        bytes32 manifestHash;
    }

    struct CuratedAuctionReceipt {
        PN.Facts mint;
        PN.Intent intent;
        AuctionContent.Facts content;
        bytes32 key;
        bytes32 saleKey;
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function curatedAuctionTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _curatedAuctionPlan(bool empty) internal returns (CuratedAuctionPlan memory p) {
        (p.nonce, p.saleId) = joinedHouse.nextCuratedSaleId(1, CURATED_AUCTION_PHASE);
        AuctionContent.Row[] memory rows = new AuctionContent.Row[](2);
        rows[0] = AuctionContent.Row(0, keccak256(""), "urn:current:curated:empty");
        rows[1] = AuctionContent.Row(
            bytes32(uint256(1)), keccak256("actual curated work"), "urn:current:curated:one"
        );
        p.gate = StreamNativeAuctionContentGate(
            _artistArtifactCreate(
                "smart-contracts/domains/auctions/StreamNativeAuctionContentGate.sol:StreamNativeAuctionContentGate",
                abi.encode(
                    address(manager),
                    address(joinedHouse),
                    p.saleId,
                    uint256(1),
                    CURATED_AUCTION_PHASE,
                    CURATED_AUCTION_COUNTER,
                    rows
                )
            )
        );
        _assertDeployableProductionInstance(address(p.gate));
        bytes32 first = _curatedAuctionLeaf(p.saleId, rows[0].contentId, rows[0].tokenDataHash);
        bytes32 second = _curatedAuctionLeaf(p.saleId, rows[1].contentId, rows[1].tokenDataHash);
        bytes32 root = first < second
            ? keccak256(abi.encodePacked(first, second))
            : keccak256(abi.encodePacked(second, first));
        p.manifestHash = keccak256(abi.encode(rows));
        AuctionContent.Publication memory publication = p.gate.publication();
        require(
            keccak256(abi.encode(publication))
                    == keccak256(
                        abi.encode(
                            AuctionContent.Publication(
                                block.chainid,
                                address(manager),
                                address(joinedHouse),
                                p.saleId,
                                1,
                                CURATED_AUCTION_PHASE,
                                root,
                                p.manifestHash,
                                CURATED_AUCTION_COUNTER
                            )
                        )
                    ) && p.gate.itemCount() == 2
                && keccak256(p.gate.manifestBytes()) == p.manifestHash,
            "complete original two-row publication binds actual Manager and house"
        );
        this.curatedAuctionAdmitGate(p.gate);
        _curatedAuctionConfigurePhase(p.gate);
        p.artwork = empty ? bytes("") : bytes("actual curated work");
        p.selection = AuctionContent.Selection(
            empty ? bytes32(0) : bytes32(uint256(1)), keccak256(p.artwork), new bytes32[](1)
        );
        p.selection.proof[0] = empty ? second : first;
        p.config.collectionId = 1;
        p.config.phaseId = CURATED_AUCTION_PHASE;
        p.config.mintAtSettlement = true;
        p.config.artworkCommitment = empty ? first : second;
        p.config.contentManifestRoot = root;
        p.config.mintCommitment = keccak256("actual curated mint commitment");
        p.config.poster = address(joinedCollaborator);
        p.config.reservePrice = JOINED_PRICE;
        p.config.minIncrementBps = 500;
        uint64 observed = this.curatedAuctionTime();
        p.config.clock = StreamEnglishAuctionClock.Configuration(
            observed, observed + 3600, 0, 600, 600, 3600, false, false
        );
        p.config.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        p.config.primaryPolicyMode = 1;
        p.config.settlementWindow = 7 days;
        p.config.mintPolicyHash = manager.phasePolicyHash(1, CURATED_AUCTION_PHASE);
    }

    function curatedAuctionAdmitGate(StreamNativeAuctionContentGate gate) external {
        require(msg.sender == address(this), "fixture self");
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            CURATED_AUCTION_VERSION,
            type(IStreamMintGate).interfaceId,
            800_000,
            address(gate).codehash,
            DEPLOYMENT_HASH,
            CURATED_AUCTION_MANIFEST,
            "urn:stream:current:artist-curated-auction"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
        StreamModuleRecord memory admitted = registry.moduleRecord(address(gate));
        require(
            admitted.status == ModuleRegistryStatus.ACTIVE
                && admitted.runtimeCodeHash == address(gate).codehash,
            "actual Governor Safe admits exact production gate"
        );
    }

    function _curatedAuctionConfigurePhase(StreamNativeAuctionContentGate gate) private {
        IStreamMintManager.MintGateConfig memory g = IStreamMintManager.MintGateConfig(
            address(gate),
            gate.gateConfigHash(),
            address(gate).codehash,
            keccak256(abi.encode(CURATED_AUCTION_VERSION, CURATED_AUCTION_MANIFEST)),
            0,
            800_000
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = CURATED_AUCTION_COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256("actual curated cap-one content context")
        );
        IStreamMintManager.MintPhaseConfig memory c = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("actual curated phase terms"), CURATED_AUCTION_MANIFEST
        );
        address[] memory allowed = new address[](0);
        _curatedAuctionPolicyConsent(
            manager.previewPhasePolicyHash(1, CURATED_AUCTION_PHASE, c, g, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.configurePhase, (uint256(1), CURATED_AUCTION_PHASE, c, g, ids, counters)
            )
        );
        allowed = new address[](1);
        allowed[0] = address(joinedHouse);
        bytes32 policy =
            manager.previewPhasePolicyHash(1, CURATED_AUCTION_PHASE, c, g, ids, counters, allowed);
        _curatedAuctionPolicyConsent(policy);
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor,
                (uint256(1), CURATED_AUCTION_PHASE, address(joinedHouse), true)
            )
        );
        require(
            manager.phasePolicyHash(1, CURATED_AUCTION_PHASE) == policy
                && ledger.registeredPhasePolicyHash(address(manager), 1, CURATED_AUCTION_PHASE)
                    == policy,
            "exact actual Artist-approved Manager and Ledger policy"
        );
        artists.requireMintConsent(1, CURATED_AUCTION_PHASE, policy);
    }

    function _curatedAuctionAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
            .artistAuthorizationState(fixtureArtistId, bytes32(0), 0)
            .nextUnusedNonce,
            this.curatedAuctionTime() + 1 days,
            ""
        );
    }

    function _curatedAuctionPolicyConsent(bytes32 policy) private {
        T.PolicyConsent memory p = T.PolicyConsent(1, CURATED_AUCTION_PHASE, policy);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordPolicyConsent, (p, _curatedAuctionAuthorization()))
        );
        (bool approved,) = artists.isPolicyConsented(1, CURATED_AUCTION_PHASE, policy);
        require(approved, "actual Artist Safe records exact policy before governance");
    }

    function _curatedAuctionSaleConsent(CuratedAuctionPlan memory p, bytes32 id) internal {
        AST.Consent memory terms =
            AST.Consent(1, address(joinedHouse), p.saleId, joinedHouse.auction(id).configHash);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent,
                (terms, _curatedAuctionAuthorization())
            )
        );
        (bool approved, bytes32 hash) = artists.isSaleConsented(1, p.saleId, terms.saleConfigHash);
        AST.Record memory record = artists.saleConsentRecord(hash);
        require(
            artists.saleConsentScope(1) == 1 && approved && record.signer == address(joinedArtist)
                && record.artistId == fixtureArtistId
                && keccak256(abi.encode(record.terms)) == keccak256(abi.encode(terms)),
            "actual operation16 binds original Artist Safe house sale and full configuration"
        );
    }

    function _curatedAuctionCreation(CuratedAuctionPlan memory p)
        internal
        returns (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artistProof
        )
    {
        bytes32 configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_AUCTION_CONFIG_V1"),
                block.chainid,
                address(joinedHouse),
                p.config
            )
        );
        require(
            configHash == joinedHouse.auctionConfigurationHash(p.config),
            "original full configuration domain"
        );
        a = IStreamNativeEnglishAuction.CreationAuthorization(
            configHash,
            address(joinedArtist),
            keccak256("actual curated creation nonce"),
            this.curatedAuctionTime() + 1 days
        );
        bytes32 digest = _curatedAuctionTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "NativeAuctionCreation(bytes32 configHash,address artist,bytes32 nonce,uint64 deadline)"
                    ),
                    a
                )
            )
        );
        require(
            digest == joinedHouse.creationAuthorizationDigest(a),
            "original creation signature domain"
        );
        return (a, _platformProof(digest), _artistProof(digest));
    }

    function _curatedAuctionOpenData(CuratedAuctionPlan memory p) internal returns (bytes memory) {
        (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artistProof
        ) = _curatedAuctionCreation(p);
        return abi.encodeCall(
            joinedHouse.registerCuratedAuction,
            (p.config, p.artwork, p.selection, p.nonce, a, platform, artistProof)
        );
    }

    function _curatedAuctionId(CuratedAuctionPlan memory p) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(joinedHouse),
                uint256(1),
                p.nonce,
                uint256(0),
                false
            )
        );
    }

    function _curatedAuctionOpen(CuratedAuctionPlan memory p) internal returns (bytes32 id) {
        _joinedSafe(joinedCollaborator, address(joinedHouse), 0, _curatedAuctionOpenData(p));
        id = _curatedAuctionId(p);
        require(
            joinedHouse.auction(id).saleId == p.saleId
                && keccak256(abi.encode(joinedHouse.curatedSelection(id)))
                    == keccak256(abi.encode(p.selection)) && core.lastAllocatedTokenId() == 0,
            "actual poster opens retained selection without reserving token identity"
        );
    }

    function _curatedAuctionTyped(bytes32 body) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeEnglishAuction"),
                keccak256("1"),
                block.chainid,
                address(joinedHouse)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _curatedAuctionSafeCall(
        OfficialSafe safe,
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        bytes32 digest = safe.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                target,
                value,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }

    function _curatedAuctionLeaf(bytes32 saleId, bytes32 contentId, bytes32 dataHash)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(joinedHouse),
                        saleId,
                        contentId,
                        dataHash
                    )
                )
            )
        );
    }

    function _curatedAuctionContext(CuratedAuctionPlan memory p) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(joinedHouse),
                p.saleId,
                p.selection.contentId
            )
        );
    }

    function _curatedAuctionCounterKey(CuratedAuctionPlan memory p)
        internal
        view
        returns (bytes32)
    {
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONTEXT,
                _curatedAuctionContext(p)
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                CURATED_AUCTION_PHASE,
                CURATED_AUCTION_COUNTER,
                subject
            )
        );
    }

    function _curatedAuctionIntent(bytes32 id) internal view returns (PN.Intent memory i) {
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        i = PN.Intent(
            1,
            CURATED_AUCTION_PHASE,
            a.saleId,
            a.saleNonce,
            a.winner.executor,
            a.winner.payer,
            a.config.poster,
            a.winner.deliverTo,
            a.winner.amount,
            1,
            a.config.expectedPrimaryPolicyHash,
            a.winner.bidIndex,
            a.winner.signed ? 1 : 2,
            a.winner.authorizationDigest,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_ENGLISH_AUCTION_EXECUTION_V1"),
                    block.chainid,
                    address(joinedHouse),
                    a.configHash,
                    a.creationDigest,
                    a.saleId,
                    a.winner
                )
            ),
            a.config.artworkCommitment,
            a.config.mintCommitment,
            a.config.mintPolicyHash
        );
    }

    function _curatedAuctionIntentHash(bytes32 id) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_INTENT_V1"),
                block.chainid,
                address(joinedHouse),
                address(joinedRecorder),
                _curatedAuctionIntent(id)
            )
        );
    }

    function curatedAuctionRecorderAdmission(bool allowed) external {
        require(msg.sender == address(this), "fixture self");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            revenueEscrow.creditProducerTransitionHashes(address(joinedRecorder), allowed);
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(revenueEscrow.setCreditProducer, (address(joinedRecorder), allowed));
        calls[0] =
            StreamCurrentStackPlan.call(address(revenueEscrow), data[0], scope, oldHash, newHash);
        _joinedBatch(calls, data);
    }

    function _curatedAuctionNoMint(CuratedAuctionPlan memory p, bytes32 authorization)
        internal
        view
    {
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists
                && manager.nextOperationNonce() == 0
                && ledger.counterValue(_curatedAuctionCounterKey(p)) == 0
                && !manager.isAuthorizationUsed(authorization)
                && !ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && manager.preparedNativeContentAdmission() == 0
                && manager.activePreparedNativeMint().operationRoot == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && entropy.revealFeeEscrow(1) == 0 && wallet.balance == 0
                && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0,
            "complete actual mint content and payment state remains unconsumed"
        );
    }

    function _curatedAuctionReceipt(
        CuratedAuctionPlan memory p,
        bytes32 id,
        Vm.Log[] memory logs,
        bool escrowed
    ) internal view returns (CuratedAuctionReceipt memory r) {
        r.key = joinedHouse.auction(id).settlementKey;
        uint256 originalCount;
        uint256 contentCount;
        bytes32 originalEvent = keccak256(
            "PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        bytes32 contentEvent = keccak256(
            "PreparedNativeContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(joinedRecorder) || logs[n].topics.length < 3) continue;
            if (logs[n].topics[0] == originalEvent) {
                require(
                    logs[n].topics.length == 4 && logs[n].topics[1] == r.key
                        && logs[n].data.length == 1152,
                    "original record event shape"
                );
                (r.mint, r.intent) = abi.decode(logs[n].data, (PN.Facts, PN.Intent));
                r.saleKey = logs[n].topics[2];
                require(
                    logs[n].topics[3] == StreamPreparedNativeSettlementHash.factsHash(r.mint),
                    "original facts event hash"
                );
                ++originalCount;
            } else if (logs[n].topics[0] == contentEvent) {
                require(
                    logs[n].topics.length == 3 && logs[n].topics[1] == r.key,
                    "content event identity"
                );
                r.content = abi.decode(logs[n].data, (AuctionContent.Facts));
                require(
                    logs[n].topics[2] == StreamPreparedNativeContentHash.factsHash(r.content),
                    "content event hash"
                );
                ++contentCount;
            }
        }
        require(
            originalCount == 1 && contentCount == 1 && r.key != 0,
            "one original receipt and content record"
        );
        require(
            keccak256(abi.encode(r.intent)) == keccak256(abi.encode(_curatedAuctionIntent(id)))
                && r.mint.operationRoot != 0 && r.mint.operationId != 0,
            "original complete winner intent and operation identities"
        );
        PN.Facts memory expectedMint = PN.Facts(
            address(joinedHouse),
            address(manager),
            address(joinedRecorder),
            address(joinedRecorder).codehash,
            1,
            CURATED_AUCTION_PHASE,
            _curatedAuctionIntentHash(id),
            r.mint.operationRoot,
            r.mint.operationId,
            1,
            1,
            address(joinedCollector),
            address(joinedHouse),
            address(joinedCollector),
            p.selection.tokenDataHash,
            p.config.mintCommitment,
            p.config.mintPolicyHash,
            p.config.mintPolicyHash
        );
        AuctionContent.Facts memory expectedContent = AuctionContent.Facts(
            r.mint.operationRoot,
            address(p.gate),
            address(p.gate).codehash,
            p.gate.gateConfigHash(),
            p.config.contentManifestRoot,
            p.manifestHash,
            CURATED_AUCTION_COUNTER,
            p.selection.contentId,
            p.selection.tokenDataHash,
            p.config.artworkCommitment,
            _curatedAuctionContext(p)
        );
        require(
            keccak256(abi.encode(r.mint)) == keccak256(abi.encode(expectedMint))
                && keccak256(abi.encode(r.content)) == keccak256(abi.encode(expectedContent))
                && r.intent.contentSelectionHash == r.content.contentLeaf
                && r.content.contentLeaf != r.mint.tokenDataHash,
            "full content facts preserve leaf identity separately from actual token bytes"
        );
        require(
            r.saleKey
                    == StreamPreparedNativeSettlementHash.saleKey(
                        address(joinedRecorder), address(joinedHouse), p.saleId, p.nonce
                    ) && joinedRecorder.preparedNativeSaleConsumed(r.saleKey)
                && joinedRecorder.settlementConsumed(r.key)
                && joinedRecorder.preparedNativeFactsHash(r.key)
                    == StreamPreparedNativeSettlementHash.factsHash(r.mint)
                && joinedRecorder.preparedNativeContentHash(r.key)
                    == StreamPreparedNativeContentHash.factsHash(r.content)
                && manager.isAuthorizationUsed(r.mint.intentHash)
                && ledger.isManagerAuthorizationUsed(address(manager), r.mint.intentHash)
                && manager.isOperationRootUsed(r.mint.operationRoot)
                && ledger.isManagerOperationRootUsed(address(manager), r.mint.operationRoot),
            "original facts content payment and canonical Ledger replay stores agree"
        );
        _curatedAuctionResult(r, escrowed);
        require(
            core.ownerOf(1) == address(joinedCollector) && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1 && core.lastAllocatedTokenId() == 1
                && core.collectionNextSerial(1) == 2 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists
                && keccak256(core.tokenData(1)) == p.selection.tokenDataHash
                && manager.nextOperationNonce() == 1
                && ledger.counterValue(_curatedAuctionCounterKey(p)) == 1
                && manager.activePreparedNativeMint().operationRoot == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && manager.preparedNativeContentAdmission() == 0,
            "one selected token and cap-one debit with all temporary admission cleared"
        );
        require(
            joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE
                && entropy.revealFeeEscrow(1) == 100 && joinedHouse.totalBuyerLiabilities() == 0
                && address(joinedHouse).balance == 0
                && joinedHouse.refundableBalance(p.saleId, address(joinedCollector)) == 0
                && wallet.balance == (escrowed ? 0 : JOINED_PRICE)
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == (escrowed ? JOINED_PRICE : 0),
            "original PROFILE payment and separate reveal fee discharge the exact winner liability"
        );
    }

    function _curatedAuctionResult(CuratedAuctionReceipt memory r, bool escrowed) private view {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(joinedHouse);
        c.executor = r.intent.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            r.intent.saleId,
            PRIMARY_REVENUE_CLASS,
            1,
            1,
            1,
            r.intent.saleNonce,
            r.intent.payer,
            r.intent.poster,
            r.intent.beneficiary,
            JOINED_PRICE,
            r.intent.originalPrimaryPolicyHash
        );
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            joinedHouse.preparedNativeSaleLifecycle(r.intent.saleId);
        c.lifecycleBinding.saleCreatedAt = lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamPreparedNativeSettlementHash.executionId(r.mint, r.intent),
            r.intent.executionNonce,
            r.intent.authorityMode,
            r.intent.saleAuthorizationDigest
        );
        c.orchestrationOrder = 2;
        c.mintManager = address(manager);
        c.operationIdentityCommitment = r.mint.operationRoot;
        c.operationId = r.mint.operationId;
        c.currentPolicyHash = r.mint.currentPolicyHash;
        c.boundPolicyHash = r.mint.boundPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            profile,
            wallet,
            0,
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash,
            factory.profileEntriesHash(profile)
        );
        c.saleExecutionHash = r.intent.saleExecutionHash;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_CANDIDATE_V1"),
                        block.chainid,
                        address(joinedRecorder),
                        r.mint,
                        r.content,
                        r.intent,
                        c
                    )
                ),
                StreamPrimarySettlementHash.settlementKey(
                    address(joinedRecorder), address(joinedHouse), c.executionBinding.executionId
                ),
                profile,
                wallet,
                address(0),
                JOINED_PRICE,
                r.intent.executor,
                c.executionBinding.executionId,
                escrowed,
                r.mint.operationRoot,
                r.mint.currentPolicyHash,
                r.mint.boundPolicyHash
            );
        require(
            r.key == expected.settlementKey
                && keccak256(abi.encode(joinedRecorder.settlementResult(r.key)))
                    == keccak256(abi.encode(expected)),
            "all twelve original content settlement receipt fields match independent candidate construction"
        );
    }
}
