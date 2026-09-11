// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";

/// @notice Identity and exact current-state snapshot of one isolated artist semantic owner.
interface IStreamArtistOwner {
    /// @notice Immutable Core whose collection identities are in this owner's records.
    function core() external view returns (address);
    /// @notice Immutable Manager included in the artist authorization domain.
    function mintManager() external view returns (address);
    function artistRegistry() external view returns (address);
    function operationCoordinator() external view returns (address);
    function archiveV2() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function domainId() external view returns (bytes32);
    function ownerStateSnapshotV2()
        external
        view
        returns (StreamArtistOnboardingTypes.Snapshot memory);
    function replayCell(bytes32 key)
        external
        view
        returns (StreamArtistOnboardingTypes.ReplayCell memory);
}
