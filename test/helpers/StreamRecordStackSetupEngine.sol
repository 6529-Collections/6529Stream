// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackFixture.sol";

interface StreamRecordStackSetupVm {
    function getDeployedCode(string calldata artifact) external returns (bytes memory);
    function etch(address target, bytes calldata code) external;
}

interface IStreamRecordStackSetupCallbacks {
    function stackArtistProof(bytes32 digest) external returns (bytes memory);
    function stackAdditionalOperatingPolicies()
        external
        view
        returns (GovernanceActionPolicyEntry[] memory);
}

/// @notice Executes the unchanged current Stack setup in the original test host context.
/// @dev No state or constructor. The host verifies this genuine artifact runtime before delegatecall.
contract StreamRecordStackSetupEngine is StreamCurrentStackFixture {
    function run(address artist_, address platform) external {
        _deployCurrentStack(artist_, platform);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return IStreamRecordStackSetupCallbacks(address(this)).stackArtistProof(digest);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return IStreamRecordStackSetupCallbacks(address(this)).stackAdditionalOperatingPolicies();
    }
}
