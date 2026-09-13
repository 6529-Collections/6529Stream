// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionArchive.sol";

/// @notice Registered immutable interpretation definitions for the fixed sanction artifact profile.
/// @dev Definition retirement does not revoke existing references. The actual byte hashes remain exact.
library StreamFinalitySanctionSchemas {
    function requireDefinitions(address artifact, uint256 cap) public view {
        bytes memory registryData = _read(
            artifact, abi.encodeCall(IStreamFinalityArtifactCoverage.schemaRegistry, ()), 32, cap
        );
        if (registryData.length != 32) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        }
        uint256 word = abi.decode(registryData, (uint256));
        if (word == 0 || word > type(uint160).max) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        }
        address registry = address(uint160(word));
        _definition(
            registry,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a,
            2574,
            cap
        );
        _definition(
            registry,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"),
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690,
            1221,
            cap
        );
        _definition(
            registry,
            keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_V1"),
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a,
            3687,
            cap
        );
        _definition(
            registry,
            keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1"),
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4,
            1246,
            cap
        );
    }

    function _definition(
        address registry,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 expectedHash,
        uint256 expectedLength,
        uint256 cap
    ) private view {
        IStreamSchemaRegistry.DocumentView memory doc = abi.decode(
            _read(registry, abi.encodeCall(IStreamSchemaRegistry.document, (id)), 8192, cap),
            (IStreamSchemaRegistry.DocumentView)
        );
        if (
            !doc.exists || doc.specification.kind != kind
                || keccak256(bytes(doc.specification.name)) != id
                || doc.specification.contentHash != expectedHash
                || doc.specification.totalBytes != expectedLength
                || doc.specification.canonicalizationId != keccak256("RAW_BYTES")
        ) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        }
        bytes memory definition = abi.decode(
            _read(registry, abi.encodeCall(IStreamSchemaRegistry.documentBytes, (id)), 8256, cap),
            (bytes)
        );
        if (definition.length != expectedLength || keccak256(definition) != expectedHash) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid();
        }
    }

    function _read(address target, bytes memory data, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        if (cap == 0 || cap > type(uint256).max / 64 || gasleft() <= cap + cap / 63 + 100000) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveReadFailed(target);
        }
        out = new bytes(maximum);
        bool ok;
        uint256 length;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(out, 32), maximum)
            length := returndatasize()
        }
        if (!ok || length > maximum) {
            revert IStreamFinalitySanctionArchive.FinalitySanctionArchiveReadFailed(target);
        }
        assembly ("memory-safe") { mstore(out, length) }
    }
}
