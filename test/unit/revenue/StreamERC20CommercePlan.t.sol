// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeImmediateSalesFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    StreamERC20CommerceDeployment as Deploy
} from "../../../script/current/StreamERC20CommerceDeployment.sol";
import {
    StreamERC20CommerceActivationPlan as Plan
} from "../../../script/current/StreamERC20CommerceActivationPlan.sol";
import {
    StreamERC20DutchSale
} from "../../../smart-contracts/domains/mint/StreamERC20DutchSale.sol";
import {
    StreamModuleRegistration,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamERC20PrimarySettlementAdapter
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import {
    IStreamERC20SaleExecution
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import {
    IStreamRoleRegistry
} from "../../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    IStreamMintAdmin
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintAdmin.sol";
import {
    IStreamMintReads
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import {
    IStreamMintPhaseFreeze
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    GovernanceActionPolicyEntry
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    GenesisBatch
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import { StreamRevenueRuntimePlan } from "../../../script/current/StreamRevenueRuntimePlan.sol";

interface CommerceOwnerTest {
    function transferOwnership(address) external;
}

/// @dev Actual four products, Core/Manager/Ledger/Registry/Recorder and upstream Safe.
/// Artist, entropy and target-side governance are the inherited explicit boundaries.
/// Artifact CREATE uses the exact literal constructor arguments and unchanged production caps;
/// no broadcast or full delayed Executor/37-product initialization is claimed.
contract StreamERC20CommercePlanTest is NativeImmediateSalesFixture {
    Deploy.Products private products;
    bytes32 private constant PRODUCT_MODULE = keccak256("reviewed additive ERC20 module manifest");

    function setUp() public override {
        super.setUp();
        Deploy.Configuration memory c;
        c.recorder = recorder;
        c.manager = manager;
        c.artists = artists;
        c.roles = IStreamRoleRegistry(address(auctionRoles));
        c.authority = address(revenueAuthority);
        c.owner = address(this);
        c.platformSigner = vm.addr(SIGNER_KEY);
        c.fixedReveal = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
        );
        c.priceReveal = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 100000, 2
        );
        c.dutchGas[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        c.dutchGas[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 500000, 100000, 2
        );
        c.dutchGas[2] = c.fixedReveal;
        products.chainId = block.chainid;
        products.configuration = c;
        products.configurationHash = keccak256(abi.encode(c));
        products.deploymentManifestHash = MANIFEST;
        products.moduleManifestHash = PRODUCT_MODULE;
        // Literal arguments below are an independent oracle for the helper encoder.
        bytes[4] memory literal;
        literal[0] = abi.encode(recorder, address(0), bytes32(0));
        literal[1] = abi.encode(manager, recorder, c.platformSigner, artists, c.fixedReveal);
        literal[2] = abi.encode(manager, recorder, c.platformSigner, artists, c.priceReveal);
        literal[3] = abi.encode(
            StreamERC20DutchSale.DeploymentConfig(
                manager, recorder, artists, c.roles, c.authority, c.dutchGas
            )
        );
        string[4] memory names = [
            "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter",
            "smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol:StreamUniversalFixedPriceSaleAdapter",
            "smart-contracts/domains/mint/StreamUniversalAllowlistPriceSale.sol:StreamUniversalAllowlistPriceSale",
            "smart-contracts/domains/mint/StreamERC20DutchSale.sol:StreamERC20DutchSale"
        ];
        for (uint256 i; i < 4; ++i) {
            address target = _artistArtifactCreate(names[i], literal[i]);
            products.targets[i] = target;
            products.runtimeCodeHashes[i] = target.codehash;
            products.constructorArgumentsHashes[i] = keccak256(literal[i]);
            require(target.code.length != 0 && target.code.length <= 24576, "real production cap");
        }
        products.dependencyCodeHashes = [
            address(recorder).codehash,
            address(manager).codehash,
            address(artists).codehash,
            address(auctionRoles).codehash
        ];
        Deploy.validate(products);
    }

    function testExactConstructorArgumentsAndFourOriginalRegistrationRoles() public view {
        bytes[4] memory args = Deploy.constructorArguments(products.configuration);
        StreamModuleRegistration[] memory rows = Deploy.registrations(products);
        require(rows.length == 4);
        for (uint256 i; i < 4; ++i) {
            require(keccak256(args[i]) == products.constructorArgumentsHashes[i]);
            require(
                rows[i].module == products.targets[i]
                    && rows[i].expectedRuntimeCodeHash == products.targets[i].codehash
            );
            require(rows[i].moduleVersion == keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"));
            require(
                rows[i].deploymentManifestHash == MANIFEST
                    && rows[i].moduleManifestHash == PRODUCT_MODULE
            );
            require(
                rows[i].interfaceId
                    == (i == 0
                            ? type(IStreamERC20PrimarySettlementAdapter).interfaceId
                            : type(IStreamERC20SaleExecution).interfaceId)
            );
            require(
                rows[i].moduleType
                    == (i == 0
                            ? keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER")
                            : i == 3
                                ? keccak256("DUTCH_AUCTION_ADAPTER")
                                : keccak256("FIXED_PRICE_SALE_ADAPTER"))
            );
        }
    }

    function testRegistrationPlanExecutesExactFourRowsAndRefusesRepeat() public {
        GenesisBatch memory b = Plan.admission(products);
        require(b.actionClass == 1 && b.calls.length == 4 && b.callDatas.length == 4);
        for (uint256 i; i < 4; ++i) {
            require(
                b.calls[i].target == address(registry) && b.calls[i].value == 0
                    && b.calls[i].callDataHash == keccak256(b.callDatas[i])
            );
            _context(b.calls[i].scopeHash, b.calls[i].oldValueHash, b.calls[i].newValueHash, 1);
            vm.prank(address(revenueAuthority));
            (bool ok, bytes memory reason) = address(registry).call(b.callDatas[i]);
            if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
            _clearContext();
            StreamModuleRecord memory row = registry.moduleRecord(products.targets[i]);
            require(
                row.status == ModuleRegistryStatus.ACTIVE
                    && row.moduleManifestHash == PRODUCT_MODULE
            );
        }
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.admission(products);
    }

    function testCatalogIsSortedZeroValueAndSubtractsExistingProfileWithoutReplacingIt()
        public
        view
    {
        GovernanceActionPolicyEntry[] memory all = Plan.policies(products);
        require(all.length == 5);
        uint256 seen;
        for (uint256 i; i < all.length; ++i) {
            require(all[i].targetCodeHash == all[i].target.codehash);
            require(all[i].targetProfileHash == keccak256(abi.encode(MANIFEST, all[i].target)));
            uint256 bit;
            if (all[i].target == address(registry)) {
                require(all[i].selector == registry.registerModule.selector);
                bit = 1;
            } else if (all[i].target == address(manager)) {
                require(all[i].selector == IStreamMintAdmin.setPhaseExecutor.selector);
                bit = 2;
            } else {
                require(all[i].selector == IStreamGasParameterHost.raiseGasParameter.selector);
                for (uint256 j = 1; j < 4; ++j) {
                    if (all[i].target == products.targets[j]) bit = uint256(1) << (j + 1);
                }
                require(bit != 0);
            }
            require((seen & bit) == 0);
            seen |= bit;
            require(
                all[i].actionClass == 1 && all[i].callType == 1 && all[i].valuePolicy == 0
                    && all[i].valueLimit == 0 && all[i].valueSemanticsHash == 0
            );
            if (i != 0) require(_key(all[i - 1]) < _key(all[i]));
        }
        require(seen == 31);
        GovernanceActionPolicyEntry[] memory known = new GovernanceActionPolicyEntry[](2);
        known[0] = all[0];
        known[1] = all[3];
        known[0].targetProfileHash = keccak256("existing legitimate profile");
        GovernanceActionPolicyEntry[] memory remaining = Plan.catalogAdditions(products, known);
        require(
            remaining.length == 3 && _key(remaining[0]) == _key(all[1])
                && _key(remaining[1]) == _key(all[2]) && _key(remaining[2]) == _key(all[4])
        );
    }

    function testCatalogDuplicateAndValueAndRuntimeConflictsRefuse() public {
        GovernanceActionPolicyEntry[] memory all = Plan.policies(products);
        GovernanceActionPolicyEntry[] memory known = new GovernanceActionPolicyEntry[](2);
        known[0] = all[0];
        known[1] = all[0];
        vm.expectRevert(abi.encodeWithSelector(Plan.IncompatibleERC20CommercePolicy.selector));
        this.additions(products, known);
        known = new GovernanceActionPolicyEntry[](1);
        known[0] = Plan.policies(products)[0];
        known[0].valueLimit = 1;
        vm.expectRevert(abi.encodeWithSelector(Plan.IncompatibleERC20CommercePolicy.selector));
        this.additions(products, known);
        known[0] = Plan.policies(products)[0];
        known[0].targetCodeHash = bytes32(uint256(7));
        vm.expectRevert(abi.encodeWithSelector(Plan.IncompatibleERC20CommercePolicy.selector));
        this.additions(products, known);
        known[0] = Plan.policies(products)[0];
        require(Plan.catalogAdditions(products, known).length == 4);
    }

    function testActualManagerHashIncludesCompleteExistingOrderAndOwnerCall() public {
        _admit();
        bytes32 before_ = manager.phasePolicyHash(1, PHASE);
        bytes32 expected = _literalNext(1);
        (bytes32 oldHash, bytes32 next) = Plan.phasePolicy(products, 1, 1, PHASE);
        require(oldHash == before_ && next == expected && next != oldHash);
        Plan.PhaseAdmission memory r = Plan.phaseCall(products, 1, 1, PHASE);
        require(r.actor == address(this) && !r.governed && r.target == address(manager));
        require(
            keccak256(r.data)
                == keccak256(
                    abi.encodeCall(
                        IStreamMintAdmin.setPhaseExecutor, (1, PHASE, products.targets[1], true)
                    )
                )
        );
        (bool ok,) = r.target.call(r.data);
        require(ok);
        require(
            manager.phasePolicyHash(1, PHASE) == expected
                && manager.phaseExecutor(1, PHASE, products.targets[1])
        );
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.phase(products, 1);
    }

    function testConsentUnavailableRefusesWithoutMutatingPhaseThenExactRetry() public {
        _admit();
        bytes32 before_ = manager.phasePolicyHash(1, PHASE);
        bytes32 expected = _literalNext(2);
        artists.setConsent(false);
        vm.expectRevert(abi.encodeWithSelector(Plan.ERC20CommerceConsentMissing.selector, expected));
        this.phase(products, 2);
        require(
            manager.phasePolicyHash(1, PHASE) == before_
                && !manager.phaseExecutor(1, PHASE, products.targets[2])
        );
        artists.setConsent(true);
        Plan.PhaseAdmission memory r = Plan.phaseCall(products, 2, 1, PHASE);
        (bool ok,) = r.target.call(r.data);
        require(ok && manager.phasePolicyHash(1, PHASE) == expected);
    }

    function testActualThresholdSafeOwnerUsesOriginalCallAndNonce() public {
        _admit();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xC01;
        keys[1] = 0xC02;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 712);
        manager.transferOwnership(address(safe));
        Plan.PhaseAdmission memory r = Plan.phaseCall(products, 3, 1, PHASE);
        require(r.actor == address(safe) && !r.governed && safe.nonce() == 0);
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.governed(products, 3);
        require(executeSafe(safe, keys, r.target, 0, r.data, 0));
        require(safe.nonce() == 1 && manager.phasePolicyHash(1, PHASE) == r.newPolicyHash);
    }

    function testBoundExecutorOwnerUsesExactClassOneZeroValuePlan() public {
        _admit();
        manager.transferOwnership(address(revenueAuthority));
        GenesisBatch memory b = Plan.governedPhase(products, 3, 1, PHASE);
        require(
            b.actionClass == 1 && b.calls.length == 1 && b.calls[0].value == 0
                && b.calls[0].target == address(manager)
        );
        require(b.calls[0].scopeHash == keccak256(abi.encode(address(manager), b.callDatas[0])));
        require(b.calls[0].callDataHash == keccak256(b.callDatas[0]));
        _context(b.calls[0].scopeHash, b.calls[0].oldValueHash, b.calls[0].newValueHash, 1);
        vm.prank(address(revenueAuthority));
        (bool ok,) = address(manager).call(b.callDatas[0]);
        require(ok);
        _clearContext();
        require(manager.phasePolicyHash(1, PHASE) == b.calls[0].newValueHash);
    }

    function testUnadmittedOrDeprecatedPaymentRefusesThenRestores() public {
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.phase(products, 1);
        _admit();
        _status(products.targets[0], ModuleRegistryStatus.DEPRECATED);
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.phase(products, 1);
        _status(products.targets[0], ModuleRegistryStatus.ACTIVE);
        require(Plan.phaseCall(products, 1, 1, PHASE).newPolicyHash == _literalNext(1));
    }

    function testMetadataRuntimeConstructorChainAndOwnerFaultsRefuseIndependently() public {
        this.valid(products);
        Deploy.Products memory p = products;
        p.constructorArgumentsHashes[2] = bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(Deploy.InvalidERC20CommerceDeployment.selector));
        this.valid(p);
        p = products;
        p.chainId += 1;
        vm.expectRevert(abi.encodeWithSelector(Deploy.InvalidERC20CommerceDeployment.selector));
        this.valid(p);
        p = products;
        p.runtimeCodeHashes[2] = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(Deploy.ERC20CommerceRuntimeChanged.selector, p.targets[2])
        );
        this.valid(p);
        p = products;
        p.configuration.owner = address(0xC0DE);
        p.configurationHash = keccak256(abi.encode(p.configuration));
        vm.expectRevert(abi.encodeWithSelector(Deploy.InvalidERC20CommerceDeployment.selector));
        this.valid(p);
        this.valid(products);
    }

    function testPermitPairAndGasConstructorMismatchRefuseWithoutProductChanges() public {
        Deploy.Products memory p = products;
        p.configuration.permit2CodeHash = bytes32(uint256(1));
        p.configurationHash = keccak256(abi.encode(p.configuration));
        vm.expectRevert(abi.encodeWithSelector(Deploy.InvalidERC20CommerceDeployment.selector));
        this.valid(p);
        p = products;
        p.configuration.priceReveal.floor += 1;
        p.configurationHash = keccak256(abi.encode(p.configuration));
        bytes[4] memory args = Deploy.constructorArguments(p.configuration);
        p.constructorArgumentsHashes[2] = keccak256(args[2]);
        vm.expectRevert(abi.encodeWithSelector(Deploy.InvalidERC20CommerceDeployment.selector));
        this.valid(p);
        this.valid(products);
    }

    function testWrongProductOrAbsentPhaseRefusesBeforeConsent() public {
        _admit();
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.phase(products, 0);
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.phase(products, 4);
        vm.expectRevert(abi.encodeWithSelector(Plan.InvalidERC20CommerceActivation.selector));
        this.absentPhase(products);
        require(Plan.phaseCall(products, 2, 1, PHASE).newPolicyHash == _literalNext(2));
    }

    function testRuntimeActivationIsSeparateFromDeployingAndRegisteringProducts() public {
        // The inherited fixture intentionally has no opted-in runtime registry.
        this.valid(products);
        _admit();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRevenueRuntimePlan.RevenueRuntimeActivationIncomplete.selector
            )
        );
        this.runtimeActivated(products);
        require(!manager.phaseExecutor(1, PHASE, products.targets[1]));
    }

    function _admit() private {
        GenesisBatch memory b = Plan.admission(products);
        for (uint256 i; i < 4; ++i) {
            _context(b.calls[i].scopeHash, b.calls[i].oldValueHash, b.calls[i].newValueHash, 1);
            vm.prank(address(revenueAuthority));
            (bool ok, bytes memory reason) = address(registry).call(b.callDatas[i]);
            if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
            _clearContext();
        }
    }

    function _literalNext(uint256 product) private view returns (bytes32) {
        (, IStreamMintManager.MintPhaseConfig memory c) = manager.phase(1, PHASE);
        bytes32[] memory ids = manager.phaseCounterIds(1, PHASE);
        IStreamMintManager.MintCounterConfig[] memory rows =
            new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            rows[i] = manager.counterConfig(1, PHASE, ids[i]);
        }
        address[] memory before_ = IStreamMintPhaseFreeze(address(manager)).phaseExecutors(1, PHASE);
        address[] memory next = new address[](before_.length + 1);
        for (uint256 i; i < before_.length; ++i) {
            next[i] = before_[i];
        }
        next[before_.length] = products.targets[product];
        return
            manager.previewPhasePolicyHash(
                1, PHASE, c, manager.phaseGate(1, PHASE), ids, rows, next
            );
    }

    function _key(GovernanceActionPolicyEntry memory r) private pure returns (bytes32) {
        return keccak256(abi.encode(r.actionClass, r.target, r.selector));
    }

    function valid(Deploy.Products calldata p) external view {
        Deploy.validate(p);
    }

    function admission(Deploy.Products calldata p) external view returns (GenesisBatch memory) {
        return Plan.admission(p);
    }

    function additions(Deploy.Products calldata p, GovernanceActionPolicyEntry[] calldata known)
        external
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return Plan.catalogAdditions(p, known);
    }

    function phase(Deploy.Products calldata p, uint8 i)
        external
        view
        returns (Plan.PhaseAdmission memory)
    {
        return Plan.phaseCall(p, i, 1, PHASE);
    }

    function governed(Deploy.Products calldata p, uint8 i)
        external
        view
        returns (GenesisBatch memory)
    {
        return Plan.governedPhase(p, i, 1, PHASE);
    }

    function absentPhase(Deploy.Products calldata p) external view {
        Plan.phaseCall(p, 1, 1, keccak256("absent phase"));
    }

    function runtimeActivated(Deploy.Products calldata p) external view {
        Plan.requireRuntimeActivated(p);
    }
}
