// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPlatformTypes as PW } from "./StreamArtistPlatformTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

interface IStreamArtistPlatformWorks {
    function declarePlatformWorks(uint256 collectionId, bytes32 statementHash)
        external
        returns (bytes32);
    function filePlatformWorksClaim(
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (bytes32);
    function setPlatformWorksContest(
        uint256 collectionId,
        uint8 state,
        bytes32 claimRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external returns (bytes32);
    function approvePlatformWorksCorrection(
        uint256 collectionId,
        bytes32 claimRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external returns (bytes32);
    function platformWorksDeclaration(uint256 collectionId)
        external
        view
        returns (bool, bytes32, uint64);
    function platformWorksContest(uint256 collectionId) external view returns (uint8, bytes32);
    function platformWorksClaims(uint256 collectionId) external view returns (uint256, bytes32);
    function platformWorksCorrection(uint256 collectionId) external view returns (uint64, bytes32);
    function platformWorksState(uint256 collectionId) external view returns (PW.State memory);
    function platformWorksClaimRecord(bytes32 hash) external view returns (PW.Claim memory);
    function platformWorksContestRecord(bytes32 hash) external view returns (PW.Contest memory);
    function platformWorksContext(
        uint256 collectionId,
        uint8 state,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) external view returns (PW.Context memory);
}

interface IStreamArtistPlatformOwner {
    function platformWorksAdmission(uint256 collectionId)
        external
        view
        returns (PW.Admission memory);
    function platformWorksState(uint256 collectionId) external view returns (PW.State memory);
    function platformWorksClaimRecord(bytes32 hash) external view returns (PW.Claim memory);
    function platformWorksContestRecord(bytes32 hash) external view returns (PW.Contest memory);
    function declarePlatformWorks(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 statementHash
    ) external returns (bytes32);
    function filePlatformWorksClaim(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI,
        address proposedArtist
    ) external returns (bytes32);
    function setPlatformWorksContest(
        T.ActionContext calldata c,
        uint256 collectionId,
        uint8 state,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId,
        address adjudicatedArtist
    ) external returns (bytes32);
    function approvePlatformWorksCorrection(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId
    ) external returns (bytes32);
}

interface IStreamArtistPlatformCoordinator {
    function coordinateDeclarePlatformWorks(
        address actor,
        uint256 collectionId,
        bytes32 statementHash
    ) external returns (bytes32);
    function coordinateFilePlatformWorksClaim(
        address actor,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (bytes32);
    function coordinateSetPlatformWorksContest(
        address actor,
        uint256 collectionId,
        uint8 state,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason
    ) external returns (bytes32);
    function coordinateApprovePlatformWorksCorrection(
        address actor,
        uint256 collectionId,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason
    ) external returns (bytes32);
    function platformWorksContext(
        uint256 collectionId,
        uint8 state,
        bytes32 claim,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) external view returns (PW.Context memory);
}
