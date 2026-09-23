// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamFinalityProfileSources as Original } from "./IStreamFinalityProfileSources.sol";
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Two immutable static profiles plus separately bound genuine publication factories.
/// @dev Indexes0/1 preserve original COLLECTION/scoped V1 tuples. There is no static index2.
/// Per-scope sources are identities, not evidence admission. The explicit discriminator makes
/// this capability distinct from the original three-static-profile interface.
interface IStreamFinalityFactoryProfileSourcesV2 {
    function factorySourceProfile() external pure returns (bytes32);
    function finalitySourceProfile(uint8 index) external view returns (Original.Profile memory);
    function finalitySourceConfigurationHash() external view returns (bytes32);
    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        returns (Original.Sources memory);
}
