// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataArtistSuccessor.t.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistHydrationGuards as RealGuards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistOwnerCheck as RealCheck
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerCheck.sol";
import {
    StreamArtistOwnerCommit as RealCommit
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerCommit.sol";
import {
    StreamArtistAuthorityCheckpoint as RealCheckpoint
} from "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

interface MetadataReadCostVm {
    function getNonce(address) external view returns (uint64);
}

/// @dev Actual Owner immutables, original guard/commit and namespace producers/readers.
/// Only this fixture's matching Coordinator may install the explicitly typed source prefix.
contract MetadataRealReadOwner is StreamArtistOwner {
    uint8 private immutable index;

    constructor(T.SuiteConfiguration memory s, address coordinator, uint8 i)
        StreamArtistOwner(
            s.registry, coordinator, s.archive, RH.ownerDomain(i), s.core, s.mintManager
        )
    {
        index = i;
    }

    function installFixturePrefix(
        T.ActionContext calldata c,
        RH.OwnerProvenance calldata p,
        bytes32 completed,
        bool omitPrefix
    ) external {
        _check(c, 60);
        AH.OwnerData memory empty;
        bytes32 delta = RealGuards.applyGuards(
            _replay, empty, artistRegistry, operationCoordinator, archiveV2, domainId, completed
        );
        if (!omitPrefix) {
            ImportedState.installOwnerPrefix(p, index, completed, c.expected.revision + 1);
        }
        _commit(c, keccak256("typed source admission"), completed, delta, bytes32(0));
    }
}

/// @dev Typed Coordinator boundary, NOT an operation60 source-authority implementation.
/// Matches actual storage suite plus immutable configuration/finality/provider getter shapes.
/// Configuration preimage is independently copied from the actual original constructor.
contract MetadataImmutableReadCoordinator {
    T.SuiteConfiguration private suite;
    address private immutable fixture;
    uint256 public immutable deploymentChainId = block.chainid;
    bytes32 public immutable configurationHash;
    address public immutable finalityRegistry;
    address public immutable finalityEvidenceProvider;

    constructor(T.SuiteConfiguration memory s) {
        fixture = msg.sender;
        address[16] memory targets;
        bytes32[16] memory runtimeHashes;
        for (uint256 i; i < 7; ++i) {
            StreamArtistOwner owner = StreamArtistOwner(s.owners[i]);
            require(
                owner.artistRegistry() == s.registry
                    && owner.operationCoordinator() == address(this)
                    && owner.archiveV2() == s.archive && owner.core() == s.core
                    && owner.mintManager() == s.mintManager
                    && owner.deploymentChainId() == block.chainid
                    && owner.domainId() == RH.ownerDomain(uint8(i)),
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

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function installFixturePrefix(
        RH.OriginEnvironment memory original,
        bytes32 completed,
        uint8 omitIndex,
        uint8 wrongIndex
    ) external {
        require(msg.sender == fixture, "fixture producer");
        for (uint8 i; i < 7; ++i) {
            RH.OwnerProvenance memory p;
            p.origins = new RH.OriginEnvironment[](1);
            p.origins[0] = original;
            p.eras = new RH.OwnerEra[](1);
            p.eras[0].originHash = RH.originHash(original);
            p.eras[0].checkpoint.schema = RH.CHECKPOINT;
            p.eras[0].checkpoint.ownerState =
                T.Snapshot(RH.ownerDomain(i), 12, bytes32(uint256(300)), bytes32(uint256(301)));
            MetadataRealReadOwner owner = MetadataRealReadOwner(suite.owners[i]);
            owner.installFixturePrefix(
                T.ActionContext(60, fixture, owner.ownerStateSnapshotV2()),
                p,
                i == wrongIndex ? keccak256("wrong completion") : completed,
                i == omitIndex
            );
        }
    }
}

/// @notice Cold cost recipe using the real Owner/Guards/Reads/State call paths.
/// @dev Core, source admission/history, immutable Coordinator and Archive remain explicit typed
/// boundaries. No full operation55–60, real Identity concrete owner or current graph claim.
contract StreamMetadataArtistRealOwnerBudgetTest is CollectionMetadataV1Fixture {
    bytes32 private constant COMPLETE = keccak256("real seven owner read fixture");
    T.SuiteConfiguration private original;
    T.SuiteConfiguration private current;
    MetadataImmutableReadCoordinator private originalCoordinator;
    MetadataImmutableReadCoordinator private currentCoordinator;
    MetadataSuccessorArtistBoundary private currentArtist;
    MetadataSuccessorArtistBoundary private previous;

    function _newArtist(address c) internal override returns (MetadataArtistBoundary) {
        return new MetadataSuccessorArtistBoundary(c);
    }

    function _owners(T.SuiteConfiguration memory s)
        private
        returns (T.SuiteConfiguration memory, MetadataImmutableReadCoordinator coordinator)
    {
        uint256 nonce = uint256(MetadataReadCostVm(address(vm)).getNonce(address(this))) + 7;
        require(nonce > 0 && nonce < 128, "fixed test CREATE nonce range");
        address predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", address(this), uint8(nonce)))))
        );
        for (uint8 i; i < 7; ++i) {
            s.owners[i] = address(new MetadataRealReadOwner(s, predicted, i));
        }
        coordinator = new MetadataImmutableReadCoordinator(s);
        require(address(coordinator) == predicted, "actual CREATE/coordinator identity");
        return (s, coordinator);
    }

    function _graph(uint8 omitIndex, uint8 wrongIndex) private returns (P.Publication memory p) {
        T.SuiteConfiguration memory s;
        s.registry = address(artist);
        s.core = address(core);
        s.archive = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.metadata = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.mintManager = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.roleRegistry = address(executor);
        s.primaryResolver = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.royaltyResolver = address(new MetadataRouterForSuccessorBoundary(address(core)));
        s.primaryRevenueClass = keccak256("PRIMARY");
        s.validator = address(schemas);
        (original, originalCoordinator) = _owners(s);
        MetadataSuccessorArtistBoundary(address(artist))
            .configure(address(originalCoordinator), address(0));
        previous = new MetadataSuccessorArtistBoundary(address(core));
        currentArtist = new MetadataSuccessorArtistBoundary(address(core));
        s.registry = address(currentArtist);
        s.archive = address(new MetadataRouterForSuccessorBoundary(address(core)));
        (current, currentCoordinator) = _owners(s);
        currentArtist.configure(address(currentCoordinator), address(previous));
        previous.seal(address(currentArtist), true);
        MetadataSuccessorArtistBoundary(address(artist)).seal(address(previous), true);
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = address(artist);
        o.coordinator = address(originalCoordinator);
        o.archive = original.archive;
        o.owners = original.owners;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = original.owners[i].codehash;
        }
        o.core = address(core);
        o.manager = original.mintManager;
        o.suiteConfigurationHash = keccak256(abi.encode(original));
        currentCoordinator.installFixturePrefix(o, COMPLETE, omitIndex, wrongIndex);
        core.setPointer(keccak256("METADATA_ROUTER"), current.metadata);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(currentArtist));
        core.setPointer(
            keccak256("MODULE_REGISTRY"),
            address(new MetadataPublicationModulesBoundary(address(metadata)))
        );
        bytes memory payload = bytes("actual immutable-bound owner cold read");
        store.publishChunk(payload);
        IStreamPreservationRecords.CollectionRecord memory r = _record(ARTIST, payload);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        p = _publication(address(0xa11ce), r);
    }

    function _coolSuite(T.SuiteConfiguration memory s) private {
        for (uint8 i; i < 7; ++i) {
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

    function _cold() private {
        (address pointer,) = store.chunk(keccak256(bytes("actual immutable-bound owner cold read")));
        safeVm.cool(pointer);
        _coolSuite(original);
        _coolSuite(current);
        safeVm.cool(address(originalCoordinator));
        safeVm.cool(address(currentCoordinator));
        safeVm.cool(address(previous));
        safeVm.cool(address(metadata));
        safeVm.cool(address(store));
        safeVm.cool(address(StreamMetadataArtistSelection));
        safeVm.cool(address(StreamMetadataRecoveredArtistSelection));
        safeVm.cool(address(StreamMetadataArtistConfiguration));
        safeVm.cool(address(StreamRecordDocumentReads));
        safeVm.cool(address(StreamMetadataPublicationEncoding));
        safeVm.cool(address(StreamCollectionRecordHashes));
        safeVm.cool(address(StreamArtistRecordPublicationReads));
        safeVm.cool(address(ImportedReads));
        safeVm.cool(address(ImportedState));
        safeVm.cool(address(RealGuards));
        safeVm.cool(address(RealCheck));
        safeVm.cool(address(RealCommit));
        safeVm.cool(address(RealCheckpoint));
    }

    function testRealOwnerColdCandidateUsesOriginal400kAndSingle150kFrame() public {
        P.Publication memory p = _graph(255, 255);
        MetadataPublicationBudgetProbe probe = new MetadataPublicationBudgetProbe();
        _cold();
        require(
            probe.candidate(current, p) == address(metadata).codehash, "real read path cold400k"
        );
    }

    function testRealOwnerColdMissingPrefixRefusesDespiteSevenMatchingMarkers() public {
        P.Publication memory p = _graph(2, 255);
        for (uint8 i; i < 7; ++i) {
            require(
                StreamArtistOwner(current.owners[i]).authorityHydrationCommitment() == COMPLETE,
                "original seven markers"
            );
        }
        MetadataPublicationBudgetProbe probe = new MetadataPublicationBudgetProbe();
        _cold();
        (bool ok,) = address(probe).staticcall(abi.encodeCall(probe.candidate, (current, p)));
        require(!ok, "missing original prefix accepted");
    }

    function testRealOwnerColdMismatchedCompletionRefusesWithCompletePrefix() public {
        P.Publication memory p = _graph(255, 6);
        MetadataPublicationBudgetProbe probe = new MetadataPublicationBudgetProbe();
        _cold();
        (bool ok,) = address(probe).staticcall(abi.encodeCall(probe.candidate, (current, p)));
        require(!ok, "mismatched seventh actual marker accepted");
    }
}
