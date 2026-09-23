// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

/// @notice The living artist's original op19 permission for a later steward sanction.
/// @dev A statement hash is the signed canonical-document commitment, not proof of retained JSON bytes.
interface IStreamArtistStewardSanctionGrant {
    struct Grant {
        bytes32 artistId;
        bool granted;
        bytes32 statementHash;
    }

    struct GrantRecord {
        bytes32 recordHash;
        Grant terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        R.ProvisionalAssociation provisional;
    }
    error InvalidStewardSanctionGrant(bytes32 artistId);
    event StewardSanctionGrantRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bool granted,
        bytes32 statementHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 grantRecordHash
    );
    function recordStewardSanctionGrant(
        Grant calldata terms,
        T.Authorization calldata authorization
    ) external returns (bytes32);
    function stewardSanctionGrant(bytes32 artistId)
        external
        view
        returns (bool granted, bytes32 grantRecordHash);
    function stewardSanctionGrantRecord(bytes32 recordHash)
        external
        view
        returns (GrantRecord memory);
    function stewardSanctionGrantSignature(bytes32 recordHash) external view returns (bytes memory);
    function stewardSanctionGrantDigest(
        Grant calldata terms,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
}

interface IStreamArtistStewardSanctionGrantOwner {
    function recordStewardSanctionGrant(
        T.ActionContext calldata context,
        IStreamArtistStewardSanctionGrant.Grant calldata terms,
        T.Authorization calldata authorization,
        T.SignerApproval calldata approval
    ) external returns (bytes32);
}

interface IStreamArtistStewardSanctionGrantCoordinator {
    function coordinateRecordStewardSanctionGrant(
        address actor,
        IStreamArtistStewardSanctionGrant.Grant calldata terms,
        T.Authorization calldata authorization
    ) external returns (bytes32);
}
