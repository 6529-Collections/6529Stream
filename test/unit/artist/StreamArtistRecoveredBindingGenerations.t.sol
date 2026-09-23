// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RecoveredSimpleCoordinatorFixture } from "./StreamArtistRecoveredSimpleHydration.t.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredSimpleHydration as Simple
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSimpleHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @dev Calls the actual fixed Binding and Acceptance owner writers. Identity signatures and
/// the seven-owner operation60 authority boundary are supplied by this typed component fixture.
contract RecoveredGenerationCoordinatorFixture is RecoveredSimpleCoordinatorFixture {
    constructor(address registry) RecoveredSimpleCoordinatorFixture(registry) { }

    function refuse(uint256 collection) external returns (bytes32) {
        T.Binding memory b = bindingOwner().binding(collection);
        return bindingOwner()
            .refuse(
                T.ActionContext(3, address(this), bindingOwner().ownerStateSnapshotV2()),
                L.Termination(
                    collection,
                    b.generation,
                    b.bindingHash,
                    keccak256("original refusal"),
                    "urn:refusal"
                ),
                b.artistAddress,
                uint256(b.generation)
            );
    }
}

/// @dev Isolated destination map adapter; no mock of original source records. This boundary
/// tests canonical decoding, emptiness and atomic map writes, not governed op55/56/57/60 admission.
contract RecoveredGenerationMapFixture {
    mapping(uint256 => T.Binding) private _bindings;
    mapping(uint256 => mapping(uint64 => T.Binding)) private _history;
    mapping(uint256 => mapping(uint64 => C.BindingTerms)) private _terms;
    mapping(uint256 => mapping(uint64 => L.Terminal)) private _terminals;
    error LateFailure();

    function hydrate(AH.Query memory q, bytes memory outer, bool fail) external {
        G.importState(_bindings, _history, _terms, _terminals, q, outer);
        if (fail) revert LateFailure();
    }

    function binding(uint256 collection) external view returns (T.Binding memory) {
        return _bindings[collection];
    }

    function row(uint256 collection, uint64 generation) external view returns (G.Row memory) {
        return G.Row(
            _history[collection][generation],
            _terms[collection][generation],
            _terminals[collection][generation]
        );
    }

    function occupy(uint256 collection, uint64 generation, uint8 kind) external {
        if (kind == 0) _bindings[collection].proposer = address(99);
        else if (kind == 1) _history[collection][generation].proposer = address(99);
        else if (kind == 2) _terms[collection][generation].threshold = 1;
        else _terminals[collection][generation].reasonHash = bytes32(uint256(99));
    }
}

