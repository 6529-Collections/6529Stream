// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamGovernanceExecutor
} from "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import {
    IStreamRoleRegistry
} from "../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamArtistActivationPlan } from "../../script/current/StreamArtistActivationPlan.sol";
import { StreamRevealActivationPlan } from "../../script/current/StreamRevealActivationPlan.sol";

/// @notice Fixed test-library boundaries for the current fixture's authority planners.
/// @dev No fixture storage, scheduling, cheatcode, constructor or assertion moves here.
/// The public library calls preserve the host context; gas equivalence is not asserted.
library StreamCurrentTestAuthorityPlans {
    function buildArtist(
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address administrator
    ) public view returns (StreamArtistActivationPlan.Plan memory) {
        return StreamArtistActivationPlan.build(roles, manager, administrator);
    }

    function buildReadBudgetExpansion(IStreamGasParameterHost manager)
        public
        view
        returns (StreamArtistActivationPlan.Plan memory)
    {
        return StreamArtistActivationPlan.buildReadBudgetExpansion(manager);
    }

    function executeArtist(
        IStreamGovernanceExecutor executor,
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address administrator,
        bytes32 actionId,
        StreamArtistActivationPlan.Plan memory plan
    ) public {
        StreamArtistActivationPlan.execute(executor, roles, manager, administrator, actionId, plan);
    }

    function buildReveal(
        IStreamRoleRegistry roles,
        StreamRevealActivationPlan.Principals memory principals
    ) public view returns (StreamArtistActivationPlan.Plan memory) {
        return StreamRevealActivationPlan.build(roles, principals);
    }

    function executeReveal(
        IStreamGovernanceExecutor executor,
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address artistAdministrator,
        StreamRevealActivationPlan.Principals memory principals,
        bytes32 actionId,
        StreamArtistActivationPlan.Plan memory plan
    ) public {
        StreamRevealActivationPlan.execute(
            executor, roles, manager, artistAdministrator, principals, actionId, plan
        );
    }
}
