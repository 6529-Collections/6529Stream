// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../parameters/StreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Definitions
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as FamilyDefinitions
} from "./StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Verifies every original output row in an actual covered canonical manifest.
/// @dev Full rendered bytes and authoritative root publication are separate obligations.
/// Current admission replays the full original checkpoint and current archive coverage.
abstract contract StreamPreservationPolicyOutputManifestBase is
    IStreamPreservationPolicyOutputManifestV1,
    StreamGasParameterHost,
    IERC165
{
    address public immutable override core;
    address public immutable override contentCheckpoint;
    address public immutable override artifactCoverage;
    bytes32 public immutable checkpointCodeHash;
    bytes32 public immutable coverageCodeHash;
    uint256 public immutable deploymentChainId;
    address public immutable schemaRegistry;
    bytes32 public immutable schemaCodeHash;

    bytes32 public immutable checkpointProfile;
    bool private immutable _familyV2;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_STATIC_OUTPUT_MANIFEST_READ_GAS");
    uint256 public constant MAX_VERIFY_BATCH = 16;
    uint256 private constant _HEADER_BYTES = 640;
    uint256 private constant _LEAF_BYTES = 1152;
    uint256 private constant _CHUNK_BYTES = 8192;
    uint256 private constant _MAX_CHUNKS = 64;
    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => bytes32) private _recordPlans;

    constructor(
        address core_,
        address checkpoint_,
        address coverage_,
        address executor,
        GasParameterConfig memory readGas,
        bool familyV2_
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || checkpoint_.code.length == 0 || coverage_.code.length == 0
                || _registerGasParameter(readGas) != DEPENDENCY_READ_GAS
                || readGas.failureClass != 2
        ) {
            revert InvalidOutputManifest();
        }
        _familyV2 = familyV2_;
        core = core_;
        contentCheckpoint = checkpoint_;
        artifactCoverage = coverage_;
        checkpointCodeHash = checkpoint_.codehash;
        coverageCodeHash = coverage_.codehash;
        deploymentChainId = block.chainid;
        schemaRegistry = abi.decode(
            _read(
                coverage_, abi.encodeCall(IStreamFinalityArtifactCoverage.schemaRegistry, ()), 32
            ),
            (address)
        );
        if (schemaRegistry.code.length == 0) revert InvalidOutputManifest();
        schemaCodeHash = schemaRegistry.codehash;
        if (
            abi.decode(
                        _read(
                            checkpoint_,
                            abi.encodeCall(IStreamPreservationPolicyContentCheckpointV1.core, ()),
                            32
                        ),
                        (address)
                    ) != core_
                || abi.decode(
                        _read(
                            coverage_, abi.encodeCall(IStreamFinalityArtifactCoverage.core, ()), 32
                        ),
                        (address)
                    ) != core_
        ) {
            revert InvalidOutputManifest();
        }
        bytes32 profile = abi.decode(
            _read(
                checkpoint_,
                abi.encodeCall(
                    IStreamPreservationPolicyContentCheckpointV1.preservationPolicyProfile, ()
                ),
                32
            ),
            (bytes32)
        );
        checkpointProfile = profile;
        if (
            (familyV2_
                        ? (profile != Family.COLLECTION_CHECKPOINT_PROFILE
                            && profile != Family.SCOPED_CHECKPOINT_PROFILE)
                        : (profile != keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
                            && profile
                                != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")))
                || !abi.decode(
                    _read(
                        checkpoint_,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamPreservationPolicyContentCheckpointV1).interfaceId)
                        ),
                        32
                    ),
                    (bool)
                )
        ) revert InvalidOutputManifest();
        if (
            familyV2_
                && abi.decode(
                        _read(
                            checkpoint_,
                            abi.encodeCall(
                                IStreamPreservationPolicyContentCheckpointV1.preservationOutputProfile,
                                ()
                            ),
                            32
                        ),
                        (bytes32)
                    ) != Family.FAMILY_PROFILE
        ) {
            revert InvalidOutputManifest();
        }
    }

    function outputProfile() external view override returns (bytes32) {
        return _familyV2 ? Family.OUTPUT_MANIFEST_PROFILE : checkpointProfile;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamPreservationPolicyOutputManifestV1).interfaceId;
    }

    function beginManifest(
        bytes32 checkpointHash,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external override returns (bytes32 planHash) {
        _pins();
        _documents();
        IStreamPreservationPolicyContentCheckpointV1.Plan memory p = _checkpoint(checkpointHash);
        F.Coverage memory c = _coverage(coverageHash, artistId, artifactHash);
        uint256 length = _HEADER_BYTES + uint256(p.tokenCount) * _LEAF_BYTES;
        if (
            artistId == 0 || p.scope.collectionId == 0 || p.tokenCount == 0
                || p.nextIndex != p.tokenCount || p.contentRoot == 0 || p.outputRoot == 0
                || c.schemaId != _schemaId() || c.canonicalizationId != _canonicalizationId()
                || c.byteLength != length || length > _MAX_CHUNKS * _CHUNK_BYTES
                || c.chunkCount != (length + _CHUNK_BYTES - 1) / _CHUNK_BYTES || c.contentHash == 0
                || p.preservationProfile != _preservationProfile()
        ) {
            revert InvalidOutputManifest();
        }
        Manifest memory m = Manifest(
            checkpointHash,
            keccak256(abi.encode(p)),
            abi.decode(
                _read(
                    contentCheckpoint,
                    abi.encodeCall(
                        IStreamPreservationPolicyContentCheckpointV1.entropySourceSet, ()
                    ),
                    32
                ),
                (address)
            ),
            p.inventoryHash,
            p.policyChainHash,
            _router(),
            p.preservationProfile,
            artifactHash,
            coverageHash,
            artistId,
            p.contentRoot,
            p.outputRoot,
            c.contentHash,
            p.scope,
            p.tokenCount,
            uint64(length)
        );
        // Four-word scope plus common Router/profile are inlined; exact head is nineteen words.
        bytes memory expected = abi.encode(
            _schemaId(),
            deploymentChainId,
            core,
            contentCheckpoint,
            checkpointHash,
            m.checkpointStateHash,
            m.entropySourceSet,
            p.inventoryHash,
            p.policyChainHash,
            m.metadataRouter,
            m.preservationProfile,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            uint256(608),
            p.tokenCount
        );
        if (keccak256(_slice(m, 0, _HEADER_BYTES)) != keccak256(expected)) {
            revert InvalidOutputManifest();
        }
        planHash = keccak256(
            abi.encode(
                _planDomain(),
                deploymentChainId,
                address(this),
                core,
                contentCheckpoint,
                artifactCoverage,
                m
            )
        );
        if (_plans[planHash].manifest.tokenCount == 0) {
            _plans[planHash].manifest = m;
            emit OutputManifestStarted(_eventVersion(), planHash, m);
        }
    }

    function verifyNextOutputs(bytes32 planHash, uint256 count)
        external
        override
        returns (bytes32 recordHash)
    {
        _pins();
        Plan storage p = _plans[planHash];
        if (p.manifest.tokenCount == 0) revert OutputManifestUnknown(planHash);
        if (count == 0 || count > MAX_VERIFY_BATCH || count > p.manifest.tokenCount - p.nextIndex) {
            revert OutputManifestBatch(count);
        }
        uint64 first = p.nextIndex;
        bytes memory batch =
            _slice(p.manifest, _HEADER_BYTES + uint256(first) * _LEAF_BYTES, count * _LEAF_BYTES);
        for (uint256 i; i < count; ++i) {
            bytes memory actual = _read(
                contentCheckpoint,
                abi.encodeCall(
                    IStreamPreservationPolicyContentCheckpointV1.outputAt,
                    (p.manifest.checkpointHash, uint256(first) + i)
                ),
                _LEAF_BYTES
            );
            bytes32 supplied;
            assembly ("memory-safe") {
                supplied := keccak256(add(add(batch, 32), mul(i, 1152)), 1152)
            }
            if (supplied != keccak256(actual)) revert OutputManifestMismatch(uint256(first) + i);
        }
        p.nextIndex = first + uint64(count);
        emit OutputManifestAdvanced(_eventVersion(), planHash, first, p.nextIndex);
        if (p.nextIndex == p.manifest.tokenCount) {
            _current(p.manifest);
            recordHash = keccak256(abi.encode(_recordDomain(), planHash));
            p.recordHash = recordHash;
            _recordPlans[recordHash] = planHash;
            emit OutputManifestVerified(_eventVersion(), recordHash, planHash, p.manifest);
        }
    }

    function manifestPlan(bytes32 planHash) external view override returns (Plan memory) {
        return _plans[planHash];
    }

    function manifestRecord(bytes32 recordHash) public view override returns (Manifest memory) {
        Plan storage p = _plans[_recordPlans[recordHash]];
        if (recordHash == 0 || p.recordHash != recordHash) {
            revert OutputManifestUnknown(recordHash);
        }
        return p.manifest;
    }

    function requireCurrentManifest(bytes32 recordHash, bytes32 artistId)
        external
        view
        override
        returns (Manifest memory m)
    {
        _pins();
        m = manifestRecord(recordHash);
        if (artistId == 0 || m.artistId != artistId) revert InvalidOutputManifest();
        _current(m);
    }

    function _current(Manifest memory m) private view {
        _documents();
        IStreamPreservationPolicyContentCheckpointV1.Plan memory p = _checkpoint(m.checkpointHash);
        F.Coverage memory c = _coverage(m.coverageHash, m.artistId, m.artifactHash);
        if (
            keccak256(abi.encode(p)) != m.checkpointStateHash || p.tokenCount != m.tokenCount
                || p.nextIndex != p.tokenCount || p.contentRoot != m.contentRoot
                || p.inventoryHash != m.inventoryHash || p.policyChainHash != m.policyChainHash
                || p.preservationProfile != _preservationProfile()
                || p.preservationProfile != m.preservationProfile || m.metadataRouter != _router()
                || p.outputRoot != m.outputRoot || c.contentHash != m.manifestHash
                || c.byteLength != m.byteLength || c.schemaId != _schemaId()
                || c.canonicalizationId != _canonicalizationId()
        ) revert InvalidOutputManifest();
    }

    function _checkpoint(bytes32 hash)
        private
        view
        returns (IStreamPreservationPolicyContentCheckpointV1.Plan memory)
    {
        return abi.decode(
            _read(
                contentCheckpoint,
                abi.encodeCall(
                    IStreamPreservationPolicyContentCheckpointV1.requireCurrentCheckpoint, (hash)
                ),
                448
            ),
            (IStreamPreservationPolicyContentCheckpointV1.Plan)
        );
    }

    function _router() private view returns (address router) {
        router = abi.decode(
            _read(
                contentCheckpoint,
                abi.encodeCall(IStreamPreservationPolicyContentCheckpointV1.metadataRouter, ()),
                32
            ),
            (address)
        );
        if (router.code.length == 0) revert InvalidOutputManifest();
    }

    function _coverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash)
        private
        view
        returns (F.Coverage memory c)
    {
        if (hash == 0 || artifactHash == 0 || artistId == 0) revert InvalidOutputManifest();
        c = abi.decode(
            _read(
                artifactCoverage,
                abi.encodeCall(
                    IStreamFinalityArtifactCoverage.requireArtifactCoverage,
                    (hash, artistId, artifactHash)
                ),
                384
            ),
            (F.Coverage)
        );
        if (
            c.completionHash != hash || c.artistId != artistId || c.artifactHash != artifactHash
                || c.firstFamilyRecordHash == 0 || c.secondFamilyRecordHash == 0
                || c.firstFamilyRecordHash == c.secondFamilyRecordHash
        ) {
            revert InvalidOutputManifest();
        }
    }

    function _slice(Manifest memory m, uint256 offset, uint256 length)
        private
        view
        returns (bytes memory out)
    {
        if (offset + length > m.byteLength) revert InvalidOutputManifest();
        out = new bytes(length);
        uint256 copied;
        while (copied < length) {
            uint256 index = offset / _CHUNK_BYTES;
            uint256 inside = offset % _CHUNK_BYTES;
            uint256 chunkLength = uint256(m.byteLength) - index * _CHUNK_BYTES;
            if (chunkLength > _CHUNK_BYTES) chunkLength = _CHUNK_BYTES;
            (address pointer, bytes32 codeHash) = abi.decode(
                _read(
                    artifactCoverage,
                    abi.encodeCall(
                        IStreamFinalityArtifactCoverage.artifactChunk,
                        (m.artifactHash, uint32(index))
                    ),
                    64
                ),
                (address, bytes32)
            );
            if (pointer.code.length != chunkLength + 1 || pointer.codehash != codeHash) {
                revert OutputManifestComponentChanged(pointer);
            }
            bytes1 prefix;
            assembly ("memory-safe") {
                extcodecopy(pointer, 0, 0, 1)
                prefix := mload(0)
            }
            if (prefix != bytes1(0)) revert OutputManifestComponentChanged(pointer);
            uint256 take = chunkLength - inside;
            if (take > length - copied) take = length - copied;
            assembly ("memory-safe") {
                extcodecopy(pointer, add(add(out, 32), copied), add(inside, 1), take)
            }
            copied += take;
            offset += take;
        }
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert InvalidOutputManifest();
        if (schemaRegistry.codehash != schemaCodeHash) {
            revert OutputManifestComponentChanged(schemaRegistry);
        }
        if (contentCheckpoint.codehash != checkpointCodeHash) {
            revert OutputManifestComponentChanged(contentCheckpoint);
        }
        if (artifactCoverage.codehash != coverageCodeHash) {
            revert OutputManifestComponentChanged(artifactCoverage);
        }
    }

    function _documents() private view {
        bytes32[2] memory ids = [_schemaId(), _canonicalizationId()];
        for (uint256 i; i < 2; ++i) {
            bytes memory raw =
                _dynamic(schemaRegistry, abi.encodeCall(Schema.document, (ids[i])), 8192);
            Schema.DocumentView memory d = abi.decode(raw, (Schema.DocumentView));
            bytes memory expected =
                (_familyV2 ? FamilyDefinitions.document(ids[i]) : Definitions.document(ids[i]));
            if (
                keccak256(raw) != keccak256(abi.encode(d)) || !d.exists
                    || d.status != Schema.DocumentStatus.ACTIVE || uint8(d.specification.kind) != i
                    || keccak256(bytes(d.specification.name)) != ids[i]
                    || d.specification.canonicalizationId != keccak256("RAW_BYTES")
                    || d.specification.totalBytes != expected.length
                    || d.specification.contentHash != keccak256(expected)
            ) revert InvalidOutputManifest();
            raw = _dynamic(schemaRegistry, abi.encodeCall(Schema.documentBytes, (ids[i])), 8192);
            bytes memory actual = abi.decode(raw, (bytes));
            if (
                keccak256(raw) != keccak256(abi.encode(actual))
                    || keccak256(actual) != keccak256(expected)
            ) revert InvalidOutputManifest();
        }
    }

    function _dynamic(address target, bytes memory input, uint256 bound)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        if (cap > type(uint256).max / 2) {
            revert OutputManifestParentGas(gasleft(), type(uint256).max);
        }
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert OutputManifestParentGas(gasleft(), required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size < 64 || size > bound) {
            revert OutputManifestReadFailed(target, bytes4(input));
        }
        output = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(output, 32), 0, size) }
    }

    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        if (cap > type(uint256).max / 2) {
            revert OutputManifestParentGas(gasleft(), type(uint256).max);
        }
        uint256 required = cap + cap / 63 + 100_000;
        if (gasleft() <= required) revert OutputManifestParentGas(gasleft(), required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert OutputManifestReadFailed(target, bytes4(input));
    }

    function _schemaId() private view returns (bytes32) {
        return _familyV2 ? FamilyDefinitions.SCHEMA : Definitions.SCHEMA;
    }

    function _canonicalizationId() private view returns (bytes32) {
        return _familyV2 ? FamilyDefinitions.CANON : Definitions.CANON;
    }

    function _preservationProfile() private view returns (bytes32) {
        return _familyV2 ? Family.FAMILY_PROFILE : Family.ORIGINAL_PROFILE;
    }

    function _planDomain() private view returns (bytes32) {
        return _familyV2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V1");
    }

    function _recordDomain() private view returns (bytes32) {
        return _familyV2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1");
    }

    function _eventVersion() private view returns (uint16) {
        return _familyV2 ? 2 : 1;
    }
}
