// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact detached metadata publication authorization carried by the unchanged op24 signature.
library StreamArtistRecordPublicationTypes {
    /// @dev The actual host's candidate preimage excludes the separate attestation backlink.
    ///      Generic record signatureScheme/signatureHash fields are zero/empty in this profile.
    struct Publication {
        address metadataHost;
        address recorder;
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 recordType;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        uint16 payloadAlgorithm;
        bytes32 payloadHash;
        bytes32 uriHash;
        uint64 effectiveAt;
        bytes32 candidateRecordHash;
    }

    struct Evidence {
        bytes32 attestationRecordHash;
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 bindingGeneration;
        address signer;
        uint8 authorityClass;
        uint32 requiredCapability;
        uint64 signedAt;
        bytes32 publicationHash;
    }
}
