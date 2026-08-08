// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice The minimal Foundry cheatcode surface used by the generic broadcaster.
interface CanonicalDeploymentVm {
    function envAddress(string calldata key) external view returns (address value);
    function envBytes32(string calldata key) external view returns (bytes32 value);
    function envString(string calldata key) external view returns (string memory value);
    function envUint(string calldata key) external view returns (uint256 value);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory value);
    function parseJsonBytes32(string calldata json, string calldata key)
        external
        pure
        returns (bytes32 value);
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256 value);
    function readFile(string calldata path) external view returns (string memory data);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Deploys only the raw initcode supplied by a validated canonical plan entry.
/// @dev This script intentionally imports no production contract. Its compilation universe
///      therefore cannot select or alter the bytecode that is broadcast.
contract DeployCanonicalInitcode {
    CanonicalDeploymentVm private constant vm =
        CanonicalDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error ChainIdMismatch(uint256 expected, uint256 actual);
    error InvalidDeployer();
    error InvalidDeploymentCount();
    error PlanHashMismatch(bytes32 expected, bytes32 actual);
    error DeploymentOrderMismatch(uint256 expected, uint256 actual);
    error InitcodeLengthMismatch(uint256 expected, uint256 actual);
    error InitcodeHashMismatch(bytes32 expected, bytes32 actual);
    error DeploymentFailed();
    error RuntimeLengthMismatch(uint256 expected, uint256 actual);
    error RuntimeHashMismatch(bytes32 expected, bytes32 actual);

    function run() external returns (address deployed) {
        string memory plan = vm.readFile(vm.envString("CANONICAL_DEPLOYMENT_PLAN_PATH"));
        bytes32 expectedPlanHash = vm.envBytes32("CANONICAL_DEPLOYMENT_PLAN_SHA256");
        bytes32 actualPlanHash = sha256(bytes(plan));
        if (actualPlanHash != expectedPlanHash) {
            revert PlanHashMismatch(expectedPlanHash, actualPlanHash);
        }

        uint256 startIndex = vm.envUint("CANONICAL_DEPLOYMENT_INDEX");
        uint256 count = vm.envUint("CANONICAL_DEPLOYMENT_COUNT");
        uint256 expectedChainId = vm.parseJsonUint(plan, ".network.chain_id");
        address deployer = vm.envAddress("CANONICAL_DEPLOYMENT_SENDER");
        if (block.chainid != expectedChainId) {
            revert ChainIdMismatch(expectedChainId, block.chainid);
        }
        if (deployer == address(0)) {
            revert InvalidDeployer();
        }
        if (count == 0) {
            revert InvalidDeploymentCount();
        }

        uint256 endIndex = startIndex + count;
        for (uint256 index = startIndex; index < endIndex; ++index) {
            deployed = _deploy(plan, index, deployer);
        }
    }

    function _deploy(string memory plan, uint256 index, address deployer)
        private
        returns (address deployed)
    {
        string memory deploymentPath = string.concat(".deployments[", _decimal(index), "]");
        uint256 actualOrder = vm.parseJsonUint(plan, string.concat(deploymentPath, ".order"));
        if (actualOrder != index + 1) {
            revert DeploymentOrderMismatch(index + 1, actualOrder);
        }
        bytes memory initcode = vm.parseJsonBytes(plan, string.concat(deploymentPath, ".initcode"));
        uint256 expectedInitcodeLength =
            vm.parseJsonUint(plan, string.concat(deploymentPath, ".initcode_length_bytes"));
        if (initcode.length != expectedInitcodeLength) {
            revert InitcodeLengthMismatch(expectedInitcodeLength, initcode.length);
        }
        bytes32 expectedInitcodeHash =
            vm.parseJsonBytes32(plan, string.concat(deploymentPath, ".initcode_keccak256"));
        bytes32 actualInitcodeHash = keccak256(initcode);
        if (actualInitcodeHash != expectedInitcodeHash) {
            revert InitcodeHashMismatch(expectedInitcodeHash, actualInitcodeHash);
        }
        uint256 expectedRuntimeLength =
            vm.parseJsonUint(plan, string.concat(deploymentPath, ".expected_runtime_length_bytes"));
        bytes32 expectedRuntimeHash =
            vm.parseJsonBytes32(plan, string.concat(deploymentPath, ".expected_runtime_keccak256"));

        vm.startBroadcast(deployer);
        assembly ("memory-safe") {
            deployed := create(0, add(initcode, 0x20), mload(initcode))
        }
        vm.stopBroadcast();

        if (deployed == address(0)) {
            revert DeploymentFailed();
        }
        if (deployed.code.length != expectedRuntimeLength) {
            revert RuntimeLengthMismatch(expectedRuntimeLength, deployed.code.length);
        }
        bytes32 actualRuntimeHash;
        assembly ("memory-safe") {
            actualRuntimeHash := extcodehash(deployed)
        }
        if (actualRuntimeHash != expectedRuntimeHash) {
            revert RuntimeHashMismatch(expectedRuntimeHash, actualRuntimeHash);
        }
    }

    function _decimal(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 digits;
        uint256 cursor = value;
        while (cursor != 0) {
            ++digits;
            cursor /= 10;
        }
        bytes memory output = new bytes(digits);
        while (value != 0) {
            --digits;
            output[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(output);
    }
}
