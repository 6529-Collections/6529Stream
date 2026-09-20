// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentRecoveryActions.sol";

/// @notice Authored bounded recovery sequences. Native execution remains separately required.
contract StreamCurrentRecoveryActionsTest is CurrentRecoveryActions {
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

    function setUp() public {
        _constructRecoveryActions();
    }

    function targetContracts() external view returns (address[] memory a) {
        a = new address[](1);
        a[0] = address(recoveryHandler);
    }

    function targetSelectors() external view returns (FuzzSelector[] memory a) {
        a = new FuzzSelector[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = CurrentRecoveryActionHandler.step.selector;
        a[0] = FuzzSelector(address(recoveryHandler), selectors);
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

    function invariant_originalRecoveryMatchesIndependentActions() public view {
        assertRecoveryState();
    }

    function afterInvariant() public view {
        assertRecoveryState();
        assertRecoveryActivity();
    }

    function testRequiredRecoveryOpeningSettlementBeforeAbort() public {
        for (uint256 i; i < RECOVERY_OPENING; ++i) {
            recoveryHandler.step(0);
        }
        assertRecoveryActivity();
    }

    function testRequiredRecoveryOpeningSettlementAfterAbort() public {
        for (uint256 i; i < RECOVERY_OPENING; ++i) {
            recoveryHandler.step(1);
        }
        assertRecoveryActivity();
    }

    function testFixedSeedReplaysRecoveryAndEconomicDecisions() public {
        uint256 saved = vm.snapshotState();
        _run(0x6529AB04, 32);
        bytes32 first = recoveryDigest;
        uint256 nonce = continuitySafe.nonce();
        require(vm.revertToState(saved), "restore exact recovery starting state");
        _run(0x6529AB04, 32);
        require(
            recoveryDigest == first && continuitySafe.nonce() == nonce,
            "same seed reproduces recovery decisions"
        );
    }

    function testOracleRejectsReusedAbortedAllocation() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "independent consumed allocation and serial model"
            )
        );
        this.probeWrongAllocation();
        assertRecoveryState();
    }

    function testOracleRejectsForgedRefundCompletion() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "independent auction conservation and pull credit"
            )
        );
        this.probeWrongRefund();
        assertRecoveryState();
    }

    function testOracleRejectsPrematureSuccessorAuthority() public {
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "independent completed burned or gap identity")
        );
        this.probeWrongRecovery();
        assertRecoveryState();
    }

    function testRecoveryDriverRejectsUnselectedCaller() public {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "selected recovery handler only"));
        this.executeRecoveryAction(0);
        assertRecoveryState();
    }

    function testFuzzBoundedRecoveryActionSequence(uint256 seed, uint8 extraSteps) public {
        _run(seed, RECOVERY_OPENING + uint256(extraSteps) % 17);
    }

    function probeWrongAllocation() external {
        require(msg.sender == address(this), "oracle probe only");
        expected.allocation = 3;
        assertRecoveryState();
    }

    function probeWrongRefund() external {
        require(msg.sender == address(this), "oracle probe only");
        expected.refunded = true;
        assertRecoveryState();
    }

    function probeWrongRecovery() external {
        require(msg.sender == address(this), "oracle probe only");
        expected.recovered = true;
        assertRecoveryState();
    }

    function _run(uint256 seed, uint256 count) private {
        for (uint256 i; i < count; ++i) {
            seed = uint256(keccak256(abi.encode("CURRENT_RECOVERY_ACTION_SEED_V1", seed, i)));
            recoveryHandler.step(seed);
        }
        assertRecoveryActivity();
    }
}
