// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamCurrentTestSetupPlans.sol";
import {
    IStreamSetupPlansMintManager,
    IStreamSetupPlansMintLedger,
    IStreamSetupPlansFixedPriceSaleAdapter,
    IStreamSetupPlansEnglishAuctionHouse,
    IStreamSetupPlansEntropyCoordinator,
    IStreamSetupPlansMetadataRouter,
    IStreamSetupPlansAssetPolicyRegistry,
    IStreamSetupPlansCore,
    IStreamSetupPlansRoyaltyResolver,
    IStreamSetupPlansGovernanceExecutor,
    IStreamSetupPlansRoleRegistry,
    IStreamSetupPlansModuleRegistry,
    IStreamSetupPlansSystemManifest,
    IStreamSetupPlansSplitFactory,
    IStreamSetupPlansArtistOnboardingRegistry,
    IStreamSetupPlansRevenueEscrow,
    IStreamSetupPlansRevenueResolver
} from "../helpers/StreamCurrentTestSetupPlanTargets.sol";
import { StreamGovernanceGenesisPlan } from "../../script/current/StreamGovernanceGenesisPlan.sol";
import { StreamCore } from "../../smart-contracts/core/StreamCore.sol";
import { StreamCorePointerState } from "../../smart-contracts/core/StreamCoreExternalReads.sol";
import {
    StreamGovernanceExecutor
} from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import { StreamRoleRegistry } from "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import { StreamModuleRegistry } from "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import { StreamSystemManifest } from "../../smart-contracts/domains/governance/StreamSystemManifest.sol";

/// @dev Real, distinct immutable bytecode for policy code-hash inputs only.
contract SetupPlansCodeAnchor {
    uint256 public immutable tag;

    constructor(uint256 value) {
        tag = value;
    }
}

/// @dev Explicit planner read double. This is not a deployed Core acceptance fixture.
contract SetupPlansCoreReads {
    address private immutable caller;
    bool public failing;

    constructor(address expected) {
        caller = expected;
    }

    function fail(bool value) external {
        failing = value;
    }

    function getSatellitePointer(bytes32) external view returns (StreamCorePointerState memory p) {
        require(msg.sender == caller && !failing, "planner pointer control");
        return p;
    }
}

/// @dev Explicit planner read double; rejects a caller-changing library boundary.
contract SetupPlansRegistryReads {
    address private immutable caller;
    uint64 private count;
    uint256 private modules;

    constructor(address expected) {
        caller = expected;
    }

    function configure(uint64 count_, uint256 modules_) external {
        count = count_;
        modules = modules_;
    }

    function registrationChainHash() external view returns (bytes32, uint64) {
        require(msg.sender == caller, "original planner caller");
        return (bytes32(0), count);
    }

    function moduleCount() external view returns (uint256) {
        require(msg.sender == caller, "original planner caller");
        return modules;
    }

    function moduleRegistryManifest() external view returns (bytes32, string memory, uint64) {
        require(msg.sender == caller, "original planner caller");
        return (keccak256("registry control"), "urn:planner:control", 1);
    }
}

