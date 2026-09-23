// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintGate.sol";
import "./IStreamMintManager.sol";

/// @notice Additive gate capability for evidence that authenticates the complete mint payload.
/// @dev Original IStreamMintGate selectors remain unchanged. Managers probe this capability
///      and dispatch the actual batch, including tokenData and mintCommitments, under their
///      existing bounded gate-call policy. A result confers no durable replay consumption.
interface IStreamMintBatchGate is IERC165 {
    function validateMintBatch(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external view returns (IStreamMintGate.GateResult memory);
}
