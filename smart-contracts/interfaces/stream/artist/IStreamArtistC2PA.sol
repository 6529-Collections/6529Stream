// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Original op24 credential statements and their independently retained identity heads.
library StreamArtistC2PATypes {
    /// @dev 1 = SHA-256 SubjectPublicKeyInfo; 2 = SHA-256 DER certificate.
    /// Other nonzero kinds remain opaque and can never establish a supported match.
    struct Credential {
        uint8 kind;
        bytes32 fingerprint;
        bytes32 keyId;
        uint64 validFrom;
        uint64 validUntil; // zero is unbounded; otherwise exclusive
    }

    /// @dev Canonical abi.encode(Payload). Empty credentials explicitly withdraw the enumeration.
    /// keyId references the operative identity document's publicKeyHistory; it is not an authority.
    struct Payload {
        uint16 schemaVersion;
        bytes32 artistId;
        bytes32 identityRecordHash;
        bytes32 previousRecordHash;
        Credential[] credentials;
    }

    struct Head {
        uint64 revision;
        bytes32 recordHash;
        bytes32 previousRecordHash;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 identityRecordHash;
        bytes32 statementHash;
        address sourceRegistry;
    }
}

interface IStreamArtistC2PAReads {
    function c2paCredentialHead(bytes32 artistId)
        external
        view
        returns (StreamArtistC2PATypes.Head memory);
    function c2paCredentialRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistC2PATypes.Head memory);
    /// @notice Credential updates never replace or satisfy the original personhood floor.
    function personhoodAttestation(uint256 collectionId, bytes32 artistId)
        external
        view
        returns (T.AttestationRecord memory);
}
