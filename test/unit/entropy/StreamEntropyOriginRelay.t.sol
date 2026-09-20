// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEntropyRelayState as S,
    StreamEntropyRelayReads as Read
} from "../../../smart-contracts/domains/entropy/StreamEntropyRelayState.sol";
import {
    StreamEntropyOriginRelay as Relay
} from "../../../smart-contracts/domains/entropy/StreamEntropyOriginRelay.sol";
import {
    StreamEntropyRelayAdmission as Admission
} from "../../../smart-contracts/domains/entropy/StreamEntropyRelayAdmission.sol";
import {
    StreamEntropyCoordinator
} from "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    StreamEntropyProviderLifecycle as Lifecycle
} from "../../../smart-contracts/domains/entropy/StreamEntropyProviderLifecycle.sol";
import {
    StreamEntropyIncidentParameters
} from "../../../smart-contracts/domains/entropy/StreamEntropyIncidentParameters.sol";
import {
    StreamEntropyRecoveryPolicies
} from "../../../smart-contracts/domains/entropy/StreamEntropyRecoveryPolicies.sol";
import { IStreamCore } from "../../../smart-contracts/interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyOriginRelay as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyEpochs as E
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import {
    IStreamEntropyProvider
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProvider.sol";
import {
    EntropyProviderState
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import { ReentrancyGuard } from "../../../smart-contracts/vendor/openzeppelin/ReentrancyGuard.sol";

interface RelayVm {
    function deal(address who, uint256 amount) external;
}

/// @dev Typed authority/Core/registry boundaries: this suite tests actual relay libraries, not the
/// full Artist/Core/governance graph or successor seed derivation, which have separate integration tests.
contract RelayAuthorityFixture {
    bool public executing;
    bytes32 public action;
    uint8 public cls;
    bytes32 public scope;
    bytes32 public oldHash;
    bytes32 public newHash;
    uint256 private nonce;

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (executing, action, cls, scope, oldHash, newHash);
    }

    function execute(
        address target,
        bytes memory data,
        uint8 class_,
        bytes32 scope_,
        bytes32 old_,
        bytes32 new_
    ) external {
        executing = true;
        action = keccak256(abi.encode(++nonce));
        cls = class_;
        scope = scope_;
        oldHash = old_;
        newHash = new_;
        (bool ok, bytes memory out) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        executing = false;
    }
}

contract RelayCoreFixture {
    address public selected;
    address public modules;
    address public tokenHost;
    uint8 public lifecycle = 2;

    function set(address selected_, address modules_, address tokenHost_) external {
        selected = selected_;
        modules = modules_;
        tokenHost = tokenHost_;
    }

    function setLifecycle(uint8 next) external {
        lifecycle = next;
    }

    function getSatellitePointer(bytes32 role)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = role == keccak256("MODULE_REGISTRY") ? modules : selected;
        return
            (target, target.codehash, false, role, bytes4(0), modules, 1, bytes32(0), bytes32(0), 1);
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return tokenHost;
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return lifecycle;
    }

    function tokenCollectionIdentity(uint256) external view returns (bool, uint256, uint256, bool) {
        return (true, 7, 1, lifecycle == 3);
    }
}

contract RelayRegistryFixture {
    address public immutable governanceExecutor;
    bool public eligible = true;

    constructor(address authority) {
        governanceExecutor = authority;
    }

    function setEligible(bool next) external {
        eligible = next;
    }

    function isModuleEligible(address, bytes32, bytes4) external view returns (bool) {
        return eligible;
    }
}

contract RelayProviderFixture {
    address public immutable coordinator;
    bytes32 public immutable streamEntropyProviderConfigHash;
    uint256 public fee = 13;
    uint256 public nextId = 19;
    uint256 public requests;
    uint256 public paid;
    bytes32 public key;
    bool public synchronous;
    bool public synchronousRejected;

    constructor(address host) {
        coordinator = host;
        streamEntropyProviderConfigHash = keccak256(abi.encode("relay provider", host));
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamEntropyProvider).interfaceId || id == 0x01ffc9a7;
    }

    function isStreamEntropyProvider() external pure returns (bool) {
        return true;
    }

    function quoteRequest(bytes calldata) external view returns (uint256) {
        return fee;
    }

    function setSynchronous(bool next) external {
        synchronous = next;
    }

    function requestEntropy(bytes32 key_, bytes calldata) external payable returns (uint256) {
        require(msg.sender == coordinator && msg.value == fee, "provider authority/fee");
        ++requests;
        paid += msg.value;
        key = key_;
        if (synchronous) {
            (bool ok,) = coordinator.call(
                abi.encodeWithSignature(
                    "fulfillEntropy(bytes32,bytes32)", key_, bytes32(uint256(123))
                )
            );
            synchronousRejected = !ok;
        }
        return nextId;
    }

    function deliver(bytes32 raw) external returns (uint8) {
        (bool ok, bytes memory out) =
            coordinator.call(abi.encodeWithSignature("fulfillEntropy(bytes32,bytes32)", key, raw));
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        return abi.decode(out, (uint8));
    }
}

