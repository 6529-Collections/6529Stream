// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintSetupPlan.sol";

interface CurrentMintSetupVm {
    function envBytes(string calldata key) external view returns (bytes memory);
}

/// @notice Return the next exact EOA/Safe CALL from a saved post-onboarding phase plan.
/// @dev Read only, including in Forge. Submit through the actual actor's existing wallet.
contract PrepareCurrentMintSetup {
    CurrentMintSetupVm private constant vm =
        CurrentMintSetupVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external view returns (StreamMintSetupPlan.NextCall memory) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        return
            prepare(abi.decode(vm.envBytes("STREAM_MINT_SETUP_PLAN"), (StreamMintSetupPlan.Plan)));
    }

    function prepare(StreamMintSetupPlan.Plan memory plan)
        public
        view
        returns (StreamMintSetupPlan.NextCall memory)
    {
        return StreamMintSetupPlan.next(plan);
    }
}
