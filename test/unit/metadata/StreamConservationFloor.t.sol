// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../../smart-contracts/domains/revenue/StreamNativeSupplementalHash.sol";
import {
    StreamConservationFloorTypes as F
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    StreamPrimarySettlementTypes as T
} from "../../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    StreamNativeSettlementTypes as N
} from "../../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamNativeSupplementalTypes as S
} from "../../../smart-contracts/interfaces/stream/revenue/StreamNativeSupplementalTypes.sol";

/// @dev Explicit typed Core boundary. One-time production Core binding is tested separately.
contract FloorCoreBoundary is MetadataCoreBoundary {
    address private _floor;
    bytes32 private _floorHash;
    mapping(uint256 => bytes32) public declaredConservationTier;

    function setFloor(address value) external {
        _floor = value;
        _floorHash = value.codehash;
    }

    function conservationFloor() external view returns (address, bytes32) {
        return (_floor, _floorHash);
    }

    function setTier(uint256 cid, bytes32 tier) external {
        declaredConservationTier[cid] = tier;
    }
}

contract FloorRegistryBoundary {
    mapping(address => StreamModuleRecord) private _records;

    function register(address target, bool sale) external {
        _records[target] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            sale ? keccak256("NATIVE_PRIMARY_SALE_ADAPTER") : keccak256("PRIMARY_SALE_SETTLEMENT"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            sale
                ? type(IStreamNativeSaleBinding).interfaceId
                : type(IStreamPrimarySaleSettlement).interfaceId,
            100000,
            target.codehash,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            "ipfs://fixture",
            1,
            1,
            1
        );
    }

    function setStatus(address target, ModuleRegistryStatus status) external {
        _records[target].status = status;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return _records[target];
    }
}

contract FloorManagerBoundary {
    address public immutable core;
    bool public used = true;

    constructor(address c) {
        core = c;
    }

    function setUsed(bool value) external {
        used = value;
    }

    function isOperationRootUsed(bytes32) external view returns (bool) {
        return used;
    }
}

