// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamGeneralAttestations as A
} from "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import "./StreamSchemaDocumentStore.sol";

/// @notice Bounded, code-pinned reads with a full EIP-150 parent-gas precheck.
library StreamGeneralAttestationReads {
    function code(address target, bytes32 expected) internal view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert A.GeneralDependencyChanged(target);
        }
    }

    function bounded(address target, bytes memory input, uint256 maximum, uint256 cap)
        public
        view
        returns (bytes memory output)
    {
        output = new bytes(maximum);
        uint256 available = gasleft();
        if (
            cap > type(uint256).max / 64 || available <= 10000
                || (available - 10000) / 64 * 63 < cap
        ) revert A.GeneralParentGas(available, cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert A.GeneralReadFailed(target);
        assembly ("memory-safe") { mstore(output, size) }
    }

    function fixedRead(address target, bytes memory input, uint256 length, uint256 cap)
        public
        view
        returns (bytes memory output)
    {
        output = bounded(target, input, length, cap);
        if (output.length != length) revert A.GeneralReadFailed(target);
    }

    function selected(
        address core,
        bytes32 coreHash,
        bytes32 kind,
        address target,
        bytes32 hash,
        uint256 cap
    ) public view {
        code(core, coreHash);
        code(target, hash);
        bytes memory raw = fixedRead(
            core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, cap
        );
        (address actual, bytes32 actualHash,,,,,,,,) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (actual != target || actualHash != hash) revert A.GeneralDependencyChanged(target);
    }

    function definition(
        address registry,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        uint256 cap
    ) public view returns (IStreamSchemaDocumentFacts.DocumentFacts memory f) {
        bytes memory raw = fixedRead(
            registry, abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)), 288, cap
        );
        f = abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists || f.kind != kind
                || f.contentHash == 0
        ) revert A.GeneralDefinitionUnavailable(id);
    }

    function exactDefinition(
        address registry,
        address store,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 expectedHash,
        uint256 expectedLength,
        uint256 cap
    ) public view {
        IStreamSchemaDocumentFacts.DocumentFacts memory f = definition(registry, id, kind, cap);
        if (
            f.contentHash != expectedHash || f.totalBytes != expectedLength
                || f.canonicalizationId != keccak256("RAW_BYTES") || f.supersedesId != 0
                || f.declarationHash == 0 || f.chunkCount == 0 || f.chunkCount > 64
        ) revert A.GeneralDefinitionUnavailable(id);
        bytes memory payload;
        for (uint256 i; i < f.chunkCount; ++i) {
            bytes32 hash = abi.decode(
                fixedRead(
                    registry,
                    abi.encodeCall(IStreamSchemaDocumentFacts.documentChunkHashAt, (id, i)),
                    32,
                    cap
                ),
                (bytes32)
            );
            bytes memory raw = bounded(
                store, abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 8256, cap
            );
            bytes memory chunk = abi.decode(raw, (bytes));
            if (
                keccak256(raw) != keccak256(abi.encode(chunk)) || keccak256(chunk) != hash
                    || chunk.length == 0 || chunk.length > 8192
                    || (i + 1 < f.chunkCount && chunk.length != 8192)
                    || payload.length + chunk.length > expectedLength
            ) revert A.GeneralDefinitionUnavailable(id);
            payload = bytes.concat(payload, chunk);
        }
        if (payload.length != expectedLength || keccak256(payload) != expectedHash) {
            revert A.GeneralDefinitionUnavailable(id);
        }
    }

    function operatorGrant(
        address metadata,
        uint256 collectionId,
        bytes32 family,
        address recorder,
        uint256 cap
    ) public view returns (uint64 revision) {
        bytes memory raw = fixedRead(
            metadata,
            abi.encodeCall(
                IStreamCollectionMetadataV1.familyWriter, (collectionId, family, uint8(3), recorder)
            ),
            64,
            cap
        );
        bool enabled;
        (enabled, revision) = abi.decode(raw, (bool, uint64));
        if (!enabled || revision == 0 || keccak256(raw) != keccak256(abi.encode(enabled, revision)))
        {
            revert A.GeneralAuthorityRequired();
        }
    }

    function operativeIdentity(address registry, bytes32 artistId, bytes32 expected, uint256 cap)
        public
        view
    {
        bytes32 actual = abi.decode(
            fixedRead(
                registry,
                abi.encodeCall(
                    IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (artistId)
                ),
                32,
                cap
            ),
            (bytes32)
        );
        if (expected == 0 || actual != expected) revert A.GeneralAuthorityRequired();
    }
}
