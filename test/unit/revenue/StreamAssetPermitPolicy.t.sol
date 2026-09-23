// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockStreamPaymentToken.sol";

/// @dev Authority-context unit seam. Actual Executor scheduling remains an integration test.
contract PermitPolicySafeAuthority is MockGovernedParameterAuthority {
    address public immutable controller;

    constructor(address controller_) MockGovernedParameterAuthority(true) {
        controller = controller_;
    }

    function execute(address target, bytes calldata data) external {
        require(msg.sender == controller, "controller");
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }
}

contract StreamAssetPermitPolicyTest is RevenueV1TestBase, OfficialSafeFixture {
    StreamAssetPolicyRegistry private policy;
    MockStreamPaymentToken private token;
    // Code identity only: this suite attests a target, not Permit2 behavior.
    MockStreamPaymentToken private permitTarget;
    uint256 private actionNonce = 100;

    function setUp() public {
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        token = new MockStreamPaymentToken();
        permitTarget = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("asset-reviewed"), 0);
    }

    function testExactAttestationAndVersionedEvent() public {
        vm.recordLogs();
        _set(3, 2, address(permitTarget), address(permitTarget).codehash);
        IStreamAssetPermitPolicy.AssetPermitPolicy memory p =
            policy.assetPermitPolicy(address(token));
        require(p.capabilities == 3 && p.permit2AllowanceMode == 2, "capabilities");
        require(
            p.permit2 == address(permitTarget)
                && p.permit2CodeHash == address(permitTarget).codehash,
            "permit identity"
        );
        require(p.assetCodeHash == address(token).codehash, "asset runtime");
        require(
            p.assetPolicyHash == keccak256("asset-reviewed") && p.assetPolicyRevision == 1,
            "policy binding"
        );
        require(
            p.revision == 1 && policy.assetPolicyRevision(address(token)) == 1,
            "independent revisions"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(policy), "one event");
        require(
            logs[0].topics[0]
                == keccak256("AssetPermitPolicyUpdated(address,bytes32,uint16,uint64,bytes32)"),
            "event ABI"
        );
        require(logs[0].topics[1] == bytes32(uint256(uint160(address(token)))), "asset topic");
        require(logs[0].topics[2] == keccak256(abi.encode(p)), "exact attestation topic");
        (uint16 schema, uint64 revision, bytes32 id) =
            abi.decode(logs[0].data, (uint16, uint64, bytes32));
        require(schema == 1 && revision == 1 && id == bytes32(actionNonce), "event data");
    }

    function testIndependentSemanticHashReconstruction() public view {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), 1, 0, address(0), bytes32(0));
        bytes32 expectedScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ASSET_PERMIT_SCOPE_V1"),
                block.chainid,
                address(policy),
                address(token)
            )
        );
        IStreamAssetPermitPolicy.AssetPermitPolicy memory empty;
        IStreamAssetPermitPolicy.AssetPermitPolicy memory proposed =
            IStreamAssetPermitPolicy.AssetPermitPolicy(
                1,
                0,
                address(0),
                bytes32(0),
                address(token).codehash,
                keccak256("asset-reviewed"),
                1,
                1
            );
        require(scope == expectedScope, "scope preimage");
        require(
            oldState
                == keccak256(
                    abi.encode(keccak256("6529STREAM_ASSET_PERMIT_STATE_V1"), scope, empty)
                ),
            "old preimage"
        );
        require(
            newState
                == keccak256(
                    abi.encode(keccak256("6529STREAM_ASSET_PERMIT_STATE_V1"), scope, proposed)
                ),
            "new preimage"
        );
    }

    function testUnauthorizedCallerAndWrongActionClassReject() public {
        _prepare(1, 0, address(0), 0, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.AssetPolicyNotAuthority.selector, address(this)
            )
        );
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
        _prepare(1, 0, address(0), 0, 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPermitPolicy.InvalidAssetPermitPolicyAction.selector)
        );
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
        require(policy.assetPermitPolicy(address(token)).revision == 0, "no unauthorized revision");
    }

    function testScheduledAssetRuntimeDriftRejects() public {
        _prepare(1, 0, address(0), 0, 1);
        vm.etch(address(token), hex"60006000f3");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPermitPolicy.InvalidAssetPermitPolicyAction.selector)
        );
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
    }

    function testScheduledPolicyRevisionDriftRejectsEvenAfterABA() public {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), 1, 0, address(0), 0);
        _setAssetPolicy(policy, address(token), 2, keccak256("asset-reviewed"), 0);
        _setAssetPolicy(policy, address(token), 1, keccak256("asset-reviewed"), 0);
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), 1, scope, oldState, newState
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPermitPolicy.InvalidAssetPermitPolicyAction.selector)
        );
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
    }

    function testExistingAttestationBecomesStaleAndRequiresReattestation() public {
        _set(1, 0, address(0), 0);
        _setAssetPolicy(policy, address(token), 1, keccak256("new-asset-review"), 0);
        require(
            policy.assetPermitPolicy(address(token)).assetPolicyRevision == 1, "no silent renewal"
        );
        require(policy.assetPolicyRevision(address(token)) == 2, "asset updated");
        _set(1, 0, address(0), 0);
        IStreamAssetPermitPolicy.AssetPermitPolicy memory p =
            policy.assetPermitPolicy(address(token));
        require(
            p.revision == 2 && p.assetPolicyRevision == 2
                && p.assetPolicyHash == keccak256("new-asset-review"),
            "explicit renewed binding"
        );
    }

    function testRevocationWorksWhileDeprecatedAndDoesNotShortenExitGrace() public {
        _set(3, 1, address(permitTarget), address(permitTarget).codehash);
        uint64 grace = uint64(block.timestamp + 180 days);
        _setAssetPolicy(policy, address(token), 3, keccak256("retirement"), grace);
        _set(0, 0, address(0), 0);
        IStreamAssetPermitPolicy.AssetPermitPolicy memory p =
            policy.assetPermitPolicy(address(token));
        require(
            p.capabilities == 0 && p.permit2 == address(0) && p.permit2CodeHash == 0,
            "revoked target"
        );
        require(p.revision == 2 && policy.assetStatus(address(token)) == 3, "independent records");
        require(policy.assetReleaseGraceUntil(address(token)) == grace, "exit unchanged");
    }

    function testNoopAndActionReplayCannotAdvanceRevision() public {
        _set(1, 0, address(0), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPermitPolicy.AssetPermitPolicyUnchanged.selector, address(token)
            )
        );
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), 0, 0, address(0), 0);
        revenueAuthority.setCurrentAction(true, bytes32(actionNonce), 1, scope, oldState, newState);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPermitPolicy.InvalidAssetPermitPolicyAction.selector)
        );
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 0, 0, address(0), 0);
        require(policy.assetPermitPolicy(address(token)).revision == 1, "replay unchanged");
    }

    function testCapabilityAndTargetFieldsFailClosed() public {
        _invalid(4, 0, address(0), 0);
        _invalid(1, 1, address(permitTarget), address(permitTarget).codehash);
        _invalid(2, 0, address(permitTarget), address(permitTarget).codehash);
        _invalid(2, 3, address(permitTarget), address(permitTarget).codehash);
        _invalid(2, 1, address(0x1234), bytes32(uint256(1)));
        _invalid(2, 1, address(permitTarget), bytes32(uint256(1)));
        _invalid(0, 0, address(permitTarget), 0);
    }

    function testDelegatedAssetAndPermitTargetReject() public {
        vm.etch(address(permitTarget), abi.encodePacked(hex"ef0100", address(0x1234)));
        _invalid(2, 1, address(permitTarget), address(permitTarget).codehash);
        vm.etch(address(token), abi.encodePacked(hex"ef0100", address(0x1234)));
        _invalid(1, 0, address(0), 0);
    }

    function testInactiveAssetsCannotGainCapabilities() public {
        _setAssetPolicy(policy, address(token), 2, keccak256("review paused"), 0);
        _invalid(1, 0, address(0), 0);
    }

    function testSafePermissionlessReadsAndAuthorityForwardedWrite() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 912);
        PermitPolicySafeAuthority authority = new PermitPolicySafeAuthority(address(safe));
        policy = new StreamAssetPolicyRegistry(address(authority));
        revenueAuthority = authority;
        _setAssetPolicy(policy, address(token), 1, keccak256("safe-reviewed"), 0);
        _prepare(1, 0, address(0), 0, 1);
        bytes memory data = abi.encodeCall(
            policy.setAssetPermitPolicy, (address(token), 1, 0, address(0), bytes32(0))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.AssetPolicyNotAuthority.selector, address(safe)
            )
        );
        vm.prank(address(safe));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
        (bool ok, bytes memory reason) = address(this)
            .call(abi.encodeCall(this.attemptSafe, (safe, keys, address(policy), data)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe rejection"
        );
        require(safe.nonce() == 0, "direct unauthorized Safe rollback");
        require(
            executeSafe(
                safe,
                keys,
                address(authority),
                0,
                abi.encodeCall(authority.execute, (address(policy), data)),
                0
            ),
            "authority Safe execution"
        );
        require(
            policy.assetPermitPolicy(address(token)).capabilities == 1 && safe.nonce() == 1,
            "actual state+Safe nonce"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(policy),
                0,
                abi.encodeCall(policy.assetPermitPolicy, (address(token))),
                0
            ),
            "Safe policy read"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(policy),
                0,
                abi.encodeCall(policy.assetPolicyRevision, (address(token))),
                0
            ),
            "Safe revision read"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(policy),
                0,
                abi.encodeCall(
                    policy.assetPermitPolicyTransitionHashes,
                    (address(token), 0, 0, address(0), bytes32(0))
                ),
                0
            ),
            "Safe transition read"
        );
        require(safe.nonce() == 4, "all read transactions executed");
    }

    function testFuzzAttestationBoundToBothRuntimeAndRevision(uint8 bits, bool preserveInfinity)
        public
    {
        bits = uint8(uint256(bits) % 3 + 1);
        bool usePermit2 = bits & 2 != 0;
        _set(
            bits,
            usePermit2 ? (preserveInfinity ? 2 : 1) : 0,
            usePermit2 ? address(permitTarget) : address(0),
            usePermit2 ? address(permitTarget).codehash : bytes32(0)
        );
        IStreamAssetPermitPolicy.AssetPermitPolicy memory p =
            policy.assetPermitPolicy(address(token));
        require(
            p.capabilities == bits && p.assetCodeHash == address(token).codehash
                && p.assetPolicyRevision == policy.assetPolicyRevision(address(token)),
            "exact attestation"
        );
    }

    function attemptSafe(
        OfficialSafe safe,
        uint256[] calldata keys,
        address target,
        bytes calldata data
    ) external returns (bool) {
        return executeSafe(safe, keys, target, 0, data, 0);
    }

    function _invalid(uint8 bits, uint8 mode, address target, bytes32 hash) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPermitPolicy.InvalidAssetPermitPolicy.selector, address(token)
            )
        );
        policy.assetPermitPolicyTransitionHashes(address(token), bits, mode, target, hash);
    }

    function _prepare(uint8 bits, uint8 mode, address target, bytes32 hash, uint8 actionClass)
        private
    {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), bits, mode, target, hash);
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), actionClass, scope, oldState, newState
        );
    }

    function _set(uint8 bits, uint8 mode, address target, bytes32 hash) private {
        _prepare(bits, mode, target, hash, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), bits, mode, target, hash);
    }
}
