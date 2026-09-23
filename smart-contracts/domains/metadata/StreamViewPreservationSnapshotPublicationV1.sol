// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamGovernedParameterAuthority
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

import {
    IStreamViewPreservationSnapshotPublicationV1 as I
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamViewPreservationSnapshotSourceReadsV1 as Sources
} from "../records/StreamViewPreservationSnapshotSourceReadsV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import { StreamRecordFamilies as Families } from "../records/StreamRecordFamilies.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";

/// @notice Root-free VIEW preservation snapshot under original writer grants and class-2 lock.
/// @dev Source snapshots remain separate from Artist CONTENT_ROOT authority and finality.
contract StreamViewPreservationSnapshotPublicationV1 is I, StreamGasParameterHost {
    bytes32 public constant READ_GAS =
        keccak256("6529STREAM_GGP_VIEW_PRESERVATION_SNAPSHOT_READ_GAS");
    bytes32 public constant SOURCE_GAS =
        keccak256("6529STREAM_GGP_VIEW_PRESERVATION_SNAPSHOT_SOURCE_GAS");
    bytes32 public constant INVENTORY_GAS =
        keccak256("6529STREAM_GGP_VIEW_PRESERVATION_SNAPSHOT_INVENTORY_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    bytes32 public immutable authorityCodeHash;
    S.Dependencies private _fixed;
    mapping(bytes32 => S.Publication) private _publications;
    mapping(bytes32 => S.Receipt) private _receipts;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => bytes32[]) private _history;
    mapping(bytes32 => mapping(bytes32 => bytes32)) private _ids;
    mapping(bytes32 => S.Lock) private _locks;
    bool private _entered;

    constructor(S.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamGasParameterHost(executor)
    {
        if (
            _registerGasParameter(configs[0]) != READ_GAS
                || _registerGasParameter(configs[1]) != SOURCE_GAS
                || _registerGasParameter(configs[2]) != INVENTORY_GAS
        ) revert S.InvalidViewPreservationSnapshot();
        for (uint256 i; i < 3; ++i) {
            if (configs[i].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK) {
                revert S.InvalidViewPreservationSnapshot();
            }
        }
        if (executor != d.targets[9]) revert S.InvalidViewPreservationSnapshot();
        _fixed = d;
        core = d.targets[0];
        metadataHost = d.targets[1];
        Sources.bindings(dependencies());
        authorityCodeHash = abi.decode(
            Reads.read(
                metadataHost,
                abi.encodeWithSignature("executorCodeHash()"),
                32,
                configs[0].genesisValue
            ),
            (bytes32)
        );
        if (
            executor.code.length == 0 || executor.codehash != authorityCodeHash
                || abi.decode(
                        Reads.read(
                            metadataHost,
                            abi.encodeWithSignature("governanceAuthority()"),
                            32,
                            configs[0].genesisValue
                        ),
                        (address)
                    ) != executor
        ) revert S.InvalidViewPreservationSnapshot();
    }

    modifier guarded() {
        if (_entered) revert S.InvalidViewPreservationSnapshot();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(I).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function dependencies() public view override returns (S.Dependencies memory d) {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.inventoryGas = gasParameter(INVENTORY_GAS);
    }

    function previewSnapshot(S.Publication calldata p, address publisher)
        external
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        _candidate(p);
        S.Receipt memory r = _receipt(p, publisher);
        return _assemble(p, r);
    }

    function publishSnapshot(S.Publication calldata p)
        external
        override
        guarded
        returns (bytes32 hash)
    {
        _candidate(p);
        S.Receipt memory r = _receipt(p, msg.sender);
        bytes32 originalAuthority = keccak256(abi.encode(r));
        bytes memory canonical;
        (r.sourceHash, canonical) = _assemble(p, r);
        if (p.expectedSourceHash == 0 || p.expectedSourceHash != r.sourceHash) {
            revert S.InvalidViewPreservationSnapshot();
        }
        // Rejoin exact original lineage and both selected Metadata grants after the full
        // current source/definition work, before immutable Store retention and any writes.
        _candidate(p);
        if (keccak256(abi.encode(_receipt(p, msg.sender))) != originalAuthority) {
            revert S.InvalidViewPreservationSnapshot();
        }
        r.manifestHash = keccak256(canonical);
        r.manifestBytes = uint32(canonical.length);
        r.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_RECORD_V1"),
                _fixed.chainId,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.recordHash = hash;
        r.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_CHAIN_V1"),
                _fixed.chainId,
                address(this),
                core,
                p.scope,
                _receipts[p.expectedHead].chainHash,
                r.revision,
                hash
            )
        );
        // The fixed Store cannot call back into the writer. Its immutable bytes grant no authority.
        Bytes.retain(_payloads[hash], _fixed.targets[3], canonical);
        _publications[hash] = p;
        _receipts[hash] = r;
        _ids[r.scopeSubject][p.snapshotId] = hash;
        _history[r.scopeSubject].push(hash);
        emit ViewPreservationSnapshotPublished(1, r.scopeSubject, p.snapshotId, hash, p, r);
    }

    function currentSnapshot(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (S.Receipt memory)
    {
        return _receipts[_head(Sources.scopeSubject(_fixed, scope))];
    }

    function snapshotRecord(bytes32 hash)
        external
        view
        override
        returns (S.Publication memory, S.Receipt memory)
    {
        return (_publications[hash], _known(hash));
    }

    function snapshotPayload(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return Bytes.read(_payloads[hash]);
    }

    function snapshotChunkCount(bytes32 hash) external view override returns (uint256) {
        _known(hash);
        return _payloads[hash].pointers.length;
    }

    function snapshotChunkAt(bytes32 hash, uint256 index)
        external
        view
        override
        returns (address pointer, bytes32 chunkHash, uint32 byteLength)
    {
        _known(hash);
        Bytes.Manifest storage saved = _payloads[hash];
        pointer = saved.pointers[index];
        chunkHash = saved.chunkHashes[index];
        uint256 remaining = uint256(saved.byteLength) - index * 8192;
        byteLength = uint32(remaining > 8192 ? 8192 : remaining);
    }

    function requireCurrent(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision)
        public
        view
        override
        returns (S.Receipt memory r)
    {
        r = _known(hash);
        bytes32 subject = Sources.scopeSubject(_fixed, scope);
        if (r.scopeSubject != subject || _head(subject) != hash || r.revision != revision) {
            revert S.ViewPreservationSnapshotLineage(hash, _head(subject));
        }
        S.Receipt memory fields = abi.decode(abi.encode(r), (S.Receipt));
        fields.recordHash = 0;
        fields.chainHash = 0;
        fields.manifestHash = 0;
        fields.manifestBytes = 0;
        fields.recordedAt = 0;
        (bytes32 sourceHash, bytes memory canonical) = _assemble(_publications[hash], fields);
        if (
            sourceHash != r.sourceHash || keccak256(canonical) != r.manifestHash
                || canonical.length != r.manifestBytes
                || Bytes.requireIntact(_payloads[hash]) != r.manifestHash
        ) revert S.InvalidViewPreservationSnapshot();
    }

    function lockTransition(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32 actionScope, bytes32 oldState, bytes32 newState)
    {
        S.Receipt memory r = currentSnapshot(scope);
        if (r.recordHash == 0) revert S.ViewPreservationSnapshotUnknown(0);
        if (_locks[r.scopeSubject].actionId != 0) {
            revert S.ViewPreservationSnapshotLocked(r.scopeSubject);
        }
        actionScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_LOCK_V1"),
                _fixed.chainId,
                address(this),
                core,
                scope
            )
        );
        oldState = keccak256(abi.encode(actionScope, r.recordHash, r.revision, false));
        newState = keccak256(abi.encode(actionScope, r.recordHash, r.revision, true));
    }

    function lockSnapshot(StreamFinalityScope calldata scope) external override guarded {
        if (msg.sender != governanceAuthority || governanceAuthority.codehash != authorityCodeHash)
        {
            revert S.ViewPreservationSnapshotAuthority(msg.sender);
        }
        (bytes32 actionScope, bytes32 oldState, bytes32 newState) = lockTransition(scope);
        (
            bool executing,
            bytes32 action,
            uint8 cls,
            bytes32 suppliedScope,
            bytes32 oldHash,
            bytes32 newHash
        ) = abi.decode(
            Reads.read(
                governanceAuthority,
                abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
                192,
                gasParameter(READ_GAS)
            ),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !executing || action == 0 || cls != 2 || suppliedScope != actionScope
                || oldHash != oldState || newHash != newState
        ) revert S.ViewPreservationSnapshotAuthority(msg.sender);
        S.Receipt memory r = currentSnapshot(scope);
        requireCurrent(scope, r.recordHash, r.revision);
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert S.InvalidViewPreservationSnapshot();
        }
        _locks[r.scopeSubject] = S.Lock(r.recordHash, r.revision, action, uint64(block.timestamp));
        emit ViewPreservationSnapshotLocked(1, r.scopeSubject, _locks[r.scopeSubject]);
    }

    function snapshotLock(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (S.Lock memory)
    {
        return _locks[Sources.scopeSubject(_fixed, scope)];
    }

    function snapshotCount(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        return _history[Sources.scopeSubject(_fixed, scope)].length;
    }

    function snapshotAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[Sources.scopeSubject(_fixed, scope)][index];
    }

    function _candidate(S.Publication memory p) private view {
        bytes32 subject = Sources.scopeSubject(_fixed, p.scope);
        if (_locks[subject].actionId != 0) revert S.ViewPreservationSnapshotLocked(subject);
        if (
            p.snapshotId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || p.expectedRevision == type(uint64).max || _ids[subject][p.snapshotId] != 0
        ) revert S.InvalidViewPreservationSnapshot();
        if (_head(subject) != p.expectedHead || _history[subject].length != p.expectedRevision) {
            revert S.ViewPreservationSnapshotLineage(p.expectedHead, _head(subject));
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "snapshotManifestURI", p.manifestURI, 2048, true
        );
    }

    function _receipt(S.Publication memory p, address publisher)
        private
        view
        returns (S.Receipt memory r)
    {
        r.scopeSubject = Sources.scopeSubject(_fixed, p.scope);
        r.predecessor = p.expectedHead;
        r.revision = p.expectedRevision + 1;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) =
            _authority(p.scope.collectionId, Families.SNAPSHOT, publisher);
        (r.displayAuthorizationClass, r.displayGrantRevision) =
            _authority(p.scope.collectionId, Families.IDENTITY, publisher);
        r.schemaHash = Definitions.SCHEMA_HASH;
        r.profileHash = Definitions.PROFILE_HASH;
        r.canonicalizationHash = Definitions.CANON_HASH;
    }

    function _authority(uint256 cid, bytes32 family, address actor)
        private
        view
        returns (uint8, uint64)
    {
        if (actor == address(0)) revert S.ViewPreservationSnapshotAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            uint8 cls = i == 0 ? 7 : 8;
            bytes memory raw = Reads.read(
                metadataHost,
                abi.encodeCall(Metadata.familyWriter, (i == 0 ? cid : 0, family, cls, actor)),
                64,
                gasParameter(READ_GAS)
            );
            (bool enabled, uint64 rev) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, rev))) {
                revert S.InvalidViewPreservationSnapshot();
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert S.ViewPreservationSnapshotAuthority(actor);
    }

    function _assemble(S.Publication memory p, S.Receipt memory r)
        private
        view
        returns (bytes32 hash, bytes memory canonical)
    {
        S.Dependencies memory d = dependencies();
        _definitions(d);
        S.Source memory f = Sources.current(d, p);
        hash = Sources.sourceHash(d, f);
        r.sourceHash = hash;
        p.expectedSourceHash = 0; // The actual hash is present in receipt/source; no preview circularity.
        canonical = abi.encode(
            keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_PAYLOAD_V1"),
            d.chainId,
            address(this),
            d.targets,
            d.codeHashes,
            p,
            r,
            f
        );
        if (canonical.length > 524288) revert S.InvalidViewPreservationSnapshot();
    }

    function _definitions(S.Dependencies memory d) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        Documents.definition(
            known,
            Definitions.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            Definitions.SCHEMA_HASH,
            Definitions.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        Documents.definition(
            known,
            Definitions.PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            Definitions.PROFILE_HASH,
            Definitions.PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        Documents.definition(
            known,
            Definitions.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            Definitions.CANON_HASH,
            Definitions.CANON_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
    }

    function _head(bytes32 subject) private view returns (bytes32) {
        uint256 n = _history[subject].length;
        return n == 0 ? bytes32(0) : _history[subject][n - 1];
    }

    function _known(bytes32 hash) private view returns (S.Receipt memory r) {
        r = _receipts[hash];
        if (hash == 0 || r.recordHash != hash) revert S.ViewPreservationSnapshotUnknown(hash);
    }
}
