// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";
import "./StreamConservationSelectionFixture.sol";
import "../../helpers/RecordSelectionLockFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamCurrentAuthorityWorkRecordSelection.sol";
import "../../../smart-contracts/domains/metadata/StreamCurrentAuthorityConservationRecordSelection.sol";
import {
    StreamMetadataArtistConfiguration as ArtistConfiguration
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

interface CurrentAuthoritySelectionVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

contract CurrentAuthoritySelectionMarker { }

/// @dev Explicit canonical Artist/Core/Coordinator response boundaries. Real Metadata, schema,
/// byte-store, selector state, domain hashes, association reads and Metadata ancestry resolver
/// execute. No genuine op55/op60 import, real governance scheduling or Finality claim.
abstract contract CurrentAuthoritySelectionBoundary {
    CurrentAuthoritySelectionVm private constant avm =
        CurrentAuthoritySelectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Graph {
        T.SuiteConfiguration suite;
        address coordinator;
        address finality;
        address provider;
    }

    Graph internal anchor;
    bytes32 internal constant COMPLETION = keccak256("explicit complete-import response boundary");

    function _startGraph(
        address core_,
        address metadata_,
        address registry,
        address coordinator_,
        address identity,
        address binding,
        address attribution
    ) internal {
        T.SuiteConfiguration memory s;
        s.registry = registry;
        s.archive = _node();
        s.core = core_;
        s.mintManager = _node();
        s.roleRegistry = _node();
        s.metadata = _node();
        s.primaryResolver = _node();
        s.royaltyResolver = _node();
        s.primaryRevenueClass = keccak256("original revenue class");
        s.validator = _node();
        for (uint256 i; i < 7; ++i) {
            s.owners[i] = _node();
        }
        s.owners[0] = binding;
        s.owners[2] = identity;
        s.owners[4] = attribution;
        anchor = Graph(s, coordinator_, _node(), _node());
        _configure(anchor);
        _answer(s.metadata, "core()", abi.encode(core_));
        MetadataCoreBoundary(core_).setPointer(keccak256("METADATA_ROUTER"), s.metadata);
        // Generous explicit boundary cap; this suite does not establish production gas budgets.
        avm.mockCall(
            metadata_,
            abi.encodeWithSignature(
                "gasParameter(bytes32)", keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS")
            ),
            abi.encode(uint256(2000000))
        );
    }

    function _successor(Graph memory prior) internal returns (Graph memory next) {
        // New addresses are allocated at the transition, after the selector has saved history.
        next.suite = anchor.suite;
        next.suite.registry = _node();
        next.suite.archive = _node();
        for (uint256 i; i < 7; ++i) {
            next.suite.owners[i] = _node();
        }
        next.coordinator = _node();
        next.finality = _node();
        next.provider = _node();
        _configure(next);
        _answer(
            prior.suite.registry,
            "artistRegistryCutover()",
            abi.encode(true, next.suite.registry, uint64(10))
        );
        _answer(next.suite.registry, "importedHistoryBindingCount()", abi.encode(uint256(1)));
        avm.mockCall(
            next.suite.registry,
            abi.encodeWithSignature("importedHistoryBinding(uint256)", uint256(0)),
            abi.encode(
                prior.suite.registry, uint64(9), keccak256("history root"), keccak256("manifest")
            )
        );
        avm.mockCall(
            next.suite.registry,
            abi.encodeWithSignature(
                "artistHistoryPredecessorBinding(address)", prior.suite.registry
            ),
            abi.encode(true, prior.suite.registry.codehash, uint256(1))
        );
        _certificate(next, _anchorOriginHash(), COMPLETION);
        MetadataCoreBoundary(anchor.suite.core)
            .setPointer(keccak256("ARTIST_REGISTRY"), next.suite.registry);
    }

    function _configure(Graph memory g) private {
        _answer(g.suite.registry, "core()", abi.encode(g.suite.core));
        _answer(g.suite.registry, "operationCoordinator()", abi.encode(g.coordinator));
        _answer(g.coordinator, "deploymentChainId()", abi.encode(block.chainid));
        _answer(g.coordinator, "suiteConfiguration()", abi.encode(g.suite));
        _answer(g.coordinator, "finalityRegistry()", abi.encode(g.finality));
        _answer(g.coordinator, "finalityEvidenceProvider()", abi.encode(g.provider));
        _answer(
            g.coordinator,
            "configurationHash()",
            abi.encode(ArtistConfiguration.hash(g.coordinator, g.suite, g.finality, g.provider))
        );
        for (uint256 i; i < 7; ++i) {
            address owner = g.suite.owners[i];
            _answer(owner, "core()", abi.encode(g.suite.core));
            _answer(owner, "artistRegistry()", abi.encode(g.suite.registry));
            _answer(owner, "operationCoordinator()", abi.encode(g.coordinator));
            _answer(owner, "deploymentChainId()", abi.encode(block.chainid));
            _answer(owner, "authorityHydrationCommitment()", abi.encode(COMPLETION));
        }
    }

    function _binding(Graph memory g, T.Binding memory b, uint8 status) internal {
        avm.mockCall(
            g.suite.owners[0],
            abi.encodeWithSignature("binding(uint256)", uint256(1)),
            abi.encode(b)
        );
        avm.mockCall(
            g.suite.owners[4],
            abi.encodeWithSignature("attributionState(uint256)", uint256(1)),
            abi.encode(status, b.generation)
        );
        avm.mockCall(
            g.suite.owners[2],
            abi.encodeWithSignature("authorityState(bytes32)", b.artistId),
            abi.encode(b.artistAddress, uint8(1), uint8(1), b.identityRecordHash)
        );
    }

    function _copyPublication(Graph memory g, address originalOwner, bytes32 authorization)
        internal
    {
        IStreamArtistRecordPublicationOwner.Record memory r = IStreamArtistRecordPublicationOwner(
                originalOwner
            ).publicationAttestation(authorization);
        T.AttestationRecord memory a =
            IStreamArtistAttributionOwner(originalOwner).attestationRecord(authorization);
        bytes memory statement =
            IStreamArtistAttributionOwner(originalOwner).statementBytes(a.statementHash);
        avm.mockCall(
            g.suite.owners[4],
            abi.encodeCall(
                IStreamArtistRecordPublicationOwner.publicationAttestation, (authorization)
            ),
            abi.encode(r)
        );
        avm.mockCall(
            g.suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attestationRecord, (authorization)),
            abi.encode(a)
        );
        avm.mockCall(
            g.suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.statementBytes, (a.statementHash)),
            abi.encode(statement)
        );
    }

    function _completion(Graph memory g, uint256 owner, bytes32 value) internal {
        _answer(g.suite.owners[owner], "authorityHydrationCommitment()", abi.encode(value));
    }

    function _certificate(Graph memory g, bytes32 actual, bytes32 completion) internal {
        avm.mockCall(
            g.suite.owners[2],
            abi.encodeWithSignature(
                "recoveredHydrationImportedOriginCertificate(bytes32)", _anchorOriginHash()
            ),
            abi.encode(actual, completion, uint64(3), uint8(2))
        );
    }

    function _anchorOriginHash() internal view returns (bytes32) {
        RH.OriginEnvironment memory e;
        e.chainId = block.chainid;
        e.registry = anchor.suite.registry;
        e.coordinator = anchor.coordinator;
        e.archive = anchor.suite.archive;
        e.owners = anchor.suite.owners;
        for (uint256 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = e.owners[i].codehash;
        }
        e.core = anchor.suite.core;
        e.manager = anchor.suite.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(anchor.suite));
        return RH.originHash(e);
    }

    function _currentTuple(address selector, Graph memory g) internal view {
        (address[5] memory targets, bytes32[5] memory hashes) =
            IStreamRecordCurrentAuthority(selector).currentArtistContext();
        address[5] memory expected = [
            g.suite.registry, g.coordinator, g.suite.owners[2], g.suite.owners[0], g.suite.owners[4]
        ];
        for (uint256 i; i < 5; ++i) {
            require(
                targets[i] == expected[i] && hashes[i] == expected[i].codehash,
                "exact live owner order and runtime"
            );
        }
    }

    function _node() private returns (address) {
        return address(new CurrentAuthoritySelectionMarker());
    }

    function _answer(address target, string memory signature, bytes memory result) private {
        avm.mockCall(target, abi.encodeWithSignature(signature), result);
    }
}

