// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RewindEvidenceBoundaryStub,
    RewindEvidenceOwnerStub,
    RewindEvidenceCoordinatorStub
} from "./StreamArtistRecoveryRewindEvidence.t.sol";
import {
    StreamArtistRecoveryRewindManifest as Manifest
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindManifest.sol";
import {
    StreamArtistRecoveryRewindEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindEvidence.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

error RewindManifestProbeFailure(uint8 getter);
error RewindManifestWrongCaller(address actual);

/// @dev Deployment getters are the existing typed fixture boundary. Only the
/// evidence-binding read adds an explicit caller check and a failure probe.
contract RewindManifestOwnerProbe is RewindEvidenceOwnerStub {
    address private _caller;
    address private _publisher;
    bytes32 private _pin;
    bool private _fail;

    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager
    )
        RewindEvidenceOwnerStub(
            registry, coordinator, archive, core_, manager, keccak256("domain:identity_authority")
        )
    { }

    function setCaller(address caller) external {
        _caller = caller;
    }

    function setBinding(address publisher, bytes32 pin) external {
        _publisher = publisher;
        _pin = pin;
    }

    function setFailure(bool fail) external {
        _fail = fail;
    }

    function recoveryRewindEvidenceBinding() external view returns (address, bytes32) {
        if (msg.sender != _caller) revert RewindManifestWrongCaller(msg.sender);
        if (_fail) revert RewindManifestProbeFailure(0);
        return (_publisher, _pin);
    }
}

/// @dev Typed, deliberately mutable publisher boundary for isolated rejection/order
/// controls. It supplies no original Artist admission or recovery authority.
contract RewindManifestPublisherProbe {
    address private immutable _caller;
    W.EnvironmentV3 private _environment;
    W.ResolutionManifestV3 private _manifest;
    bytes32 private _hash;
    bytes32 private _identityPin;
    bytes32 private _payoutPin;
    uint8 private _failure;

    constructor(address caller, W.EnvironmentV3 memory environment) {
        _caller = caller;
        _environment = environment;
    }

    function setEnvironment(W.EnvironmentV3 calldata environment) external {
        _environment = environment;
    }

    function setFailure(uint8 getter) external {
        _failure = getter;
    }

    function setManifest(
        bytes32 hash,
        W.ResolutionManifestV3 calldata manifest,
        bytes32 identityPin,
        bytes32 payoutPin
    ) external {
        _hash = hash;
        _manifest = manifest;
        _identityPin = identityPin;
        _payoutPin = payoutPin;
    }

    function owner() external view returns (address) {
        _probe(1);
        return _environment.identityOwner;
    }

    function payoutOwner() external view returns (address) {
        _probe(2);
        return _environment.payoutOwner;
    }

    function artistRegistry() external view returns (address) {
        _probe(3);
        return _environment.registry;
    }

    function deploymentChainId() external view returns (uint256) {
        _probe(4);
        return _environment.chainId;
    }

    function coordinator() external view returns (address) {
        _probe(5);
        return _environment.coordinator;
    }

    function archive() external view returns (address) {
        _probe(6);
        return _environment.archive;
    }

    function core() external view returns (address) {
        _probe(7);
        return _environment.core;
    }

    function mintManager() external view returns (address) {
        _probe(8);
        return _environment.manager;
    }

    function resolutionManifestV3(bytes32 hash)
        external
        view
        returns (W.ResolutionManifestV3 memory, bytes32, bytes32)
    {
        _probe(9);
        if (hash != _hash) revert W.InvalidRecoveryRewindManifest(hash);
        return (_manifest, _identityPin, _payoutPin);
    }

    function _probe(uint8 getter) private view {
        if (msg.sender != _caller) revert RewindManifestWrongCaller(msg.sender);
        if (_failure == getter) revert RewindManifestProbeFailure(getter);
    }
}

/// @dev Both readers run in exactly this host. The original body is frozen from
/// Selection._manifest at 3c78cc5ae6f7ce722a633c4adf4c86484e4024d4.
contract RewindManifestComparisonHost {
    address private immutable owner;
    address private immutable artistRegistry;
    address private immutable coordinator;
    uint256 private immutable deploymentChainId;

    constructor(address owner_, address registry_, address coordinator_, uint256 chainId_) {
        owner = owner_;
        artistRegistry = registry_;
        coordinator = coordinator_;
        deploymentChainId = chainId_;
    }

    function actual(W.EnvironmentV3 memory e, bytes32 hash)
        external
        view
        returns (W.ResolutionManifestV3 memory)
    {
        return Manifest.read(owner, artistRegistry, coordinator, deploymentChainId, e, hash);
    }

    function original(W.EnvironmentV3 memory e, bytes32 hash)
        external
        view
        returns (W.ResolutionManifestV3 memory m)
    {
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindEvidence publisher = IStreamArtistRecoveryRewindEvidence(target);
        if (
            publisher.owner() != owner || publisher.payoutOwner() != e.payoutOwner
                || publisher.artistRegistry() != artistRegistry
                || publisher.deploymentChainId() != deploymentChainId
                || publisher.coordinator() != coordinator || publisher.archive() != e.archive
                || publisher.core() != e.core || publisher.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
        bytes32 identityPin;
        bytes32 payoutPin;
        (m, identityPin, payoutPin) = publisher.resolutionManifestV3(hash);
        if (
            hash == 0 || identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || hash != W.manifestHash(e, m) || m.supersededRecords.length > W.MAX_SUPERSESSIONS
        ) {
            revert W.InvalidRecoveryRewindSelection(hash);
        }
        bytes32 previous;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            if (m.supersededRecords[i].recordHash <= previous) {
                revert W.InvalidRecoveryRewindSelection(hash);
            }
            previous = m.supersededRecords[i].recordHash;
        }
    }
}

/// @notice Exact reader return/revert parity and fixed-call context; no adjudication claim.
/// @dev One case uses the actual Evidence publisher. All surrounding owner/Coordinator
/// state is explicitly the existing typed deployment fixture, not original Artist records.
contract StreamArtistRecoveryRewindManifestTest {
    address private registry;
    address private archive;
    address private core;
    address private manager;
    RewindEvidenceCoordinatorStub private coordinator;
    RewindManifestOwnerProbe private identity;
    RewindEvidenceOwnerStub private payout;
    RewindManifestComparisonHost private host;
    RewindManifestPublisherProbe private publisher;

    function setUp() public {
        registry = address(new RewindEvidenceBoundaryStub());
        archive = address(new RewindEvidenceBoundaryStub());
        core = address(new RewindEvidenceBoundaryStub());
        manager = address(new RewindEvidenceBoundaryStub());
        coordinator = new RewindEvidenceCoordinatorStub();
        identity =
            new RewindManifestOwnerProbe(registry, address(coordinator), archive, core, manager);
        payout = new RewindEvidenceOwnerStub(
            registry,
            address(coordinator),
            archive,
            core,
            manager,
            keccak256("domain:payout_lifecycle")
        );
        T.SuiteConfiguration memory suite;
        suite.registry = registry;
        suite.archive = archive;
        suite.core = core;
        suite.mintManager = manager;
        suite.owners[2] = address(identity);
        suite.owners[5] = address(payout);
        coordinator.setSuite(suite);
        host = new RewindManifestComparisonHost(
            address(identity), registry, address(coordinator), block.chainid
        );
        identity.setCaller(address(host));
        publisher = new RewindManifestPublisherProbe(address(host), _environment());
        identity.setBinding(address(publisher), address(publisher).codehash);
    }

    function testCompleteDynamicManifestSortedZeroOneAndSixtyFourParity() public {
        uint256[3] memory counts = [uint256(0), uint256(1), uint256(64)];
        for (uint256 i; i < counts.length; ++i) {
            W.ResolutionManifestV3 memory manifest = _manifest(counts[i]);
            bytes32 hash = _install(manifest);
            _parity(hash, true, abi.encode(manifest));
        }
    }

    function testCorrectHashStillRejectsZeroDuplicateDescendingAndSixtyFiveRecords() public {
        for (uint256 variant; variant < 4; ++variant) {
            W.ResolutionManifestV3 memory manifest = _manifest(variant == 3 ? 65 : 2);
            if (variant == 0) manifest.supersededRecords[0].recordHash = bytes32(0);
            if (variant == 1) {
                manifest.supersededRecords[1].recordHash = manifest.supersededRecords[0].recordHash;
            }
            if (variant == 2) manifest.supersededRecords[0].recordHash = bytes32(uint256(500));
            bytes32 hash = _install(manifest);
            _parity(
                hash, false, abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, hash)
            );
        }
    }

    function testOwnerBindingFailuresPrecedePublisherReadsAndPreserveOwnerRevert() public {
        bytes32 hash = _install(_manifest(1));
        publisher.setFailure(1);
        address[4] memory targets =
            [address(0), address(0x1234), address(publisher), address(publisher)];
        bytes32[4] memory pins =
            [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(0), bytes32(uint256(3))];
        for (uint256 i; i < targets.length; ++i) {
            identity.setBinding(targets[i], pins[i]);
            _parity(
                hash,
                false,
                abi.encodeWithSelector(W.RecoveryRewindDependencyChanged.selector, targets[i])
            );
        }
        identity.setFailure(true);
        _parity(hash, false, abi.encodeWithSelector(RewindManifestProbeFailure.selector, uint8(0)));
    }

    function testEveryPublisherIdentityMismatchShortCircuitsBeforeNextGetter() public {
        bytes32 hash = _install(_manifest(1));
        for (uint8 getter = 1; getter <= 8; ++getter) {
            W.EnvironmentV3 memory changed = _environment();
            if (getter == 1) changed.identityOwner = address(0x1111);
            if (getter == 2) changed.payoutOwner = address(0x2222);
            if (getter == 3) changed.registry = address(0x3333);
            if (getter == 4) ++changed.chainId;
            if (getter == 5) changed.coordinator = address(0x5555);
            if (getter == 6) changed.archive = address(0x6666);
            if (getter == 7) changed.core = address(0x7777);
            if (getter == 8) changed.manager = address(0x8888);
            publisher.setEnvironment(changed);
            publisher.setFailure(getter + 1);
            _parity(
                hash,
                false,
                abi.encodeWithSelector(
                    W.RecoveryRewindDependencyChanged.selector, address(publisher)
                )
            );
        }
    }

    function testEveryPublisherGetterFailureBubblesInOriginalOrder() public {
        bytes32 hash = _install(_manifest(1));
        for (uint8 getter = 1; getter <= 9; ++getter) {
            publisher.setFailure(getter);
            _parity(
                hash, false, abi.encodeWithSelector(RewindManifestProbeFailure.selector, getter)
            );
        }
    }

    function testIdentityPayoutOutputPinsAndReturnedManifestHashAreRequired() public {
        W.EnvironmentV3 memory e = _environment();
        W.ResolutionManifestV3 memory manifest = _manifest(2);
        bytes32 correct = _manifestHash(e, manifest);
        for (uint256 variant; variant < 4; ++variant) {
            bytes32 requested = variant == 2 ? bytes32(uint256(998)) : correct;
            if (variant == 3) requested = bytes32(0);
            publisher.setManifest(
                requested,
                manifest,
                variant == 0 ? bytes32(uint256(991)) : e.identityCodeHash,
                variant == 1 ? bytes32(uint256(992)) : e.payoutCodeHash
            );
            _parity(
                requested,
                false,
                abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, requested)
            );
        }
    }

    function testZeroAndMissingHashesPreservePublisherErrorBeforeSelectionChecks() public {
        _install(_manifest(1));
        bytes32[2] memory hashes = [bytes32(0), bytes32(uint256(999))];
        for (uint256 i; i < hashes.length; ++i) {
            _parity(
                hashes[i],
                false,
                abi.encodeWithSelector(W.InvalidRecoveryRewindManifest.selector, hashes[i])
            );
        }
        publisher.setFailure(9);
        _parity(
            bytes32(0), false, abi.encodeWithSelector(RewindManifestProbeFailure.selector, uint8(9))
        );
    }

    function testCallerSensitiveProbesAndActualEvidencePublisherReadback() public {
        W.ResolutionManifestV3 memory manifest = _manifest(7);
        bytes32 hash = _install(manifest);
        // Every owner/publisher read in both successful routes requires this exact
        // comparison host as caller. Direct reads from the test are rejected.
        _parity(hash, true, abi.encode(manifest));
        (bool ownerOK, bytes memory ownerError) =
            address(identity).staticcall(abi.encodeCall(identity.recoveryRewindEvidenceBinding, ()));
        (bool publisherOK, bytes memory publisherError) =
            address(publisher).staticcall(abi.encodeCall(publisher.owner, ()));
        bytes memory expected =
            abi.encodeWithSelector(RewindManifestWrongCaller.selector, address(this));
        require(!ownerOK && !publisherOK, "caller-sensitive probes are active");
        require(
            keccak256(ownerError) == keccak256(expected)
                && keccak256(publisherError) == keccak256(expected),
            "exact caller rejection"
        );

        StreamArtistRecoveryRewindEvidence actualPublisher = new StreamArtistRecoveryRewindEvidence(
            address(identity), registry, address(coordinator), archive, core, manager
        );
        bytes32 actualHash = actualPublisher.publishResolutionManifestV3(manifest);
        require(actualHash == hash, "original literal manifest domain");
        identity.setBinding(address(actualPublisher), address(actualPublisher).codehash);
        _parity(actualHash, true, abi.encode(manifest));
        _parity(
            bytes32(0),
            false,
            abi.encodeWithSelector(W.InvalidRecoveryRewindManifest.selector, bytes32(0))
        );
        _parity(
            bytes32(uint256(999)),
            false,
            abi.encodeWithSelector(W.InvalidRecoveryRewindManifest.selector, bytes32(uint256(999)))
        );
    }

    function _parity(bytes32 hash, bool expectedOK, bytes memory expected) private view {
        W.EnvironmentV3 memory e = _environment();
        (bool actualOK, bytes memory actual) =
            address(host).staticcall(abi.encodeCall(host.actual, (e, hash)));
        (bool originalOK, bytes memory original) =
            address(host).staticcall(abi.encodeCall(host.original, (e, hash)));
        require(actualOK == expectedOK && originalOK == expectedOK, "original manifest read status");
        require(
            keccak256(actual) == keccak256(original), "complete original manifest return or revert"
        );
        require(keccak256(actual) == keccak256(expected), "independent expected return or error");
    }

    function _install(W.ResolutionManifestV3 memory manifest) private returns (bytes32 hash) {
        W.EnvironmentV3 memory e = _environment();
        hash = _manifestHash(e, manifest);
        publisher.setManifest(hash, manifest, e.identityCodeHash, e.payoutCodeHash);
    }

    function _manifestHash(W.EnvironmentV3 memory e, W.ResolutionManifestV3 memory manifest)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3"),
                uint16(3),
                e,
                manifest
            )
        );
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            block.chainid,
            registry,
            address(identity),
            address(identity).codehash,
            address(payout),
            address(payout).codehash,
            address(coordinator),
            archive,
            core,
            manager
        );
    }

    function _manifest(uint256 count) private pure returns (W.ResolutionManifestV3 memory m) {
        m.artistId = bytes32(uint256(11));
        m.identity = W.ReceiptPrefix(
            T.Snapshot(
                keccak256("domain:identity_authority"),
                12,
                bytes32(uint256(13)),
                bytes32(uint256(14))
            ),
            15
        );
        m.payout = W.ReceiptPrefix(
            T.Snapshot(
                keccak256("domain:payout_lifecycle"), 16, bytes32(uint256(17)), bytes32(uint256(18))
            ),
            19
        );
        m.causeHash = bytes32(uint256(20));
        m.resolutionHash = bytes32(uint256(21));
        m.executedHead = bytes32(uint256(22));
        m.basis = E.VestingBasis.DECLARED_VESTINGS;
        m.requestCommitment = bytes32(uint256(23));
        m.resolutionEvidenceHash = bytes32(uint256(24));
        m.contestedVestings = new E.VestingReference[](2);
        m.contestedVestings[0] = E.VestingReference(bytes32(uint256(27)), bytes32(uint256(28)));
        m.contestedVestings[1] = E.VestingReference(bytes32(uint256(25)), bytes32(uint256(26)));
        m.supersededRecords = new W.RecordReference[](count);
        for (uint256 i; i < count; ++i) {
            m.supersededRecords[i] = W.RecordReference(W.RecordKind(6 - i % 7), bytes32(100 + i));
        }
    }
}
