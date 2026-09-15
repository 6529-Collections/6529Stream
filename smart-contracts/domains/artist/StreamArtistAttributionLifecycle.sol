// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttributionBindingTransport
} from "./StreamArtistAttributionBindingTransport.sol";
import { StreamArtistAttributionCommitEncoding } from "./StreamArtistAttributionCommitEncoding.sol";
import { StreamArtistAttestationTransport } from "./StreamArtistAttestationTransport.sol";
import "./StreamArtistAttestationHydration.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import "./StreamArtistAttributionBindingMutation.sol";
import "./StreamArtistAttributionReadEncoding.sol";
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";
import "./StreamArtistAttributionAttestations.sol";
import "./StreamArtistPlatformState.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "./StreamArtistAttributionClaimState.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "./StreamArtistAttributionPolicy.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistRecordPublicationState.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of collection attribution state and state-bound artist attestations.
contract StreamArtistAttributionLifecycle is StreamArtistOwner {
    // Original errors still bubble from the fixed linked attestation worker.
    error BoundExceeded(uint256 actual, uint256 maximum);
    error UnsupportedProfile();
    error InvalidSanctionConfirmation();
    error InvalidAttribution(uint256 collectionId);
    mapping(uint256 => AttrState.Attribution) private _attributions;
    mapping(bytes32 => T.AttestationRecord) private _attestations;
    mapping(bytes32 => T.AttestationRecord) private _records;
    mapping(bytes32 => bytes) private _statements;
    mapping(bytes32 => IStreamArtistRecordPublicationOwner.Record) private _publications;
    StreamArtistPlatformState.Store private _platform;
    mapping(bytes32 => uint8) private _attestationClasses;
    StreamArtistAttributionClaimState.Store private _attributionClaims;
    mapping(uint256 => bytes32) private _latestDisplayClaim;
    mapping(bytes32 => Attest.Association) private _attestationAssociations;
    event ArtistAttestationDelegation(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed delegationRecordHash,
        bytes32 indexed artistId,
        address signer
    );

    function recordPreimageBytes(bytes32 hash) external view returns (bytes memory) {
        return StreamArtistPayloadStore.recordBytes(hash);
    }

    function storedPayloadCount() external view returns (uint256) {
        return StreamArtistPayloadStore.count();
    }

    function storedPayloadAt(uint256 index) external view returns (address, bytes32, bytes32) {
        return StreamArtistPayloadStore.at(index);
    }

    function attestationAssociation(bytes32 record)
        external
        view
        returns (Attest.Association memory)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attestationAssociation(
                _attestationStore(), core, record
            )
        );
    }

    /// @notice Additional context reconstructing a refusal's exact normative record from events.
    event ArtistBindingTerminationContext(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint64 indexed bindingGeneration,
        bytes32 indexed recordReference,
        bytes32 bindingHash,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    );
    event ArtistAttributionStateChanged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed newState,
        uint64 bindingGeneration,
        uint8 oldState,
        address actor,
        uint8 authorityClass,
        bytes32 recordHash,
        bytes32 reasonHash,
        string reasonURI
    );
    event ArtistAttestationRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed subjectKind,
        address indexed signer,
        bytes32 subjectId,
        bytes32 subjectStateHash,
        bytes32 schemaId,
        bytes32 statementHash,
        bytes32 statementURIHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 attestationRecordHash
    );

    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:attribution_lifecycle"),
            core_,
            manager_
        )
    { }

    function confirmSanctionFinalized(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Confirmation.Transition calldata p,
        address savedSigner,
        uint8 savedAuthorityClass
    ) external {
        _check(c, 13);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.confirmSanctionFinalized(
            _attestationStore(), msg.data
        );
        _commit(c, m.action, m.stateDelta, 0, 0);
    }

    function platformWorksAdmission(uint256 collectionId)
        external
        view
        returns (PW.Admission memory)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.platformWorksAdmission(
                _attestationStore(), core, collectionId
            )
        );
    }

    function platformWorksState(uint256 collectionId) external view returns (PW.State memory) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.platformWorksState(
                _attestationStore(), core, collectionId
            )
        );
    }

    function platformWorksClaimRecord(bytes32 hash) external view returns (PW.Claim memory) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.platformWorksClaimRecord(
                _attestationStore(), core, hash
            )
        );
    }

    function platformWorksContestRecord(bytes32 hash) external view returns (PW.Contest memory) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.platformWorksContestRecord(
                _attestationStore(), core, hash
            )
        );
    }

    function declarePlatformWorks(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 statementHash
    ) external returns (bytes32 hash) {
        _check(c, 8);
        if (_attributions[collectionId].generation != 0 || _attributions[collectionId].state != 0) {
            revert PW.InvalidPlatformWorks(collectionId);
        }
        hash = StreamArtistPlatformState.declare(
            _platform, artistRegistry, core, c.actor, collectionId, statementHash
        );
        _platformCommit(c, collectionId, hash, bytes32(collectionId), hash);
    }

    function filePlatformWorksClaim(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI,
        address proposedArtist
    ) external returns (bytes32 hash) {
        _check(c, 9);
        hash = StreamArtistPlatformState.claim(
            _platform,
            artistRegistry,
            core,
            c.actor,
            collectionId,
            evidenceHash,
            reasonHash,
            reasonURI,
            proposedArtist
        );
        _latestDisplayClaim[collectionId] = hash;
        _platformCommit(
            c,
            collectionId,
            hash,
            keccak256(abi.encode(collectionId, c.actor, evidenceHash, reasonHash)),
            hash
        );
    }

    function setPlatformWorksContest(
        T.ActionContext calldata c,
        uint256 collectionId,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId,
        address adjudicatedArtist
    ) external returns (bytes32 hash) {
        _check(c, 11);
        hash = StreamArtistPlatformState.contest(
            _platform, collectionId, state, claim_, evidence, reason, actionId, adjudicatedArtist
        );
        _platformCommit(
            c, collectionId, hash, keccak256(abi.encode(collectionId, actionId)), bytes32(0)
        );
    }

    function approvePlatformWorksCorrection(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId
    ) external returns (bytes32 hash) {
        _check(c, 53);
        hash = StreamArtistPlatformState.correct(
            _platform, artistRegistry, core, collectionId, claim_, evidence, reason, actionId
        );
        _platformCommit(c, collectionId, hash, keccak256(abi.encode(collectionId, actionId)), hash);
    }

    function _platformCommit(
        T.ActionContext calldata c,
        uint256 id,
        bytes32 hash,
        bytes32 scope,
        bytes32 primary
    ) private {
        bytes32 replay = _consume(
            keccak256(abi.encode("PLATFORM_WORKS", c.operationId)), scope, hash
        );
        _commit(
            c,
            hash,
            StreamArtistAttributionCommitEncoding.platformState(_platform, id),
            replay,
            primary
        );
        _native(c.operationId, hash, bytes32(0), id);
    }

    function fileAttributionClaim(
        T.ActionContext calldata c,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string calldata uri,
        address proposedArtist
    ) external returns (bytes32 record) {
        _check(c, 10);
        record = StreamArtistAttributionClaimState.file(
            _attributionClaims,
            artistRegistry,
            core,
            c.actor,
            id,
            evidence,
            reason,
            uri,
            proposedArtist
        );
        _latestDisplayClaim[id] = record;
        bytes32 replay = _consume(
            keccak256("attribution_lifecycle.replay.claim_record_hash_uniqueness"),
            keccak256(abi.encode(id, c.actor, evidence, reason)),
            record
        );
        _commit(
            c,
            keccak256(abi.encode(id, c.actor, evidence, reason, uri, proposedArtist)),
            StreamArtistAttributionCommitEncoding.claimState(_attributionClaims, record),
            replay,
            record
        );
        _native(c.operationId, record, bytes32(0), id);
    }

    function attributionClaims(uint256 id) external view returns (uint256, bytes32) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attributionClaims(_attestationStore(), core, id)
        );
    }

    function attributionClaimRecord(bytes32 hash)
        external
        view
        returns (StreamArtistAttributionClaimTypes.Claim memory)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attributionClaimRecord(
                _attestationStore(), core, hash
            )
        );
    }

    function attestationAuthorityClass(bytes32 hash) public view returns (uint8) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attestationAuthorityClass(
                _attestationStore(), core, hash
            )
        );
    }

    function artistAttestationStatus(uint256 id, uint8 kind, bytes32 subjectId, bytes32 currentHash)
        external
        view
        returns (uint8 status, bytes32 record, bytes32 attested, uint8 class_, uint64 signedAt)
    {
        _returnAttribution(
                StreamArtistAttributionReadEncoding.artistAttestationStatus(
                    _attestationStore(), core, id, kind, subjectId, currentHash
                )
            );
    }

    function deploymentAttestation(uint256 id) external view returns (bytes32, uint8, uint64) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.deploymentAttestation(_attestationStore(), core, id)
        );
    }

    function attributionState(uint256 collectionId) external view returns (uint8, uint64) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attributionState(
                _attestationStore(), core, collectionId
            )
        );
    }

    function attestation(uint256 collectionId, uint8 kind, bytes32 subjectId)
        external
        view
        returns (T.AttestationRecord memory)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attestation(
                _attestationStore(), core, collectionId, kind, subjectId
            )
        );
    }

    function attestationRecord(bytes32 record) external view returns (T.AttestationRecord memory) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.attestationRecord(_attestationStore(), core, record)
        );
    }

    function statementBytes(bytes32 hash) external view returns (bytes memory) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.statementBytes(_attestationStore(), core, hash)
        );
    }

    function publicationAttestation(bytes32 recordHash)
        external
        view
        returns (IStreamArtistRecordPublicationOwner.Record memory)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.publicationAttestation(
                _attestationStore(), core, recordHash
            )
        );
    }

    function claim(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external {
        _check(c, 1);
        AttrState.Mutation memory m =
            StreamArtistAttributionBindingTransport.claimEncoded(_attestationStore(), msg.data);
        _commit(c, m.action, m.stateDelta, 0, 0);
    }

    function recordRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint256 nonce,
        bytes32 record
    ) external {
        _check(c, 3);
        if (signer != b.artistAddress || record == bytes32(0)) revert T.InvalidRecord();
        _terminate(c, b, p, signer, 1, nonce, record);
    }

    function recordWithdrawal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p
    ) external {
        _check(c, 4);
        if (c.actor != b.proposer) revert T.Unauthorized(c.actor);
        _terminate(c, b, p, c.actor, 0, 0, b.bindingHash);
    }

    function recordRefusalWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce,
        bytes32 record
    ) external {
        _check(c, 3);
        StreamArtistCurrentAuthorityFacts.requirePrincipal(b.artistId, signer, authority, false);
        if (record == bytes32(0)) revert T.InvalidRecord();
        _terminate(c, b, p, signer, authority.authorityClass, nonce, record);
    }

    function _terminate(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint8 authority,
        uint256 nonce,
        bytes32 recordReference
    ) private {
        AttrState.Mutation memory m =
            StreamArtistAttributionBindingTransport.terminateEncoded(
                _attestationStore(), msg.data, signer, authority, nonce, recordReference
            );
        _commit(c, m.action, m.stateDelta, 0, 0);
    }

    function accept(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record
    ) external {
        _check(c, 2);
        _complete(c, collectionId, b, record, b.artistAddress, 1);
    }

    function completeCollaboratorBinding(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        address signer
    ) external {
        _check(c, 7);
        if (signer == address(0)) revert T.InvalidSignature();
        _complete(c, collectionId, b, record, signer, 1);
    }

    function acceptWithAuthority(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        R.AuthorityFact calldata authority
    ) external {
        _check(c, 2);
        StreamArtistCurrentAuthorityFacts.requirePrincipal(
            b.artistId, authority.authorityAddress, authority, false
        );
        _complete(c, collectionId, b, record, authority.authorityAddress, authority.authorityClass);
    }

    function completeCollaboratorBindingWithAuthority(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        address signer,
        R.AuthorityFact calldata authority
    ) external {
        _check(c, 7);
        StreamArtistCurrentAuthorityFacts.requirePrincipal(
            authority.artistId, signer, authority, false
        );
        _complete(c, collectionId, b, record, signer, authority.authorityClass);
    }

    function _complete(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        address signer,
        uint8 authorityClass
    ) private {
        AttrState.Mutation memory m =
            StreamArtistAttributionBindingTransport.completeEncoded(
                _attestationStore(), msg.data, signer, authorityClass
            );
        _commit(c, m.action, m.stateDelta, 0, 0);
    }

    function recordAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32 record) {
        _check(c, 24);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordAttestation(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    function recordIdentityAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32) {
        _check(c, 24);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordIdentityAttestation(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    function recordAuthenticatedAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        Attest.Admission calldata a,
        bytes calldata statement
    ) external returns (bytes32 record) {
        _check(c, 24);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordAuthenticatedAttestation(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    function recordAttestationWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32) {
        _check(c, 24);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordAttestationWithAuthority(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    function recordPublicationAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        R.AuthorityFact calldata authority,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement,
        bytes32 metadataHostCodeHash
    ) external returns (bytes32) {
        _check(c, 24);
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordPublicationAttestation(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    /// @dev Exact declared storage root, not a computed or caller-supplied location.
    function _attestationStore() private pure returns (AttrState.State storage s) {
        assembly ("memory-safe") { s.slot := _attributions.slot }
    }

    function _returnAttribution(bytes memory encoded) private pure {
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function authorityHydrationState(AH.Query calldata q)
        external
        view
        override
        returns (bytes memory)
    {
        AttrState.Attribution memory a = _attributions[q.collectionId];
        if (a.state != 2 || a.generation != 1) revert T.UnsupportedProfile();
        return abi.encode(a);
    }

    function authorityAttestationHydrationState(
        AH.Query calldata q,
        StreamArtistReadinessHydrationTypes.AttestationInput[] calldata inputs
    ) external view returns (bytes memory) {
        return StreamArtistAttestationHydration.exportState(
            _attestationStore(), _environment(), q, inputs
        );
    }

    function _hydrateAuthority(AH.Query calldata q, AH.OwnerData calldata p) internal override {
        if (StreamArtistAttestationHydration.isState(p.typedState)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistAttestationHydration.importState(
                _attestationStore(), _environment(), q, p.typedState
            );
            return;
        }
        if (_attributions[q.collectionId].generation != 0 || p.nonces.length != 0) {
            revert T.InvalidRecord();
        }
        _attributions[q.collectionId] = abi.decode(p.typedState, (AttrState.Attribution));
    }
}
