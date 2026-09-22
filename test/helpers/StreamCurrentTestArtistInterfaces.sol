// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact factory call surface used by the unchanged Artist test fixture.
/// @dev These calls still target the real factory and its fixed deployment libraries.
interface IStreamTestArtistExtensionFactory {
    function deployIdentity(uint8 kind, address[6] calldata pins) external returns (address child);

    function deployRegistry(uint8 kind, address host, address coordinator)
        external
        returns (address child);
}

/// @dev Nominal address only: no calls use this type. Genuine artifact creation,
/// constructor arguments and runtime checks remain in the original fixture.
interface IStreamTestArtistArtifactAddress { }
