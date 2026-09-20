// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamMetadataRecoveredArtistSelection
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveredArtistSelection.sol";
import {
    StreamMetadataArtistConfiguration
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol";
import {
    StreamMetadataArtistSelection
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistSelection.sol";
import {
    StreamArtistRecordPublicationReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecordPublicationReads.sol";

import { StreamArtistRecoveredHydrationState as ImportedState } from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import { StreamArtistRecoveredOwnerReads as ImportedReads } from "../../../smart-contracts/domains/artist/StreamArtistRecoveredOwnerReads.sol";
import { StreamArtistOwnerHydration as ImportedBinding } from "../../../smart-contracts/domains/artist/StreamArtistOwnerHydration.sol";
interface MetadataCertificateVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract MetadataRouterForSuccessorBoundary {
    address public immutable core;

    constructor(address core_) {
        core = core_;
    }
}

contract MetadataPublicationModulesBoundary {
    address public immutable host;

    constructor(address host_) {
        host = host_;
    }

    function isModuleEligible(address value, bytes32 kind, bytes4 id) external view returns (bool) {
        return value == host && kind == keccak256("COLLECTION_METADATA")
            && id == type(IStreamCollectionMetadataV1).interfaceId;
    }
}

contract MetadataPublicationBudgetProbe {
    function candidate(T.SuiteConfiguration memory suite, P.Publication memory p)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRecordPublicationReads.candidate(suite, p);
    }
}

import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

// Explicit typed lineage boundaries. Metadata, schemas, byte store and Safe are real contracts;
// these controls do not claim execution of Artist operations55–57/60 or signature admission.
contract MetadataHydrationCoordinatorBoundary {
    T.SuiteConfiguration private suite;
    address[16] private targets;
    bytes32[16] private runtimeHashes;
    uint256 public immutable deploymentChainId = block.chainid;
    bytes32 public configurationHash;
    address public finalityRegistry;
    address public finalityEvidenceProvider;

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    // Reproduces the actual Coordinator constructor's owner binding invariant and
    // authorityHydrationSuite's saved-storage/runtime read cost. Registry/Archive
    // construction and operation60 execution remain explicitly typed boundaries.
    function configure(T.SuiteConfiguration memory s) external {
        for (uint256 i; i < 7; ++i) {
            MetadataHydratedOwnerBoundary owner = MetadataHydratedOwnerBoundary(s.owners[i]);
            require(
                owner.artistRegistry() == s.registry
                    && owner.operationCoordinator() == address(this)
                    && owner.archiveV2() == s.archive && owner.core() == s.core
                    && owner.mintManager() == s.mintManager
                    && owner.deploymentChainId() == block.chainid
                    && owner.domainId() == keccak256(abi.encode("fixture owner", i)),
                "constructor owner binding"
            );
            targets[i] = s.owners[i];
        }
        suite = s;
        targets[7] = s.registry;
        targets[8] = s.archive;
        targets[9] = s.core;
        targets[10] = s.mintManager;
        targets[11] = s.roleRegistry;
        targets[12] = s.metadata;
        targets[13] = s.primaryResolver;
        targets[14] = s.royaltyResolver;
        targets[15] = s.validator;
        for (uint256 i; i < 16; ++i) {
            require(targets[i].code.length != 0 && targets[i] != address(this), "target");
            for (uint256 j; j < i; ++j) {
                require(targets[j] != targets[i], "duplicate target");
            }
            runtimeHashes[i] = targets[i].codehash;
        }
        address finalityRegistry_ = s.archive;
        address provider = s.validator;
        bytes32 providerCodeHash = provider.codehash;
        finalityRegistry = finalityRegistry_;
        finalityEvidenceProvider = provider;
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                s,
                runtimeHashes,
                finalityRegistry_,
                finalityRegistry_.codehash,
                provider,
                providerCodeHash,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
    }

    function corruptSuiteForNegative(T.SuiteConfiguration memory s) external {
        suite = s; // Explicit injected storage corruption, not an actual Coordinator setter.
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        require(block.chainid == deploymentChainId, "chain");
        for (uint256 j; j < 16; ++j) {
            require(targets[j].codehash == runtimeHashes[j], "target runtime");
        }
        return suite;
    }
}

contract MetadataHydratedOwnerBoundary {
    address public artistRegistry;
    address public operationCoordinator;
    address public archiveV2;
    address public core;
    address public mintManager;
    uint256 public deploymentChainId;
    bytes32 public domainId;
    bytes32 public authorityHydrationCommitment;
    mapping(bytes32 => RH.OriginEnvironment) private _origins;
    mapping(bytes32 => bool) private _enabled;
    mapping(bytes32 => T.ReplayCell) private _fixtureReplay;
    uint8 private immutable _ownerIndex;

    // Typed source/admission boundary; actual immutable storage producer and read workers.
    // Corruption controls only disable the served certificate, never rewrite an installed prefix.
    function setOrigin(bytes32 hash, RH.OriginEnvironment memory value) external {
        _origins[hash] = value;
        bool valid = value.registry != address(0) && RH.originHash(value) == hash;
        _enabled[hash] = valid;
        if (valid && ImportedState.commitment() == 0) {
            RH.OwnerProvenance memory p;
            p.origins = new RH.OriginEnvironment[](1);
            p.origins[0] = value;
            p.eras = new RH.OwnerEra[](1);
            p.eras[0].originHash = hash;
            p.eras[0].checkpoint.schema = RH.CHECKPOINT;
            p.eras[0].checkpoint.ownerState = T.Snapshot(RH.ownerDomain(_ownerIndex), 12, bytes32(uint256(300)), bytes32(uint256(301)));
            ImportedState.installOwnerPrefix(p, _ownerIndex, authorityHydrationCommitment, 1);
        }
    }

    function recoveredHydrationImportedOriginCertificate(bytes32 hash)
        external view returns (bytes32, bytes32, uint64, uint8)
    {
        require(_enabled[hash], "disabled certificate fixture");
        // Same fixed reader and namespace as the real Owner. Stored fixture bindings and the
        // extra refusal slot conservatively add reads; actual Owner bindings are immutable.
        bytes memory raw = ImportedReads.read(_fixtureReplay,
            ImportedBinding.Binding(artistRegistry, operationCoordinator, archiveV2, RH.ownerDomain(_ownerIndex)), 0, msg.data);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function recoveredHydrationOrigin(bytes32 hash)
        external
        view
        returns (RH.OriginEnvironment memory)
    {
        require(_origins[hash].registry != address(0), "missing original prefix");
        return _origins[hash];
    }

    constructor(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 index,
        bytes32 commitment
    ) {
        _ownerIndex = uint8(index);
        artistRegistry = s.registry;
        operationCoordinator = coordinator;
        archiveV2 = s.archive;
        core = s.core;
        mintManager = s.mintManager;
        deploymentChainId = block.chainid;
        domainId = keccak256(abi.encode("fixture owner", index));
        authorityHydrationCommitment = commitment;
    }

    function setCompletion(bytes32 value) external {
        authorityHydrationCommitment = value;
    }

    function setCore(address value) external {
        core = value;
    }

    function setDomain(bytes32 value) external {
        domainId = value;
    }
}

contract MetadataSuccessorArtistBoundary is MetadataArtistBoundary {
    address public operationCoordinator;
    address public predecessor;
    bytes32 public predecessorHash;
    bool public sourceSealed;
    address public successor;
    uint256 public bindingCount;
    bool public bound = true;
    bool public failHistory;
    constructor(address c) MetadataArtistBoundary(c) { }

    function configure(address coordinator, address prior) external {
        operationCoordinator = coordinator;
        predecessor = prior;
        predecessorHash = prior.codehash;
        bindingCount = prior == address(0) ? 0 : 1;
    }

    function seal(address value, bool enabled) external {
        successor = value;
        sourceSealed = enabled;
    }

    function setPrior(address value, bytes32 hash, bool enabled, uint256 count) external {
        predecessor = value;
        predecessorHash = hash;
        bound = enabled;
        bindingCount = count;
    }

    function gasParameterInfo(bytes32 id) external pure returns (uint256, uint256, uint8, uint64) {
        require(id == keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS"), "parameter");
        return (400000, 150000, 2, 1); // Original Registry genesis settings, no test-only increase.
    }

    function setFailHistory(bool value) external {
        failHistory = value;
    }

    function artistRegistryCutover() external view returns (bool, address, uint64) {
        return (sourceSealed, successor, 10);
    }

    function importedHistoryBindingCount() external view returns (uint256) {
        require(!failHistory, "history unavailable");
        return bindingCount;
    }

    function importedHistoryBinding(uint256 index)
        external
        view
        returns (address, uint64, bytes32, bytes32)
    {
        require(index == 0, "index");
        return (predecessor, 9, keccak256("root"), keccak256("manifest"));
    }

    function artistHistoryPredecessorBinding(address prior)
        external
        view
        returns (bool, bytes32, uint256)
    {
        return (bound && prior == predecessor, predecessorHash, bindingCount);
    }
}

contract StreamMetadataArtistSuccessorTest is CollectionMetadataV1Fixture {
    bytes32 private constant COMPLETION = keccak256("one complete seven-owner operation60");
    MetadataSuccessorArtistBoundary private next;
    MetadataHydrationCoordinatorBoundary private priorCoordinator;
    MetadataHydrationCoordinatorBoundary private nextCoordinator;
    T.SuiteConfiguration private nextSuite;
    T.SuiteConfiguration private originalSuite;
    MetadataSuccessorArtistBoundary private immediatePrior;

    function _newArtist(address c) internal override returns (MetadataArtistBoundary) {
        return new MetadataSuccessorArtistBoundary(c);
    }

    function _graph() private {
        next = new MetadataSuccessorArtistBoundary(address(core));
        priorCoordinator = new MetadataHydrationCoordinatorBoundary();
        nextCoordinator = new MetadataHydrationCoordinatorBoundary();
        T.SuiteConfiguration memory s;
        s.registry = address(artist);
        s.archive = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.core = address(core);
        s.metadata = address(new MetadataRouterForSuccessorBoundary(address(core)));
        core.setPointer(keccak256("METADATA_ROUTER"), s.metadata);
        core.setPointer(
            keccak256("MODULE_REGISTRY"),
            address(new MetadataPublicationModulesBoundary(address(metadata)))
        );
        s.mintManager = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.roleRegistry = address(executor);
        s.primaryResolver = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.royaltyResolver = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.primaryRevenueClass = keccak256("PRIMARY");
        s.validator = address(schemas);
        for (uint256 i; i < 7; ++i) {
            s.owners[i] =
                address(new MetadataHydratedOwnerBoundary(s, address(priorCoordinator), i, 0));
        }
        priorCoordinator.configure(s);
        originalSuite = s;
        MetadataSuccessorArtistBoundary(address(artist))
            .configure(address(priorCoordinator), address(0));
        s.registry = address(next);
        s.archive = address(new MetadataRouterForSuccessorBoundary(address(core)));
        for (uint256 i; i < 7; ++i) {
            s.owners[i] = address(
                new MetadataHydratedOwnerBoundary(s, address(nextCoordinator), i, COMPLETION)
            );
        }
        nextCoordinator.configure(s);
        nextSuite = s;
        next.configure(address(nextCoordinator), address(artist));
        MetadataSuccessorArtistBoundary(address(artist)).seal(address(next), true);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(next));
    }

    function _origin() private view returns (RH.OriginEnvironment memory value) {
        value.chainId = block.chainid;
        value.registry = address(artist);
        value.coordinator = address(priorCoordinator);
        value.archive = originalSuite.archive;
        value.owners = originalSuite.owners;
        for (uint256 i; i < 7; ++i) {
            value.ownerCodeHashes[i] = originalSuite.owners[i].codehash;
        }
        value.core = address(core);
        value.manager = originalSuite.mintManager;
        value.suiteConfigurationHash = keccak256(abi.encode(originalSuite));
    }

    function _advance() private {
        immediatePrior = next;
        T.SuiteConfiguration memory s = nextSuite;
        next = new MetadataSuccessorArtistBoundary(address(core));
        nextCoordinator = new MetadataHydrationCoordinatorBoundary();
        s.registry = address(next);
        s.archive = address(new MetadataRouterForSuccessorBoundary(address(core)));
        for (uint256 i; i < 7; ++i) {
            s.owners[i] = address(
                new MetadataHydratedOwnerBoundary(s, address(nextCoordinator), i, COMPLETION)
            );
        }
        nextCoordinator.configure(s);
        nextSuite = s;
        next.configure(address(nextCoordinator), address(immediatePrior));
        immediatePrior.seal(address(next), true);
        RH.OriginEnvironment memory origin = _origin();
        MetadataHydratedOwnerBoundary(s.owners[2]).setOrigin(RH.originHash(origin), origin);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(next));
    }

    function _repeatedCandidate() private returns (P.Publication memory p) {
        _graph();
        _advance();
        bytes memory payload = bytes("same original Metadata across repeated import");
        store.publishChunk(payload);
        (, p) = _terms(address(0xa11ce), payload);
    }

    function testRepeatedSelectionRequiresExactOriginalEnvironmentInCommittedPrefix() public {
        P.Publication memory p = _repeatedCandidate();
        (bytes32 candidate,) = metadata.requireArtistRecordCandidate(p);
        require(candidate == p.candidateRecordHash, "original Metadata candidate at C");
        RH.OriginEnvironment memory origin = _origin();
        bytes32 hash = RH.originHash(origin);
        MetadataHydratedOwnerBoundary owner = MetadataHydratedOwnerBoundary(nextSuite.owners[2]);
        RH.OriginEnvironment memory missing;
        owner.setOrigin(hash, missing);
        _candidateFailure(p);
        bytes memory raw = abi.encode(origin);
        require(raw.length == 672, "all 21 original environment words");
        for (uint256 i; i < 21; ++i) {
            uint256 before_;
            assembly ("memory-safe") {
                let slot := add(add(raw, 32), mul(i, 32))
                before_ := mload(slot)
                mstore(slot, xor(before_, 1))
            }
            owner.setOrigin(hash, abi.decode(raw, (RH.OriginEnvironment)));
            _candidateFailure(p);
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), before_) }
        }
        owner.setOrigin(hash, origin);
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedPrefixDoesNotReplaceCurrentImmediateCutoverProof() public {
        P.Publication memory p = _repeatedCandidate();
        next.setPrior(address(immediatePrior), bytes32(uint256(9)), true, 1);
        _candidateFailure(p);
        next.setPrior(address(immediatePrior), address(immediatePrior).codehash, true, 2);
        _candidateFailure(p);
        next.setPrior(address(immediatePrior), address(immediatePrior).codehash, true, 1);
        immediatePrior.seal(address(next), false);
        _candidateFailure(p);
        immediatePrior.seal(address(0xbeef), true);
        _candidateFailure(p);
        immediatePrior.seal(address(next), true);
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedPrefixStillRequiresAllSevenCompletionsAndOriginalRuntime() public {
        P.Publication memory p = _repeatedCandidate();
        for (uint256 i; i < 7; ++i) {
            MetadataHydratedOwnerBoundary owner = MetadataHydratedOwnerBoundary(nextSuite.owners[i]);
            owner.setCompletion(0);
            _candidateFailure(p);
            owner.setCompletion(keccak256(abi.encode("wrong completion", i)));
            _candidateFailure(p);
            owner.setCompletion(COMPLETION);
        }
        bytes memory code = originalSuite.owners[0].code;
        vm.etch(originalSuite.owners[0], hex"00");
        _candidateFailure(p);
        vm.etch(originalSuite.owners[0], code);
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedOriginalAuthorizationConsumptionPersistsAtThirdAndFourthRegistry() public {
        address recorder = address(0xa11ce);
        bytes memory payload = bytes("original consumption persists");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(recorder, payload);
        bytes32 used = keccak256("original used at A");
        artist.setSigner(recorder);
        artist.permit(used, p);
        bytes32 original =
            metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, used);
        _graph();
        _advance();
        for (uint256 hop; hop < 2; ++hop) {
            next.setSigner(recorder);
            next.permit(used, p);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, used
                )
            );
            metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, used);
            if (hop == 0) _advance();
        }
        r.effectiveAt = 2;
        p = _publication(recorder, r);
        bytes32 fresh = keccak256("fresh original op24 at D");
        next.permit(fresh, p);
        bytes32 saved =
            metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, fresh);
        require(
            saved == _oldRecordHash(recorder, r) && saved != original, "same Metadata record domain"
        );
        require(metadata.artistRegistry() == address(artist), "birth anchor unchanged at D");
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(saved);
        require(
            receipt.artistAuthorization == fresh && receipt.recorder == recorder,
            "original successor callback"
        );
    }

    function testRepeatedSelectionRetainsOriginalChainAndRouterChecks() public {
        P.Publication memory p = _repeatedCandidate();
        MetadataSuccessorArtistBoundary(address(artist)).seal(address(immediatePrior), false);
        _candidateFailure(p);
        MetadataSuccessorArtistBoundary(address(artist)).seal(address(immediatePrior), true);
        core.setPointer(
            keccak256("METADATA_ROUTER"),
            address(new MetadataRouterForSuccessorBoundary(address(core)))
        );
        _candidateFailure(p);
        core.setPointer(keccak256("METADATA_ROUTER"), nextSuite.metadata);
        uint256 chain = nextCoordinator.deploymentChainId();
        vm.chainId(chain + 1);
        _candidateFailure(p);
        vm.chainId(chain);
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedCandidateWorkerRetainsColdGenesis400kBudget() public {
        P.Publication memory p = _repeatedCandidate();
        MetadataPublicationBudgetProbe probe = new MetadataPublicationBudgetProbe();
        (address payloadPointer,) =
            store.chunk(keccak256(bytes("same original Metadata across repeated import")));
        safeVm.cool(payloadPointer);
        _coolSuite(originalSuite);
        _coolSuite(nextSuite);
        safeVm.cool(address(priorCoordinator));
        safeVm.cool(address(nextCoordinator));
        safeVm.cool(address(immediatePrior));
        safeVm.cool(address(metadata));
        safeVm.cool(address(store));
        safeVm.cool(address(StreamMetadataArtistSelection));
        safeVm.cool(address(StreamMetadataRecoveredArtistSelection));
        safeVm.cool(address(ImportedReads));
        safeVm.cool(address(ImportedState));
        safeVm.cool(address(StreamMetadataArtistConfiguration));
        safeVm.cool(address(StreamRecordDocumentReads));
        safeVm.cool(address(StreamMetadataPublicationEncoding));
        safeVm.cool(address(StreamCollectionRecordHashes));
        safeVm.cool(address(StreamArtistRecordPublicationReads));
        bytes32 hash = probe.candidate(nextSuite, p);
        require(hash == address(metadata).codehash, "actual publication worker original400k at C");
    }

    function testCompactCertificateRejectsMissingWrongAndNoncanonicalWordsThenExactRetry() public {
        P.Publication memory p = _repeatedCandidate();
        RH.OriginEnvironment memory original = _origin();
        bytes32 h = RH.originHash(original);
        address owner = nextSuite.owners[2];
        bytes memory call_ = abi.encodeWithSignature("recoveredHydrationImportedOriginCertificate(bytes32)", h);
        MetadataCertificateVm cheat = MetadataCertificateVm(address(vm));
        bytes[] memory invalid = new bytes[](8);
        invalid[0] = bytes(""); // Full old origin getter remains present; no fallback allowed.
        invalid[1] = abi.encode(bytes32(uint256(1)), COMPLETION, uint64(1), uint8(2));
        invalid[2] = abi.encode(h, bytes32(0), uint64(1), uint8(2));
        invalid[3] = abi.encode(h, bytes32(uint256(1)), uint64(1), uint8(2));
        invalid[4] = abi.encode(h, COMPLETION, uint64(0), uint8(2));
        invalid[5] = abi.encode(h, COMPLETION, uint64(1), uint8(1));
        invalid[6] = abi.encode(h, COMPLETION, uint256(1) << 64, uint8(2));
        invalid[7] = abi.encode(h, COMPLETION, uint64(1), uint256(258));
        for (uint256 i; i < invalid.length; ++i) {
            cheat.mockCall(owner, call_, invalid[i]);
            _candidateFailure(p);
            cheat.clearMockedCalls();
            (bytes32 result,) = metadata.requireArtistRecordCandidate(p);
            require(result == p.candidateRecordHash, "exact certificate retry");
        }
        cheat.mockCall(owner, call_, abi.encode(h, COMPLETION, uint64(1), uint8(2), bytes32(0)));
        _candidateFailure(p); cheat.clearMockedCalls();
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedDependencyFrameRefusesMalformedSourceSuiteThenExactRetry() public {
        P.Publication memory p = _repeatedCandidate();
        MetadataCertificateVm cheat = MetadataCertificateVm(address(vm));
        bytes memory selector = abi.encodeWithSignature("suiteConfiguration()");
        cheat.mockCall(address(priorCoordinator), selector, abi.encode(originalSuite, bytes32(0)));
        _candidateFailure(p); cheat.clearMockedCalls();
        T.SuiteConfiguration memory changed = originalSuite;
        changed.primaryRevenueClass = keccak256("wrong class");
        cheat.mockCall(address(priorCoordinator), selector, abi.encode(changed));
        _candidateFailure(p); cheat.clearMockedCalls();
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedFixedWordShortLongAndZeroRefuseThenExactRetry() public {
        P.Publication memory p = _repeatedCandidate();
        metadata.requireArtistRecordCandidate(p);
        MetadataCertificateVm cheat = MetadataCertificateVm(address(vm));
        address[3] memory targets = [address(next), address(priorCoordinator), nextSuite.owners[6]];
        bytes4[3] memory selectors = [
            bytes4(keccak256("importedHistoryBindingCount()")),
            bytes4(keccak256("configurationHash()")),
            bytes4(keccak256("authorityHydrationCommitment()"))
        ];
        for (uint256 i; i < 3; ++i) {
            bytes memory input = abi.encodePacked(selectors[i]);
            (bool beforeOK, bytes memory original) = targets[i].staticcall(input);
            require(beforeOK && original.length == 32, "actual original full word");
            bytes[] memory refused = new bytes[](4);
            refused[0] = bytes("");
            refused[1] = new bytes(31);
            refused[2] = abi.encode(bytes32(uint256(1)), bytes32(uint256(2)));
            refused[3] = abi.encode(bytes32(0));
            for (uint256 j; j < refused.length; ++j) {
                cheat.mockCall(targets[i], input, refused[j]);
                _candidateFailure(p);
                cheat.clearMockedCalls();
                (bytes32 candidate,) = metadata.requireArtistRecordCandidate(p);
                require(candidate == p.candidateRecordHash, "exact original word retry");
            }
        }
    }

    function testRepeatedAddressCanonicalityAndMissingCodeRemainMandatory() public {
        P.Publication memory p = _repeatedCandidate();
        metadata.requireArtistRecordCandidate(p);
        MetadataCertificateVm cheat = MetadataCertificateVm(address(vm));
        // Address-returning getters retain their original full abi.decode path.
        cheat.mockCall(address(priorCoordinator), abi.encodeWithSignature("finalityRegistry()"),
            abi.encode((uint256(1) << 160) | uint160(priorCoordinator.finalityRegistry())));
        _candidateFailure(p);
        cheat.clearMockedCalls();
        metadata.requireArtistRecordCandidate(p);
        bytes memory runtime = nextSuite.owners[6].code;
        vm.etch(nextSuite.owners[6], bytes(""));
        _candidateFailure(p);
        vm.etch(nextSuite.owners[6], runtime);
        (bytes32 candidate,) = metadata.requireArtistRecordCandidate(p);
        require(candidate == p.candidateRecordHash, "exact runtime retry");
    }

    function testCandidateDocumentAndSelectionRefusalsAreIndependentlyMandatory() public {
        P.Publication memory p = _repeatedCandidate();
        P.Publication memory bad = abi.decode(abi.encode(p), (P.Publication));
        bad.subjectId = bytes32(uint256(77)); _candidateFailure(bad);
        bad = abi.decode(abi.encode(p), (P.Publication));
        bad.schemaId = keccak256("unregistered schema"); _candidateFailure(bad);
        bad = abi.decode(abi.encode(p), (P.Publication));
        bad.payloadHash = keccak256("missing bytes"); _candidateFailure(bad);
        bad = abi.decode(abi.encode(p), (P.Publication));
        bad.candidateRecordHash = bytes32(uint256(8)); _candidateFailure(bad);
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(0);
        _candidateFailure(p);
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(COMPLETION);
        metadata.requireArtistRecordCandidate(p);
    }

    function testRepeatedCandidateLowParentBudgetRefusesWithoutChangingConsumption() public {
        P.Publication memory p = _repeatedCandidate();
        bytes memory input = abi.encodeCall(metadata.requireArtistRecordCandidate, (p));
        (bool ok,) = address(metadata).staticcall{gas: 150000}(input);
        require(!ok, "full dependency reservation retained");
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash && metadata.payloadPointerCount(1) == 0, "read-only exact retry");
    }

    function _terms(address recorder, bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p)
    {
        r = _record(ARTIST, payload);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        p = _publication(recorder, r);
    }

    function _candidateFailure(P.Publication memory p) private {
        (bool ok,) =
            address(metadata).staticcall(abi.encodeCall(metadata.requireArtistRecordCandidate, (p)));
        require(!ok, "unproved successor accepted");
    }

    function testOriginalPermitConsumptionSurvivesSuccessorAndNewPublicationUsesSameHostDomain()
        public
    {
        address recorder = address(0xa11ce);
        bytes memory payload = bytes("original and successor bytes");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(recorder, payload);
        artist.setSigner(recorder);
        artist.permit(keccak256("used"), p);
        bytes32 original = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("used")
        );
        require(original == _oldRecordHash(recorder, r), "original preimage");
        _graph();
        next.setSigner(recorder);
        next.permit(keccak256("used"), p);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector,
                keccak256("used")
            )
        );
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, keccak256("used"));
        r.effectiveAt = 2;
        p = _publication(recorder, r);
        next.permit(keccak256("fresh"), p);
        bytes32 saved = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("fresh")
        );
        require(saved == _oldRecordHash(recorder, r), "same Metadata/Core record domain");
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(saved);
        require(
            receipt.artistAuthorization == keccak256("fresh") && receipt.recorder == recorder,
            "actual successor callback and original recorder"
        );
        require(metadata.artistRegistry() == address(artist), "birth anchor retained");
    }

    function testActualArtistCandidateWorkerUsesGenesis400kBudgetWithDistinctRouter() public {
        _graph();
        require(nextSuite.metadata != address(metadata), "router and record host distinct");
        bytes memory payload = bytes("bounded original Artist worker");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        MetadataPublicationBudgetProbe probe = new MetadataPublicationBudgetProbe();
        bytes32 hash = probe.candidate(nextSuite, p);
        require(hash == address(metadata).codehash, "actual fixed candidate worker at original cap");
        T.SuiteConfiguration memory prior = priorCoordinator.authorityHydrationSuite();
        T.SuiteConfiguration memory current = nextSuite;
        (address payloadPointer,) = store.chunk(keccak256(payload));
        _coolSuite(prior);
        _coolSuite(current);
        safeVm.cool(address(priorCoordinator));
        safeVm.cool(address(nextCoordinator));
        safeVm.cool(address(metadata));
        safeVm.cool(address(store));
        safeVm.cool(address(StreamMetadataArtistSelection));
        safeVm.cool(address(StreamMetadataArtistConfiguration));
        safeVm.cool(address(StreamRecordDocumentReads));
        safeVm.cool(address(StreamMetadataPublicationEncoding));
        safeVm.cool(address(StreamCollectionRecordHashes));
        safeVm.cool(payloadPointer);
        safeVm.cool(address(StreamArtistRecordPublicationReads));
        hash = probe.candidate(current, p);
        require(hash == address(metadata).codehash, "cold original400k callback");
        core.setPointer(
            keccak256("METADATA_ROUTER"),
            address(new MetadataRouterForSuccessorBoundary(address(core)))
        );
        _candidateFailure(p);
    }

    function _coolSuite(T.SuiteConfiguration memory s) private {
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(s.owners[i]);
        }
        safeVm.cool(s.registry);
        safeVm.cool(s.archive);
        safeVm.cool(s.core);
        safeVm.cool(s.mintManager);
        safeVm.cool(s.roleRegistry);
        safeVm.cool(s.metadata);
        safeVm.cool(s.primaryResolver);
        safeVm.cool(s.royaltyResolver);
        safeVm.cool(s.validator);
    }

    function testEveryOwnerMustHaveMatchingNonzeroCompletionAndCorrectDomain() public {
        _graph();
        bytes memory payload = bytes("complete only");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        for (uint256 i; i < 7; ++i) {
            MetadataHydratedOwnerBoundary owner = MetadataHydratedOwnerBoundary(nextSuite.owners[i]);
            owner.setCompletion(0);
            _candidateFailure(p);
            owner.setCompletion(keccak256(abi.encode(i)));
            _candidateFailure(p);
            owner.setCompletion(COMPLETION);
            owner.setDomain(keccak256("wrong owner domain"));
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "constructor owner binding"));
            nextCoordinator.configure(nextSuite);
            owner.setDomain(keccak256(abi.encode("fixture owner", i)));
            bytes memory runtime = address(owner).code;
            vm.etch(address(owner), hex"00");
            _candidateFailure(p);
            vm.etch(address(owner), runtime);
        }
        (bytes32 hash, uint8 kind) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash && kind == 8, "all seven restored");
    }

    function testSealAndImmediatePinnedPredecessorRequiredEvenWithCompleteOwnerClaims() public {
        _graph();
        bytes memory payload = bytes("lineage");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        MetadataSuccessorArtistBoundary original = MetadataSuccessorArtistBoundary(address(artist));
        original.seal(address(next), false);
        _candidateFailure(p);
        original.seal(address(0xbeef), true);
        _candidateFailure(p);
        original.seal(address(next), true);
        next.setPrior(address(artist), bytes32(uint256(7)), true, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, false, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, true, 2);
        _candidateFailure(p);
        next.setPrior(address(0xbeef), address(artist).codehash, true, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, true, 1);
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "exact lineage restored");
    }

    function testSuiteAndOwnerBindingsCannotSubstituteDifferentCoreOrMetadata() public {
        _graph();
        bytes memory payload = bytes("suite");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        T.SuiteConfiguration memory s = nextSuite;
        s.metadata = address(0xbeef);
        nextCoordinator.corruptSuiteForNegative(s);
        _candidateFailure(p);
        s = nextSuite;
        s.core = address(0xbeef);
        nextCoordinator.corruptSuiteForNegative(s);
        _candidateFailure(p);
        s = nextSuite;
        s.primaryResolver = address(0xbeef);
        nextCoordinator.corruptSuiteForNegative(s);
        _candidateFailure(p);
        nextCoordinator.configure(nextSuite);
        MetadataHydratedOwnerBoundary(nextSuite.owners[3]).setCore(address(0xbeef));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "constructor owner binding"));
        nextCoordinator.configure(nextSuite);
        MetadataHydratedOwnerBoundary(nextSuite.owners[3]).setCore(address(core));
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "bindings restored");
    }

    function testUnavailableProofAndUnselectedMetadataFailClosed() public {
        _graph();
        bytes memory payload = bytes("availability");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        next.setFailHistory(true);
        _candidateFailure(p);
        next.setFailHistory(false);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(schemas));
        _candidateFailure(p);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "current route restored");
    }

    function testActualSafeFailurePreservesNonceAuthorizationAndChunkThenIdenticalRetry() public {
        _graph();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xa11;
        keys[1] = 0xb22;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        bytes memory payload = bytes("Safe successor publication");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(address(account), payload);
        bytes32 permit = keccak256("Safe permit");
        next.setSigner(address(account));
        next.permit(permit, p);
        bytes memory data = abi.encodeCall(
            metadata.recordArtistCollectionRecordWithPayload,
            (address(account), 1, r, payload, permit)
        );
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(metadata), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(0);
        (bool ok, bytes memory reason) = address(account)
            .call(
                abi.encodeCall(
                    account.execTransaction,
                    (
                        address(metadata),
                        0,
                        data,
                        0,
                        0,
                        0,
                        0,
                        address(0),
                        payable(address(0)),
                        signatures
                    )
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe denied"
        );
        require(
            account.nonce() == nonce && !metadata.consumedArtistAuthorization(permit)
                && metadata.payloadPointerCount(1) == 0,
            "all state unchanged"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "no denied payload");
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(COMPLETION);
        require(
            account.execTransaction(
                address(metadata), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            ),
            "same exact signed transaction"
        );
        require(
            account.nonce() == nonce + 1 && metadata.consumedArtistAuthorization(permit),
            "one successful use"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(p.candidateRecordHash);
        require(receipt.recorder == address(account), "Safe recorder retained");
    }

    function testLateAppendFailureRollsBackSuccessorUseAndActualChunk() public {
        _graph();
        bytes memory payload = bytes("late append");
        (IStreamPreservationRecords.CollectionRecord memory r,) = _terms(address(0xa11ce), payload);
        r.uri = "javascript:bad";
        P.Publication memory p = _publication(address(0xa11ce), r);
        bytes32 permit = keccak256("late permit");
        next.setSigner(address(0xa11ce));
        next.permit(permit, p);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRenderer.UnsafeMetadataURI.selector));
        metadata.recordArtistCollectionRecordWithPayload(address(0xa11ce), 1, r, payload, permit);
        require(
            !metadata.consumedArtistAuthorization(permit) && metadata.payloadPointerCount(1) == 0,
            "authorization and index rollback"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "actual store rollback");
    }
}
