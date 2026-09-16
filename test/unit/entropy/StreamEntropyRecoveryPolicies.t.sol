// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";

/// @notice Actual policy/coordinator/Safe; Core, provider and executing-authority boundaries are explicit fixtures.
contract StreamEntropyRecoveryPoliciesTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    address private permittedSafe;
    bytes32 private constant ID = keccak256("ordered recovery policy");
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant REASON = keccak256("reason schema");
    bytes32 private constant MANIFEST = keccak256("policy manifest");

    function setUp() public {
        EntropySubjectCoreFixture core = new EntropySubjectCoreFixture();
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                ID,
                "urn:stream:test:recovery-policy",
                MANIFEST
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(provider));
    }

    function _steps() private view returns (R.FreshRecoveryStep[] memory steps) {
        steps = new R.FreshRecoveryStep[](2);
        steps[0] = R.FreshRecoveryStep(address(provider), 2, keccak256("first config"), 12, false);
        steps[1] = R.FreshRecoveryStep(address(provider), 3, keccak256("second config"), 24, true);
    }

    function _hash(
        R.FreshRecoveryStep[] memory steps,
        uint16 attempts,
        bytes32 role,
        bytes32 manifest
    ) private view returns (bytes32) {
        // Literal original recipe, independent of the production implementation.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                uint256(block.chainid),
                address(entropy),
                ID,
                attempts,
                role,
                REASON,
                manifest,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
    }

    function _data(
        R.FreshRecoveryStep[] memory steps,
        uint16 attempts,
        bytes32 role,
        bytes32 manifest
    ) private pure returns (bytes memory) {
        return abi.encodeCall(
            R.configureFreshRecoveryPolicy, (ID, attempts, role, REASON, manifest, steps)
        );
    }

    function _context(bytes32 hash, bool freezing, bytes32 actionId, uint8 cls) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            entropy.freshRecoveryPolicyTransition(ID, hash, freezing);
        this.setCurrentAction(true, actionId, cls, scope, oldHash, newHash);
    }

    function _configure() private returns (bytes32 hash) {
        R.FreshRecoveryStep[] memory steps = _steps();
        hash = _hash(steps, 2, ROLE, MANIFEST);
        _context(hash, false, bytes32(uint256(101)), 1);
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, REASON, MANIFEST, steps);
    }

    function _stored() private view returns (bytes32) {
        (R.FreshRecoveryPolicy memory p, bytes32 hash, uint64 revision, bytes32 actionId) =
            entropy.freshRecoveryPolicy(ID);
        return keccak256(abi.encode(p, hash, revision, actionId));
    }

    function _refused(bytes memory data) private {
        bytes32 prior = _stored();
        (bool ok,) = address(entropy).call(data);
        require(!ok && prior == _stored(), "rejected mutation must be atomic");
    }

    function testCanonicalHashFullOrderedReadbackAndOriginalEvents() public {
        vm.recordLogs();
        bytes32 hash = _configure();
        (R.FreshRecoveryPolicy memory p, bytes32 saved, uint64 revision, bytes32 actionId) =
            entropy.freshRecoveryPolicy(ID);
        require(
            p.exists && !p.frozen && saved == hash && revision == 1
                && actionId == bytes32(uint256(101))
        );
        require(
            p.maxFreshRecoveryAttempts == 2 && p.incidentDeclarerRole == ROLE
                && p.reasonSchemaHash == REASON && p.policyManifestHash == MANIFEST
        );
        require(keccak256(abi.encode(p.steps)) == keccak256(abi.encode(_steps())));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 3 && logs[0].emitter == address(entropy));
        require(
            logs[0].topics[0]
                == keccak256(
                    "FreshRecoveryPolicyConfigured(uint16,bytes32,bytes32,uint16,bytes32,bytes32)"
                )
        );
        require(logs[0].topics[1] == ID && logs[0].topics[2] == hash);
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(uint16(1), uint16(2), ROLE, MANIFEST))
        );
        require(keccak256(logs[1].data) == keccak256(abi.encode(uint16(1), REASON, p.steps)));
        require(
            entropy.supportsInterface(type(R).interfaceId) && !entropy.supportsInterface(0xffffffff)
        );
    }

    function testFreezeIsPermanentAndDoesNotChangeCanonicalPolicyHash() public {
        bytes32 hash = _configure();
        _context(hash, true, bytes32(uint256(102)), 1);
        entropy.freezeFreshRecoveryPolicy(ID);
        (R.FreshRecoveryPolicy memory p, bytes32 saved, uint64 revision,) =
            entropy.freshRecoveryPolicy(ID);
        require(p.frozen && saved == hash && revision == 2);
        _refused(abi.encodeCall(R.freezeFreshRecoveryPolicy, (ID)));
        _refused(_data(_steps(), 2, ROLE, MANIFEST));
    }

    function testReconfigurationInvalidatesOldFreezeAndAcceptsFreshCommitments() public {
        bytes32 hash = _configure();
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            entropy.freshRecoveryPolicyTransition(ID, hash, true);
        R.FreshRecoveryStep[] memory steps = _steps();
        (steps[0], steps[1]) = (steps[1], steps[0]);
        bytes32 nextPolicyHash = _hash(steps, 2, ROLE, MANIFEST);
        require(hash != nextPolicyHash, "order is identity");
        _context(nextPolicyHash, false, bytes32(uint256(102)), 1);
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, REASON, MANIFEST, steps);
        this.setCurrentAction(true, bytes32(uint256(103)), 1, scope, oldHash, nextHash);
        _refused(abi.encodeCall(R.freezeFreshRecoveryPolicy, (ID)));
        _context(nextPolicyHash, true, bytes32(uint256(103)), 1);
        entropy.freezeFreshRecoveryPolicy(ID);
        (R.FreshRecoveryPolicy memory p, bytes32 saved, uint64 revision,) =
            entropy.freshRecoveryPolicy(ID);
        require(p.frozen && saved == nextPolicyHash && revision == 3);
    }

    function testWrongClassMissingContextWrongCallerAndChangedPreimageAreRejected() public {
        R.FreshRecoveryStep[] memory steps = _steps();
        bytes memory data = _data(steps, 2, ROLE, MANIFEST);
        _refused(data);
        bytes32 hash = _hash(steps, 2, ROLE, MANIFEST);
        _context(hash, false, bytes32(uint256(101)), 0);
        _refused(data);
        _context(hash, false, bytes32(uint256(101)), 1);
        vm.prank(address(0xbeef));
        (bool ok,) = address(entropy).call(data);
        require(!ok);
        steps[0].acceptLateOriginalFulfillment = true;
        _refused(_data(steps, 2, ROLE, MANIFEST));
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, REASON, MANIFEST, _steps());
    }

    function testMalformedContextAndConsumedActionRejectWithIdenticalRetry() public {
        R.FreshRecoveryStep[] memory steps = _steps();
        bytes32 hash = _hash(steps, 2, ROLE, MANIFEST);
        _context(hash, false, bytes32(uint256(101)), 1);
        for (uint256 i = 1; i <= uint256(ResponseMode.NonCanonicalActionClass); ++i) {
            this.setResponseMode(ResponseMode(i));
            _refused(_data(steps, 2, ROLE, MANIFEST));
        }
        this.setResponseMode(ResponseMode.Canonical);
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, REASON, MANIFEST, steps);
        _context(hash, false, bytes32(uint256(101)), 1);
        _refused(_data(steps, 2, ROLE, MANIFEST));
        _context(hash, false, bytes32(uint256(102)), 1);
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, REASON, MANIFEST, steps);
    }

    function testInvalidRoleBoundsStepsAndAbsentPolicyFreezeReject() public {
        R.FreshRecoveryStep[] memory steps = _steps();
        _refused(abi.encodeCall(R.freezeFreshRecoveryPolicy, (ID)));
        _refused(_data(steps, 0, ROLE, MANIFEST));
        _refused(_data(steps, 3, ROLE, MANIFEST));
        _refused(_data(steps, 2, bytes32(uint256(uint160(address(this)))), MANIFEST));
        _refused(_data(steps, 2, ROLE, 0));
        steps[0].notBeforeBlocks = 0;
        _refused(_data(steps, 2, ROLE, MANIFEST));
        steps = _steps();
        steps[0].providerEpoch = 0;
        _refused(_data(steps, 2, ROLE, MANIFEST));
        steps = _steps();
        steps[0].provider = address(0xbeef);
        _refused(_data(steps, 2, ROLE, MANIFEST));
        steps = new R.FreshRecoveryStep[](33);
        _refused(_data(steps, 1, ROLE, MANIFEST));
    }

    function testProviderRevocationDoesNotRewriteFrozenPolicyAndPolicyDoesNotEnableCollection()
        public
    {
        bytes32 hash = _configure();
        _context(hash, true, bytes32(uint256(102)), 1);
        entropy.freezeFreshRecoveryPolicy(ID);
        bytes32 prior = _stored();
        _setEntropyProviderRevoked(address(entropy), address(provider), true);
        require(
            _stored() == prior && entropy.collectionProviderEpoch(1) == 0
                && entropy.pendingRequestCount() == 0
        );
        (address configured,,,,,,) = entropy.collectionEntropyConfig(1);
        require(configured == address(0));
    }

    function applyThroughAuthority(bytes calldata data) external {
        require(msg.sender == permittedSafe, "test authority's threshold Safe only");
        (bool ok, bytes memory result) = address(entropy).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }

    function executeDirectSafe(OfficialSafe safe, uint256[] memory keys, bytes memory data)
        external
        returns (bool)
    {
        require(msg.sender == address(this));
        return executeSafe(safe, keys, address(entropy), 0, data, 0);
    }

    function testThresholdSafeExecutesPolicyThroughExplicitAuthorityBoundaryAndRejectsDirectWrite()
        public
    {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE01;
        keys[1] = 0x5AFE02;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 421);
        permittedSafe = address(safe);
        R.FreshRecoveryStep[] memory steps = _steps();
        bytes memory data = _data(steps, 2, ROLE, MANIFEST);
        _context(_hash(steps, 2, ROLE, MANIFEST), false, bytes32(uint256(101)), 1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDirectSafe(safe, keys, data);
        require(
            executeSafe(
                safe, keys, address(this), 0, abi.encodeCall(this.applyThroughAuthority, (data)), 0
            )
        );
        (R.FreshRecoveryPolicy memory p,,,) = entropy.freshRecoveryPolicy(ID);
        require(p.exists);
    }

    function testFuzzChangedManifestCannotReuseGovernanceCommitment(bytes32 manifest) public {
        if (manifest == 0 || manifest == MANIFEST) return;
        R.FreshRecoveryStep[] memory steps = _steps();
        _context(_hash(steps, 2, ROLE, MANIFEST), false, bytes32(uint256(101)), 1);
        _refused(_data(steps, 2, ROLE, manifest));
    }
}
