// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable typed ingress-to-coordinator deployment binding.
interface IStreamArtistIngressBinding {
    function operationCoordinator() external view returns (address);
}
