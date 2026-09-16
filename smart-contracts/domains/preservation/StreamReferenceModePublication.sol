// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import { StreamReferenceModeProof } from "./StreamReferenceModeProof.sol";
import { StreamReferenceModeDefinitionsRead } from "./StreamReferenceModeDefinitionsRead.sol";
import { StreamReferenceModeDefinitions } from "../records/StreamReferenceModeDefinitions.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "./StreamReferenceRenderSourceReads.sol";
import "./StreamReferenceRenderRecordReads.sol";
import "./StreamReferenceRenderPreparation.sol";
import "../records/StreamReferenceManifestJson.sol";
import "../records/StreamReferenceRenderDefinitionReads.sol";
import "../records/StreamSnapshotManifestBytes.sol";
import "../records/StreamRecordFamilies.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Original non-byte-exact reference observations with exact typed mode evidence.
/// @dev Publishing never changes artwork bytes. Bulk runtime objects remain externally archived;
///      complete original canonical manifests and ABI witnesses use actual immutable Store chunks.
contract StreamReferenceModePublication is
    IStreamReferenceModePublication,
    IStreamArtworkFinalityComponent,
    IStreamArtworkScopedFinalityComponent,
    IStreamModule,
    StreamGasParameterHost
{
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_REFERENCE_READ_GAS");
    bytes32 public constant SOURCE_GAS = keccak256("6529STREAM_GGP_REFERENCE_SOURCE_GAS");
    bytes32 public constant SNAPSHOT_GAS = keccak256("6529STREAM_GGP_REFERENCE_SNAPSHOT_GAS");
    bytes32 public constant ARCHIVE_GAS = keccak256("6529STREAM_GGP_REFERENCE_ARCHIVE_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override metadataRouter;
    address public immutable override snapshots;
    address public immutable override archiveCoverage;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable executorCodeHash;
    StreamReferenceRenderTypes.Dependencies private _fixed;
    mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) private _publications;
    mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) private _payloads;
    mapping(bytes32 => StreamReferenceRenderTypes.Receipt) private _receipts;
    mapping(uint256 => bytes32[]) private _history;
    mapping(uint256 => mapping(bytes32 => bool)) private _ids;
    mapping(uint256 => StreamReferenceRenderTypes.Lock) private _locks;
    bool private _entered;
    mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) private _fileInventories;
    mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) private _modeEvidence;
    StreamReferenceModeTypes.Dependencies private _modeBindings;
    mapping(bytes32 => StreamReferenceModeTypes.Facts) private _modeFacts;

    constructor(
        StreamReferenceRenderTypes.Dependencies memory d,
        address executor,
        GasParameterConfig[4] memory configs,
        StreamReferenceModeTypes.Dependencies memory modeBindings
    ) StreamGasParameterHost(executor) {
        if (
            _registerGasParameter(configs[0]) != READ_GAS
                || _registerGasParameter(configs[1]) != SOURCE_GAS
                || _registerGasParameter(configs[2]) != SNAPSHOT_GAS
                || _registerGasParameter(configs[3]) != ARCHIVE_GAS
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        for (uint256 i; i < 4; ++i) {
            if (configs[i].failureClass != 1) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
        }
        _fixed = d;
        _modeBindings = modeBindings;
        core = d.targets[0];
        metadataHost = d.targets[1];
        metadataRouter = d.targets[4];
        snapshots = d.targets[5];
        archiveCoverage = d.targets[6];
        deploymentChainId = block.chainid;
        executorCodeHash = abi.decode(
            StreamFinalityRouterEvidence.read(
                metadataHost,
                abi.encodeWithSignature("executorCodeHash()"),
                32,
                configs[0].genesisValue
            ),
            (bytes32)
        );
        if (
            executorCodeHash == 0 || executor.codehash != executorCodeHash
                || abi.decode(
                        StreamFinalityRouterEvidence.read(
                            metadataHost,
                            abi.encodeWithSignature("governanceAuthority()"),
                            32,
                            configs[0].genesisValue
                        ),
                        (address)
                    ) != executor
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        StreamReferenceRenderSourceReads.validateDependencies(dependencies());
    }
    modifier guarded() {
        if (_entered) revert StreamReferenceRenderTypes.InvalidReferenceRender();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamReferenceModePublication).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId
            || id == type(IStreamModule).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function dependencies()
        public
        view
        override
        returns (StreamReferenceRenderTypes.Dependencies memory d)
    {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.snapshotGas = gasParameter(SNAPSHOT_GAS);
        d.archiveGas = gasParameter(ARCHIVE_GAS);
    }

    function modeDependencies()
        external
        view
        override
        returns (StreamReferenceModeTypes.Dependencies memory)
    {
        return _modeBindings;
    }

    function previewReference(StreamReferenceRenderTypes.Publication memory, address)
        external
        pure
        override
        returns (bytes32, bytes memory)
    {
        revert StreamReferenceModeTypes.InvalidModeEvidence();
    }

    function publishReference(StreamReferenceRenderTypes.Publication memory)
        external
        pure
        override
        returns (bytes32)
    {
        revert StreamReferenceModeTypes.InvalidModeEvidence();
    }

    function modeContextHash(StreamReferenceRenderTypes.Publication calldata p)
        external
        view
        override
        returns (bytes32)
    {
        return StreamReferenceModeProof.contextHash(dependencies(), p);
    }

    function previewModeReference(
        StreamReferenceRenderTypes.Publication calldata original,
        StreamReferenceModeTypes.Evidence calldata originalEvidence,
        address recorder
    ) external view override returns (bytes32 sourceHash, bytes memory canonical) {
        StreamReferenceRenderTypes.Publication memory p = original;
        _candidate(p);
        StreamReferenceRenderTypes.Receipt memory r = _receipt(p, recorder);
        StreamReferenceRenderTypes.Dependencies memory d = dependencies();
        StreamReferenceRenderTypes.SourceFacts memory f =
            StreamReferenceRenderSourceReads.requireModeSourceInputs(
                d, StreamReferenceRenderSourceReads.project(p), false
            );
        StreamReferenceModeTypes.Facts memory mode = StreamReferenceModeProof.requireEvidence(
            d, _modeBindings, p, f, originalEvidence, false
        );
        sourceHash = StreamReferenceModeProof.sourceHash(d, _modeBindings, f, mode);
        p.expectedSourcesHash = sourceHash;
        r.sourcesHash = sourceHash;
        canonical = StreamReferenceModeProof.payload(
            p,
            r,
            f,
            originalEvidence,
            mode,
            StreamReferenceRenderPreparation.environment(_fileInventories, p.environment)
        );
    }

    function publishModeReference(
        StreamReferenceRenderTypes.Publication calldata original,
        StreamReferenceModeTypes.Evidence calldata originalEvidence
    ) external override guarded returns (bytes32 hash) {
        StreamReferenceRenderTypes.Publication memory p = original;
        StreamReferenceModeTypes.Evidence memory evidence = originalEvidence;
        _candidate(p);
        StreamReferenceRenderTypes.Receipt memory r = _receipt(p, msg.sender);
        StreamReferenceRenderTypes.Dependencies memory d = dependencies();
        _definitions(d);
        StreamReferenceRenderTypes.SourceFacts memory f =
            StreamReferenceRenderSourceReads.requireModeSourceInputs(
                d, StreamReferenceRenderSourceReads.project(p), false
            );
        StreamReferenceModeTypes.Facts memory mode =
            StreamReferenceModeProof.requireEvidence(d, _modeBindings, p, f, evidence, false);
        r.sourcesHash = StreamReferenceModeProof.sourceHash(d, _modeBindings, f, mode);
        if (p.expectedSourcesHash == 0 || p.expectedSourcesHash != r.sourcesHash) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bytes memory canonical = StreamReferenceModeProof.payload(
            p,
            r,
            f,
            evidence,
            mode,
            StreamReferenceRenderPreparation.environment(_fileInventories, p.environment)
        );
        r.payloadHash = keccak256(canonical);
        r.payloadBytes = uint32(canonical.length);
        r.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
                deploymentChainId,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.recordHash = hash;
        r.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_CHAIN_V1"),
                deploymentChainId,
                address(this),
                core,
                p.collectionId,
                p.expectedHead == 0 ? bytes32(0) : _receipts[p.expectedHead].recordChainHash,
                r.revision,
                hash
            )
        );
        StreamSnapshotManifestBytes.retain(_payloads[hash], d.targets[3], canonical);
        StreamSnapshotManifestBytes.retain(_publications[hash], d.targets[3], abi.encode(p));
        StreamSnapshotManifestBytes.retain(_modeEvidence[hash], d.targets[3], abi.encode(evidence));
        _modeFacts[hash] = mode;
        _receipts[hash] = r;
        _history[p.collectionId].push(hash);
        _ids[p.collectionId][p.referenceId] = true;
        emit ReferenceModePublished(
            1, hash, evidence.mode, mode.evidenceHash, mode.interpretationHash
        );
        emit ReferenceRenderPublished(hash, p.collectionId, p.referenceId, r, p.manifestURI);
    }

    function currentReference(uint256 cid)
        public
        view
        override
        returns (StreamReferenceRenderTypes.Receipt memory)
    {
        return _receipts[_head(cid)];
    }

    function prepareFileInventory(
        StreamReferenceRenderTypes.PackageFile[] calldata rows,
        bool relative
    ) external override guarded returns (bytes32) {
        return StreamReferenceRenderPreparation.prepare(
            _fileInventories, _fixed.targets[3], _fixed.codeHashes[3], rows, relative
        );
    }

    function preparedFileInventory(bytes32 id) external view override returns (bytes memory) {
        return StreamSnapshotManifestBytes.read(_fileInventories[id]);
    }

    function referenceRecord(bytes32 hash)
        external
        view
        override
        returns (
            StreamReferenceRenderTypes.Publication memory,
            StreamReferenceRenderTypes.Receipt memory
        )
    {
        _known(hash);
        bytes memory raw =
            StreamReferenceRenderRecordReads.recordBytes(_publications[hash], _receipts[hash]);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function referencePayload(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return StreamSnapshotManifestBytes.read(_payloads[hash]);
    }

    function referenceCount(uint256 cid) external view override returns (uint256) {
        return _history[cid].length;
    }

    function referenceAt(uint256 cid, uint256 index) external view override returns (bytes32) {
        return _history[cid][index];
    }

    function referenceLock(uint256 cid)
        external
        view
        override
        returns (StreamReferenceRenderTypes.Lock memory)
    {
        return _locks[cid];
    }

    function requireCurrent(uint256 cid, bytes32 hash, uint64 revision)
        public
        view
        override
        returns (StreamReferenceRenderTypes.Receipt memory r)
    {
        _known(hash);
        r = _receipts[hash];
        if (_head(cid) != hash || r.collectionId != cid || r.revision != revision) {
            revert StreamReferenceRenderTypes.ReferenceLineage(hash, _head(cid));
        }
        StreamReferenceRenderTypes.Dependencies memory d = dependencies();
        StreamReferenceRenderTypes.Publication memory p = abi.decode(
            StreamSnapshotManifestBytes.read(_publications[hash]),
            (StreamReferenceRenderTypes.Publication)
        );
        StreamReferenceModeTypes.Evidence memory evidence = _evidence(hash);
        StreamReferenceRenderTypes.SourceFacts memory f =
            StreamReferenceRenderSourceReads.requireModeSourceInputs(
                d, StreamReferenceRenderSourceReads.project(p), true
            );
        StreamReferenceModeTypes.Facts memory mode =
            StreamReferenceModeProof.requireEvidence(d, _modeBindings, p, f, evidence, true);
        if (
            StreamReferenceModeProof.sourceHash(d, _modeBindings, f, mode) != r.sourcesHash
                || keccak256(abi.encode(mode)) != keccak256(abi.encode(_modeFacts[hash]))
                || StreamSnapshotManifestBytes.requireIntact(_payloads[hash]) != r.payloadHash
        ) {
            revert StreamReferenceModeTypes.InvalidModeEvidence();
        }
    }

    function lockTransition(uint256 cid)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        StreamReferenceRenderTypes.Receipt memory r = currentReference(cid);
        if (r.recordHash == 0 || _locks[cid].actionId != 0) {
            revert StreamReferenceRenderTypes.ReferenceLocked();
        }
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_LOCK_SCOPE_V1"),
                deploymentChainId,
                address(this),
                core,
                cid
            )
        );
        oldHash = keccak256(abi.encode(scope, r.recordHash, r.revision, false));
        newHash = keccak256(abi.encode(scope, r.recordHash, r.revision, true));
    }

    function lockReference(uint256 cid) external override guarded {
        if (msg.sender != governanceAuthority || governanceAuthority.codehash != executorCodeHash) {
            revert StreamReferenceRenderTypes.ReferenceAuthority(msg.sender);
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = lockTransition(cid);
        bytes memory raw = StreamFinalityRouterEvidence.read(
            governanceAuthority,
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            192,
            gasParameter(READ_GAS)
        );
        (
            bool executing,
            bytes32 id,
            uint8 cls,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            keccak256(raw)
                    != keccak256(abi.encode(executing, id, cls, actualScope, actualOld, actualNew))
                || !executing || id == 0 || cls != 2 || actualScope != scope || actualOld != oldHash
                || actualNew != newHash || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) {
            revert StreamReferenceRenderTypes.ReferenceAuthority(msg.sender);
        }
        StreamReferenceRenderTypes.Receipt memory r = currentReference(cid);
        requireCurrent(cid, r.recordHash, r.revision);
        _locks[cid] =
            StreamReferenceRenderTypes.Lock(r.recordHash, r.revision, id, uint64(block.timestamp));
        emit ReferenceRenderLocked(r.recordHash, cid, id, r.revision);
    }

    function finalityState(uint256 cid)
        public
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        StreamReferenceRenderTypes.Receipt memory r = currentReference(cid);
        requireCurrent(cid, r.recordHash, r.revision);
        StreamReferenceRenderTypes.Lock memory l = _locks[cid];
        if (l.actionId == 0 || l.recordHash != r.recordHash || l.revision != r.revision) {
            revert StreamReferenceRenderTypes.ReferenceLocked();
        }
        return StreamFinalityComponentState(
            true,
            StreamFinalityDomains.COMPONENT_REFERENCE_RENDER,
            address(this),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(this).codehash,
            streamModuleVersion(),
            StreamReferenceModeDefinitions.PROFILE_HASH,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_LOCKED_REFERENCE_COMPONENT_V1"),
                    deploymentChainId,
                    address(this),
                    core,
                    cid,
                    r,
                    l
                )
            )
        );
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        return finalityState(scope.collectionId);
    }

    function streamModuleType() external pure override returns (bytes32) {
        return keccak256("REFERENCE_RENDER");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("STREAM_REFERENCE_MODE_IMPLEMENTATION_V1");
    }

    function streamModuleInterfaceId() external pure override returns (bytes4) {
        return type(IStreamArtworkFinalityComponent).interfaceId;
    }

    function streamModuleSchemaHash() external pure override returns (bytes32) {
        return StreamReferenceModeDefinitions.SCHEMA_HASH;
    }

    function streamModuleSupersedes() external pure override returns (address) {
        return address(0);
    }

    function streamModuleCodeHash() external view override returns (bytes32) {
        return address(this).codehash;
    }

    function streamModuleDeploymentManifestHash() external view override returns (bytes32) {
        return keccak256(abi.encode(deploymentChainId, _fixed));
    }

    function streamModuleManifest() external pure override returns (string memory, bytes32) {
        return ("", StreamReferenceModeDefinitions.PROFILE_HASH);
    }

    function _receipt(StreamReferenceRenderTypes.Publication memory p, address recorder)
        private
        view
        returns (StreamReferenceRenderTypes.Receipt memory r)
    {
        r.collectionId = p.collectionId;
        r.referenceId = p.referenceId;
        r.predecessor = p.expectedHead;
        r.revision = p.expectedRevision + 1;
        r.snapshotRecordHash = p.snapshotRecordHash;
        r.snapshotRevision = p.snapshotRevision;
        r.recorder = recorder;
        (r.authorizationClass, r.grantRevision) = _authority(p.collectionId, recorder);
        r.effectiveAt = p.effectiveAt;
        r.reasonHash = p.reasonHash;
        r.schemaHash = StreamReferenceModeDefinitions.SCHEMA_HASH;
        r.profileHash = StreamReferenceModeDefinitions.PROFILE_HASH;
        r.canonicalizationHash = StreamReferenceModeDefinitions.CANON_HASH;
    }

    function _authority(uint256 cid, address actor) private view returns (uint8 cls, uint64 rev) {
        if (actor == address(0)) revert StreamReferenceRenderTypes.ReferenceAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 3 : 8;
            bytes memory raw = StreamFinalityRouterEvidence.read(
                metadataHost,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (i == 0 ? cid : 0, StreamRecordFamilies.CURATOR, cls, actor)
                ),
                64,
                gasParameter(READ_GAS)
            );
            bool enabled;
            (enabled, rev) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, rev))) {
                revert StreamReferenceRenderTypes.ReferenceDependency(metadataHost);
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert StreamReferenceRenderTypes.ReferenceAuthority(actor);
    }

    function _candidate(StreamReferenceRenderTypes.Publication memory p) private view {
        if (
            p.collectionId == 0 || p.referenceId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || p.expectedRevision == type(uint64).max || _ids[p.collectionId][p.referenceId]
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        if (
            _head(p.collectionId) != p.expectedHead
                || _history[p.collectionId].length != p.expectedRevision
        ) {
            revert StreamReferenceRenderTypes.ReferenceLineage(
                p.expectedHead, _head(p.collectionId)
            );
        }
        if (_locks[p.collectionId].actionId != 0) {
            revert StreamReferenceRenderTypes.ReferenceLocked();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "referenceManifestURI", p.manifestURI, 2048, true
        );
    }

    function _definitions(StreamReferenceRenderTypes.Dependencies memory d) private view {
        StreamReferenceModeDefinitionsRead.requireDefinitions(d);
    }

    function referenceModeEvidence(bytes32 hash)
        external
        view
        override
        returns (StreamReferenceModeTypes.Evidence memory, StreamReferenceModeTypes.Facts memory)
    {
        _known(hash);
        return (_evidence(hash), _modeFacts[hash]);
    }

    function referenceMode(bytes32 hash)
        external
        view
        override
        returns (StreamReferenceModeTypes.Mode, bytes32)
    {
        _known(hash);
        return (_modeFacts[hash].mode, _modeFacts[hash].evidenceHash);
    }

    function _evidence(bytes32 hash)
        private
        view
        returns (StreamReferenceModeTypes.Evidence memory e)
    {
        bytes memory raw = StreamSnapshotManifestBytes.read(_modeEvidence[hash]);
        e = abi.decode(raw, (StreamReferenceModeTypes.Evidence));
        if (keccak256(raw) != keccak256(abi.encode(e))) {
            revert StreamReferenceModeTypes.InvalidModeEvidence();
        }
    }

    function _head(uint256 cid) private view returns (bytes32) {
        uint256 n = _history[cid].length;
        return n == 0 ? bytes32(0) : _history[cid][n - 1];
    }

    function _known(bytes32 hash) private view {
        if (hash == 0 || _receipts[hash].recordHash != hash) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
    }
}
