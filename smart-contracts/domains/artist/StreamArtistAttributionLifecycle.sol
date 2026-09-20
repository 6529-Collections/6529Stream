// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredCollectionHydration
} from "./StreamArtistRecoveredCollectionHydration.sol";
import { StreamArtistRecoveredHydrationCodec } from "./StreamArtistRecoveredHydrationCodec.sol";
import { StreamArtistAttributionRecoveredImport } from "./StreamArtistAttributionRecoveredImport.sol";
import "./StreamArtistC2PACredentials.sol";
import { StreamArtistPersonhoodReads } from "./StreamArtistPersonhoodReads.sol";
import { StreamArtistPersonhoodReadEncoding } from "./StreamArtistPersonhoodReadEncoding.sol";
import { StreamArtistPersonhoodSummary } from "./StreamArtistPersonhoodSummary.sol";
import { StreamArtistPersonhoodTypes as Personhood } from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import "./StreamArtistDisputeWithdrawalState.sol";
import {
    StreamArtistAttributionPlatformTransport as PlatformTransport
} from "./StreamArtistAttributionPlatformTransport.sol";
import {
    IStreamArtistStaticFacts as SF
} from "../../interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import "./StreamArtistRepudiationState.sol";
import "./StreamArtistRepudiationAttributionTransport.sol";

import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "./StreamArtistDisputeState.sol";
import { StreamArtistAttributionDisputeTransport as DisputeTransport } from "./StreamArtistAttributionDisputeTransport.sol";
import { StreamArtistAttributionSupplementalReads } from "./StreamArtistAttributionSupplementalReads.sol";

