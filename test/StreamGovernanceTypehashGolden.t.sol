// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGovernanceExecutor.sol";
import "../smart-contracts/IStreamModule.sol";
import "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/StreamGovernanceExecutor.sol";
import "../smart-contracts/StreamModuleRegistry.sol";
import "../smart-contracts/StreamRoles.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

/// @notice Golden equality tests for every doc-pinned governance and registry
///         hash domain, the [GOV-ROLES] keccak-of-own-name rule, the pinned
///         enum numeric IDs, and the [LTA-MODULE-ID] selector surface.
/// @dev Pinned 0x literals are copied from `docs/adr/0004-admin-governance.md`
///     [GOV-ACTION-ID], `docs/stream-long-term-architecture.md` [LTA-DOMAINS],
///     and `docs/collection-metadata-contract.md` [CMC-RECORD-CHAIN]; each is
///     asserted against a live keccak recomputation of the exact string
///     preimage. These domains are catalog-pinned rather than contract ABI.
contract StreamGovernanceTypehashGoldenTest is CharacterizationTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    bytes32 private constant PINNED_GOVERNANCE_ACTION_V2 =
        0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b;
    bytes32 private constant PINNED_GOVERNANCE_CALLS_V2 =
        0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70;
    bytes32 private constant PINNED_MODULE_REGISTRATION_RECORD_V1 =
        0x4b5b157069f454a5c1b78a95a28e2016af2d428d4eb4037917b271a668490869;
    bytes32 private constant PINNED_RECORD_CHAIN_V1 =
        0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609;
    bytes32 private constant PINNED_ROLE_MUTATION_V1 =
        0xa8dba5d6fcfd6e5b3cd0487118fc42e1d598c9ba0fb59aefad69b419212bc91e;
    bytes32 private constant PINNED_GLOBAL_ROLE_MUTATION_V1 =
        0x2da8f94be4b1e85c976aae097d48589ff562492679ebc2842c866ba5b986d39c;
    bytes32 private constant PINNED_ROLE_MUTATION_SCOPE_V1 =
        0x51943e9f337cf7f50fc89b1f37701a670f4477d8d6e3efbd34d986b27f35d271;
    bytes32 private constant PINNED_ROLE_MUTATION_STATE_V1 =
        0xf80e0ae6730f5e4e48b5a6c1b46bfb06af297aefb0eaa569f87f095a7f99153d;
    bytes32 private constant PINNED_ROLE_MANAGER_CONFIG_V1 =
        0x6b7160b8472382fb5a6b7cad94720fd10007c4124b0b0d405aa6523763ad0fe7;
    bytes32 private constant PINNED_ROLE_MANAGER_CONFIG_STATE_V1 =
        0x00ef486fa9550ecdc9851c2df1073c1c991e7d56e6a0d388357ba5f5a89c4263;
    bytes32 private constant PINNED_ROLE_MANAGER_CONFIG_MUTATION_V1 =
        0xbd1ca24b4e56b656dee2d7ca30433716550c54ab67aab3e6b9eba46ac0ff79d6;

    StreamGovernanceExecutor private executor;
    StreamModuleRegistry private registry;

    function setUp() public {
        executor = new StreamGovernanceExecutor(address(this));
        registry =
            new StreamModuleRegistry(executor, keccak256("registry-manifest"), "ipfs://registry");
    }

    function testGovernanceActionTypehashGolden() public {
        keccak256("6529STREAM_GOVERNANCE_ACTION_V2")
            .assertEq(PINNED_GOVERNANCE_ACTION_V2, "action preimage recompute");
    }

    function testGovernanceCallsTypehashGolden() public {
        keccak256("6529STREAM_GOVERNANCE_CALLS_V2")
            .assertEq(PINNED_GOVERNANCE_CALLS_V2, "calls preimage recompute");
    }

    function testGovernanceV2DomainsAreNotContractGetters() public {
        bytes4[5] memory retiredGetters = [
            bytes4(0x5a7922a5),
            bytes4(0xe27ffa02),
            bytes4(0x4f87c81c),
            bytes4(0xe5427dd5),
            bytes4(0x0b1a9825)
        ];
        for (uint256 i = 0; i < retiredGetters.length; i++) {
            (bool success,) = address(executor).staticcall(abi.encodePacked(retiredGetters[i]));
            success.assertFalse("catalog domain must not spend executor ABI");
        }
    }

    function testGovernanceV2SelectorGoldens() public {
        bytes32(IStreamGovernanceExecutor.scheduleGovernanceBatch.selector)
            .assertEq(bytes32(bytes4(0x9c954144)), "schedule batch selector");
        bytes32(IStreamGovernanceExecutor.executeGovernanceBatch.selector)
            .assertEq(bytes32(bytes4(0x2eccc33e)), "execute batch selector");
        bytes32(IStreamGovernanceExecutor.currentAction.selector)
            .assertEq(bytes32(bytes4(0x546ea281)), "current action selector");
        bytes32(IStreamGovernanceExecutor.publishGovernanceCallData.selector)
            .assertEq(bytes32(bytes4(0x5447021f)), "publish calldata selector");
        bytes32(IStreamGovernanceExecutor.publishedCallData.selector)
            .assertEq(bytes32(bytes4(0x95a2b189)), "published calldata selector");
        bytes32(IStreamGovernanceExecutor.scheduledCallDataPointer.selector)
            .assertEq(bytes32(bytes4(0x38f8ce24)), "scheduled pointer selector");
        bytes32(IStreamGovernanceExecutor.scheduledCallData.selector)
            .assertEq(bytes32(bytes4(0x72a3c7b8)), "scheduled data selector");
    }

    function testManifestAndEmergencySelectorGoldens() public {
        bytes32(IStreamGovernanceExecutor.systemManifestBatchTailRule.selector)
            .assertEq(bytes32(bytes4(0xffd6babe)), "tail rule selector");
        bytes32(IStreamGovernanceExecutor.registerSystemManifestTailTrigger.selector)
            .assertEq(bytes32(bytes4(0xc64f0807)), "register tail selector");
        bytes32(IStreamGovernanceExecutor.systemManifestTailTriggerCount.selector)
            .assertEq(bytes32(bytes4(0xeee99df8)), "tail count selector");
        bytes32(IStreamGovernanceExecutor.systemManifestTailTriggerAt.selector)
            .assertEq(bytes32(bytes4(0xd83d70b6)), "tail at selector");
        bytes32(IStreamGovernanceExecutor.systemManifestTailTriggerChainHash.selector)
            .assertEq(bytes32(bytes4(0xa05cac72)), "tail chain selector");
        bytes32(IStreamGovernanceExecutor.bindSystemManifestBootstrap.selector)
            .assertEq(bytes32(bytes4(0x32212927)), "bootstrap bind selector");
        bytes32(IStreamGovernanceExecutor.pendingScheduledActionCount.selector)
            .assertEq(bytes32(bytes4(0x20662991)), "pending count selector");
        bytes32(IStreamGovernanceExecutor.systemManifestBootstrapState.selector)
            .assertEq(bytes32(bytes4(0x8a2d979b)), "bootstrap state selector");
        bytes32(IStreamGovernanceExecutor.sealSystemManifestBootstrap.selector)
            .assertEq(bytes32(bytes4(0xbd1f39cd)), "bootstrap seal selector");
        bytes32(IStreamGovernanceExecutor.emergencyRestorationEligibility.selector)
            .assertEq(bytes32(bytes4(0xf23a1e43)), "emergency eligibility selector");
        bytes32(IStreamGovernanceExecutor.registerEmergencyRestorationEligibility.selector)
            .assertEq(bytes32(bytes4(0x9e842aea)), "register emergency selector");
        bytes32(IStreamGovernanceExecutor.emergencyRestorationEligibilityCount.selector)
            .assertEq(bytes32(bytes4(0xffd0e631)), "emergency count selector");
        bytes32(IStreamGovernanceExecutor.emergencyRestorationEligibilityAt.selector)
            .assertEq(bytes32(bytes4(0xe249cded)), "emergency at selector");
        bytes32(IStreamGovernanceExecutor.emergencyRestorationEligibilityChainHash.selector)
            .assertEq(bytes32(bytes4(0x927836c4)), "emergency chain selector");
    }

    function testV1DomainGettersAreRetired() public {
        (bool callsV1,) = address(executor).staticcall(hex"48634e0d");
        (bool actionV1,) = address(executor).staticcall(hex"5cf9f49e");
        callsV1.assertFalse("calls V1 getter retired");
        actionV1.assertFalse("action V1 getter retired");
    }

    function testModuleRegistrationRecordTypehashGolden() public {
        registry.STREAM_MODULE_REGISTRATION_RECORD_V1()
            .assertEq(
                PINNED_MODULE_REGISTRATION_RECORD_V1, "registration record typehash vs doc pin"
            );
        keccak256("6529STREAM_MODULE_REGISTRATION_RECORD_V1")
            .assertEq(
                PINNED_MODULE_REGISTRATION_RECORD_V1, "registration record preimage recompute"
            );
    }

    function testRecordChainTypehashGolden() public {
        registry.STREAM_RECORD_CHAIN_V1()
            .assertEq(PINNED_RECORD_CHAIN_V1, "record chain typehash vs doc pin");
        keccak256("6529STREAM_RECORD_CHAIN_V1")
            .assertEq(PINNED_RECORD_CHAIN_V1, "record chain preimage recompute");
    }

    function testRoleRegistryDomainGoldens() public {
        keccak256("6529STREAM_ROLE_MUTATION_V1")
            .assertEq(PINNED_ROLE_MUTATION_V1, "role mutation preimage recompute");
        keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1")
            .assertEq(PINNED_GLOBAL_ROLE_MUTATION_V1, "global role mutation preimage recompute");
        keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1")
            .assertEq(PINNED_ROLE_MUTATION_SCOPE_V1, "role scope preimage recompute");
        keccak256("6529STREAM_ROLE_MUTATION_STATE_V1")
            .assertEq(PINNED_ROLE_MUTATION_STATE_V1, "role state preimage recompute");
        keccak256("6529STREAM_ROLE_MANAGER_CONFIG_V1")
            .assertEq(PINNED_ROLE_MANAGER_CONFIG_V1, "role manager key preimage recompute");
        keccak256("6529STREAM_ROLE_MANAGER_CONFIG_STATE_V1")
            .assertEq(PINNED_ROLE_MANAGER_CONFIG_STATE_V1, "role manager state preimage recompute");
        keccak256("6529STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1")
            .assertEq(
                PINNED_ROLE_MANAGER_CONFIG_MUTATION_V1, "role manager mutation preimage recompute"
            );
    }

    function testModuleRegistrationLaneConstants() public {
        registry.MODULE_REGISTRATION_RECORD_TYPE()
            .assertEq(keccak256("MODULE_REGISTRATION"), "registration lane record type");
        registry.MODULE_REGISTRATION_SCOPE_KEY().assertEq(0, "registration lane scope key");
    }

    function testGovernanceActionScheduledTopicGolden() public {
        keccak256(
                bytes(
                    string.concat(
                        "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,",
                        "bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,",
                        "address,bytes32,string,bytes32)"
                    )
                )
            )
            .assertEq(
                0x31024a726b55cea4cbdba5c85421828889c7015fdc195fafed46fed8020f760c,
                "scheduled event topic"
            );
    }

    function testRoleConstantsAreKeccakOfOwnName() public {
        StreamRoles.ROLE_PAUSE_GUARDIAN
            .assertEq(keccak256("ROLE_PAUSE_GUARDIAN"), "ROLE_PAUSE_GUARDIAN");
        StreamRoles.ROLE_UNPAUSE.assertEq(keccak256("ROLE_UNPAUSE"), "ROLE_UNPAUSE");
        StreamRoles.ROLE_COLLECTION_FINALITY_ADMIN
            .assertEq(keccak256("ROLE_COLLECTION_FINALITY_ADMIN"), "ROLE_COLLECTION_FINALITY_ADMIN");
        StreamRoles.ROLE_TERMINAL_FREEZE_VETO
            .assertEq(keccak256("ROLE_TERMINAL_FREEZE_VETO"), "ROLE_TERMINAL_FREEZE_VETO");
        StreamRoles.ROLE_ENTROPY_INCIDENT_DECLARER
            .assertEq(keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), "ROLE_ENTROPY_INCIDENT_DECLARER");
        StreamRoles.ROLE_ENTROPY_REVEAL_OWNER
            .assertEq(keccak256("ROLE_ENTROPY_REVEAL_OWNER"), "ROLE_ENTROPY_REVEAL_OWNER");
        StreamRoles.ROLE_ARTIST_REGISTRY_ADMIN
            .assertEq(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), "ROLE_ARTIST_REGISTRY_ADMIN");
        StreamRoles.ROLE_ATTRIBUTION_ARBITER
            .assertEq(keccak256("ROLE_ATTRIBUTION_ARBITER"), "ROLE_ATTRIBUTION_ARBITER");
        StreamRoles.ROLE_ARTIST_DORMANCY_ADMIN
            .assertEq(keccak256("ROLE_ARTIST_DORMANCY_ADMIN"), "ROLE_ARTIST_DORMANCY_ADMIN");
        StreamRoles.ROLE_ATTRIBUTION_APPEAL
            .assertEq(keccak256("ROLE_ATTRIBUTION_APPEAL"), "ROLE_ATTRIBUTION_APPEAL");
        StreamRoles.ROLE_FIXITY_OPERATOR
            .assertEq(keccak256("ROLE_FIXITY_OPERATOR"), "ROLE_FIXITY_OPERATOR");
        StreamRoles.ROLE_EXPORT_PUBLISHER
            .assertEq(keccak256("ROLE_EXPORT_PUBLISHER"), "ROLE_EXPORT_PUBLISHER");
        StreamRoles.ROLE_CLAIM_ROUTER_OPERATOR
            .assertEq(keccak256("ROLE_CLAIM_ROUTER_OPERATOR"), "ROLE_CLAIM_ROUTER_OPERATOR");
        StreamRoles.ROLE_EMERGENCY_RECIPIENT
            .assertEq(keccak256("ROLE_EMERGENCY_RECIPIENT"), "ROLE_EMERGENCY_RECIPIENT");
        StreamRoles.ROLE_ENTROPY_ADMIN
            .assertEq(keccak256("ROLE_ENTROPY_ADMIN"), "ROLE_ENTROPY_ADMIN");
        StreamRoles.ROLE_TREASURY.assertEq(keccak256("ROLE_TREASURY"), "ROLE_TREASURY");
    }

    function testModuleRegistryStatusNumericPins() public {
        // Pinned in the Numeric ID Catalog ([LTA-REGISTRY] requirement 2).
        uint256(uint8(ModuleRegistryStatus.UNKNOWN)).assertEq(0, "UNKNOWN = 0");
        uint256(uint8(ModuleRegistryStatus.ACTIVE)).assertEq(1, "ACTIVE = 1");
        uint256(uint8(ModuleRegistryStatus.DEPRECATED)).assertEq(2, "DEPRECATED = 2");
        uint256(uint8(ModuleRegistryStatus.INCIDENT_REVOKED)).assertEq(3, "INCIDENT_REVOKED = 3");
    }

    function testGovernanceActionStatusOrderPins() public {
        uint256(uint8(GovernanceActionStatus.NONE)).assertEq(0, "NONE = 0");
        uint256(uint8(GovernanceActionStatus.SCHEDULED)).assertEq(1, "SCHEDULED = 1");
        uint256(uint8(GovernanceActionStatus.CANCELLED)).assertEq(2, "CANCELLED = 2");
        uint256(uint8(GovernanceActionStatus.EXECUTED)).assertEq(3, "EXECUTED = 3");
        uint256(uint8(GovernanceActionStatus.EXPIRED)).assertEq(4, "EXPIRED = 4");
        uint256(uint8(GovernanceActionStatus.VETOED)).assertEq(5, "VETOED = 5");
    }

    function testActionClassNumericPins() public {
        uint256(StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING)
            .assertEq(0, "IMMEDIATE_TIGHTENING = 0");
        uint256(StreamGovernanceActionClasses.DELAYED_LOOSENING)
            .assertEq(1, "DELAYED_LOOSENING = 1");
        uint256(StreamGovernanceActionClasses.TERMINAL_FREEZE).assertEq(2, "TERMINAL_FREEZE = 2");
        uint256(StreamGovernanceActionClasses.POINTER_REPLACEMENT)
            .assertEq(3, "POINTER_REPLACEMENT = 3");
        uint256(StreamGovernanceActionClasses.FUNDS_RECOVERY).assertEq(4, "FUNDS_RECOVERY = 4");
        uint256(StreamGovernanceActionClasses.SUCCESSOR_DECLARATION)
            .assertEq(5, "SUCCESSOR_DECLARATION = 5");
        uint256(StreamGovernanceActionClasses.EMERGENCY_RESTORATION)
            .assertEq(6, "EMERGENCY_RESTORATION = 6");
    }

    function testGovernanceWindowFloorConstants() public {
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING))
            .assertEq(0, "immediate tightening delay");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.DELAYED_LOOSENING))
            .assertEq(48 hours, "delayed loosening floor");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.POINTER_REPLACEMENT))
            .assertEq(48 hours, "pointer replacement floor");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.TERMINAL_FREEZE))
            .assertEq(72 hours, "terminal freeze veto floor");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.FUNDS_RECOVERY))
            .assertEq(14 days, "funds recovery floor");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.SUCCESSOR_DECLARATION))
            .assertEq(30 days, "successor declaration floor");
        uint256(7 days).assertEq(604_800, "open-to-execute floor catalog pin");
        uint256(4 hours).assertEq(14_400, "emergency assumption latency catalog pin");
        uint256(executor.minimumDelay(StreamGovernanceActionClasses.EMERGENCY_RESTORATION))
            .assertEq(0, "emergency restoration delay");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.UnknownActionClass.selector, 7)
        );
        executor.minimumDelay(7);
    }

    function testStreamModuleSelectorGolden() public {
        // [LTA-MODULE-ID]: the eight canonical selectors are golden-tested.
        bytes32(IStreamModule.streamModuleType.selector)
            .assertEq(bytes32(bytes4(keccak256("streamModuleType()"))), "streamModuleType selector");
        bytes32(IStreamModule.streamModuleVersion.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleVersion()"))), "streamModuleVersion selector"
            );
        bytes32(IStreamModule.streamModuleInterfaceId.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleInterfaceId()"))),
                "streamModuleInterfaceId selector"
            );
        bytes32(IStreamModule.streamModuleSchemaHash.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleSchemaHash()"))),
                "streamModuleSchemaHash selector"
            );
        bytes32(IStreamModule.streamModuleSupersedes.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleSupersedes()"))),
                "streamModuleSupersedes selector"
            );
        bytes32(IStreamModule.streamModuleCodeHash.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleCodeHash()"))),
                "streamModuleCodeHash selector"
            );
        bytes32(IStreamModule.streamModuleDeploymentManifestHash.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleDeploymentManifestHash()"))),
                "streamModuleDeploymentManifestHash selector"
            );
        bytes32(IStreamModule.streamModuleManifest.selector)
            .assertEq(
                bytes32(bytes4(keccak256("streamModuleManifest()"))),
                "streamModuleManifest selector"
            );
    }
}
