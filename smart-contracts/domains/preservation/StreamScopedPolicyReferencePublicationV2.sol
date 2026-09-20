// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedPolicyReferencePublicationV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as T
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamReferenceInventoryPreparation
} from "../../interfaces/stream/preservation/IStreamReferenceInventoryPreparation.sol";
import {
    IStreamReferenceEnvironmentPreparation
} from "../../interfaces/stream/preservation/IStreamReferenceEnvironmentPreparation.sol";
import {
    IStreamArtworkScopedFinalityComponent,
    StreamFinalityComponentState,
    StreamFinalityScope,
    StreamFinalityDomains
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import { IStreamModule } from "../../interfaces/stream/modules/IStreamModule.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamScopedPolicyReferenceDefinitionsV2 as D
} from "../records/StreamScopedPolicyReferenceDefinitionsV2.sol";
import {
    StreamScopedPolicyReferenceSourceReadsV2 as Sources
} from "./StreamScopedPolicyReferenceSourceReadsV2.sol";
import {
    StreamScopedPolicyReferenceRecordsV2 as Records
} from "./StreamScopedPolicyReferenceRecordsV2.sol";
import {
    StreamReferenceRenderPreparation as Environment
} from "./StreamReferenceRenderPreparation.sol";
import {
    StreamReferenceInventoryPreparation as Parts
} from "./StreamReferenceInventoryPreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";
import {
    StreamGasParameterHost,
    IStreamGovernedParameterAuthority,
    IStreamGasParameterHost
} from "../parameters/StreamGasParameterHost.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Exact repeated reference observations for complete TOKEN, RELEASE and SEASON scopes.
/// @dev Separate original records and domains. This host neither grants Artist content authority
/// nor turns first/last samples into a complete render-critical archive. VIEW needs its own source.
contract StreamScopedPolicyReferencePublicationV2 is
    IStreamScopedPolicyReferencePublicationV2,
    IStreamReferenceInventoryPreparation,
    IStreamReferenceEnvironmentPreparation,
    IStreamArtworkScopedFinalityComponent,
    IStreamModule,
    StreamGasParameterHost
{
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_SCOPED_POLICY_REFERENCE_READ_GAS");
    bytes32 public constant SOURCE_GAS =
        keccak256("6529STREAM_GGP_SCOPED_POLICY_REFERENCE_SOURCE_GAS");
    bytes32 public constant SNAPSHOT_GAS =
        keccak256("6529STREAM_GGP_SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS");
    bytes32 public constant ARCHIVE_GAS =
        keccak256("6529STREAM_GGP_SCOPED_POLICY_REFERENCE_ARCHIVE_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override metadataRouter;
    address public immutable override snapshots;
    address public immutable override archiveCoverage;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable executorCodeHash;
    T.Dependencies private _fixed;
    mapping(bytes32 => Bytes.Manifest) private _publications;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => T.Receipt) private _receipts;
    mapping(bytes32 => bytes32[]) private _history;
    mapping(bytes32 => mapping(bytes32 => bool)) private _ids;
    mapping(bytes32 => R.Lock) private _locks;
    mapping(bytes32 => Bytes.Manifest) private _fileInventories;
    bool private _entered;

    constructor(T.Dependencies memory d, address executor, GasParameterConfig[4] memory configs)
        StreamGasParameterHost(executor)
    {
        if (
            _registerGasParameter(configs[0]) != READ_GAS
                || _registerGasParameter(configs[1]) != SOURCE_GAS
                || _registerGasParameter(configs[2]) != SNAPSHOT_GAS
                || _registerGasParameter(configs[3]) != ARCHIVE_GAS
        ) revert T.InvalidScopedPolicyReference();
        for (uint256 i; i < 4; ++i) {
            if (configs[i].failureClass != 1) revert T.InvalidScopedPolicyReference();
        }
        _fixed = d;
        core = d.targets[0];
        metadataHost = d.targets[1];
        metadataRouter = d.targets[4];
        snapshots = d.targets[5];
        archiveCoverage = d.targets[6];
        deploymentChainId = block.chainid;
        executorCodeHash = abi.decode(
            Reads.read(
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
                        Reads.read(
                            metadataHost,
                            abi.encodeWithSignature("governanceAuthority()"),
                            32,
                            configs[0].genesisValue
                        ),
                        (address)
                    ) != executor
        ) revert T.InvalidScopedPolicyReference();
        Sources.bindings(dependencies());
    }

    modifier guarded() {
        if (_entered) revert T.InvalidScopedPolicyReference();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamScopedPolicyReferencePublicationV2).interfaceId
            || id == type(IStreamReferenceInventoryPreparation).interfaceId
            || id == type(IStreamReferenceEnvironmentPreparation).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId
            || id == type(IStreamModule).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function scopedPolicyReferenceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2");
    }

    function dependencies() public view override returns (T.Dependencies memory d) {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.snapshotGas = gasParameter(SNAPSHOT_GAS);
        d.archiveGas = gasParameter(ARCHIVE_GAS);
    }

    function previewReference(T.Publication calldata p, address recorder)
        external
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        bytes32 subject = _candidate(p);
        T.Receipt memory r = _receipt(p, subject, recorder);
        return Records.prepare(_fileInventories, dependencies(), p, r, false);
    }

    function publishReference(T.Publication calldata p)
        external
        override
        guarded
        returns (bytes32 hash)
    {
        bytes32 subject = _candidate(p);
        T.Receipt memory r = _receipt(p, subject, msg.sender);
        T.Dependencies memory d = dependencies();
        bytes memory canonical;
        (r.observation.sourcesHash, canonical) = Records.prepare(_fileInventories, d, p, r, false);
        if (
            p.observation.expectedSourcesHash == 0
                || p.observation.expectedSourcesHash != r.observation.sourcesHash
        ) revert T.InvalidScopedPolicyReference();
        r.observation.payloadHash = keccak256(canonical);
        r.observation.payloadBytes = uint32(canonical.length);
        r.observation.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2"),
                deploymentChainId,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.observation.recordHash = hash;
        r.observation.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_CHAIN_V2"),
                deploymentChainId,
                address(this),
                core,
                subject,
                p.observation.expectedHead == 0
                    ? bytes32(0)
                    : _receipts[p.observation.expectedHead].observation.recordChainHash,
                r.observation.revision,
                hash
            )
        );
        Bytes.retain(_payloads[hash], d.targets[3], canonical);
        Bytes.retain(_publications[hash], d.targets[3], abi.encode(p));
        // Retention calls only the fixed Store's immutable reads. Still recheck the grant and
        // exact scope lineage before accepting the append, retaining atomic late-failure rollback.
        (uint8 cls, uint64 rev) = _authority(p.scope.collectionId, msg.sender);
        if (
            cls != r.observation.authorizationClass || rev != r.observation.grantRevision
                || _candidate(p) != subject
        ) revert T.ScopedPolicyReferenceAuthority(msg.sender);
        _receipts[hash] = r;
        _history[subject].push(hash);
        _ids[subject][p.observation.referenceId] = true;
        emit ScopedPolicyReferencePublished(
            2, subject, p.observation.referenceId, hash, r, p.observation.manifestURI
        );
    }

    function currentReference(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (T.Receipt memory)
    {
        bytes32 hash = _head(_subject(scope));
        _requireExactScope(hash, scope);
        T.Receipt memory r = _receipts[hash];
        if (r.observation.recordHash != 0 && r.observation.collectionId != scope.collectionId) {
            revert T.InvalidScopedPolicyReference();
        }
        return r;
    }

    function referenceRecord(bytes32 hash)
        external
        view
        override
        returns (T.Publication memory, T.Receipt memory)
    {
        _known(hash);
        bytes memory raw = Records.recordBytes(_publications[hash], _receipts[hash]);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function referencePayload(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return Bytes.read(_payloads[hash]);
    }

    function referenceSource(bytes32 hash) external view override returns (T.SourceFacts memory) {
        _known(hash);
        bytes memory raw = Records.source(_payloads[hash]);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function referenceCount(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        bytes32 subject = _subject(scope);
        _requireExactScope(_head(subject), scope);
        return _history[subject].length;
    }

    function referenceAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        bytes32 hash = _history[_subject(scope)][index];
        _requireExactScope(hash, scope);
        return hash;
    }

    function referenceLock(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (R.Lock memory)
    {
        bytes32 subject = _subject(scope);
        _requireExactScope(_head(subject), scope);
        return _locks[subject];
    }

    function requireCurrent(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision)
        public
        view
        override
        returns (T.Receipt memory r)
    {
        _known(hash);
        _requireExactScope(hash, scope);
        bytes32 subject = _subject(scope);
        r = _receipts[hash];
        if (
            _head(subject) != hash || r.scopeSubject != subject
                || r.observation.collectionId != scope.collectionId
                || r.observation.revision != revision
        ) {
            revert T.ScopedPolicyReferenceLineage(hash, _head(subject));
        }
        Records.requireCurrent(
            _publications[hash], _payloads[hash], _receipts[hash], dependencies()
        );
    }

    function lockTransition(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32 actionScope, bytes32 oldHash, bytes32 newHash)
    {
        bytes32 subject = _subject(scope);
        T.Receipt memory r = currentReference(scope);
        if (r.observation.recordHash == 0 || _locks[subject].actionId != 0) {
            revert T.ScopedPolicyReferenceLocked(subject);
        }
        actionScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_LOCK_SCOPE_V2"),
                deploymentChainId,
                address(this),
                core,
                scope,
                subject
            )
        );
        oldHash = keccak256(
            abi.encode(actionScope, r.observation.recordHash, r.observation.revision, false)
        );
        newHash = keccak256(
            abi.encode(actionScope, r.observation.recordHash, r.observation.revision, true)
        );
    }

    function lockReference(StreamFinalityScope calldata scope) external override guarded {
        if (msg.sender != governanceAuthority || governanceAuthority.codehash != executorCodeHash) {
            revert T.ScopedPolicyReferenceAuthority(msg.sender);
        }
        (bytes32 actionScope, bytes32 oldHash, bytes32 newHash) = lockTransition(scope);
        bytes memory raw = Reads.read(
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
                || !executing || id == 0 || cls != 2 || actualScope != actionScope
                || actualOld != oldHash || actualNew != newHash || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) revert T.ScopedPolicyReferenceAuthority(msg.sender);
        T.Receipt memory r = currentReference(scope);
        requireCurrent(scope, r.observation.recordHash, r.observation.revision);
        R.Lock memory value =
            R.Lock(r.observation.recordHash, r.observation.revision, id, uint64(block.timestamp));
        _locks[r.scopeSubject] = value;
        emit ScopedPolicyReferenceLocked(2, r.scopeSubject, value);
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        T.Receipt memory r = currentReference(scope);
        requireCurrent(scope, r.observation.recordHash, r.observation.revision);
        R.Lock memory l = _locks[r.scopeSubject];
        if (
            l.actionId == 0 || l.recordHash != r.observation.recordHash
                || l.revision != r.observation.revision
        ) {
            revert T.ScopedPolicyReferenceLocked(r.scopeSubject);
        }
        return StreamFinalityComponentState(
            true,
            StreamFinalityDomains.COMPONENT_REFERENCE_RENDER,
            address(this),
            type(IStreamArtworkScopedFinalityComponent).interfaceId,
            address(this).codehash,
            streamModuleVersion(),
            D.PROFILE_HASH,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_LOCKED_SCOPED_POLICY_REFERENCE_COMPONENT_V2"),
                    deploymentChainId,
                    address(this),
                    core,
                    scope,
                    r,
                    l
                )
            )
        );
    }

    function prepareFileInventory(R.PackageFile[] calldata rows, bool relative)
        external
        override
        guarded
        returns (bytes32)
    {
        return Environment.prepare(
            _fileInventories, _fixed.targets[3], _fixed.codeHashes[3], rows, relative
        );
    }

    function prepareFileInventoryPart(R.PackageFile[] calldata, bool)
        external
        override
        guarded
        returns (bytes32)
    {
        return Parts.preparePart(
            _fileInventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data
        );
    }

    function prepareFileInventoryFromParts(R.PackageFile[] calldata, bool)
        external
        override
        guarded
        returns (bytes32)
    {
        return Parts.assemble(_fileInventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data);
    }

    function preparedFileInventory(bytes32 id) external view override returns (bytes memory) {
        return Bytes.read(_fileInventories[id]);
    }

    function prepareEnvironment(R.Environment calldata)
        external
        override
        guarded
        returns (bytes32)
    {
        return Environment.prepareEnvironment(
            _fileInventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data
        );
    }

    function streamModuleType() external pure override returns (bytes32) {
        return keccak256("REFERENCE_RENDER");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("STREAM_SCOPED_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V2");
    }

    function streamModuleInterfaceId() external pure override returns (bytes4) {
        return type(IStreamArtworkScopedFinalityComponent).interfaceId;
    }

    function streamModuleSchemaHash() external pure override returns (bytes32) {
        return D.SCHEMA_HASH;
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
        return ("", D.PROFILE_HASH);
    }

    function _receipt(T.Publication calldata p, bytes32 subject, address recorder)
        private
        view
        returns (T.Receipt memory r)
    {
        r.scopeSubject = subject;
        R.Publication calldata o = p.observation;
        r.observation.collectionId = o.collectionId;
        r.observation.referenceId = o.referenceId;
        r.observation.predecessor = o.expectedHead;
        r.observation.revision = o.expectedRevision + 1;
        r.observation.snapshotRecordHash = o.snapshotRecordHash;
        r.observation.snapshotRevision = o.snapshotRevision;
        r.observation.recorder = recorder;
        (r.observation.authorizationClass, r.observation.grantRevision) =
            _authority(o.collectionId, recorder);
        r.observation.effectiveAt = o.effectiveAt;
        r.observation.reasonHash = o.reasonHash;
        r.observation.schemaHash = D.SCHEMA_HASH;
        r.observation.profileHash = D.PROFILE_HASH;
        r.observation.canonicalizationHash = D.CANON_HASH;
    }

    function _authority(uint256 cid, address actor) private view returns (uint8 cls, uint64 rev) {
        if (actor == address(0)) revert T.ScopedPolicyReferenceAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 3 : 8;
            bytes memory raw = Reads.read(
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
                revert T.ScopedPolicyReferenceDependency(metadataHost);
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert T.ScopedPolicyReferenceAuthority(actor);
    }

    function _candidate(T.Publication calldata p) private view returns (bytes32 subject) {
        subject = _subject(p.scope);
        _requireExactScope(_head(subject), p.scope);
        R.Publication calldata o = p.observation;
        if (
            o.collectionId != p.scope.collectionId || o.referenceId == 0 || o.reasonHash == 0
                || o.effectiveAt == 0 || o.effectiveAt > block.timestamp
                || block.timestamp > type(uint64).max || o.expectedRevision == type(uint64).max
                || _ids[subject][o.referenceId]
        ) revert T.InvalidScopedPolicyReference();
        if (_head(subject) != o.expectedHead || _history[subject].length != o.expectedRevision) {
            revert T.ScopedPolicyReferenceLineage(o.expectedHead, _head(subject));
        }
        if (_locks[subject].actionId != 0) revert T.ScopedPolicyReferenceLocked(subject);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "referenceManifestURI", o.manifestURI, 2048, true
        );
    }

    function _requireExactScope(bytes32 hash, StreamFinalityScope memory scope) private view {
        if (hash == 0) return;
        T.Publication memory p = Records.publication(_publications[hash]);
        if (keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))) {
            revert T.InvalidScopedPolicyReference();
        }
    }

    function _subject(StreamFinalityScope memory scope) private view returns (bytes32) {
        return Sources.subject(_fixed, scope);
    }

    function _head(bytes32 subject) private view returns (bytes32) {
        uint256 n = _history[subject].length;
        return n == 0 ? bytes32(0) : _history[subject][n - 1];
    }

    function _known(bytes32 hash) private view {
        if (hash == 0 || _receipts[hash].observation.recordHash != hash) {
            revert T.ScopedPolicyReferenceUnknown(hash);
        }
    }
}