import {
    StreamArtistAttributionBindingTransport
} from "./StreamArtistAttributionBindingTransport.sol";
import { StreamArtistAttributionCommitEncoding } from "./StreamArtistAttributionCommitEncoding.sol";
import { StreamArtistAttestationTransport } from "./StreamArtistAttestationTransport.sol";
import "./StreamArtistAttestationHydration.sol";
import "./StreamArtistAttributionHydrationTransport.sol";
import "./StreamArtistPublicationHydration.sol";
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
    error InvalidPlatformWorks(uint256 collectionId);
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

    function personhoodEvidence(uint256 collectionId, bytes32 artistId)
        external view returns (Personhood.Selection calldata) {
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function personhoodEvidenceStatus(uint256 collectionId, bytes32 artistId)
        external view returns (bytes32, Personhood.Status) {
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function personhoodProofSummary(bytes32 nativeRecordHash)
        external view returns (Personhood.Summary calldata) {
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function personhoodProofSummaryHash(bytes32 nativeRecordHash) external view returns (bytes32) {
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function auditPersonhoodEvidence(bytes32 nativeRecordHash)
        external view returns (bytes32, Personhood.NotarizationFacts calldata) {
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function personhoodResolution(uint256 collectionId, bytes32 artistId,
        T.AttestationRecord calldata record, bool checkEvidence)
        external view returns (bool, Personhood.NotarizationFacts calldata) {
        if (msg.sender != address(this)) revert T.Unauthorized(msg.sender);
        _returnAttribution(StreamArtistPersonhoodReadEncoding.readEncoded(
            _attestationStore(), _environment(), operationCoordinator, msg.data
        ));
    }

    function c2paCredentialHead(bytes32 artistId) external view returns (C2PA.Head memory) {
        return StreamArtistC2PACredentials.head(artistId);
    }

    function c2paCredentialRecord(bytes32 record) external view returns (C2PA.Head memory) {
        return StreamArtistC2PACredentials.state().records[record];
    }

    function personhoodAttestation(uint256 collectionId, bytes32 artistId)
        external
        view
        returns (T.AttestationRecord memory)
    {
        bytes32 record = StreamArtistC2PACredentials.personhoodKey(collectionId, artistId);
        if (record != 0) return _records[record];
        // Historical imports without the derived index retain their original personhood head.
        T.AttestationRecord memory legacy =
            _attestations[keccak256(abi.encode(collectionId, uint8(10), artistId))];
        if (StreamArtistC2PACredentials.isPersonhood(legacy.schemaId)) return legacy;
        T.AttestationRecord memory empty;
        return empty;
    }
    event ArtistAttestationDelegation(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed delegationRecordHash,
        bytes32 indexed artistId,
        address signer
    );

    function staticAttributionState(uint256 id) external view returns (uint8, uint64) {
        AttrState.Attribution storage a = _attributions[id];
        return (a.state, a.generation);
    }

    function staticPlatformWorksState(uint256 id) external view returns (PW.State memory) {
        PW.State storage p = _platform.collections[id];
        // Exact twenty fixed ABI words from the original typed State root.
        assembly ("memory-safe") {
            let output := mload(0x40)
            let root := p.slot
            let addressMask := sub(shl(160, 1), 1)
            let uint64Mask := sub(shl(64, 1), 1)
            mstore(output, sload(root))
            mstore(add(output, 32), sload(add(root, 1)))
            let declaration := sload(add(root, 2))
            mstore(add(output, 64), and(declaration, addressMask))
            mstore(add(output, 96), and(shr(160, declaration), uint64Mask))
            mstore(add(output, 128), and(sload(add(root, 3)), 255))
            mstore(add(output, 160), sload(add(root, 4)))
            mstore(add(output, 192), sload(add(root, 5)))
            mstore(add(output, 224), sload(add(root, 6)))
            mstore(add(output, 256), sload(add(root, 7)))
            mstore(add(output, 288), sload(add(root, 8)))
            mstore(add(output, 320), and(sload(add(root, 9)), addressMask))
            mstore(add(output, 352), sload(add(root, 10)))
            mstore(add(output, 384), sload(add(root, 11)))
            mstore(add(output, 416), sload(add(root, 12)))
            mstore(add(output, 448), sload(add(root, 13)))
            mstore(add(output, 480), sload(add(root, 14)))
            let approval := sload(add(root, 15))
            mstore(add(output, 512), and(approval, uint64Mask))
            mstore(add(output, 544), and(shr(64, approval), uint64Mask))
            mstore(add(output, 576), iszero(iszero(and(shr(128, approval), 255))))
            mstore(add(output, 608), sload(add(root, 16)))
            return(output, 640)
        }
    }

    function staticAttributionClaims(uint256 id) external view returns (uint256, bytes32) {
        PW.State storage p = _platform.collections[id];
        uint256 count = _attributionClaims.counts[id];
        if (count == 0) return (p.claimCount, p.latestClaim);
        return (p.claimCount + count, _latestDisplayClaim[id]);
    }

    function staticAttestation(uint256 id, uint8 kind, bytes32 subject)
        external
        view
        returns (SF.Attestation memory result)
    {
        T.AttestationRecord storage r = _attestations[keccak256(abi.encode(id, kind, subject))];
        uint8 class_;
        if (r.recordHash != 0 && _records[r.recordHash].recordHash == r.recordHash) {
            class_ = _attestationClasses[r.recordHash];
            if (
                class_ == 0
                    && _publications[r.recordHash].evidence.attestationRecordHash == r.recordHash
            ) {
                class_ = _publications[r.recordHash].evidence.authorityClass;
            }
        }
        return SF.Attestation(r.recordHash, r.generation, r.subjectStateHash, class_, r.signedAt);
    }

    function recordPreimageBytes(bytes32 hash) external view returns (bytes calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function storedPayloadCount() external view returns (uint256) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function storedPayloadAt(uint256 index) external view returns (address, bytes32, bytes32) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attestationAssociation(bytes32 record)
        external
        view
        returns (Attest.Association calldata)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
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
        returns (PW.Admission calldata)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function platformWorksState(uint256 collectionId) external view returns (PW.State calldata) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function platformWorksClaimRecord(bytes32 hash) external view returns (PW.Claim calldata) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function platformWorksContestRecord(bytes32 hash) external view returns (PW.Contest calldata) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function declarePlatformWorks(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 statementHash
    ) external returns (bytes32 hash) {
        return _platformTransport(c, 8);
    }

    function filePlatformWorksClaim(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string calldata reasonURI,
        address proposedArtist
    ) external returns (bytes32 hash) {
        return _platformTransport(c, 9);
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
        return _platformTransport(c, 11);
    }

    function approvePlatformWorksCorrection(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId
    ) external returns (bytes32 hash) {
        return _platformTransport(c, 53);
    }

    function _platformTransport(T.ActionContext calldata c, uint16 op) private returns (bytes32) {
        _check(c, op);
        PlatformTransport.Result memory m =
            PlatformTransport.applyEncoded(_attestationStore(), _environment(), msg.data);
        bytes32 replay = _consume(
            c.operationId == 10
                ? keccak256("attribution_lifecycle.replay.claim_record_hash_uniqueness")
                : keccak256(abi.encode("PLATFORM_WORKS", c.operationId)),
            m.scope,
            m.record
        );
        bytes32 state = c.operationId == 10
            ? StreamArtistAttributionCommitEncoding.claimState(_attributionClaims, m.record)
            : StreamArtistAttributionCommitEncoding.platformState(_platform, m.id);
        _commit(c, m.action, state, replay, m.primary);
        _native(c.operationId, m.record, bytes32(0), m.id);
        return m.record;
    }

    function fileAttributionClaim(
        T.ActionContext calldata c,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string calldata uri,
        address proposedArtist
    ) external returns (bytes32 record) {
        return _platformTransport(c, 10);
    }

    function attributionClaims(uint256 id) external view returns (uint256, bytes32) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function attributionClaimRecord(bytes32 hash)
        external
        view
        returns (StreamArtistAttributionClaimTypes.Claim calldata)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function attestationAuthorityClass(bytes32 hash) public view returns (uint8) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function artistAttestationStatus(uint256 id, uint8 kind, bytes32 subjectId, bytes32 currentHash)
        external
        view
        returns (uint8 status, bytes32 record, bytes32 attested, uint8 class_, uint64 signedAt)
    {
        _returnAttribution(
                StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
            );
    }

    function deploymentAttestation(uint256 id) external view returns (bytes32, uint8, uint64) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function attributionState(uint256 collectionId) external view returns (uint8, uint64) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function attestation(uint256 collectionId, uint8 kind, bytes32 subjectId)
        external
        view
        returns (T.AttestationRecord calldata)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function attestationRecord(bytes32 record) external view returns (T.AttestationRecord calldata) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function statementBytes(bytes32 hash) external view returns (bytes calldata) {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
        );
    }

    function publicationAttestation(bytes32 recordHash)
        external
        view
        returns (IStreamArtistRecordPublicationOwner.Record calldata)
    {
        _returnAttribution(
            StreamArtistAttributionReadEncoding.readEncoded(_attestationStore(), core, msg.data)
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
        return _recordAttestationEncoded(c, b.artistId, p.collectionId);
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
        return _recordAttestationEncoded(c, b.artistId, p.collectionId);
    }

    function recordAuthenticatedAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        Attest.Admission calldata a,
        bytes calldata statement
    ) external returns (bytes32 record) {
        _check(c, 24);
        return _recordAttestationEncoded(c, b.artistId, p.collectionId);
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
        return _recordAttestationEncoded(c, b.artistId, p.collectionId);
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
        return _recordAttestationEncoded(c, b.artistId, p.collectionId);
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
        returns (bytes calldata)
    {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function authorityAttestationHydrationState(
        AH.Query calldata q,
        StreamArtistReadinessHydrationTypes.AttestationInput[] calldata inputs
    ) external view returns (bytes calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function authorityPublicationHydrationState(
        AH.Query calldata q,
        StreamArtistReadinessHydrationTypes.AttestationInput[] calldata inputs
    ) external view returns (bytes calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function _hydrateAuthority(AH.Query calldata q, AH.OwnerData calldata p) internal override {
        if (StreamArtistRecoveredHydrationCodec.isState(p.typedState, 4)) {
            if (_revision != 0 || p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistAttributionRecoveredImport.importEncoded(_attestationStore(), msg.data);
            return;
        }
        StreamArtistAttributionHydrationTransport.importEncoded(
            _attestationStore(), _environment(), msg.data
        );
    }

    function _recoveredHydrationFeatures() internal pure override returns (uint256) {
        return StreamArtistRecoveredHydrationTypes.ECONOMICS_GRAPH_FEATURES;
    }

    function recoveredAuthorityHydrationState(
        AH.Query calldata q,
        StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata p
    ) external view override returns (bytes calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionDispute(uint256 id, uint64 generation)
        external
        view
        returns (AD.Head calldata)
    {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionDisputeRecord(bytes32 hash) external view returns (AD.Record calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionDisputeResolution(bytes32 action)
        external
        view
        returns (AD.Resolution calldata)
    {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionDisputeWithdrawal(bytes32 opening) external view
        returns (StreamArtistDisputeWithdrawalTypes.Outcome calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function applyDisputeWithdrawal(T.ActionContext calldata c, AD.Filing calldata p,
        AD.Admission calldata a, uint256 nonce) external returns (bytes32) {
        _check(c, 61);
        return _disputeTransport(c);
    }

    function applyDispute(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        AD.Admission calldata a,
        uint256 nonce,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32) {
        uint16 op = p.disputeAction == 1 ? 44 : 45;
        _check(c, op);
        return _disputeTransport(c);
    }

    function applyDisputeResolution(
        T.ActionContext calldata c,
        AD.ResolutionRequest calldata p,
        T.Binding calldata b,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32) {
        _check(c, 46);
        return _disputeTransport(c);
    }

    function rawPendingRepudiation(uint256 id) external view returns (bytes32) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionRepudiationRecord(bytes32 hash) external view returns (RP.Record calldata) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function attributionRepudiationTerminal(bytes32 hash)
        external
        view
        returns (RP.Terminal calldata)
    {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function repudiationCount(bytes32 id, bytes32 cohort) external view returns (uint256) {
        _returnAttribution(StreamArtistAttributionSupplementalReads.readEncoded(
            _attestationStore(), _environment(), msg.data
        ));
    }

    function stageRepudiation(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        RP.Admission calldata admission,
        uint256 nonce
    ) external returns (bytes32) {
        _check(c, 47);
        return _disputeTransport(c);
    }

    function vetoRepudiation(
        T.ActionContext calldata c,
        RP.Record calldata record,
        RP.GuardianProof calldata proof
    ) external {
        _check(c, 48);
        _disputeTransport(c);
    }

    function cancelRepudiation(T.ActionContext calldata c, RP.Record calldata record) external {
        _check(c, 49);
        _disputeTransport(c);
    }

    function executeRepudiation(T.ActionContext calldata c, RP.Record calldata record) external {
        _check(c, 50);
        _disputeTransport(c);
    }

    function _disputeTransport(T.ActionContext calldata c) private returns (bytes32) {
        DisputeTransport.Result memory m = DisputeTransport.applyEncoded(
            _attestationStore(), _environment(), msg.data
        );
        bytes32 consumed;
        if (m.replayKind != DisputeTransport.ReplayKind.None) {
            consumed = _consume(m.replaySurface, m.replayScope, m.replayCommitment);
            if (m.replayKind == DisputeTransport.ReplayKind.GovernancePair) {
                consumed = keccak256(abi.encode(consumed, _consume(
                    keccak256("attribution_lifecycle.replay.governance_action"),
                    m.governanceScope, m.governanceCommitment
                )));
            }
        }
        _commit(c, m.action, m.state, consumed, m.record);
        if (m.nativeReceipt) _native(c.operationId, m.record, m.artistId, m.collectionId);
        return m.output;
    }
    function _recordAttestationEncoded(
        T.ActionContext calldata c,
        bytes32 artistId,
        uint256 collectionId
    ) private returns (bytes32) {
        AttrState.Mutation memory m = StreamArtistAttestationTransport.recordEncoded(
            _attestationStore(), _environment(), msg.data
        );
        _commit(c, m.action, m.stateDelta, bytes32(0), m.record);
        _native(c.operationId, m.record, artistId, collectionId);
        return m.record;
    }
}