contract RelayHostHarness is ReentrancyGuard {
    IStreamCore public immutable core;
    address public immutable authority;
    C.PolicyExport private policy;
    C.ImportReceipt private receipt;
    uint64 public serial = 1;
    bytes32 public constant DIGEST = keccak256("unit ordered inventory");
    mapping(bytes32 => StreamEntropyCoordinator.Request) private requests;
    mapping(address => mapping(uint256 => bytes32)) private providerKeys;
    mapping(bytes32 => bytes32) private actualWitness;
    uint8 public response;
    uint256 public deliveries;
    bytes32 public acceptedRaw;

    constructor(IStreamCore core_, address authority_) {
        core = core_;
        authority = authority_;
        StreamEntropyIncidentParameters.initialize(authority_);
        StreamEntropyRecoveryPolicies.initialize(authority_);
        Lifecycle.initialize(authority_);
    }

    function setPolicy(C.PolicyExport memory p) external {
        policy = p;
    }

    function bumpSource() external {
        ++serial;
    }

    function exportEntropyPolicy(uint256) external view returns (C.PolicyExport memory) {
        return policy;
    }

    function entropyPolicyInventory() external view returns (uint256, uint64, bytes32) {
        return (1, serial, DIGEST);
    }

    function stage(address source) external returns (bytes32) {
        receipt.state = C.ImportState.STAGING;
        receipt.nonce = 1;
        receipt.predecessor = source;
        receipt.predecessorCodeHash = source.codehash;
        receipt.pointerRevision = 1;
        receipt.count = 1;
        receipt.serial = 1;
        receipt.idDigest = DIGEST;
        receipt.manifestHash = keccak256("manifest");
        receipt.nextIndex = 1;
        receipt.beginActionId = keccak256("begin");
        receipt.importHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_V1"),
                block.chainid,
                address(this),
                address(this).codehash,
                address(core),
                receipt.nonce,
                source,
                source.codehash,
                uint64(1),
                uint256(1),
                uint64(1),
                DIGEST,
                receipt.manifestHash
            )
        );
        return receipt.importHash;
    }

    function active(bool next) external {
        receipt.state = next ? C.ImportState.ACTIVE : C.ImportState.STAGING;
        receipt.activationActionId = next ? keccak256("activation") : bytes32(0);
    }

    function entropyPolicyImport() external view returns (C.ImportReceipt memory) {
        return receipt;
    }

    function importedEntropyPolicy(uint256)
        external
        view
        returns (bytes32, bytes32, address, bytes32, bytes32)
    {
        return (
            receipt.importHash,
            keccak256(abi.encode(policy)),
            policy.policyOrigin,
            policy.policyOriginCodeHash,
            policy.record.policyHash
        );
    }

    function transition(uint256 id, address next, bytes32 hash)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return Admission.admissionTransition(core, authority, id, next, hash);
    }

    function admit(uint256 id, address next, bytes32 hash) external nonReentrant {
        Admission.admit(core, authority, id, next, hash);
    }

    function admission(uint256 id, address next) external view returns (bytes32, bytes32, bytes32) {
        S.Admission storage a = S.store().admissions[id][next];
        return (a.successorCodeHash, a.importHash, a.policyHash);
    }

    function lifecycleTransition(address provider, EntropyProviderState next)
        external
        view
        returns (bytes32, bytes32, bytes32, uint8)
    {
        return Lifecycle.transition(provider, next, "unit lifecycle", false);
    }

    function lifecycle(address provider, EntropyProviderState next) external {
        Lifecycle.update(authority, provider, next, "unit lifecycle", false);
    }

    function prepare(address origin, R.RelayInput memory input) public returns (bytes32 id) {
        id = S.prewriteLocal(core, origin, origin.codehash, input);
        actualWitness[input.successorRequestKey] =
            S.witnessHash(core, address(this), origin, origin.codehash, input);
    }

    function send(address origin, R.RelayInput memory input)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        prepare(origin, input);
        return R(origin).relayEntropyRequest{ value: msg.value }(input);
    }

    function relayRequestWitness(bytes32 key) external view returns (bytes32) {
        return actualWitness[key];
    }

    function relayEntropyRequest(R.RelayInput memory input)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        return Relay.submit(core, requests, providerKeys, input);
    }

    function fulfillEntropy(bytes32 key, bytes32 raw) external nonReentrant returns (uint8) {
        (bool found, uint8 result) = Relay.capture(core, requests, providerKeys, key, raw);
        require(found, "not relay");
        return result;
    }

    function retry(bytes32 id) external nonReentrant returns (bool, uint8) {
        return Relay.retry(core, requests, providerKeys, id);
    }

    function result(bytes32 id) external view returns (R.RelayResult memory) {
        return S.store().results[id];
    }

    function route(bytes32 key) external view returns (S.LocalRoute memory) {
        return S.store().localRoutes[key];
    }

    function setResponse(uint8 next) external {
        response = next;
    }

    function fulfillRelayedEntropy(bytes32 key, bytes32 id, bytes32 raw) external returns (uint8) {
        uint8 outcome = _fulfillRelayedEntropy(key, id, raw);
        // Inject malformed ABI only after the guarded body has restored its lock.
        // A raw return inside nonReentrant would poison every subsequent retry.
        if (response == 2) {
            assembly ("memory-safe") {
                mstore(0, 0)
                return(0, 31)
            }
        }
        return outcome;
    }

    function _fulfillRelayedEntropy(bytes32 key, bytes32 id, bytes32 raw)
        private
        nonReentrant
        returns (uint8)
    {
        S.LocalRoute storage local = S.store().localRoutes[key];
        require(
            msg.sender == local.origin && msg.sender.codehash == local.originCodeHash
                && id == local.relayId,
            "route authentication"
        );
        if (response == 1) revert("external delivery fault");
        if (response == 2) return 0;
        if (response == 3) assembly ("memory-safe") { invalid() }
        if (response == 8) return 1;
        if (response >= 4) return response - 2;
        ++deliveries;
        acceptedRaw = raw;
        return 0;
    }

    function seedOriginal(address provider, uint256 id, bytes32 key) external {
        providerKeys[provider][id] = key;
    }

    function bindOriginal(address provider, uint256 id) external view {
        S.requireProviderIdUnused(provider, id);
    }

    function key(R.RelayInput memory input) external view returns (bytes32) {
        return S.requestKey(core, address(this), input);
    }

    function read(address target, bytes memory data, uint256 size)
        external
        view
        returns (bytes memory)
    {
        return Read.read(target, data, size);
    }
}

