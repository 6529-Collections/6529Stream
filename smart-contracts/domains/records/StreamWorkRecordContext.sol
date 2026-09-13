// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkRecordDefinitions.sol";
import "./StreamWorkRecordJson.sol";
import "./StreamCollectionRecordHashes.sol";
import "./StreamRecordFamilies.sol";
import "./StreamRecordArtistIdentityReads.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Fixed WORK dependency graph and complete registered interpretation bytes.
/// @dev Stateless bounded reads; constructor selection and current use are separate caller decisions.
library StreamWorkRecordContext {
    bytes32 private constant RAW_BYTES = keccak256("RAW_BYTES");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");

    struct Dependencies {
        // Core, metadata host, schema registry, byte store.
        address[4] targets;
        bytes32[4] codeHashes;
        // Facade, Coordinator, Identity, Binding, Attribution owners.
        address[5] artists;
        bytes32[5] artistCodeHashes;
        uint256 chainId;
        uint256 readGas;
    }

    function currentContext(Dependencies memory d) public view returns (Dependencies memory) {
        if (block.chainid != d.chainId) {
            revert IStreamWorkRecordSelection.WorkDependencyChanged(d.targets[0]);
        }
        for (uint256 i; i < 4; ++i) {
            _code(d.targets[i], d.codeHashes[i]);
        }
        // The immutable pinned host's getter has no external calls.
        d.readGas = IStreamGasParameterHost(d.targets[1]).gasParameter(READ_GAS);
        if (d.readGas == 0 || d.readGas > type(uint64).max) {
            revert IStreamWorkRecordSelection.InvalidWorkConfiguration();
        }
        if (
            _word(
                        _fixed(
                            d,
                            d.targets[1],
                            abi.encodeCall(
                                IERC165.supportsInterface,
                                (type(IStreamCollectionRecordReceipts).interfaceId)
                            ),
                            32
                        ),
                        0
                    ) != bytes32(uint256(1))
                || _word(
                        _fixed(
                            d,
                            d.targets[2],
                            abi.encodeCall(
                                IERC165.supportsInterface,
                                (type(IStreamSchemaDocumentFacts).interfaceId)
                            ),
                            32
                        ),
                        0
                    ) != bytes32(uint256(1))
        ) revert IStreamWorkRecordSelection.InvalidWorkConfiguration();
        if (
            _hash(d, d.targets[1], "coreCodeHash()") != d.codeHashes[0]
                || _hash(d, d.targets[1], "schemaRegistryCodeHash()") != d.codeHashes[2]
                || _hash(d, d.targets[1], "chunkStoreCodeHash()") != d.codeHashes[3]
                || _address(d, d.targets[1], "core()") != d.targets[0]
                || _address(d, d.targets[1], "schemaRegistry()") != d.targets[2]
                || _address(d, d.targets[1], "chunkStore()") != d.targets[3]
                || _address(d, d.targets[2], "chunkStore()") != d.targets[3]
        ) revert IStreamWorkRecordSelection.InvalidWorkConfiguration();
        _selected(d, keccak256("COLLECTION_METADATA"), d.targets[1], d.codeHashes[1]);
        if (d.artists[0] != address(0)) {
            for (uint256 i; i < 5; ++i) {
                _code(d.artists[i], d.artistCodeHashes[i]);
            }
            bytes32 expectedArtists = keccak256(abi.encode(d.artists, d.artistCodeHashes));
            Dependencies memory fresh = pinArtists(d);
            if (keccak256(abi.encode(fresh.artists, fresh.artistCodeHashes)) != expectedArtists) {
                revert IStreamWorkRecordSelection.WorkAssociationChanged();
            }
        }
        return d;
    }

    function pinArtists(Dependencies memory d) public view returns (Dependencies memory) {
        StreamRecordArtistIdentityReads.Pins memory known = StreamRecordArtistIdentityReads.resolve(
            d.targets[1], d.targets[0], d.chainId, d.readGas
        );
        for (uint256 i; i < 3; ++i) {
            d.artists[i] = known.targets[i];
            d.artistCodeHashes[i] = known.codeHashes[i];
        }
        bytes memory suite =
            _fixed(d, d.artists[1], abi.encodeWithSignature("suiteConfiguration()"), 544);
        for (uint256 i; i < 17; ++i) {
            if (i != 15 && uint256(_word(suite, i)) > type(uint160).max) {
                revert IStreamWorkRecordSelection.WorkDependencyReadFailed(d.artists[1]);
            }
        }
        if (
            _word(suite, 0) != bytes32(uint256(uint160(d.artists[0])))
                || _word(suite, 9) != bytes32(uint256(uint160(d.targets[0])))
        ) revert IStreamWorkRecordSelection.InvalidWorkConfiguration();
        d.artists[3] = address(uint160(uint256(_word(suite, 2))));
        d.artists[4] = address(uint160(uint256(_word(suite, 6))));
        for (uint256 i = 3; i < 5; ++i) {
            if (d.artists[i].code.length == 0) {
                revert IStreamWorkRecordSelection.WorkDependencyChanged(d.artists[i]);
            }
            d.artistCodeHashes[i] = d.artists[i].codehash;
            if (
                _address(d, d.artists[i], "core()") != d.targets[0]
                    || _address(d, d.artists[i], "artistRegistry()") != d.artists[0]
                    || _address(d, d.artists[i], "operationCoordinator()") != d.artists[1]
                    || _hash(d, d.artists[i], "deploymentChainId()") != bytes32(d.chainId)
            ) revert IStreamWorkRecordSelection.InvalidWorkConfiguration();
        }
        _selected(d, keccak256("ARTIST_REGISTRY"), d.artists[0], d.artistCodeHashes[0]);
        return d;
    }

    function definitions(Dependencies memory d) public view {
        definition(
            d,
            StreamWorkRecordDefinitions.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamWorkRecordDefinitions.SCHEMA_HASH,
            StreamWorkRecordDefinitions.SCHEMA_BYTES,
            RAW_BYTES,
            true
        );
        definition(
            d,
            StreamWorkRecordDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamWorkRecordDefinitions.PROFILE_HASH,
            StreamWorkRecordDefinitions.PROFILE_BYTES,
            RAW_BYTES,
            true
        );
        definition(
            d,
            StreamWorkRecordDefinitions.CATALOG_SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamWorkRecordDefinitions.CATALOG_SCHEMA_HASH,
            StreamWorkRecordDefinitions.CATALOG_SCHEMA_BYTES,
            RAW_BYTES,
            true
        );
        definition(
            d,
            StreamWorkRecordDefinitions.CATALOG_PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamWorkRecordDefinitions.CATALOG_PROFILE_HASH,
            StreamWorkRecordDefinitions.CATALOG_PROFILE_BYTES,
            RAW_BYTES,
            true
        );
        definition(
            d,
            StreamWorkRecordDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamWorkRecordDefinitions.CANON_HASH,
            StreamWorkRecordDefinitions.CANON_BYTES,
            RAW_BYTES,
            true
        );
    }

    function document(Dependencies memory d, bytes32 id)
        public
        view
        returns (IStreamSchemaDocumentFacts.DocumentFacts memory row)
    {
        bytes memory raw = _fixed(
            d, d.targets[2], abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)), 288
        );
        row = abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        _canonical(d.targets[2], raw, abi.encode(row));
    }

    function definition(
        Dependencies memory d,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 hash,
        uint256 length,
        bytes32 canon,
        bool firstVersion
    ) public view returns (bytes memory payload) {
        IStreamSchemaDocumentFacts.DocumentFacts memory row = document(d, id);
        // The pinned Registry derives each immutable ID from its exact registered name.
        // URI is registration metadata; do not claim to re-create its declaration preimage.
        if (
            !row.exists || row.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || row.kind != kind || row.canonicalizationId != canon
                || (firstVersion && row.supersedesId != 0) || row.totalBytes != length
                || row.contentHash != hash || row.declarationHash == 0 || row.chunkCount == 0
                || row.chunkCount > 64 || length > 524288
        ) revert IStreamWorkRecordSelection.WorkDefinitionUnavailable(id);
        for (uint256 i; i < row.chunkCount; ++i) {
            bytes32 chunkHash = _word(
                _fixed(
                    d,
                    d.targets[2],
                    abi.encodeCall(IStreamSchemaDocumentFacts.documentChunkHashAt, (id, i)),
                    32
                ),
                0
            );
            bytes memory chunk = _chunk(d, chunkHash);
            if (
                chunk.length == 0 || chunk.length > 8192
                    || (i + 1 < row.chunkCount && chunk.length != 8192)
                    || payload.length + chunk.length > length
            ) revert IStreamWorkRecordSelection.WorkDefinitionUnavailable(id);
            payload = bytes.concat(payload, chunk);
        }
        if (payload.length != length || keccak256(payload) != hash) {
            revert IStreamWorkRecordSelection.WorkDefinitionUnavailable(id);
        }
    }

    function _selected(Dependencies memory d, bytes32 kind, address target, bytes32 codeHash)
        private
        view
    {
        bytes memory raw = _fixed(
            d, d.targets[0], abi.encodeWithSignature("getSatellitePointer(bytes32)", kind), 320
        );
        if (
            uint256(_word(raw, 0)) > type(uint160).max || uint256(_word(raw, 2)) > 1
                || uint256(_word(raw, 4)) & type(uint224).max != 0
                || uint256(_word(raw, 5)) > type(uint160).max
                || uint256(_word(raw, 6)) > type(uint8).max
                || uint256(_word(raw, 9)) > type(uint64).max
        ) revert IStreamWorkRecordSelection.WorkDependencyReadFailed(d.targets[0]);
        if (
            _word(raw, 0) != bytes32(uint256(uint160(target))) || _word(raw, 1) != codeHash
                || _word(raw, 3) != kind || _word(raw, 6) != bytes32(uint256(1))
        ) revert IStreamWorkRecordSelection.WorkHostNotSelected();
    }

    function _code(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert IStreamWorkRecordSelection.WorkDependencyChanged(target);
        }
    }

    function _address(Dependencies memory d, address target, string memory signature)
        private
        view
        returns (address)
    {
        uint256 word = uint256(_hash(d, target, signature));
        if (word > type(uint160).max) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
        return address(uint160(word));
    }

    function _hash(Dependencies memory d, address target, string memory signature)
        private
        view
        returns (bytes32)
    {
        return _word(_fixed(d, target, abi.encodeWithSignature(signature), 32), 0);
    }

    function _chunk(Dependencies memory d, bytes32 hash) private view returns (bytes memory chunk) {
        bytes memory raw = _read(
            d, d.targets[3], abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 8256
        );
        chunk = abi.decode(raw, (bytes));
        _canonical(d.targets[3], raw, abi.encode(chunk));
        if (keccak256(chunk) != hash) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(d.targets[3]);
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 word) {
        assembly ("memory-safe") { word := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (raw.length != encoded.length || keccak256(raw) != keccak256(encoded)) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
    }

    function _fixed(Dependencies memory d, address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory raw)
    {
        raw = _read(d, target, input, size);
        if (raw.length != size) revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
    }

    function _read(Dependencies memory d, address target, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory raw)
    {
        uint256 cap = d.readGas;
        raw = new bytes(maximum);
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) {
            revert IStreamWorkRecordSelection.WorkDependencyReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, size) }
    }
}
