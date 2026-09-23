// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistEstateActivation.sol";
import "./StreamArtistIdentityContestTypes.sol";
import "../preservation/StreamArchivalTypes.sol";

interface IStreamArtistEstateBinding {
    function archivalCoverage() external view returns (address);
    function archivalCoverageCodeHash() external view returns (bytes32);
    function archivalCoverageConfigurationHash() external view returns (bytes32);
}

interface IStreamArtistEstateOwner {
    function estateRequestFacts(Estate.Request calldata p, bytes32 envelopeHash)
        external
        view
        returns (Estate.RequestFacts memory);
    function estateExecutionFacts(Estate.Execution calldata p, bytes32 envelopeHash)
        external
        view
        returns (uint32 capabilities, Estate.AccelerationContext memory);
    function requestEstate(
        T.ActionContext calldata c,
        Estate.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        StreamArchivalTypes.CoverageFacts calldata coverage
    ) external returns (bytes32);
    function cancelEstate(T.ActionContext calldata c, bytes32 artistId, bytes32 expected) external;
    function executeEstate(
        T.ActionContext calldata c,
        Estate.Execution calldata p,
        StreamArchivalTypes.CoverageFacts calldata coverage,
        StreamArtistIdentityContestTypes.GovernanceWitness calldata governance
    ) external;
    function estateActivationState(bytes32 artistId)
        external
        view
        returns (address successor, uint64 noticeEndsAt, bytes32 activationRecordHash);
    function estateActivationRecord(bytes32 record)
        external
        view
        returns (Estate.RequestRecord memory, uint8, Estate.ExecutionFacts memory);
    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        returns (uint256);
    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (Estate.AuthorityCapabilities memory);
    function estateActivationDigest(Estate.Request calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function estateTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64);
    function delegationEpochState(bytes32 grant) external view returns (bool, uint64, uint64);
}

interface IStreamArtistEstateCoordinator {
    function coordinateRequestEstateActivation(
        address actor,
        Estate.Request calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateCancelEstateActivation(address actor, bytes32 artistId, bytes32 expected)
        external;
    function coordinateExecuteEstateActivation(address actor, Estate.Execution calldata p) external;
}
