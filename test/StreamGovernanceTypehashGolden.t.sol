// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGovernanceExecutor.sol";
import "../smart-contracts/IStreamModule.sol";
import "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/StreamGovernanceExecutor.sol";
import "../smart-contracts/StreamModuleRegistry.sol";
import "../smart-contracts/StreamRoleRegistry.sol";
import "../smart-contracts/StreamRoles.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

/// @notice Golden equality tests for every doc-pinned governance and registry
///         hash domain, the [GOV-ROLES] keccak-of-own-name rule, the pinned
///         enum numeric IDs, and the [LTA-MODULE-ID] selector surface.
/// @dev Pinned 0x literals are copied from `docs/adr/0004-admin-governance.md`
///     [GOV-ACTION-ID], `docs/stream-long-term-architecture.md` [LTA-DOMAINS],
///     and `docs/collection-metadata-contract.md` [CMC-RECORD-CHAIN]; each is
///     asserted against both the deployed Solidity constant and a live keccak
///     recomputation of the exact string preimage.
contract StreamGovernanceTypehashGoldenTest is CharacterizationTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    bytes32 private constant PINNED_GOVERNANCE_ACTION_V1 =
        0xda01e91bb5de11674cef69c6774002280d75bcb43cd9c78413c4b94d5d14249b;
    bytes32 private constant PINNED_GOVERNANCE_CALLS_V1 =
        0x51c60c7ea5577cbf0c5157f544a7de1a186ae82b6fc4df6a626b9c8d1d3a0b61;
    bytes32 private constant PINNED_MODULE_REGISTRATION_RECORD_V1 =
        0x4b5b157069f454a5c1b78a95a28e2016af2d428d4eb4037917b271a668490869;
    bytes32 private constant PINNED_RECORD_CHAIN_V1 =
        0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609;

    StreamGovernanceExecutor private executor;
    StreamModuleRegistry private registry;

    function setUp() public {
        StreamRoleRegistry roleRegistry = new StreamRoleRegistry();
        executor = new StreamGovernanceExecutor(roleRegistry);
        registry =
            new StreamModuleRegistry(executor, keccak256("registry-manifest"), "ipfs://registry");
    }

    function testGovernanceActionTypehashGolden() public {
        executor.STREAM_GOVERNANCE_ACTION_V1()
            .assertEq(PINNED_GOVERNANCE_ACTION_V1, "action typehash vs doc pin");
        keccak256("6529STREAM_GOVERNANCE_ACTION_V1")
            .assertEq(PINNED_GOVERNANCE_ACTION_V1, "action preimage recompute");
    }

    function testGovernanceCallsTypehashGolden() public {
        executor.STREAM_GOVERNANCE_CALLS_V1()
            .assertEq(PINNED_GOVERNANCE_CALLS_V1, "calls typehash vs doc pin");
        keccak256("6529STREAM_GOVERNANCE_CALLS_V1")
            .assertEq(PINNED_GOVERNANCE_CALLS_V1, "calls preimage recompute");
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

    function testModuleRegistrationLaneConstants() public {
        registry.MODULE_REGISTRATION_RECORD_TYPE()
            .assertEq(keccak256("MODULE_REGISTRATION"), "registration lane record type");
        registry.MODULE_REGISTRATION_SCOPE_KEY().assertEq(0, "registration lane scope key");
    }

    function testGovernanceActionScheduledTopicGolden() public {
        executor.GOVERNANCE_ACTION_SCHEDULED_TOPIC()
            .assertEq(
                keccak256(
                    bytes(
                        string.concat(
                            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,",
                            "bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,",
                            "address,bytes32,string,bytes32)"
                        )
                    )
                ),
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
        uint256(executor.OPEN_TO_EXECUTE_WINDOW_FLOOR()).assertEq(7 days, "open-to-execute floor");
        uint256(executor.EMERGENCY_ASSUMPTION_LATENCY())
            .assertEq(4 hours, "emergency assumption latency");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.UnknownActionClass.selector, 6)
        );
        executor.minimumDelay(6);
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
