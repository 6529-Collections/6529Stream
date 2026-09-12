// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistEstateTypes as Estate } from "./StreamArtistEstateTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

interface IStreamArtistEstateEvents {
    event ArtistEstateActivationRequested(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint64 requestedAt,
        uint64 noticeEndsAt,
        uint256 nonce,
        bytes32 evidenceHash,
        bytes32 activationRecordHash
    );
    event ArtistEstateActivationCancelled(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed canceller,
        uint8 authorityClass,
        bytes32 activationRecordHash
    );
    event ArtistSuccessionActivated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint8 authorityClass,
        uint32 effectiveCapabilities,
        bytes32 activationEvidenceHash,
        bytes32 governanceActionId
    );
}

interface IStreamArtistEstateActivation is IStreamArtistEstateEvents {
    function requestEstateActivation(
        Estate.Request calldata request,
        T.Authorization calldata authorization
    ) external returns (bytes32 activationRecordHash);
    function cancelEstateActivation(bytes32 artistId, bytes32 expectedActivationRecordHash) external;
    function executeEstateActivation(Estate.Execution calldata request) external;
    function estateActivationDigest(
        Estate.Request calldata request,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
    function estateActivationState(bytes32 artistId)
        external
        view
        returns (address successor, uint64 noticeEndsAt, bytes32 activationRecordHash);
    function estateActivationRecord(bytes32 activationRecordHash)
        external
        view
        returns (Estate.RequestRecord memory, uint8 phase, Estate.ExecutionFacts memory);
    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        returns (uint256);
    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (Estate.AuthorityCapabilities memory);
    function estateAccelerationContext(Estate.Execution calldata request)
        external
        view
        returns (Estate.AccelerationContext memory);
}
