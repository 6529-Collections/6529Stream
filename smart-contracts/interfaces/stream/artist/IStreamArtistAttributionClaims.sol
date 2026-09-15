// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

library StreamArtistAttributionClaimTypes {
    struct Claim {
        bytes32 recordHash;
        uint256 collectionId;
        address claimant;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        string reasonURI;
        uint64 filedAt;
        address proposedArtist;
        bytes32 previousRecordHash;
        uint256 index;
    }
    error InvalidAttributionClaim(uint256 collectionId);
}

interface IStreamArtistAttributionClaims {
    event AttributionClaimFiled(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed claimant,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string reasonURI,
        uint64 filedAt,
        bytes32 claimRecordHash
    );
    function fileAttributionClaim(
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (bytes32);
    function attributionClaimRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistAttributionClaimTypes.Claim memory);
}

interface IStreamArtistAttributionClaimsOwner {
    function fileAttributionClaim(
        T.ActionContext calldata context,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI,
        address proposedArtist
    ) external returns (bytes32);
    function attributionClaimRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistAttributionClaimTypes.Claim memory);
}

interface IStreamArtistAttributionClaimsCoordinator {
    function coordinateFileAttributionClaim(
        address actor,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (bytes32);
}