contract FloorMetadataBoundary {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Synthetic source facts test ledger orchestration only; they are not native record/proof evidence.
contract FloorProviderBoundary is IStreamConservationFloorProvider {
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    address public immutable override metadata;
    bytes32 public immutable override metadataCodeHash;
    uint256 public immutable override deploymentChainId;
    bytes32 public override configurationHash = keccak256("synthetic-source-configuration");
    F.CollectionFacts private _collection;
    F.ReleaseContext private _release;
    F.ReleaseFacts private _facts;
    bool public unavailableCollection;
    bool public unavailableRelease;
    bool public unavailableScope;
    bool public strictToken;
    bool public tokenSpecific;

    function setTokenProfile(bool strict_, bool specific_) external {
        strictToken = strict_;
        tokenSpecific = specific_;
    }

    constructor(address c, address m) {
        core = c;
        coreCodeHash = c.codehash;
        metadata = m;
        metadataCodeHash = m.codehash;
        deploymentChainId = block.chainid;
        _collection = F.CollectionFacts(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            0,
            bytes32(uint256(4)),
            bytes32(uint256(5)),
            bytes32(uint256(6)),
            false
        );
        _release = F.ReleaseContext(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            0,
            bytes32(uint256(4)),
            false
        );
        _facts = F.ReleaseFacts(bytes32(uint256(4)), bytes32(uint256(5)), 0);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamConservationFloorProvider).interfaceId;
    }

    function setUnavailable(bool collection_, bool release_, bool scope_) external {
        unavailableCollection = collection_;
        unavailableRelease = release_;
        unavailableScope = scope_;
    }

    function setConfiguration(bytes32 value) external {
        configurationHash = value;
    }

    function setCollection(F.CollectionFacts calldata value) external {
        _collection = value;
    }

    function setRelease(F.ReleaseContext calldata release_, F.ReleaseFacts calldata facts)
        external
    {
        _release = release_;
        _facts = facts;
    }

    function collectionFacts() external view returns (F.CollectionFacts memory) {
        return _collection;
    }

    function releaseFacts() external view returns (F.ReleaseContext memory, F.ReleaseFacts memory) {
        return (_release, _facts);
    }

    function requireCollectionFloor(uint256, bytes32)
        external
        view
        override
        returns (F.CollectionFacts memory)
    {
        require(!unavailableCollection, "synthetic collection unavailable");
        return _collection;
    }

    function saleRelease(F.SaleContext calldata sale)
        external
        view
        override
        returns (F.ReleaseContext memory)
    {
        require(!unavailableScope, "synthetic scope unavailable");
        if (strictToken && sale.tokenId != 0) {
            require(
                IStreamCoreIdentity(core).tokenLifecycle(sale.tokenId) != 0,
                "no invented allocation"
            );
        }
        F.ReleaseContext memory release = _release;
        if (tokenSpecific) {
            release.membershipHash = keccak256(abi.encode(release.membershipHash, sale.tokenId));
        }
        return release;
    }

    function requireReleaseFloor(F.SaleContext calldata, F.ReleaseContext calldata, bytes32)
        external
        view
        override
        returns (F.ReleaseFacts memory)
    {
        require(!unavailableRelease, "synthetic release unavailable");
        return _facts;
    }
}

    /// @dev Typed admitted caller/result boundary; actual payment/recorder integration is separate.
    contract FloorRecorderBoundary {
        address public immutable core;
        bytes32 public immutable coreCodeHash;
        address public immutable moduleRegistry;
        bytes32 public immutable moduleRegistryCodeHash;
        mapping(bytes32 => bool) public settlementConsumed;
        mapping(bytes32 => T.PrimarySettlementResult) private _results;
        mapping(bytes32 => S.NativeSupplementalResult) private _supplements;

        constructor(address c, address registry) {
            core = c;
            coreCodeHash = c.codehash;
            moduleRegistry = registry;
            moduleRegistryCodeHash = registry.codehash;
        }

        function supportsInterface(bytes4 id) external pure returns (bool) {
            return id == 0x01ffc9a7 || id == type(IStreamPrimarySaleSettlement).interfaceId;
        }

        function settlementResult(bytes32 key)
            external
            view
            returns (T.PrimarySettlementResult memory)
        {
            return _results[key];
        }

        function nativeSupplementalResult(bytes32 key)
            external
            view
            returns (S.NativeSupplementalResult memory)
        {
            return _supplements[key];
        }

        function record(
            StreamConservationFloor floor,
            T.ERC20SettlementCandidate calldata c,
            T.PrimarySettlementResult calldata r
        ) external returns (bytes32) {
            _save(r);
            return floor.recordPrimarySale(c, r);
        }

        function invokeOnly(
            StreamConservationFloor floor,
            T.ERC20SettlementCandidate calldata c,
            T.PrimarySettlementResult calldata r
        ) external returns (bytes32) {
            return floor.recordPrimarySale(c, r);
        }

        function recordThenFail(
            StreamConservationFloor floor,
            T.ERC20SettlementCandidate calldata c,
            T.PrimarySettlementResult calldata r
        ) external {
            _save(r);
            floor.recordPrimarySale(c, r);
            revert("downstream mint failed");
        }

        function supplement(
            StreamConservationFloor floor,
            S.NativeSupplementalCandidate calldata c,
            S.NativeSupplementalResult calldata r
        ) external returns (bytes32) {
            _supplements[r.settlementKey] = r;
            _save(
                T.PrimarySettlementResult(
                    r.candidateCommitment,
                    r.settlementKey,
                    r.profileId,
                    r.wallet,
                    address(0),
                    r.amount,
                    r.executor,
                    r.executionId,
                    r.escrowed,
                    r.originalOperationRoot,
                    c.originalFloor.currentPolicyHash,
                    c.originalFloor.boundPolicyHash
                )
            );
            return floor.requireSupplemental(c, r);
        }

        function _save(T.PrimarySettlementResult memory r) private {
            settlementConsumed[r.settlementKey] = true;
            _results[r.settlementKey] = r;
        }
    }

    contract FloorClearingBoundary {
        address public immutable core;
        address public immutable mintManager;
        bytes32 public immutable mintManagerCodeHash;
        address public immutable primarySaleSettlement;
        N.SaleLifecycleBinding private _lifecycle;
        mapping(bytes32 => S.ClearingPurchaseFacts) private _purchase;
        mapping(bytes32 => bytes32) public activeNativeSupplementalSettlement;

        constructor(address c, address manager, address recorder) {
            core = c;
            mintManager = manager;
            mintManagerCodeHash = manager.codehash;
            primarySaleSettlement = recorder;
            _lifecycle = N.SaleLifecycleBinding(1, 1);
        }

        function supportsInterface(bytes4 id) external pure returns (bool) {
            return id == 0x01ffc9a7 || id == type(IStreamNativeSaleBinding).interfaceId
                || id == type(IStreamNativeClearingSaleBinding).interfaceId;
        }

        function nativeSaleLifecycleBinding(bytes32)
            external
            view
            returns (N.SaleLifecycleBinding memory)
        {
            return _lifecycle;
        }

        function clearingPurchaseFacts(bytes32 id)
            external
            view
            returns (S.ClearingPurchaseFacts memory)
        {
            return _purchase[id];
        }

        function configure(bytes32 id, S.ClearingPurchaseFacts calldata p, bytes32 commitment)
            external
        {
            _purchase[id] = p;
            activeNativeSupplementalSettlement[id] = commitment;
        }
    }

    contract StreamConservationFloorTest is CharacterizationTestBase {
        FloorCoreBoundary private core;
        MetadataExecutorBoundary private executor;
        FloorRegistryBoundary private registry;
        FloorManagerBoundary private manager;
        FloorMetadataBoundary private metadata;
        FloorProviderBoundary private provider;
        FloorRecorderBoundary private recorder;
        FloorClearingBoundary private sale;
        StreamConservationFloor private floor;
        bytes32 private constant LITE = keccak256("MUSEUM_GRADE_LITE");
        bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
        bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");

        function setUp() public {
            vm.warp(1000);
            core = new FloorCoreBoundary();
            executor = new MetadataExecutorBoundary();
            registry = new FloorRegistryBoundary();
            manager = new FloorManagerBoundary(address(core));
            metadata = new FloorMetadataBoundary();
            provider = new FloorProviderBoundary(address(core), address(metadata));
            recorder = new FloorRecorderBoundary(address(core), address(registry));
            sale = new FloorClearingBoundary(address(core), address(manager), address(recorder));
            registry.register(address(recorder), false);
            registry.register(address(sale), true);
            core.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
            core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
            floor = new StreamConservationFloor(
                address(core),
                address(executor),
                _gas("CONSERVATION_FLOOR_READ_GAS", 300000),
                _gas("CONSERVATION_FLOOR_PRODUCER_GAS", 1000000),
                _gas("CONSERVATION_FLOOR_CALL_GAS", 6000000)
            );
            core.setFloor(address(floor));
            _append(address(metadata), address(provider));
        }

        function testProspectiveUndeclaredTierIsLiteAndReceiptsAreExact() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            floor.preparePrimarySale(address(recorder), c, r);
            vm.recordLogs();
            bytes32 hash = recorder.record(floor, c, r);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            F.SettlementReceipt memory s = floor.settlementReceipt(r.settlementKey);
            F.FirstSaleReceipt memory first = floor.firstSale(1);
            require(
                core.declaredConservationTier(1) == 0 && s.effectiveTier == LITE,
                "prospective default"
            );
            require(
                hash != 0 && s.receiptHash == hash && s.firstSaleReceiptHash == first.receiptHash,
                "receipt link"
            );
            require(
                s.candidatePayloadHash == keccak256(abi.encode(c))
                    && s.resultHash == keccak256(abi.encode(r)),
                "exact payloads"
            );
            require(
                s.recorder == address(recorder) && s.recorderCodeHash == address(recorder).codehash,
                "original recorder"
            );
            require(
                first.sourceId == 1 && first.recordedAt == 1000
                    && first.facts.personhoodEvidenceHash != 0,
                "synthetic facts stored"
            );
            require(logs.length == 3 && logs[2].emitter == address(floor), "all three floor events");
            require(
                logs[2].topics[1] == r.settlementKey && logs[2].topics[2] == hash,
                "settlement event identity"
            );
            (F.SettlementReceipt memory emitted, uint16 schemaVersion) =
                abi.decode(logs[2].data, (F.SettlementReceipt, uint16));
            require(
                schemaVersion == 1 && keccak256(abi.encode(emitted)) == keccak256(abi.encode(s)),
                "exact original event"
            );
        }

        function testFirstAndSameReleaseSurviveUnavailableHistoricalProducerFacts() public {
            _record(1);
            F.FirstSaleReceipt memory first = floor.firstSale(1);
            provider.setUnavailable(true, true, false);
            bytes32 next = _record(2);
            require(floor.firstSale(1).receiptHash == first.receiptHash, "first receipt immutable");
            require(
                floor.settlementReceipt(next).releaseReceiptHash != 0,
                "same semantic release retained"
            );
        }

        function testNewReleaseCannotReuseFirstSaleAsWaiver() public {
            _record(1);
            (F.ReleaseContext memory release, F.ReleaseFacts memory facts) = provider.releaseFacts();
            release.mediaInventoryHash = bytes32(uint256(77));
            provider.setRelease(release, facts);
            provider.setUnavailable(true, true, false);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(2);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(
                !recorder.settlementConsumed(r.settlementKey)
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "rollback"
            );
        }

        function testSameReleaseStillRequiresCurrentScopeMapping() public {
            _record(1);
            provider.setUnavailable(false, false, true);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(2);
            vm.expectRevert();
            recorder.record(floor, c, r);
        }

        function testReplacementRetainsFirstReleaseAndEverySourceRow() public {
            bytes32 firstKey = _record(1);
            F.SettlementReceipt memory original = floor.settlementReceipt(firstKey);
            FloorMetadataBoundary replacement = new FloorMetadataBoundary();
            FloorProviderBoundary nextProvider =
                new FloorProviderBoundary(address(core), address(replacement));
            nextProvider.setUnavailable(true, true, false);
            core.setPointer(keccak256("COLLECTION_METADATA"), address(replacement));
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(2);
            vm.expectRevert();
            recorder.record(floor, c, r);
            _append(address(replacement), address(nextProvider));
            bytes32 nextKey = _record(2);
            F.SettlementReceipt memory next = floor.settlementReceipt(nextKey);
            require(
                next.firstSaleReceiptHash == original.firstSaleReceiptHash
                    && next.releaseReceiptHash == original.releaseReceiptHash,
                "historical denominator"
            );
            require(
                floor.sourceAt(1).metadata == address(metadata)
                    && floor.sourceAt(2).predecessor == 1,
                "source history"
            );
            require(
                floor.firstSale(1).sourceId == 1 && floor.sourceCount() == 2,
                "original source preserved"
            );
        }

        function testRecorderReplacementCannotEraseFirstSale() public {
            bytes32 key = _record(1);
            F.SettlementReceipt memory original = floor.settlementReceipt(key);
            recorder = new FloorRecorderBoundary(address(core), address(registry));
            registry.register(address(recorder), false);
            bytes32 next = _record(2);
            require(
                floor.settlementReceipt(next).firstSaleReceiptHash == original.firstSaleReceiptHash,
                "durable first"
            );
            require(
                floor.settlementReceipt(key).recorder == original.recorder, "historical recorder"
            );
        }

        function testSourceRequiresExactGovernanceAndCannotRewritePredecessor() public {
            FloorProviderBoundary next = new FloorProviderBoundary(address(core), address(metadata));
            vm.expectRevert();
            floor.appendSource(address(metadata), address(next), 1);
            vm.expectRevert();
            floor.sourceTransition(address(metadata), address(next), 0);
            _append(address(metadata), address(next));
            require(
                floor.sourceCount() == 2 && floor.sourceAt(1).provider == address(provider),
                "append only"
            );
        }

        function testProviderConfigurationDriftFailsAfterFirstSale() public {
            _record(1);
            provider.setConfiguration(bytes32(uint256(99)));
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(2);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(floor.firstSale(1).receiptHash != 0, "historical read survives");
        }

        function testWaivedTierRequiresGenuineRecorderButNoProducerFacts() public {
            core.setTier(1, WAIVED);
            provider.setUnavailable(true, true, true);
            bytes32 key = _record(1);
            F.SettlementReceipt memory receipt = floor.settlementReceipt(key);
            require(
                receipt.effectiveTier == WAIVED && receipt.releaseReceiptHash == 0, "waived release"
            );
            require(
                floor.firstSale(1).sourceId == 0 && floor.firstSale(1).facts.rightsRecordHash == 0,
                "no invented evidence"
            );
        }

        function testArtistProofUnavailableCannotBecomeSuccessfulFloor() public {
            F.CollectionFacts memory facts = provider.collectionFacts();
            facts.personhoodEvidenceHash = 0;
            provider.setCollection(facts);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(floor.firstSale(1).receiptHash == 0, "no opaque personhood substitution");
        }

        function testPlatformRequiresRightsAndNoInventedArtist() public {
            F.CollectionFacts memory facts;
            facts.platformWorks = true;
            facts.rightsRecordHash = bytes32(uint256(1));
            provider.setCollection(facts);
            _record(1);
            require(floor.firstSale(1).facts.artistId == 0, "platform is not artist");
        }

        function testMalformedPlatformAndMissingRightsFail() public {
            F.CollectionFacts memory facts;
            facts.platformWorks = true;
            facts.artistId = bytes32(uint256(1));
            facts.rightsRecordHash = bytes32(uint256(2));
            provider.setCollection(facts);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            vm.expectRevert();
            recorder.record(floor, c, r);
            facts.artistId = 0;
            facts.rightsRecordHash = 0;
            provider.setCollection(facts);
            vm.expectRevert();
            recorder.record(floor, c, r);
        }

        function testFullScriptNeedsReferenceForItsNewRelease() public {
            core.setTier(1, FULL);
            (F.ReleaseContext memory release, F.ReleaseFacts memory facts) = provider.releaseFacts();
            release.scriptWork = true;
            release.scriptSourceHash = bytes32(uint256(88));
            provider.setRelease(release, facts);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            vm.expectRevert();
            recorder.record(floor, c, r);
            facts.referenceEvidenceHash = bytes32(uint256(99));
            provider.setRelease(release, facts);
            _settle(c, r);
        }

        /// @dev Genuine paid ledger receipts over the explicitly synthetic typed provider.
        /// This exercises ledger reuse policy, not the held native documentary-personhood proof.
        function testFullScriptKeepsOriginalPaidReferenceAcrossBenignSourceReplacement() public {
            core.setTier(1, FULL);
            (F.ReleaseContext memory originalContext, F.ReleaseFacts memory facts) =
                provider.releaseFacts();
            originalContext.scriptWork = true;
            originalContext.scriptSourceHash = keccak256(
                abi.encode(keccak256("script-v1"), address(0x111), keccak256("renderer-v1"))
            );
            facts.referenceEvidenceHash = keccak256("original typed reference proof");
            provider.setRelease(originalContext, facts);
            bytes32 firstKey = _record(1);
            F.SettlementReceipt memory originalSale = floor.settlementReceipt(firstKey);
            bytes32 semanticKey = _semanticRelease(originalContext);
            F.ReleaseFloorReceipt memory originalRelease = floor.releaseFloorReceipt(semanticKey);
            require(
                originalRelease.receiptHash == originalSale.releaseReceiptHash
                    && originalRelease.facts.referenceEvidenceHash == facts.referenceEvidenceHash,
                "genuine paid FULL-script reference receipt"
            );

            FloorMetadataBoundary nextMetadata = new FloorMetadataBoundary();
            FloorProviderBoundary nextProvider =
                new FloorProviderBoundary(address(core), address(nextMetadata));
            nextProvider.setConfiguration(
                keccak256("replacement configuration for unchanged content")
            );
            F.ReleaseContext memory current =
                abi.decode(abi.encode(originalContext), (F.ReleaseContext));
            current.sourceContextHash = keccak256("replacement source context");
            facts.sourceContextHash = current.sourceContextHash;
            facts.referenceEvidenceHash = 0;
            nextProvider.setRelease(current, facts);
            nextProvider.setUnavailable(true, true, false);
            core.setPointer(keccak256("COLLECTION_METADATA"), address(nextMetadata));
            _append(address(nextMetadata), address(nextProvider));
            bytes32 nextKey = _record(2);
            require(
                floor.settlementReceipt(nextKey).releaseReceiptHash == originalRelease.receiptHash
                    && keccak256(abi.encode(floor.releaseFloorReceipt(semanticKey)))
                        == keccak256(abi.encode(originalRelease))
                    && floor.firstSale(1).receiptHash == originalSale.firstSaleReceiptHash
                    && floor.sourceAt(2).provider == address(nextProvider),
                "benign replacement retains full original receipt even when current reference is unavailable"
            );

            nextProvider.setUnavailable(true, true, true);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(3);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(
                !recorder.settlementConsumed(r.settlementKey)
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "current semantic mapping is still required"
            );

            for (uint256 change; change < 3; ++change) {
                // The provider's scriptSourceHash commits both script and renderer semantics.
                current = abi.decode(abi.encode(originalContext), (F.ReleaseContext));
                current.sourceContextHash = keccak256(abi.encode("changed current source", change));
                if (change == 0) {
                    current.mediaInventoryHash = keccak256("material media-v2");
                } else {
                    current.scriptSourceHash = keccak256(
                        abi.encode(
                            change == 1 ? keccak256("script-v2") : keccak256("script-v1"),
                            change == 1 ? address(0x111) : address(0x222),
                            change == 1 ? keccak256("renderer-v1") : keccak256("renderer-v2")
                        )
                    );
                }
                facts.sourceContextHash = current.sourceContextHash;
                facts.referenceEvidenceHash = 0;
                nextProvider.setRelease(current, facts);
                nextProvider.setUnavailable(true, false, false);
                (c, r) = _pair(10 + change);
                vm.expectRevert();
                recorder.record(floor, c, r);
                require(
                    !recorder.settlementConsumed(r.settlementKey)
                        && floor.releaseFloorReceipt(_semanticRelease(current)).receiptHash == 0,
                    "material media, script or renderer change cannot borrow old reference"
                );
                facts.referenceEvidenceHash =
                    keccak256(abi.encode("new exact typed reference", change));
                nextProvider.setRelease(current, facts);
                recorder.record(floor, c, r);
                F.ReleaseFloorReceipt memory fresh =
                    floor.releaseFloorReceipt(_semanticRelease(current));
                require(
                    fresh.receiptHash != originalRelease.receiptHash && fresh.sourceId == 2
                        && fresh.facts.referenceEvidenceHash == facts.referenceEvidenceHash
                        && floor.settlementReceipt(r.settlementKey).releaseReceiptHash
                            == fresh.receiptHash,
                    "new semantic release retains its new genuine paid reference receipt"
                );
            }
            require(
                keccak256(abi.encode(floor.releaseFloorReceipt(semanticKey)))
                    == keccak256(abi.encode(originalRelease)),
                "later material releases never rewrite original evidence"
            );
        }

        function _semanticRelease(F.ReleaseContext memory release) private view returns (bytes32) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONSERVATION_RELEASE_V1"),
                    block.chainid,
                    address(core),
                    uint256(1),
                    release.scopeSubject,
                    release.membershipHash,
                    release.mediaInventoryHash,
                    release.scriptSourceHash,
                    release.scriptWork
                )
            );
        }

        function testUnboundAndUnadmittedCallerCannotWrite() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            vm.expectRevert();
            floor.recordPrimarySale(c, r);
            registry.setStatus(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
            vm.expectRevert();
            recorder.record(floor, c, r);
            registry.setStatus(address(recorder), ModuleRegistryStatus.ACTIVE);
            core.setFloor(address(provider));
            vm.expectRevert();
            recorder.record(floor, c, r);
        }

        function testMissingConsumedResultAndMismatchedAssetAreRejected() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            vm.expectRevert();
            recorder.invokeOnly(floor, c, r);
            c.asset = address(0x1234);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(floor.firstSale(1).receiptHash == 0, "no receipt");
        }

        function testDuplicateAndOrderZeroCannotCreateReceipt() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            _settle(c, r);
            vm.expectRevert();
            recorder.record(floor, c, r);
            (c, r) = _pair(2);
            c.orchestrationOrder = 0;
            vm.expectRevert();
            recorder.record(floor, c, r);
        }

        function testPreparedAllocatedTokenAndCompletedCustodyUseDistinctOrders() public {
            core.setToken(10, address(this), 1);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            c.orchestrationOrder = 2;
            c.sale.tokenId = 10;
            _settle(c, r);
            (c, r) = _pair(2);
            c.orchestrationOrder = 3;
            c.sale.tokenId = 10;
            c.mintManager = address(0);
            c.operationIdentityCommitment = 0;
            c.operationId = 0;
            c.currentPolicyHash = 0;
            c.boundPolicyHash = 0;
            r.operationIdentityCommitment = 0;
            r.currentPolicyHash = 0;
            r.boundPolicyHash = 0;
            vm.expectRevert();
            recorder.record(floor, c, r);
            core.setToken(10, address(this), 2);
            _settle(c, r);
            require(
                floor.settlementReceipt(r.settlementKey).tokenId == 10, "actual custody identity"
            );
        }

        function testLaterMintFailureRollsBackLedgerAndRecorder() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            floor.preparePrimarySale(address(recorder), c, r);
            vm.expectRevert();
            recorder.recordThenFail(floor, c, r);
            require(
                floor.firstSale(1).receiptHash == 0
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "ledger rollback"
            );
            require(!recorder.settlementConsumed(r.settlementKey), "recorder rollback");
            _settle(c, r);
        }

        function testSupplementalAuthenticatesOriginalReceiptWithoutNewFirstSaleChecks() public {
            N.NativeSettlementCandidate memory native = _native(1);
            T.ERC20SettlementCandidate memory original =
                StreamNativeSettlementHash.accountingContext(native);
            T.PrimarySettlementResult memory firstResult = _result(native);
            bytes32 firstHash = _settle(original, firstResult);
            (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r) =
                _supplement(native);
            provider.setUnavailable(true, true, true);
            require(recorder.supplement(floor, c, r) == firstHash, "genuine original floor");
            require(
                floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "financial supplement is not new initial floor"
            );
        }

        function testSupplementalMissingOriginalReceiptCannotBlindSkip() public {
            (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r) =
                _supplement(_native(1));
            vm.expectRevert();
            recorder.supplement(floor, c, r);
            require(!recorder.settlementConsumed(r.settlementKey), "supplement rollback");
        }

        function testSupplementalRejectsDifferentConsumerPurchaseAndUnusedRoot() public {
            N.NativeSettlementCandidate memory native = _native(1);
            _settle(StreamNativeSettlementHash.accountingContext(native), _result(native));
            (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r) =
                _supplement(native);
            S.ClearingPurchaseFacts memory changed = c.purchase;
            changed.paidPrice += 1;
            sale.configure(c.purchaseId, changed, r.candidateCommitment);
            vm.expectRevert();
            recorder.supplement(floor, c, r);
            sale.configure(c.purchaseId, c.purchase, r.candidateCommitment);
            manager.setUsed(false);
            vm.expectRevert();
            recorder.supplement(floor, c, r);
        }

        function testSupplementalRejectsAllocatedTokenAndWrongAmount() public {
            N.NativeSettlementCandidate memory native = _native(1);
            _settle(StreamNativeSettlementHash.accountingContext(native), _result(native));
            (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r) =
                _supplement(native);
            core.setToken(c.purchase.tokenId, address(this), 1);
            vm.expectRevert();
            recorder.supplement(floor, c, r);
            core.setToken(c.purchase.tokenId, address(this), 2);
            r.amount += 1;
            vm.expectRevert();
            recorder.supplement(floor, c, r);
        }

        /// forge-config: default.fuzz.runs = 256
        function testFuzzSupplementalOriginalPayloadCannotChange(bytes32 authorization) public {
            N.NativeSettlementCandidate memory native = _native(1);
            _settle(StreamNativeSettlementHash.accountingContext(native), _result(native));
            (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r) =
                _supplement(native);
            if (authorization == c.originalFloor.executionBinding.saleAuthorizationDigest) return;
            c.originalFloor.executionBinding.saleAuthorizationDigest = authorization;
            vm.expectRevert();
            recorder.supplement(floor, c, r);
        }

        function testCallGasIsIndependentlyRegisteredAndWrongIdRejected() public {
            require(floor.gasParameter(floor.CALL_GAS()) == 6000000, "whole entry gas cap");
            (,, uint8 failureClass, uint64 revision) = floor.gasParameterInfo(floor.CALL_GAS());
            require(failureClass == 2 && revision == 1, "fail closed parameter");
            vm.expectRevert();
            new StreamConservationFloor(
                address(core),
                address(executor),
                _gas("CONSERVATION_FLOOR_READ_GAS", 300000),
                _gas("CONSERVATION_FLOOR_PRODUCER_GAS", 1000000),
                _gas("WRONG_CALL_GAS", 6000000)
            );
        }

        function testPreparationIsNotSaleAndPaidTimestampIsPreserved() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            bytes32 preparation = floor.preparePrimarySale(address(recorder), c, r);
            require(
                floor.primarySalePrepared(preparation) && floor.firstSale(1).receiptHash == 0
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0
                    && !recorder.settlementConsumed(r.settlementKey),
                "unpaid preparation"
            );
            vm.warp(1100);
            recorder.record(floor, c, r);
            require(
                floor.firstSale(1).recordedAt == 1100
                    && floor.settlementReceipt(r.settlementKey).recordedAt == 1100,
                "actual paid time"
            );
        }

        function testStalePreparationUsesFreshCurrentFactsAndActualResult() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            bytes32 originalPreparation = floor.preparePrimarySale(address(recorder), c, r);
            F.CollectionFacts memory f = provider.collectionFacts();
            f.rightsRecordHash = bytes32(uint256(999));
            provider.setCollection(f);
            r.escrowed = true;
            recorder.record(floor, c, r);
            require(
                floor.primarySalePrepared(originalPreparation)
                    && floor.firstSale(1).facts.rightsRecordHash == f.rightsRecordHash
                    && floor.settlementReceipt(r.settlementKey).resultHash
                        == keccak256(abi.encode(r)),
                "fresh valid evidence and actual escrow result, original preparation retained"
            );
        }

        function testStalePreparationCannotBypassUnavailableCurrentEvidence() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            bytes32 prepared = floor.preparePrimarySale(address(recorder), c, r);
            provider.setUnavailable(true, false, false);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(
                floor.primarySalePrepared(prepared) && !recorder.settlementConsumed(r.settlementKey)
                    && floor.firstSale(1).receiptHash == 0
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "old preparation retained without paid state or false current proof"
            );
        }

        function testWaivedFirstPreparationRetainsOldHeadAndUsesCurrentPaidHead() public {
            core.setTier(1, WAIVED);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            bytes32 oldPreparation = floor.preparePrimarySale(address(recorder), c, r);
            FloorProviderBoundary next = new FloorProviderBoundary(address(core), address(metadata));
            _append(address(metadata), address(next));
            recorder.record(floor, c, r);
            require(
                floor.primarySalePrepared(oldPreparation)
                    && floor.firstSale(1).sourceSetHash == floor.sourceSetHashAt(2),
                "current paid head without rewriting old preparation"
            );
        }

        function testInlineAndOptionalPreparedPathsReturnIdenticalFullReceipts() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            uint256 snapshot = vm.snapshotState();
            bytes32 inlineHash = recorder.record(floor, c, r);
            F.SettlementReceipt memory inlineReceipt = floor.settlementReceipt(r.settlementKey);
            F.FirstSaleReceipt memory inlineFirst = floor.firstSale(1);
            require(vm.revertToState(snapshot), "restore identical original state");
            floor.preparePrimarySale(address(recorder), c, r);
            bytes32 preparedHash = recorder.record(floor, c, r);
            require(
                inlineHash == preparedHash
                    && keccak256(abi.encode(inlineReceipt))
                        == keccak256(abi.encode(floor.settlementReceipt(r.settlementKey)))
                    && keccak256(abi.encode(inlineFirst))
                        == keccak256(abi.encode(floor.firstSale(1))),
                "full original hashes and immutable receipt tuples are preparation independent"
            );
        }

        function testLateFailureRollsBackNewInlineEvidenceAndPaidLinks() public {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            uint256 snapshot = vm.snapshotState();
            bytes32 expectedPreparation = floor.preparePrimarySale(address(recorder), c, r);
            require(
                vm.revertToState(snapshot) && !floor.primarySalePrepared(expectedPreparation),
                "no prior prepared evidence"
            );
            vm.expectRevert();
            recorder.recordThenFail(floor, c, r);
            require(
                !floor.primarySalePrepared(expectedPreparation)
                    && !recorder.settlementConsumed(r.settlementKey)
                    && floor.firstSale(1).receiptHash == 0
                    && floor.settlementReceipt(r.settlementKey).receiptHash == 0,
                "new immutable seed, evidence, paid links and recorder effects revert together"
            );
            recorder.record(floor, c, r);
            require(
                floor.primarySalePrepared(expectedPreparation)
                    && floor.firstSale(1).receiptHash != 0,
                "same direct purchase succeeds without preparation transaction"
            );
        }

        function testHistoricalGettersNeverReadOldRecorderOrProvider() public {
            bytes32 key = _record(1);
            bytes32 firstHash = floor.firstSale(1).receiptHash;
            bytes32 settlementHash = floor.settlementReceipt(key).receiptHash;
            vm.etch(address(recorder), hex"00");
            vm.etch(address(provider), hex"00");
            require(
                floor.firstSale(1).receiptHash == firstHash
                    && floor.settlementReceipt(key).receiptHash == settlementHash,
                "full original historical receipts reconstruct from immutable prepared state"
            );
        }

        function _settle(T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r)
            private
            returns (bytes32)
        {
            floor.preparePrimarySale(address(recorder), c, r);
            return recorder.record(floor, c, r);
        }

        function testProspectivePreparedCollectionProfileMatchesActualAllocatedToken() public {
            provider.setTokenProfile(true, false);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            c.orchestrationOrder = 2;
            c.sale.tokenId = 10;
            floor.preparePrimarySale(address(recorder), c, r);
            require(
                core.tokenLifecycle(10) == 0 && floor.firstSale(1).receiptHash == 0,
                "only prospective evidence"
            );
            vm.expectRevert();
            recorder.record(floor, c, r);
            core.setToken(10, address(this), 1);
            recorder.record(floor, c, r);
            require(
                floor.settlementReceipt(r.settlementKey).tokenId == 10, "exact allocated identity"
            );
        }

        function testProspectiveCollectionPreparationCannotSubstituteTokenSpecificEvidence()
            public
        {
            provider.setTokenProfile(true, true);
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
            c.orchestrationOrder = 2;
            c.sale.tokenId = 10;
            bytes32 collectionPreparation = floor.preparePrimarySale(address(recorder), c, r);
            core.setToken(10, address(this), 1);
            provider.setUnavailable(false, true, false);
            vm.expectRevert();
            recorder.record(floor, c, r);
            require(
                floor.firstSale(1).receiptHash == 0
                    && floor.primarySalePrepared(collectionPreparation),
                "collection preparation cannot waive current token evidence"
            );
            provider.setUnavailable(false, false, false);
            recorder.record(floor, c, r);
            require(
                floor.settlementReceipt(r.settlementKey).tokenId == 10
                    && floor.primarySalePrepared(collectionPreparation),
                "fresh token-specific evidence recorded inline"
            );
        }

        function _gas(string memory name, uint256 value)
            private
            pure
            returns (IStreamGasParameterHost.GasParameterConfig memory)
        {
            return IStreamGasParameterHost.GasParameterConfig(name, value, value, 2);
        }

        function _append(address m, address p) private {
            uint64 predecessor = floor.sourceCount();
            (bytes32 s, bytes32 o, bytes32 n) = floor.sourceTransition(m, p, predecessor);
            executor.execute(
                address(floor), abi.encodeCall(floor.appendSource, (m, p, predecessor)), s, o, n
            );
        }

        function _record(uint256 nonce) private returns (bytes32 key) {
            (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(nonce);
            _settle(c, r);
            return r.settlementKey;
        }

        function _pair(uint256 nonce)
            private
            view
            returns (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r)
        {
            N.NativeSettlementCandidate memory n = _native(nonce);
            return (StreamNativeSettlementHash.accountingContext(n), _result(n));
        }

        function _native(uint256 nonce)
            private
            view
            returns (N.NativeSettlementCandidate memory n)
        {
            n.saleAdapter = address(sale);
            n.executor = address(this);
            n.sale = T.PrimarySale(
                bytes32(uint256(55)),
                keccak256("PRIMARY_SALE"),
                0,
                1,
                0,
                nonce,
                address(this),
                address(this),
                address(0xcafe),
                10,
                bytes32(uint256(56))
            );
            n.lifecycleBinding = N.SaleLifecycleBinding(1, 1);
            n.executionBinding = T.SaleExecutionBinding(0, nonce, 1, bytes32(uint256(57)));
            n.orchestrationOrder = 1;
            n.mintManager = address(manager);
            n.operationIdentityCommitment = keccak256(abi.encode("root", nonce));
            n.operationId = keccak256(abi.encode("operation", nonce));
            n.currentPolicyHash = bytes32(uint256(58));
            n.boundPolicyHash = bytes32(uint256(59));
            n.rights = T.PrimaryRights(
                bytes32(uint256(60)), address(0xbeef), 0, bytes32(uint256(61)), bytes32(uint256(62))
            );
            n.saleExecutionHash = bytes32(uint256(63));
            n.executionBinding.executionId = StreamNativeSettlementHash.executionId(n);
        }

        function _result(N.NativeSettlementCandidate memory n)
            private
            view
            returns (T.PrimarySettlementResult memory r)
        {
            r = T.PrimarySettlementResult(
                StreamNativeSettlementHash.candidateCommitment(address(recorder), n),
                StreamPrimarySettlementHash.settlementKey(
                    address(recorder), n.saleAdapter, n.executionBinding.executionId
                ),
                n.rights.profileId,
                n.rights.wallet,
                address(0),
                n.sale.amount,
                n.executor,
                n.executionBinding.executionId,
                false,
                n.operationIdentityCommitment,
                n.currentPolicyHash,
                n.boundPolicyHash
            );
        }

        function _supplement(N.NativeSettlementCandidate memory n)
            private
            returns (S.NativeSupplementalCandidate memory c, S.NativeSupplementalResult memory r)
        {
            T.PrimarySettlementResult memory previous = _result(n);
            c.originalFloor = n;
            c.executor = address(this);
            c.purchase = S.ClearingPurchaseFacts(
                previous.settlementKey,
                previous.candidateCommitment,
                n.executionBinding.saleAuthorizationDigest,
                1,
                10,
                n.operationId,
                30,
                10,
                20,
                false,
                0,
                20,
                1100,
                1
            );
            c.purchaseId = StreamNativeSupplementalHash.purchaseId(c);
            c.currentRights = n.rights;
            c.currentPrimaryPolicyHash = bytes32(uint256(66));
            r.candidateCommitment =
                StreamNativeSupplementalHash.candidateCommitment(address(recorder), c);
            r.executionId = StreamNativeSupplementalHash.executionId(address(recorder), c);
            r.settlementKey = StreamPrimarySettlementHash.settlementKey(
                address(recorder), n.saleAdapter, r.executionId
            );
            r.purchaseId = c.purchaseId;
            r.originalFloorSettlementKey = previous.settlementKey;
            r.tokenId = 10;
            r.profileId = c.currentRights.profileId;
            r.wallet = c.currentRights.wallet;
            r.amount = 10;
            r.executor = c.executor;
            r.originalOperationRoot = n.operationIdentityCommitment;
            r.originalOperationId = n.operationId;
            r.originalExpectedPrimaryPolicyHash = n.sale.expectedPrimaryPolicyHash;
            r.currentPrimaryPolicyHash = c.currentPrimaryPolicyHash;
            r.policyDrift = true;
            core.setToken(10, address(this), 2);
            sale.configure(c.purchaseId, c.purchase, r.candidateCommitment);
        }
    }
