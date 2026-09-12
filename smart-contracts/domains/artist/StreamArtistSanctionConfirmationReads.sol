// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/IStreamCanonicalArtworkFinality.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionArchive.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";

/// @notice Canonical stored execution evidence; current discovery and coverage are not queried.
/// @dev Only the locked Coordinator supplies its immutable deployment pins to operative calls.
library StreamArtistSanctionConfirmationReads {
    struct Pins {
        address finalityRegistry;
        bytes32 finalityCodeHash;
        bytes32 coreCodeHash;
        bytes32 artistCodeHash;
        uint256 readGas;
    }

    struct Trace {
        uint256 readGas;
        bytes32 hash;
    }

    function observe(T.SuiteConfiguration memory suite, Pins memory pins, uint256 collectionId)
        public
        view
        returns (Confirmation.Observation memory o)
    {
        _pins(suite, pins);
        Trace memory trace = Trace(pins.readGas, bytes32(0));
        o.binding_ = _binding(suite, trace, collectionId);
        bytes memory raw = _read(
            trace,
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (collectionId)),
            64
        );
        if (_word(raw, 0) != 2 || _word(raw, 32) != o.binding_.generation) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        o.priorAttributionState = uint8(_word(raw, 0));
        StreamFinalityComponentState memory current = _component(suite, pins, trace, collectionId);
        o.sanction = _sanction(suite, trace, collectionId, o.binding_, current.dataHash);
        o.finalityRecord = _record(pins, trace, collectionId);
        o.components =
            _components(pins, trace, collectionId, o.finalityRecord.componentsHash, current);
        _witnesses(suite, pins, trace, o);
        _pins(suite, pins);
        o.rawReadHash = trace.hash;
    }

    function _pins(T.SuiteConfiguration memory suite, Pins memory pins) private view {
        if (
            pins.finalityRegistry.code.length == 0
                || pins.finalityRegistry.codehash != pins.finalityCodeHash
                || suite.core.code.length == 0 || suite.core.codehash != pins.coreCodeHash
                || suite.registry.code.length == 0 || suite.registry.codehash != pins.artistCodeHash
        ) revert T.InvalidBinding();
    }

    function _binding(T.SuiteConfiguration memory suite, Trace memory trace, uint256 collectionId)
        private
        view
        returns (T.Binding memory b)
    {
        bytes memory raw = _read(
            trace,
            suite.owners[0],
            abi.encodeCall(IStreamArtistBindingOwner.binding, (collectionId)),
            320
        );
        if (
            collectionId == 0 || _word(raw, 32) >> 160 != 0 || _word(raw, 128) >> 64 != 0
                || _word(raw, 160) >> 8 != 0 || _word(raw, 192) >> 8 != 0
                || _word(raw, 224) >> 8 != 0 || _word(raw, 256) >> 160 != 0 || _word(raw, 288) != 1
        ) revert Confirmation.InvalidSanctionConfirmation();
        b = abi.decode(raw, (T.Binding));
        if (b.artistId == 0 || b.bindingHash == 0 || b.generation == 0) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
    }

    function _component(
        T.SuiteConfiguration memory suite,
        Pins memory pins,
        Trace memory trace,
        uint256 collectionId
    ) private view returns (StreamFinalityComponentState memory value) {
        bytes memory raw = _read(
            trace,
            suite.registry,
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (collectionId)),
            256
        );
        if (_word(raw, 0) != 1 || _word(raw, 64) >> 160 != 0 || uint224(_word(raw, 96)) != 0) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        value = abi.decode(raw, (StreamFinalityComponentState));
        if (
            value.componentType != keccak256("ARTIST_SANCTION") || value.component != suite.registry
                || value.interfaceId != type(IStreamArtworkFinalityComponent).interfaceId
                || value.codeHash != pins.artistCodeHash || value.dataHash == 0
        ) revert Confirmation.InvalidSanctionConfirmation();
    }

    function _sanction(
        T.SuiteConfiguration memory suite,
        Trace memory trace,
        uint256 collectionId,
        T.Binding memory b,
        bytes32 hash
    ) private view returns (S.Record memory r) {
        bytes memory raw = _read(
            trace,
            suite.owners[6],
            abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (hash)),
            512
        );
        if (
            _word(raw, 64) >> 160 != 0 || _word(raw, 96) >> 8 != 0 || _word(raw, 128) != 0
                || _word(raw, 352) >> 64 != 0 || _word(raw, 384) >> 64 != 0
                || _word(raw, 416) >> 64 != 0
        ) revert Confirmation.InvalidSanctionConfirmation();
        r = abi.decode(raw, (S.Record));
        if (
            r.recordHash != hash || r.artistId != b.artistId || r.bindingGeneration != b.generation
                || r.bindingHash != b.bindingHash || r.signer == address(0)
                || (r.authorityClass != 1 && r.authorityClass != 3)
                || r.terms.collectionId != collectionId || r.terms.tokenId != 0
                || r.terms.scopeId != 0
                || StreamArtistSanctionHashes.record(
                        StreamArtistHashes.Environment(
                            block.chainid, suite.registry, suite.core, suite.mintManager
                        ),
                        r
                    ) != hash
        ) revert Confirmation.InvalidSanctionConfirmation();
    }

    function _record(Pins memory pins, Trace memory trace, uint256 collectionId)
        private
        view
        returns (StreamCollectionFinalityRecord memory r)
    {
        // The registry's total finalization calldata ceiling makes this a conservative URI bound.
        bytes memory raw = _readBounded(
            trace,
            pins.finalityRegistry,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (collectionId)),
            33088,
            false
        );
        if (
            raw.length < 320 || _word(raw, 0) != 32 || _word(raw, 32) != 1 || _word(raw, 160) != 256
                || _word(raw, 224) >> 160 != 0 || _word(raw, 256) >> 64 != 0
        ) revert Confirmation.InvalidSanctionConfirmation();
        uint256 length = _word(raw, 288);
        if (length > 32768 || raw.length != 320 + ((length + 31) / 32) * 32) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        for (uint256 i = 320 + length; i < raw.length; ++i) {
            if (raw[i] != 0) revert Confirmation.InvalidSanctionConfirmation();
        }
        r = abi.decode(raw, (StreamCollectionFinalityRecord));
        if (
            r.finalityRecordHash == 0 || r.manifestContentHash == 0 || r.componentsHash == 0
                || r.manifestPointer != pins.finalityRegistry || r.finalizedAt == 0
                || keccak256(bytes(r.finalityManifestURI)) != r.manifestURIHash
        ) revert Confirmation.InvalidSanctionConfirmation();
    }

    function _components(
        Pins memory pins,
        Trace memory trace,
        uint256 collectionId,
        bytes32 expected,
        StreamFinalityComponentState memory current
    ) private view returns (StreamFinalityComponentExpectation[] memory items) {
        uint256 count = _word(
            _read(
                trace,
                pins.finalityRegistry,
                abi.encodeCall(
                    IStreamArtworkFinalityRegistry.finalityComponentCount, (collectionId)
                ),
                32
            ),
            0
        );
        if (count == 0 || count > 32) revert Confirmation.InvalidSanctionConfirmation();
        bytes memory raw = _read(
            trace,
            pins.finalityRegistry,
            abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponents, (collectionId, 0, count)
            ),
            64 + 224 * count
        );
        if (_word(raw, 0) != 32 || _word(raw, 32) != count) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        for (uint256 i; i < count; ++i) {
            uint256 offset = 64 + 224 * i;
            if (_word(raw, offset + 32) >> 160 != 0 || uint224(_word(raw, offset + 64)) != 0) {
                revert Confirmation.InvalidSanctionConfirmation();
            }
            if (i != 0 && !_ascending(raw, offset - 224, offset)) {
                revert Confirmation.InvalidSanctionConfirmation();
            }
        }
        items = abi.decode(raw, (StreamFinalityComponentExpectation[]));
        if (
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, items))
                != expected
        ) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        uint256 found;
        for (uint256 i; i < count; ++i) {
            if (items[i].componentType != keccak256("ARTIST_SANCTION")) continue;
            ++found;
            StreamFinalityComponentExpectation memory match_ = StreamFinalityComponentExpectation(
                current.componentType,
                current.component,
                current.interfaceId,
                current.codeHash,
                current.moduleVersion,
                current.manifestHash,
                current.dataHash
            );
            if (keccak256(abi.encode(items[i])) != keccak256(abi.encode(match_))) {
                revert Confirmation.InvalidSanctionConfirmation();
            }
        }
        if (found != 1) revert Confirmation.InvalidSanctionConfirmation();
    }

    function _ascending(bytes memory raw, uint256 previous, uint256 next)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < 224; i += 32) {
            uint256 a = _word(raw, previous + i);
            uint256 b = _word(raw, next + i);
            if (a != b) return a < b;
        }
        return false;
    }

    function _witnesses(
        T.SuiteConfiguration memory suite,
        Pins memory pins,
        Trace memory trace,
        Confirmation.Observation memory o
    ) private view {
        if (
            _address(
                        trace,
                        pins.finalityRegistry,
                        IStreamFinalityDeploymentBindings.coreReads.selector
                    ) != suite.core
                || _address(
                        trace,
                        pins.finalityRegistry,
                        IStreamFinalityDeploymentBindings.sanctionReads.selector
                    ) != suite.registry
        ) revert Confirmation.InvalidSanctionConfirmation();
        address artifact = _address(
            trace,
            pins.finalityRegistry,
            IStreamFinalityDeploymentBindings.artifactCoverage.selector
        );
        if (artifact == address(0)) revert Confirmation.InvalidSanctionConfirmation();
        bytes32 hash = o.finalityRecord.finalityRecordHash;
        bytes memory raw = _read(
            trace,
            pins.finalityRegistry,
            abi.encodeCall(IStreamCanonicalArtworkFinality.finalityExecutionWitness, (hash)),
            160
        );
        if (_word(raw, 32) >> 160 != 0 || _word(raw, 128) >> 64 != 0) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        o.executionWitness = abi.decode(raw, (StreamFinalityExecutionWitness));
        if (
            o.executionWitness.actionId == 0 || o.executionWitness.proposer == address(0)
                || o.executionWitness.roleMutationHash == 0 || o.executionWitness.roleRevision == 0
        ) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        raw = _read(
            trace,
            pins.finalityRegistry,
            abi.encodeCall(IStreamFinalitySanctionArchive.finalitySanctionArchiveWitness, (hash)),
            128
        );
        o.archiveWitness = abi.decode(raw, (StreamFinalitySanctionArchiveWitness));
        StreamFinalitySanctionArchiveProof memory proof = o.archiveWitness.proof;
        if (
            proof.sanctionRecordHash != o.sanction.recordHash || proof.artifactHash == 0
                || proof.completionHash == 0
                || o.archiveWitness.evidenceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                            block.chainid,
                            suite.core,
                            pins.finalityRegistry,
                            artifact,
                            proof
                        )
                    )
        ) revert Confirmation.InvalidSanctionConfirmation();
    }

    function _address(Trace memory trace, address target, bytes4 selector)
        private
        view
        returns (address)
    {
        uint256 value = _word(_read(trace, target, abi.encodeWithSelector(selector), 32), 0);
        if (value >> 160 != 0) revert Confirmation.InvalidSanctionConfirmation();
        return address(uint160(value));
    }

    function _word(bytes memory value, uint256 offset) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(value, 32), offset)) }
    }

    function _read(Trace memory trace, address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return _readBounded(trace, target, data, size, true);
    }

    function _readBounded(
        Trace memory trace,
        address target,
        bytes memory data,
        uint256 size,
        bool exact
    ) private view returns (bytes memory raw) {
        uint256 cap = trace.readGas;
        if (cap == 0 || cap > type(uint256).max / 64) revert T.InvalidBinding();
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert Confirmation.SanctionConfirmationParentGas(gasleft(), required);
        }
        raw = new bytes(size);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned > size || (exact && returned != size)) {
            revert Confirmation.SanctionConfirmationReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, returned) }
        trace.hash = keccak256(abi.encode(trace.hash, target, keccak256(data), keccak256(raw)));
    }
}