/// @notice Compares the real linked library with pinned original planner controls.
/// @dev Unit planner evidence only; no current-stack deployment or gas claim.
contract StreamCurrentSetupPlansTest {
    bytes32 private constant PROFILE = keccak256("current-stack integration fixture v1");
    SetupPlansCoreReads private coreReads;
    SetupPlansRegistryReads private registryReads;
    StreamCurrentTestSetupPlans.Targets private targets;
    uint256 private sentinel = 6529;

    function setUp() public {
        address[17] memory a;
        for (uint256 i; i < a.length; ++i) {
            a[i] = address(new SetupPlansCodeAnchor(i));
        }
        targets = StreamCurrentTestSetupPlans.Targets(
            IStreamSetupPlansMintManager(a[0]),
            IStreamSetupPlansMintLedger(a[1]),
            IStreamSetupPlansFixedPriceSaleAdapter(a[2]),
            IStreamSetupPlansEnglishAuctionHouse(payable(a[3])),
            IStreamSetupPlansEntropyCoordinator(payable(a[4])),
            IStreamSetupPlansMetadataRouter(a[5]),
            IStreamSetupPlansAssetPolicyRegistry(a[6]),
            IStreamSetupPlansCore(a[7]),
            IStreamSetupPlansRoyaltyResolver(a[8]),
            IStreamSetupPlansGovernanceExecutor(payable(a[9])),
            IStreamSetupPlansRoleRegistry(a[10]),
            IStreamSetupPlansModuleRegistry(a[11]),
            IStreamSetupPlansSystemManifest(a[12]),
            IStreamSetupPlansSplitFactory(a[13]),
            IStreamSetupPlansArtistOnboardingRegistry(a[14]),
            IStreamSetupPlansRevenueEscrow(payable(a[15])),
            IStreamSetupPlansRevenueResolver(a[16])
        );
        coreReads = new SetupPlansCoreReads(address(this));
        registryReads = new SetupPlansRegistryReads(address(this));
    }

    function testEveryOriginalPolicyRowAndAdditionalFieldsMatch() public {
        GovernanceActionPolicyEntry[] memory extra = _additional();
        StreamCurrentTestSetupPlans.Targets memory t = targets;
        bytes32 beforeInputs = keccak256(abi.encode(t, extra));
        SetupPlansOriginalPolicies original = new SetupPlansOriginalPolicies(t, PROFILE, extra);
        GovernanceActionPolicyEntry[] memory expected = original.policies();
        GovernanceActionPolicyEntry[] memory actual =
            StreamCurrentTestSetupPlans.operatingPolicies(t, PROFILE, extra);
        require(
            actual.length == 78 && keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "all original row bytes"
        );
        require(
            actual[19].actionClass == 2 && actual[20].actionClass == 2, "royalty freeze overrides"
        );
        require(
            keccak256(abi.encode(actual[76], actual[77]))
                == keccak256(abi.encode(extra[0], extra[1])),
            "all appended fields"
        );
        require(
            keccak256(abi.encode(t, extra)) == beforeInputs && sentinel == 6529,
            "inputs and host storage untouched"
        );
    }

    function testTargetChangesAffectOnlyTheirOriginalRows() public {
        StreamCurrentTestSetupPlans.Targets memory t = targets;
        GovernanceActionPolicyEntry[] memory extra = _additional();
        GovernanceActionPolicyEntry[] memory beforeRows =
            StreamCurrentTestSetupPlans.operatingPolicies(t, PROFILE, extra);
        address oldTarget = address(t.manager);
        t.manager = IStreamSetupPlansMintManager(address(new SetupPlansCodeAnchor(999)));
        GovernanceActionPolicyEntry[] memory afterRows =
            StreamCurrentTestSetupPlans.operatingPolicies(t, PROFILE, extra);
        SetupPlansOriginalPolicies original = new SetupPlansOriginalPolicies(t, PROFILE, extra);
        require(
            keccak256(abi.encode(afterRows)) == keccak256(abi.encode(original.policies())),
            "changed target original bytes"
        );
        uint256 changed;
        for (uint256 i; i < 76; ++i) {
            if (beforeRows[i].target == oldTarget) {
                ++changed;
                require(
                    afterRows[i].target == address(t.manager)
                        && afterRows[i].targetCodeHash == address(t.manager).codehash,
                    "actual changed target and code"
                );
                require(
                    keccak256(abi.encode(beforeRows[i])) != keccak256(abi.encode(afterRows[i])),
                    "changed target detected"
                );
            } else {
                require(
                    keccak256(abi.encode(beforeRows[i])) == keccak256(abi.encode(afterRows[i])),
                    "unrelated row unchanged"
                );
            }
        }
        require(changed != 0, "negative control exercised");
    }

    function testDeploymentHashChangesEveryBaseProfileAndPreservesAdditionalRows() public view {
        GovernanceActionPolicyEntry[] memory extra = _additional();
        GovernanceActionPolicyEntry[] memory a =
            StreamCurrentTestSetupPlans.operatingPolicies(targets, PROFILE, extra);
        GovernanceActionPolicyEntry[] memory b =
            StreamCurrentTestSetupPlans.operatingPolicies(targets, bytes32(uint256(999)), extra);
        for (uint256 i; i < 76; ++i) {
            require(
                a[i].targetProfileHash != b[i].targetProfileHash,
                "deployment hash binds every base row"
            );
            a[i].targetProfileHash = b[i].targetProfileHash;
            require(
                keccak256(abi.encode(a[i])) == keccak256(abi.encode(b[i])), "only profile changes"
            );
        }
        require(
            keccak256(abi.encode(a[76], a[77])) == keccak256(abi.encode(b[76], b[77])),
            "additional profile stays explicit"
        );
    }

    function testEmptyAdditionalAndZeroTargetsRetainOriginalBehavior() public {
        StreamCurrentTestSetupPlans.Targets memory t;
        GovernanceActionPolicyEntry[] memory empty = new GovernanceActionPolicyEntry[](0);
        SetupPlansOriginalPolicies original = new SetupPlansOriginalPolicies(t, bytes32(0), empty);
        GovernanceActionPolicyEntry[] memory actual =
            StreamCurrentTestSetupPlans.operatingPolicies(t, bytes32(0), empty);
        require(
            actual.length == 76
                && keccak256(abi.encode(actual)) == keccak256(abi.encode(original.policies())),
            "original empty/zero control"
        );
    }

    function testFoundationFullReturnedBytesAndInputsMatch() public view {
        (
            StreamGovernanceGenesisPlan.Configuration memory c,
            StreamSystemManifestUpdate memory update
        ) = _foundation();
        bytes32 beforeInputs = keccak256(abi.encode(c, update));
        (SystemManifestBootstrapBinding memory oldBinding, GenesisBatch[] memory oldBatches) =
            StreamGovernanceGenesisPlan.build(c, address(0xBEEF), update);
        require(keccak256(abi.encode(c, update)) == beforeInputs, "original inputs unchanged");
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            StreamCurrentTestSetupPlans.foundationPlan(c, address(0xBEEF), update);
        require(
            keccak256(abi.encode(binding, batches))
                == keccak256(abi.encode(oldBinding, oldBatches)),
            "complete foundation ABI bytes"
        );
        require(
            binding.expectedInventoryLeafCount == 5 && batches.length == 4
                && binding.initialTerminalFreezeVetoGuardians.length == 2,
            "nonempty original plan"
        );
        require(
            keccak256(abi.encode(c, update)) == beforeInputs && sentinel == 6529,
            "linked inputs and storage unchanged"
        );
    }

    function testFoundationPayloadAndUpdateChangesAreNotLost() public view {
        (
            StreamGovernanceGenesisPlan.Configuration memory c,
            StreamSystemManifestUpdate memory update
        ) = _foundation();
        (SystemManifestBootstrapBinding memory a, GenesisBatch[] memory x) =
            StreamCurrentTestSetupPlans.foundationPlan(c, address(0xBEEF), update);
        update.manifestHash = keccak256("changed update");
        (SystemManifestBootstrapBinding memory b, GenesisBatch[] memory y) =
            StreamCurrentTestSetupPlans.foundationPlan(c, address(0xFEED), update);
        (SystemManifestBootstrapBinding memory expected, GenesisBatch[] memory rows) =
            StreamGovernanceGenesisPlan.build(c, address(0xFEED), update);
        require(
            keccak256(abi.encode(b, y)) == keccak256(abi.encode(expected, rows)),
            "changed inputs exact original bytes"
        );
        require(
            keccak256(abi.encode(a, x)) != keccak256(abi.encode(b, y)),
            "negative input control differs"
        );
    }

    function testBothRejectMismatchedRegistryCount() public {
        registryReads.configure(0, 1);
        _sameFailure(abi.encodeWithSignature("Error(string)", "registry count mismatch"));
    }

    function testBothRejectNonemptyGenesisRegistry() public {
        registryReads.configure(1, 1);
        _sameFailure(abi.encodeWithSignature("Error(string)", "genesis registry not empty"));
    }

    function testBothRejectFailedPointerRead() public {
        coreReads.fail(true);
        _sameFailure(abi.encodeWithSignature("Error(string)", "invalid pointer read"));
    }

    function originalFoundation()
        external
        view
        returns (SystemManifestBootstrapBinding memory, GenesisBatch[] memory)
    {
        (StreamGovernanceGenesisPlan.Configuration memory c, StreamSystemManifestUpdate memory u) =
            _foundation();
        return StreamGovernanceGenesisPlan.build(c, address(0xBEEF), u);
    }

    function linkedFoundation()
        external
        view
        returns (SystemManifestBootstrapBinding memory, GenesisBatch[] memory)
    {
        (StreamGovernanceGenesisPlan.Configuration memory c, StreamSystemManifestUpdate memory u) =
            _foundation();
        return StreamCurrentTestSetupPlans.foundationPlan(c, address(0xBEEF), u);
    }

    function _sameFailure(bytes memory expected) private {
        (bool oldOk, bytes memory oldError) =
            address(this).call(abi.encodeCall(this.originalFoundation, ()));
        (bool newOk, bytes memory newError) =
            address(this).call(abi.encodeCall(this.linkedFoundation, ()));
        require(
            !oldOk && !newOk && keccak256(oldError) == keccak256(expected)
                && keccak256(newError) == keccak256(expected),
            "same exact original failure"
        );
    }

    function _foundation()
        private
        view
        returns (
            StreamGovernanceGenesisPlan.Configuration memory c,
            StreamSystemManifestUpdate memory u
        )
    {
        c.executor = StreamGovernanceExecutor(payable(address(targets.executor)));
        c.roles = StreamRoleRegistry(address(targets.roles));
        c.core = StreamCore(address(coreReads));
        c.registry = StreamModuleRegistry(address(registryReads));
        c.manifest = StreamSystemManifest(address(targets.manifest));
        c.bootstrapAuthority = address(this);
        c.governanceRoot = address(targets.artists);
        c.guardians = new address[](2);
        c.guardians[0] = address(targets.sale);
        c.guardians[1] = address(targets.auction);
        if (c.guardians[0] > c.guardians[1]) {
            (c.guardians[0], c.guardians[1]) = (c.guardians[1], c.guardians[0]);
        }
        c.deploymentHash = PROFILE;
        c.manifestModuleHash = keccak256("manifest module");
        c.moduleURI = "urn:planner:module";
        u = StreamSystemManifestUpdate(
            keccak256("manifest"),
            "urn:planner:manifest",
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            bytes32(uint256(5)),
            bytes32(uint256(6)),
            bytes32(uint256(7))
        );
    }

    function _additional() private view returns (GovernanceActionPolicyEntry[] memory rows) {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = GovernanceActionPolicyEntry(
            3,
            address(targets.core),
            bytes4(0xabcdef12),
            address(targets.core).codehash,
            bytes32(uint256(11)),
            2,
            3,
            4,
            bytes32(uint256(12))
        );
        // Allocate a separate struct: memory assignment would alias rows[0].
        GovernanceActionPolicyEntry memory first = rows[0];
        rows[1] = GovernanceActionPolicyEntry(
            first.actionClass,
            first.target,
            first.selector,
            first.targetCodeHash,
            first.targetProfileHash,
            first.callType,
            first.valuePolicy,
            first.valueLimit,
            first.valueSemanticsHash
        );
        rows[1].actionClass = 0;
        require(
            rows[0].actionClass == 3 && rows[1].actionClass == 0,
            "independent additional policy classes"
        );
    }
}

