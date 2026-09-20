// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH,
    IStreamArtistReadinessAttributionOwner
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttestationTypes as Attest,
    IStreamArtistAuthenticatedAttestationOwner
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistAttributionOwner
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistRecordPublicationOwner as PublicationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistRecordPublicationTypes as Publication
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistPersonhoodTypes as Personhood,
    IStreamArtistPersonhoodEvidence
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecordPublicationRules as PublicationRules
} from "./StreamArtistRecordPublicationRules.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
import { StreamArtistPersonhoodSummary as Summary } from "./StreamArtistPersonhoodSummary.sol";
import { StreamArtistPersonhoodJSON as PersonhoodJSON } from "./StreamArtistPersonhoodJSON.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "./StreamArtistPersonhoodDefinitions.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";

import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";

/// @notice Fixed pure validation of the original complete recovered attestation bundle.
/// @dev Nominal types, original hash domains and validation order stay defined by the owner codec.
/// No storage roots, current authority reads or state mutations enter this worker.
library StreamArtistRecoveredAttestationValidation {
    bytes32 private constant SUMMARY = keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1");
    uint256 private constant MAX_RECORDS = 128;

    function validate(Original.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        Provenance.validateOwner(p, 4);
        if (
            b.records.length == 0 || b.records.length > MAX_RECORDS
                || b.personhood.length > MAX_RECORDS
        ) revert T.UnsupportedProfile();
        if (
            b.provenance != RH.ownerProvenanceHash(p, 4) || q.artistId == 0
                || b.artistId != q.artistId || q.collectionId == 0
                || b.collectionId != q.collectionId || q.bindingHash == 0
                || b.bindingHash != q.bindingHash || b.item.state != 2
                || (b.item.generation == 0 || b.item.generation > 128)
                || b.records.length != p.journal.length || p.aliases.length != 0
        ) _invalid();
        _eras(p, b.item.generation);
        uint256 personhood;
        C2PA.Head memory head;
        for (uint256 i; i < b.records.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (entry.receipt.operation != 24) revert T.UnsupportedProfile();
            PubH.Row memory row = b.records[i];
            if (
                entry.receipt.artistId != b.artistId || entry.receipt.collectionId != b.collectionId
                    || entry.receipt.recordHash != row.attestation.record.recordHash
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (b.records[j].attestation.record.recordHash == entry.receipt.recordHash) {
                    _invalid();
                }
            }
            RH.OriginEnvironment memory o = _origin(p, entry.position.point.environmentHash);
            _row(q, o, row, b.item.generation);
            if (_personhood(row.attestation.input.terms)) {
                if (personhood >= b.personhood.length) _invalid();
                _summary(q, o, row.attestation, b.personhood[personhood++], b.item.generation);
            }
            if (_credential(row.attestation.input.terms)) {
                head = _nextHead(head, b, row.attestation, o.registry);
            }
        }
        if (personhood != b.personhood.length) _invalid();
    }

    function _row(
        AH.Query memory q,
        RH.OriginEnvironment memory o,
        PubH.Row memory row,
        uint64 generation
    ) private pure {
        ReadinessH.AttestationRow memory r = row.attestation;
        T.Attestation memory t = r.input.terms;
        T.AttestationRecord memory record = r.record;
        bool publication = t.subjectKind == 7 || t.subjectKind == 8;
        if (
            t.collectionId != q.collectionId || t.subjectKind == 0 || t.subjectKind > 10
                || (r.authorityClass != 1 && r.authorityClass != 2 && r.authorityClass != 3)
                || record.recordHash == 0 || record.generation != generation
                || record.signer == address(0) || record.signedAt == 0 || r.statement.length == 0
                || r.statement.length > 8192 || bytes(t.statementURI).length > 2048
                || t.statementHash != keccak256(r.statement)
                || record.statementHash != t.statementHash || record.schemaId != t.schemaId
                || record.subjectStateHash != t.subjectStateHash
                || record.recordHash
                    != Hashes.attestationRecordForAuthority(
                        _environment(o),
                        t,
                        q.artistId,
                        record.signer,
                        r.authorityClass,
                        r.input.nonce,
                        record.signedAt
                    )
        ) _invalid();
        Attest.Association memory a = r.association;
        if (a.artistId == 0) {
            Attest.Association memory empty;
            if (
                (t.subjectKind != 9 && t.subjectKind != 10 && !publication) || r.authorityClass == 2
                    || keccak256(abi.encode(a)) != keccak256(abi.encode(empty))
            ) _invalid();
        } else if (
            a.artistId != q.artistId || a.bindingHash != q.bindingHash || a.generation != generation
                || (r.authorityClass == 2 ? a.delegation == 0 : a.delegation != 0)
                || a.fact.owner == address(0) || a.fact.ownerCodeHash == 0
                || a.fact.subjectId != t.subjectId || a.fact.stateHash != t.subjectStateHash
        ) {
            _invalid();
        }
        if (t.subjectKind <= 6) {
            if (t.subjectStateHash == 0 || t.schemaId == 0) _invalid();
        } else if (t.subjectKind == 9) {
            T.Binding memory binding_;
            binding_.artistId = q.artistId;
            binding_.generation = generation;
            binding_.bindingHash = q.bindingHash;
            if (
                (a.artistId != 0 && a.fact.owner != o.core)
                    || t.subjectId != bytes32(uint256(uint160(o.core)))
                    || t.schemaId != keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
                    || t.subjectStateHash
                        != Hashes.deploymentFacts(_environment(o), q.collectionId, binding_)
            ) _invalid();
        } else if (t.subjectKind == 10) {
            if (
                (a.artistId != 0
                        && (a.fact.owner != o.owners[2]
                            || a.fact.ownerCodeHash != o.ownerCodeHashes[2]))
                    || t.subjectId != q.artistId || t.subjectStateHash == 0
                    || (!Credentials.isPersonhood(t.schemaId) && t.schemaId != Credentials.SCHEMA)
            ) _invalid();
            if (_credential(t)) Credentials.decode(r.statement, q.artistId, t.subjectStateHash);
        }
        _publication(q, row, publication, generation);
    }

    function _publication(
        AH.Query memory q,
        PubH.Row memory row,
        bool publication,
        uint64 generation
    ) private pure {
        PublicationOwner.Record memory saved = row.publication;
        if (!publication) {
            PublicationOwner.Record memory empty;
            if (keccak256(abi.encode(saved)) != keccak256(abi.encode(empty))) _invalid();
            return;
        }
        ReadinessH.AttestationRow memory r = row.attestation;
        (Publication.Publication memory p, uint32 capability) =
            PublicationRules.decode(r.input.terms, r.statement);
        Publication.Evidence memory e = saved.evidence;
        if (
            saved.metadataHostCodeHash == 0
                || keccak256(abi.encode(saved.publication)) != keccak256(abi.encode(p))
                || e.attestationRecordHash != r.record.recordHash || e.artistId != q.artistId
                || e.bindingHash != q.bindingHash || e.bindingGeneration != generation
                || e.signer != r.record.signer || e.signer != p.recorder
                || e.authorityClass != r.authorityClass || e.requiredCapability != capability
                || e.signedAt != r.record.signedAt || e.publicationHash != keccak256(abi.encode(p))
        ) _invalid();
        if (
            r.association.artistId != 0
                && (r.association.fact.owner != p.metadataHost
                    || r.association.fact.ownerCodeHash != saved.metadataHostCodeHash)
        ) _invalid();
    }

    function _summary(
        AH.Query memory q,
        RH.OriginEnvironment memory o,
        ReadinessH.AttestationRow memory r,
        Original.PersonhoodRow memory row,
        uint64 generation
    ) private pure {
        if (row.recordHash != r.record.recordHash || row.originalRegistry != o.registry) _invalid();
        bool canonical;
        Personhood.Reference memory ref_;
        if (r.input.terms.schemaId == PersonhoodDefinitions.EVIDENCE_SCHEMA) {
            (canonical, ref_) = PersonhoodJSON.tryDecode(r.statement);
        }
        if (!canonical) {
            Personhood.Summary memory empty;
            if (
                row.summaryHash != 0
                    || keccak256(abi.encode(row.summary)) != keccak256(abi.encode(empty))
            ) _invalid();
            return;
        }
        Personhood.Summary memory s = row.summary;
        if (
            s.version != 1 || s.chainId != o.chainId || s.nativeRecordHash != r.record.recordHash
                || s.statementHash != r.record.statementHash || s.artistId != q.artistId
                || s.bindingHash != q.bindingHash || s.generation != generation
                || s.collectionId != q.collectionId
                || s.identityRecordHash != r.record.subjectStateHash
                || ref_.artistRegistry != o.registry || ref_.artistId != q.artistId
                || ref_.operativeIdentityRecordHash != r.record.subjectStateHash
                || keccak256(abi.encode(s.evidenceReference)) != keccak256(abi.encode(ref_))
                || s.originalRegistryCodeHash == 0 || s.core != o.core || s.coreCodeHash == 0
                || s.documentaryHash == 0 || row.summaryHash == 0
                || row.summaryHash != keccak256(abi.encode(SUMMARY, s))
        ) _invalid();
    }

    function _nextHead(
        C2PA.Head memory previous,
        Original.Bundle memory b,
        ReadinessH.AttestationRow memory r,
        address registry
    ) private pure returns (C2PA.Head memory) {
        C2PA.Payload memory p = Credentials.decode(
            r.statement, b.artistId, r.input.terms.subjectStateHash
        );
        if (p.previousRecordHash != previous.recordHash) _invalid();
        return C2PA.Head(
            previous.revision + 1,
            r.record.recordHash,
            previous.recordHash,
            b.artistId,
            b.collectionId,
            b.bindingHash,
            b.item.generation,
            r.record.subjectStateHash,
            r.record.statementHash,
            registry
        );
    }

    function _eras(RH.OwnerProvenance memory p, uint64 generation) private pure {
        uint256 cursor;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory e = p.eras[i];
            uint256 base = i == 0 ? 2 * uint256(generation) : 1;
            if (
                e.lowerRevision != (i == 0 ? 0 : 1)
                    || uint256(e.checkpoint.ownerState.revision) != base + e.nativeCount
                    || e.checkpoint.replayCount != 0 || e.checkpoint.replayRoot != 0
                    || e.checkpoint.nonceIndexCount != 0 || e.checkpoint.nonceRoot != 0
            ) _invalid();
            for (uint256 j; j < e.nativeCount; ++j) {
                if (uint256(p.journal[cursor++].position.point.ownerRevision) != base + j + 1) {
                    _invalid();
                }
            }
        }
    }

    function _origin(RH.OwnerProvenance memory p, bytes32 hash)
        private
        pure
        returns (RH.OriginEnvironment memory)
    {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == hash) return p.origins[i];
        }
        _invalid();
    }

    function _environment(RH.OriginEnvironment memory o)
        private
        pure
        returns (Hashes.Environment memory)
    {
        return Hashes.Environment(o.chainId, o.registry, o.core, o.manager);
    }

    function _personhood(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && Credentials.isPersonhood(p.schemaId);
    }

    function _credential(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && p.schemaId == Credentials.SCHEMA;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
