// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistPayloadStore
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadStore.sol";
import "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistEstateTypes as EstateTypes
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";

/// @notice Frozen original25 mechanics, not the current fixed writer.
/// @dev Exact library body from source SHA 3ac39b556f17e938c5de2b7401429a2f8903ceb3,
/// smart-contracts/domains/artist/StreamArtistIdentityRevisionState.sol; only this library name
/// and import paths differ. The canonical record hash uses the principal's authority class,
/// while the original Record constructor below stores literal1. Formatting is nonsemantic.
library FrozenRevisionState3ac39b55 {
    struct State {
        mapping(bytes32 => bytes32) latestRecord;
        mapping(bytes32 => StreamArtistIdentityRevisionTypes.Record) records;
        mapping(bytes32 => bytes32) pendingRecord;
        mapping(bytes32 => R.ProvisionalAssociation) associations;
    }

    event ArtistIdentityRevisionRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bytes32 previousRecordHash,
        bytes32 revisedRecordHash,
        string identityRecordURI,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 revisionRecordHash
    );
    event ArtistIdentityDisplayNameStored(
        bytes32 indexed artistId, bytes32 indexed identityRecordHash, string displayName
    );

    function digest(
        StreamArtistHashes.Environment memory e,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603),
                    p.artistId,
                    p.previousRecordHash,
                    p.revisedRecordHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function operative(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) internal view returns (bytes32) {
        bytes32 registration = identity.identities[artistId].identityRecordHash;
        if (registration == bytes32(0)) revert T.InvalidIdentity(artistId);
        bytes32 latest = _selected(s, rotations, artistId);
        return latest == bytes32(0) ? registration : s.records[latest].revisedRecordHash;
    }

    function operativeRead(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bytes32) {
        return operative(s, identity, rotations, artistId);
    }

    function metadata(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bytes32 documentHash, string memory uri, string memory displayName) {
        documentHash = operative(s, identity, rotations, artistId);
        bytes32 latest = _selected(s, rotations, artistId);
        if (latest == bytes32(0)) {
            T.Identity storage original = identity.identities[artistId];
            return (documentHash, original.identityRecordURI, original.displayName);
        }
        StreamArtistIdentityRevisionTypes.Record storage r = s.records[latest];
        return (documentHash, r.identityRecordURI, r.displayName);
    }

    function revise(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes memory document,
        string memory displayName
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.Closure memory empty;
        Dismissal.RevisionContinuation memory none;
        return _revise(
            s, identity, rotations, replay, o, c, p, a, proof, document, displayName, empty, none
        );
    }

    function reviseWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes memory document,
        string memory displayName,
        Dismissal.Closure memory closure,
        Dismissal.RevisionContinuation memory continuation
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _revise(
            s,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            a,
            proof,
            document,
            displayName,
            closure,
            continuation
        );
    }

    function _revise(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes memory document,
        string memory displayName,
        Dismissal.Closure memory closure,
        Dismissal.RevisionContinuation memory continuation
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        if (
            p.previousRecordHash != operative(s, identity, rotations, p.artistId)
                || p.revisedRecordHash == bytes32(0) || p.revisedRecordHash == p.previousRecordHash
                || document.length == 0 || keccak256(document) != p.revisedRecordHash
                || bytes(displayName).length == 0 || a.time == 0 || a.time > block.timestamp
                || (proof.direct && a.time != block.timestamp)
        ) revert T.InvalidRecord();
        if (document.length > 8192) revert T.BoundExceeded(document.length, 8192);
        if (bytes(p.identityRecordURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.identityRecordURI).length, 2048);
        }
        if (bytes(displayName).length > 256) {
            revert T.BoundExceeded(bytes(displayName).length, 256);
        }
        bytes32 pending_ = s.pendingRecord[p.artistId];
        if (
            pending_ != bytes32(0)
                && !StreamArtistRotationState.eligible(
                    rotations, p.artistId, s.associations[pending_]
                )
        ) {
            revert R.ProvisionalChainOccupied(pending_);
        }
        bytes32 previousRevision = _selected(s, rotations, p.artistId);
        bytes32 record = keccak256(
            abi.encode(
                bytes32(0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4),
                o.environment.chainId,
                o.environment.registry,
                p.artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                proof.signer,
                identity.identities[p.artistId].authorityClass,
                a.nonce,
                a.time
            )
        );
        if (continuation.continuationHash != bytes32(0) && continuation.artistId != p.artistId) {
            revert T.InvalidRecord();
        }
        bool continuing = continuation.continuationHash != bytes32(0)
            && continuation.stableRevisionRecordHash == previousRevision
            && continuation.stableDocumentHash == p.previousRecordHash;
        bytes32 chainSurface = continuing
            ? keccak256("identity_authority.replay.identity_revision_continuation")
            : keccak256("identity_authority.replay.identity_revision_chain");
        bytes32 chainScope = continuing
            ? keccak256(
                abi.encode(
                    p.artistId,
                    previousRevision,
                    p.previousRecordHash,
                    continuation.continuationHash
                )
            )
            : keccak256(abi.encode(p.artistId, previousRevision, p.previousRecordHash));
        bytes32 chainKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                chainSurface,
                chainScope
            )
        );
        if (replay[chainKey].status != 0) revert T.Replay(chainKey);
        if (s.records[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            digest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        StreamArtistIdentityRevisionTypes.Record memory item =
            StreamArtistIdentityRevisionTypes.Record(
                record,
                p.artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                previousRevision,
                proof.signer,
                1,
                a.nonce,
                a.time,
                p.identityRecordURI,
                displayName
            );
        s.records[record] = item;
        R.ProvisionalAssociation memory association_ =
            StreamArtistRotationState.associationWithResolution(rotations, p.artistId, closure);
        s.associations[record] = association_;
        if (association_.transitionRecordHash == bytes32(0)) {
            s.latestRecord[p.artistId] = record;
            delete s.pendingRecord[p.artistId];
        } else {
            s.latestRecord[p.artistId] = previousRevision;
            s.pendingRecord[p.artistId] = record;
        }
        if (identity.documents[p.revisedRecordHash].length == 0) {
            identity.documents[p.revisedRecordHash] = document;
            StreamArtistPayloadStore.store(keccak256("ARTIST_IDENTITY_DOCUMENT"), document);
        }
        replay[chainKey] = T.ReplayCell(record, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(chainKey, replay[chainKey]);
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof, keccak256(document), displayName));
        m.state = keccak256(
            abi.encode(
                m.state,
                previousRevision,
                item,
                association_,
                s.latestRecord[p.artistId],
                s.pendingRecord[p.artistId]
            )
        );
        m.replay = keccak256(abi.encode(m.replay, chainKey, record));
        emit ArtistIdentityRevisionRecorded(
            1,
            p.artistId,
            proof.signer,
            p.previousRecordHash,
            p.revisedRecordHash,
            p.identityRecordURI,
            identity.identities[p.artistId].authorityClass,
            a.nonce,
            a.time,
            record
        );
        emit ArtistIdentityDisplayNameStored(p.artistId, p.revisedRecordHash, displayName);

        if (
            closure.dismissalRecordHash != bytes32(0) || continuation.continuationHash != bytes32(0)
        ) {
            m.state = keccak256(abi.encode(m.state, closure, continuation, continuing));
        }
    }

    function _selected(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) private view returns (bytes32) {
        bytes32 candidate = s.pendingRecord[artistId];
        return candidate != bytes32(0)
            && StreamArtistRotationState.eligible(rotations, artistId, s.associations[candidate])
            ? candidate
            : s.latestRecord[artistId];
    }
}

