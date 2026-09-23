// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Supplemental exact-source V2 VIEW reads for bounded checkpoint transactions.
/// @dev A consumer must pin the actual adapter runtime and configuration. Returned bytes
/// are observations, not a snapshot, archived execution, or finality acceptance.
interface IStreamViewCheckpointServingV2 {
    struct Binding {
        address core;
        bytes32 coreCodeHash;
        address router;
        bytes32 routerCodeHash;
        uint256 chainId;
        uint32 rendererGas;
    }
    function binding() external view returns (Binding memory);
    function workerBinding() external view returns (address worker, bytes32 runtimeHash);
    function configurationHash() external view returns (bytes32);
    function currentOutput(StreamFinalityScope calldata scope, uint256 tokenId, uint8 mode)
        external
        view
        returns (bytes32 adoptionRecord, string memory output);
    function historicalOutput(bytes32 adoptionRecord, uint256 tokenId, uint8 mode)
        external
        view
        returns (StreamFinalityScope memory scope, string memory output);
}
