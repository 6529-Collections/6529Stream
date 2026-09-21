// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationCallerPreparationFixture
} from "./StreamCurrentAuthorityPreservationCallerPreparationFixture.sol";

/// @notice A separately created setup account for a recorded local caller bootstrap.
/// @dev Test infrastructure only. Its real constructor and prepare call must occur after the
/// outer recorder starts. It uses Foundry cheatcodes during setup and is not an RPC deployment
/// recipe. The complete successful state needs separate export/import and native qualification.
contract StreamCurrentAuthorityPreservationCallerScenario is
    StreamCurrentAuthorityPreservationCallerPreparationFixture
{
    bool private preparationStarted;
    bool public preparationComplete;
    PreservationCallerPreparation private prepared;

    function prepare() external {
        require(!preparationStarted, "one genuine setup");
        preparationStarted = true;
        prepared = _preparePreservationCallers();
        preparationComplete = true;
    }

    function preparation() external view returns (PreservationCallerPreparation memory) {
        require(preparationComplete, "successful setup required");
        return prepared;
    }

    function writerState()
        external
        view
        returns (address writer, address[] memory owners, uint256 threshold, uint256 nonce)
    {
        require(preparationComplete, "successful setup required");
        writer = address(assemblyArtist);
        owners = assemblyArtist.getOwners();
        threshold = assemblyArtist.getThreshold();
        nonce = assemblyArtist.nonce();
    }
}
