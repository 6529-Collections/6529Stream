// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropySubjectIdentity.t.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";

interface CollectionRecoveryVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Actual coordinator and policy workers; Core/provider/executing governance are typed fixtures.
contract StreamEntropyCollectionRecoveryTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture
{
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    bytes32 private constant ID = keccak256("collection recovery");
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant HASH = keccak256("fixture manifest");
    bytes32 private policyHash;

    function setUp() public {
        core = new EntropySubjectCoreFixture();
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:binding",
                HASH
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(provider));
        entropy.configureCollection(1, address(provider), HASH, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        R.FreshRecoveryStep[] memory steps = new R.FreshRecoveryStep[](2);
        steps[0] = R.FreshRecoveryStep(address(provider), 3, HASH, 12, false);
        steps[1] = R.FreshRecoveryStep(address(provider), 4, HASH, 24, true);
        policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                ID,
                uint16(2),
                ROLE,
                HASH,
                HASH,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            entropy.freshRecoveryPolicyTransition(ID, policyHash, false);
        this.setCurrentAction(true, bytes32(uint256(501)), 1, scope, oldHash, next);
        entropy.configureFreshRecoveryPolicy(ID, 2, ROLE, HASH, HASH, steps);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _freeze() private {
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            entropy.freshRecoveryPolicyTransition(ID, policyHash, true);
        this.setCurrentAction(true, bytes32(uint256(502)), 1, scope, oldHash, next);
        entropy.freezeFreshRecoveryPolicy(ID);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _context(uint16 attempts, bytes32 policy, bytes32 action) private {
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            entropy.collectionFreshRecoveryTransition(1, attempts, policy);
        this.setCurrentAction(true, action, 1, scope, oldHash, next);
    }

    function _bind() private {
        _freeze();
        _context(2, ID, bytes32(uint256(601)));
        entropy.configureCollectionFreshRecovery(1, 2, ID);
    }

    function _state() private view returns (bytes32) {
        return keccak256(
            abi.encode(entropy.collectionFreshRecovery(1), entropy.collectionProviderEpoch(1))
        );
    }

    function _refused(uint16 attempts, bytes32 policy) private {
        bytes32 before_ = _state();
        (bool ok,) = address(entropy)
            .call(abi.encodeCall(C.configureCollectionFreshRecovery, (1, attempts, policy)));
        require(!ok && before_ == _state(), "binding failure not atomic");
    }

    function testAbsentAndUnfrozenPoliciesCannotAttach() public {
        require(
            entropy.collectionFreshRecovery(1).policyId == 0
                && entropy.collectionProviderEpoch(1) == 1
        );
        _refused(2, ID);
        _refused(1, HASH);
        _refused(0, ID);
        _freeze();
        _refused(3, ID);
        require(entropy.supportsInterface(type(C).interfaceId));
    }

    function testFrozenBindingRetainsExactPolicyAndEmitsEpochAndAction() public {
        _freeze();
        _context(2, ID, bytes32(uint256(601)));
        vm.recordLogs();
        entropy.configureCollectionFreshRecovery(1, 2, ID);
        C.CollectionRecovery memory b = entropy.collectionFreshRecovery(1);
        require(
            b.policyId == ID && b.policyHash == policyHash && b.maxFreshRecoveryAttempts == 2
                && b.revision == 1 && b.lastActionId == bytes32(uint256(601))
        );
        require(entropy.collectionProviderEpoch(1) == 2);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2);
        require(
            logs[0].topics[0]
                == keccak256(
                    "CollectionFreshRecoveryConfigured(uint16,uint256,bytes32,bytes32,uint16,uint32,uint64,bytes32)"
                )
        );
        require(logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == ID);
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        policyHash,
                        uint16(2),
                        uint32(2),
                        uint64(1),
                        bytes32(uint256(601))
                    )
                )
        );
    }

    function testExactAuthorityContextIsMandatoryAndFailedAttemptCanRetry() public {
        _freeze();
        _refused(2, ID);
        _context(2, ID, bytes32(uint256(601)));
        vm.prank(address(0xbeef));
        (bool ok,) =
            address(entropy).call(abi.encodeCall(C.configureCollectionFreshRecovery, (1, 2, ID)));
        require(!ok);
        _refused(1, ID);
        entropy.configureCollectionFreshRecovery(1, 2, ID);
    }

    function testFinalityCommitmentDisclosesRecoveryAndOriginalPolicyLocksAtFirstToken() public {
        (, bytes32 before_,,,) = entropy.entropyPolicyFrozen(1);
        _bind();
        (bool frozen, bytes32 after_,,,) = entropy.entropyPolicyFrozen(1);
        require(!frozen && after_ != before_);
        core.registerToken(1, HASH);
        (frozen, after_,,,) = entropy.entropyPolicyFrozen(1);
        require(frozen);
        _refused(0, 0);
        require(entropy.collectionFreshRecovery(1).policyHash == policyHash);
    }

    function testScopeRegistrationLocksBinding() public {
        _freeze();
        entropy.registerEntropyScope(1, 0, HASH);
        _refused(2, ID);
    }

    function testCoreFreezeRejectsPreparedBindingWithoutWrites() public {
        _freeze();
        _context(2, ID, bytes32(uint256(601)));
        CollectionRecoveryVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeWithSignature("collectionFreezeStatus(uint256)", uint256(1)),
                abi.encode(true)
            );
        _refused(2, ID);
    }

    function testPreMintDetachAdvancesEpochButCannotReplayPriorAction() public {
        _bind();
        _context(0, 0, bytes32(uint256(601)));
        _refused(0, 0);
        _context(0, 0, bytes32(uint256(602)));
        entropy.configureCollectionFreshRecovery(1, 0, 0);
        C.CollectionRecovery memory b = entropy.collectionFreshRecovery(1);
        require(
            b.policyId == 0 && b.policyHash == 0 && b.maxFreshRecoveryAttempts == 0
                && b.revision == 2 && entropy.collectionProviderEpoch(1) == 3
        );
    }

    function testOrdinaryProviderChangeCannotOvertakeFrozenRecoveryEpochs() public {
        _bind();
        MockStreamEntropyProvider next = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(next));
        bytes32 before_ = _state();
        (bool ok,) = address(entropy)
            .call(
                abi.encodeCall(
                    entropy.configureCollection, (1, address(next), HASH, true, uint64(10))
                )
            );
        require(!ok && before_ == _state());
        entropy.configureCollection(1, address(provider), HASH, false, 20);
        require(entropy.collectionProviderEpoch(1) == 2);
    }
}
