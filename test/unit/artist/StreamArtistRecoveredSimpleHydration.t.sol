// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistBindingLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import {
    StreamArtistCollaboratorLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import {
    StreamArtistAcceptanceLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import {
    StreamArtistRecoveredSimpleHydration as Adapter
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSimpleHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
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

contract RecoveredSimplePeerOwner is StreamArtistOwner {
    constructor(address registry, uint8 index)
        StreamArtistOwner(
            registry, msg.sender, address(403), RH.ownerDomain(index), address(401), address(402)
        )
    { }
}

/// @dev Actual concrete owners and their original writers; the fixture supplies the fixed
/// Coordinator's admission boundary. This is not a signature, lane55/56 or full operation60 test.
contract RecoveredSimpleCoordinatorFixture {
    T.SuiteConfiguration private _suite;
    bool public lateFailure;
    error SimpleLateFailure();

    constructor(address registry) {
        _suite.registry = registry;
        _suite.archive = address(403);
        _suite.core = address(401);
        _suite.mintManager = address(402);
        _suite.owners[0] = address(
            new StreamArtistBindingLifecycle(
                registry, address(this), address(403), address(401), address(402)
            )
        );
        _suite.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                registry, address(this), address(403), address(401), address(402)
            )
        );
        _suite.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                registry, address(this), address(403), address(401), address(402)
            )
        );
        for (uint8 i; i < 7; ++i) {
            if (i != 0 && i != 1 && i != 3) {
                _suite.owners[i] = address(new RecoveredSimplePeerOwner(registry, i));
            }
        }
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function owner(uint8 index) external view returns (StreamArtistOwner) {
        return StreamArtistOwner(_suite.owners[index]);
    }

    function bindingOwner() public view returns (StreamArtistBindingLifecycle) {
        return StreamArtistBindingLifecycle(_suite.owners[0]);
    }

    function collaboratorOwner() public view returns (StreamArtistCollaboratorLifecycle) {
        return StreamArtistCollaboratorLifecycle(_suite.owners[1]);
    }

    function acceptanceOwner() public view returns (StreamArtistAcceptanceLifecycle) {
        return StreamArtistAcceptanceLifecycle(_suite.owners[3]);
    }

    function propose(uint256 collection) public returns (T.Binding memory b) {
        T.BindingProposal memory p;
        p.artistAddress = address(1001);
        p.identityRecordHash = keccak256("original identity genesis document");
        p.consentMode = 1;
        p.reasonHash = keccak256("proposal reason");
        return bindingOwner().propose(_context(0, 1), collection, bytes32(uint256(1002)), p);
    }

    function accept(uint256 collection) public returns (bytes32 record) {
        T.Binding memory b = bindingOwner().binding(collection);
        record =
            acceptanceOwner().recordAcceptance(_context(3, 2), collection, b, b.artistAddress, 0);
        bindingOwner().accept(_context(0, 2), collection, b.bindingHash, record);
    }

    function create(uint256 collection) external {
        propose(collection);
        accept(collection);
    }

    function withdraw(uint256 collection) external {
        T.Binding memory b = bindingOwner().binding(collection);
        L.Termination memory p;
        p.collectionId = collection;
        p.generation = b.generation;
        p.bindingHash = b.bindingHash;
        p.reasonHash = keccak256("withdraw original pending binding");
        bindingOwner().withdraw(_context(0, 4), p);
    }

    function proposeCollaborator(bool complete) external {
        C.IdentityProposal memory p;
        p.account = address(1003);
        p.identityRecordHash = keccak256("collaborator document");
        p.reasonHash = keccak256("collaborator reason");
        collaboratorOwner().proposeIdentity(_context(1, 5), p);
        if (complete) {
            collaboratorOwner()
                .completeIdentity(
                    _context(1, 6), p.account, p.identityRecordHash, bytes32(uint256(1004))
                );
        }
    }

    function acceptCollaboratorRow(bytes32 bindingHash) external {
        C.BindingAcceptance memory p;
        p.collectionId = 7;
        p.generation = 1;
        p.bindingHash = bindingHash;
        p.account = address(1003);
        collaboratorOwner()
            .recordRowAcceptance(
                _context(1, 7), p, bytes32(uint256(1004)), keccak256("admitted collaborator row")
            );
    }

    function setLateFailure(bool fail) external {
        lateFailure = fail;
    }

    function importThree(AH.Query calldata q, AH.OwnerData[3] calldata data, bytes32 commitment)
        external
    {
        uint8[3] memory indices = [uint8(0), uint8(1), uint8(3)];
        for (uint256 i; i < 3; ++i) {
            StreamArtistOwner(_suite.owners[indices[i]])
                .applyArtistAuthorityHydration(_context(indices[i], 60), q, data[i], commitment);
        }
        if (lateFailure) revert SimpleLateFailure();
    }

    function _context(uint8 index, uint16 operation) private view returns (T.ActionContext memory) {
        return T.ActionContext(
            operation, address(this), StreamArtistOwner(_suite.owners[index]).ownerStateSnapshotV2()
        );
    }
}

