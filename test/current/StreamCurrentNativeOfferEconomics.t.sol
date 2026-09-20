// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentNativeOfferEconomics.sol";

/// @notice Authored actual native paid-offer state model; matched-source native acceptance pending.
contract StreamCurrentNativeOfferEconomicsTest is CurrentNativeOfferEconomics {
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
        _constructNativeOfferEconomics();
    }

    function targetContracts() external view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(economicHandler);
    }

    function targetSelectors() external view returns (FuzzSelector[] memory targets) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = NativeOfferEconomicHandler.step.selector;
        targets = new FuzzSelector[](1);
        targets[0] = FuzzSelector(address(economicHandler), selectors);
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

    function invariant_nativeOfferMatchesIndependentEconomics() public view {
        assertEconomicState();
    }

    function afterInvariant() public view {
        assertEconomicState();
        assertEconomicActivity();
    }

    function testFullNativeOfferClosesRefundAndAllSplits() public {
        for (uint256 i; i < ECONOMIC_OPENING; ++i) {
            economicHandler.step(0);
        }
        assertEconomicActivity();
    }

    function testFullNativeOfferReversesRemainingReleaseOrderAndLargerExcess() public {
        for (uint256 i; i < ECONOMIC_OPENING; ++i) {
            economicHandler.step(999);
        }
        assertEconomicActivity();
    }

    function testFixedSeedReplaysEconomicPartitionsAndSafeNonces() public {
        uint256 snap = vm.snapshotState();
        _run(0x6529EC09, 30);
        bytes32 digest = economicDigest;
        require(vm.revertToState(snap), "restore actual economic starting state");
        _run(0x6529EC09, 30);
        require(
            economicDigest == digest,
            "same economic seed reproduces partition and authority decisions"
        );
    }

    function testOracleRejectsInventedRefundPayment() public {
        for (uint256 i; i < 4; ++i) {
            economicHandler.step(17);
        }
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "independent buyer-only refundable liability")
        );
        this.probeRefundOracle();
        assertEconomicState();
    }

    function testOracleRejectsPrematureSplitRelease() public {
        for (uint256 i; i < 6; ++i) {
            economicHandler.step(17);
        }
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "independent split conservation"));
        this.probeSplitOracle();
        assertEconomicState();
    }

    function testOracleRejectsSellerSignatureAsTransaction() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "independent Safe transaction and signature nonces"
            )
        );
        this.probeSafeOracle();
        assertEconomicState();
    }

    function testEconomicDriverRejectsUnselectedCaller() public {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "selected economic handler only"));
        this.economicAction(0);
        assertEconomicState();
    }

    function testFuzzBoundedNativeOfferEconomicSequence(uint256 seed, uint8 extraSteps) public {
        _run(seed, ECONOMIC_OPENING + uint256(extraSteps) % 17);
    }

    function probeRefundOracle() external {
        require(msg.sender == address(this), "economic oracle probe only");
        model.refunded = true;
        assertEconomicState();
    }

    function probeSplitOracle() external {
        require(msg.sender == address(this), "economic oracle probe only");
        model.artistReleased = true;
        assertEconomicState();
    }

    function probeSafeOracle() external {
        require(msg.sender == address(this), "economic oracle probe only");
        ++model.nonces[2];
        assertEconomicState();
    }

    function _run(uint256 seed, uint256 count) private {
        for (uint256 i; i < count; ++i) {
            seed = uint256(keccak256(abi.encode("CURRENT_NATIVE_OFFER_ECONOMIC_SEED_V1", seed, i)));
            economicHandler.step(seed);
        }
        assertEconomicActivity();
    }
}
