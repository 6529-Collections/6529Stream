// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @notice Actual coordinator and Safe; Core, provider and governance context are explicit fixtures.
contract StreamEntropyProviderLifecycleTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    bytes32 private constant HASH = keccak256("lifecycle fixture");
    string private constant REASON = "urn:stream:test:lifecycle";
    uint256 private nonce;

    function setUp() public {
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
                REASON,
                HASH
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
    }

    function _context(EntropyProviderState next, bytes32 id) private returns (bytes memory data) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) =
            entropy.entropyProviderTransition(address(provider), next, REASON);
        this.setCurrentAction(true, id, cls, scope, oldHash, newHash);
        if (next == EntropyProviderState.ACTIVE) {
            return abi.encodeCall(entropy.activateEntropyProvider, (address(provider), REASON));
        }
        if (next == EntropyProviderState.DEPRECATED) {
            return abi.encodeCall(entropy.deprecateEntropyProvider, (address(provider), REASON));
        }
        return abi.encodeCall(entropy.revokeEntropyProvider, (address(provider), REASON));
    }

    function _change(EntropyProviderState next) private {
        bytes memory data = _context(next, bytes32(++nonce));
        (bool ok, bytes memory out) = address(entropy).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _configured() private {
        _change(EntropyProviderState.ACTIVE);
        entropy.configureCollection(1, address(provider), HASH, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function _refused(bytes memory data) private {
        bytes32 before = keccak256(abi.encode(entropy.entropyProviderRecord(address(provider))));
        (bool ok,) = address(entropy).call(data);
        require(!ok, "invalid transition accepted");
        require(
            before == keccak256(abi.encode(entropy.entropyProviderRecord(address(provider)))),
            "failed transition mutated state"
        );
    }

    function testUnknownProviderCannotConfigureAndIsNotEnumerated() public {
        require(entropy.entropyProviderCount() == 0);
        require(
            entropy.entropyProviderRecord(address(provider)).state == EntropyProviderState.UNKNOWN
        );
        _refused(
            abi.encodeCall(
                entropy.configureCollection, (1, address(provider), HASH, true, uint64(10))
            )
        );
        require(entropy.supportsInterface(type(IStreamEntropyProviderLifecycle).interfaceId));
        require(!entropy.supportsInterface(0xffffffff));
    }

    function testAdmissionAndRestorationEnumerateOnceAndRetainAuthorizingEvent() public {
        vm.recordLogs();
        _change(EntropyProviderState.ACTIVE);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[0].emitter == address(entropy));
        require(
            logs[0].topics[0]
                == keccak256(
                    "EntropyProviderStateUpdated(uint16,address,bytes32,uint8,uint8,string)"
                )
        );
        require(
            logs[0].topics[1] == bytes32(uint256(uint160(address(provider))))
                && logs[0].topics[2] == bytes32(uint256(1))
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1), EntropyProviderState.UNKNOWN, EntropyProviderState.ACTIVE, REASON
                    )
                )
        );
        _change(EntropyProviderState.DEPRECATED);
        _change(EntropyProviderState.ACTIVE);
        IStreamEntropyProviderLifecycle.ProviderRecord memory r =
            entropy.entropyProviderRecord(address(provider));
        require(
            entropy.entropyProviderCount() == 1 && entropy.entropyProviderAt(0) == address(provider)
        );
        require(
            r.revision == 3 && r.lastActionId == bytes32(uint256(3))
                && r.reasonHash == keccak256(bytes(REASON))
                && r.runtimeCodeHash == address(provider).codehash
        );
        (bool ok,) = address(entropy).staticcall(abi.encodeCall(entropy.entropyProviderAt, (1)));
        require(!ok);
    }

    function testExactContextClassAndAuthorityAreRequired() public {
        bytes memory data =
            abi.encodeCall(entropy.activateEntropyProvider, (address(provider), REASON));
        _refused(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash,) = entropy.entropyProviderTransition(
            address(provider), EntropyProviderState.ACTIVE, REASON
        );
        this.setCurrentAction(true, HASH, 0, scope, oldHash, newHash);
        _refused(data);
        this.setCurrentAction(true, HASH, 1, keccak256("wrong scope"), oldHash, newHash);
        _refused(data);
        this.setCurrentAction(true, HASH, 1, scope, oldHash, keccak256("wrong next"));
        _refused(data);
        this.setCurrentAction(true, HASH, 1, scope, oldHash, newHash);
        vm.prank(address(0xbeef));
        (bool ok,) = address(entropy).call(data);
        require(!ok);
        entropy.activateEntropyProvider(address(provider), REASON);
        require(entropy.entropyProviderRecord(address(provider)).lastActionId == HASH);
    }

    function testMalformedGovernanceResponsesFailClosedAndExactRetryWorks() public {
        bytes memory data = _context(EntropyProviderState.ACTIVE, HASH);
        for (uint8 i = 1; i <= 5; ++i) {
            this.setResponseMode(ResponseMode(i));
            _refused(data);
        }
        this.setResponseMode(ResponseMode.Canonical);
        entropy.activateEntropyProvider(address(provider), REASON);
        require(entropy.entropyProviderCount() == 1);
    }

    function testTransitionReplayAndStaleReasonCannotMutateState() public {
        bytes memory oldData = _context(EntropyProviderState.ACTIVE, HASH);
        entropy.activateEntropyProvider(address(provider), REASON);
        bytes memory data = _context(EntropyProviderState.DEPRECATED, HASH);
        _refused(data);
        _refused(oldData);
        _context(EntropyProviderState.DEPRECATED, keccak256("fresh"));
        _refused(
            abi.encodeCall(entropy.deprecateEntropyProvider, (address(provider), "changed reason"))
        );
        entropy.deprecateEntropyProvider(address(provider), REASON);
    }

    function testDeprecatedBlocksNewRequestsAndConfigsButPendingTokenAndScopeFulfill() public {
        _configured();
        core.registerToken(1, HASH);
        core.registerToken(2, HASH);
        bytes32 scope = entropy.registerEntropyScope(1, 0, HASH);
        (, uint256 tokenRequest) = entropy.requestEntropy(1);
        (, uint256 scopeRequest) = entropy.requestScopeEntropy(scope, HASH);
        _change(EntropyProviderState.DEPRECATED);
        _refused(abi.encodeCall(entropy.requestEntropy, (2)));
        _refused(
            abi.encodeCall(
                entropy.configureCollection, (2, address(provider), HASH, true, uint64(10))
            )
        );
        require(
            provider.fulfill(tokenRequest, HASH) == 0 && provider.fulfill(scopeRequest, HASH) == 0
        );
        require(entropy.pendingRequestCount() == 0);
    }

    function testIncidentRevocationRetainsOriginalOutputAndRestorationRetriesIt() public {
        _configured();
        core.registerToken(1, HASH);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        bytes32 policy = keccak256(abi.encode(entropy.requestPolicySnapshot(key)));
        _change(EntropyProviderState.INCIDENT_REVOKED);
        require(entropy.providerRevoked(address(provider)) && provider.fulfill(id, HASH) == 5);
        require(
            entropy.pendingRequestCount() == 1
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED
        );
        _change(EntropyProviderState.ACTIVE);
        require(!entropy.providerRevoked(address(provider)) && provider.fulfill(id, HASH) == 0);
        require(policy == keccak256(abi.encode(entropy.requestPolicySnapshot(key))));
        (bytes32 seed, bool final_) = entropy.tokenSeed(1);
        require(final_ && seed != 0);
        _change(EntropyProviderState.INCIDENT_REVOKED);
        require(provider.fulfill(id, HASH) == 3);
        (bytes32 retained, bool stillFinal) = entropy.tokenSeed(1);
        require(stillFinal && retained == seed);
    }

    function testCompatibilityRevocationRequiresItsOwnExactDelayedContext() public {
        _configured();
        bytes memory data = _context(EntropyProviderState.INCIDENT_REVOKED, HASH);
        _refused(abi.encodeCall(entropy.setProviderRevoked, (address(provider), true)));
        (bool ok,) = address(entropy).call(data);
        require(ok);
        _setEntropyProviderRevoked(address(entropy), address(provider), false);
        require(
            entropy.entropyProviderRecord(address(provider)).state == EntropyProviderState.ACTIVE
        );
    }

    function testRuntimeDriftRefusesNewRequestsAndCallbacksWithoutChangingRequest() public {
        _configured();
        core.registerToken(1, HASH);
        core.registerToken(2, HASH);
        (bytes32 key,) = entropy.requestEntropy(1);
        bytes memory original = address(provider).code;
        vm.etch(address(provider), hex"60006000fd");
        _refused(abi.encodeCall(entropy.requestEntropy, (2)));
        vm.prank(address(provider));
        require(entropy.fulfillEntropy(key, HASH) == 5);
        require(entropy.pendingRequestCount() == 1);
        vm.etch(address(provider), original);
        require(provider.fulfill(1, HASH) == 0);
    }

    function testSafeRequestAndPendingCallbackContinueAfterDeprecation() public {
        _configured();
        core.registerToken(1, HASH);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE01;
        keys[1] = 0x5AFE02;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 319);
        require(
            executeSafe(
                safe, keys, address(entropy), 0, abi.encodeCall(entropy.requestEntropy, (1)), 0
            )
        );
        _change(EntropyProviderState.DEPRECATED);
        require(provider.fulfill(1, HASH) == 0);
        require(entropy.pendingRequestCount() == 0);
    }

    function testFuzzProviderTransitionsNeverRewriteSavedRequest(bytes32 raw, bool incident)
        public
    {
        _configured();
        core.registerToken(1, HASH);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        bytes32 before = keccak256(abi.encode(entropy.requestPolicySnapshot(key)));
        _change(incident ? EntropyProviderState.INCIDENT_REVOKED : EntropyProviderState.DEPRECATED);
        uint8 outcome = provider.fulfill(id, raw);
        require(outcome == (incident ? 5 : 0));
        _change(EntropyProviderState.ACTIVE);
        require(provider.fulfill(id, raw) == (incident ? 0 : 3));
        require(before == keccak256(abi.encode(entropy.requestPolicySnapshot(key))));
        require(entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 2);
    }
}
