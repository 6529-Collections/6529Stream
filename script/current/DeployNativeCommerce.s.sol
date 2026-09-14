// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCommerceDeployment.sol";
import "./StreamNativeCommerceGovernancePlan.sol";

interface NativeCommerceDeploymentVm {
    function envAddress(string calldata key) external view returns (address);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Add native commerce to an existing current Anvil or Sepolia deployment.
/// @dev No signer material is read. Supply Foundry's signer/unlocked account separately.
///      Preserve returned product coordinates and the original transaction journal for resumption.
contract DeployNativeCommerce {
    NativeCommerceDeploymentVm private constant vm =
        NativeCommerceDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run(
        IStreamRevenueResolver resolver,
        StreamModuleRegistry registry,
        IStreamRevenueEscrow escrow,
        StreamNativeEnglishAuction.DeploymentConfig calldata configuration,
        bytes32 deploymentManifestHash,
        bytes32 moduleManifestHash
    ) external returns (StreamNativeCommerceDeployment.Products memory products) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        address operator = vm.envAddress("STREAM_DEPLOYER");
        require(operator != address(0), "deployer required");
        vm.startBroadcast(operator);
        products = StreamNativeCommerceDeployment.deploy(
            resolver, registry, escrow, configuration, deploymentManifestHash, moduleManifestHash
        );
        vm.stopBroadcast();
    }

    function prepareAdmission(StreamNativeCommerceDeployment.Products calldata products)
        external
        view
        returns (GenesisBatch memory batch, GovernanceActionPolicyEntry[] memory intents)
    {
        return (
            StreamNativeCommerceDeployment.admission(products),
            StreamNativeCommerceDeployment.policies(products)
        );
    }

    /// @notice Build after observed module admission; schedule through the original Executor.
    function prepareCustodyBinding(StreamNativeCommerceDeployment.Products calldata products)
        external
        view
        returns (GenesisBatch memory)
    {
        return StreamNativeCommerceGovernancePlan.custodyBinding(products);
    }

    function prepareGovernedManagerBinding(
        StreamNativeCommerceDeployment.Products calldata products
    ) external view returns (GenesisBatch memory) {
        return StreamNativeCommerceGovernancePlan.managerBinding(products);
    }

    function prepareCatalogAdditions(
        StreamNativeCommerceDeployment.Products calldata products,
        GovernanceActionPolicyEntry[] calldata knownEntries
    ) external view returns (GovernanceActionPolicyEntry[] memory) {
        return StreamNativeCommerceGovernancePlan.catalogAdditions(products, knownEntries);
    }

    function prepareManagerBinding(StreamNativeCommerceDeployment.Products calldata products)
        external
        view
        returns (address target, bytes memory data)
    {
        return StreamNativeCommerceDeployment.managerBinding(products);
    }
}
