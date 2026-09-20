// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataArtistSuccessor.t.sol";
import {
    MetadataRealReadOwner,
    MetadataImmutableReadCoordinator,
    MetadataRealOwnerReadDeployment
} from "../../helpers/MetadataRealOwnerReadFixture.sol";
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
        return MetadataRealOwnerReadDeployment.deploy(address(vm), s);
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
