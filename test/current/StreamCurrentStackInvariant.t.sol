// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../helpers/StreamCurrentStackHandler.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

/// @notice Stateful sequence fuzzing against actual sealed current-stack contracts.
/// @dev Only the bounded handler is targeted. No arbitrary-call revert campaign or mocked Core.
contract StreamCurrentStackInvariantTest is StreamCurrentStackFixture {
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
    bytes32 private constant ERC20_PHASE = keccak256("stateful ERC20 phase");
    bytes32 private constant REVENUE = PRIMARY_REVENUE_CLASS;
    StreamERC20FixedPriceSaleAdapter private erc20Sale;
    MockStreamPaymentToken private paymentToken;
    bytes32 private erc20SaleId;
    StreamCurrentStackHandler private handler;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        require(executor.genesisInitialized(), "genesis not initialized");
        handler = new StreamCurrentStackHandler(
            StreamCurrentStackHandler.Config(
                core,
                manager,
                sale,
                erc20Sale,
                auction,
                paymentToken,
                wallet,
                artist,
                PROTOCOL,
                profile,
                erc20SaleId,
                _fixtureSupplyLimit()
            )
        );
    }

    function _fixtureSupplyLimit() internal pure override returns (uint64) {
        return 256;
    }

    function _deployAdditionalProducts() internal override {
        paymentToken = new MockStreamPaymentToken();
        erc20Sale = new StreamERC20FixedPriceSaleAdapter(
            manager,
            primaryResolver,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists))
        );
        _assertDeployableProductionInstance(address(erc20Sale));
    }

    function _configureAdditionalProducts() internal override {
        GovernanceActionRequest memory activation = StreamCurrentAssetPolicy.activationRequest(
            assetPolicy, address(paymentToken), keccak256("standard test ERC20"), DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (activation))
        );
        vm.warp(activation.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), activation.callData);
        _configureMintPhase(ERC20_PHASE, address(erc20Sale));
        (bytes32 policy,,) = erc20Sale.primaryPolicy(1, REVENUE);
        erc20SaleId = erc20Sale.registerSale(
            IStreamERC20FixedPriceSaleAdapter.SaleConfig(
                1,
                ERC20_PHASE,
                address(paymentToken),
                REVENUE,
                100,
                manager.phasePolicyHash(1, ERC20_PHASE),
                policy,
                0,
                type(uint64).max
            )
        );
        erc20Sale.transferOwnership(address(executor));
    }

    // Foundry's standard invariant-target discovery ABI, with no new test dependency.
    function targetContracts() external view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function targetSelectors() external view returns (FuzzSelector[] memory targets) {
        targets = new FuzzSelector[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = StreamCurrentStackHandler.step.selector;
        targets[0] = FuzzSelector(address(handler), selectors);
    }

    // Empty optional discovery surfaces use the StdInvariant ABI. Forge queries these
    // even when the campaign selects its single handler explicitly above.
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

    function invariant_currentStackConservesValueSupplyAndConsent() public view {
        handler.assertInvariants();
    }

    /// @dev Each fuzz run must have exercised every supported opening-cycle operation.
    function afterInvariant() public view {
        handler.assertCampaignActivity();
        handler.assertInvariants();
    }

    function testGhostModelRejectsWrongPayerDebitEvenWhenAggregateIsUnchanged() public {
        address first = vm.addr(0xC011EC70);
        address second = vm.addr(0xC011EC71);
        uint256 sum = paymentToken.rawBalance(first) + paymentToken.rawBalance(second);
        vm.prank(first);
        paymentToken.transfer(second, 1);
        require(
            paymentToken.rawBalance(first) + paymentToken.rawBalance(second) == sum,
            "aggregate changed"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "intended payer debit"));
        handler.assertInvariants();
    }

    function testHandlerOpeningCycleExercisesEveryRequiredOperation() public {
        for (uint256 i; i < 12; ++i) {
            handler.step(i * 101 + 7);
            handler.assertInvariants();
        }
        handler.assertCampaignActivity();
    }
}
