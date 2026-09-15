// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

library StreamArtistIdentityRevisionTypes {
    struct Revision {
        bytes32 artistId;
        bytes32 previousRecordHash;
        bytes32 revisedRecordHash;
        string identityRecordURI;
    }

    struct Record {
        bytes32 recordHash;
        bytes32 artistId;
        bytes32 previousRecordHash;
        bytes32 revisedRecordHash;
        bytes32 previousRevisionRecord;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        string identityRecordURI;
        string displayName;
    }
}

/// @notice Current identity documents with immutable registration and revision history.
/// @dev Mirrors are non-authoritative; hash-verified document bytes take precedence.
interface IStreamArtistIdentityRevisionReads {
    function operativeIdentityRecord(bytes32 artistId) external view returns (bytes32);
    function identityRecordBytes(bytes32 artistId) external view returns (bytes memory);
    function identityDocumentBytes(bytes32 identityRecordHash) external view returns (bytes memory);
    function artistDisplayName(bytes32 artistId) external view returns (string memory, bytes32);
    function identityRevisionRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory);
}

interface IStreamArtistIdentityRevision is IStreamArtistIdentityRevisionReads {
    /// @dev Direct time=0 records observed inclusion time; signed relays preserve their signedAt.
    function recordIdentityRevision(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
    function identityRevisionDigest(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32);
}

interface IStreamArtistIdentityRevisionCoordinator {
    function coordinateRecordIdentityRevision(
        address actor,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
}

interface IStreamArtistIdentityRevisionOwner is IStreamArtistIdentityRevisionReads {
    function recordIdentityRevision(
        T.ActionContext calldata c,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
    /// @notice Exact operative proposal facts; never changes the immutable identity tuple.
    function operativeIdentityMetadata(bytes32 artistId)
        external
        view
        returns (bytes32 documentHash, string memory uri, string memory displayName);
}

/// @notice Typed cross-domain fact from the guarded Coordinator; no owner-to-owner callbacks.
interface IStreamArtistIdentityAttestationOwner {
    function recordIdentityAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32);
}
