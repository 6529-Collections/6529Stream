// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/StreamCorePermanentTarget.t.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyScopeRegistration.sol";

interface RegistrationColdVm {
    function cool(address target) external;
}

contract RegistrationCapReceiver is IERC721Receiver {
    error ReceiverRefusedAfterRegistration();
    bool public refuse = true;

    function allow() external {
        refuse = false;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        if (refuse) revert ReceiverRefusedAfterRegistration();
        return this.onERC721Received.selector;
    }
}

/// @notice Actual Core mutation path and actual Coordinator under the current 500,000 gas value.
/// @dev The Core subclass only exposes original hash/read workers. Registry, Manager, governance,
///      roles and provider are explicit typed boundaries. No actual-current full graph claim.
contract StreamEntropyRegistrationCapTest is CharacterizationTestBase, EntropyTimeAuthorityFixture {
    PermanentTargetCoreHarness private core;
    PermanentTargetModuleRegistry private registry;
    PermanentTargetMintManager private manager;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    bytes32 private constant MANIFEST = keccak256("registration-cap-fixture");
    bytes32 private constant CAP =
        0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17;
    bytes32 private constant COMMITMENT = keccak256("first actual registration");

    uint256 private registrationValue;

    function setUp() public {
        _deploy(500000);
    }

    function _deploy(uint256 value) private {
        registrationValue = value;
        vm.roll(100);
        registry = new PermanentTargetModuleRegistry();
        registry.setGovernanceExecutor(address(this));
        StreamCore.GasParameterGenesisConfig[] memory gas =
            new StreamCore.GasParameterGenesisConfig[](4);
        // Exact four current StreamCurrentStackPlan gas rows; only the explicit
        // floor-negative test substitutes the registration value. The final 2 is
        // failureClass; the constructor initializes revision 1.
        gas[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 100000, 25000, 1
        );
        gas[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7, 2910000, 1460000, 1
        );
        gas[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93, 12000000, 250000, 1
        );
        gas[3] = StreamCore.GasParameterGenesisConfig(CAP, value, 120000, 2);
        core = new PermanentTargetCoreHarness(
            "Stream",
            "STR",
            address(this),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, MANIFEST, MANIFEST
            ),
            gas
        );
        registry.setRecord(
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST,
            MANIFEST
        );
        manager = new PermanentTargetMintManager();
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                MANIFEST,
                "urn:cap-test",
                MANIFEST
            )
        );
        _install(keccak256("MINT_MANAGER"), address(manager), type(IStreamMintManager).interfaceId);
        _install(
            keccak256("ENTROPY_COORDINATOR"),
            address(entropy),
            type(IStreamEntropyCoordinator).interfaceId
        );
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        this.setCurrentAction(
            true,
            keccak256("create collection"),
            1,
            scope,
            keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0))),
            keccak256(abi.encode(domain, scope, true, uint8(2), uint8(0), false, uint256(0)))
        );
        core.createCollection(2, false, 0, 0);
        provider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(provider));
        entropy.configureCollection(1, address(provider), MANIFEST, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function _install(bytes32 kind, address target, bytes4 interfaceId) private {
        registry.setRecord(target, kind, interfaceId, MANIFEST, MANIFEST);
        StreamCorePointerState memory previous = core.pointerState(kind);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            target,
            target.codehash,
            false,
            kind,
            interfaceId,
            address(registry),
            uint8(ModuleRegistryStatus.ACTIVE),
            MANIFEST,
            MANIFEST,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            core.pointerTransitionHashes(kind, previous, candidate);
        this.setCurrentAction(true, keccak256(abi.encode("install", kind)), 3, scope, oldHash, next);
        core.updateSatellitePointer(kind, target);
    }

    function _cold() private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            core.gasParameterInfo(CAP);
        require(
            value == registrationValue && floor == 120000 && failureClass == 2 && revision == 1,
            "exact live GGP"
        );
        RegistrationColdVm cold = RegistrationColdVm(address(vm));
        // Named accounts and their storage only. Core's actual mint naturally warms the
        // new token identity/atMint cells before the bounded registration callback.
        cold.cool(address(core));
        cold.cool(address(entropy));
        cold.cool(address(manager));
        cold.cool(address(registry));
        cold.cool(address(StreamEntropyScopeRegistration));
        cold.cool(address(StreamCoreExternalReads));
    }

    function testFirstColdActualCoreRegistrationAtCurrent500kValue() public {
        _cold();
        (uint256 token, uint256 serial) =
            manager.mint(core, 1, address(0xBEEF), bytes("first"), COMMITMENT);
        require(token == 1 && serial == 1 && core.ownerOf(token) == address(0xBEEF));
        require(core.coordinatorAtMint(token) == address(entropy));
        require(entropy.tokenEntropyStatus(token) == StreamEntropyStatus.REGISTERED);
        require(entropy.registeredAtBlock(token) == 100 && entropy.nonterminalTokenCount(1) == 1);
        require(entropy.pendingRequestCount() == 0);
        (,, bool locked,,,,) = entropy.collectionEntropyConfig(1);
        require(locked);
    }

    function testLateReceiverRejectionRollsBackRegistrationThenIdenticalMintRetries() public {
        RegistrationCapReceiver receiver = new RegistrationCapReceiver();
        bytes memory data = bytes("receiver retry");
        _cold();
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistrationCapReceiver.ReceiverRefusedAfterRegistration.selector
            )
        );
        manager.mint(core, 1, address(receiver), data, COMMITMENT);
        _assertRegistrationRolledBack();
        receiver.allow();
        _cold();
        (uint256 token, uint256 serial) = manager.mint(core, 1, address(receiver), data, COMMITMENT);
        require(token == 1 && serial == 1 && core.ownerOf(token) == address(receiver));
        require(entropy.tokenEntropyStatus(token) == StreamEntropyStatus.REGISTERED);
        require(entropy.nonterminalTokenCount(1) == 1 && entropy.registeredAtBlock(1) == 100);
    }

    function testMinimum120kValueFailsClosedWithoutRegistrationOrMintState() public {
        _deploy(120000);
        _cold();
        vm.expectRevert(abi.encodeWithSelector(StreamCore.EntropyRegistrationFailed.selector));
        manager.mint(core, 1, address(0xBEEF), bytes("floor negative"), COMMITMENT);
        _assertRegistrationRolledBack();
    }

    function _assertRegistrationRolledBack() private view {
        require(core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1);
        require(core.coordinatorAtMint(1) == address(0) && core.tokenLifecycle(1) == 0);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE);
        require(entropy.registeredAtBlock(1) == 0 && entropy.nonterminalTokenCount(1) == 0);
        (,, bool locked,,,,) = entropy.collectionEntropyConfig(1);
        require(!locked);
        require(entropy.pendingRequestCount() == 0);
    }
}
