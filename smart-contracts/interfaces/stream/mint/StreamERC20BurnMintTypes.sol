// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamUniversalFixedPriceSaleAdapter as U
} from "./IStreamUniversalFixedPriceSaleAdapter.sol";
import { StreamPrimarySettlementTypes as S } from "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Original universal sale payload plus the exact, ordered same-transaction burn inputs.
library StreamERC20BurnMintTypes {
    struct Execution {
        U.SaleExecutionData sale;
        uint256[] sourceTokenIds;
    }

    struct Result {
        S.PrimarySettlementResult settlement;
        uint256 tokenId;
        bytes32 operationRoot;
        bytes32 operationId;
    }
}
