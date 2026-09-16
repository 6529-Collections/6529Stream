// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PreservationReferenceFixture.sol";
import "./PreservationSafeCallProbe.sol";
import {
    StreamBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamBundleArchiveTypes as BundleSafeT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as SafeInventoryT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as SafeChains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";

/// @dev Explicit small authenticated-inventory boundary, as in the accepted focused
/// bundle tests. It does not claim to be a complete eight-source inventory producer.
contract PreservationSafeInventoryBoundary {
    address public core;
    address public metadataHost;
    address public artifactCoverage;
    address public externalCoverage;
    SafeInventoryT.Evidence private evidence;
    SafeInventoryT.Segment[] private segments;

    constructor(
        address c,
        address m,
        address a,
        address x,
        SafeInventoryT.Evidence memory e,
        SafeInventoryT.Segment[] memory s
    ) {
        core = c;
        metadataHost = m;
        artifactCoverage = a;
        externalCoverage = x;
        evidence = e;
        for (uint256 i; i < s.length; ++i) {
            segments.push(s[i]);
        }
    }

    function inventoryEvidence(bytes32 id) external view returns (SafeInventoryT.Evidence memory) {
        require(id == evidence.planId);
        return evidence;
    }

    function inventorySegment(bytes32 id, uint64 index)
        external
        view
        returns (SafeInventoryT.Segment memory)
    {
        require(id == evidence.planId);
        return segments[index];
    }
}

contract PreservationSafeOnchainEnvironmentBoundary {
    function currentArtifactEnvironment() external pure returns (bytes32, uint64) {
        return (keccak256("explicit unchanged onchain environment boundary"), 1);
    }
}

/// @dev Actual external object/checkpoint/receipt/fixity host and original browser
/// identity, with real two-owner Safe calls. Small inventory and onchain environment
/// are typed boundaries; complete 547-role/both-backend coverage stays in accepted31.
contract StreamPreservationBundleSafeSurfaceTest is PreservationReferenceFixture {
    StreamBundleArchiveCoverage private bundle;
    PreservationSafeCallProbe private probe;
    BundleSafeT.Dependencies private d;
    SafeInventoryT.Item[2] private rows;
    SafeInventoryT.Evidence private original;
    bytes32 private packageCoverage;
    bytes32 private packageObject;

    function setUp() public override {
        super.setUp();
        bytes32 referenceRecord = _referencePublish(address(this));
        probe = new PreservationSafeCallProbe();
        packageCoverage = terms.environment.coverageHash;
        packageObject = terms.environment.objectHash;
        E.ObjectIdentity memory obj = archiveHost.objectIdentity(packageObject);
        SafeInventoryT.Item memory item;
        item.kind = SafeInventoryT.Kind.EXTERNAL_OBJECT;
        item.role = keccak256("RUNNABLE_PACKAGE");
        item.source = address(referenceHost);
        item.sourceRecord = referenceRecord;
        item.algorithm = 1;
        item.canonicalizationId = obj.canonicalizationId;
        item.digest = abi.encodePacked(obj.contentHash);
        item.byteSize = obj.byteSize;
        item.schemaId = obj.schemaId;
        item.formatId = obj.formatId;
        item.catalogId = obj.formatCatalogId;
        item.catalogHash = obj.formatCatalogHash;
        item.objectHash = packageObject;
        item.originalCoverageHash = packageCoverage;
        rows[0] = item;
        item.role = keccak256("SAME_PACKAGE_SECOND_DECLARED_ROLE");
        rows[1] = item;
        SafeInventoryT.Segment[] memory segments = new SafeInventoryT.Segment[](3);
        SafeInventoryT.Item[] memory singleton = new SafeInventoryT.Item[](1);
        singleton[0] = rows[0];
        segments[0] =
            SafeChains.segment(keccak256("first package role"), item.sourceRecord, singleton);
        segments[1] = SafeChains.segment(
            keccak256("explicit empty segment"), item.sourceRecord, new SafeInventoryT.Item[](0)
        );
        singleton[0] = rows[1];
        segments[2] =
            SafeChains.segment(keccak256("second package role"), item.sourceRecord, singleton);
        original.planId = keccak256("small explicit Safe inventory boundary");
        original.collectionId = 1;
        original.scopeSubject = keccak256("small explicit collection boundary");
        original.artistId = obj.artistId;
        original.segmentCount = 3;
        original.itemCount = 2;
        original.renderCriticalEvidenceHash =
            keccak256("small explicit current source commitment boundary");
        for (uint64 i; i < 3; ++i) {
            original.segmentChainHash = SafeChains.append(original.segmentChainHash, i, segments[i]);
        }
        address onchain = address(new PreservationSafeOnchainEnvironmentBoundary());
        address selected = address(
            new PreservationSafeInventoryBoundary(
                address(core), address(metadata), onchain, address(archiveHost), original, segments
            )
        );
        d.targets = [
            address(core),
            address(metadata),
            selected,
            onchain,
            address(archiveHost),
            address(store)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 3000000;
        bundle = new StreamBundleArchiveCoverage(d);
    }

    function safeBundleExecute(address target, bytes memory data) external returns (bool) {
        require(msg.sender == address(this), "test entry only");
        return executeSafe(archiveAgentSafe, archiveAgentKeys, target, 0, data, 0);
    }

    function _call(bytes memory data) private {
        uint256 nonce = archiveAgentSafe.nonce();
        require(this.safeBundleExecute(address(bundle), data), "actual direct Safe CALL");
        require(archiveAgentSafe.nonce() == nonce + 1, "one Safe nonce");
    }

    function _read(bytes memory data, bytes memory expected) private {
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 owners = keccak256(abi.encode(archiveAgentSafe.getOwners()));
        uint256 threshold = archiveAgentSafe.getThreshold();
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(probe),
                0,
                abi.encodeCall(
                    probe.check, (address(archiveAgentSafe), address(bundle), data, expected)
                ),
                1
            ),
            "Safe-context exact return"
        );
        require(archiveAgentSafe.nonce() == nonce + 1, "one checked bundle read nonce");
        require(
            archiveAgentSafe.getThreshold() == threshold
                && keccak256(abi.encode(archiveAgentSafe.getOwners())) == owners,
            "stateless probe preserves Safe authority"
        );
    }

    function _reject(bytes memory data) private {
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 before_ = keccak256(abi.encode(bundle.progress(original.planId)));
        (bool ok,) =
            address(this).call(abi.encodeCall(this.safeBundleExecute, (address(bundle), data)));
        require(!ok && archiveAgentSafe.nonce() == nonce, "Safe nonce rollback");
        require(
            keccak256(abi.encode(bundle.progress(original.planId))) == before_,
            "all admission progress rolls back"
        );
    }

    function _proof() private view returns (BundleSafeT.Proof memory) {
        return BundleSafeT.Proof(1, packageCoverage, packageObject);
    }

    function _complete() private returns (SafeInventoryT.BundleEvidence memory) {
        bytes32 id = original.planId;
        _call(abi.encodeCall(bundle.beginCoverage, (id)));
        _call(abi.encodeCall(bundle.coverNext, (id, rows[0], bytes32(0), _proof())));
        _call(abi.encodeCall(bundle.coverEmptySegment, (id)));
        _call(abi.encodeCall(bundle.coverNext, (id, rows[1], bytes32(0), _proof())));
        return bundle.requireCoverage(id, original.renderCriticalEvidenceHash);
    }

    function testSafeAllDeclaredBundleReadsAndExactOriginalState() public {
        SafeInventoryT.BundleEvidence memory e = _complete();
        bytes32 id = original.planId;
        _read(abi.encodeCall(bundle.core, ()), abi.encode(d.targets[0]));
        _read(abi.encodeCall(bundle.metadataHost, ()), abi.encode(d.targets[1]));
        _read(abi.encodeCall(bundle.renderCriticalInventory, ()), abi.encode(d.targets[2]));
        _read(abi.encodeCall(bundle.artifactCoverage, ()), abi.encode(d.targets[3]));
        _read(abi.encodeCall(bundle.externalCoverage, ()), abi.encode(d.targets[4]));
        _read(abi.encodeCall(bundle.deploymentChainId, ()), abi.encode(block.chainid));
        _read(abi.encodeCall(bundle.coreCodeHash, ()), abi.encode(d.codeHashes[0]));
        _read(abi.encodeCall(bundle.metadataCodeHash, ()), abi.encode(d.codeHashes[1]));
        _read(abi.encodeCall(bundle.inventoryCodeHash, ()), abi.encode(d.codeHashes[2]));
        _read(abi.encodeCall(bundle.bundleEvidence, (id)), abi.encode(e));
        _read(
            abi.encodeCall(bundle.requireCoverage, (id, original.renderCriticalEvidenceHash)),
            abi.encode(e)
        );
        _read(abi.encodeCall(bundle.dependencies, ()), abi.encode(d));
        _read(abi.encodeCall(bundle.dependencyHash, ()), abi.encode(keccak256(abi.encode(d))));
        _read(
            abi.encodeCall(bundle.PROFILE, ()),
            abi.encode(keccak256("6529STREAM_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"))
        );
        _read(abi.encodeCall(bundle.progress, (id)), abi.encode(bundle.progress(id)));
        (SafeInventoryT.Item memory item, BundleSafeT.Admission memory admitted) =
            bundle.admittedItem(id, 1);
        require(
            keccak256(abi.encode(item)) == keccak256(abi.encode(rows[1]))
                && admitted.proof.coverageHash == packageCoverage,
            "exact original item and coverage"
        );
        _read(abi.encodeCall(bundle.admittedItem, (id, uint64(1))), abi.encode(item, admitted));
        _read(abi.encodeCall(bundle.requireFullCurrentCoverage, (id)), abi.encode(e));
        _reject(abi.encodeCall(bundle.requireCoverage, (id, bytes32(uint256(1)))));
        _reject(abi.encodeCall(bundle.admittedItem, (id, uint64(2))));
    }

    function testSafeBundleFailureAtomicitySameSignedRetryAndCompleteRefresh() public {
        bytes32 id = original.planId;
        _call(abi.encodeCall(bundle.beginCoverage, (id)));
        _reject(abi.encodeCall(bundle.coverEmptySegment, (id)));
        _reject(abi.encodeCall(bundle.coverNext, (id, rows[1], bytes32(0), _proof())));
        _call(abi.encodeCall(bundle.coverNext, (id, rows[0], bytes32(0), _proof())));
        _call(abi.encodeCall(bundle.coverEmptySegment, (id)));
        bytes memory data = abi.encodeCall(bundle.coverNext, (id, rows[1], bytes32(0), _proof()));
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(bundle), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory transaction = abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(bundle),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(archiveAgentKeys, digest)
            )
        );
        _extRecordFixity(originalFirstReceipts[0], 2, false);
        bytes32 progress = keccak256(abi.encode(bundle.progress(id)));
        (bool ok,) = address(archiveAgentSafe).call(transaction);
        require(
            !ok && archiveAgentSafe.nonce() == nonce
                && progress == keccak256(abi.encode(bundle.progress(id))),
            "late archive failure is atomic"
        );
        _extRecordFixity(originalFirstReceipts[0], 1, true);
        bytes memory result;
        (ok, result) = address(archiveAgentSafe).call(transaction);
        require(
            ok && result.length == 32 && abi.decode(result, (bool))
                && archiveAgentSafe.nonce() == nonce + 1,
            "identical signed Safe retry"
        );
        SafeInventoryT.BundleEvidence memory e = bundle.bundleEvidence(id);
        _reject(abi.encodeCall(bundle.requireCoverage, (id, original.renderCriticalEvidenceHash)));
        _read(abi.encodeCall(bundle.bundleEvidence, (id)), abi.encode(e));
        _call(abi.encodeCall(bundle.beginRefresh, (id)));
        bytes32 key = bundle.beginRefresh(id);
        _reject(abi.encodeCall(bundle.refreshNext, (id, uint64(1))));
        _call(abi.encodeCall(bundle.refreshNext, (id, uint64(0))));
        _call(abi.encodeCall(bundle.beginRefresh, (id)));
        require(bundle.refresh(key).nextIndex == 1, "permissionless begin cannot reset progress");
        _reject(abi.encodeCall(bundle.requireCoverage, (id, original.renderCriticalEvidenceHash)));
        _call(abi.encodeCall(bundle.refreshNext, (id, uint64(1))));
        require(bundle.refresh(key).complete, "every original item refreshed");
        _read(abi.encodeCall(bundle.refresh, (key)), abi.encode(bundle.refresh(key)));
        _read(
            abi.encodeCall(bundle.requireCoverage, (id, original.renderCriticalEvidenceHash)),
            abi.encode(e)
        );
        _read(abi.encodeCall(bundle.requireFullCurrentCoverage, (id)), abi.encode(e));
    }

    function testSafeExternalEnvironmentExactWordsHealthAndGraphRetry() public {
        bytes memory input = abi.encodeCall(archiveHost.currentExternalArtifactEnvironment, ());
        (bytes32 environment, uint64 revision) = archiveHost.currentExternalArtifactEnvironment();
        _externalRead(input, abi.encode(environment, revision));
        _extRole(address(archiveFixitySafe), false);
        (bytes32 same, uint64 sameRevision) = archiveHost.currentExternalArtifactEnvironment();
        require(
            same == environment && sameRevision == revision,
            "role revocation does not rewrite old archive semantics"
        );
        _externalRead(input, abi.encode(environment, revision));
        _extRole(address(archiveFixitySafe), true);
        _extRecordFixity(originalFirstReceipts[0], 1, false);
        (same, sameRevision) = archiveHost.currentExternalArtifactEnvironment();
        require(
            same == environment && sameRevision == revision + 1,
            "every successful passing observation increments health"
        );
        _externalRead(input, abi.encode(environment, revision + 1));

        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(archiveHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory transaction = abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(archiveHost),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(archiveAgentKeys, digest)
            )
        );
        bytes32 kind = keccak256("MODULE_REGISTRY");
        address prior = core.selected(kind);
        core.setPointer(kind, address(0));
        (bool ok,) = address(archiveAgentSafe).call(transaction);
        require(
            !ok && archiveAgentSafe.nonce() == nonce, "invalid current graph rolls back Safe nonce"
        );
        require(
            archiveHost.coverage(packageCoverage).objectHash == packageObject,
            "original archive evidence survives current graph failure"
        );
        core.setPointer(kind, prior);
        bytes memory result;
        (ok, result) = address(archiveAgentSafe).call(transaction);
        require(
            ok && result.length == 32 && abi.decode(result, (bool))
                && archiveAgentSafe.nonce() == nonce + 1,
            "exact signed current graph retry"
        );
        _externalRead(input, abi.encode(environment, revision + 1));
    }

    function _externalRead(bytes memory input, bytes memory expected) private {
        require(expected.length == 64, "canonical two-word expectation");
        uint256 nonce = archiveAgentSafe.nonce();
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(probe),
                0,
                abi.encodeCall(
                    probe.check, (address(archiveAgentSafe), address(archiveHost), input, expected)
                ),
                1
            ),
            "actual Safe-context environment CALL"
        );
        require(archiveAgentSafe.nonce() == nonce + 1, "one environment read nonce");
    }
}
