// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockVRFCoordinatorV2Plus.sol";
import "./EntropyPolicySuccessorFixtures.sol";
import { ARRNGControllerFaults } from "./StreamEntropyProviderARRNG.t.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as O
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";

/// @notice Actual Coordinators, import/relay workers and production ARRNG/VRF adapters.
/// @dev The ARRNG controller and Chainlink service are local ABI/callback mocks; there is no
/// oracle, subscription or external-network proof. Core pointers/token identity, Artist, registry
/// eligibility and executing governance are typed unit fixtures, not actual Core/Safe flows.
/// Policies use the real legacy configuration surface; no Artist signature claim is made.
contract StreamEntropyProductionProviderRelayTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture
{
    bytes32 private constant HASH = keccak256("production adapter relay fixture");
    bytes32 private constant SALT = keccak256("production adapter relay salt");
    bytes32 private constant COMMITMENT = keccak256("production adapter delivery commitment");
    bytes32 private constant AUTH = keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
    bytes32 private constant DELIVERY =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_DELIVERY_GAS_LIMIT");
    uint256 private constant ARRNG_FEE = 100;
    uint256 private constant SUBSCRIPTION = uint256(type(uint64).max) + 100;

    EntropyPolicySuccessorCoreFixture private core;
    EntropyCollectionPolicyArtistFixture private artist;
    EntropySuccessorModuleFixture private modules;
    MockEntropyRoleRegistry public roleRegistry;
    StreamEntropyCoordinator private source;
    StreamEntropyCoordinator private successor;
    ARRNGControllerFaults private arrngService;
    MockVRFCoordinatorV2Plus private vrfService;
    StreamEntropyProviderARRNG private arrng;
    StreamEntropyProviderVRF private vrf;
    uint256 private _actionNonce;

    struct Request {
        bool isArrng;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 key;
        uint256 id;
        bytes32 relayId;
    }

    event log_named_uint(string key, uint256 value);

    function setUp() public {
        vm.roll(100);
        vm.deal(address(this), 100 ether);
        core = new EntropyPolicySuccessorCoreFixture();
        artist = new EntropyCollectionPolicyArtistFixture(address(core));
        modules = new EntropySuccessorModuleFixture(address(this));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        source = _deploy();
        core.wire(source, address(artist), address(modules));
        arrngService = new ARRNGControllerFaults();
        vrfService = new MockVRFCoordinatorV2Plus();
        arrng = new StreamEntropyProviderARRNG(
            StreamEntropyProviderARRNG.Config(
                address(source),
                address(this),
                address(arrngService),
                address(arrngService).codehash,
                arrngService.owner(),
                arrngService.oracleAddress(),
                address(this),
                ARRNG_FEE,
                500000
            ),
            HASH,
            "urn:test:production-arrng-relay",
            HASH
        );
        vrf = new StreamEntropyProviderVRF(
            StreamEntropyProviderVRF.Config(
                address(source),
                address(this),
                address(vrfService),
                SUBSCRIPTION,
                keccak256("relay VRF key"),
                3,
                500000,
                2500000,
                true
            ),
            HASH,
            "urn:test:production-vrf-relay",
            HASH
        );
        _admitProviders(source);
        source.configureCollection(1, address(arrng), SALT, true, 10);
        source.configureCollectionRevealPolicy(
            1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, ARRNG_FEE
        );
        source.configureCollection(2, address(vrf), SALT, true, 10);
        source.configureCollectionRevealPolicy(2, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        successor = _candidate();
        _migrate(source, successor);
    }

    function testARRNGOriginalCallerIdKeyContextAndSuccessfulRelay() public {
        _successfulRelay(true);
    }

    function testVRFOriginalCallerIdKeyContextAndSuccessfulRelay() public {
        _successfulRelay(false);
    }

    function testARRNGZeroUpstreamWordRetainedAcrossFailedDeliveryAndExactRetry() public {
        _zeroWordRetry(true);
    }

    function testVRFZeroUpstreamWordRetainedAcrossFailedDeliveryAndExactRetry() public {
        _zeroWordRetry(false);
    }

    function testARRNGOldSuccessorCallbackAfterZeroPendingOnwardReplacement() public {
        _onward(true);
    }

    function testVRFOldSuccessorCallbackAfterZeroPendingOnwardReplacement() public {
        _onward(false);
    }

    function _successfulRelay(bool isArrng) private {
        uint256 cid = isArrng ? 1 : 2;
        core.registerToken(cid, cid, COMMITMENT);
        Request memory r = _request(isArrng, cid);
        _directSuccessorDenied(r);
        bytes32 raw = _raw(r, 42);
        _callbackAndCapture(r, 42, raw);
        _retryAndAssertFinal(r, raw);
        require(address(source).balance == 0 && address(successor).balance == 0, "no retained fee");
        if (isArrng) {
            require(address(arrngService).balance == ARRNG_FEE && address(arrng).balance == 0);
        } else {
            require(address(vrfService).balance == 0 && address(vrf).balance == 0);
        }
    }

    function _zeroWordRetry(bool isArrng) private {
        uint256 cid = isArrng ? 1 : 2;
        core.registerToken(cid, cid, COMMITMENT);
        Request memory r = _request(isArrng, cid);
        // Production adapters hash the word array: zero upstream is not a claim of zero relay raw.
        bytes32 raw = _raw(r, 0);
        _callbackAndCapture(r, 0, raw);
        uint256 requestsBefore = _upstreamCount(isArrng);
        EntropySuccessorVm(address(vm))
            .mockCallRevert(
                address(successor),
                abi.encodeCall(O.fulfillRelayedEntropy, (r.key, r.relayId, raw)),
                abi.encodeWithSignature("SuccessorTransportUnavailable()")
            );
        (bool delivered, uint8 outcome) = O(address(source)).retryEntropyRelay(r.relayId);
        require(!delivered && outcome == 4, "failed transport remains retryable");
        O.RelayResult memory pending = O(address(source)).entropyRelayResult(r.relayId);
        require(
            pending.rawReceived && pending.raw == raw && !pending.delivered
                && !pending.terminalStale
        );
        require(successor.pendingRequestCount() == 1 && successor.nonterminalTokenCount(cid) == 1);
        require(core.metadataNotifications() == 0 && _upstreamCount(isArrng) == requestsBefore);
        EntropySuccessorVm(address(vm)).clearMockedCalls();
        _retryAndAssertFinal(r, raw);
        // A repeated upstream callback cannot replace the accepted word or request another draw.
        _callback(r, 999);
        O(address(source)).retryEntropyRelay(r.relayId);
        O.RelayResult memory finalResult = O(address(source)).entropyRelayResult(r.relayId);
        require(
            finalResult.raw == raw && finalResult.delivered
                && _upstreamCount(isArrng) == requestsBefore
        );
        _adapterStatus(r, StreamProviderResultStatus.DELIVERED, raw);
        _assertFinal(r, raw);
        require(core.metadataNotifications() == 1, "finality and notification exactly once");
    }

    function _onward(bool isArrng) private {
        uint256 cid = isArrng ? 1 : 2;
        core.registerToken(cid, cid, COMMITMENT);
        require(successor.pendingRequestCount() == 0, "no pending request at replacement");
        StreamEntropyCoordinator third = _candidate();
        _migrate(successor, third);
        require(address(core.selected()) == address(third) && core.pointerRevision() == 3);
        require(C(address(third)).exportEntropyPolicy(cid).policyOrigin == address(source));
        // Request the already registered old subject only after the zero-pending handoff.
        // The typed Core does not stand in for the actual Core's replacement admission gate.
        Request memory r = _request(isArrng, cid);
        bytes32 raw = _raw(r, 73);
        _callbackAndCapture(r, 73, raw);
        _retryAndAssertFinal(r, raw);
        require(core.coordinatorAtMint(cid) == address(successor));
        require(third.tokenEntropyStatus(cid) == StreamEntropyStatus.NONE);
        require(source.tokenEntropyStatus(cid) == StreamEntropyStatus.NONE);
        require(C(address(successor)).entropyPolicyImport().state == C.ImportState.ACTIVE);
        require(address(core.selected()) == address(third), "callback does not restore old pointer");
    }

    function _request(bool isArrng, uint256 tokenId) private returns (Request memory r) {
        r.isArrng = isArrng;
        r.collectionId = isArrng ? 1 : 2;
        r.tokenId = tokenId;
        vm.recordLogs();
        uint256 before = gasleft();
        (r.key, r.id) = successor.requestEntropy{ value: isArrng ? ARRNG_FEE : 0 }(tokenId);
        emit log_named_uint(
            isArrng ? "ARRNG nested relay submit gas" : "VRF nested relay submit gas",
            before - gasleft()
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = successor.requestPolicySnapshot(r.key);
        require(p.inputsHash == COMMITMENT && p.requestAttempt == 1, "original snapshot");
        require(
            r.key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                        block.chainid,
                        address(successor),
                        address(core),
                        r.collectionId,
                        tokenId,
                        p.provider,
                        p.providerEpoch,
                        p.providerConfigHash,
                        p.requestAttempt
                    )
                ),
            "original key preimage"
        );
        bytes32 contextHash = keccak256(_context(r, p));
        r.relayId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RELAY_V1"),
                block.chainid,
                address(source),
                address(successor),
                address(successor).codehash,
                C(address(successor)).entropyPolicyImport().importHash,
                r.collectionId,
                r.key,
                contextHash
            )
        );
        O.RelayResult memory result = O(address(source)).entropyRelayResult(r.relayId);
        require(result.submitted && !result.rawReceived && !result.delivered);
        require(result.successor == address(successor) && result.successorRequestKey == r.key);
        require(result.provider == _provider(isArrng) && result.providerRequestId == r.id);
        require(result.contextHash == contextHash && result.relayId == r.relayId);
        require(
            result.providerCodeHash == p.providerCodeHash
                && result.providerConfigHash == p.providerConfigHash
        );
        require(successor.providerRequestKeys(_provider(isArrng), r.id) == r.key);
        require(
            source.providerRequestKeys(_provider(isArrng), r.id) == 0
                && source.pendingRequestCount() == 0
        );
        require(
            successor.pendingRequestCount() == 1
                && source.tokenEntropyStatus(tokenId) == StreamEntropyStatus.NONE
        );
        _adapterStatus(r, StreamProviderResultStatus.REQUESTED, 0);
        _adapterContext(logs, r, contextHash);
        if (isArrng) {
            require(
                arrng.coordinator() == address(source) && arrng.keyToArrngRequest(r.key) == r.id
            );
            require(
                r.id == arrngService.arrngRequestId()
                    && arrngService.refundAddress() == address(arrng)
            );
        } else {
            require(vrf.coordinator() == address(source) && vrf.keyToVrfRequest(r.key) == r.id);
            require(
                vrfService.consumers(r.id) == address(vrf) && vrfService.nextRequestId() == r.id + 1
            );
            IVRFCoordinatorV2Plus.RandomWordsRequest memory upstream = vrfService.lastRequest();
            require(upstream.subId == SUBSCRIPTION && upstream.keyHash == vrf.keyHash());
            require(
                upstream.requestConfirmations == 3 && upstream.callbackGasLimit == 500000
                    && upstream.numWords == 1
            );
            require(
                keccak256(upstream.extraArgs)
                    == keccak256(abi.encodeWithSelector(bytes4(0x92fd1338), true))
            );
        }
        _measureAuthReads(r, p);
    }

    function _directSuccessorDenied(Request memory r) private {
        uint256 before = _upstreamCount(r.isArrng);
        bytes32 key = keccak256("unauthorized successor direct key");
        if (r.isArrng) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamEntropyProviderARRNG.ARRNGUnauthorized.selector, address(successor)
                )
            );
            vm.prank(address(successor));
            arrng.requestEntropy(key, hex"01");
            require(arrng.keyToArrngRequest(key) == 0);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamEntropyProviderVRF.Unauthorized.selector, address(successor)
                )
            );
            vm.prank(address(successor));
            vrf.requestEntropy(key, hex"01");
            require(vrf.keyToVrfRequest(key) == 0);
        }
        require(_upstreamCount(r.isArrng) == before, "direct caller rejected before upstream");
    }

    function _callbackAndCapture(Request memory r, uint256 word, bytes32 raw) private {
        _callback(r, word);
        O.RelayResult memory result = O(address(source)).entropyRelayResult(r.relayId);
        require(
            result.rawReceived && result.raw == raw && !result.delivered && !result.terminalStale
        );
        // The unchanged provider callback envelope cannot supply the full nested 500k host cap.
        // Origin ACK means durable capture; permissionless relay retry performs successor delivery.
        _adapterStatus(r, StreamProviderResultStatus.DELIVERED, raw);
        require(successor.tokenEntropyStatus(r.tokenId) == StreamEntropyStatus.REQUESTED);
        require(successor.pendingRequestCount() == 1 && core.metadataNotifications() == 0);
    }

    function _callback(Request memory r, uint256 word) private {
        uint256 before = gasleft();
        if (r.isArrng) {
            uint256[] memory words = new uint256[](1);
            words[0] = word;
            (bool ok,) = arrngService.deliver(arrng, r.id, words, 0, 1000000);
            require(ok, "ARRNG service callback accepted");
        } else {
            (bool ok, uint256 used) = vrfService.fulfill(r.id, word);
            require(ok, "VRF service callback accepted");
            emit log_named_uint("VRF service callback measured gas", used);
        }
        emit log_named_uint(
            r.isArrng
                ? "ARRNG callback plus origin capture gas"
                : "VRF callback plus origin capture gas",
            before - gasleft()
        );
    }

    function _retryAndAssertFinal(Request memory r, bytes32 raw) private {
        uint256 requestsBefore = _upstreamCount(r.isArrng);
        uint256 before = gasleft();
        vm.prank(address(0xBEEF));
        (bool delivered, uint8 outcome) = O(address(source)).retryEntropyRelay(r.relayId);
        emit log_named_uint(
            r.isArrng
                ? "ARRNG origin retry plus successor finalization gas"
                : "VRF origin retry plus successor finalization gas",
            before - gasleft()
        );
        require(delivered && outcome == 0 && _upstreamCount(r.isArrng) == requestsBefore);
        O.RelayResult memory result = O(address(source)).entropyRelayResult(r.relayId);
        require(
            result.rawReceived && result.delivered && result.raw == raw && !result.terminalStale
        );
        require(
            successor.pendingRequestCount() == 0
                && successor.nonterminalTokenCount(r.collectionId) == 0
        );
        require(source.pendingRequestCount() == 0 && core.metadataNotifications() == 1);
        _assertFinal(r, raw);
    }

    function _assertFinal(Request memory r, bytes32 raw) private view {
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = successor.requestPolicySnapshot(r.key);
        StreamEntropyCoordinator.SeedInputs memory expected = StreamEntropyCoordinator.SeedInputs(
            keccak256("6529STREAM_ENTROPY_SEED_V1"),
            block.chainid,
            address(successor),
            address(core),
            r.collectionId,
            bytes32(r.tokenId),
            p.provider,
            p.providerEpoch,
            p.providerConfigHash,
            r.key,
            r.id,
            raw,
            p.collectionSalt,
            p.inputsHash
        );
        (bytes32 seed, bool finalized) = successor.tokenSeed(r.tokenId);
        require(finalized && seed == keccak256(abi.encode(expected)), "original deterministic seed");
    }

    function _adapterStatus(Request memory r, StreamProviderResultStatus expected, bytes32 raw)
        private
        view
    {
        bytes32 key;
        bytes32 actual;
        StreamProviderResultStatus status;
        if (r.isArrng) (key, actual, status,,,) = arrng.results(r.id);
        else (key, actual, status,,) = vrf.results(r.id);
        require(key == r.key && actual == raw && status == expected, "actual adapter stored result");
    }

    function _adapterContext(Vm.Log[] memory logs, Request memory r, bytes32 expected)
        private
        view
    {
        bytes32 topic = r.isArrng
            ? keccak256("ARRNGRequestContext(uint16,uint256,uint256,bytes32,address)")
            : keccak256("VRFRequestContext(uint16,uint256,bytes32,bool)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != _provider(r.isArrng) || logs[i].topics.length != 2
                    || logs[i].topics[0] != topic
            ) continue;
            require(logs[i].topics[1] == bytes32(r.id), "original service ID event");
            if (r.isArrng) {
                (uint16 version, uint256 cap, bytes32 contextHash, address owner) =
                    abi.decode(logs[i].data, (uint16, uint256, bytes32, address));
                require(
                    version == 1 && cap == 500000 && contextHash == expected
                        && owner == arrngService.owner()
                );
            } else {
                (uint16 version, bytes32 contextHash, bool nativePayment) =
                    abi.decode(logs[i].data, (uint16, bytes32, bool));
                require(version == 1 && contextHash == expected && nativePayment);
            }
            return;
        }
        revert("missing actual adapter context event");
    }

    function _measureAuthReads(
        Request memory r,
        IStreamEntropyEpochs.RequestPolicySnapshot memory p
    ) private {
        uint256 cap = source.gasParameter(AUTH);
        require(cap == 100000 && successor.gasParameter(AUTH) == cap);
        require(source.gasParameter(DELIVERY) == 500000 && vrf.callbackGasLimit() == 500000);
        require(arrng.gasParameter(arrng.GGP_CALLBACK_GAS_LIMIT()) == 500000);
        uint256 before = gasleft();
        (bool ok, bytes memory data) = address(source).staticcall{ gas: cap }(
            abi.encodeCall(C.exportEntropyPolicy, (r.collectionId))
        );
        emit log_named_uint("AUTH warmed policy export read gas", before - gasleft());
        require(ok && data.length == 1184, "full canonical policy export within AUTH cap");
        O.RelayInput memory input = O.RelayInput(
            C(address(successor)).entropyPolicyImport().importHash,
            r.collectionId,
            r.tokenId,
            0,
            r.key,
            p
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RELAY_WITNESS_V1"),
                block.chainid,
                address(core),
                address(successor),
                address(successor).codehash,
                address(source),
                address(source).codehash,
                input
            )
        );
        before = gasleft();
        (ok, data) = address(successor).staticcall{ gas: cap }(
            abi.encodeCall(O.relayRequestWitness, (r.key))
        );
        emit log_named_uint("AUTH warmed request witness read gas", before - gasleft());
        require(
            ok && data.length == 32 && abi.decode(data, (bytes32)) == expected,
            "full canonical witness within AUTH cap"
        );
    }

    function _context(Request memory r, IStreamEntropyEpochs.RequestPolicySnapshot memory p)
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            uint16(1),
            address(core),
            r.collectionId,
            r.tokenId,
            bytes32(0),
            p.providerEpoch,
            p.providerConfigHash,
            p.requestAttempt,
            p.inputsHash
        );
    }

    function _raw(Request memory r, uint256 word) private view returns (bytes32) {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        return keccak256(
            abi.encode(r.isArrng ? arrng.RAW_DOMAIN() : vrf.RAW_DOMAIN(), r.key, r.id, words)
        );
    }

    function _provider(bool isArrng) private view returns (address) {
        return isArrng ? address(arrng) : address(vrf);
    }

    function _upstreamCount(bool isArrng) private view returns (uint256) {
        return isArrng ? arrngService.arrngRequestId() : vrfService.nextRequestId();
    }

    function _deploy() private returns (StreamEntropyCoordinator target) {
        target = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:production-provider-relay",
                HASH
            )
        );
        modules.setEligible(address(target), true);
    }

    function _candidate() private returns (StreamEntropyCoordinator target) {
        target = _deploy();
        _admitProviders(target);
    }

    function _admitProviders(StreamEntropyCoordinator target) private {
        _admitEntropyProvider(address(target), address(arrng));
        _admitEntropyProvider(address(target), address(vrf));
    }

    function _migrate(StreamEntropyCoordinator prior, StreamEntropyCoordinator candidate) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(candidate)).entropyPolicyImportTransition(address(prior), HASH);
        _action(scope, oldHash, newHash, 1);
        C(address(candidate)).beginEntropyPolicyImport(address(prior), HASH);
        _clearAction();
        (uint256 count,,) = C(address(prior)).entropyPolicyInventory();
        require(count == 2, "both provider collections inventoried");
        for (uint256 i; i < count; ++i) {
            C(address(candidate)).importNextEntropyPolicy(i);
            uint256 cid = C(address(prior)).entropyPolicyCollectionAt(i);
            C.PolicyExport memory p = C(address(prior)).exportEntropyPolicy(cid);
            require(p.policyOrigin == address(source), "ultimate origin retained");
            bytes32 importHash = C(address(candidate)).entropyPolicyImport().importHash;
            (scope, oldHash, newHash) = O(address(source))
                .entropyRelayAdmissionTransition(cid, address(candidate), importHash);
            _action(scope, oldHash, newHash, 1);
            O(address(source)).admitEntropyRelay(cid, address(candidate), importHash);
            _clearAction();
            C(address(candidate)).confirmEntropyRelayRoute(cid);
        }
        (scope, oldHash, newHash) = C(address(candidate)).entropyPolicyImportSealTransition();
        _action(scope, oldHash, newHash, 1);
        C(address(candidate)).sealEntropyPolicyImport();
        _clearAction();
        (scope, oldHash, newHash) = C(address(candidate)).entropyPolicyImportActivationTransition();
        core.select(candidate, core.pointerRevision() + 1);
        _action(scope, oldHash, newHash, 3);
        C(address(candidate)).activateEntropyPolicyImport();
        _clearAction();
    }

    function _action(bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) private {
        this.setCurrentAction(
            true,
            keccak256(abi.encode("production provider relay action", ++_actionNonce)),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function _clearAction() private {
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    receive() external payable { }
}