contract StreamCurrentAuthorityWorkSelectionTest is
    WorkSelectionFixture,
    RecordSelectionLockFixture,
    CurrentAuthoritySelectionBoundary
{
    function _newProfile() private returns (StreamWorkRecordSelection legacy) {
        legacy = selection;
        _startGraph(
            address(core),
            address(metadata),
            address(facade),
            address(coordinator),
            address(identityOwner),
            address(bindingOwner),
            address(attributionOwner)
        );
        selection = StreamWorkRecordSelection(
            address(
                new StreamCurrentAuthorityWorkRecordSelection(
                    address(core), address(metadata), address(schemas)
                )
            )
        );
        require(
            IStreamRecordCurrentAuthority(address(selection)).currentAuthorityProfile()
                == keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1")
        );
        require(selection.supportsInterface(type(IStreamRecordCurrentAuthority).interfaceId));
    }

    function _sameBinding(Graph memory g) private {
        _binding(
            g, T.Binding(ARTIST_ID, ORIGINAL, IDENTITY, BINDING, 1, 0, 0, 0, address(this), true), 2
        );
    }

    function testWorkSameSelectorPreservesAHistoryAndAppendsThroughBThenUnpredictedC()
        public
        ready
    {
        _bound(1, BINDING, 2);
        StreamWorkRecordSelection legacy = _newProfile();
        StreamWorkRecordTypes.Description memory a = _artistDescription();
        bytes32 ah = _curatorPublish(a);
        IStreamWorkRecordSelection.Selection memory sa =
            selection.selectCurrent(1, subject, ah, 0, 0, _witness(ah, a));
        legacy.selectCurrent(1, subject, ah, 0, 0, _witness(ah, a));
        a.predecessor = ah;
        a.full.title = "B head from retained original Metadata";
        bytes32 bh = _curatorPublish(a);
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        _currentTuple(address(selection), b);
        require(selection.requireCurrent(1, subject, ah, 1).selectionHash == sa.selectionHash);
        vm.expectRevert();
        legacy.requireCurrent(1, subject, ah, 1);
        IStreamWorkRecordSelection.Selection memory sb =
            selection.selectCurrent(1, subject, bh, ah, 1, _witness(bh, a));
        a.predecessor = bh;
        a.full.title = "C head after B selection";
        bytes32 ch = _curatorPublish(a);
        Graph memory c = _successor(b);
        _sameBinding(c);
        _currentTuple(address(selection), c);
        IStreamWorkRecordSelection.Selection memory sc =
            selection.selectCurrent(1, subject, ch, bh, 2, _witness(ch, a));
        require(selection.requireCurrent(1, subject, ch, 3).selectionHash == sc.selectionHash);
        require(
            keccak256(abi.encode(selection.workSelectionAt(1, subject, 1)))
                == keccak256(abi.encode(sa)),
            "A history unchanged"
        );
        require(
            keccak256(abi.encode(selection.workSelectionAt(1, subject, 2)))
                == keccak256(abi.encode(sb)),
            "B history unchanged"
        );
        bytes32 commitment = sc.selectionHash;
        sc.selectionHash = 0;
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_WORK_SELECTION_V1"),
                        block.chainid,
                        address(selection),
                        address(core),
                        address(metadata),
                        address(schemas),
                        address(store),
                        uint256(1),
                        subject,
                        sc
                    )
                ),
            "same original selector domain"
        );
    }

    function testWorkOriginalLockSurvivesBAndCAndStillBlocksBothWriters() public ready {
        _bound(1, BINDING, 2);
        _newProfile();
        StreamWorkRecordTypes.Description memory a = _artistDescription();
        bytes32 ah = _curatorPublish(a);
        IStreamWorkRecordSelection.Selection memory saved =
            selection.selectCurrent(1, subject, ah, 0, 0, _witness(ah, a));
        _sealGraph(address(core), address(executor));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, ah, 1);
        _sealWitness(address(executor), 2, 2, scope, oldHash, newHash);
        executor.execute(
            address(selection),
            abi.encodeCall(selection.lockSelection, (1, subject, ah, 1)),
            scope,
            oldHash,
            newHash
        );
        bytes32 locked = keccak256(abi.encode(selection.selectionLock(1, subject)));
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        Graph memory c = _successor(b);
        _sameBinding(c);
        require(selection.requireCurrent(1, subject, ah, 1).selectionHash == saved.selectionHash);
        require(
            keccak256(abi.encode(selection.selectionLock(1, subject))) == locked,
            "original lock unchanged"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.selectCurrent(1, subject, ah, ah, 1, _witness(ah, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.adoptArtistRecord(1, subject, ah, ah, 1, _witness(ah, a));
    }

    function testWorkRejectsPartialCompletionWrongAncestorAndChangedAssociationWithoutErasingHead()
        public
        ready
    {
        _bound(1, BINDING, 2);
        _newProfile();
        StreamWorkRecordTypes.Description memory a = _artistDescription();
        bytes32 ah = _curatorPublish(a);
        IStreamWorkRecordSelection.Selection memory saved =
            selection.selectCurrent(1, subject, ah, 0, 0, _witness(ah, a));
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        _completion(b, 5, 0);
        vm.expectRevert();
        selection.requireCurrent(1, subject, ah, 1);
        _completion(b, 5, COMPLETION);
        Graph memory c = _successor(b);
        _sameBinding(c);
        _certificate(c, keccak256("unrelated ancestor"), COMPLETION);
        vm.expectRevert();
        selection.requireCurrent(1, subject, ah, 1);
        _certificate(c, _anchorOriginHash(), COMPLETION);
        _binding(
            c,
            T.Binding(
                ARTIST_ID,
                ORIGINAL,
                IDENTITY,
                keccak256("wrong binding"),
                1,
                0,
                0,
                0,
                address(this),
                true
            ),
            2
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkAssociationChanged.selector)
        );
        selection.requireCurrent(1, subject, ah, 1);
        _sameBinding(c);
        require(
            keccak256(abi.encode(selection.requireCurrent(1, subject, ah, 1)))
                == keccak256(abi.encode(saved)),
            "identical retained head after repair"
        );
    }
}

