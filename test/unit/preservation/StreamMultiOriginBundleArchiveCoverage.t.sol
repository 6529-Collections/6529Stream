// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamMultiOriginBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginBundleArchiveCoverage.sol";
import {
    StreamMultiOriginScopedBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedBundleArchiveCoverage.sol";
import {
    StreamBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";

interface MultiOriginCoverageVm {
    function etch(address target, bytes calldata code) external;
}

/// @dev These are explicit inventory/provenance and Artifact environment boundaries, not
/// evidence that the Artist worker, current selection, lineage or full Finality graph passed.
contract MultiOriginCoverageMarker { }

contract MultiOriginCoverageStop {
    constructor(bytes memory payload) {
        bytes memory runtime = bytes.concat(hex"00", payload);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}

contract MultiOriginCoverageArchiveBoundary {
    struct Saved {
        bytes payload;
        address pointer;
    }
    mapping(bytes32 => Saved) private _saved;

    function save(bytes32 id, bytes memory payload) external {
        _saved[id] = Saved(payload, address(new MultiOriginCoverageStop(payload)));
    }

    function artistEvidenceBytesV2(bytes32 id, uint64 version)
        external
        view
        returns (bytes memory)
    {
        require(version == 1 && _saved[id].pointer != address(0));
        return _saved[id].payload;
    }

    function artistEvidenceMetadataV2(bytes32 id, uint64 version)
        external
        view
        returns (bytes32, address, uint32, uint64)
    {
        require(version == 1 && _saved[id].pointer != address(0));
        Saved storage s = _saved[id];
        return (keccak256(s.payload), s.pointer, uint32(s.payload.length), 1);
    }

    function pointer(bytes32 id) external view returns (address) {
        return _saved[id].pointer;
    }
}

contract MultiOriginCoverageEnvironmentBoundary {
    uint64 public epoch = 1;

    function currentArtifactEnvironment() external view returns (bytes32, uint64) {
        return (keccak256("explicit Artifact environment boundary"), epoch);
    }

    function currentExternalArtifactEnvironment() external view returns (bytes32, uint64) {
        return (keccak256("explicit external environment boundary"), epoch);
    }

    function advance() external {
        ++epoch;
    }
}

abstract contract MultiOriginCoverageInventoryBoundary {
    address public core;
    address public metadataHost;
    address public artifactCoverage;
    address public externalCoverage;
    bytes32 public originProfile;
    bytes32 public dependencyHash = keccak256("explicit dependency boundary");
    O.Dependencies private _originDependencies;
    O.Origin[] private _origins;
    mapping(bytes32 => O.RecordOrigin) private _facts;
    T.Segment private _segment;
    T.Evidence internal _e;
    StreamFinalityScope internal _scope;
    bytes32 private _root;
    uint256 private _count;
    bool public staleSource;
    bool public malformedFact;

    constructor(B.Dependencies memory d, O.Dependencies memory o, bytes32 profile) {
        core = d.targets[0];
        metadataHost = d.targets[1];
        artifactCoverage = d.targets[3];
        externalCoverage = d.targets[4];
        _originDependencies = o;
        originProfile = profile;
    }

    function configure(
        T.Evidence memory e,
        T.Segment memory segment,
        O.Origin[] memory origins,
        T.Item[] memory items,
        O.RecordOrigin[] memory facts,
        StreamFinalityScope memory scope
    ) external {
        _e = e;
        _segment = segment;
        _scope = scope;
        delete _origins;
        bytes32 chain;
        for (uint256 i; i < origins.length; ++i) {
            _origins.push(origins[i]);
            chain = O.appendOrigin(chain, i, origins[i]);
        }
        _count = origins.length;
        _root = O.sealedOriginSetHash(_count, chain);
        for (uint256 i; i < items.length; ++i) {
            _facts[Chains.itemHash(items[i])] = facts[i];
        }
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            _e.renderCriticalEvidenceHash = keccak256(
                abi.encode(
                    originProfile, block.chainid, address(this), dependencyHash, e, _root, _count
                )
            );
        } else {
            _e.renderCriticalEvidenceHash = keccak256(
                abi.encode(
                    originProfile,
                    block.chainid,
                    address(this),
                    dependencyHash,
                    Scoped.Evidence(scope, e),
                    _root,
                    _count
                )
            );
        }
    }

    function originDependencies() external view returns (O.Dependencies memory) {
        return _originDependencies;
    }

    function originCount(bytes32) external view returns (uint256) {
        return _count;
    }

    function originSetHash(bytes32) external view returns (bytes32) {
        return _root;
    }

    function originAt(bytes32, uint256 index) external view returns (O.Origin memory) {
        return _origins[index];
    }

    function artistArchiveOrigin(bytes32 id, bytes32 itemHash)
        external
        view
        returns (O.RecordOrigin memory)
    {
        if (malformedFact) {
            assembly ("memory-safe") {
                mstore(0, 0)
                return(0, 32)
            }
        }
        require(id == _e.planId && _facts[itemHash].role != 0);
        return _facts[itemHash];
    }

    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        require(id == _e.planId && index == 0);
        return _segment;
    }

    function setFact(bytes32 itemHash, O.RecordOrigin memory fact) external {
        _facts[itemHash] = fact;
    }

    function setOrigin(uint256 index, O.Origin memory origin) external {
        _origins[index] = origin;
    }

    function setRoot(bytes32 root) external {
        _root = root;
    }

    function setCount(uint256 count) external {
        _count = count;
    }

    function setProfile(bytes32 profile) external {
        originProfile = profile;
    }

    function setWorker(O.Dependencies memory o) external {
        _originDependencies = o;
    }

    function setStaleSource() external {
        staleSource = true;
    }

    function setMalformedFact(bool malformed) external {
        malformedFact = malformed;
    }

    function requireCurrent() external view {
        require(!staleSource, "independent source check");
    }

    function evidenceHash() external view returns (bytes32) {
        return _e.renderCriticalEvidenceHash;
    }
}

contract MultiOriginCollectionInventoryBoundary is MultiOriginCoverageInventoryBoundary {
    constructor(B.Dependencies memory d, O.Dependencies memory o)
        MultiOriginCoverageInventoryBoundary(d, o, O.INVENTORY_PROFILE)
    { }

    function inventoryEvidence(bytes32 id) external view returns (T.Evidence memory) {
        require(id == _e.planId);
        return _e;
    }
}

contract MultiOriginScopedInventoryBoundary is MultiOriginCoverageInventoryBoundary {
    constructor(B.Dependencies memory d, O.Dependencies memory o)
        MultiOriginCoverageInventoryBoundary(d, o, O.SCOPED_INVENTORY_PROFILE)
    { }

    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory) {
        require(id == _e.planId);
        return Scoped.Evidence(_scope, _e);
    }
}