contract StreamArtistRecoveredBindingGenerationsTest {
    struct Fixture {
        RecoveredGenerationCoordinatorFixture source;
        AH.Query query;
        RH.OwnerProvenance provenance;
        G.Bundle bundle;
    }

    function testBindingGenerationsActualMixedHistoryAndAllFourMaps() external {
        Fixture memory f = _fixture(3, 0);
        assert(f.provenance.eras[0].checkpoint.ownerState.revision == 6);
        assert(f.provenance.journal.length == 4 && f.provenance.aliases.length == 5);
        assert(f.bundle.rows[0].terminal.kind == 1 && f.bundle.rows[1].terminal.kind == 2);
        assert(f.source.acceptanceOwner().artistNativeReceiptCount() == 1);
        assert(f.source.acceptanceOwner().artistNativeReceiptAt(0).operation == 2);
        bytes32 sourceBefore = _source(f);
        RecoveredGenerationMapFixture target = new RecoveredGenerationMapFixture();
        bytes memory outer =
            _outer(f, G.encode(f.bundle, f.query, f.provenance), RH.BINDING_GENERATIONS);
        assert(G.selected(outer));
        target.hydrate(f.query, outer, false);
        _same(target, f);
        assert(_source(f) == sourceBefore);
    }

    function testBindingGenerationsAllRefusalsHaveExactNativeAndReplayClocks() external {
        Fixture memory f = _fixture(4, 1);
        assert(f.provenance.journal.length == 7 && f.provenance.aliases.length == 7);
        for (uint256 i; i < 3; ++i) {
            assert(f.provenance.journal[2 * i].receipt.operation == 1);
            assert(f.provenance.journal[2 * i + 1].receipt.operation == 3);
            assert(f.provenance.journal[2 * i + 1].position.point.ownerRevision == 2 * i + 2);
        }
        G.validate(f.bundle, f.query, f.provenance);
    }

    function testBindingGenerationsWithdrawalsDoNotInventNativeRecords() external {
        Fixture memory f = _fixture(4, 2);
        assert(f.provenance.journal.length == 4 && f.provenance.aliases.length == 7);
        for (uint256 i; i < 4; ++i) {
            assert(f.provenance.journal[i].receipt.operation == 1);
            assert(f.provenance.journal[i].position.point.ownerRevision == 2 * i + 1);
            if (i != 3) assert(f.bundle.rows[i].terminal.recordHash == 0);
        }
        RecoveredGenerationMapFixture target = new RecoveredGenerationMapFixture();
        target.hydrate(
            f.query,
            _outer(f, G.encode(f.bundle, f.query, f.provenance), RH.BINDING_GENERATIONS),
            false
        );
        _same(target, f);
    }

    function testBindingGenerationsRejectOmissionReorderingAndCurrentHeadMismatch() external {
        Fixture memory f = _fixture(3, 0);
        G.Row[] memory rows = f.bundle.rows;
        f.bundle.rows = new G.Row[](2);
        f.bundle.rows[0] = rows[0];
        f.bundle.rows[1] = rows[2];
        _invalid(f);
        f.bundle.rows = rows;
        (f.bundle.rows[0], f.bundle.rows[1]) = (f.bundle.rows[1], f.bundle.rows[0]);
        _invalid(f);
        (f.bundle.rows[0], f.bundle.rows[1]) = (f.bundle.rows[1], f.bundle.rows[0]);
        f.bundle.current.proposer = address(98);
        _invalid(f);
    }

    function testBindingGenerationsRejectWrongArtistGenerationAndProposalDomain() external {
        Fixture memory f = _fixture(3, 0);
        bytes32 artist = f.bundle.rows[0].item.artistId;
        f.bundle.rows[0].item.artistId = bytes32(uint256(99));
        _invalid(f);
        f.bundle.rows[0].item.artistId = artist;
        f.bundle.rows[0].item.generation = 2;
        _invalid(f);
        f.bundle.rows[0].item.generation = 1;
        f.provenance.origins[0].registry = address(9999);
        _rehash(f.provenance);
        _bind(f);
        _invalid(f); // otherwise well-formed era and replay keys, original proposal hash unchanged
    }

    function testBindingGenerationsRequireExactPendingTerminalAndFinalEmptyTuple() external {
        Fixture memory f = _fixture(3, 0);
        f.bundle.rows[0].terminal.reasonHash = 0;
        _invalid(f);
        f.bundle.rows[0].terminal.reasonHash = keccak256("original refusal");
        f.bundle.rows[1].terminal.recordHash = bytes32(uint256(99));
        _invalid(f);
        f.bundle.rows[1].terminal.recordHash = 0;
        f.bundle.rows[0].item.accepted = true;
        _invalid(f);
        f.bundle.rows[0].item.accepted = false;
        f.bundle.rows[2].terminal.reasonHash = bytes32(uint256(99));
        _invalid(f);
    }

    function testBindingGenerationsModeTwoAndCollaboratorTermsStayOutsideProfile() external {
        Fixture memory f = _fixture(3, 0);
        f.bundle.rows[0].item.consentMode = 2;
        _invalid(f);
        f.bundle.rows[0].item.consentMode = 1;
        f.bundle.rows[0].terms.count = 1;
        _invalid(f);
        f.bundle.rows[0].terms.count = 0;
        f.bundle.rows[1].terms.capabilityPolicySetHash = bytes32(uint256(99));
        _invalid(f);
    }

    function testBindingGenerationsNoHiddenOwnerMutationNonceOrNativeFamily() external {
        Fixture memory f = _fixture(3, 0);
        ++f.provenance.eras[0].checkpoint.ownerState.revision;
        _bind(f);
        _invalid(f);
        --f.provenance.eras[0].checkpoint.ownerState.revision;
        f.provenance.eras[0].checkpoint.nonceRoot = bytes32(uint256(99));
        _bind(f);
        _invalid(f);
        f.provenance.eras[0].checkpoint.nonceRoot = 0;
        f.provenance.journal[1].receipt.operation = 4;
        _bind(f);
        _invalid(f);
    }

    function testBindingGenerationsRejectWrongReplayCommitmentSurfaceAndOriginalPoint() external {
        Fixture memory f = _fixture(3, 0);
        uint256 at =
            _aliasAt(f.provenance, keccak256("binding_lifecycle.replay.refusal_uniqueness"), 1);
        bytes32 old = f.provenance.aliases[at].cell.commitment;
        f.provenance.aliases[at].cell.commitment = bytes32(uint256(99));
        _bind(f);
        _invalid(f);
        f.provenance.aliases[at].cell.commitment = old;
        f.provenance.aliases[at].admittedAt.ownerRevision = 1;
        f.provenance.aliases[at].cell.touchedRevision = 1;
        _bind(f);
        _invalid(f);
        f.provenance.aliases[at].admittedAt.ownerRevision = 2;
        f.provenance.aliases[at].cell.touchedRevision = 2;
        f.provenance.aliases[at].surface = keccak256("unknown original guard");
        f.provenance.aliases[at].originalKey =
            _key(f.provenance.origins[0], f.provenance.aliases[at]);
        _sort(f.provenance.aliases);
        _bind(f);
        _invalid(f);
    }

    function testBindingGenerationsCompleteAliasSetAndNativeOrderCannotBeProjected() external {
        Fixture memory f = _fixture(3, 0);
        RH.ReplayAlias[] memory aliases = f.provenance.aliases;
        f.provenance.aliases = new RH.ReplayAlias[](aliases.length - 1);
        for (uint256 i; i < f.provenance.aliases.length; ++i) {
            f.provenance.aliases[i] = aliases[i];
        }
        --f.provenance.eras[0].checkpoint.replayCount;
        _bind(f);
        _invalid(f);
        f.provenance.aliases = aliases;
        ++f.provenance.eras[0].checkpoint.replayCount;
        f.provenance.journal[1].position.point.ownerRevision = 1;
        _bind(f);
        _invalid(f);
    }

    function testBindingGenerationsFixedSourceMustMatchActualCheckpointAndCurrentRows() external {
        Fixture memory f = _fixture(3, 0);
        ++f.provenance.eras[0].checkpoint.ownerState.revision;
        _revert(
            address(this),
            abi.encodeCall(this.collect, (address(f.source.bindingOwner()), f.query, f.provenance)),
            RH.InvalidRecoveredHydrationProvenance.selector
        );
    }

    function testBindingGenerationsLateFailureAndOccupiedHistoricalCellsRestoreEverything()
        external
    {
        Fixture memory f = _fixture(3, 0);
        bytes memory outer =
            _outer(f, G.encode(f.bundle, f.query, f.provenance), RH.BINDING_GENERATIONS);
        RecoveredGenerationMapFixture target = new RecoveredGenerationMapFixture();
        bytes32 empty = _maps(target, f);
        _revert(
            address(target),
            abi.encodeCall(target.hydrate, (f.query, outer, true)),
            RecoveredGenerationMapFixture.LateFailure.selector
        );
        assert(_maps(target, f) == empty);
        target.hydrate(f.query, outer, false);
        _same(target, f);
        _revert(
            address(target),
            abi.encodeCall(target.hydrate, (f.query, outer, false)),
            T.InvalidRecord.selector
        );
        for (uint8 kind; kind < 4; ++kind) {
            RecoveredGenerationMapFixture occupied = new RecoveredGenerationMapFixture();
            occupied.occupy(7, 2, kind);
            bytes32 before_ = _maps(occupied, f);
            _revert(
                address(occupied),
                abi.encodeCall(occupied.hydrate, (f.query, outer, false)),
                T.InvalidRecord.selector
            );
            assert(_maps(occupied, f) == before_);
        }
    }

    function testBindingGenerationsCanonicalCodecAndExplicitFeatureAreRequired() external {
        Fixture memory f = _fixture(3, 0);
        bytes memory raw = G.encode(f.bundle, f.query, f.provenance);
        _revert(
            address(this),
            abi.encodeCall(this.decode, (f.query, f.provenance, bytes.concat(raw, hex"00"))),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        RecoveredGenerationMapFixture target = new RecoveredGenerationMapFixture();
        bytes memory outer = _outer(f, raw, 0);
        assert(!G.selected(outer));
        _revert(
            address(target),
            abi.encodeCall(target.hydrate, (f.query, outer, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        target.hydrate(f.query, _outer(f, raw, RH.BINDING_GENERATIONS), false);
        _same(target, f);
    }

    function testBindingGenerationsOriginalGenerationOneUsesUnchangedCodec() external {
        RecoveredGenerationCoordinatorFixture source = _sourceFixture(1, 0);
        AH.Query memory q = _query(source);
        RH.OwnerProvenance memory p = _local(source, q);
        bytes memory old = source.bindingOwner().recoveredAuthorityHydrationState(q, p);
        Simple.decodeBinding(q, p, old);
        _revert(
            address(this),
            abi.encodeCall(this.collect, (address(source.bindingOwner()), q, p)),
            T.UnsupportedProfile.selector
        );
    }

    function testBindingGenerationsBound128DoesNotChangeOriginalWriters() external {
        Fixture memory f = _fixture(128, 2);
        assert(
            f.bundle.rows.length == 128
                && f.provenance.eras[0].checkpoint.ownerState.revision == 256
        );
        RecoveredGenerationCoordinatorFixture beyond = _sourceFixture(129, 2);
        AH.Query memory q = _query(beyond);
        RH.OwnerProvenance memory p = _local(beyond, q);
        assert(beyond.bindingOwner().binding(7).generation == 129);
        _revert(
            address(this),
            abi.encodeCall(this.collect, (address(beyond.bindingOwner()), q, p)),
            T.UnsupportedProfile.selector
        );
    }

    function testBindingGenerationsSyntheticRepeatedEraRetainsUltimateOriginalClocks() external {
        Fixture memory f = _fixture(3, 0);
        f.provenance = _secondEra(f.provenance);
        _bind(f);
        G.validate(f.bundle, f.query, f.provenance);
        assert(
            f.provenance.eras[0].checkpoint.ownerState.revision == 6
                && f.provenance.eras[1].checkpoint.ownerState.revision == 1
        );
        RecoveredGenerationMapFixture target = new RecoveredGenerationMapFixture();
        target.hydrate(
            f.query,
            _outer(
                f,
                G.encode(f.bundle, f.query, f.provenance),
                RH.BINDING_GENERATIONS | RH.REPEATED_IMPORT
            ),
            false
        );
        _same(target, f);
        ++f.provenance.eras[1].checkpoint.ownerState.revision;
        _bind(f);
        _invalid(f);
    }

    function check(G.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        external
        pure
    {
        G.validate(b, q, p);
    }

    function collect(address source, AH.Query memory q, RH.OwnerProvenance memory p) external view {
        G.collect(source, q, p);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        G.decode(q, p, raw);
    }

    function _fixture(uint256 generations, uint8 pattern) private returns (Fixture memory f) {
        f.source = _sourceFixture(generations, pattern);
        f.query = _query(f.source);
        f.provenance = _local(f.source, f.query);
        f.bundle = G.collect(address(f.source.bindingOwner()), f.query, f.provenance);
    }

    function _sourceFixture(uint256 generations, uint8 pattern)
        private
        returns (RecoveredGenerationCoordinatorFixture source)
    {
        source = new RecoveredGenerationCoordinatorFixture(address(501));
        for (uint256 i; i < generations; ++i) {
            source.propose(7);
            if (i + 1 == generations) source.accept(7);
            else if (pattern == 1 || (pattern == 0 && i % 2 == 0)) source.refuse(7);
            else source.withdraw(7);
        }
    }

    function _query(RecoveredGenerationCoordinatorFixture source)
        private
        view
        returns (AH.Query memory q)
    {
        T.Binding memory b = source.bindingOwner().binding(7);
        q.artistId = b.artistId;
        q.collectionId = 7;
        q.bindingHash = b.bindingHash;
    }

    function _local(RecoveredGenerationCoordinatorFixture source, AH.Query memory q)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        T.SuiteConfiguration memory suite = source.authorityHydrationSuite();
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = suite.registry;
        o.coordinator = address(source);
        o.archive = suite.archive;
        o.core = suite.core;
        o.manager = suite.mintManager;
        o.owners = suite.owners;
        o.suiteConfigurationHash = keccak256(abi.encode(suite));
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = o;
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint = source.bindingOwner().authorityCheckpoint();
        p.eras[0].nativeCount = source.bindingOwner().artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].receipt = source.bindingOwner().artistNativeReceiptAt(i);
            p.journal[i].position = RH.Position(
                RH.Point(
                    RH.originHash(o), 0, source.bindingOwner().artistNativeReceiptRevisionAt(i)
                ),
                i
            );
        }
        p.aliases = new RH.ReplayAlias[](p.eras[0].checkpoint.replayCount);
        uint256 generations = source.bindingOwner().binding(q.collectionId).generation;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a;
            a.originHash = RH.originHash(o);
            (a.originalKey, a.cell) = source.bindingOwner().authorityReplayAt(i);
            a.admittedAt = RH.Point(a.originHash, 0, a.cell.touchedRevision);
            bool found;
            for (uint64 g = 1; g <= generations; ++g) {
                a.scope = keccak256(abi.encode(q.collectionId, g));
                a.surface = keccak256("binding_lifecycle.replay.proposal_key");
                if (_key(o, a) == a.originalKey) {
                    found = true;
                    break;
                }
                L.Terminal memory terminal =
                    source.bindingOwner().bindingTermination(q.collectionId, g);
                a.surface = terminal.kind == 1
                    ? keccak256("binding_lifecycle.replay.refusal_uniqueness")
                    : keccak256("binding_lifecycle.replay.proposal_terminal_transition_key");
                if (_key(o, a) == a.originalKey) {
                    found = true;
                    break;
                }
            }
            require(found, "every actual original replay preimage found");
            p.aliases[i] = a;
        }
        _sort(p.aliases);
    }

    function _outer(Fixture memory f, bytes memory semantic, uint256 features)
        private
        pure
        returns (bytes memory)
    {
        RH.OwnerProvenance memory p = f.provenance;
        uint256 last = p.eras.length - 1;
        RH.ExportHeader memory h;
        h.profile = RH.PROFILE;
        h.version = RH.VERSION;
        h.ownerIndex = 0;
        h.sourceOrigin = p.eras[last].originHash;
        h.priorImportCommitment = p.eras[last].priorImportCommitment;
        h.semanticInventory = keccak256(semantic);
        h.provenanceCommitment = RH.ownerProvenanceHash(p, 0);
        h.replayAliasesCommitment = RH.aliasesHash(0, p.aliases);
        h.requiredFeatures = features;
        h.semanticRecordCount = p.journal.length;
        h.replayAliasCount = p.aliases.length;
        h.eraCount = p.eras.length;
        Payload.Payload memory data;
        data.provenance = p;
        data.semanticState = semantic;
        data.nonces = new RH.NonceInventory[](0);
        return Payload.encode(0, h, data);
    }

    /// @dev Structural second-era control only. No claim that a real seven-owner import occurred.
    function _secondEra(RH.OwnerProvenance memory p)
        private
        pure
        returns (RH.OwnerProvenance memory n)
    {
        n.origins = new RH.OriginEnvironment[](2);
        n.origins[0] = p.origins[0];
        n.origins[1] = abi.decode(abi.encode(p.origins[0]), (RH.OriginEnvironment));
        n.origins[1].registry = address(801);
        n.origins[1].coordinator = address(802);
        n.origins[1].owners[0] = address(803);
        n.origins[1].suiteConfigurationHash = keccak256("synthetic later suite");
        n.eras = new RH.OwnerEra[](2);
        n.eras[0] = p.eras[0];
        CP.Checkpoint memory checkpoint =
            abi.decode(abi.encode(p.eras[0].checkpoint), (CP.Checkpoint));
        checkpoint.ownerState.revision = 1;
        n.eras[1] = RH.OwnerEra(
            RH.originHash(n.origins[1]), checkpoint, 0, 1, keccak256("synthetic completed import")
        );
        n.journal = p.journal;
        n.aliases = new RH.ReplayAlias[](p.aliases.length * 2);
        for (uint256 i; i < p.aliases.length; ++i) {
            n.aliases[i] = p.aliases[i];
            RH.ReplayAlias memory a = abi.decode(abi.encode(p.aliases[i]), (RH.ReplayAlias));
            a.originHash = n.eras[1].originHash;
            a.originalKey = _key(n.origins[1], a);
            n.aliases[p.aliases.length + i] = a;
        }
        _sort(n.aliases);
    }

    function _rehash(RH.OwnerProvenance memory p) private pure {
        bytes32 hash = RH.originHash(p.origins[0]);
        p.eras[0].originHash = hash;
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].position.point.environmentHash = hash;
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            p.aliases[i].originHash = hash;
            p.aliases[i].admittedAt.environmentHash = hash;
            p.aliases[i].originalKey = _key(p.origins[0], p.aliases[i]);
        }
        _sort(p.aliases);
    }

    function _bind(Fixture memory f) private pure {
        f.bundle.provenanceCommitment = RH.ownerProvenanceHash(f.provenance, 0);
    }

    function _invalid(Fixture memory f) private {
        _revert(
            address(this),
            abi.encodeCall(this.check, (f.bundle, f.query, f.provenance)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
    }

    function _revert(address target, bytes memory data, bytes4 selector) private {
        (bool ok, bytes memory result) = target.call(data);
        assert(!ok && keccak256(result) == keccak256(abi.encodeWithSelector(selector)));
    }

    function _aliasAt(RH.OwnerProvenance memory p, bytes32 surface, uint64 generation)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < p.aliases.length; ++i) {
            if (
                p.aliases[i].surface == surface
                    && p.aliases[i].scope == keccak256(abi.encode(uint256(7), generation))
            ) return i;
        }
        revert("fixture missing original alias");
    }

    function _key(RH.OriginEnvironment memory o, RH.ReplayAlias memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[0],
                RH.ownerDomain(0),
                a.surface,
                a.scope
            )
        );
    }

    function _sort(RH.ReplayAlias[] memory a) private pure {
        for (uint256 i = 1; i < a.length; ++i) {
            RH.ReplayAlias memory item = a[i];
            uint256 j = i;
            while (j != 0 && a[j - 1].originalKey > item.originalKey) {
                a[j] = a[j - 1];
                --j;
            }
            a[j] = item;
        }
    }

    function _same(RecoveredGenerationMapFixture target, Fixture memory f) private view {
        assert(keccak256(abi.encode(target.binding(7))) == keccak256(abi.encode(f.bundle.current)));
        for (uint256 i; i < f.bundle.rows.length; ++i) {
            assert(
                keccak256(abi.encode(target.row(7, uint64(i + 1))))
                    == keccak256(abi.encode(f.bundle.rows[i]))
            );
        }
    }

    function _maps(RecoveredGenerationMapFixture target, Fixture memory f)
        private
        view
        returns (bytes32 hash)
    {
        hash = keccak256(abi.encode(target.binding(7)));
        for (uint256 i; i < f.bundle.rows.length; ++i) {
            hash = keccak256(abi.encode(hash, target.row(7, uint64(i + 1))));
        }
    }

    function _source(Fixture memory f) private view returns (bytes32 hash) {
        hash = keccak256(
            abi.encode(
                f.source.bindingOwner().authorityCheckpoint(),
                f.source.acceptanceOwner().authorityCheckpoint(),
                G.collect(address(f.source.bindingOwner()), f.query, f.provenance)
            )
        );
    }
}
