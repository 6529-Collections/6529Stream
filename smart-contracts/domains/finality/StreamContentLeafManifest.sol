// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamContentLeafManifest.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Verifies every field of every ordered checkpoint leaf in actual preserved bytes.
/// @dev Canonical encoding is documented in docs/integrations/content-leaf-manifests.md.
///      Anyone, including a Safe, can advance a plan. Current admission is distinct from history.
contract StreamContentLeafManifest is IStreamContentLeafManifest, StreamGasParameterHost, IERC165 {
    address public immutable override core;
    address public immutable override contentCheckpoint;
    address public immutable override artifactCoverage;
    bytes32 public immutable checkpointCodeHash;
    bytes32 public immutable coverageCodeHash;
    uint256 public immutable deploymentChainId;

    bytes32 public constant SCHEMA_ID = keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1");
    bytes32 public constant CANONICALIZATION_ID =
        keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1");
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_CONTENT_LEAF_MANIFEST_READ_GAS");
    uint256 public constant MAX_VERIFY_BATCH = 16;
    uint256 private constant _HEADER_BYTES = 320;
    uint256 private constant _LEAF_BYTES = 192;
    uint256 private constant _CHUNK_BYTES = 8192;
    uint256 private constant _MAX_CHUNKS = 64;
    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => bytes32) private _recordPlans;

    constructor(
        address core_,
        address checkpoint_,
        address coverage_,
        address executor,
        GasParameterConfig memory readGas
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || checkpoint_.code.length == 0 || coverage_.code.length == 0
                || _registerGasParameter(readGas) != DEPENDENCY_READ_GAS
                || readGas.failureClass != 2
        ) {
            revert InvalidLeafManifest();
        }
        core = core_;
        contentCheckpoint = checkpoint_;
        artifactCoverage = coverage_;
        checkpointCodeHash = checkpoint_.codehash;
        coverageCodeHash = coverage_.codehash;
        deploymentChainId = block.chainid;
        if (
            abi.decode(
                        _read(
                            checkpoint_,
                            abi.encodeCall(IStreamOnchainContentCheckpoint.core, ()),
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
            revert InvalidLeafManifest();
        }
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamContentLeafManifest).interfaceId;
    }

    function beginManifest(
        bytes32 checkpointHash,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external override returns (bytes32 planHash) {
        _pins();
        IStreamOnchainContentCheckpoint.Plan memory p = _checkpoint(checkpointHash);
        F.Coverage memory c = _coverage(coverageHash, artistId, artifactHash);
        uint256 length = _HEADER_BYTES + uint256(p.tokenCount) * _LEAF_BYTES;
        if (
            artistId == 0 || p.collectionId == 0 || p.tokenCount == 0 || p.nextIndex != p.tokenCount
                || p.contentRoot == 0 || c.schemaId != SCHEMA_ID
                || c.canonicalizationId != CANONICALIZATION_ID || c.byteLength != length
                || length > _MAX_CHUNKS * _CHUNK_BYTES
                || c.chunkCount != (length + _CHUNK_BYTES - 1) / _CHUNK_BYTES || c.contentHash == 0
        ) {
            revert InvalidLeafManifest();
        }
        Manifest memory m = Manifest(
            checkpointHash,
            artifactHash,
            coverageHash,
            artistId,
            p.contentRoot,
            c.contentHash,
            p.collectionId,
            p.tokenCount,
            uint64(length)
        );
        // ABI's dynamic-array offset is 9 words; its exact count is the tenth word.
        bytes memory expected = abi.encode(
            SCHEMA_ID,
            deploymentChainId,
            core,
            contentCheckpoint,
            checkpointHash,
            p.collectionId,
            p.contentRoot,
            p.tokenCount,
            uint256(288),
            p.tokenCount
        );
        if (keccak256(_slice(m, 0, _HEADER_BYTES)) != keccak256(expected)) {
            revert InvalidLeafManifest();
        }
        planHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_LEAF_MANIFEST_PLAN_V1"),
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
            emit LeafManifestStarted(planHash, m);
        }
    }

    function verifyNextLeaves(bytes32 planHash, uint256 count)
        external
        override
        returns (bytes32 recordHash)
    {
        _pins();
        Plan storage p = _plans[planHash];
        if (p.manifest.tokenCount == 0) revert LeafManifestUnknown(planHash);
        if (count == 0 || count > MAX_VERIFY_BATCH || count > p.manifest.tokenCount - p.nextIndex) {
            revert LeafManifestBatch(count);
        }
        uint64 first = p.nextIndex;
        bytes memory batch =
            _slice(p.manifest, _HEADER_BYTES + uint256(first) * _LEAF_BYTES, count * _LEAF_BYTES);
        for (uint256 i; i < count; ++i) {
            bytes memory actual = _read(
                contentCheckpoint,
                abi.encodeCall(
                    IStreamOnchainContentCheckpoint.checkpointLeaf,
                    (p.manifest.checkpointHash, uint256(first) + i)
                ),
                _LEAF_BYTES
            );
            bytes32 supplied;
            assembly ("memory-safe") {
                supplied := keccak256(add(add(batch, 32), mul(i, 192)), 192)
            }
            if (supplied != keccak256(actual)) revert LeafManifestMismatch(uint256(first) + i);
        }
        p.nextIndex = first + uint64(count);
        emit LeafManifestAdvanced(planHash, first, p.nextIndex);
        if (p.nextIndex == p.manifest.tokenCount) {
            _current(p.manifest);
            recordHash = keccak256(
                abi.encode(keccak256("6529STREAM_CONTENT_LEAF_MANIFEST_VERIFIED_V1"), planHash)
            );
            p.recordHash = recordHash;
            _recordPlans[recordHash] = planHash;
            emit LeafManifestVerified(recordHash, planHash, p.manifest);
        }
    }

    function manifestPlan(bytes32 planHash) external view override returns (Plan memory) {
        return _plans[planHash];
    }

    function manifestRecord(bytes32 recordHash) public view override returns (Manifest memory) {
        Plan storage p = _plans[_recordPlans[recordHash]];
        if (recordHash == 0 || p.recordHash != recordHash) revert LeafManifestUnknown(recordHash);
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
        if (artistId == 0 || m.artistId != artistId) revert InvalidLeafManifest();
        _current(m);
    }

    function _current(Manifest memory m) private view {
        IStreamOnchainContentCheckpoint.Plan memory p = _checkpoint(m.checkpointHash);
        F.Coverage memory c = _coverage(m.coverageHash, m.artistId, m.artifactHash);
        if (
            p.collectionId != m.collectionId || p.tokenCount != m.tokenCount
                || p.nextIndex != p.tokenCount || p.contentRoot != m.contentRoot
                || c.contentHash != m.manifestHash || c.byteLength != m.byteLength
                || c.schemaId != SCHEMA_ID || c.canonicalizationId != CANONICALIZATION_ID
        ) revert InvalidLeafManifest();
    }

    function _checkpoint(bytes32 hash)
        private
        view
        returns (IStreamOnchainContentCheckpoint.Plan memory)
    {
        return abi.decode(
            _read(
                contentCheckpoint,
                abi.encodeCall(IStreamOnchainContentCheckpoint.requireCurrentCheckpoint, (hash)),
                224
            ),
            (IStreamOnchainContentCheckpoint.Plan)
        );
    }

    function _coverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash)
        private
        view
        returns (F.Coverage memory c)
    {
        if (hash == 0 || artifactHash == 0 || artistId == 0) revert InvalidLeafManifest();
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
            revert InvalidLeafManifest();
        }
    }

    function _slice(Manifest memory m, uint256 offset, uint256 length)
        private
        view
        returns (bytes memory out)
    {
        if (offset + length > m.byteLength) revert InvalidLeafManifest();
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
                revert LeafManifestComponentChanged(pointer);
            }
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
        if (block.chainid != deploymentChainId) revert InvalidLeafManifest();
        if (contentCheckpoint.codehash != checkpointCodeHash) {
            revert LeafManifestComponentChanged(contentCheckpoint);
        }
        if (artifactCoverage.codehash != coverageCodeHash) {
            revert LeafManifestComponentChanged(artifactCoverage);
        }
    }

    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        if (cap > type(uint256).max / 2) {
            revert LeafManifestParentGas(gasleft(), type(uint256).max);
        }
        uint256 required = cap + cap / 63 + 100_000;
        if (gasleft() <= required) revert LeafManifestParentGas(gasleft(), required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert LeafManifestReadFailed(target, bytes4(input));
    }
}
