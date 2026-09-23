// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Additive identity for a synchronous adapter; does not promise asynchronous requests.
interface IStreamInstantEntropyProviderIdentity is IERC165 {
    enum InstantMode {
        COMMIT_REVEAL,
        DELAYED_BLOCKHASH,
        DETERMINISTIC_TEST_ONLY
    }

    function isStreamInstantEntropyProvider() external view returns (bool);
    function streamEntropyProviderFamily() external pure returns (bytes32);
    function streamEntropyProviderVersion() external pure returns (bytes32);
    function streamEntropyProviderConfigHash() external view returns (bytes32);
    function instantEntropyProfile()
        external
        view
        returns (InstantMode mode, bytes32 assumptionsHash);
}
