// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "../artist/StreamArtistOnboardingTypes.sol";

/// @notice Closed, constructor-authenticated catalogue of supported Artist suites.
interface IStreamStaticArtistLineageSource {
    function core() external view returns (address);
    function router() external view returns (address);
    function originalArtist() external view returns (address);
    function originalArtistCodeHash() external view returns (bytes32);
    function sourceChainId() external view returns (uint256);
    function catalogueHash() external view returns (bytes32);
    function catalogueCount() external view returns (uint256);
    function catalogueSuite(uint256 index) external view returns (T.SuiteConfiguration memory);
    function currentSuite() external view returns (T.SuiteConfiguration memory);
}
