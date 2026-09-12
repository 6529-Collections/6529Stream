// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactBindings.sol";
import "../../interfaces/stream/preservation/IStreamArchivalCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArchivalChunkCoverage.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Ordered actual-byte artifact coverage under the existing independent archival families.
/// @dev Admission is bounded to 64 canonical chunks. Coverage advances one index per call.
///      The global provider epoch conservatively invalidates plans after any replaced fixity.
contract StreamFinalityArtifactCoverage is StreamGasParameterHost, IStreamFinalityArtifactCoverage {
    uint256 public constant MAX_CHUNKS = 64;
    uint256 public constant CHUNK_BYTES = 8192;
    bytes32 private constant _READ_GAS =
        keccak256("6529STREAM_GGP_FINALITY_ARTIFACT_DEPENDENCY_READ_GAS");
    address public immutable override core;
    address public immutable override archivalCoverage;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    address public immutable override finalityRegistry;
    bytes32 private immutable _coreCodeHash;
    bytes32 private immutable _coverageCodeHash;
    bytes32 private immutable _schemaCodeHash;
    bytes32 private immutable _storeCodeHash;

    struct Part {
        address pointer;
        bytes32 codeHash;
    }
    mapping(bytes32 => F.Artifact) private _artifacts;
    mapping(bytes32 => Part[]) private _parts;
    mapping(bytes32 => F.Plan) private _plans;
    mapping(bytes32 => F.Coverage) private _coverage;
    mapping(bytes32 => bytes32) private _completionPlan;
    mapping(bytes32 => mapping(uint32 => bytes32)) private _originalPartCoverage;
    mapping(bytes32 => F.Validation) private _validations;
    mapping(bytes32 => bytes32) private _validationRecordPlan;
    mapping(bytes32 => bytes32) private _currentValidation;

    constructor(
        address core_,
        address coverage_,
        address schema_,
        address store_,
        address predictedFinality_,
        address executor,
        GasParameterConfig memory readGas
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || coverage_.code.length == 0 || schema_.code.length == 0
                || store_.code.length == 0 || predictedFinality_ == address(0)
                || keccak256(bytes(readGas.name))
                    != keccak256("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS") || readGas.floor < 300000
                || readGas.failureClass != 2
        ) revert InvalidArtifact();
        _registerGasParameter(readGas);
        core = core_;
        archivalCoverage = coverage_;
        schemaRegistry = schema_;
        chunkStore = store_;
        finalityRegistry = predictedFinality_;
        _coreCodeHash = core_.codehash;
        _coverageCodeHash = coverage_.codehash;
        _schemaCodeHash = schema_.codehash;
        _storeCodeHash = store_.codehash;
        if (
            _address(schema_, abi.encodeCall(IStreamFinalityArtifactBindings.chunkStore, ()))
                    != store_
                || _address(coverage_, abi.encodeCall(IStreamArchivalCoverage.core, ())) != core_
                || _address(
                        coverage_, abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ())
                    ) != executor
                || _address(
                        schema_, abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ())
                    ) != executor
        ) revert InvalidArtifact();
    }

    function recordArtifact(F.Artifact calldata a) external override returns (bytes32 hash) {
        _storagePins();
        uint256 count = a.chunkHashes.length;
        if (
            a.artistId == 0 || a.schemaId == 0 || a.canonicalizationId == 0 || a.hashAlgorithm != 1
                || a.contentHash == 0 || a.byteLength == 0
                || a.byteLength > MAX_CHUNKS * CHUNK_BYTES || count == 0 || count > MAX_CHUNKS
                || count != a.chunkLengths.length
        ) revert InvalidArtifact();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_V1"), block.chainid, address(this), core, a
            )
        );
        if (_artifacts[hash].artistId != 0) revert ArtifactExists(hash);
        bytes memory whole = new bytes(a.byteLength);
        uint256 offset;
        for (uint256 i; i < count; ++i) {
            uint32 length = a.chunkLengths[i];
            if (
                length == 0 || length > CHUNK_BYTES || (i + 1 < count && length != CHUNK_BYTES)
                    || offset + length > a.byteLength || a.chunkHashes[i] == 0
            ) revert InvalidArtifact();
            bytes memory raw = _read(
                chunkStore,
                abi.encodeCall(IStreamFinalityArtifactBindings.chunk, (a.chunkHashes[i])),
                64
            );
            (address pointer, uint32 storedLength) = abi.decode(raw, (address, uint32));
            if (storedLength != length || pointer.code.length != uint256(length) + 1) {
                revert InvalidArtifact();
            }
            bytes memory part = _bytes(pointer, length);
            if (keccak256(part) != a.chunkHashes[i]) revert InvalidArtifact();
            assembly ("memory-safe") {
                extcodecopy(pointer, add(add(whole, 32), offset), 1, length)
            }
            _parts[hash].push(Part(pointer, pointer.codehash));
            offset += length;
        }
        if (offset != a.byteLength || keccak256(whole) != a.contentHash) revert InvalidArtifact();
        _artifacts[hash] = a;
        emit FinalityArtifactRecorded(1, hash, a);
    }

    function artifact(bytes32 hash) external view override returns (F.Artifact memory) {
        return _artifacts[hash];
    }

    function artifactChunk(bytes32 hash, uint32 index)
        external
        view
        override
        returns (address, bytes32)
    {
        if (index >= _parts[hash].length) revert InvalidArtifact();
        Part storage part = _parts[hash][index];
        return (part.pointer, part.codeHash);
    }

    function beginCoverage(bytes32 hash, bytes32 first, bytes32 second)
        external
        override
        returns (bytes32 planHash)
    {
        if (_artifacts[hash].artistId == 0) revert ArtifactMissing(hash);
        if (first == 0 || second == 0 || first == second) revert InvalidArtifact();
        (bytes32 environment, uint64 epoch) = _environment();
        planHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_COVERAGE_PLAN_V1"),
                block.chainid,
                address(this),
                hash,
                first,
                second,
                environment,
                epoch
            )
        );
        if (_plans[planHash].artifactHash != 0) revert InvalidArtifactCoverage(planHash);
        F.Plan memory p = F.Plan(
            hash,
            first,
            second,
            environment,
            epoch,
            0,
            keccak256(
                abi.encode(keccak256("6529STREAM_FINALITY_ARTIFACT_COVERAGE_CHAIN_V1"), planHash)
            ),
            0
        );
        _plans[planHash] = p;
        emit FinalityArtifactCoverageStarted(1, planHash, p);
    }

    function coverNextChunk(bytes32 planHash, uint32 index, bytes32 coverageHash)
        external
        override
        returns (bytes32 completionHash)
    {
        F.Plan storage p = _plans[planHash];
        if (p.artifactHash == 0 || p.completionHash != 0) revert InvalidArtifactCoverage(planHash);
        if (p.nextIndex != index) revert ArtifactCoverageIndex(p.nextIndex, index);
        _current(planHash, p);
        F.Artifact storage a = _artifacts[p.artifactHash];
        if (index >= a.chunkHashes.length) revert InvalidArtifactCoverage(planHash);
        _partPin(p.artifactHash, index);
        A.CoverageFacts memory actual = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(
                    IStreamArchivalCoverage.requireCoverage,
                    (coverageHash, a.artistId, a.chunkHashes[index])
                ),
                384
            ),
            (A.CoverageFacts)
        );
        if (
            actual.coverageRecordHash != coverageHash || actual.artistId != a.artistId
                || actual.evidenceHash != a.chunkHashes[index]
                || actual.firstFamilyRecordHash != p.firstFamilyRecordHash
                || actual.secondFamilyRecordHash != p.secondFamilyRecordHash
        ) revert InvalidArtifactCoverage(planHash);
        (address pointer, bytes32 codeHash) = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(
                    IStreamArchivalChunkCoverage.chunkEnvelopePointer, (actual.envelopeHash)
                ),
                64
            ),
            (address, bytes32)
        );
        Part storage part = _parts[p.artifactHash][index];
        if (pointer != part.pointer || codeHash != part.codeHash) {
            revert InvalidArtifactCoverage(planHash);
        }
        p.evidenceChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_COVERED_PART_V1"),
                p.evidenceChainHash,
                planHash,
                index,
                a.chunkHashes[index],
                a.chunkLengths[index],
                pointer,
                codeHash,
                actual
            )
        );
        p.nextIndex = index + 1;
        _originalPartCoverage[planHash][index] = coverageHash;
        emit FinalityArtifactChunkCovered(1, planHash, index, coverageHash, p.evidenceChainHash);
        if (p.nextIndex == a.chunkHashes.length) {
            completionHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_ARTIFACT_COVERAGE_COMPLETE_V1"),
                    planHash,
                    p.artifactHash,
                    p.validationEpoch,
                    p.evidenceChainHash,
                    p.nextIndex
                )
            );
            F.Coverage memory result = F.Coverage(
                completionHash,
                p.artifactHash,
                a.artistId,
                a.schemaId,
                a.canonicalizationId,
                a.contentHash,
                a.byteLength,
                p.nextIndex,
                p.firstFamilyRecordHash,
                p.secondFamilyRecordHash,
                p.validationEpoch,
                p.evidenceChainHash
            );
            p.completionHash = completionHash;
            _coverage[completionHash] = result;
            _completionPlan[completionHash] = planHash;
            _initializeValidation(completionHash, p);
            emit FinalityArtifactCoverageCompleted(1, completionHash, planHash, result);
        }
    }

    function coveragePlan(bytes32 hash) external view override returns (F.Plan memory) {
        return _plans[hash];
    }

    function coverage(bytes32 hash) external view override returns (F.Coverage memory) {
        return _coverage[hash];
    }

    function currentCoverageValidation(bytes32 completionHash)
        external
        view
        override
        returns (F.Validation memory)
    {
        return _validations[_validationRecordPlan[_currentValidation[completionHash]]];
    }

    function coverageValidationRecord(bytes32 hash)
        external
        view
        override
        returns (F.Validation memory)
    {
        return _validations[_validationRecordPlan[hash]];
    }

    function refreshNextChunk(bytes32 completionHash, uint32 index, bytes32 currentCoverageHash)
        external
        override
        returns (bytes32 validationRecordHash)
    {
        F.Coverage storage original = _coverage[completionHash];
        if (completionHash == 0 || original.completionHash != completionHash) {
            revert InvalidArtifactCoverage(completionHash);
        }
        (bytes32 environment, uint64 epoch) = _environment();
        bytes32 planHash = _validationPlan(completionHash, environment, epoch);
        F.Validation storage v = _validations[planHash];
        if (v.validationRecordHash != 0) revert InvalidArtifactCoverage(planHash);
        if (index != v.nextIndex || index >= original.chunkCount) {
            revert ArtifactCoverageIndex(v.nextIndex, index);
        }
        if (v.completionHash == 0) {
            v.completionHash = completionHash;
            v.environmentHash = environment;
            v.validationEpoch = epoch;
            v.evidenceChainHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_ARTIFACT_REVALIDATION_CHAIN_V1"), planHash
                )
            );
        }
        _partPin(original.artifactHash, index);
        F.Artifact storage a = _artifacts[original.artifactHash];
        A.CoverageFacts memory actual = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(
                    IStreamArchivalCoverage.requireCoverage,
                    (currentCoverageHash, original.artistId, a.chunkHashes[index])
                ),
                384
            ),
            (A.CoverageFacts)
        );
        bytes32 originalCoverageHash = _originalPartCoverage[_completionPlan[completionHash]][index];
        A.CoverageFacts memory before_ = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(IStreamArchivalCoverage.coverage, (originalCoverageHash)),
                384
            ),
            (A.CoverageFacts)
        );
        if (
            before_.coverageRecordHash != originalCoverageHash
                || actual.coverageRecordHash != currentCoverageHash || before_.envelopeHash == 0
        ) revert InvalidArtifactCoverage(planHash);
        // Only current healthy fixity witnesses may advance. All archival identities stay exact.
        before_.coverageRecordHash = actual.coverageRecordHash;
        before_.firstFixityRecordHash = actual.firstFixityRecordHash;
        before_.secondFixityRecordHash = actual.secondFixityRecordHash;
        if (keccak256(abi.encode(before_)) != keccak256(abi.encode(actual))) {
            revert InvalidArtifactCoverage(planHash);
        }
        v.evidenceChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_REVALIDATED_PART_V1"),
                v.evidenceChainHash,
                planHash,
                index,
                originalCoverageHash,
                actual
            )
        );
        v.nextIndex = index + 1;
        emit FinalityArtifactValidationAdvanced(
            1, completionHash, planHash, index, currentCoverageHash, v.evidenceChainHash
        );
        if (v.nextIndex == original.chunkCount) {
            validationRecordHash = _completeValidation(planHash, v);
        }
    }

    function _initializeValidation(bytes32 completionHash, F.Plan storage p) private {
        bytes32 key = _validationPlan(completionHash, p.environmentHash, p.validationEpoch);
        F.Validation storage v = _validations[key];
        v.completionHash = completionHash;
        v.environmentHash = p.environmentHash;
        v.validationEpoch = p.validationEpoch;
        v.nextIndex = p.nextIndex;
        v.evidenceChainHash = p.evidenceChainHash;
        _completeValidation(key, v);
    }

    function _completeValidation(bytes32 key, F.Validation storage v)
        private
        returns (bytes32 hash)
    {
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_VALIDATION_RECORD_V1"),
                key,
                v.completionHash,
                v.environmentHash,
                v.validationEpoch,
                v.nextIndex,
                v.evidenceChainHash
            )
        );
        v.validationRecordHash = hash;
        _validationRecordPlan[hash] = key;
        _currentValidation[v.completionHash] = hash;
        emit FinalityArtifactValidationCompleted(1, hash, v);
    }

    function _validationPlan(bytes32 completionHash, bytes32 environment, uint64 epoch)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_REVALIDATION_PLAN_V1"),
                block.chainid,
                address(this),
                completionHash,
                environment,
                epoch
            )
        );
    }

    function requireArtifactCoverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash)
        external
        view
        override
        returns (F.Coverage memory result)
    {
        result = _coverage[hash];
        if (
            hash == 0 || result.completionHash != hash || result.artistId != artistId
                || result.artifactHash != artifactHash
        ) revert InvalidArtifactCoverage(hash);
        bytes32 record = _currentValidation[hash];
        F.Validation storage v = _validations[_validationRecordPlan[record]];
        (bytes32 environment, uint64 epoch) = _environment();
        if (
            record == 0 || v.validationRecordHash != record || v.completionHash != hash
                || v.nextIndex != result.chunkCount || v.environmentHash != environment
                || v.validationEpoch != epoch
        ) {
            revert ArtifactCoverageStale(_completionPlan[hash]);
        }
        for (uint32 i; i < result.chunkCount; ++i) {
            _partPin(artifactHash, i);
        }
    }

    function _current(bytes32 planHash, F.Plan storage p) private view {
        (bytes32 environment, uint64 epoch) = _environment();
        if (environment != p.environmentHash || epoch != p.validationEpoch) {
            revert ArtifactCoverageStale(planHash);
        }
    }

    function _partPin(bytes32 hash, uint32 index) private view {
        Part storage p = _parts[hash][index];
        if (
            p.pointer.codehash != p.codeHash
                || p.pointer.code.length != uint256(_artifacts[hash].chunkLengths[index]) + 1
        ) {
            revert ArtifactComponentChanged(p.pointer);
        }
    }

    function _environment() private view returns (bytes32 hash, uint64 epoch) {
        _storagePins();
        if (core.codehash != _coreCodeHash || archivalCoverage.codehash != _coverageCodeHash) {
            revert ArtifactComponentChanged(archivalCoverage);
        }
        bytes memory pointer = _read(
            core,
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            320
        );
        (address target, bytes32 codeHash,,,,,,,,) = abi.decode(
            pointer,
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (
            target != finalityRegistry || target.code.length == 0 || target.codehash != codeHash
                || _address(target, abi.encodeCall(IStreamFinalityArtifactBindings.core, ()))
                    != core
                || _address(
                        target, abi.encodeCall(IStreamFinalityArtifactBindings.artifactCoverage, ())
                    ) != address(this)
        ) {
            revert ArtifactComponentChanged(target);
        }
        bytes32 coverageEnvironment = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(IStreamArchivalChunkCoverage.requireCoverageEnvironment, ()),
                32
            ),
            (bytes32)
        );
        epoch = abi.decode(
            _read(
                archivalCoverage,
                abi.encodeCall(IStreamArchivalChunkCoverage.coverageValidationEpoch, ()),
                32
            ),
            (uint64)
        );
        if (epoch == 0 || coverageEnvironment == 0) revert InvalidArtifact();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_ENVIRONMENT_V1"),
                block.chainid,
                address(this),
                core,
                _coreCodeHash,
                archivalCoverage,
                _coverageCodeHash,
                schemaRegistry,
                _schemaCodeHash,
                chunkStore,
                _storeCodeHash,
                target,
                codeHash,
                coverageEnvironment
            )
        );
    }

    function _storagePins() private view {
        if (
            schemaRegistry.codehash != _schemaCodeHash || chunkStore.codehash != _storeCodeHash
                || _address(
                        schemaRegistry,
                        abi.encodeCall(IStreamFinalityArtifactBindings.chunkStore, ())
                    ) != chunkStore
        ) {
            revert ArtifactComponentChanged(schemaRegistry);
        }
    }

    function _bytes(address pointer, uint256 length) private view returns (bytes memory result) {
        bytes1 prefix;
        assembly ("memory-safe") {
            let scratch := mload(0x40)
            extcodecopy(pointer, scratch, 0, 1)
            prefix := mload(scratch)
        }
        if (prefix != 0) revert InvalidArtifact();
        result = new bytes(length);
        assembly ("memory-safe") { extcodecopy(pointer, add(result, 32), 1, length) }
    }

    function _address(address target, bytes memory data) private view returns (address result) {
        uint256 word = abi.decode(_read(target, data, 32), (uint256));
        if (word == 0 || word > type(uint160).max) revert ArtifactReadFailed(target);
        result = address(uint160(word));
    }

    function _read(address target, bytes memory data, uint256 expected)
        private
        view
        returns (bytes memory raw)
    {
        uint256 cap = gasParameter(_READ_GAS);
        if (cap > type(uint256).max / 2) revert ArtifactParentGas(gasleft(), type(uint256).max);
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert ArtifactParentGas(gasleft(), required);
        raw = new bytes(expected);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), expected)
            size := returndatasize()
        }
        if (!ok || size != expected) revert ArtifactReadFailed(target);
    }
}
