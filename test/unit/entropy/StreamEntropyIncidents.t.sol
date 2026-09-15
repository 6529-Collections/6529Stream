// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/parameters/StreamGasParameterStore.sol";

interface IncidentVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

/// @notice Real bounded-call adversary: gas exhaustion and oversized returndata are not cheat-code simulations.
contract IncidentProbeProvider {
    address public immutable coordinator;
    bytes32 private _key;
    uint8 public mode;

    constructor(address c) {
        coordinator = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamEntropyProvider).interfaceId
            || id == type(IStreamEntropyProviderFeeQuote).interfaceId || id == 0x01ffc9a7;
    }

    function isStreamEntropyProvider() external pure returns (bool) {
        return true;
    }

    function streamEntropyProviderConfigHash() external view returns (bytes32) {
        return keccak256(abi.encode(coordinator));
    }

    function contextIndependentRequestFee() external pure returns (uint256) {
        return 0;
    }

    function quoteRequest(bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function requestEntropy(bytes32 key, bytes calldata) external payable returns (uint256) {
        require(msg.sender == coordinator && msg.value == 0);
        _key = key;
        return 1;
    }

    function setMode(uint8 m) external {
        mode = m;
    }

    function providerResultStatus(uint256)
        external
        view
        returns (uint256, bytes32, bytes32, bool, bool)
    {
        uint8 m = mode;
        if (m == 1) assembly ("memory-safe") { for { } 1 { } { } }
        if (m == 2) {
            bytes memory bomb = new bytes(32768);
            assembly ("memory-safe") { return(add(bomb, 32), mload(bomb)) }
        }
        if (m == 3) revert("provider unavailable");
        return (1, _key, bytes32(0), false, false);
    }
}

