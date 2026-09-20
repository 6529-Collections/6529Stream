// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Explicit non-sanction preservation of an authenticated adopted full-policy VIEW.
/// @dev Distinct from live VIEW bytes. Historical selection does not freeze live Artist facts.
interface IStreamViewPreservationRendererV1 {
    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address router;
        bytes32 routerCodeHash;
        address preservationAttribution;
        bytes32 preservationAttributionCodeHash;
        uint256 chainId;
        uint32 rendererGas;
        uint32 attributionGas;
    }

    struct Binding {
        address core;
        address router;
        address liveRenderer;
        bytes32 liveRendererRuntimeHash;
        address preservationAttribution;
        bytes32 preservationAttributionRuntimeHash;
    }
    function preservationProfile() external pure returns (bytes32);
    function configuration() external view returns (Configuration memory);
    function configurationHash() external view returns (bytes32);
    function workerBinding() external view returns (address worker, bytes32 runtimeHash);
    function encodingBinding() external view returns (address encoder, bytes32 runtimeHash);
    /// @notice Authenticated retained producer identity; this getter alone asserts no current eligibility.
    function preservationViewBinding(bytes32 adoptionRecord) external view returns (Binding memory);
    function preservationViewJSON(StreamFinalityScope calldata scope, uint256 tokenId)
        external
        view
        returns (bytes32 adoptionRecord, string memory output);
    function preservationViewHTML(StreamFinalityScope calldata scope, uint256 tokenId)
        external
        view
        returns (bytes32 adoptionRecord, string memory output);
    function historicalPreservationViewJSON(bytes32 adoptionRecord, uint256 tokenId)
        external
        view
        returns (StreamFinalityScope memory scope, string memory output);
    function historicalPreservationViewHTML(bytes32 adoptionRecord, uint256 tokenId)
        external
        view
        returns (StreamFinalityScope memory scope, string memory output);
}
