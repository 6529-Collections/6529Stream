// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";

/// @dev Exact target-side context fixture; actual Executor timelock routes are integration tests.
abstract contract RevenueV1TestBase is CharacterizationTestBase {
    MockGovernedParameterAuthority internal revenueAuthority;
    uint256 private _policyActionCounter;

    function _revenueAuthority() internal returns (MockGovernedParameterAuthority) {
        if (address(revenueAuthority) == address(0)) {
            revenueAuthority = new MockGovernedParameterAuthority(true);
        }
        return revenueAuthority;
    }

    function _walletGasConfigs()
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[2] memory configs)
    {
        configs[0] = IStreamGasParameterHost.GasParameterConfig(
            "ERC_1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        configs[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30_000, 15_000, 2);
    }

    function _prepareAssetPolicy(
        StreamAssetPolicyRegistry registry,
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 grace
    ) internal {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            registry.assetPolicyTransitionHashes(asset, status, policyHash, grace);
        revenueAuthority.setCurrentAction(
            true, bytes32(++_policyActionCounter), 1, scope, oldState, newState
        );
    }

    function _setAssetPolicy(
        StreamAssetPolicyRegistry registry,
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 grace
    ) internal {
        _prepareAssetPolicy(registry, asset, status, policyHash, grace);
        vm.prank(address(revenueAuthority));
        registry.setAssetStatus(asset, status, policyHash, grace);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}
