// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent sanction terms and the separately stored authorization context.
library StreamArtistSanctionTypes {
    struct Terms {
        uint8 scopeType;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 scopeId;
        bytes32 sanctionSubjectHash;
        bytes32 statementHash;
    }

    /// @notice Every word of the permanent AA-SANCTION subject preimage, in its original order.
    struct Subject {
        bytes32 domain;
        uint256 chainId;
        address core;
        address finalityRegistry;
        uint8 scopeType;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 scopeId;
        bytes32 coreFactsHash;
        bytes32 nonSanctionComponentsHash;
        bytes32 manifestURIHash;
        bytes32 manifestContentHash;
        bytes32 manifestSchemaId;
        bytes32 manifestCanonicalizationHash;
    }

    /// @dev The authoritative producer validates the covered hashes; the text describes the signing session.
    struct Ceremony {
        bytes32 contentRoot;
        bytes32[] mediaHashes;
        bytes32[] referenceRenderHashes;
        string statement;
        string signingToolName;
        string signingToolVersion;
    }

    /// @notice Historical signer and association evidence. Deadline is distinct from observed signedAt.
    /// @dev Only the fourteen permanent AA-SANCTION fields enter recordHash. The remaining fields
    ///      are immutable admission evidence and the independently archived authorization context.
    struct Record {
        bytes32 recordHash;
        bytes32 artistId;
        address signer;
        uint8 authorityClass;
        Terms terms;
        uint256 nonce;
        uint64 signedAt;
        uint64 deadline;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        bytes32 digest;
    }

    error InvalidSanction();
    error InvalidSanctionCeremony();
    error SanctionSignatureRequired();
}