interface FrozenLegacyRevisionVm {
    function warp(uint256 timestamp) external;
    function expectRevert(bytes calldata data) external;
}

contract FrozenLegacyRevisionBoundary { }

contract FrozenLegacyRevisionPayoutOwner is StreamArtistOwner {
    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager
    )
        StreamArtistOwner(
            registry, coordinator, archive, keccak256("domain:payout_lifecycle"), core_, manager
        )
    { }
}

/// @notice A labeled source-compatibility boundary, not an actual40/43 integration fixture.
/// @dev Only the initial principal/capability facts are seeded. Every tested original25 calls the
/// frozen writer, original Identity authorization/nonce allocator, owner commit and native journal.
/// No storage cheatcodes or synthetic revision rows stand in for those producer calls.
contract FrozenLegacyRevisionOwner is StreamArtistOwner {
    FrozenRevisionState3ac39b55.State private _revisions;
    StreamArtistIdentityState.State private _identity;
    StreamArtistRotationState.State private _rotations;
    bytes32 public immutable seededArtist;

    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager,
        bytes32 artistId,
        uint8 authorityClass
    )
        StreamArtistOwner(
            registry, coordinator, archive, keccak256("domain:identity_authority"), core_, manager
        )
    {
        seededArtist = artistId;
        bytes memory document = bytes("frozen-fixture registration document");
        bytes32 registration = keccak256(document);
        _identity.identities[artistId] = T.Identity(
            coordinator,
            authorityClass,
            authorityClass == 1 ? 1 : 3,
            1,
            1,
            registration,
            "ipfs://frozen-fixture-registration",
            "Frozen fixture",
            0
        );
        _identity.activeIdentity[coordinator] = artistId;
        _identity.documents[registration] = document;
    }

    function writeFrozen(
        T.ActionContext calldata context,
        StreamArtistIdentityRevisionTypes.Revision calldata proposal,
        T.Authorization calldata authorization,
        bytes calldata document
    ) external returns (bytes32 record) {
        _check(context, 25);
        StreamArtistIdentityState.OwnerContext memory owner = StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
        T.SignerApproval memory approval = T.SignerApproval(
            context.actor,
            FrozenRevisionState3ac39b55.digest(_environment(), proposal, authorization),
            true
        );
        StreamArtistIdentityState.Mutation memory mutation = FrozenRevisionState3ac39b55.revise(
            _revisions,
            _identity,
            _rotations,
            _replay,
            owner,
            context,
            proposal,
            authorization,
            approval,
            document,
            "Frozen original25"
        );
        _commit(context, mutation.action, mutation.state, mutation.replay, mutation.record);
        _native(25, mutation.record, proposal.artistId, 0);
        return mutation.record;
    }

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
        return _identity.identities[artistId];
    }

    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (EstateTypes.AuthorityCapabilities memory)
    {
        T.Identity memory principal = _identity.identities[artistId];
        return EstateTypes.AuthorityCapabilities(
            principal.authorityAddress,
            principal.authorityClass,
            principal.status,
            512,
            keccak256("SEEDED_CAPABILITY_BOUNDARY_NOT_AN_EXECUTED_ORIGIN")
        );
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        return _revisions.records[record];
    }

    function identityDocumentBytes(bytes32 hash) external view returns (bytes memory) {
        return _identity.documents[hash];
    }

    function identityRevisionProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return _revisions.associations[record];
    }

    function identityRevisionRecoveryContinuationV3(bytes32) external pure returns (bytes32) {
        return 0;
    }

    /// @dev Explicit negative read-control after a real frozen25; not a producer or history claim.
    function corruptStoredClass(bytes32 record, uint8 authorityClass) external {
        require(
            msg.sender == operationCoordinator && _revisions.records[record].recordHash == record
        );
        _revisions.records[record].authorityClass = authorityClass;
    }
}

