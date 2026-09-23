// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "../../script/current/StreamCanonicalNativeSalesActivationPlan.sol";
import {
    IStreamNativeDutchSales as Dutch
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Original read-only canonical sale planners for the two paid test hosts.
/// @dev Public library calls preserve the host as outward caller. Original planner
/// bodies, checks, argument types and call order remain authoritative. This helper
/// performs no setup mutation or construction. Fresh native and trace proof is required.
library StreamCurrentTestCanonicalSalesActivation {
    function registrationBatch(A.Context memory x)
        public view returns (GenesisBatch memory)
    {
        return A.registrationBatch(x);
    }

    function recorderCredit(A.Context memory x)
        public view returns (GenesisBatch memory)
    {
        return A.recorderCredit(x);
    }

    function requireSettlementReady(A.Context memory x)
        public view
    {
        A.requireSettlementReady(x);
    }

    function configurePhase(A.Context memory x, A.Phase memory p)
        public view returns (A.OwnerCall memory)
    {
        return A.configurePhase(x, p);
    }

    function phaseExecutor(A.Context memory x, uint8 index, uint256 collection, bytes32 phase)
        public view returns (A.OwnerCall memory)
    {
        return A.phaseExecutor(x, index, collection, phase);
    }

    function registerDutch(A.Context memory x, Dutch.Configuration memory config)
        public view returns (A.OwnerCall memory)
    {
        return A.registerDutch(x, config);
    }

    function validateOwnerCall(A.Context memory x, A.OwnerCall memory saved)
        public view
    {
        A.validateOwnerCall(x, saved);
    }

    function governed(A.Context memory x, A.OwnerCall memory saved)
        public view returns (GenesisBatch memory)
    {
        return A.governed(x, saved);
    }
}