contract StreamEntropyOriginRelayTest {
    RelayVm private constant vm = RelayVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RelayAuthorityFixture private auth;
    RelayCoreFixture private core;
    RelayRegistryFixture private registry;
    RelayHostHarness private origin;
    RelayHostHarness private successor;
    RelayProviderFixture private provider;
    bytes32 private importHash;

    function setUp() public {
        auth = new RelayAuthorityFixture();
        core = new RelayCoreFixture();
        registry = new RelayRegistryFixture(address(auth));
        origin = new RelayHostHarness(IStreamCore(address(core)), address(auth));
        successor = new RelayHostHarness(IStreamCore(address(core)), address(auth));
        provider = new RelayProviderFixture(address(origin));
        core.set(address(origin), address(registry), address(successor));
        C.PolicyExport memory p;
        p.collectionId = 7;
        p.profile = C.PolicyProfile.EXPLICIT;
        p.policyOrigin = address(origin);
        p.policyOriginCodeHash = address(origin).codehash;
        p.record.configured = true;
        p.record.explicitPolicy = true;
        p.record.frozen = true;
        p.record.mode = P.Mode.ASYNC;
        p.record.revision = 1;
        p.record.providerEpoch = 1;
        p.record.policyHash = keccak256("typed source policy H");
        p.policy.mode = P.Mode.ASYNC;
        p.policy.provider = address(provider);
        p.policy.collectionSalt = keccak256("salt");
        p.policy.timeoutBlocks = 12;
        p.policy.reveal.declared = true;
        p.providerCodeHash = address(provider).codehash;
        p.providerConfigHash = provider.streamEntropyProviderConfigHash();
        origin.setPolicy(p);
        successor.setPolicy(p);
        importHash = successor.stage(address(origin));
        _lifecycle(EntropyProviderState.ACTIVE);
        vm.deal(address(this), 1 ether);
    }

    function _lifecycle(EntropyProviderState next) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) =
            origin.lifecycleTransition(address(provider), next);
        auth.execute(
            address(origin),
            abi.encodeCall(origin.lifecycle, (address(provider), next)),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function _admit() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            origin.transition(7, address(successor), importHash);
        auth.execute(
            address(origin),
            abi.encodeCall(origin.admit, (7, address(successor), importHash)),
            1,
            scope,
            oldHash,
            newHash
        );
        successor.active(true);
    }

    function _input() private view returns (R.RelayInput memory input) {
        input.importHash = importHash;
        input.collectionId = 7;
        input.tokenId = 1;
        input.policy = E.RequestPolicySnapshot(
            address(provider),
            address(provider).codehash,
            1,
            provider.streamEntropyProviderConfigHash(),
            keccak256("salt"),
            keccak256("original mint commitment"),
            1
        );
        input.successorRequestKey = successor.key(input);
    }

    function _send() private returns (bytes32 id) {
        _admit();
        R.RelayInput memory input = _input();
        require(successor.send{ value: 13 }(address(origin), input) == 19, "actual provider id");
        id = successor.route(input.successorRequestKey).relayId;
        require(
            provider.key() == input.successorRequestKey && provider.paid() == 13
                && address(origin).balance == 0,
            "key and exact cash"
        );
    }

    function testGovernedAdmissionBindsExactImportedSourceAndRejectsRebinding() public {
        _admit();
        (bytes32 pin, bytes32 imported, bytes32 hash) = origin.admission(7, address(successor));
        require(
            pin == address(successor).codehash && imported == importHash
                && hash == keccak256("typed source policy H"),
            "admission exact"
        );
        (bool ok,) =
            address(origin).call(abi.encodeCall(origin.admit, (7, address(successor), importHash)));
        require(!ok, "permanent admission");
    }

    function testStaleHeaderAndWrongGovernanceClassRejectAdmission() public {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            origin.transition(7, address(successor), importHash);
        (bool ok,) = address(auth)
            .call(
                abi.encodeCall(
                    auth.execute,
                    (
                        address(origin),
                        abi.encodeCall(origin.admit, (7, address(successor), importHash)),
                        uint8(3),
                        scope,
                        oldHash,
                        newHash
                    )
                )
            );
        require(!ok, "wrong class");
        origin.bumpSource();
        (ok,) = address(origin)
            .staticcall(abi.encodeCall(origin.transition, (7, address(successor), importHash)));
        require(!ok, "stale source");
    }

    function testZeroRawDurableAcknowledgementAndExactSuccessfulRetry() public {
        bytes32 id = _send();
        successor.setResponse(1);
        require(provider.deliver(bytes32(0)) == 0, "origin acknowledges capture");
        R.RelayResult memory r = origin.result(id);
        require(
            r.rawReceived && r.raw == 0 && !r.delivered && r.lastOutcome == 4
                && successor.deliveries() == 0,
            "zero capture survives failed delivery"
        );
        successor.setResponse(0);
        (bool delivered, uint8 outcome) = origin.retry(id);
        require(
            delivered && outcome == 0 && successor.deliveries() == 1
                && successor.acceptedRaw() == 0,
            "exact retry"
        );
        origin.retry(id);
        require(successor.deliveries() == 1 && provider.requests() == 1, "no second delivery/draw");
        (bool ok,) = address(provider).call(abi.encodeCall(provider.deliver, (bytes32(uint256(1)))));
        require(!ok, "raw cannot change");
    }

    function testMalformedGasBurningAndNonzeroOutcomesRemainRetryable() public {
        bytes32 id = _send();
        successor.setResponse(2);
        provider.deliver(bytes32(uint256(77)));
        require(
            origin.result(id).rawReceived && !origin.result(id).delivered
                && origin.result(id).lastOutcome == 4 && successor.deliveries() == 0,
            "malformed retained"
        );
        successor.setResponse(3);
        origin.retry(id);
        require(!origin.result(id).delivered && origin.result(id).lastOutcome == 4, "OOG retained");
        for (uint8 i = 4; i <= 8; ++i) {
            successor.setResponse(i);
            origin.retry(id);
            require(
                !origin.result(id).delivered && !origin.result(id).terminalStale,
                "nonzero retryable"
            );
            require(
                origin.result(id).lastOutcome == (i == 8 ? 1 : i - 2),
                "exact nonzero response reached"
            );
        }
        successor.setResponse(0);
        origin.retry(id);
        require(
            origin.result(id).delivered && successor.acceptedRaw() == bytes32(uint256(77))
                && successor.deliveries() == 1 && provider.requests() == 1,
            "original raw retry"
        );
    }

    function testRevocationCapturesButCannotDeliverUntilOriginalLifecycleAllows() public {
        bytes32 id = _send();
        _lifecycle(EntropyProviderState.INCIDENT_REVOKED);
        provider.deliver(bytes32(uint256(42)));
        require(
            origin.result(id).rawReceived && origin.result(id).lastOutcome == 5
                && successor.deliveries() == 0,
            "revoked capture only"
        );
        _lifecycle(EntropyProviderState.ACTIVE);
        origin.retry(id);
        require(origin.result(id).delivered, "reactivated original route");
    }

    function testHistoricalSuccessorRouteDoesNotRequireCurrentSelection() public {
        _admit();
        core.set(address(0x1234), address(registry), address(successor));
        R.RelayInput memory input = _input();
        successor.send{ value: 13 }(address(origin), input);
        bytes32 id = successor.route(input.successorRequestKey).relayId;
        provider.deliver(bytes32(uint256(99)));
        require(origin.result(id).delivered, "historical request and callback");
    }

    function testSynchronousCallbackRejectedUntilBothBindingsExist() public {
        provider.setSynchronous(true);
        bytes32 id = _send();
        require(
            provider.synchronousRejected() && origin.result(id).submitted
                && !origin.result(id).rawReceived,
            "synchronous rejected"
        );
        provider.deliver(bytes32(uint256(123)));
        require(origin.result(id).delivered, "later callback");
    }

    function testDuplicateProviderIdAndFeeMismatchRollBackBothHostsAndCash() public {
        _admit();
        R.RelayInput memory input = _input();
        (bool ok,) = address(successor).call{ value: 12 }(
            abi.encodeCall(successor.send, (address(origin), input))
        );
        require(!ok, "exact fee");
        require(
            successor.route(input.successorRequestKey).origin == address(0)
                && provider.requests() == 0 && address(origin).balance == 0,
            "fee rollback"
        );
        origin.seedOriginal(address(provider), 19, keccak256("original host request"));
        (ok,) = address(successor).call{ value: 13 }(
            abi.encodeCall(successor.send, (address(origin), input))
        );
        require(!ok, "cross map collision");
        require(
            successor.route(input.successorRequestKey).origin == address(0)
                && provider.requests() == 0 && provider.paid() == 0,
            "cross host rollback"
        );
    }

    function testOriginalBindingCannotReuseRelayProviderId() public {
        _send();
        (bool ok,) = address(origin)
            .staticcall(abi.encodeCall(origin.bindOriginal, (address(provider), uint256(19))));
        require(!ok, "symmetric collision guard");
    }

    function testInactiveImportWrongTokenLifecycleAndAlteredTermsCannotRequest() public {
        _admit();
        R.RelayInput memory input = _input();
        successor.active(false);
        (bool ok,) = address(successor).call{ value: 13 }(
            abi.encodeCall(successor.send, (address(origin), input))
        );
        require(!ok, "active required");
        successor.active(true);
        core.setLifecycle(1);
        (ok,) = address(successor).call{ value: 13 }(
            abi.encodeCall(successor.send, (address(origin), input))
        );
        require(!ok, "minted required");
        core.setLifecycle(2);
        input.policy.collectionSalt = keccak256("substituted");
        (ok,) = address(successor).call{ value: 13 }(
            abi.encodeCall(successor.send, (address(origin), input))
        );
        require(!ok && provider.requests() == 0, "terms pinned");
    }

    function testAuthenticationReadRequiresCompleteCapAndExactReturnWidth() public {
        (bool ok,) = address(origin).staticcall{ gas: 60000 }(
            abi.encodeCall(
                origin.read, (address(core), abi.encodeCall(core.tokenLifecycle, (1)), uint256(32))
            )
        );
        require(!ok, "no clipped auth cap");
        (ok,) = address(origin)
            .staticcall(
                abi.encodeCall(
                    origin.read,
                    (address(core), abi.encodeCall(core.tokenLifecycle, (1)), uint256(64))
                )
            );
        require(!ok, "exact width");
    }
}
