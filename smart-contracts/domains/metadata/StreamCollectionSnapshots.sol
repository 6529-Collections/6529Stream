// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../records/StreamSnapshotSourceReads.sol";
import "../records/StreamSnapshotManifestBytes.sol";
import "../records/StreamSnapshotManifestJson.sol";
import "../records/StreamWorkRecordContext.sol";
import "../records/StreamRecordFamilies.sol";
import "../finality/StreamFinalityCoordinatorPolicyReads.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Actual admin publication of complete native source snapshots in immutable chunks.
/// @dev Snapshot and display grants are independent. Original artist/leaf/archive records are
///      references, never newly authored by this administrator. No renderer route is mutated.
contract StreamCollectionSnapshots is IStreamCollectionSnapshots, StreamGasParameterHost {
    bytes32 public constant RECORD_TYPE = keccak256("SNAPSHOT_NATIVE_ONCHAIN");
    bytes32 public constant SNAPSHOTS = keccak256("SNAPSHOTS");
    bytes32 public constant METADATA_ALL = keccak256("METADATA_ALL");
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_SNAPSHOT_READ_GAS");
    bytes32 public constant SOURCE_GAS = keccak256("6529STREAM_GGP_SNAPSHOT_SOURCE_GAS");
    bytes32 public constant EVIDENCE_GAS = keccak256("6529STREAM_GGP_SNAPSHOT_EVIDENCE_GAS");
    bytes32 public constant INVENTORY_GAS = keccak256("6529STREAM_GGP_SNAPSHOT_INVENTORY_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override metadataRouter;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable governanceAuthorityCodeHash;
    StreamSnapshotTypes.Dependencies private _fixed;
    mapping(bytes32 => StreamSnapshotTypes.Publication) private _publications;
    mapping(bytes32 => StreamSnapshotTypes.Receipt) private _receipts;
    mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) private _manifests;
    mapping(uint256 => bytes32[]) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _ids;
    mapping(uint256 => mapping(bytes32 => StreamSnapshotTypes.Lock)) private _locks;
    bool private _entered;

    constructor(
        StreamSnapshotTypes.Dependencies memory d,
        address executor,
        GasParameterConfig[4] memory gasConfigs
    ) StreamGasParameterHost(executor) {
        if (
            executor == address(0) || _registerGasParameter(gasConfigs[0]) != READ_GAS
                || _registerGasParameter(gasConfigs[1]) != SOURCE_GAS
                || _registerGasParameter(gasConfigs[2]) != EVIDENCE_GAS
                || _registerGasParameter(gasConfigs[3]) != INVENTORY_GAS
        ) {
            revert StreamSnapshotTypes.SnapshotConfiguration();
        }
        for (uint256 i; i < 4; ++i) {
            if (gasConfigs[i].failureClass != 1) {
                revert StreamSnapshotTypes.SnapshotConfiguration();
            }
        }
        core = d.targets[0];
        metadataHost = d.targets[1];
        schemaRegistry = d.targets[2];
        chunkStore = d.targets[3];
        metadataRouter = d.targets[4];
        deploymentChainId = block.chainid;
        governanceAuthorityCodeHash = abi.decode(
            StreamFinalityRouterEvidence.read(
                d.targets[1],
                abi.encodeWithSignature("executorCodeHash()"),
                32,
                gasConfigs[0].genesisValue
            ),
            (bytes32)
        );
        if (governanceAuthorityCodeHash == 0 || executor.codehash != governanceAuthorityCodeHash) {
            revert StreamSnapshotTypes.SnapshotConfiguration();
        }
        _fixed = d;
        StreamSnapshotSourceReads.bindings(dependencies());
        if (
            abi.decode(
                    StreamFinalityRouterEvidence.read(
                        metadataHost,
                        abi.encodeWithSignature("governanceAuthority()"),
                        32,
                        gasConfigs[0].genesisValue
                    ),
                    (address)
                ) != executor
        ) revert StreamSnapshotTypes.SnapshotConfiguration();
    }

    modifier guarded() {
        if (_entered) revert StreamSnapshotTypes.SnapshotSource();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamCollectionSnapshots).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function dependencies()
        public
        view
        override
        returns (StreamSnapshotTypes.Dependencies memory d)
    {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.evidenceGas = gasParameter(EVIDENCE_GAS);
        d.inventoryGas = gasParameter(INVENTORY_GAS);
    }

    function previewSnapshot(StreamSnapshotTypes.Publication calldata p, address publisher)
        external
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        _candidate(p);
        StreamSnapshotTypes.Receipt memory r = _receipt(p, publisher);
        return _assemble(p, r);
    }

    function publishSnapshot(StreamSnapshotTypes.Publication calldata p)
        external
        override
        guarded
        returns (bytes32 hash)
    {
        _candidate(p);
        StreamSnapshotTypes.Receipt memory r = _receipt(p, msg.sender);
        bytes memory canonical;
        (r.sourceHash, canonical) = _assemble(p, r);
        if (p.expectedSourceHash == 0 || p.expectedSourceHash != r.sourceHash) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        r.manifestHash = keccak256(canonical);
        r.manifestBytes = uint32(canonical.length);
        r.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SNAPSHOT_RECORD_V1"),
                deploymentChainId,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.recordHash = hash;
        bytes32 priorChain =
            p.expectedHead == 0 ? bytes32(0) : _receipts[p.expectedHead].recordChainHash;
        r.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SNAPSHOT_CHAIN_V1"),
                deploymentChainId,
                address(this),
                core,
                p.collectionId,
                priorChain,
                r.revision,
                hash
            )
        );
        StreamSnapshotManifestBytes.retain(_manifests[hash], chunkStore, canonical);
        _publications[hash] = p;
        _receipts[hash] = r;
        _ids[p.collectionId][p.snapshotId] = hash;
        _history[p.collectionId].push(hash);
        emit CollectionSnapshotPublished(
            1, p.collectionId, p.snapshotId, hash, r, p.manifestURI, _manifests[hash].pointers[0]
        );
    }

    function currentSnapshot(uint256 cid)
        public
        view
        override
        returns (StreamSnapshotTypes.Receipt memory)
    {
        return _receipts[_head(cid)];
    }

    function snapshotRecord(bytes32 hash)
        external
        view
        override
        returns (StreamSnapshotTypes.Publication memory, StreamSnapshotTypes.Receipt memory)
    {
        _known(hash);
        return (_publications[hash], _receipts[hash]);
    }

    function snapshotHash(uint256 cid, bytes32 id) external view override returns (bytes32) {
        return _receipts[_ids[cid][id]].manifestHash;
    }

    function latestSnapshotHash(uint256 cid) external view override returns (bytes32) {
        return _receipts[_head(cid)].manifestHash;
    }

    function snapshotCount(uint256 cid) external view override returns (uint256) {
        return _history[cid].length;
    }

    function snapshotRecordAt(uint256 cid, uint256 index) external view override returns (bytes32) {
        return _history[cid][index];
    }

    function snapshotManifestBytes(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return StreamSnapshotManifestBytes.read(_manifests[hash]);
    }

    function snapshotManifestPointer(uint256 cid, bytes32 id)
        external
        view
        override
        returns (address)
    {
        bytes32 hash = _ids[cid][id];
        _known(hash);
        return _manifests[hash].pointers[0];
    }

    function snapshotManifestChunkCount(bytes32 hash) external view override returns (uint256) {
        _known(hash);
        return _manifests[hash].pointers.length;
    }

    function snapshotManifestChunkAt(bytes32 hash, uint256 index)
        external
        view
        override
        returns (bytes32 chunkHash, address pointer, uint32 length)
    {
        _known(hash);
        StreamSnapshotManifestBytes.Manifest storage m = _manifests[hash];
        pointer = m.pointers[index];
        chunkHash = m.chunkHashes[index];
        uint256 size = m.byteLength - index * 8192;
        length = uint32(size > 8192 ? 8192 : size);
    }

    function requireCurrent(uint256 cid, bytes32 hash, uint64 revision)
        public
        view
        override
        returns (StreamSnapshotTypes.Receipt memory r)
    {
        _known(hash);
        r = _receipts[hash];
        if (_head(cid) != hash || r.collectionId != cid || r.revision != revision) {
            revert StreamSnapshotTypes.SnapshotLineage(hash, _head(cid));
        }
        StreamSnapshotTypes.Dependencies memory d = dependencies();
        (
            StreamSnapshotTypes.NativeFacts memory native,
            StreamFinalityCoordinatorPolicyEvidence memory entropy
        ) = _sources(d, _publications[hash]);
        // Publication already authenticated the canonical whole document and immutable provenance.
        // Revalidate every live source and retained byte without serializing those same values again.
        if (
            _sourceHash(d, native, entropy) != r.sourceHash
                || StreamSnapshotManifestBytes.requireIntact(_manifests[hash]) != r.manifestHash
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
    }

    function requireLocked(uint256 cid, bytes32 hash, uint64 revision)
        external
        view
        override
        returns (StreamSnapshotTypes.Receipt memory r)
    {
        r = requireCurrent(cid, hash, revision);
        if (
            _locks[cid][SNAPSHOTS].actionId == 0 && _locks[cid][METADATA_ALL].actionId == 0
                && _locks[cid][RECORD_TYPE].actionId == 0
        ) revert StreamSnapshotTypes.SnapshotLocked(SNAPSHOTS);
    }

    function lockTransition(uint256 cid, bytes32 lockId)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        if (lockId != SNAPSHOTS && lockId != METADATA_ALL && lockId != RECORD_TYPE) {
            revert StreamSnapshotTypes.SnapshotLocked(lockId);
        }
        StreamSnapshotTypes.Receipt memory r = currentSnapshot(cid);
        if (r.recordHash == 0 || _locks[cid][lockId].actionId != 0) {
            revert StreamSnapshotTypes.SnapshotLocked(lockId);
        }
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_SNAPSHOT_LOCK_SCOPE_V1"),
                deploymentChainId,
                address(this),
                core,
                cid,
                lockId
            )
        );
        oldHash = keccak256(abi.encode(scope, r.recordHash, r.revision, false));
        newHash = keccak256(abi.encode(scope, r.recordHash, r.revision, true));
    }

    function lockSnapshots(uint256 cid, bytes32 lockId) external override guarded {
        if (msg.sender != governanceAuthority) {
            revert StreamSnapshotTypes.SnapshotAuthority(msg.sender);
        }
        StreamSnapshotTypes.Dependencies memory d = dependencies();
        StreamSnapshotSourceReads.bindings(d);
        bool frozen = abi.decode(
            StreamFinalityRouterEvidence.read(
                core,
                abi.encodeCall(IStreamCoreCollectionView.collectionFreezeStatus, (cid)),
                32,
                d.readGas
            ),
            (bool)
        );
        if (frozen && lockId != RECORD_TYPE) revert StreamSnapshotTypes.SnapshotLocked(lockId);
        bytes32 id = _lockAuthority(cid, lockId, d.readGas);
        StreamSnapshotTypes.Receipt memory r = currentSnapshot(cid);
        requireCurrent(cid, r.recordHash, r.revision);
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        _locks[cid][lockId] =
            StreamSnapshotTypes.Lock(r.recordHash, r.revision, id, uint64(block.timestamp));
        emit CollectionSnapshotLocked(1, cid, lockId, id, r.recordHash, r.revision);
    }

    function _lockAuthority(uint256 cid, bytes32 lockId, uint256 readGas)
        private
        view
        returns (bytes32)
    {
        if (governanceAuthority.codehash != governanceAuthorityCodeHash) {
            revert StreamSnapshotTypes.SnapshotDependency(governanceAuthority);
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = lockTransition(cid, lockId);
        (
            bool executing,
            bytes32 id,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 oldState,
            bytes32 newState
        ) = abi.decode(
            StreamFinalityRouterEvidence.read(
                governanceAuthority,
                abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
                192,
                readGas
            ),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !executing || id == 0 || actionClass != 2 || actualScope != scope || oldState != oldHash
                || newState != newHash
        ) {
            revert StreamSnapshotTypes.SnapshotAuthority(msg.sender);
        }
        return id;
    }

    function snapshotLock(uint256 cid, bytes32 id)
        external
        view
        override
        returns (StreamSnapshotTypes.Lock memory)
    {
        return _locks[cid][id];
    }

    function _candidate(StreamSnapshotTypes.Publication memory p) private view {
        if (
            p.collectionId == 0 || p.snapshotId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || _ids[p.collectionId][p.snapshotId] != 0 || p.expectedRevision == type(uint64).max
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        if (
            _head(p.collectionId) != p.expectedHead
                || _history[p.collectionId].length != p.expectedRevision
        ) {
            revert StreamSnapshotTypes.SnapshotLineage(p.expectedHead, _head(p.collectionId));
        }
        if (_locks[p.collectionId][SNAPSHOTS].actionId != 0) {
            revert StreamSnapshotTypes.SnapshotLocked(SNAPSHOTS);
        }
        if (_locks[p.collectionId][METADATA_ALL].actionId != 0) {
            revert StreamSnapshotTypes.SnapshotLocked(METADATA_ALL);
        }
        if (_locks[p.collectionId][RECORD_TYPE].actionId != 0) {
            revert StreamSnapshotTypes.SnapshotLocked(RECORD_TYPE);
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "snapshotManifestURI", p.manifestURI, 2048, true
        );
    }

    function _receipt(StreamSnapshotTypes.Publication memory p, address publisher)
        private
        view
        returns (StreamSnapshotTypes.Receipt memory r)
    {
        r.collectionId = p.collectionId;
        r.snapshotId = p.snapshotId;
        r.predecessor = p.expectedHead;
        r.revision = p.expectedRevision + 1;
        r.inventoryPlan = p.inventoryPlan;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) =
            _authority(p.collectionId, StreamRecordFamilies.SNAPSHOT, publisher);
        (r.displayAuthorizationClass, r.displayGrantRevision) =
            _authority(p.collectionId, StreamRecordFamilies.IDENTITY, publisher);
        r.effectiveAt = p.effectiveAt;
        r.reasonHash = p.reasonHash;
        r.schemaDefinitionHash = StreamSnapshotDefinitions.SCHEMA_HASH;
        r.profileDefinitionHash = StreamSnapshotDefinitions.PROFILE_HASH;
        r.canonicalizationDefinitionHash = StreamSnapshotDefinitions.CANON_HASH;
    }

    function _authority(uint256 cid, bytes32 family, address actor)
        private
        view
        returns (uint8 cls, uint64 revision)
    {
        if (actor == address(0)) revert StreamSnapshotTypes.SnapshotAuthority(actor);
        uint256 cap = gasParameter(READ_GAS);
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 7 : 8;
            (bool enabled, uint64 rev) = abi.decode(
                StreamFinalityRouterEvidence.read(
                    metadataHost,
                    abi.encodeCall(
                        IStreamCollectionMetadataV1.familyWriter,
                        (i == 0 ? cid : 0, family, cls, actor)
                    ),
                    64,
                    cap
                ),
                (bool, uint64)
            );
            if (enabled && rev != 0) return (cls, rev);
        }
        revert StreamSnapshotTypes.SnapshotAuthority(actor);
    }

    function _assemble(
        StreamSnapshotTypes.Publication memory p,
        StreamSnapshotTypes.Receipt memory r
    ) private view returns (bytes32 sourceHash, bytes memory canonical) {
        StreamSnapshotTypes.Dependencies memory d = dependencies();
        (
            StreamSnapshotTypes.NativeFacts memory native,
            StreamFinalityCoordinatorPolicyEvidence memory entropy
        ) = _sources(d, p);
        sourceHash = _sourceHash(d, native, entropy);
        canonical = StreamSnapshotManifestJson.manifest(d, native, entropy, p, r);
    }

    function _sources(
        StreamSnapshotTypes.Dependencies memory d,
        StreamSnapshotTypes.Publication memory p
    )
        private
        view
        returns (
            StreamSnapshotTypes.NativeFacts memory native,
            StreamFinalityCoordinatorPolicyEvidence memory entropy
        )
    {
        _definitions(d);
        native = StreamSnapshotSourceReads.requireCurrent(d, p.collectionId);
        if (d.readGas > type(uint32).max || d.inventoryGas > type(uint32).max) {
            revert StreamSnapshotTypes.SnapshotConfiguration();
        }
        StreamFinalityCoordinatorPolicyReads.Dependencies memory policy;
        uint256[4] memory roles = [uint256(0), 1, 7, 8];
        for (uint256 i; i < 4; ++i) {
            policy.targets[i] = d.targets[roles[i]];
            policy.codeHashes[i] = d.codeHashes[roles[i]];
        }
        policy.chainId = d.chainId;
        policy.readGas = uint32(d.readGas);
        policy.inventoryGas = uint32(d.inventoryGas);
        entropy = StreamFinalityCoordinatorPolicyReads.requireCurrent(
            policy,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, p.collectionId, 0, 0),
            p.inventoryPlan
        );
        if (!entropy.allFrozen || entropy.policyCount == 0) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
    }

    function _sourceHash(
        StreamSnapshotTypes.Dependencies memory d,
        StreamSnapshotTypes.NativeFacts memory native,
        StreamFinalityCoordinatorPolicyEvidence memory entropy
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SNAPSHOT_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                native,
                entropy
            )
        );
    }

    function _definitions(StreamSnapshotTypes.Dependencies memory d) private view {
        StreamWorkRecordContext.Dependencies memory defs;
        for (uint256 i; i < 4; ++i) {
            defs.targets[i] = d.targets[i];
            defs.codeHashes[i] = d.codeHashes[i];
        }
        defs.chainId = d.chainId;
        defs.readGas = d.readGas;
        StreamWorkRecordContext.definition(
            defs,
            StreamSnapshotDefinitions.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamSnapshotDefinitions.SCHEMA_HASH,
            StreamSnapshotDefinitions.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            defs,
            StreamSnapshotDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamSnapshotDefinitions.PROFILE_HASH,
            StreamSnapshotDefinitions.PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            defs,
            StreamSnapshotDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamSnapshotDefinitions.CANON_HASH,
            StreamSnapshotDefinitions.CANON_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
    }

    function _head(uint256 cid) private view returns (bytes32) {
        uint256 length = _history[cid].length;
        return length == 0 ? bytes32(0) : _history[cid][length - 1];
    }

    function _known(bytes32 hash) private view {
        if (_receipts[hash].recordHash == 0) revert StreamSnapshotTypes.SnapshotUnknown(hash);
    }
}
