// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
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

import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";

/// @notice Exact attestation recipes executed in the original Attribution owner storage context.
library StreamArtistAttributionAttestations {
    event ArtistAttestationDelegation(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed delegationRecordHash,
        bytes32 indexed artistId,
        address signer
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

    function recordAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) public returns (AttrState.Mutation memory m) {
        // The old callback has no operative Identity fact. Only deployment uses it.
        if (p.subjectKind != 9) revert T.UnsupportedProfile();
        if (signer != b.artistAddress) revert T.InvalidAttribution(p.collectionId);
        AttrState.AttestationContext memory x;
        x.signer = signer;
        x.nonce = nonce;
        x.signedAt = signedAt;
        x.authorityClass = 1;
        return _recordAttestation(s, e, b, p, statement, x);
    }

    function recordIdentityAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) public returns (AttrState.Mutation memory m) {
        if (p.subjectKind != 10 || operativeIdentityHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
        if (signer != b.artistAddress) revert T.InvalidAttribution(p.collectionId);
        AttrState.AttestationContext memory x;
        x.operativeIdentityHash = operativeIdentityHash;
        x.signer = signer;
        x.nonce = nonce;
        x.signedAt = signedAt;
        x.authorityClass = 1;
        return _recordAttestation(s, e, b, p, statement, x);
    }

    function recordAuthenticatedAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        Attest.Admission calldata a,
        bytes calldata statement
    ) public returns (AttrState.Mutation memory m) {
        StreamArtistCurrentAuthorityFacts.requireAccepted(
            b, a.authority.authorityAddress, a.authority, false
        );
        uint8 class_ = a.authority.authorityClass;
        if (a.delegation != 0) {
            if (class_ != 1 || a.signer == address(0)) revert T.InvalidRecord();
            class_ = 2;
        } else if (a.signer != a.authority.authorityAddress) {
            revert T.InvalidRecord();
        }
        if (
            a.signedAt == 0 || a.signedAt > block.timestamp || a.fact.owner.code.length == 0
                || a.fact.ownerCodeHash != a.fact.owner.codehash || a.fact.subjectId != p.subjectId
                || a.fact.stateHash != p.subjectStateHash
        ) revert T.InvalidRecord();
        m.record = StreamArtistHashes.attestationRecordForAuthority(
            e, p, b.artistId, a.signer, class_, a.nonce, a.signedAt
        );
        Attest.Association memory association =
            Attest.Association(b.artistId, b.bindingHash, b.generation, a.delegation, a.fact);
        s.attestationAssociations[m.record] = association;
        bytes32 associationHash = keccak256(abi.encode(association));
        if (p.subjectKind == 7 || p.subjectKind == 8) {
            AttrState.Attribution storage attr = s.attributions[p.collectionId];
            if (
                !StreamArtistAttributionPolicy.acceptedOrSanctioned(attr.state)
                    || attr.generation != b.generation
            ) revert T.InvalidAttribution(p.collectionId);
            StreamArtistRecordPublicationState.Input memory input_;
            input_.environment = e;
            input_.binding_ = b;
            input_.terms = p;
            input_.authority = R.AuthorityFact(b.artistId, a.signer, class_, a.authority.status);
            input_.nonce = a.nonce;
            input_.signedAt = a.signedAt;
            input_.statement = statement;
            input_.metadataHostCodeHash = a.fact.ownerCodeHash;
            (bytes32 actual, bytes32 action, bytes32 stateDelta) = StreamArtistRecordPublicationState.record(
                s.records, s.attestations, s.statements, s.publications, input_
            );
            if (actual != m.record) revert T.InvalidRecord();
            s.attestationClasses[m.record] = class_;
            m.action = action;
            m.stateDelta = keccak256(abi.encode(stateDelta, associationHash));
        } else {
            AttrState.AttestationContext memory x;
            x.operativeIdentityHash = a.operativeIdentity;
            x.signer = a.signer;
            x.nonce = a.nonce;
            x.signedAt = a.signedAt;
            x.authorityClass = class_;
            x.verifiedSubjectHash = a.fact.stateHash;
            x.associationHash = associationHash;
            AttrState.Mutation memory actual = _recordAttestation(s, e, b, p, statement, x);
            if (actual.record != m.record) revert T.InvalidRecord();
            m.action = actual.action;
            m.stateDelta = actual.stateDelta;
        }
        if (a.delegation != 0) {
            emit ArtistAttestationDelegation(1, m.record, a.delegation, b.artistId, a.signer);
        }
    }

    function recordAttestationWithAuthority(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 operativeIdentityHash,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) public returns (AttrState.Mutation memory m) {
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
        if (
            (p.subjectKind == 10 && operativeIdentityHash == bytes32(0))
                || (p.subjectKind == 9 && operativeIdentityHash != bytes32(0))
        ) revert T.InvalidRecord();
        AttrState.AttestationContext memory x;
        x.operativeIdentityHash = operativeIdentityHash;
        x.signer = signer;
        x.nonce = nonce;
        x.signedAt = signedAt;
        x.authorityClass = authority.authorityClass;
        return _recordAttestation(s, e, b, p, statement, x);
    }

    function recordPublicationAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        R.AuthorityFact calldata authority,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement,
        bytes32 metadataHostCodeHash
    ) public returns (AttrState.Mutation memory m) {
        StreamArtistCurrentAuthorityFacts.requireAccepted(
            b, authority.authorityAddress, authority, false
        );
        if ((p.subjectKind != 7 && p.subjectKind != 8) || metadataHostCodeHash == 0) {
            revert T.InvalidRecord();
        }
        AttrState.Attribution storage attr = s.attributions[p.collectionId];
        if (
            !StreamArtistAttributionPolicy.acceptedOrSanctioned(attr.state)
                || attr.generation != b.generation
        ) {
            revert T.InvalidAttribution(p.collectionId);
        }
        StreamArtistRecordPublicationState.Input memory input_;
        input_.environment = e;
        input_.binding_ = b;
        input_.terms = p;
        input_.authority = authority;
        input_.nonce = nonce;
        input_.signedAt = signedAt;
        input_.statement = statement;
        input_.metadataHostCodeHash = metadataHostCodeHash;
        (bytes32 record, bytes32 action, bytes32 stateDelta) = StreamArtistRecordPublicationState.record(
            s.records, s.attestations, s.statements, s.publications, input_
        );
        s.attestationClasses[record] = authority.authorityClass;
        return AttrState.Mutation(record, action, stateDelta);
    }

    function _recordAttestation(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes calldata statement,
        AttrState.AttestationContext memory x
    ) private returns (AttrState.Mutation memory m) {
        AttrState.Attribution storage attr = s.attributions[p.collectionId];
        if (
            !StreamArtistAttributionPolicy.acceptedOrSanctioned(attr.state)
                || attr.generation != b.generation
        ) {
            revert T.InvalidAttribution(p.collectionId);
        }
        if (
            statement.length == 0 || p.statementHash == bytes32(0)
                || keccak256(statement) != p.statementHash
        ) revert T.InvalidRecord();
        if (statement.length > 8192) revert T.BoundExceeded(statement.length, 8192);
        if (bytes(p.statementURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.statementURI).length, 2048);
        }
        if (p.subjectKind == 9) {
            if (
                p.subjectId != bytes32(uint256(uint160(e.core)))
                    || p.subjectStateHash
                        != StreamArtistHashes.deploymentFacts(e, p.collectionId, b)
                    || p.schemaId != keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
            ) revert T.InvalidRecord();
        } else if (p.subjectKind == 10) {
            if (
                p.subjectId != b.artistId || p.subjectStateHash != x.operativeIdentityHash
                    || (p.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
                        && p.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"))
            ) revert T.InvalidRecord();
        } else if (p.subjectKind >= 1 && p.subjectKind <= 6) {
            if (
                x.verifiedSubjectHash == 0 || x.verifiedSubjectHash != p.subjectStateHash
                    || p.schemaId == 0
            ) revert T.InvalidRecord();
        } else {
            revert T.UnsupportedProfile();
        }
        m.record = StreamArtistHashes.attestationRecordForAuthority(
            e, p, b.artistId, x.signer, x.authorityClass, x.nonce, x.signedAt
        );
        if (s.records[m.record].recordHash != bytes32(0)) revert T.InvalidRecord();
        T.AttestationRecord memory item = T.AttestationRecord(
            m.record,
            p.subjectStateHash,
            p.schemaId,
            p.statementHash,
            b.generation,
            x.signedAt,
            x.signer
        );
        s.records[m.record] = item;
        s.attestationClasses[m.record] = x.authorityClass;
        s.attestations[keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId))] = item;
        if (s.statements[p.statementHash].length == 0) s.statements[p.statementHash] = statement;
        m.action = p.subjectKind == 10
            ? keccak256(
                abi.encode(
                    b,
                    p,
                    x.signer,
                    x.nonce,
                    x.signedAt,
                    keccak256(statement),
                    x.operativeIdentityHash
                )
            )
            : keccak256(abi.encode(b, p, x.signer, x.nonce, x.signedAt, keccak256(statement)));
        m.stateDelta = x.associationHash == 0
            ? keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId, item))
            : keccak256(
                abi.encode(
                    keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId, item)),
                    x.associationHash
                )
            );

        emit ArtistAttestationRecorded(
            1,
            p.collectionId,
            p.subjectKind,
            x.signer,
            p.subjectId,
            p.subjectStateHash,
            p.schemaId,
            p.statementHash,
            keccak256(bytes(p.statementURI)),
            x.authorityClass,
            x.nonce,
            x.signedAt,
            m.record
        );
    }
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

    function confirmSanctionFinalized(
        AttrState.State storage s,
        T.ActionContext calldata c,
        T.Binding calldata b,
        Confirmation.Transition calldata p,
        address savedSigner,
        uint8 savedAuthorityClass
    ) public returns (AttrState.Mutation memory m) {
        AttrState.Attribution storage a = s.attributions[p.collectionId];
        if (
            !b.accepted || b.artistId == 0 || b.bindingHash == 0 || p.collectionId == 0
                || p.artistId != b.artistId || p.bindingGeneration != b.generation || a.state != 2
                || p.priorAttributionState != a.state || a.generation != b.generation
                || p.sanctionRecordHash == 0 || p.finalityRecordHash == 0
                || savedSigner == address(0)
                || (savedAuthorityClass != 1 && savedAuthorityClass != 3)
        ) revert Confirmation.InvalidSanctionConfirmation();
        a.state = 3;
        m = AttrState.Mutation(
            0,
            keccak256(abi.encode(b, p, savedSigner, savedAuthorityClass)),
            keccak256(abi.encode(p.collectionId, a))
        );
        emit ArtistAttributionStateChanged(
            1,
            p.collectionId,
            3,
            b.generation,
            2,
            c.actor,
            savedAuthorityClass,
            p.sanctionRecordHash,
            p.finalityRecordHash,
            ""
        );
    }
}
