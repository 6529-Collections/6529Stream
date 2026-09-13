// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianAppealTypes as A } from "./StreamArtistGuardianAppealTypes.sol";

interface IStreamArtistGuardianAppealEvidence {
    function owner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function publish(A.Document calldata document) external returns (bytes32);
    function evidence(bytes32 documentHash)
        external
        view
        returns (A.Document memory, bytes32 ownerCodeHash);
}

interface IStreamArtistGuardianAppealBinding {
    function guardianAppealEvidenceBinding() external view returns (address, bytes32);
}

interface IStreamArtistGuardianAppealOwner {
    function guardianRecoveryAuthorityRole(bytes32 artistId, bytes32[] calldata records)
        external
        view
        returns (bytes32);
}
