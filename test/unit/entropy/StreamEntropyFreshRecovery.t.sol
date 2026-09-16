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

interface RecoveryVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Explicit Artist boundary; actual original Artist consent admission has a separate suite.
contract RecoveryArtistFixture {
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

/// @notice Actual coordinator/workers/Safe; Core, Artist, role and provider boundaries are explicit fixtures.
contract StreamEntropyFreshRecoveryTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant HASH = keccak256("independent provider evidence");
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private first;
    MockStreamEntropyProvider private fallbackProvider;
    MockEntropyRoleRegistry public roleRegistry;
    RecoveryArtistFixture private artist;

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
        first = new MockStreamEntropyProvider(address(entropy));
        fallbackProvider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(first));
        _admitEntropyProvider(address(entropy), address(fallbackProvider));
        entropy.configureCollection(1, address(first), HASH, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
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
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            entropy.freshRecoveryPolicyTransition(id, hash, false);
        this.setCurrentAction(true, bytes32(uint256(101)), 1, scope, oldHash, next);
        entropy.configureFreshRecoveryPolicy(id, 2, ROLE, HASH, HASH, steps);
        (scope, oldHash, next) = entropy.freshRecoveryPolicyTransition(id, hash, true);
        this.setCurrentAction(true, bytes32(uint256(102)), 1, scope, oldHash, next);
        entropy.freezeFreshRecoveryPolicy(id);
        (scope, oldHash, next) = entropy.collectionFreshRecoveryTransition(1, 2, id);
        this.setCurrentAction(true, bytes32(uint256(103)), 1, scope, oldHash, next);
        entropy.configureCollectionFreshRecovery(1, 2, id);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        roleRegistry.setHolder(ROLE, address(this));
        artist = new RecoveryArtistFixture(address(core));
        RecoveryVm(address(vm))
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

    function testExactTokenRequestPolicyArtistStateAndEvidenceEvents() public {
        (bytes32 old,) = _failedToken();
        (bytes32 expected, bytes32 state) = _approve(old);
        bytes32 independent = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                uint256(1),
                address(fallbackProvider),
                uint32(3),
                fallbackProvider.streamEntropyProviderConfigHash(),
                uint16(2)
            )
        );
        require(expected == independent);
        vm.recordLogs();
        (bytes32 key, uint256 id) = entropy.requestFreshEntropy(_input(old));
        require(key == expected && id == 1);
        require(entropy.pendingRequestCount() == 1 && entropy.nonterminalTokenCount(1) == 1);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED);
        IStreamEntropyEpochs.RequestPolicySnapshot memory saved = entropy.requestPolicySnapshot(key);
        require(saved.requestAttempt == 2 && saved.providerEpoch == 3 && saved.inputsHash == HASH);
        F.RecoveryReceipt memory receipt = entropy.freshRecoveryReceipt(key);
        require(
            receipt.previousRequestKey == old && receipt.contentStateHash == state
                && receipt.artistRecordHash != 0
        );
        bytes32 evidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RECOVERY_EVIDENCE_V1"),
                HASH,
                HASH,
                receipt.artistRecordHash,
                old,
                key,
                state,
                keccak256(bytes(_input(old).reasonURI))
            )
        );
        require(receipt.evidenceHash == evidence);
        (, bytes32 actual) = entropy.artistContentFamilyState(1, FAMILY);
        require(actual == state);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs[0].topics[0]
                == keccak256(
                    "EntropyRecoveryRequested(uint16,uint256,uint256,address,address,bytes32,bytes32,uint32,uint32,string,bytes32)"
                )
        );
        require(
            logs[0].topics[1] == bytes32(uint256(1))
                && logs[0].topics[3] == bytes32(uint256(uint160(address(first))))
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        address(fallbackProvider),
                        old,
                        key,
                        uint32(2),
                        uint32(3),
                        _input(old).reasonURI,
                        evidence
                    )
                )
        );
    }

    function testMissingConsentWrongEvidenceWrongRoleAndNoIncidentFailAtomically() public {
        core.registerToken(1, HASH);
        (bytes32 old,) = entropy.requestEntropy(1);
        _refused(_input(old), 0);
        vm.roll(111);
        entropy.markEntropyRequestUnrecoverable(1, "urn:test:incident", HASH);
        vm.roll(122);
        _refused(_input(old), 0);
        _approve(old);
        F.RecoveryInput memory changed = _input(old);
        changed.providerEvidenceHash = keccak256("changed evidence");
        _refused(changed, 0);
        roleRegistry.setHolder(ROLE, address(0xbeef));
        _refused(_input(old), 0);
        roleRegistry.setHolder(ROLE, address(this));
        entropy.requestFreshEntropy(_input(old));
    }

    function testDelayProviderDriftAndReceivedOriginalBlockRecovery() public {
        (bytes32 old, uint256 id) = _failedToken();
        vm.roll(121);
        _refused(_input(old), 0);
        vm.roll(122);
        _approve(old);
        _setEntropyProviderRevoked(address(entropy), address(fallbackProvider), true);
        _refused(_input(old), 0);
        _setEntropyProviderRevoked(address(entropy), address(fallbackProvider), false);
        require(first.fulfill(id, bytes32(uint256(7))) == 2);
        _refused(_input(old), 0);
    }

    function testScopeReusesOriginalInputsAndConsumesDistinctArtistEvidence() public {
        bytes32 scope = entropy.registerEntropyScope(1, 1, HASH);
        (bytes32 old,) = entropy.requestScopeEntropy(scope, keccak256("sealed scope inputs"));
        vm.roll(111);
        entropy.markEntropyScopeRequestUnrecoverable(scope, "urn:test:scope", HASH);
        vm.roll(122);
        _approve(old);
        (bytes32 key, uint256 id) = entropy.requestFreshEntropy(_input(old));
        require(entropy.requestPolicySnapshot(key).inputsHash == keccak256("sealed scope inputs"));
        require(entropy.nonterminalTokenCount(1) == 0 && entropy.pendingRequestCount() == 1);
        require(fallbackProvider.fulfill(id, bytes32(uint256(8))) == 0);
        require(entropy.scopeEntropy(scope).status == StreamEntropyStatus.FINALIZED);
    }

    function testFeeEscrowExcessAndProviderReentryRollbackPermitExactRetry() public {
        (bytes32 old,) = _failedToken();
        fallbackProvider.setFee(17);
        _approve(old);
        vm.deal(address(this), 100);
        entropy.fundRevealFeeEscrow{ value: 7 }(1);
        fallbackProvider.setReenterOnRequest(true);
        _refused(_input(old), 15);
        require(entropy.revealFeeEscrow(1) == 7 && entropy.totalFeeCredits() == 0);
        fallbackProvider.setReenterOnRequest(false);
        entropy.requestFreshEntropy{ value: 15 }(_input(old));
        require(entropy.revealFeeEscrow(1) == 0 && entropy.totalRevealFeeEscrows() == 0);
        require(entropy.entropyFeeCredit(address(this)) == 5 && entropy.totalFeeCredits() == 5);
        require(address(entropy).balance == 5 && address(fallbackProvider).balance == 17);
    }

    function testStaleOriginalNeverFinalizesAndOldTerminalCallsCannotCloseNewRequest() public {
        (bytes32 old, uint256 id) = _failedToken();
        _approve(old);
        (bytes32 key, uint256 freshId) = entropy.requestFreshEntropy(_input(old));
        require(first.fulfill(id, bytes32(uint256(7))) == 1);
        (bool ok,) = address(entropy).call(abi.encodeCall(entropy.markRequestStale, (old)));
        require(!ok);
        (ok,) = address(entropy).call(abi.encodeCall(entropy.markRequestFailed, (old)));
        require(!ok);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED
                && entropy.pendingRequestCount() == 1
        );
        require(fallbackProvider.fulfill(freshId, bytes32(uint256(8))) == 0);
        require(entropy.requestPolicySnapshot(key).requestAttempt == 2);
        _refused(_input(key), 0);
    }

    function testAllowedLateOriginalWinsOnceAndDisplacesPendingFallback() public {
        _deploy(true);
        (bytes32 old, uint256 id) = _failedToken();
        _approve(old);
        (, uint256 freshId) = entropy.requestFreshEntropy(_input(old));
        require(first.fulfill(id, bytes32(uint256(7))) == 0);
        (bytes32 seed,) = entropy.tokenSeed(1);
        require(fallbackProvider.fulfill(freshId, bytes32(uint256(8))) == 3);
        (bytes32 after_,) = entropy.tokenSeed(1);
        require(seed == after_);
        require(entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0);
        (,,,,, bytes32 winner,,) = entropy.tokenEntropy(1);
        require(winner == old);
    }

    function testOrderedSecondStepAndMaximumAttempts() public {
        (bytes32 old,) = _failedToken();
        _approve(old);
        (bytes32 second,) = entropy.requestFreshEntropy(_input(old));
        vm.roll(133);
        entropy.markEntropyRequestUnrecoverable(1, "urn:test:second incident", HASH);
        vm.roll(144);
        _approve(second);
        (bytes32 third,) = entropy.requestFreshEntropy(_input(second));
        require(
            entropy.requestPolicySnapshot(third).requestAttempt == 3
                && entropy.requestPolicySnapshot(third).providerEpoch == 4
        );
        vm.roll(155);
        entropy.markEntropyRequestUnrecoverable(1, "urn:test:third incident", HASH);
        vm.roll(166);
        _refused(_input(third), 0);
    }

    function testStillEligibleAncestorOutputBlocksAnotherFreshDraw() public {
        _deploy(true);
        (bytes32 old, uint256 id) = _failedToken();
        _approve(old);
        (bytes32 second,) = entropy.requestFreshEntropy(_input(old));
        vm.roll(133);
        entropy.markEntropyRequestUnrecoverable(1, "urn:test:second incident", HASH);
        vm.roll(144);
        require(first.fulfill(id, bytes32(uint256(99))) == 2);
        _refused(_input(second), 0);
    }

    function testExplicitUnboundAttributionNeedsNoArtistRecordAndBurnedTokenCannotRecover() public {
        (bytes32 old,) = _failedToken();
        artist.setBound(false);
        core.burnToken(1);
        _refused(_input(old), 0);
        // A scope remains a separate registered subject and has no burned-token lifecycle.
        bytes32 scope = entropy.registerEntropyScope(1, 0, keccak256("unbound scope"));
        (bytes32 scoped,) = entropy.requestScopeEntropy(scope, HASH);
        vm.roll(133);
        entropy.markEntropyScopeRequestUnrecoverable(scope, "urn:test:scope", HASH);
        vm.roll(144);
        (bytes32 next,) = entropy.requestFreshEntropy(_input(scoped));
        require(entropy.freshRecoveryReceipt(next).artistRecordHash == 0);
    }

    function testThresholdSafeOwnsItsAttachedFeeAndUnusedCredit() public {
        (bytes32 old,) = _failedToken();
        fallbackProvider.setFee(10);
        _approve(old);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5afe21;
        keys[1] = 0x5afe22;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 521);
        roleRegistry.setHolder(ROLE, address(safe));
        vm.deal(address(safe), 15);
        require(
            executeSafe(
                safe,
                keys,
                address(entropy),
                15,
                abi.encodeCall(F.requestFreshEntropy, (_input(old))),
                0
            )
        );
        require(
            entropy.entropyFeeCredit(address(safe)) == 5
                && entropy.entropyFeeCredit(address(this)) == 0
        );
    }

    function testFuzzFinalizedRecoveryCannotChangeSeed(bytes32 firstRaw, bytes32 secondRaw) public {
        (bytes32 old,) = _failedToken();
        _approve(old);
        (, uint256 id) = entropy.requestFreshEntropy(_input(old));
        require(fallbackProvider.fulfill(id, firstRaw) == 0);
        (bytes32 before_,) = entropy.tokenSeed(1);
        vm.prank(address(fallbackProvider));
        (,,,,, bytes32 key,,) = entropy.tokenEntropy(1);
        vm.prank(address(fallbackProvider));
        require(entropy.fulfillEntropy(key, secondRaw) == 3);
        (bytes32 after_,) = entropy.tokenSeed(1);
        require(before_ == after_);
    }
}
