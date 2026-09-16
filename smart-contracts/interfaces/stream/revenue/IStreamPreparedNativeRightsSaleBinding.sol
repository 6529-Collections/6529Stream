// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeRightsTypes.sol";
import "./StreamPrimarySettlementTypes.sol";

interface IStreamPreparedNativeRightsSaleBinding {
    function activePreparedNativeRightsIntent(bytes32 intentHash)
        external
        view
        returns (StreamPreparedNativeRightsTypes.Intent memory);

    function onPreparedNativeRightsMint(StreamPreparedNativeRightsTypes.Facts calldata facts)
        external
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
