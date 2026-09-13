// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../script/current/StreamGovernanceGenesisPlan.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Real five-leaf governance bootstrap removes the archive/artist constructor cycle.
/// @dev This foundation is not the full product inventory or final estate activation.
contract StreamCurrentGovernanceBootstrapTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamGovernanceGenesisPlan.Configuration internal configuration;
    OfficialSafe internal governor;
    uint256[] internal signers;
    bytes private encodedPlan;
    StreamArweaveCheckpointVerifier private checkpoint;

    function setUp() public {
        StreamGovernanceGenesisPlan.Configuration memory c;
        c.executor = new StreamGovernanceExecutor(address(this));
        c.roles = new StreamRoleRegistry(address(c.executor));
        c.registry = new StreamModuleRegistry(
            c.executor,
            keccak256("foundation registry"),
            "urn:6529stream:fixture:foundation-registry"
        );
        c.deploymentHash = keccak256("foundation fixture deployment");
        c.core = new StreamCore(
            "Stream foundation",
            "STREAM",
            address(c.executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(c.registry),
                address(c.registry).codehash,
                keccak256("foundation registry"),
                c.deploymentHash
            ),
            StreamCurrentStackPlan.gasParameters()
        );
        c.manifest = new StreamSystemManifest(address(c.core), address(c.executor));
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xF001;
        owners[1] = 0xF002;
        owners[2] = 0xF003;
        governor = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 0xF001
        );
        signers.push(owners[0]);
        signers.push(owners[2]);
        c.governanceRoot = address(governor);
        c.bootstrapAuthority = address(this);
        c.guardians = new address[](2);
        c.guardians[0] = address(new StreamGovernanceActor(address(this)));
        c.guardians[1] = address(new StreamGovernanceActor(address(this)));
        if (c.guardians[0] > c.guardians[1]) {
            (c.guardians[0], c.guardians[1]) = (c.guardians[1], c.guardians[0]);
        }
        c.manifestModuleHash = keccak256("foundation manifest module");
        c.moduleURI = "urn:6529stream:fixture:foundation-module";
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"governance foundation only\",\"version\":1}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:fixture:foundation",
            keccak256("events"),
            keccak256("compatibility"),
            keccak256("numeric ids"),
            keccak256("schema"),
            keccak256("canonicalization"),
            keccak256("specification"),
            keccak256("client")
        );
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            StreamGovernanceGenesisPlan.build(c, payload, update);
        encodedPlan = abi.encode(binding, batches);
        configuration = c;

        StreamArchivalTypes.Observer[] memory observers = new StreamArchivalTypes.Observer[](2);
        observers[0] = StreamArchivalTypes.Observer(vm.addr(0xF011), keccak256("observer one"));
        observers[1] = StreamArchivalTypes.Observer(vm.addr(0xF012), keccak256("observer two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        checkpoint =
            new StreamArweaveCheckpointVerifier(address(c.executor), observers, 2, _signatureGas());
    }

    function testCurrentFoundationSealsBeforeCoverageDeploymentWithRealSafeRoot() public {
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        require(address(c.executor.roleRegistry()) == address(0), "not initialized");
        vm.expectRevert();
        this.deployCoverage();
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        c.executor.commitGenesisPlan(c.executor.hashGenesisPlan(binding, batches));
        c.executor.initializeGenesis(binding, batches);
        _assertFoundation(binding);
        StreamArchivalCoverage coverage = this.deployCoverage();
        _assertCoverage(coverage);
        require(
            executeSafe(
                governor,
                signers,
                address(c.executor),
                0,
                abi.encodeCall(c.executor.roleRegistry, ()),
                0
            ),
            "actual Safe governance read"
        );
        require(
            executeSafe(
                governor, signers, address(coverage), 0, abi.encodeCall(coverage.core, ()), 0
            ),
            "actual Safe coverage read"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGenesisInitializer.GenesisAlreadyInitialized.selector)
        );
        c.executor.initializeGenesis(binding, batches);
    }

    function testCurrentPreparedFoundationRejectsChangedPlanThenCompletesExactPlan() public {
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        c.executor.commitGenesisPlan(c.executor.hashGenesisPlan(binding, batches));
        bytes32 expected = binding.expectedManifestHash;
        binding.expectedManifestHash = keccak256("uncommitted replacement manifest");
        vm.expectRevert();
        c.executor.prepareGenesis(binding, batches);
        require(
            address(c.executor.roleRegistry()) == address(0), "failed preparation cannot bind roles"
        );
        require(c.registry.moduleCount() == 0, "failed preparation cannot register modules");
        binding.expectedManifestHash = expected;
        c.executor.prepareGenesis(binding, batches);
        require(address(c.executor.roleRegistry()) == address(c.roles), "actual prepared role pin");
        // The immutable provider may now deploy. It does not enter or rewrite the committed foundation plan.
        StreamArchivalCoverage coverage = this.deployCoverage();
        _assertCoverage(coverage);
        require(c.registry.moduleCount() == 0, "preparation has not executed product writes");
        c.executor.initializeGenesis(binding, batches);
        _assertFoundation(binding);
        _assertCoverage(coverage);
    }

    function deployCoverage() external returns (StreamArchivalCoverage) {
        return new StreamArchivalCoverage(
            address(configuration.core),
            address(configuration.executor),
            address(configuration.roles),
            address(checkpoint),
            _signatureGas(),
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
    }

    function _signatureGas()
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(
            "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
    }

    function _plan()
        internal
        view
        returns (SystemManifestBootstrapBinding memory, GenesisBatch[] memory)
    {
        return abi.decode(encodedPlan, (SystemManifestBootstrapBinding, GenesisBatch[]));
    }

    function _assertCoverage(StreamArchivalCoverage coverage) private view {
        require(coverage.core() == address(configuration.core), "real Core");
        require(coverage.roleRegistry() == address(configuration.roles), "canonical roles");
        require(
            coverage.governanceAuthority() == address(configuration.executor), "canonical Executor"
        );
        require(coverage.checkpointVerifier() == address(checkpoint), "exact verifier");
        require(
            address(coverage).code.length <= 24576 && address(checkpoint).code.length <= 24576,
            "deployable archival runtimes"
        );
    }

    function _assertFoundation(SystemManifestBootstrapBinding memory binding) private view {
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        (bool ok, bytes memory data) = address(c.executor)
            .staticcall(abi.encodeCall(c.executor.systemManifestBootstrapState, ()));
        require(ok, "actual bootstrap state");
        StreamGovernanceManifest.BootstrapStateView memory state =
            abi.decode(data, (StreamGovernanceManifest.BootstrapStateView));
        require(
            state.bound && state.isSealed && c.executor.genesisInitialized(),
            "canonical sealed foundation"
        );
        require(
            state.inventoryLeafCount == 5 && state.expectedInventoryLeafCount == 5,
            "five real foundation leaves"
        );
        require(
            state.inventoryStateRoot == binding.expectedInventoryStateRoot,
            "exact committed inventory"
        );
        require(
            state.governanceRoot == address(governor) && governor.getThreshold() == 2
                && governor.getOwners().length == 3,
            "actual two-of-three Safe root"
        );
        require(
            c.registry.moduleCount() == 2 && c.manifest.streamSystemManifestPointerCount() == 1,
            "foundation registration and publication only"
        );
        StreamCorePointerState memory pointer =
            StreamCurrentStackPlan.readPointer(c.core, keccak256("SYSTEM_MANIFEST"));
        require(
            pointer.target == address(c.manifest) && pointer.frozen, "permanent manifest installed"
        );
        require(
            StreamCurrentStackPlan.readPointer(c.core, keccak256("ARTIST_REGISTRY")).target
                == address(0),
            "no pretend artist deployment"
        );
        require(
            StreamCurrentStackPlan.readPointer(c.core, keccak256("MINT_MANAGER")).target
                == address(0),
            "no pretend product activation"
        );
        bool extension;
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            GovernanceActionPolicyEntry memory row = binding.actionPolicies[i];
            if (
                row.target == address(c.executor)
                    && row.selector == c.executor.extendGovernanceActionPolicy.selector
            ) {
                require(
                    row.actionClass == 3 && row.targetCodeHash == address(c.executor).codehash,
                    "future admission remains exact delayed governance"
                );
                extension = true;
            }
        }
        require(extension, "catalog extension admitted before seal");
    }
}