contract StreamCurrentAuthorityConservationSelectionTest is
    ConservationSelectionFixture,
    CurrentAuthoritySelectionBoundary
{
    function _newProfile() private returns (StreamConservationRecordSelection legacy) {
        legacy = selection;
        _startGraph(
            address(core),
            address(metadata),
            address(facade),
            address(coordinator),
            address(identityOwner),
            address(bindingOwner),
            address(attributionOwner)
        );
        selection = StreamConservationRecordSelection(
            address(
                new StreamCurrentAuthorityConservationRecordSelection(
                    address(core), address(metadata), address(schemas)
                )
            )
        );
        require(
            IStreamRecordCurrentAuthority(address(selection)).currentAuthorityProfile()
                == keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1")
        );
        require(selection.supportsInterface(type(IStreamRecordCurrentAuthority).interfaceId));
    }

    function _sameBinding(Graph memory g) private {
        _binding(
            g, T.Binding(ARTIST_ID, ORIGINAL, IDENTITY, BINDING, 1, 1, 0, 0, address(this), true), 2
        );
    }

    function testConservationSameSelectorKeepsOriginalHistoryWhileAppendingUnderBAndC()
        public
        ready
    {
        StreamConservationRecordSelection legacy = _newProfile();
        StreamConservationRecordTypes.Intent memory a = _intent();
        (bytes32 ah,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        IStreamConservationRecordSelection.Selection memory sa =
            selection.adoptIntent(1, subject, ah, 0, 0, _intentWitness(ah, a));
        legacy.adoptIntent(1, subject, ah, 0, 0, _intentWitness(ah, a));
        StreamConservationRecordTypes.IntentWaiver memory waiver = _waiver();
        waiver.predecessor = ah;
        (bytes32 bh, bytes32 ba) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(waiver),
            1
        );
        a.predecessor = bh;
        (bytes32 ch, bytes32 ca) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        _copyPublication(b, address(attributionOwner), ba);
        require(
            selection.requireCurrent(1, subject, a.artist.origin, ah, 1).selectionHash
                == sa.selectionHash
        );
        vm.expectRevert();
        legacy.requireCurrent(1, subject, a.artist.origin, ah, 1);
        IStreamConservationRecordSelection.Selection memory sb =
            selection.adoptWaiver(1, subject, bh, ah, 1, _waiverWitness(bh, waiver));
        Graph memory c = _successor(b);
        _sameBinding(c);
        _copyPublication(c, address(attributionOwner), ca);
        _currentTuple(address(selection), c);
        IStreamConservationRecordSelection.Selection memory sc =
            selection.adoptIntent(1, subject, ch, bh, 2, _intentWitness(ch, a));
        require(
            selection.requireCurrent(1, subject, a.artist.origin, ch, 3).selectionHash
                == sc.selectionHash
        );
        require(
            keccak256(abi.encode(selection.conservationSelectionAt(1, subject, a.artist.origin, 1)))
                == keccak256(abi.encode(sa))
        );
        require(
            keccak256(abi.encode(selection.conservationSelectionAt(1, subject, a.artist.origin, 2)))
                == keccak256(abi.encode(sb))
        );
        bytes32 commitment = sc.selectionHash;
        sc.selectionHash = 0;
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                        block.chainid,
                        address(selection),
                        address(core),
                        address(metadata),
                        address(schemas),
                        address(store),
                        uint256(1),
                        subject,
                        sc
                    )
                ),
            "same original selector domain"
        );
    }

    function testConservationPreparedCatalogAndIntentLockSurviveThenRetirementStillRejects()
        public
        ready
    {
        _newProfile();
        StreamConservationRecordTypes.Interview memory interview = _interview();
        StreamConservationRecordTypes.Format memory format;
        format.kind = StreamConservationRecordTypes.FormatKind.CATALOG;
        format.formatId = bytes32(uint256(99));
        format.catalog.selectedEntryId = format.formatId;
        format.catalog.name = "CURRENT_AUTHORITY_RETAINED_CATALOG_V1";
        format.catalog.entries = new StreamConservationRecordTypes.CatalogEntry[](2);
        format.catalog.entries[0].entryId = bytes32(uint256(98));
        format.catalog.entries[0].puid = "fmt/199";
        format.catalog.entries[1].entryId = format.formatId;
        format.catalog.entries[1].puid = "fmt/111";
        interview.transcript.format = format;
        bytes memory catalog = StreamConservationFormatJson.catalogDocument(format.catalog);
        bytes32 id = _registerDocument(
            format.catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog,
            StreamWorkRecordDefinitions.CANON_ID
        );
        (
            StreamConservationRecordTypes.Intent memory a,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), interview, 1);
        IStreamConservationRecordSelection.PreparedInterview memory prepared =
            selection.prepareInterview(1, subject, a.interview.record.recordHash, iw);
        (bytes32 ah,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        IStreamConservationRecordSelection.Selection memory saved =
            selection.adoptIntentWithPreparedInterview(1, subject, ah, 0, 0, _intentWitness(ah, a));
        a.predecessor = ah;
        (bytes32 later, bytes32 laterAuthorization) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, ah, 1);
        bytes32 lockHash = keccak256(abi.encode(selection.intentLock(1, subject)));
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        Graph memory c = _successor(b);
        _sameBinding(c);
        _copyPublication(c, address(attributionOwner), laterAuthorization);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationHeadLocked.selector
            )
        );
        selection.adoptIntentWithPreparedInterview(
            1, subject, later, ah, 1, _intentWitness(later, a)
        );
        require(
            selection.requireCurrent(1, subject, a.artist.origin, ah, 1).selectionHash
                == saved.selectionHash
        );
        require(
            keccak256(abi.encode(selection.intentLock(1, subject))) == lockHash,
            "permanent original intent lock"
        );
        require(
            keccak256(abi.encode(selection.preparedInterview(a.interview.record.recordHash)))
                == keccak256(abi.encode(prepared)),
            "full prepared history unchanged"
        );
        IStreamConservationRecordSelection.CatalogPin memory pin =
            selection.selectionCatalogAt(1, subject, a.artist.origin, 1, 0);
        require(
            selection.selectionCatalogCount(1, subject, a.artist.origin, 1) == 1
                && pin.documentId == id && pin.contentHash == keccak256(catalog)
                && pin.totalBytes == catalog.length,
            "all catalog bytes retained"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            newHash
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationDefinitionUnavailable.selector, id
            )
        );
        selection.requireCurrent(1, subject, a.artist.origin, ah, 1);
        require(
            selection.selectionCatalogAt(1, subject, a.artist.origin, 1, 0).contentHash
                    == pin.contentHash
                && keccak256(abi.encode(selection.intentLock(1, subject))) == lockHash,
            "retirement changes eligibility only"
        );
    }

    function testConservationRefusesIncompleteAndWrongLineageWithoutChangingSavedSelection()
        public
        ready
    {
        _newProfile();
        StreamConservationRecordTypes.Intent memory a = _intent();
        (bytes32 ah,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        IStreamConservationRecordSelection.Selection memory saved =
            selection.adoptIntent(1, subject, ah, 0, 0, _intentWitness(ah, a));
        Graph memory b = _successor(anchor);
        _sameBinding(b);
        _completion(b, 6, keccak256("different owner commitment"));
        vm.expectRevert();
        selection.requireCurrent(1, subject, a.artist.origin, ah, 1);
        _completion(b, 6, COMPLETION);
        Graph memory c = _successor(b);
        _sameBinding(c);
        _certificate(c, _anchorOriginHash(), keccak256("unrelated import"));
        vm.expectRevert();
        selection.requireCurrent(1, subject, a.artist.origin, ah, 1);
        _certificate(c, _anchorOriginHash(), COMPLETION);
        _binding(
            c, T.Binding(ARTIST_ID, ORIGINAL, IDENTITY, BINDING, 2, 1, 0, 0, address(this), true), 2
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationAssociationChanged.selector
            )
        );
        selection.requireCurrent(1, subject, a.artist.origin, ah, 1);
        _sameBinding(c);
        require(
            keccak256(abi.encode(selection.requireCurrent(1, subject, a.artist.origin, ah, 1)))
                == keccak256(abi.encode(saved)),
            "original exact tuple restored"
        );
    }
}
