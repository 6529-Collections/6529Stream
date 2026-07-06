// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamRoleRegistry.sol";
import "../smart-contracts/StreamRoleRegistry.sol";
import "../smart-contracts/StreamRoles.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

contract RoleHolderContractMock {
    // Deployed-code holder used by the [GOV-WINDOWS] rule 2 redundancy views.
    function ping() external pure returns (bool) {
        return true;
    }
}

contract StreamRoleRegistryTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    event StreamRoleGranted(
        uint16 schemaVersion,
        bytes32 indexed role,
        address indexed holder,
        uint8 grantClass,
        address indexed actor
    );

    event StreamRoleRevoked(
        uint16 schemaVersion,
        bytes32 indexed role,
        address indexed holder,
        uint8 grantClass,
        address indexed actor
    );

    StreamRoleRegistry private registry;

    address private roleManager = address(0x40A6);
    address private holder = address(0x101D);
    address private secondHolder = address(0x201D);
    address private stranger = address(0x5719);

    function setUp() public {
        registry = new StreamRoleRegistry();
        registry.registerRoleManager(roleManager, true);
    }

    function testGrantClassVocabulary() public {
        // Root-class rows of the [GOV-ROLES] table.
        _assertRoot(StreamRoles.ROLE_PAUSE_GUARDIAN, "ROLE_PAUSE_GUARDIAN");
        _assertRoot(StreamRoles.ROLE_UNPAUSE, "ROLE_UNPAUSE");
        _assertRoot(StreamRoles.ROLE_COLLECTION_FINALITY_ADMIN, "ROLE_COLLECTION_FINALITY_ADMIN");
        _assertRoot(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, "ROLE_TERMINAL_FREEZE_VETO");
        _assertRoot(StreamRoles.ROLE_ATTRIBUTION_ARBITER, "ROLE_ATTRIBUTION_ARBITER");
        _assertRoot(StreamRoles.ROLE_ARTIST_DORMANCY_ADMIN, "ROLE_ARTIST_DORMANCY_ADMIN");
        _assertRoot(StreamRoles.ROLE_ATTRIBUTION_APPEAL, "ROLE_ATTRIBUTION_APPEAL");
        _assertRoot(StreamRoles.ROLE_EMERGENCY_RECIPIENT, "ROLE_EMERGENCY_RECIPIENT");
        _assertRoot(StreamRoles.ROLE_TREASURY, "ROLE_TREASURY");
        // Operational-class rows.
        _assertOperational(
            StreamRoles.ROLE_ENTROPY_INCIDENT_DECLARER, "ROLE_ENTROPY_INCIDENT_DECLARER"
        );
        _assertOperational(StreamRoles.ROLE_ENTROPY_REVEAL_OWNER, "ROLE_ENTROPY_REVEAL_OWNER");
        _assertOperational(StreamRoles.ROLE_ARTIST_REGISTRY_ADMIN, "ROLE_ARTIST_REGISTRY_ADMIN");
        _assertOperational(StreamRoles.ROLE_FIXITY_OPERATOR, "ROLE_FIXITY_OPERATOR");
        _assertOperational(StreamRoles.ROLE_EXPORT_PUBLISHER, "ROLE_EXPORT_PUBLISHER");
        _assertOperational(StreamRoles.ROLE_CLAIM_ROUTER_OPERATOR, "ROLE_CLAIM_ROUTER_OPERATOR");
        _assertOperational(StreamRoles.ROLE_ENTROPY_ADMIN, "ROLE_ENTROPY_ADMIN");
    }

    function _assertRoot(bytes32 role, string memory label) private {
        registry.isKnownRole(role).assertTrue(label);
        uint256(registry.roleGrantClass(role))
            .assertEq(uint256(StreamRoles.GRANT_CLASS_ROOT), label);
    }

    function _assertOperational(bytes32 role, string memory label) private {
        registry.isKnownRole(role).assertTrue(label);
        uint256(registry.roleGrantClass(role))
            .assertEq(uint256(StreamRoles.GRANT_CLASS_OPERATIONAL), label);
    }

    function testUnknownRoleIsClosedWorld() public {
        bytes32 madeUp = keccak256("ROLE_MADE_UP");
        registry.isKnownRole(madeUp).assertFalse("made-up role unknown");
        vm.expectRevert(abi.encodeWithSelector(IStreamRoleRegistry.UnknownRole.selector, madeUp));
        registry.grantRole(madeUp, holder);
        vm.expectRevert(abi.encodeWithSelector(IStreamRoleRegistry.UnknownRole.selector, madeUp));
        registry.roleGrantClass(madeUp);
    }

    function testRootRoleGrantAuthority() public {
        // Owner grants and the event carries the grant class.
        vm.expectEmit(true, true, true, true);
        emit StreamRoleGranted(
            1, StreamRoles.ROLE_TREASURY, holder, StreamRoles.GRANT_CLASS_ROOT, address(this)
        );
        registry.grantRole(StreamRoles.ROLE_TREASURY, holder);
        registry.hasRole(StreamRoles.ROLE_TREASURY, holder).assertTrue("root role granted");

        // Role managers cannot grant root-class roles.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleActorNotAuthorized.selector,
                StreamRoles.ROLE_TREASURY,
                roleManager
            )
        );
        vm.prank(roleManager);
        registry.grantRole(StreamRoles.ROLE_TREASURY, secondHolder);

        // Nor can they revoke them.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleActorNotAuthorized.selector,
                StreamRoles.ROLE_TREASURY,
                roleManager
            )
        );
        vm.prank(roleManager);
        registry.revokeRole(StreamRoles.ROLE_TREASURY, holder);
    }

    function testOperationalRoleGrantAuthority() public {
        // Role manager grants operational-class roles.
        vm.prank(roleManager);
        registry.grantRole(StreamRoles.ROLE_EXPORT_PUBLISHER, holder);
        registry.hasRole(StreamRoles.ROLE_EXPORT_PUBLISHER, holder)
            .assertTrue("operational role granted by manager");

        // Strangers cannot.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleActorNotAuthorized.selector,
                StreamRoles.ROLE_EXPORT_PUBLISHER,
                stranger
            )
        );
        vm.prank(stranger);
        registry.grantRole(StreamRoles.ROLE_EXPORT_PUBLISHER, secondHolder);

        // Manager revoke works and events.
        vm.expectEmit(true, true, true, true);
        emit StreamRoleRevoked(
            1,
            StreamRoles.ROLE_EXPORT_PUBLISHER,
            holder,
            StreamRoles.GRANT_CLASS_OPERATIONAL,
            roleManager
        );
        vm.prank(roleManager);
        registry.revokeRole(StreamRoles.ROLE_EXPORT_PUBLISHER, holder);
        registry.hasRole(StreamRoles.ROLE_EXPORT_PUBLISHER, holder).assertFalse("revoked");
    }

    function testGrantValidation() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.ZeroRoleHolder.selector, StreamRoles.ROLE_TREASURY
            )
        );
        registry.grantRole(StreamRoles.ROLE_TREASURY, address(0));

        registry.grantRole(StreamRoles.ROLE_TREASURY, holder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleAlreadyGranted.selector, StreamRoles.ROLE_TREASURY, holder
            )
        );
        registry.grantRole(StreamRoles.ROLE_TREASURY, holder);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleNotGranted.selector, StreamRoles.ROLE_TREASURY, secondHolder
            )
        );
        registry.revokeRole(StreamRoles.ROLE_TREASURY, secondHolder);
    }

    function testHolderEnumerationSwapRemove() public {
        address third = address(0x301D);
        registry.grantRole(StreamRoles.ROLE_TREASURY, holder);
        registry.grantRole(StreamRoles.ROLE_TREASURY, secondHolder);
        registry.grantRole(StreamRoles.ROLE_TREASURY, third);
        registry.roleHolderCount(StreamRoles.ROLE_TREASURY).assertEq(3, "three holders");
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 0).assertEq(holder, "index 0");
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 1).assertEq(secondHolder, "index 1");
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 2).assertEq(third, "index 2");

        // Swap-remove keeps the enumeration dense and index-consistent.
        registry.revokeRole(StreamRoles.ROLE_TREASURY, holder);
        registry.roleHolderCount(StreamRoles.ROLE_TREASURY).assertEq(2, "two holders");
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 0).assertEq(third, "moved holder");
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 1).assertEq(secondHolder, "stable");
        registry.hasRole(StreamRoles.ROLE_TREASURY, holder).assertFalse("revoked gone");
        registry.hasRole(StreamRoles.ROLE_TREASURY, third).assertTrue("moved still holds");

        // Re-grant and re-revoke through the moved index stays consistent.
        registry.revokeRole(StreamRoles.ROLE_TREASURY, third);
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 0).assertEq(secondHolder, "compacted");

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleHolderIndexOutOfBounds.selector,
                StreamRoles.ROLE_TREASURY,
                1
            )
        );
        registry.roleHolderAt(StreamRoles.ROLE_TREASURY, 1);
    }

    function testResolveRoleRequiresExactlyOneHolder() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleUnresolved.selector, StreamRoles.ROLE_TREASURY
            )
        );
        registry.resolveRole(StreamRoles.ROLE_TREASURY);

        registry.grantRole(StreamRoles.ROLE_TREASURY, holder);
        registry.resolveRole(StreamRoles.ROLE_TREASURY).assertEq(holder, "single holder");

        registry.grantRole(StreamRoles.ROLE_TREASURY, secondHolder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.AmbiguousRoleResolution.selector, StreamRoles.ROLE_TREASURY, 2
            )
        );
        registry.resolveRole(StreamRoles.ROLE_TREASURY);
    }

    function testEmergencyRecipientResolvesThroughRegistry() public {
        // ADR 0004 [GOV-ROLES]: never a stored raw address; unset resolution
        // reverts instead of defaulting to a deployer or owner.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleUnresolved.selector, StreamRoles.ROLE_EMERGENCY_RECIPIENT
            )
        );
        registry.emergencyRecipient();

        registry.grantRole(StreamRoles.ROLE_EMERGENCY_RECIPIENT, holder);
        registry.emergencyRecipient().assertEq(holder, "resolved through role registry");

        // Rotation is a role mutation, not an address write.
        registry.revokeRole(StreamRoles.ROLE_EMERGENCY_RECIPIENT, holder);
        registry.grantRole(StreamRoles.ROLE_EMERGENCY_RECIPIENT, secondHolder);
        registry.emergencyRecipient().assertEq(secondHolder, "rotated holder");
    }

    function testPauseUnpauseDisjointness() public {
        // [GOV-WINDOWS] rule 3: pause guardians cannot unpause and unpause
        // holders cannot pause.
        registry.grantRole(StreamRoles.ROLE_PAUSE_GUARDIAN, holder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.DisjointRoleConflict.selector,
                StreamRoles.ROLE_UNPAUSE,
                StreamRoles.ROLE_PAUSE_GUARDIAN,
                holder
            )
        );
        registry.grantRole(StreamRoles.ROLE_UNPAUSE, holder);

        registry.grantRole(StreamRoles.ROLE_UNPAUSE, secondHolder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.DisjointRoleConflict.selector,
                StreamRoles.ROLE_PAUSE_GUARDIAN,
                StreamRoles.ROLE_UNPAUSE,
                secondHolder
            )
        );
        registry.grantRole(StreamRoles.ROLE_PAUSE_GUARDIAN, secondHolder);
    }

    function testRoleRedundancyViews() public {
        bytes32 role = StreamRoles.ROLE_PAUSE_GUARDIAN;
        (uint256 count, uint256 contractCount) = registry.roleRedundancy(role);
        count.assertEq(0, "no holders yet");
        contractCount.assertEq(0, "no contract holders yet");
        registry.isRoleRedundant(role).assertFalse("empty role not redundant");

        // Two EOA-class holders fail the no-single-signer-EOA requirement.
        registry.grantRole(role, holder);
        registry.grantRole(role, secondHolder);
        (count, contractCount) = registry.roleRedundancy(role);
        count.assertEq(2, "two holders");
        contractCount.assertEq(0, "no code observed");
        registry.isRoleRedundant(role).assertFalse("EOA holders not redundant");

        // Two independently controlled contract holders satisfy the floor.
        registry.revokeRole(role, holder);
        registry.revokeRole(role, secondHolder);
        RoleHolderContractMock safeA = new RoleHolderContractMock();
        RoleHolderContractMock safeB = new RoleHolderContractMock();
        registry.grantRole(role, address(safeA));
        (uint256 oneCount, uint256 oneContract) = registry.roleRedundancy(role);
        oneCount.assertEq(1, "one holder");
        oneContract.assertEq(1, "one contract holder");
        registry.isRoleRedundant(role).assertFalse("single holder not redundant");

        registry.grantRole(role, address(safeB));
        registry.isRoleRedundant(role).assertTrue("two contract holders redundant");

        // A mixed set with any code-less holder fails.
        registry.grantRole(role, holder);
        registry.isRoleRedundant(role).assertFalse("mixed set with EOA fails");
    }

    function testRoleManagerRegistration() public {
        registry.isRoleManager(roleManager).assertTrue("manager registered");
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(stranger);
        registry.registerRoleManager(stranger, true);

        registry.registerRoleManager(roleManager, false);
        registry.isRoleManager(roleManager).assertFalse("manager removed");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleActorNotAuthorized.selector,
                StreamRoles.ROLE_EXPORT_PUBLISHER,
                roleManager
            )
        );
        vm.prank(roleManager);
        registry.grantRole(StreamRoles.ROLE_EXPORT_PUBLISHER, holder);
    }

    // ------------------------------------------- FIX B: per-scope veto roles

    function testScopableRoleVocabularyIsClosed() public {
        // Only ROLE_TERMINAL_FREEZE_VETO is scopable today.
        registry.isScopableRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO)
            .assertTrue("terminal-freeze veto scopable");
        registry.isScopableRole(StreamRoles.ROLE_TREASURY).assertFalse("treasury not scopable");
        registry.isScopableRole(StreamRoles.ROLE_PAUSE_GUARDIAN)
            .assertFalse("pause guardian not scopable");
    }

    function testScopedRoleDerivationAndGrant() public {
        bytes32 scope = keccak256("freeze-scope");
        bytes32 derived = registry.scopedRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope);
        derived.assertEq(
            keccak256(abi.encode(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope)),
            "scoped role derivation"
        );

        // A closed-world direct grant of the derived key reverts (it is not a
        // base vocabulary member); the scoped API is the only path.
        vm.expectRevert(abi.encodeWithSelector(IStreamRoleRegistry.UnknownRole.selector, derived));
        registry.grantRole(derived, holder);

        // Root-class scoped grant is owner-only.
        registry.grantScopedRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope, holder);
        registry.hasRole(derived, holder).assertTrue("scoped role granted");
        registry.roleHolderCount(derived).assertEq(1, "scoped holder count");
        registry.roleHolderAt(derived, 0).assertEq(holder, "scoped holder enumerated");

        // A different scope is a distinct role.
        registry.hasRole(
                registry.scopedRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, keccak256("other")),
                holder
            ).assertFalse("other scope not granted");

        // Revoke through the scoped API.
        registry.revokeScopedRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope, holder);
        registry.hasRole(derived, holder).assertFalse("scoped role revoked");
    }

    function testScopedGrantRejectsNonScopableBaseAndUnauthorized() public {
        bytes32 scope = keccak256("scope");
        // Non-scopable base reverts UnknownRole.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.UnknownRole.selector, StreamRoles.ROLE_TREASURY
            )
        );
        registry.grantScopedRole(StreamRoles.ROLE_TREASURY, scope, holder);

        // Root-class scoped grants are owner-only: a role manager cannot.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleActorNotAuthorized.selector,
                StreamRoles.ROLE_TERMINAL_FREEZE_VETO,
                roleManager
            )
        );
        vm.prank(roleManager);
        registry.grantScopedRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope, holder);
    }
}
