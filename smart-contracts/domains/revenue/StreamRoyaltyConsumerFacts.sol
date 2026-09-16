// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRoyaltyConsumerContinuity as I } from "../../interfaces/stream/revenue/IStreamRoyaltyConsumerContinuity.sol";
import { StreamRoyaltyContinuityState as S } from "./StreamRoyaltyContinuityState.sol";
import { StreamRoyaltyContinuityTypes as C } from "../../interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";

/// @notice Fixed encoding over the original import and origin ledgers; owns no independent balances.
library StreamRoyaltyConsumerFacts {
    function receiptEncoded(address core, address factory) public view returns (bytes memory) {
        S.State storage s = S.state();
        C.ImportState storage t = s.transfer;
        return abi.encode(I.Receipt(
            t.status, core, factory,
            t.status == 0 ? address(this) : s.consumerOrigin,
            t.status == 0 ? address(this).codehash : s.consumerOriginRuntimeHash,
            t.source, t.sourceRuntimeHash, t.manifestHash, t.beginActionId,
            t.status == 0 ? bytes32(0) : keccak256(abi.encode(t.expected))
        ));
    }

    function origins(uint8 scope, uint256 scopeId, uint256 collectionId, bool frozen)
        public view returns (address, address)
    {
        return (S.origin(scope, scopeId, frozen), S.electionOrigin(collectionId));
    }
}
