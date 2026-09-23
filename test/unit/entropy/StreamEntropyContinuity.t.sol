// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";
import {
    IStreamEntropyFreshRecovery as F
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    IStreamEntropyRecoveryPolicies as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";

interface ContinuityVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Explicit Artist boundary; actual original Artist consent admission has a separate suite.
contract ContinuityArtistFixture {
    address public immutable core;
    bool public bound = true;
    mapping(bytes32 => bytes32) public consents;

    constructor(address c) {
        core = c;
    }

    function setBound(bool b) external {
        bound = b;
    }

    function approve(bytes32 state, bytes32 record) external {
        consents[state] = record;
    }

    function gasParameterInfo(bytes32) external pure returns (uint256, uint256, uint8, uint64) {
        return (600000, 100000, 2, 1);
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        if (!bound) return (0, 0, 0, 0, 0);
        return (2, 1, keccak256("artist"), 1, keccak256("accepted binding"));
    }

    function contentConsentEvidenceForHost(uint256, address, bytes32, bytes32 state)
        external
        view
        returns (bytes32)
    {
        return consents[state];
    }
}

/// @notice Actual coordinator/continuity workers and Safe; Core, Artist, roles and providers are explicit unit boundaries.
contract StreamEntropyContinuityTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant HASH = keccak256("independent provider evidence");
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    StreamEntropyCoordinator private successor;
    MockStreamEntropyProvider private first;
    MockStreamEntropyProvider private fallbackProvider;
    MockEntropyRoleRegistry public roleRegistry;
    ContinuityArtistFixture private artist;

    function setUp() public {
        _deploy(false);
    }

    function _deploy(bool late) private {
        vm.roll(100);
        core = new EntropySubjectCoreFixture();
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:fresh",
                HASH
            )
        );
        core.setCoordinator(entropy);
        successor = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:next",
                HASH
            )
        );
        first = new MockStreamEntropyProvider(address(entropy));
        fallbackProvider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(first));
        _admitEntropyProvider(address(entropy), address(fallbackProvider));
        entropy.configureCollection(1, address(first), HASH, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        entropy.configureCollection(2, address(first), HASH, true, 10);
        entropy.configureCollectionRevealPolicy(2, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        P.FreshRecoveryStep[] memory steps = new P.FreshRecoveryStep[](2);
        steps[0] = P.FreshRecoveryStep(
            address(fallbackProvider),
            3,
            fallbackProvider.streamEntropyProviderConfigHash(),
            10,
            late
        );
        steps[1] = P.FreshRecoveryStep(
            address(fallbackProvider),
            4,
            fallbackProvider.streamEntropyProviderConfigHash(),
            10,
            false
        );
        bytes32 id = keccak256("ordered policy");
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                id,
                uint16(2),
                ROLE,
                HASH,
                HASH,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"),
                block.chainid,
                address(entropy),
                address(core),
                id,
                hash,
                address(successor),
                address(successor).codehash
            )
        );
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            entropy.freshRecoveryPolicyV2Transition(id, hash);
        this.setCurrentAction(true, bytes32(uint256(101)), 1, scope, oldHash, next);
        entropy.configureFreshRecoveryPolicyV2(
            id, 2, ROLE, HASH, HASH, steps, address(successor), address(successor).codehash
        );
        (scope, oldHash, next) = entropy.freshRecoveryPolicyTransition(id, hash, true);
        this.setCurrentAction(true, bytes32(uint256(102)), 1, scope, oldHash, next);
        entropy.freezeFreshRecoveryPolicy(id);
        (scope, oldHash, next) = entropy.collectionFreshRecoveryTransition(1, 2, id);
        this.setCurrentAction(true, bytes32(uint256(103)), 1, scope, oldHash, next);
        entropy.configureCollectionFreshRecovery(1, 2, id);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        roleRegistry.setHolder(ROLE, address(this));
        artist = new ContinuityArtistFixture(address(core));
        ContinuityVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeWithSignature(
                    "getSatellitePointer(bytes32)", keccak256("ARTIST_REGISTRY")
                ),
                abi.encode(
                    address(artist),
                    address(artist).codehash,
                    false,
                    bytes32(0),
                    bytes4(0),
                    address(0),
                    uint8(0),
                    bytes32(0),
                    bytes32(0),
                    uint64(1)
                )
            );
    }

    function _input(bytes32 old) private pure returns (F.RecoveryInput memory) {
        return F.RecoveryInput(old, "urn:test:incident:independent-proof", HASH);
    }

    function _failedToken() private returns (bytes32 key, uint256 id) {
        core.registerToken(1, HASH);
        (key, id) = entropy.requestEntropy(1);
        vm.roll(111);
        entropy.markEntropyRequestUnrecoverable(1, "urn:test:incident", HASH);
        vm.roll(122);
    }

    function _approve(bytes32 key) private returns (bytes32 next, bytes32 state) {
        (next, state,) = entropy.freshRecoveryTransition(_input(key));
        artist.approve(state, keccak256(abi.encode("actual fixture consent", key, state)));
    }

    function _refused(F.RecoveryInput memory input, uint256 value) private {
        (, bytes32 before_) = entropy.artistContentFamilyState(1, FAMILY);
        uint256 pending = entropy.pendingRequestCount();
        (bool ok,) =
            address(entropy).call{ value: value }(abi.encodeCall(F.requestFreshEntropy, (input)));
        (, bytes32 after_) = entropy.artistContentFamilyState(1, FAMILY);
        require(
            !ok && before_ == after_ && entropy.pendingRequestCount() == pending,
            "rejection changed recovery state"
        );
    }

    function _uncovered() private view returns (uint256) {
        return entropy.uncoveredPendingRequestCount(address(successor), address(successor).codehash);
    }

    function testMixedTokenScopeCoverageUsesExactFrozenTargetAndRetiresOnce() public {
        core.registerToken(1, HASH);
        (, uint256 coveredToken) = entropy.requestEntropy(1);
        bytes32 coveredScope = entropy.registerEntropyScope(1, 1, keccak256("covered"));
        entropy.requestScopeEntropy(coveredScope, HASH);
        core.registerTokenInCollection(2, 2, HASH);
        (, uint256 uncoveredToken) = entropy.requestEntropy(2);
        bytes32 uncoveredScope = entropy.registerEntropyScope(2, 1, keccak256("uncovered"));
        (bytes32 closeKey,) = entropy.requestScopeEntropy(uncoveredScope, HASH);
        require(
            entropy.pendingRequestCount() == 4 && _uncovered() == 2, "collection coverage complete"
        );
        require(
            entropy.uncoveredPendingRequestCount(address(successor), HASH) == 4,
            "runtime is part of target"
        );
        require(
            entropy.uncoveredPendingRequestCount(address(this), address(this).codehash) == 4,
            "address exact"
        );
        require(first.fulfill(uncoveredToken, HASH) == 0 && _uncovered() == 1);
        vm.roll(111);
        entropy.markRequestStale(closeKey);
        require(_uncovered() == 0 && entropy.pendingRequestCount() == 2);
        require(first.fulfill(coveredToken, HASH) == 0 && _uncovered() == 0);
        require(
            first.fulfill(coveredToken, HASH) == 3 && entropy.pendingRequestCount() == 1,
            "no double retirement"
        );
    }

    function testFrozenPolicyCannotAcquireOrChangeReplacementPermission() public {
        bytes32 id = keccak256("ordered policy");
        (address target, bytes32 codeHash, bytes32 hash) = entropy.coordinatorReplacementTerms(id);
        require(
            target == address(successor) && codeHash == address(successor).codehash && hash != 0
        );
        vm.expectRevert();
        entropy.freshRecoveryPolicyV2Transition(id, keccak256("changed"));
        P.FreshRecoveryStep[] memory steps = new P.FreshRecoveryStep[](1);
        steps[0] = P.FreshRecoveryStep(
            address(fallbackProvider),
            3,
            fallbackProvider.streamEntropyProviderConfigHash(),
            10,
            false
        );
        vm.expectRevert();
        entropy.configureFreshRecoveryPolicyV2(
            id, 1, ROLE, HASH, HASH, steps, address(successor), codeHash
        );
        vm.expectRevert();
        entropy.configureFreshRecoveryPolicy(id, 1, ROLE, HASH, HASH, steps);
        (address afterTarget, bytes32 afterCode, bytes32 afterHash) =
            entropy.coordinatorReplacementTerms(id);
        require(
            target == afterTarget && codeHash == afterCode && hash == afterHash, "immutable terms"
        );
    }

    function testWrongRuntimeAndForeignCoreFailBeforePolicyMutation() public {
        P.FreshRecoveryStep[] memory steps = new P.FreshRecoveryStep[](1);
        steps[0] = P.FreshRecoveryStep(
            address(fallbackProvider),
            3,
            fallbackProvider.streamEntropyProviderConfigHash(),
            10,
            false
        );
        vm.expectRevert();
        entropy.configureFreshRecoveryPolicyV2(
            HASH, 1, ROLE, HASH, HASH, steps, address(successor), HASH
        );
        EntropySubjectCoreFixture foreign = new EntropySubjectCoreFixture();
        StreamEntropyCoordinator other = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(foreign),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:foreign",
                HASH
            )
        );
        vm.expectRevert();
        entropy.configureFreshRecoveryPolicyV2(
            HASH, 1, ROLE, HASH, HASH, steps, address(other), address(other).codehash
        );
        (address target,, bytes32 hash) = entropy.coordinatorReplacementTerms(HASH);
        require(target == address(0) && hash == 0);
    }

    function testOriginalV1HashAndFrozenPolicyRemainUncovered() public {
        bytes32 id = keccak256("original V1 policy");
        P.FreshRecoveryStep[] memory steps = new P.FreshRecoveryStep[](1);
        steps[0] = P.FreshRecoveryStep(
            address(fallbackProvider),
            3,
            fallbackProvider.streamEntropyProviderConfigHash(),
            10,
            false
        );
        bytes32 originalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                id,
                uint16(1),
                ROLE,
                HASH,
                HASH,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        (bytes32 scope, bytes32 prior, bytes32 next) =
            entropy.freshRecoveryPolicyTransition(id, originalHash, false);
        this.setCurrentAction(true, keccak256("configure original"), 1, scope, prior, next);
        entropy.configureFreshRecoveryPolicy(id, 1, ROLE, HASH, HASH, steps);
        (address target, bytes32 runtime, bytes32 actualHash) =
            entropy.coordinatorReplacementTerms(id);
        require(
            target == address(0) && runtime == 0 && actualHash == originalHash, "original V1 domain"
        );
        vm.expectRevert();
        entropy.collectionFreshRecoveryTransition(2, 1, id);
        (scope, prior, next) = entropy.freshRecoveryPolicyTransition(id, originalHash, true);
        this.setCurrentAction(true, keccak256("freeze original"), 1, scope, prior, next);
        entropy.freezeFreshRecoveryPolicy(id);
        (scope, prior, next) = entropy.collectionFreshRecoveryTransition(2, 1, id);
        this.setCurrentAction(true, keccak256("bind original"), 1, scope, prior, next);
        entropy.configureCollectionFreshRecovery(2, 1, id);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        core.registerTokenInCollection(2, 2, HASH);
        (, uint256 requestId) = entropy.requestEntropy(2);
        require(entropy.pendingRequestCount() == 1 && _uncovered() == 1, "V1 grants no replacement");
        vm.expectRevert();
        entropy.configureFreshRecoveryPolicyV2(
            id, 1, ROLE, HASH, HASH, steps, address(successor), address(successor).codehash
        );
        require(first.fulfill(requestId, HASH) == 0 && _uncovered() == 0);
    }

    function testProviderReentryRollsBothCountersBackThenSameRequestSucceeds() public {
        core.registerToken(1, HASH);
        first.setReenterOnRequest(true);
        vm.expectRevert();
        entropy.requestEntropy(1);
        require(
            entropy.pendingRequestCount() == 0 && _uncovered() == 0 && first.nextRequestId() == 1
        );
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED);
        first.setReenterOnRequest(false);
        (, uint256 id) = entropy.requestEntropy(1);
        require(id == 1 && entropy.pendingRequestCount() == 1 && _uncovered() == 0);
        require(
            first.fulfill(id, HASH) == 0 && entropy.pendingRequestCount() == 0 && _uncovered() == 0
        );
    }

    function testLateOriginalRetiresActiveReplacementCoverageNotTerminalAncestor() public {
        _deploy(true);
        (bytes32 old, uint256 originalId) = _failedToken();
        require(
            entropy.pendingRequestCount() == 0 && _uncovered() == 0, "terminal ancestor retired"
        );
        _approve(old);
        (, uint256 newId) = entropy.requestFreshEntropy(_input(old));
        require(entropy.pendingRequestCount() == 1 && _uncovered() == 0);
        require(first.fulfill(originalId, HASH) == 0, "allowed original wins");
        require(
            entropy.pendingRequestCount() == 0 && _uncovered() == 0, "active successor retired once"
        );
        (bytes32 seed, bool final_) = entropy.tokenSeed(1);
        require(final_);
        require(fallbackProvider.fulfill(newId, keccak256("other")) == 3);
        (bytes32 after_,) = entropy.tokenSeed(1);
        require(after_ == seed && _uncovered() == 0);
    }

    function testOriginalScopeCanRequestAfterCutoverButNewScopeCannotUseOldHost() public {
        bytes32 original = entropy.registerEntropyScope(1, 0, HASH);
        core.setCoordinator(successor);
        (bytes32 key, uint256 id) = entropy.requestScopeEntropy(original, HASH);
        require(key != 0 && first.fulfill(id, HASH) == 0);
        vm.expectRevert();
        entropy.registerEntropyScope(1, 0, keccak256("new"));
        (bytes32 seed, bool finalized) = entropy.scopeSeed(original);
        require(seed != 0 && finalized);
    }

    function testSafeRequestFailurePreservesNonceAndIdenticalCalldataRetry() public {
        core.registerToken(1, HASH);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xAA11;
        keys[1] = 0xAA12;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 988);
        bytes memory data = abi.encodeCall(entropy.requestEntropy, (uint256(1)));
        uint256 nonce = safe.nonce();
        first.setReenterOnRequest(true);
        vm.expectRevert();
        this.executeRequestSafe(safe, keys, data);
        require(safe.nonce() == nonce && entropy.pendingRequestCount() == 0 && _uncovered() == 0);
        first.setReenterOnRequest(false);
        require(this.executeRequestSafe(safe, keys, data));
        require(
            safe.nonce() == nonce + 1 && entropy.pendingRequestCount() == 1 && _uncovered() == 0
        );
    }

    function executeRequestSafe(OfficialSafe safe, uint256[] memory keys, bytes memory data)
        external
        returns (bool)
    {
        require(msg.sender == address(this));
        return executeSafe(safe, keys, address(entropy), 0, data, 0);
    }
}