/// @notice Actual coordinator and real Safe; Core, roles, provider and delayed-executor context are explicit unit seams.
contract StreamEntropyIncidentsTest is
    CharacterizationTestBase,
    OfficialSafeFixture,
    EntropyTimeAuthorityFixture
{
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant CAP = keccak256("6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT");
    bytes32 private constant EVIDENCE = keccak256("independent upstream incident evidence");
    string private constant REASON = "ipfs://bafyincident";
    IncidentVm private constant ivm = IncidentVm(address(vm));
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    OfficialSafe private keeper;
    uint256[] private keys;

    function setUp() public {
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
                EVIDENCE,
                "urn:test:entropy-incidents",
                EVIDENCE
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        entropy.configureCollection(1, address(provider), EVIDENCE, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        roleRegistry.setHolder(ROLE, address(this));
    }

    function _request() private returns (bytes32 key, uint256 id) {
        core.registerToken(1, EVIDENCE);
        return entropy.requestEntropy(1);
    }

    function _expire() private {
        vm.roll(111);
    }

    function _assertPending(bytes32 key) private view {
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED);
        require(entropy.pendingRequestCount() == 1 && entropy.nonterminalTokenCount(1) == 1);
        require(entropy.entropyIncident(key).declarer == address(0));
    }

    function _fail(bytes4 expected) private {
        ivm.expectRevert(expected);
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
    }

    function testTokenIncidentRetainsEvidenceEventsAndNeverRedraws() public {
        (bytes32 key, uint256 id) = _request();
        _expire();
        vm.recordLogs();
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool seen;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "EntropyRequestFailed(uint16,uint256,uint256,address,bytes32,uint32,uint16,string,bytes32)"
                    )
            ) {
                require(logs[i].emitter == address(entropy));
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(1))
                );
                require(logs[i].topics[3] == bytes32(uint256(uint160(address(provider)))));
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), key, uint32(1), uint16(1), REASON, EVIDENCE)
                        )
                );
                seen = true;
            }
        }
        require(seen && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0);
        IStreamEntropyIncidents.Incident memory item = entropy.entropyIncident(key);
        require(
            item.declarer == address(this) && item.declaredAtBlock == 111
                && item.evidenceHash == EVIDENCE
        );
        require(keccak256(bytes(item.reasonURI)) == keccak256(bytes(REASON)));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(seed == 0 && !finalized);
        ivm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FAILED
            )
        );
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        ivm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FAILED
            )
        );
        entropy.requestEntropy(1);
        require(provider.fulfill(id, EVIDENCE) != 0);
        (seed, finalized) = entropy.tokenSeed(1);
        require(seed == 0 && !finalized);
    }

    function testScopeUsesOriginalSubjectAndItsOwnFailureEvent() public {
        bytes32 scope = entropy.registerEntropyScope(1, 0, EVIDENCE);
        (bytes32 key,) = entropy.requestScopeEntropy(scope, EVIDENCE);
        _expire();
        vm.recordLogs();
        entropy.markEntropyScopeRequestUnrecoverable(scope, REASON, EVIDENCE);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2
                && logs[1].topics[0]
                    == keccak256(
                        "EntropyScopeRequestFailed(uint16,uint256,bytes32,address,bytes32,uint32,uint16,string,bytes32)"
                    )
        );
        require(logs[1].topics[2] == scope && entropy.entropyIncident(key).evidenceHash == EVIDENCE);
        require(entropy.scopeEntropy(scope).status == StreamEntropyStatus.FAILED);
        require(entropy.nonterminalTokenCount(1) == 0 && entropy.pendingRequestCount() == 0);
        ivm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FAILED
            )
        );
        entropy.requestScopeEntropy(scope, keccak256("replacement"));
        require(entropy.scopeEntropy(scope).inputsHash == EVIDENCE);
    }

    function testTimeoutIsStrictAndRevocationOnlySkipsClock() public {
        (bytes32 key,) = _request();
        vm.roll(110);
        _fail(StreamEntropyCoordinator.RequestNotExpired.selector);
        _assertPending(key);
        entropy.setProviderRevoked(address(provider), true);
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FAILED);
    }

    function testRoleIsResolvedAtCallTimeAndAuthorityIsNotAnExemption() public {
        (bytes32 key,) = _request();
        _expire();
        roleRegistry.setHolder(ROLE, address(0));
        ivm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(this))
        );
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        _assertPending(key);
        roleRegistry.setHolder(ROLE, address(this));
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
    }

    function testSafeRoleCanDeclareOnlyAfterRoleAssignment() public {
        (bytes32 key,) = _request();
        _expire();
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        keeper = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 119);
        bytes memory callData =
            abi.encodeCall(entropy.markEntropyRequestUnrecoverable, (1, REASON, EVIDENCE));
        ivm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeIncidentSafe(callData);
        _assertPending(key);
        roleRegistry.setHolder(ROLE, address(keeper));
        require(executeSafe(keeper, keys, address(entropy), 0, callData, 0));
        require(entropy.entropyIncident(key).declarer == address(keeper));
    }

    // One external boundary makes the expected Safe revert independent of preparatory nonce/digest reads.
    function executeIncidentSafe(bytes calldata callData) external returns (bool) {
        require(msg.sender == address(this));
        return executeSafe(keeper, keys, address(entropy), 0, callData, 0);
    }

    function testEvidenceAndReasonAreRequiredAndBounded() public {
        (bytes32 key,) = _request();
        _expire();
        ivm.expectRevert(IStreamEntropyIncidents.InvalidIncidentEvidence.selector);
        entropy.markEntropyRequestUnrecoverable(1, REASON, 0);
        ivm.expectRevert(IStreamEntropyIncidents.InvalidIncidentEvidence.selector);
        entropy.markEntropyRequestUnrecoverable(1, "", EVIDENCE);
        ivm.expectRevert(IStreamEntropyIncidents.InvalidIncidentEvidence.selector);
        entropy.markEntropyRequestUnrecoverable(1, string(new bytes(2049)), EVIDENCE);
        _assertPending(key);
    }

    function testUnknownAndWrongSubjectCannotConsumeAnIncident() public {
        (bytes32 key,) = _request();
        _expire();
        ivm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidSubject.selector, key)
        );
        entropy.markEntropyScopeRequestUnrecoverable(key, REASON, EVIDENCE);
        ivm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.NONE
            )
        );
        entropy.markEntropyRequestUnrecoverable(2, REASON, EVIDENCE);
        _assertPending(key);
    }

    function testFinalizedAndReceivedZeroRandomnessAreNeverNegativeEvidence() public {
        (, uint256 id) = _request();
        require(provider.fulfill(id, 0) == 0);
        _expire();
        ivm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FINALIZED
            )
        );
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
    }

    function testReceivedOutputBlocksEvenAfterProviderRevocation() public {
        (bytes32 key, uint256 id) = _request();
        entropy.setProviderRevoked(address(provider), true);
        require(provider.fulfill(id, 0) != 0);
        _fail(IStreamEntropyIncidents.IncidentProviderProbeFailed.selector);
        _assertPending(key);
    }

    function testProbeRejectsShortOversizedAndWrongKeyReports() public {
        (bytes32 key, uint256 id) = _request();
        _expire();
        bytes memory data = abi.encodeCall(provider.providerResultStatus, (id));
        ivm.mockCall(address(provider), data, new bytes(159));
        _fail(IStreamEntropyIncidents.IncidentProviderProbeFailed.selector);
        ivm.mockCall(address(provider), data, new bytes(192));
        _fail(IStreamEntropyIncidents.IncidentProviderProbeFailed.selector);
        ivm.mockCall(
            address(provider),
            data,
            abi.encode(uint256(1), bytes32(uint256(88)), bytes32(0), uint256(0), uint256(0))
        );
        _fail(IStreamEntropyIncidents.IncidentProviderProbeFailed.selector);
        _assertPending(key);
        ivm.clearMockedCalls();
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
    }

    function testFuzzOnlyCanonicalNegativeProviderReportsCanClose(
        uint8 status,
        uint8 received,
        uint8 delivered,
        bytes32 rawHash
    ) public {
        (bytes32 key, uint256 id) = _request();
        _expire();
        ivm.mockCall(
            address(provider),
            abi.encodeCall(provider.providerResultStatus, (id)),
            abi.encode(uint256(status), key, rawHash, uint256(received), uint256(delivered))
        );
        bool allowed = (status == 1 || status == 4 || status == 5) && received == 0
            && delivered == 0 && rawHash == 0;
        (bool ok,) = address(entropy)
            .call(abi.encodeCall(entropy.markEntropyRequestUnrecoverable, (1, REASON, EVIDENCE)));
        require(ok == allowed);
        if (!allowed) _assertPending(key);
    }

    function testCanonicalFailedProviderReportIsAccepted() public {
        (bytes32 key, uint256 id) = _request();
        _expire();
        provider.fail(id);
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        require(entropy.entropyIncident(key).evidenceHash == EVIDENCE);
    }

    function testRealProbeOutOfGasRevertAndReturnBombRollBackAndPermitRetry() public {
        IncidentProbeProvider adversary = new IncidentProbeProvider(address(entropy));
        entropy.configureCollection(1, address(adversary), EVIDENCE, true, 10);
        (bytes32 key,) = _request();
        _expire();
        for (uint8 mode = 1; mode <= 3; ++mode) {
            adversary.setMode(mode);
            _fail(IStreamEntropyIncidents.IncidentProviderProbeFailed.selector);
            _assertPending(key);
        }
        adversary.setMode(0);
        entropy.markEntropyRequestUnrecoverable(1, REASON, EVIDENCE);
        require(entropy.entropyIncident(key).evidenceHash == EVIDENCE);
    }

    function testGovernedProbeBudgetUsesCanonicalCommitmentsAndReplayRules() public {
        IStreamGasParameterHost.GasParameterConfig[] memory rows =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        rows[0] = IStreamGasParameterHost.GasParameterConfig(
            "ENTROPY_RESULT_PROBE_GAS_LIMIT", 100000, 100000, 1
        );
        StreamGasParameterStore canonical = new StreamGasParameterStore(address(this), rows);
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            entropy.gasParameterInfo(CAP);
        (uint256 cv, uint256 cf, uint8 cc, uint64 cr) = canonical.gasParameterInfo(CAP);
        require(value == cv && floor == cf && failureClass == cc && revision == cr);
        require(entropy.gasParameterIds().length == 1 && entropy.gasParameterIds()[0] == CAP);
        require(
            entropy.supportsInterface(type(IStreamEntropyIncidents).interfaceId)
                && entropy.supportsInterface(type(IStreamGasParameterHost).interfaceId)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            entropy.gasParameterTransition(CAP, 200000);
        bytes32 expectedScope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(entropy),
                CAP
            )
        );
        require(scope == expectedScope);
        bytes32 stateDomain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        require(
            oldHash
                == keccak256(abi.encode(stateDomain, scope, value, floor, failureClass, revision))
        );
        require(
            newHash
                == keccak256(
                    abi.encode(stateDomain, scope, uint256(200000), floor, failureClass, uint64(2))
                )
        );
        ivm.expectRevert(IStreamGasParameterHost.GasParameterActionNotExecuting.selector);
        entropy.raiseGasParameter(CAP, 200000);
        this.setCurrentAction(true, EVIDENCE, 1, scope, oldHash, newHash);
        entropy.raiseGasParameter(CAP, 200000);
        require(entropy.gasParameter(CAP) == 200000);
        (scope, oldHash, newHash) = entropy.gasParameterTransition(CAP, 300000);
        this.setCurrentAction(true, EVIDENCE, 1, scope, oldHash, newHash);
        ivm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionAlreadyApplied.selector, CAP, EVIDENCE
            )
        );
        entropy.raiseGasParameter(CAP, 300000);
    }
}