/// @dev Historical control: the three policy bodies below are copied from
/// StreamCurrentStackFixture at 64891089052ddfba393458359a34aaf5073ee1ea.
/// Keep the original bodies independent of the new library implementation.
contract SetupPlansOriginalPolicies {
    IStreamSetupPlansMintManager private manager;
    IStreamSetupPlansMintLedger private ledger;
    IStreamSetupPlansFixedPriceSaleAdapter private sale;
    IStreamSetupPlansEnglishAuctionHouse private auction;
    IStreamSetupPlansEntropyCoordinator private entropy;
    IStreamSetupPlansMetadataRouter private router;
    IStreamSetupPlansAssetPolicyRegistry private assetPolicy;
    IStreamSetupPlansCore private core;
    IStreamSetupPlansRoyaltyResolver private royalties;
    IStreamSetupPlansGovernanceExecutor private executor;
    IStreamSetupPlansRoleRegistry private roles;
    IStreamSetupPlansModuleRegistry private registry;
    IStreamSetupPlansSystemManifest private manifest;
    IStreamSetupPlansSplitFactory private factory;
    IStreamSetupPlansArtistOnboardingRegistry private artists;
    IStreamSetupPlansRevenueEscrow private revenueEscrow;
    IStreamSetupPlansRevenueResolver private primaryResolver;
    bytes32 private DEPLOYMENT_HASH;
    GovernanceActionPolicyEntry[] private extra;

    constructor(
        StreamCurrentTestSetupPlans.Targets memory t,
        bytes32 hash,
        GovernanceActionPolicyEntry[] memory additional
    ) {
        manager = t.manager;
        ledger = t.ledger;
        sale = t.sale;
        auction = t.auction;
        entropy = t.entropy;
        router = t.router;
        assetPolicy = t.assetPolicy;
        core = t.core;
        royalties = t.royalties;
        executor = t.executor;
        roles = t.roles;
        registry = t.registry;
        manifest = t.manifest;
        factory = t.factory;
        artists = t.artists;
        revenueEscrow = t.revenueEscrow;
        primaryResolver = t.primaryResolver;
        DEPLOYMENT_HASH = hash;
        for (uint256 i; i < additional.length; ++i) {
            extra.push(additional[i]);
        }
    }

    function policies() external view returns (GovernanceActionPolicyEntry[] memory) {
        return _operatingPolicies();
    }

    function _additionalOperatingPolicies()
        private
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return extra;
    }

    function _operatingPolicies() private view returns (GovernanceActionPolicyEntry[] memory rows) {
        GovernanceActionPolicyEntry[] memory additional = _additionalOperatingPolicies();
        rows = new GovernanceActionPolicyEntry[](76 + additional.length);
        rows[0] = _operatingPolicy(address(manager), manager.configurePhase.selector);
        rows[1] = _operatingPolicy(address(manager), manager.setPhaseExecutor.selector);
        rows[2] = _operatingPolicy(address(manager), manager.setPhasePaused.selector);
        rows[3] = _operatingPolicy(address(ledger), ledger.setLedgerWriter.selector);
        rows[4] = _operatingPolicy(address(sale), sale.setPlatformSigner.selector);
        rows[5] = _operatingPolicy(address(sale), sale.setPaused.selector);
        rows[6] = _operatingPolicy(address(auction), auction.setPlatformSigner.selector);
        rows[7] = _operatingPolicy(address(auction), auction.setPaused.selector);
        rows[8] = _operatingPolicy(address(entropy), entropy.setRequester.selector);
        rows[9] = _operatingPolicy(address(entropy), entropy.setProviderRevoked.selector);
        rows[10] = _operatingPolicy(address(entropy), entropy.markRequestStale.selector);
        rows[11] = _operatingPolicy(address(entropy), entropy.markRequestFailed.selector);
        rows[12] = _operatingPolicy(address(router), router.setCollectionScript.selector);
        rows[13] = _operatingPolicy(address(router), router.setContractMetadataURI.selector);
        rows[14] = _operatingPolicy(address(assetPolicy), assetPolicy.setAssetStatus.selector);
        rows[15] = _operatingPolicy(address(core), core.raiseGasParameter.selector);
        rows[16] = _operatingPolicy(address(core), core.setCollectionMaxSupply.selector);
        rows[17] = _operatingPolicy(address(royalties), royalties.configureDefaultRoyalty.selector);
        rows[18] =
            _operatingPolicy(address(royalties), royalties.configureCollectionRoyalty.selector);
        rows[19] = _operatingPolicy(address(royalties), royalties.freezeDefaultRoyalty.selector);
        rows[19].actionClass = 2;
        rows[20] = _operatingPolicy(address(royalties), royalties.freezeCollectionRoyalty.selector);
        rows[20].actionClass = 2;
        uint256 i = 21;
        rows[i++] = _operatingPolicy(3, address(executor), executor.rotateGovernanceRoot.selector);
        rows[i++] = _operatingPolicy(
            3, address(executor), executor.extendGovernanceActionPolicy.selector
        );
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerProposer.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerProposer.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerCanceller.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerCanceller.selector);
        rows[i++] =
            _operatingPolicy(0, address(executor), executor.setApprovedNativeReceiver.selector);
        rows[i++] =
            _operatingPolicy(1, address(executor), executor.setApprovedNativeReceiver.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.setTighteningCall.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.setTighteningCall.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerFreezeSelector.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerFreezeSelector.selector);
        rows[i++] = _operatingPolicy(
            2, address(executor), executor.registerSystemManifestTailTrigger.selector
        );
        rows[i++] = _operatingPolicy(1, address(roles), roles.grantRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.revokeRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.grantScopedRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.revokeScopedRole.selector);
        rows[i++] = _operatingPolicy(0, address(roles), roles.registerRoleManager.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.registerRoleManager.selector);
        rows[i++] = _operatingPolicy(0, address(registry), registry.setModuleStatus.selector);
        rows[i++] = _operatingPolicy(1, address(registry), registry.setModuleStatus.selector);
        rows[i++] =
            _operatingPolicy(1, address(registry), registry.setModuleRegistryManifest.selector);
        rows[i++] = _operatingPolicy(0, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(1, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(0, address(core), core.setCollectionMaxSupply.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.blockCollectionBurns.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.freezeCollection.selector);
        rows[i++] =
            _operatingPolicy(0, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] =
            _operatingPolicy(1, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] =
            _operatingPolicy(2, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] = _operatingPolicy(address(manager), manager.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(factory), factory.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(artists), artists.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.setCreditProducer.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(primaryResolver), primaryResolver.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(
            address(primaryResolver), primaryResolver.createPrimaryTemplate.selector
        );
        rows[i++] = _operatingPolicy(
            address(primaryResolver), primaryResolver.createDynamicPrimaryTemplate.selector
        );
        rows[i++] =
            _operatingPolicy(address(assetPolicy), assetPolicy.setAssetPermitPolicy.selector);
        rows[i++] = _operatingPolicy(
            address(primaryResolver), primaryResolver.setPrimaryTemplateAssignment.selector
        );
        rows[i++] = _operatingPolicy(address(entropy), entropy.raiseTimeParameter.selector);
        rows[i++] = _operatingPolicy(
            1, address(artists), IStreamArtistIdentityContest.contestArtistIdentity.selector
        );
        rows[i++] = _operatingPolicy(
            2, address(artists), IStreamArtistIdentityContest.contestArtistIdentity.selector
        );
        rows[i++] = _operatingPolicy(
            1,
            address(artists),
            IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector
        );
        rows[i++] = _operatingPolicy(
            2,
            address(artists),
            IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector
        );
        rows[i++] = _operatingPolicy(address(router), router.setCollectionScriptManifest.selector);
        rows[i++] = _operatingPolicy(address(router), router.setCollectionMediaManifest.selector);
        rows[i++] = _operatingPolicy(address(router), router.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(entropy), entropy.activateEntropyProvider.selector);
        rows[i++] = _operatingPolicy(0, address(entropy), entropy.deprecateEntropyProvider.selector);
        rows[i++] = _operatingPolicy(0, address(entropy), entropy.revokeEntropyProvider.selector);
        // Bounded predecessor grace remains an exact delayed-loosening CALL.
        rows[i++] = _operatingPolicy(address(manager), manager.setPhaseExecutorWithGrace.selector);
        rows[i++] = _operatingPolicy(2, address(manager), manager.freezePhase.selector);
        rows[i++] = _operatingPolicy(1, address(ledger), ledger.importPhaseFreezes.selector);
        // Metadata, economics and entropy configuration are also collected from genesis.
        for (uint256 j; j < additional.length; ++j) {
            rows[i++] = additional[j];
        }
        assert(i == rows.length);
    }

    function _operatingPolicy(uint8 actionClass, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory row)
    {
        row = _operatingPolicy(target, selector);
        row.actionClass = actionClass;
    }

    function _operatingPolicy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }
}
