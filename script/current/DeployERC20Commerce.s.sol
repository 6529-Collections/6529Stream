// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamERC20CommerceActivationPlan.sol";

interface ERC20CommerceDeploymentVm {
    function envAddress(string calldata key) external view returns (address);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Explicit additive Anvil/Sepolia construction; no broadcasts occur merely by planning.
/// @dev Supply Foundry's signer independently. Never read or retain signer material in this script.
contract DeployERC20Commerce {
    ERC20CommerceDeploymentVm private constant vm =
        ERC20CommerceDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run(
        StreamERC20CommerceDeployment.Configuration calldata config,
        bytes32 deploymentManifest,
        bytes32 moduleManifest
    ) external returns (StreamERC20CommerceDeployment.Products memory products) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        address operator = vm.envAddress("STREAM_DEPLOYER");
        require(operator != address(0), "deployer required");
        vm.startBroadcast(operator);
        products = StreamERC20CommerceDeployment.deploy(config, deploymentManifest, moduleManifest);
        vm.stopBroadcast();
    }

    function prepareAdmission(StreamERC20CommerceDeployment.Products calldata p)
        external
        view
        returns (GenesisBatch memory, GovernanceActionPolicyEntry[] memory)
    {
        StreamERC20CommerceActivationPlan.requireRuntimeActivated(p);
        return (
            StreamERC20CommerceActivationPlan.admission(p),
            StreamERC20CommerceActivationPlan.policies(p)
        );
    }

    function prepareCatalogAdditions(
        StreamERC20CommerceDeployment.Products calldata p,
        GovernanceActionPolicyEntry[] calldata known
    ) external view returns (GovernanceActionPolicyEntry[] memory) {
        return StreamERC20CommerceActivationPlan.catalogAdditions(p, known);
    }

    function previewPhasePolicy(
        StreamERC20CommerceDeployment.Products calldata p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) external view returns (bytes32, bytes32) {
        return StreamERC20CommerceActivationPlan.phasePolicy(p, product, collectionId, phaseId);
    }

    function preparePhase(
        StreamERC20CommerceDeployment.Products calldata p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) external view returns (StreamERC20CommerceActivationPlan.PhaseAdmission memory) {
        StreamERC20CommerceActivationPlan.requireRuntimeActivated(p);
        return StreamERC20CommerceActivationPlan.phaseCall(p, product, collectionId, phaseId);
    }

    function prepareGovernedPhase(
        StreamERC20CommerceDeployment.Products calldata p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) external view returns (GenesisBatch memory) {
        StreamERC20CommerceActivationPlan.requireRuntimeActivated(p);
        return StreamERC20CommerceActivationPlan.governedPhase(p, product, collectionId, phaseId);
    }
}
