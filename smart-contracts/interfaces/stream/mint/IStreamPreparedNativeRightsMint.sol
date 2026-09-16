// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";
import "../revenue/IStreamPreparedNativeRightsSaleBinding.sol";

interface IStreamPreparedNativeRightsMint {
    function executePreparedNativeRightsMint(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        );

    function activePreparedNativeRights()
        external
        view
        returns (StreamPreparedNativeRightsTypes.Facts memory);
}
