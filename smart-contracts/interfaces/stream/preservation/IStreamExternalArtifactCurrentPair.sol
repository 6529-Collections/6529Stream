// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

/// @notice Additive current liveness of exact original external archive receipt identities.
/// @dev Callers retain original coverage separately. This does not create a recorded coverage,
///      replace a receipt, or impose an elapsed-time fixity cadence beyond the host's latest head.
interface IStreamExternalArtifactCurrentPair {
    function currentReceiptPair(
        bytes32 firstReceipt,
        bytes32 secondReceipt,
        bytes32 artistId,
        bytes32 objectHash
    ) external view returns (E.CurrentPair memory);
}