contract FrozenLegacyRevisionReadHarness {
    function read(W.EnvironmentV3 calldata environment, bytes32 artistId, uint256 nativeIndex)
        external
        view
        returns (Records.Facts memory)
    {
        return Records.read(environment, W.RecordKind.IDENTITY_REVISION, artistId, nativeIndex);
    }
}

/// @notice Exact prepatch op25 stored-class mismatch and strict reader compatibility.
/// @dev This narrow host claims frozen original25 admission, not a live Artist/Safe/Archive flow.
contract StreamArtistRecoveryRewindLegacyRevisionTest {
    FrozenLegacyRevisionVm private constant vm =
        FrozenLegacyRevisionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("frozen-original25-artist");
    uint256 public immutable deploymentChainId = block.chainid;
    T.SuiteConfiguration private _suite;
    FrozenLegacyRevisionOwner private owner;
    FrozenLegacyRevisionReadHarness private reader;
    W.EnvironmentV3 private environment;

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function setUp() public {
        vm.warp(100);
        reader = new FrozenLegacyRevisionReadHarness();
        _deploy(3);
    }

    function testFrozenOriginal25Class3HashAndStoredLiteral1AreBothPreserved() public {
        bytes memory document = bytes("actual frozen class3 revision");
        bytes32 record = _write(document, 0);
        StreamArtistIdentityRevisionTypes.Record memory original =
            owner.identityRevisionRecord(record);
        require(original.authorityClass == 1, "exact historical stored literal1");
        require(
            record == _hash(original, 3) && record != _hash(original, 1), "original class3 hash"
        );
        Records.Facts memory facts = reader.read(environment, ARTIST, 0);
        require(facts.authorityClass == 3 && facts.eligible, "class derived from canonical hash");
        require(
            facts.selected.recordHash == record && facts.selected.nativeIndex == 0,
            "actual native25"
        );
        require(
            facts.selected.originalDataHash == keccak256(abi.encode(original, document)),
            "full stored tuple retained"
        );
        require(
            facts.selected.admissionProof != 0 && facts.admissionRevision == 1, "original admission"
        );
        require(
            facts.association.transitionRecordHash == 0 && facts.association.windowEndsAt == 0,
            "mature boundary"
        );
        _assertReplay(original);
        require(
            owner.identityRevisionRecord(record).authorityClass == 1, "reader never repairs history"
        );
    }

    function testFrozenOriginal25LivingHashRetainsOriginalClass1Behavior() public {
        _deploy(1);
        bytes32 record = _write(bytes("original living revision"), 0);
        StreamArtistIdentityRevisionTypes.Record memory original =
            owner.identityRevisionRecord(record);
        Records.Facts memory facts = reader.read(environment, ARTIST, 0);
        require(original.authorityClass == 1 && record == _hash(original, 1), "living original");
        require(facts.authorityClass == 1 && facts.selected.recordHash == record, "living reader");
        _assertReplay(original);
    }

    function testFrozenOriginal25Class3ChainAuthenticatesBothActualOriginalAdmissions() public {
        bytes32 first = _write(bytes("first class3 revision"), 0);
        StreamArtistIdentityRevisionTypes.Record memory firstRecord =
            owner.identityRevisionRecord(first);
        bytes32 firstData = reader.read(environment, ARTIST, 0).selected.originalDataHash;
        bytes32 second = _write(bytes("second class3 revision"), 1);
        StreamArtistIdentityRevisionTypes.Record memory secondRecord =
            owner.identityRevisionRecord(second);
        Records.Facts memory facts = reader.read(environment, ARTIST, 1);
        require(
            secondRecord.previousRevisionRecord == first && facts.previousRecordHash == first,
            "actual branch parent"
        );
        require(
            facts.previousValueHash == firstRecord.revisedRecordHash && facts.authorityClass == 3,
            "exact prior document"
        );
        require(
            owner.artistNativeReceiptCount() == 2 && facts.admissionRevision == 2,
            "two native admissions"
        );
        require(
            reader.read(environment, ARTIST, 0).selected.originalDataHash == firstData,
            "earlier stored tuple immutable"
        );
        _assertReplay(firstRecord);
        _assertReplay(secondRecord);
    }

    function testFrozenOriginal25RejectsStoredClasses2And4ThenIdenticalReadSucceeds() public {
        bytes32 record = _write(bytes("class controls"), 0);
        bytes32 before_ = keccak256(abi.encode(reader.read(environment, ARTIST, 0)));
        owner.corruptStoredClass(record, 2);
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, record));
        reader.read(environment, ARTIST, 0);
        owner.corruptStoredClass(record, 4);
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, record));
        reader.read(environment, ARTIST, 0);
        owner.corruptStoredClass(record, 1);
        require(
            keccak256(abi.encode(reader.read(environment, ARTIST, 0))) == before_,
            "exact tuple restoration/retry"
        );
    }

    function testFrozenOriginal25CanonicalClass4RemainsOutsideReaderProfile() public {
        _deploy(4);
        bytes32 record = _write(bytes("original class4 boundary control"), 0);
        StreamArtistIdentityRevisionTypes.Record memory original =
            owner.identityRevisionRecord(record);
        require(
            original.authorityClass == 1 && record == _hash(original, 4),
            "actual frozen class4 hash"
        );
        require(
            record != _hash(original, 1) && record != _hash(original, 3),
            "neither admitted canonical class"
        );
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, record));
        reader.read(environment, ARTIST, 0);
        _assertReplay(original);
    }

    function testFrozenOriginal25Class2CannotBeProducedByOriginalAuthorization() public {
        _deploy(2);
        bytes memory document = bytes("invalid class2 producer request");
        StreamArtistIdentityRevisionTypes.Revision memory proposal =
            StreamArtistIdentityRevisionTypes.Revision(
                ARTIST,
                owner.identity(ARTIST).identityRecordHash,
                keccak256(document),
                "ipfs://invalid-class2"
            );
        T.ActionContext memory context =
            T.ActionContext(25, address(this), owner.ownerStateSnapshotV2());
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, ARTIST));
        owner.writeFrozen(
            context, proposal, T.Authorization(0, uint64(block.timestamp), bytes("")), document
        );
        require(
            owner.ownerStateSnapshotV2().revision == 0 && owner.artistNativeReceiptCount() == 0,
            "producer rolled back"
        );
    }

    function _deploy(uint8 authorityClass) private {
        _suite.registry = address(new FrozenLegacyRevisionBoundary());
        _suite.archive = address(new FrozenLegacyRevisionBoundary());
        _suite.core = address(new FrozenLegacyRevisionBoundary());
        _suite.mintManager = address(new FrozenLegacyRevisionBoundary());
        owner = new FrozenLegacyRevisionOwner(
            _suite.registry,
            address(this),
            _suite.archive,
            _suite.core,
            _suite.mintManager,
            ARTIST,
            authorityClass
        );
        _suite.owners[2] = address(owner);
        _suite.owners[5] = address(
            new FrozenLegacyRevisionPayoutOwner(
                _suite.registry, address(this), _suite.archive, _suite.core, _suite.mintManager
            )
        );
        environment = W.EnvironmentV3(
            block.chainid,
            _suite.registry,
            address(owner),
            address(owner).codehash,
            _suite.owners[5],
            _suite.owners[5].codehash,
            address(this),
            _suite.archive,
            _suite.core,
            _suite.mintManager
        );
    }

    function _write(bytes memory document, uint256 nonce) private returns (bytes32) {
        uint256 count = owner.artistNativeReceiptCount();
        bytes32 previousDocument = count == 0
            ? owner.identity(ARTIST).identityRecordHash
            : owner.identityRevisionRecord(owner.artistNativeReceiptAt(count - 1).recordHash)
            .revisedRecordHash;
        StreamArtistIdentityRevisionTypes.Revision memory proposal =
            StreamArtistIdentityRevisionTypes.Revision(
                ARTIST, previousDocument, keccak256(document), "ipfs://original-frozen-revision"
            );
        return owner.writeFrozen(
            T.ActionContext(25, address(this), owner.ownerStateSnapshotV2()),
            proposal,
            T.Authorization(nonce, uint64(block.timestamp), bytes("")),
            document
        );
    }

    function _hash(StreamArtistIdentityRevisionTypes.Record memory record, uint8 authorityClass)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                block.chainid,
                _suite.registry,
                record.artistId,
                record.previousRecordHash,
                record.revisedRecordHash,
                record.signer,
                authorityClass,
                record.nonce,
                record.signedAt
            )
        );
    }

    function _assertReplay(StreamArtistIdentityRevisionTypes.Record memory record) private view {
        bytes32 digest = FrozenRevisionState3ac39b55.digest(
            StreamArtistHashes.Environment(
                block.chainid, _suite.registry, _suite.core, _suite.mintManager
            ),
            StreamArtistIdentityRevisionTypes.Revision(
                ARTIST,
                record.previousRecordHash,
                record.revisedRecordHash,
                record.identityRecordURI
            ),
            T.Authorization(record.nonce, record.signedAt, bytes(""))
        );
        T.ReplayCell memory nonce = owner.replayCell(
            Admission.key(
                environment,
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(ARTIST, record.nonce))
            )
        );
        T.ReplayCell memory chain = owner.replayCell(
            Admission.key(
                environment,
                keccak256("identity_authority.replay.identity_revision_chain"),
                keccak256(
                    abi.encode(ARTIST, record.previousRevisionRecord, record.previousRecordHash)
                )
            )
        );
        require(
            nonce.commitment == digest && nonce.kind == 1 && nonce.status == 2,
            "original nonce stays consumed"
        );
        require(
            chain.commitment == record.recordHash && chain.kind == 1 && chain.status == 2,
            "original branch stays consumed"
        );
        require(
            chain.touchedRevision == nonce.touchedRevision && chain.touchedRevision != 0,
            "same original write"
        );
    }
}