/// @dev Pure decoder exposure is only for malformed-certificate controls; real-source tests use
/// the original owners above. Synthetic repeated-era controls do not claim accepted repeated60.
contract RecoveredSimpleDecodeBoundary {
    function binding(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Adapter.decodeBinding(q, p, raw);
    }

    function acceptance(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Adapter.decodeAcceptance(q, p, raw);
    }

    function collaborator(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Adapter.decodeCollaborator(q, p, raw);
    }
}

contract StreamArtistRecoveredSimpleHydrationTest {
    function testSimpleExportsExactOriginalBindingAcceptanceAndNonemptyEmptyCertificate() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        RH.OwnerProvenance memory b = _local(source, 0, q);
        bytes memory binding = source.bindingOwner().recoveredAuthorityHydrationState(q, b);
        S.Binding memory value = Adapter.decodeBinding(q, b, binding);
        assert(
            keccak256(abi.encode(value.item))
                == keccak256(abi.encode(source.bindingOwner().binding(7)))
        );
        assert(
            keccak256(abi.encode(value.history))
                == keccak256(abi.encode(source.bindingOwner().bindingAt(7, 1)))
        );
        assert(value.item.identityRecordHash == keccak256("original identity genesis document"));
        assert(
            keccak256(source.bindingOwner().authorityHydrationState(q))
                == keccak256(abi.encode(AH.Binding(value.item, value.terms)))
        );
        RH.OwnerProvenance memory a = _local(source, 3, q);
        S.Acceptance memory accepted = Adapter.decodeAcceptance(
            q, a, source.acceptanceOwner().recoveredAuthorityHydrationState(q, a)
        );
        assert(accepted.record == source.acceptanceOwner().acceptanceRecord(q.bindingHash));
        assert(accepted.acceptedAt == source.acceptanceOwner().acceptedAt(q.bindingHash));
        assert(
            keccak256(source.acceptanceOwner().authorityHydrationState(q))
                == keccak256(abi.encode(AH.Acceptance(accepted.record, accepted.acceptedAt)))
        );
        RH.OwnerProvenance memory c = _local(source, 1, q);
        bytes memory empty = source.collaboratorOwner().recoveredAuthorityHydrationState(q, c);
        assert(empty.length != 0);
        Adapter.decodeCollaborator(q, c, empty);
        assert(source.collaboratorOwner().authorityHydrationState(q).length == 0);
        assert(
            source.bindingOwner().recoveredAuthorityHydrationCapability().supportedFeatures == 31
        );
        assert(
            source.collaboratorOwner().recoveredAuthorityHydrationCapability().supportedFeatures
                == 31
        );
        assert(
            source.acceptanceOwner().recoveredAuthorityHydrationCapability().supportedFeatures == 31
        );
        // These are actual post-commit native writers, not a synthetic _native ordering.
        assert(source.bindingOwner().artistNativeReceiptRevisionAt(0) == 1);
        assert(source.bindingOwner().ownerStateSnapshotV2().revision == 2);
        assert(source.acceptanceOwner().artistNativeReceiptRevisionAt(0) == 1);
        assert(source.acceptanceOwner().ownerStateSnapshotV2().revision == 1);
    }

    function testSimpleImportsThroughActualOwnerGuardsAndRetainsOriginalRecordsWithoutNativeRows()
        external
    {
        RecoveredSimpleCoordinatorFixture source = _source();
        RecoveredSimpleCoordinatorFixture target =
            new RecoveredSimpleCoordinatorFixture(address(502));
        AH.Query memory q = _query(source);
        AH.OwnerData[3] memory data = _data(source, q);
        target.importThree(q, data, keccak256("joined source admission fixture"));
        _retained(source, target, q);
        uint8[3] memory indices = [uint8(0), uint8(1), uint8(3)];
        for (uint256 i; i < 3; ++i) {
            StreamArtistOwner owner = target.owner(indices[i]);
            assert(
                owner.ownerStateSnapshotV2().revision == 1 && owner.artistNativeReceiptCount() == 0
            );
            (RH.OwnerProvenance memory prefix, bytes32 commitment, uint64 revision) =
                owner.recoveredHydrationImportedPrefix();
            assert(commitment == keccak256("joined source admission fixture") && revision == 1);
            assert(
                RH.ownerProvenanceHash(prefix, indices[i])
                    == RH.ownerProvenanceHash(_local(source, indices[i], q), indices[i])
            );
        }
    }

    function testSimpleLateRevertRestoresAllThreeOwnersAndAllowsIdenticalRetry() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        RecoveredSimpleCoordinatorFixture target =
            new RecoveredSimpleCoordinatorFixture(address(503));
        AH.Query memory q = _query(source);
        AH.OwnerData[3] memory data = _data(source, q);
        bytes32 before_ = _snapshot(target);
        bytes memory call_ =
            abi.encodeCall(target.importThree, (q, data, keccak256("retry admission fixture")));
        target.setLateFailure(true);
        _revert(
            address(target),
            call_,
            abi.encodeWithSelector(RecoveredSimpleCoordinatorFixture.SimpleLateFailure.selector)
        );
        assert(_snapshot(target) == before_ && target.bindingOwner().binding(7).generation == 0);
        assert(target.acceptanceOwner().acceptanceRecord(q.bindingHash) == 0);
        target.setLateFailure(false);
        (bool ok,) = address(target).call(call_);
        assert(ok);
        _retained(source, target, q);
    }

    function testSimpleRejectsRealNonnativeCollaboratorProposalAndCompletion() external {
        for (uint256 complete; complete < 2; ++complete) {
            RecoveredSimpleCoordinatorFixture source = _source();
            AH.Query memory q = _query(source);
            source.proposeCollaborator(complete != 0);
            assert(source.collaboratorOwner().artistNativeReceiptCount() == 0);
            assert(source.collaboratorOwner().ownerStateSnapshotV2().revision == complete + 1);
            RH.OwnerProvenance memory local = _local(source, 1, q);
            _revert(
                address(source.collaboratorOwner()),
                abi.encodeCall(
                    source.collaboratorOwner().recoveredAuthorityHydrationState, (q, local)
                ),
                abi.encodeWithSelector(T.UnsupportedProfile.selector)
            );
        }
    }

    function testSimpleRejectsRealNonnativeCollaboratorJoinWithoutReplayOrNativeRows() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        source.acceptCollaboratorRow(q.bindingHash);
        assert(source.collaboratorOwner().artistNativeReceiptCount() == 0);
        assert(source.collaboratorOwner().authorityCheckpoint().replayCount == 0);
        assert(source.collaboratorOwner().acceptedCount(q.bindingHash) == 1);
        assert(source.collaboratorOwner().identityLinked(bytes32(uint256(1004)), address(1003)));
        RH.OwnerProvenance memory local = _local(source, 1, q);
        _revert(
            address(source.collaboratorOwner()),
            abi.encodeCall(source.collaboratorOwner().recoveredAuthorityHydrationState, (q, local)),
            abi.encodeWithSelector(T.UnsupportedProfile.selector)
        );
    }

    function testSimpleRejectsPendingAndRealSecondGenerationAfterWithdrawal() external {
        RecoveredSimpleCoordinatorFixture source =
            new RecoveredSimpleCoordinatorFixture(address(504));
        source.propose(7);
        AH.Query memory q = _query(source);
        RH.OwnerProvenance memory p = _local(source, 0, q);
        _revert(
            address(source.bindingOwner()),
            abi.encodeCall(source.bindingOwner().recoveredAuthorityHydrationState, (q, p)),
            abi.encodeWithSelector(T.UnsupportedProfile.selector)
        );
        source.withdraw(7);
        source.propose(7);
        source.accept(7);
        assert(source.bindingOwner().binding(7).generation == 2);
        // Complete source checkpoint witnesses include the original withdrawal guard.
        q = _query(source);
        p = _bindingWithWithdrawal(source, q);
        _revert(
            address(source.bindingOwner()),
            abi.encodeCall(source.bindingOwner().recoveredAuthorityHydrationState, (q, p)),
            abi.encodeWithSelector(T.UnsupportedProfile.selector)
        );
    }

    function testSimpleRejectsMultipleActualAcceptedCollectionsWithoutDroppingRows() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        source.create(8);
        AH.Query memory q = _query(source);
        for (uint256 i; i < 2; ++i) {
            uint8 index = i == 0 ? 0 : 3;
            RH.OwnerProvenance memory p = _local(source, index, q);
            _revert(
                address(source.owner(index)),
                abi.encodeCall(source.owner(index).recoveredAuthorityHydrationState, (q, p)),
                abi.encodeWithSelector(T.UnsupportedProfile.selector)
            );
        }
    }

    function testSimpleBindingDecoderRejectsChangedHistoryTermsTerminalAndOriginalHash() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        RH.OwnerProvenance memory p = _local(source, 0, q);
        bytes memory raw = source.bindingOwner().recoveredAuthorityHydrationState(q, p);
        RecoveredSimpleDecodeBoundary decoder = new RecoveredSimpleDecodeBoundary();
        for (uint256 i; i < 4; ++i) {
            S.Binding memory b = Adapter.decodeBinding(q, p, raw);
            if (i == 0) b.history.proposer = address(999);
            if (i == 1) b.terms.collaboratorSetHash = bytes32(uint256(999));
            if (i == 2) b.terminal.reasonHash = bytes32(uint256(999));
            if (i == 3) {
                b.item.identityRecordHash = bytes32(uint256(999));
                b.history = b.item;
            }
            _revert(
                address(decoder),
                abi.encodeCall(decoder.binding, (q, p, abi.encode(S.BINDING, RH.VERSION, b))),
                abi.encodeWithSelector(
                    i == 3 ? T.InvalidRecord.selector : T.UnsupportedProfile.selector
                )
            );
        }
    }

    function testSimpleAcceptanceDecoderRejectsMissingTimeRecordScopeAndNoncanonicalBytes()
        external
    {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        RH.OwnerProvenance memory p = _local(source, 3, q);
        bytes memory raw = source.acceptanceOwner().recoveredAuthorityHydrationState(q, p);
        RecoveredSimpleDecodeBoundary decoder = new RecoveredSimpleDecodeBoundary();
        for (uint256 i; i < 4; ++i) {
            S.Acceptance memory a = Adapter.decodeAcceptance(q, p, raw);
            if (i == 0) a.acceptedAt = 0;
            if (i == 1) a.record = bytes32(uint256(999));
            if (i == 2) a.scope.bindingHash = bytes32(uint256(999));
            bytes memory encoded = i == 3
                ? bytes.concat(raw, bytes32(uint256(1)))
                : abi.encode(S.ACCEPTANCE, RH.VERSION, a);
            bytes4 error_ = i == 3
                ? RH.InvalidRecoveredHydrationProfile.selector
                : (i == 2 ? T.InvalidRecord.selector : T.UnsupportedProfile.selector);
            _revert(
                address(decoder),
                abi.encodeCall(decoder.acceptance, (q, p, encoded)),
                abi.encodeWithSelector(error_)
            );
        }
    }

    function testSimpleRepeatedEraCertificateAccountsForImportAndRejectsHiddenLocalChanges()
        external
    {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        RecoveredSimpleDecodeBoundary decoder = new RecoveredSimpleDecodeBoundary();
        uint8[3] memory indices = [uint8(0), uint8(1), uint8(3)];
        for (uint256 i; i < 3; ++i) {
            uint8 index = indices[i];
            RH.OwnerProvenance memory p = _local(source, index, q);
            bytes memory raw = source.owner(index).recoveredAuthorityHydrationState(q, p);
            p = _syntheticSecondEra(p, index);
            raw = _rebind(raw, p, index);
            bytes memory call_ = _decodeCall(decoder, q, p, raw, index);
            (bool ok,) = address(decoder).call(call_);
            assert(ok);
            p.eras[1].checkpoint.ownerState.revision = 2;
            raw = _rebind(raw, p, index);
            _revert(
                address(decoder),
                _decodeCall(decoder, q, p, raw, index),
                abi.encodeWithSelector(T.UnsupportedProfile.selector)
            );
        }
    }

    function testSimpleSourceExportRejectsStaleCheckpointAndWrongRuntimePin() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        AH.Query memory q = _query(source);
        for (uint256 i; i < 2; ++i) {
            RH.OwnerProvenance memory p = _local(source, 0, q);
            if (i == 0) {
                p.eras[0].checkpoint.ownerState.stateRoot = keccak256("stale root");
            } else {
                p.origins[0].ownerCodeHashes[0] = keccak256("wrong runtime");
                p = _rehashFirst(p);
            }
            _revert(
                address(source.bindingOwner()),
                abi.encodeCall(source.bindingOwner().recoveredAuthorityHydrationState, (q, p)),
                abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
            );
        }
    }

    function testSimpleImportRejectsOccupiedCollaboratorAndRollsBackEarlierOwner() external {
        RecoveredSimpleCoordinatorFixture source = _source();
        RecoveredSimpleCoordinatorFixture target =
            new RecoveredSimpleCoordinatorFixture(address(505));
        AH.Query memory q = _query(source);
        target.acceptCollaboratorRow(q.bindingHash);
        bytes32 before_ = _snapshot(target);
        _revert(
            address(target),
            abi.encodeCall(
                target.importThree, (q, _data(source, q), keccak256("occupied destination"))
            ),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        assert(_snapshot(target) == before_ && target.bindingOwner().binding(7).generation == 0);
        assert(target.collaboratorOwner().acceptedCount(q.bindingHash) == 1);
    }

    function _source() private returns (RecoveredSimpleCoordinatorFixture source) {
        source = new RecoveredSimpleCoordinatorFixture(address(501));
        source.create(7);
    }

    function _query(RecoveredSimpleCoordinatorFixture source)
        private
        view
        returns (AH.Query memory q)
    {
        T.Binding memory b = source.bindingOwner().binding(7);
        q.artistId = b.artistId;
        q.collectionId = 7;
        q.bindingHash = b.bindingHash;
    }

    function _local(RecoveredSimpleCoordinatorFixture source, uint8 index, AH.Query memory q)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        T.SuiteConfiguration memory suite = source.authorityHydrationSuite();
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = suite.registry;
        o.coordinator = address(source);
        o.archive = suite.archive;
        o.owners = suite.owners;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        o.core = suite.core;
        o.manager = suite.mintManager;
        o.suiteConfigurationHash = keccak256(abi.encode(suite));
        p.origins[0] = o;
        StreamArtistOwner owner = source.owner(index);
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint = owner.authorityCheckpoint();
        p.eras[0].nativeCount = owner.artistNativeReceiptCount();
        p.journal = new RH.JournalEntry[](p.eras[0].nativeCount);
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].receipt = owner.artistNativeReceiptAt(i);
            p.journal[i].position = RH.Position(
                RH.Point(RH.originHash(o), index, owner.artistNativeReceiptRevisionAt(i)), i
            );
        }
        p.aliases = new RH.ReplayAlias[](p.eras[0].checkpoint.replayCount);
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a;
            a.originHash = RH.originHash(o);
            a.ownerIndex = index;
            (a.originalKey, a.cell) = owner.authorityReplayAt(i);
            if (index == 0) {
                a.surface = keccak256("binding_lifecycle.replay.proposal_key");
                a.scope = keccak256(abi.encode(q.collectionId + i, uint64(1)));
            } else if (index == 3) {
                a.surface = keccak256("acceptance_lifecycle.replay.record_uniqueness");
                a.scope =
                    keccak256(abi.encode(q.collectionId + i, uint64(1), uint8(1), address(1001)));
            } else {
                a.surface = keccak256("collaborator_lifecycle.replay.collaborator_proposal_key");
                a.scope = keccak256(abi.encode(address(1003), keccak256("collaborator document")));
            }
            a.admittedAt = RH.Point(RH.originHash(o), index, a.cell.touchedRevision);
            p.aliases[i] = a;
        }
        _sort(p.aliases);
    }

    function _bindingWithWithdrawal(RecoveredSimpleCoordinatorFixture source, AH.Query memory q)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        p = _local(source, 0, q);
        for (uint256 i; i < 3; ++i) {
            RH.ReplayAlias memory a;
            a.originHash = p.eras[0].originHash;
            a.ownerIndex = 0;
            (a.originalKey, a.cell) = source.bindingOwner().authorityReplayAt(i);
            a.surface = i == 1
                ? keccak256("binding_lifecycle.replay.proposal_terminal_transition_key")
                : keccak256("binding_lifecycle.replay.proposal_key");
            a.scope = keccak256(abi.encode(uint256(7), uint64(i == 2 ? 2 : 1)));
            a.admittedAt = RH.Point(a.originHash, 0, a.cell.touchedRevision);
            p.aliases[i] = a;
        }
        _sort(p.aliases);
    }

    function _data(RecoveredSimpleCoordinatorFixture source, AH.Query memory q)
        private
        view
        returns (AH.OwnerData[3] memory data)
    {
        uint8[3] memory indices = [uint8(0), uint8(1), uint8(3)];
        for (uint256 i; i < 3; ++i) {
            uint8 index = indices[i];
            RH.OwnerProvenance memory local = _local(source, index, q);
            bytes memory semantic = source.owner(index).recoveredAuthorityHydrationState(q, local);
            RH.ExportHeader memory header;
            header.profile = RH.PROFILE;
            header.version = RH.VERSION;
            header.ownerIndex = index;
            header.sourceOrigin = local.eras[0].originHash;
            header.semanticInventory = keccak256(semantic);
            header.provenanceCommitment = RH.ownerProvenanceHash(local, index);
            header.replayAliasesCommitment = RH.aliasesHash(index, local.aliases);
            header.semanticRecordCount = local.journal.length;
            header.replayAliasCount = local.aliases.length;
            header.eraCount = 1;
            Payload.Payload memory payload;
            payload.provenance = local;
            payload.nonces = new RH.NonceInventory[](0);
            payload.semanticState = semantic;
            data[i].typedState = Payload.encode(index, header, payload);
            data[i].origins = new AH.Origin[](local.aliases.length);
            data[i].sourceKeys = new bytes32[](local.aliases.length);
            data[i].cells = new T.ReplayCell[](local.aliases.length);
            for (uint256 j; j < local.aliases.length; ++j) {
                RH.ReplayAlias memory a = local.aliases[j];
                data[i].origins[j] = AH.Origin(a.surface, a.scope);
                data[i].sourceKeys[j] = a.originalKey;
                data[i].cells[j] = a.cell;
            }
        }
    }

    function _syntheticSecondEra(RH.OwnerProvenance memory p, uint8 index)
        private
        pure
        returns (RH.OwnerProvenance memory next)
    {
        next.origins = new RH.OriginEnvironment[](2);
        next.origins[0] = p.origins[0];
        next.origins[1] = abi.decode(abi.encode(p.origins[0]), (RH.OriginEnvironment));
        next.origins[1].registry = address(9001);
        next.origins[1].coordinator = address(9002);
        next.origins[1].owners[index] = address(9003);
        next.origins[1].suiteConfigurationHash = keccak256("synthetic second immutable suite");
        next.eras = new RH.OwnerEra[](2);
        next.eras[0] = p.eras[0];
        CP.Checkpoint memory checkpoint =
            abi.decode(abi.encode(p.eras[0].checkpoint), (CP.Checkpoint));
        next.eras[1] = RH.OwnerEra(
            RH.originHash(next.origins[1]),
            checkpoint,
            0,
            1,
            keccak256("synthetic import certificate")
        );
        next.eras[1].checkpoint.ownerState.revision = 1;
        next.journal = p.journal;
        next.aliases = new RH.ReplayAlias[](p.aliases.length * 2);
        if (p.aliases.length != 0) {
            next.aliases[0] = p.aliases[0];
            next.aliases[1] = abi.decode(abi.encode(p.aliases[0]), (RH.ReplayAlias));
            next.aliases[1].originHash = next.eras[1].originHash;
            next.aliases[1].originalKey = _key(next.origins[1], next.aliases[1]);
            _sort(next.aliases);
        }
    }

    function _rehashFirst(RH.OwnerProvenance memory p)
        private
        pure
        returns (RH.OwnerProvenance memory)
    {
        bytes32 hash = RH.originHash(p.origins[0]);
        p.eras[0].originHash = hash;
        for (uint256 i; i < p.journal.length; ++i) {
            p.journal[i].position.point.environmentHash = hash;
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            p.aliases[i].originHash = hash;
            p.aliases[i].admittedAt.environmentHash = hash;
        }
        return p;
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
                o.owners[a.ownerIndex],
                RH.ownerDomain(a.ownerIndex),
                a.surface,
                a.scope
            )
        );
    }

    function _rebind(bytes memory raw, RH.OwnerProvenance memory p, uint8 index)
        private
        pure
        returns (bytes memory)
    {
        bytes32 commitment = RH.ownerProvenanceHash(p, index);
        if (index == 0) {
            (,, S.Binding memory b) = abi.decode(raw, (bytes32, uint16, S.Binding));
            b.provenanceCommitment = commitment;
            return abi.encode(S.BINDING, RH.VERSION, b);
        }
        if (index == 3) {
            (,, S.Acceptance memory a) = abi.decode(raw, (bytes32, uint16, S.Acceptance));
            a.provenanceCommitment = commitment;
            return abi.encode(S.ACCEPTANCE, RH.VERSION, a);
        }
        (,, S.EmptyCollaborator memory c) = abi.decode(raw, (bytes32, uint16, S.EmptyCollaborator));
        c.provenanceCommitment = commitment;
        return abi.encode(S.COLLABORATOR, RH.VERSION, c);
    }

    function _decodeCall(
        RecoveredSimpleDecodeBoundary decoder,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        bytes memory raw,
        uint8 index
    ) private pure returns (bytes memory) {
        if (index == 0) return abi.encodeCall(decoder.binding, (q, p, raw));
        if (index == 3) return abi.encodeCall(decoder.acceptance, (q, p, raw));
        return abi.encodeCall(decoder.collaborator, (q, p, raw));
    }

    function _sort(RH.ReplayAlias[] memory aliases) private pure {
        for (uint256 i = 1; i < aliases.length; ++i) {
            RH.ReplayAlias memory item = aliases[i];
            uint256 j = i;
            while (j != 0 && aliases[j - 1].originalKey > item.originalKey) {
                aliases[j] = aliases[j - 1];
                --j;
            }
            aliases[j] = item;
        }
    }

    function _snapshot(RecoveredSimpleCoordinatorFixture fixture) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                fixture.bindingOwner().authorityCheckpoint(),
                fixture.collaboratorOwner().authorityCheckpoint(),
                fixture.acceptanceOwner().authorityCheckpoint(),
                fixture.bindingOwner().authorityHydrationCommitment(),
                fixture.collaboratorOwner().authorityHydrationCommitment(),
                fixture.acceptanceOwner().authorityHydrationCommitment()
            )
        );
    }

    function _retained(
        RecoveredSimpleCoordinatorFixture source,
        RecoveredSimpleCoordinatorFixture target,
        AH.Query memory q
    ) private view {
        assert(
            keccak256(abi.encode(source.bindingOwner().binding(7)))
            == keccak256(abi.encode(target.bindingOwner().binding(7)))
        );
        assert(
            keccak256(abi.encode(source.bindingOwner().bindingAt(7, 1)))
                == keccak256(abi.encode(target.bindingOwner().bindingAt(7, 1)))
        );
        assert(
            keccak256(abi.encode(source.bindingOwner().bindingTerms(7, 1)))
                == keccak256(abi.encode(target.bindingOwner().bindingTerms(7, 1)))
        );
        assert(
            target.acceptanceOwner().acceptanceRecord(q.bindingHash)
                == source.acceptanceOwner().acceptanceRecord(q.bindingHash)
        );
        assert(
            target.acceptanceOwner().acceptedAt(q.bindingHash)
                == source.acceptanceOwner().acceptedAt(q.bindingHash)
        );
        assert(target.collaboratorOwner().acceptedCount(q.bindingHash) == 0);
    }

    function _revert(address target, bytes memory data, bytes memory expected) private {
        (bool ok, bytes memory reason) = target.call(data);
        assert(!ok && keccak256(reason) == keccak256(expected));
    }
}
