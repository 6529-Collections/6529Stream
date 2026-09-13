// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import "../../interfaces/stream/artist/StreamArtistRecoveryTypes.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/IStreamCanonicalArtworkFinality.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionArchive.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";

/// @notice Exact executed original finality and its immutable artist association in all five scopes.
/// @dev Current Binding, Attribution, authority, discovery and coverage are deliberately not read.
///      The fixed Coordinator supplies the immutable deployment pins; no caller-selected trust root.
library StreamArtistRecoveryOriginalReads {
    error RecoveryOriginalReadFailed(address target);
    error RecoveryOriginalParentGas(uint256 available, uint256 required);
    error RecoveryOriginalInvalid();

    struct Pins {
        address finalityRegistry;
        bytes32 finalityCodeHash;
        bytes32 coreCodeHash;
        bytes32 artistCodeHash;
        uint256 readGas;
    }

    struct Trace {
        uint256 cap;
        bytes32 hash;
    }

    struct Observation {
        StreamFinalityScope scope;
        S.Record sanction;
        StreamFinalityComponentExpectation[] components;
        bytes32 fullRecordHash;
        StreamFinalityExecutionWitness execution;
        StreamFinalitySanctionArchiveWitness archive;
        bytes32 rawReadHash;
    }

    function observe(T.SuiteConfiguration memory suite, Pins memory pins, bytes32 finalityHash)
        public
        view
        returns (Observation memory o)
    {
        _pins(suite, pins);
        if (finalityHash == 0) revert RecoveryOriginalInvalid();
        Trace memory t = Trace(pins.readGas, 0);
        _witnesses(suite, pins, t, finalityHash, o);
        o.sanction = _sanction(suite, t, o.archive.proof.sanctionRecordHash);
        o.scope = StreamFinalityScope(
            StreamFinalityScopeType(o.sanction.terms.scopeType),
            o.sanction.terms.collectionId,
            o.sanction.terms.tokenId,
            o.sanction.terms.scopeId
        );
        bytes32 componentsHash;
        (componentsHash, o.fullRecordHash) = _record(pins, t, finalityHash, o.scope);
        o.components = _components(suite, pins, t, o.scope, componentsHash, o.sanction.recordHash);
        _pins(suite, pins);
        o.rawReadHash = t.hash;
    }

    function _pins(T.SuiteConfiguration memory suite, Pins memory p) private view {
        if (
            p.finalityRegistry.code.length == 0 || p.finalityRegistry.codehash != p.finalityCodeHash
                || suite.core.code.length == 0 || suite.core.codehash != p.coreCodeHash
                || suite.registry.code.length == 0 || suite.registry.codehash != p.artistCodeHash
        ) revert T.InvalidBinding();
    }

    function _witnesses(
        T.SuiteConfiguration memory suite,
        Pins memory p,
        Trace memory t,
        bytes32 hash,
        Observation memory o
    ) private view {
        if (
            _address(t, p.finalityRegistry, IStreamFinalityDeploymentBindings.coreReads.selector)
                    != suite.core
                || _address(
                        t,
                        p.finalityRegistry,
                        IStreamFinalityDeploymentBindings.sanctionReads.selector
                    ) != suite.registry
        ) {
            revert RecoveryOriginalInvalid();
        }
        address artifact = _address(
            t, p.finalityRegistry, IStreamFinalityDeploymentBindings.artifactCoverage.selector
        );
        if (artifact == address(0)) revert RecoveryOriginalInvalid();
        bytes memory raw = _read(
            t,
            p.finalityRegistry,
            abi.encodeCall(IStreamCanonicalArtworkFinality.finalityExecutionWitness, (hash)),
            160,
            true
        );
        if (_word(raw, 32) >> 160 != 0 || _word(raw, 128) >> 64 != 0) {
            revert RecoveryOriginalInvalid();
        }
        o.execution = abi.decode(raw, (StreamFinalityExecutionWitness));
        if (
            o.execution.actionId == 0 || o.execution.proposer == address(0)
                || o.execution.roleMutationHash == 0 || o.execution.roleRevision == 0
        ) revert RecoveryOriginalInvalid();
        raw = _read(
            t,
            p.finalityRegistry,
            abi.encodeCall(IStreamFinalitySanctionArchive.finalitySanctionArchiveWitness, (hash)),
            128,
            true
        );
        o.archive = abi.decode(raw, (StreamFinalitySanctionArchiveWitness));
        StreamFinalitySanctionArchiveProof memory proof = o.archive.proof;
        if (
            proof.sanctionRecordHash == 0 || proof.artifactHash == 0 || proof.completionHash == 0
                || o.archive.evidenceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                            block.chainid,
                            suite.core,
                            p.finalityRegistry,
                            artifact,
                            proof
                        )
                    )
        ) revert RecoveryOriginalInvalid();
    }

    function _sanction(T.SuiteConfiguration memory suite, Trace memory t, bytes32 hash)
        private
        view
        returns (S.Record memory r)
    {
        bytes memory raw = _read(
            t,
            suite.owners[6],
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (hash)),
            512,
            true
        );
        if (
            _word(raw, 64) >> 160 != 0 || _word(raw, 96) >> 8 != 0 || _word(raw, 128) > 4
                || _word(raw, 352) >> 64 != 0 || _word(raw, 384) >> 64 != 0
                || _word(raw, 416) >> 64 != 0
        ) {
            revert RecoveryOriginalInvalid();
        }
        r = abi.decode(raw, (S.Record));
        S.Terms memory s = r.terms;
        if (
            r.recordHash != hash || r.artistId == 0 || r.bindingGeneration == 0
                || r.bindingHash == 0 || r.signer == address(0)
                || (r.authorityClass != 1 && r.authorityClass != 3) || s.collectionId == 0
                || (s.scopeType == 0 && (s.tokenId != 0 || s.scopeId != 0))
                || (s.scopeType == 1 && (s.tokenId == 0 || s.scopeId != 0))
                || (s.scopeType > 1 && (s.tokenId != 0 || s.scopeId == 0))
                || StreamArtistSanctionHashes.record(
                        StreamArtistHashes.Environment(
                            block.chainid, suite.registry, suite.core, suite.mintManager
                        ),
                        r
                    ) != hash
        ) revert RecoveryOriginalInvalid();
    }

    function _record(Pins memory p, Trace memory t, bytes32 hash, StreamFinalityScope memory scope)
        private
        view
        returns (bytes32 componentsHash, bytes32 fullRecordHash)
    {
        bytes memory raw;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            raw = _read(
                t,
                p.finalityRegistry,
                abi.encodeCall(
                    IStreamArtworkFinalityRegistry.collectionFinalityRecord, (scope.collectionId)
                ),
                33088,
                false
            );
            if (
                raw.length < 320 || _word(raw, 0) != 32 || _word(raw, 32) != 1
                    || _word(raw, 160) != 256 || _word(raw, 224) >> 160 != 0
                    || _word(raw, 256) >> 64 != 0
            ) revert RecoveryOriginalInvalid();
            _tail(raw, 320);
            StreamCollectionFinalityRecord memory r =
                abi.decode(raw, (StreamCollectionFinalityRecord));
            if (
                r.finalityRecordHash != hash || r.manifestContentHash == 0 || r.componentsHash == 0
                    || r.manifestPointer != p.finalityRegistry || r.finalizedAt == 0
                    || keccak256(bytes(r.finalityManifestURI)) != r.manifestURIHash
            ) revert RecoveryOriginalInvalid();
            return (r.componentsHash, keccak256(raw));
        }
        raw = _read(
            t,
            p.finalityRegistry,
            abi.encodeCall(IStreamArtworkFinalityRegistry.artworkScopeFinalityRecord, (scope)),
            33216,
            false
        );
        if (
            raw.length < 448 || _word(raw, 0) != 32 || _word(raw, 32) != 1 || _word(raw, 64) > 4
                || _word(raw, 320) != 384 || _word(raw, 352) >> 160 != 0
                || _word(raw, 384) >> 64 != 0
        ) {
            revert RecoveryOriginalInvalid();
        }
        _tail(raw, 448);
        StreamScopedFinalityRecord memory r = abi.decode(raw, (StreamScopedFinalityRecord));
        if (
            keccak256(abi.encode(r.scope)) != keccak256(abi.encode(scope))
                || r.finalityRecordHash != hash || r.manifestContentHash == 0
                || r.componentsHash == 0 || r.manifestPointer != p.finalityRegistry
                || r.finalizedAt == 0
                || keccak256(bytes(r.finalityManifestURI)) != r.manifestURIHash
        ) {
            revert RecoveryOriginalInvalid();
        }
        return (r.componentsHash, keccak256(raw));
    }

    function _tail(bytes memory raw, uint256 start) private pure {
        uint256 size = _word(raw, start - 32);
        if (size > 32768 || raw.length != start + ((size + 31) / 32) * 32) {
            revert RecoveryOriginalInvalid();
        }
        for (uint256 i = start + size; i < raw.length; ++i) {
            if (raw[i] != 0) revert RecoveryOriginalInvalid();
        }
    }

    function _components(
        T.SuiteConfiguration memory suite,
        Pins memory p,
        Trace memory t,
        StreamFinalityScope memory scope,
        bytes32 expected,
        bytes32 sanctionHash
    ) private view returns (StreamFinalityComponentExpectation[] memory items) {
        bool collection = scope.scopeType == StreamFinalityScopeType.COLLECTION;
        bytes memory callData = collection
            ? abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponentCount, (scope.collectionId)
            )
            : abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCountForScope, (scope));
        uint256 count = _word(_read(t, p.finalityRegistry, callData, 32, true), 0);
        if (count == 0 || count > 32) revert RecoveryOriginalInvalid();
        callData = collection
            ? abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponents, (scope.collectionId, 0, count)
            )
            : abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponentsForScope, (scope, 0, count)
            );
        bytes memory raw = _read(t, p.finalityRegistry, callData, 64 + 224 * count, true);
        if (_word(raw, 0) != 32 || _word(raw, 32) != count) revert RecoveryOriginalInvalid();
        for (uint256 i; i < count; ++i) {
            uint256 offset = 64 + 224 * i;
            if (
                _word(raw, offset + 32) >> 160 != 0 || uint224(_word(raw, offset + 64)) != 0
                    || (i != 0 && !_ascending(raw, offset - 224, offset))
            ) revert RecoveryOriginalInvalid();
        }
        items = abi.decode(raw, (StreamFinalityComponentExpectation[]));
        if (
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, items))
                != expected
        ) {
            revert RecoveryOriginalInvalid();
        }
        uint256 found;
        for (uint256 i; i < count; ++i) {
            StreamFinalityComponentExpectation memory item = items[i];
            if (item.componentType != keccak256("ARTIST_SANCTION")) continue;
            ++found;
            if (
                item.component != suite.registry || item.codeHash != p.artistCodeHash
                    || item.dataHash != sanctionHash
                    || item.interfaceId
                        != (collection
                                ? type(IStreamArtworkFinalityComponent).interfaceId
                                : type(IStreamArtworkScopedFinalityComponent).interfaceId)
                    || item.moduleVersion == 0 || item.manifestHash == 0
            ) revert RecoveryOriginalInvalid();
        }
        if (found != 1) revert RecoveryOriginalInvalid();
    }

    function _ascending(bytes memory raw, uint256 a, uint256 b) private pure returns (bool) {
        for (uint256 i; i < 224; i += 32) {
            uint256 left = _word(raw, a + i);
            uint256 right = _word(raw, b + i);
            if (left != right) return left < right;
        }
        return false;
    }

    function _address(Trace memory t, address target, bytes4 selector)
        private
        view
        returns (address)
    {
        uint256 value = _word(_read(t, target, abi.encodeWithSelector(selector), 32, true), 0);
        if (value >> 160 != 0) revert RecoveryOriginalInvalid();
        return address(uint160(value));
    }

    function _word(bytes memory raw, uint256 offset) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(raw, 32), offset)) }
    }

    function _read(Trace memory t, address target, bytes memory input, uint256 maximum, bool exact)
        private
        view
        returns (bytes memory raw)
    {
        uint256 cap = t.cap;
        if (cap == 0 || cap > type(uint256).max / 64) revert T.InvalidBinding();
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert RecoveryOriginalParentGas(gasleft(), required);
        raw = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert RecoveryOriginalReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, size) }
        t.hash = keccak256(abi.encode(t.hash, target, keccak256(input), keccak256(raw)));
    }
}
