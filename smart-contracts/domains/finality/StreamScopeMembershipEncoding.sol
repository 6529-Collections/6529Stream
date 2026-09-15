// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Canonical byte grammar and hashes; no publication or token authority is inferred.
library StreamScopeMembershipEncoding {
    bytes32 internal constant SCOPE_ID_DOMAIN = keccak256("6529STREAM_SCOPE_MEMBERSHIP_ID_V1");
    bytes32 internal constant MEMBERSHIP_DOMAIN = keccak256("6529STREAM_SCOPE_MEMBERSHIP_FACTS_V1");
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
    bytes32 internal constant CANONICALIZATION_ID = keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1");
    uint256 internal constant CHUNK_BYTES = 8192;
    uint256 internal constant MAX_CHUNKS = 64;

    error InvalidScopeMembershipEncoding();

    function encode(StreamScopeMembershipManifest memory m) public pure returns (bytes memory raw) {
        _shape(m);
        raw = abi.encode(
            m.version,
            m.chainId,
            m.core,
            m.collectionId,
            m.scopeType,
            m.tokenCount,
            m.tokenListHash,
            m.chunkHashes
        );
    }

    function decode(bytes memory raw) public pure returns (StreamScopeMembershipManifest memory m) {
        if (raw.length < 288 || raw.length > 288 + 32 * MAX_CHUNKS) {
            revert InvalidScopeMembershipEncoding();
        }
        uint256 parts = _word(raw, 8);
        if (
            _word(raw, 0) != 1 || _word(raw, 2) >> 160 != 0 || _word(raw, 4) > type(uint8).max
                || _word(raw, 7) != 256 || parts > MAX_CHUNKS || raw.length != 288 + 32 * parts
        ) revert InvalidScopeMembershipEncoding();
        m.version = 1;
        m.chainId = _word(raw, 1);
        m.core = address(uint160(_word(raw, 2)));
        m.collectionId = _word(raw, 3);
        m.scopeType = uint8(_word(raw, 4));
        m.tokenCount = _word(raw, 5);
        m.tokenListHash = bytes32(_word(raw, 6));
        m.chunkHashes = new bytes32[](parts);
        for (uint256 i; i < parts; ++i) {
            m.chunkHashes[i] = bytes32(_word(raw, 9 + i));
        }
        _shape(m);
    }

    function scopeId(
        uint256 chainId,
        address core,
        uint256 collectionId,
        uint8 scopeType,
        bytes32 recordHash
    ) public pure returns (bytes32) {
        if (
            core == address(0) || collectionId == 0 || scopeType < 2 || scopeType > 4
                || recordHash == 0
        ) {
            revert InvalidScopeMembershipEncoding();
        }
        return
            keccak256(
                abi.encode(SCOPE_ID_DOMAIN, chainId, core, collectionId, scopeType, recordHash)
            );
    }

    function membershipHash(
        uint256 chainId,
        address core,
        address metadataHost,
        address inventory,
        StreamFinalityScope memory scope,
        StreamScopeMembershipFacts memory f
    ) public pure returns (bytes32) {
        // The output hash field is intentionally excluded; all other seven fact words are bound.
        bytes32 factsHash = keccak256(
            abi.encode(
                f.scopeSubject,
                f.scopeManifestHash,
                f.sourceRecordHash,
                f.tokenCount,
                f.tokenListHash,
                f.inventoryCount,
                f.inventoryPrefixHash
            )
        );
        return keccak256(
            abi.encode(MEMBERSHIP_DOMAIN, chainId, core, metadataHost, inventory, scope, factsHash)
        );
    }

    function _shape(StreamScopeMembershipManifest memory m) private pure {
        if (
            m.version != 1 || m.core == address(0) || m.collectionId == 0 || m.scopeType < 2
                || m.scopeType > 4 || m.tokenCount > MAX_CHUNKS * CHUNK_BYTES / 32
                || m.chunkHashes.length != (m.tokenCount * 32 + CHUNK_BYTES - 1) / CHUNK_BYTES
                || m.tokenListHash == 0 || (m.tokenCount == 0 && m.tokenListHash != keccak256(""))
        ) revert InvalidScopeMembershipEncoding();
        for (uint256 i; i < m.chunkHashes.length; ++i) {
            if (m.chunkHashes[i] == 0) revert InvalidScopeMembershipEncoding();
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }
}
