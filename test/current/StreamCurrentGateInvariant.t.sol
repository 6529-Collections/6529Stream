// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentGateCampaignDriver.sol";

/// @notice Bounded original-product campaign with explicit nonvacuity and deterministic replay.
/// @dev Authored invariants; execution/source/size receipts are required before claiming a pass.
contract StreamCurrentGateInvariantTest is CurrentGateCampaignDriver {
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }
    uint256 private constant REGRESSION_SEED = 0x65294703;

    function setUp() public {
        _constructGateCampaign();
    }

    function targetContracts() external view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(campaignHandler);
    }

    function targetSelectors() external view returns (FuzzSelector[] memory targets) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = CurrentGateCampaignHandler.step.selector;
        targets = new FuzzSelector[](1);
        targets[0] = FuzzSelector(address(campaignHandler), selectors);
    }

    function excludeContracts() external pure returns (address[] memory) {
        return new address[](0);
    }

    function targetSenders() external pure returns (address[] memory) {
        return new address[](0);
    }

    function excludeSenders() external pure returns (address[] memory) {
        return new address[](0);
    }

    function targetArtifacts() external pure returns (string[] memory) {
        return new string[](0);
    }

    function excludeArtifacts() external pure returns (string[] memory) {
        return new string[](0);
    }

    function targetArtifactSelectors() external pure returns (FuzzArtifactSelector[] memory) {
        return new FuzzArtifactSelector[](0);
    }

    function targetInterfaces() external pure returns (FuzzInterface[] memory) {
        return new FuzzInterface[](0);
    }

    function excludeSelectors() external pure returns (FuzzSelector[] memory) {
        return new FuzzSelector[](0);
    }

    function invariant_originalGateAccountingMatchesIndependentHistory() public view {
        campaignHandler.assertInvariants();
    }

    function afterInvariant() public view {
        campaignHandler.assertCampaignActivity();
        campaignHandler.assertInvariants();
    }

    function testRequiredOpeningCoversAllGatesReplayCapAndBothCallbackRetries() public {
        _run(REGRESSION_SEED, 14);
        campaignHandler.assertCampaignActivity();
        require(
            campaignHandler.callbackRetries(0) == 1 && campaignHandler.callbackRetries(1) == 1
                && campaignHandler.revocationRetries() == 1 && campaignHandler.capDenials() == 1,
            "each required retry and cap boundary actually exercised"
        );
    }

    function testFixedSeedReplaysSameBoundedCampaign() public {
        uint256 saved = vm.snapshotState();
        _run(REGRESSION_SEED, 38);
        bytes32 digest = campaignHandler.campaignDigest();
        uint256 attempts = campaignHandler.attempts();
        uint256 minted = core.totalSupply();
        uint256 successes = campaignHandler.successes();
        require(vm.revertToState(saved), "restore exact campaign starting state");
        _run(REGRESSION_SEED, 38);
        require(
            campaignHandler.campaignDigest() == digest && campaignHandler.attempts() == attempts
                && core.totalSupply() == minted && campaignHandler.successes() == successes,
            "same seed and source reproduce operation decisions"
        );
        campaignHandler.assertCampaignActivity();
    }

    function testBeneficiaryOracleRejectsBalancedWrongBucketThenRestores() public {
        campaignHandler.step(REGRESSION_SEED);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "independent beneficiary allowance")
        );
        campaignHandler.probeWrongBeneficiaryOracle();
        campaignHandler.assertInvariants();
    }

    function testReplayOracleRejectsMissingCommittedAuthorizationThenRestores() public {
        campaignHandler.step(REGRESSION_SEED);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "independent authorization history")
        );
        campaignHandler.probeMissingAuthorizationOracle();
        campaignHandler.assertInvariants();
    }

    function testOwnershipOracleRejectsWrongOwnerWithoutChangingSupply() public {
        campaignHandler.step(REGRESSION_SEED);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "independent token ownership content and serial"
            )
        );
        campaignHandler.probeWrongOwnerOracle();
        campaignHandler.assertInvariants();
    }

    function testDriverRejectsUnselectedCallersBeforeSigningOrMutation() public {
        GateCampaign.Request memory request =
            GateCampaign.Request(0, 0, 1, false, 1, bytes32(uint256(1)));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "fixed campaign driver caller"));
        this.campaignBuild(request);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "fixed campaign driver caller"));
        this.campaignGrant(0, true);
        campaignHandler.assertInvariants();
    }

    function testFuzzBoundedOriginalGateSequence(uint256 seed, uint8 extraSteps) public {
        _run(seed, 14 + uint256(extraSteps) % 33);
        campaignHandler.assertCampaignActivity();
    }

    function _run(uint256 seed, uint256 count) private {
        for (uint256 i; i < count; ++i) {
            seed = uint256(keccak256(abi.encode("CURRENT_GATE_CAMPAIGN_SEED_V1", seed, i)));
            campaignHandler.step(seed);
        }
    }
}