contract StreamMultiOriginBundleArchiveCoverageTest {
    MultiOriginCoverageVm private constant vm =
        MultiOriginCoverageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    MultiOriginCoverageArchiveBoundary private archiveA;
    MultiOriginCoverageArchiveBoundary private archiveB;
    MultiOriginCoverageEnvironmentBoundary private externalEnvironment;
    MultiOriginCollectionInventoryBoundary private inventory;
    StreamMultiOriginBundleArchiveCoverage private coverage;
    B.Dependencies private d;
    O.Dependencies private od;
    T.Item[] private items;
    O.RecordOrigin[] private facts;
    O.Origin[] private origins;
    bytes32[] private suffix;
    T.Evidence private evidence;
    T.Segment private segment;
    bytes32 private constant PLAN = keccak256("explicit multi-origin inventory boundary");

    function setUp() public {
        address marker = address(new MultiOriginCoverageMarker());
        archiveA = new MultiOriginCoverageArchiveBoundary();
        archiveB = new MultiOriginCoverageArchiveBoundary();
        externalEnvironment = new MultiOriginCoverageEnvironmentBoundary();
        d.targets[0] = marker;
        d.targets[1] = marker;
        d.targets[3] = address(new MultiOriginCoverageEnvironmentBoundary());
        d.targets[4] = address(externalEnvironment);
        d.targets[5] = address(archiveB);
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 2000000;
        od = O.Dependencies(marker, marker.codehash, 4000000, O.PROFILE);
        inventory = new MultiOriginCollectionInventoryBoundary(d, od);
        d.targets[2] = address(inventory);
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        coverage = new StreamMultiOriginBundleArchiveCoverage(d, od, O.INVENTORY_PROFILE);
        origins.push(_origin(address(archiveA), address(0xA)));
        origins.push(_origin(address(archiveB), address(0xB)));
        _append(0, 24, keccak256("A original publication"));
        _append(1, 17, keccak256("B native content consent"));
        _append(0, 24, keccak256("same A bytes in another role"));
        T.Item memory absent;
        absent.kind = T.Kind.ABSENT;
        absent.role = keccak256("explicit absent field");
        absent.source = marker;
        absent.sourceRecord = keccak256("absent source");
        items.push(absent);
        facts.push();
        T.Item[] memory all = items;
        segment = Chains.segment(keccak256("boundary segment"), keccak256("boundary witness"), all);
        for (uint256 i; i < all.length; ++i) {
            suffix.push(0);
        }
        for (uint256 i = all.length - 1; i != 0; --i) {
            suffix[i - 1] =
                Chains.link(segment.key, uint64(all.length), uint64(i), all[i], suffix[i]);
        }
        evidence.planId = PLAN;
        evidence.collectionId = 1;
        evidence.artistId = keccak256("artist");
        evidence.scopeSubject = keccak256("collection boundary");
        evidence.sourceContextHash = keccak256("fixed source context");
        evidence.segmentCount = 1;
        evidence.itemCount = uint64(items.length);
        evidence.segmentChainHash = Chains.append(0, 0, segment);
        inventory.configure(
            evidence,
            segment,
            origins,
            items,
            facts,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
    }

    function _origin(address archive, address registry) private view returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.registry = registry;
        o.environment.coordinator = address(uint160(registry) + 1);
        o.environment.archive = archive;
        o.environment.core = d.targets[0];
        o.environment.suiteConfigurationHash = keccak256(abi.encode(registry));
        o.registryCodeHash = keccak256("explicit original registry runtime boundary");
        o.coordinatorCodeHash = keccak256("explicit original coordinator runtime boundary");
        o.archiveCodeHash = archive.codehash;
    }

    function _append(uint256 origin, uint16 operation, bytes32 role) private {
        O.RecordOrigin memory f;
        f.producer = origins[origin];
        f.actor = address(0x6529);
        f.occurrence.position.point.environmentHash = RH.originHash(f.producer.environment);
        f.occurrence.position.point.ownerIndex = operation == 17 ? 6 : 4;
        f.occurrence.position.point.ownerRevision = 9;
        f.occurrence.receipt.operation = operation;
        f.occurrence.receipt.artistId = keccak256("artist");
        f.occurrence.receipt.collectionId = 1;
        f.occurrence.receipt.recordHash =
            keccak256(abi.encode("actual receipt boundary", operation));
        if (origin == 0) {
            f.importCommitment = keccak256("complete import boundary");
            f.importedAtRevision = 2;
        }
        f.semanticRecordHash = keccak256("exact typed semantic tuple boundary");
        f.role = role;
        f.sourceContextHash = keccak256("fixed source context");
        bytes memory payload = abi.encode("exact original bytes", operation);
        bytes32 id = O.evidenceId(f);
        MultiOriginCoverageArchiveBoundary(f.producer.environment.archive).save(id, payload);
        T.Item memory item;
        item.kind = T.Kind.STATE_BUNDLE;
        item.role = role;
        item.source = f.producer.environment.archive;
        item.sourceRecord = id;
        item.sourceIndex = 1;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(keccak256(payload));
        item.byteSize = uint64(payload.length);
        item.provenanceHash = O.recordOriginHash(f);
        items.push(item);
        facts.push(f);
    }

    function _complete() private returns (T.BundleEvidence memory) {
        coverage.beginCoverage(PLAN);
        for (uint64 i; i < items.length; ++i) {
            coverage.coverNext(PLAN, items[i], suffix[i], B.Proof(0, 0, 0));
        }
        return coverage.requireCoverage(PLAN, inventory.evidenceHash());
    }

    function _reject(address target, bytes memory input, bytes4 selector) private {
        (bool ok, bytes memory raw) = target.call(input);
        require(!ok && raw.length >= 4 && bytes4(raw) == selector, "exact rejection required");
    }

    function testTwoOriginalArchivesAndRepeatedRoleRetainExactBytesAndFacts() public {
        T.BundleEvidence memory result = _complete();
        require(result.itemCount == 4 && result.bundleCoverageHash != 0);
        require(coverage.admittedOriginHash(PLAN, 0) == O.recordOriginHash(facts[0]));
        require(coverage.admittedOriginHash(PLAN, 0) != coverage.admittedOriginHash(PLAN, 2));
        require(coverage.admittedOriginHash(PLAN, 3) == 0);
        require(
            coverage.requireFullCurrentCoverage(PLAN).bundleCoverageHash
                == result.bundleCoverageHash
        );
        require(
            coverage.dependencies().targets[5] == address(archiveB),
            "routing never rewrites fixed frame"
        );
        StreamBundleArchiveCoverage old = new StreamBundleArchiveCoverage(d);
        old.beginCoverage(PLAN);
        _reject(
            address(old),
            abi.encodeCall(old.coverNext, (PLAN, items[0], suffix[0], B.Proof(0, 0, 0))),
            T.InvalidInventoryItem.selector
        );
    }

    function testUnadmittedFactAndChangedActorCannotRouteBeforeProgress() public {
        coverage.beginCoverage(PLAN);
        O.RecordOrigin memory f = facts[0];
        f.actor = address(0xBAD);
        inventory.setFact(Chains.itemHash(items[0]), f);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, items[0], suffix[0], B.Proof(0, 0, 0))),
            O.InvalidArchiveOrigin.selector
        );
        require(coverage.progress(PLAN).itemCount == 0);
        f = facts[0];
        f.role = 0;
        inventory.setFact(Chains.itemHash(items[0]), f);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, items[0], suffix[0], B.Proof(0, 0, 0))),
            T.InventoryRead.selector
        );
        inventory.setFact(Chains.itemHash(items[0]), facts[0]);
        coverage.coverNext(PLAN, items[0], suffix[0], B.Proof(0, 0, 0));
    }

    function testWrongOccurrenceRoleContextAndOwnerCannotAdmit() public {
        coverage.beginCoverage(PLAN);
        for (uint256 i; i < 5; ++i) {
            O.RecordOrigin memory f = facts[0];
            if (i == 0) f.role = keccak256("wrong role");
            if (i == 1) f.sourceContextHash = keccak256("wrong context");
            if (i == 2) f.occurrence.position.point.ownerIndex = 6;
            if (i == 3) f.occurrence.receipt.recordHash = keccak256("wrong record");
            if (i == 4) f.occurrence.position.point.environmentHash = keccak256("other era");
            inventory.setFact(Chains.itemHash(items[0]), f);
            _reject(
                address(coverage),
                abi.encodeCall(coverage.coverNext, (PLAN, items[0], suffix[0], B.Proof(0, 0, 0))),
                O.InvalidArchiveOrigin.selector
            );
        }
        require(coverage.progress(PLAN).itemCount == 0);
    }

    function testSegmentOrderIsCheckedBeforeOriginOrArchiveRead() public {
        inventory.setFact(Chains.itemHash(items[0]), facts[1]);
        coverage.beginCoverage(PLAN);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, items[1], suffix[0], B.Proof(0, 0, 0))),
            T.InvalidInventorySegment.selector
        );
        require(coverage.progress(PLAN).itemCount == 0);
    }

    function testSealedRootDuplicateOriginAndBoundFailClosed() public {
        inventory.setRoot(0);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
        inventory.setOrigin(1, origins[0]);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
        inventory.setCount(18);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.ArchiveOriginLimit.selector
        );
    }

    function testWorkerReciprocityAndProfileRejectBeforeAdmission() public {
        inventory.setProfile(O.SCOPED_INVENTORY_PROFILE);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
        inventory.setProfile(O.INVENTORY_PROFILE);
        O.Dependencies memory changed = od;
        changed.originGas += 1;
        inventory.setWorker(changed);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
    }

    function testRefreshUsesOriginalRoutingAndExactStoredFactHash() public {
        bytes32 original = _complete().bundleCoverageHash;
        externalEnvironment.advance();
        _reject(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, inventory.evidenceHash())),
            T.InventoryIncomplete.selector
        );
        bytes32 key = coverage.beginRefresh(PLAN);
        O.RecordOrigin memory f = facts[0];
        f.semanticRecordHash = keccak256("changed retained tuple");
        inventory.setFact(Chains.itemHash(items[0]), f);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.refreshNext, (PLAN, uint64(0))),
            O.InvalidArchiveOrigin.selector
        );
        require(coverage.refresh(key).nextIndex == 0);
        inventory.setFact(Chains.itemHash(items[0]), facts[0]);
        for (uint64 i; i < items.length; ++i) {
            coverage.refreshNext(PLAN, i);
        }
        require(
            coverage.requireCoverage(PLAN, inventory.evidenceHash()).bundleCoverageHash == original
        );
    }

    function testArchiveRuntimeAndFullStopDiagnosticRemainSeparateFromCachedCoverage() public {
        bytes32 original = _complete().bundleCoverageHash;
        address pointer = archiveA.pointer(items[0].sourceRecord);
        vm.etch(pointer, hex"0001");
        require(
            coverage.requireCoverage(PLAN, inventory.evidenceHash()).bundleCoverageHash == original
        );
        _reject(
            address(coverage),
            abi.encodeCall(coverage.requireFullCurrentCoverage, (PLAN)),
            T.InvalidInventoryItem.selector
        );
        vm.etch(address(archiveA), hex"00");
        _reject(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, inventory.evidenceHash())),
            T.InventoryRead.selector
        );
    }

    function testArchiveLivenessDoesNotHideSeparateSourceCurrentness() public {
        bytes32 original = _complete().bundleCoverageHash;
        inventory.setStaleSource();
        require(
            coverage.requireCoverage(PLAN, inventory.evidenceHash()).bundleCoverageHash == original
        );
        (bool ok,) = address(inventory).staticcall(abi.encodeCall(inventory.requireCurrent, ()));
        require(!ok);
    }

    function testScopedAdapterKeepsExactScopeAndDistinctProfile() public {
        MultiOriginScopedInventoryBoundary scopedInventory =
            new MultiOriginScopedInventoryBoundary(d, od);
        B.Dependencies memory sd = d;
        sd.targets[2] = address(scopedInventory);
        sd.codeHashes[2] = address(scopedInventory).codehash;
        StreamMultiOriginScopedBundleArchiveCoverage scoped =
            new StreamMultiOriginScopedBundleArchiveCoverage(sd, od, O.SCOPED_INVENTORY_PROFILE);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 2, 0);
        T.Evidence memory se = evidence;
        se.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, d.targets[0], scope);
        se.tokenCount = 1;
        se.tokenInventoryHash = keccak256("exact token inventory boundary");
        scopedInventory.configure(se, segment, origins, items, facts, scope);
        scoped.beginCoverage(PLAN);
        for (uint64 i; i < items.length; ++i) {
            scoped.coverNext(PLAN, items[i], suffix[i], B.Proof(0, 0, 0));
        }
        Scoped.BundleEvidence memory result =
            scoped.requireCoverage(scope, PLAN, scopedInventory.evidenceHash());
        require(result.coverage.itemCount == 4 && scoped.PROFILE() != coverage.PROFILE());
        scope.tokenId = 3;
        _reject(
            address(scoped),
            abi.encodeCall(scoped.requireCoverage, (scope, PLAN, scopedInventory.evidenceHash())),
            T.InventoryIncomplete.selector
        );
    }

    function testSeventeenOriginTableIsAcceptedAndEighteenthRejected() public {
        for (uint256 i = origins.length; i < 17; ++i) {
            origins.push(_origin(address(archiveB), address(uint160(0x100 + i))));
        }
        inventory.configure(
            evidence,
            segment,
            origins,
            items,
            facts,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        require(_complete().itemCount == 4);
        inventory.setCount(18);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, inventory.evidenceHash())),
            O.ArchiveOriginLimit.selector
        );
    }

    function testConstructorFixedPolicyProfileHasSeparateDependencyAndExactSeal() public {
        StreamMultiOriginBundleArchiveCoverage policy =
            new StreamMultiOriginBundleArchiveCoverage(d, od, O.POLICY_INVENTORY_PROFILE);
        require(policy.dependencyHash() != coverage.dependencyHash());
        _reject(
            address(policy),
            abi.encodeCall(policy.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
        inventory.setProfile(O.POLICY_INVENTORY_PROFILE);
        inventory.configure(
            evidence,
            segment,
            origins,
            items,
            facts,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        policy.beginCoverage(PLAN);
        for (uint64 i; i < items.length; ++i) {
            policy.coverNext(PLAN, items[i], suffix[i], B.Proof(0, 0, 0));
        }
        require(policy.requireCoverage(PLAN, inventory.evidenceHash()).itemCount == 4);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.beginCoverage, (PLAN)),
            O.InvalidArchiveOrigin.selector
        );
    }

    function testMalformedFactAndChangedBytesRollbackThenIdenticalRetry() public {
        coverage.beginCoverage(PLAN);
        inventory.setMalformedFact(true);
        _reject(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, items[0], suffix[0], B.Proof(0, 0, 0))),
            T.InventoryRead.selector
        );
        inventory.setMalformedFact(false);
        coverage.coverNext(PLAN, items[0], suffix[0], B.Proof(0, 0, 0));
        bytes memory original = archiveB.artistEvidenceBytesV2(items[1].sourceRecord, 1);
        archiveB.save(items[1].sourceRecord, bytes("altered original bytes"));
        bytes memory next =
            abi.encodeCall(coverage.coverNext, (PLAN, items[1], suffix[1], B.Proof(0, 0, 0)));
        _reject(address(coverage), next, T.InvalidInventoryItem.selector);
        require(coverage.progress(PLAN).itemCount == 1);
        archiveB.save(items[1].sourceRecord, original);
        (bool ok,) = address(coverage).call(next);
        require(ok && coverage.progress(PLAN).itemCount == 2);
    }
}
