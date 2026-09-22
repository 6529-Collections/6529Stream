// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredSanctionConfirmationProof as Confirmation
} from "./StreamArtistRecoveredSanctionConfirmationProof.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistSanctionOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    IStreamArtistSanctionArchiveFacts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import { StreamArtistSanctionHashes as Hashes } from "./StreamArtistSanctionHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistSanctionState as SanctionState } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

/// @notice Complete original op12 rows and exact archived op13 transitions for one collection.
library StreamArtistRecoveredSanctionRows {
    function collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        G.Bundle memory bindings
    ) public view returns (H.Inventory memory x) {
        (x.catalogues, x.operations) = Catalogue.collect(p);
        uint256 ns;
        uint256 nc;
        for (uint256 i; i < x.operations.length; ++i) {
            if (x.operations[i].operation == 12) ++ns;
            else ++nc;
        }
        if (ns > RH.MAX_JOURNAL_ENTRIES || nc > H.MAX_CONFIRMATIONS || ns == 0) _invalid();
        x.sanctions = new H.SanctionRow[](ns);
        x.confirmations = new H.ConfirmationRow[](nc);
        ns = 0;
        nc = 0;
        for (uint256 i; i < x.operations.length; ++i) {
            H.OperationEvidence memory operation = x.operations[i];
            uint256 era = _era(p, operation.originHash);
            RH.OriginEnvironment memory o = p.origins[era];
            H.Envelope memory e = Catalogue.read(o, x.catalogues[era], operation.evidence);
            if (operation.operation == 12) {
                H.SanctionPayload memory s = Codec.sanction(e.payload);
                _sanction(o, p.eras[era], e, s, q, bindings);
                H.SanctionRow memory row;
                row.point = RH.Point(operation.originHash, 6, e.after_[6].revision);
                row.record = Source(source).sanctionRecord(e.value);
                row.archiveBytes = Source(source).sanctionArchiveBytes(e.value);
                row.archiveFacts =
                    IStreamArtistSanctionArchiveFacts(source).sanctionArchiveFacts(e.value);
                row.evidence = operation.evidence;
                if (keccak256(abi.encode(row.record)) != keccak256(abi.encode(s.record))) {
                    _invalid();
                }
                bytes memory expected = Hashes.archiveBytes(
                    StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    s.prepared.subject.finalityRegistry,
                    s.record,
                    s.prepared.ceremony,
                    s.authorization.signature
                );
                IStreamArtistSanctionArchiveFacts.Facts memory facts =
                    IStreamArtistSanctionArchiveFacts.Facts(
                        s.record.recordHash,
                        q.artistId,
                        Hashes.ARCHIVE_SCHEMA,
                        Hashes.ARCHIVE_CANONICALIZATION,
                        keccak256(expected),
                        uint64(expected.length)
                    );
                if (
                    keccak256(expected) != keccak256(row.archiveBytes)
                        || keccak256(abi.encode(facts)) != keccak256(abi.encode(row.archiveFacts))
                ) _invalid();
                x.sanctions[ns++] = row;
            } else {
                (H.ConfirmationPayload memory c, RH.Point memory ap, RH.Point memory cp) =
                    Confirmation.validate(o, p.eras[era], e);
                _binding(c.binding_, q, bindings);
                if (c.transition.collectionId != q.collectionId) _invalid();
                x.confirmations[nc++] = H.ConfirmationRow(ap, cp, operation.evidence, c.transition);
            }
        }
        _journal(q, p, x.sanctions);
        _heads(source, x.sanctions);
        _confirmed(p, x);
    }

    /// @notice The original singleton op12 proof, reusable after exact aggregate binding selection.
    /// @dev The caller authenticates the full catalogue, original era and binding inventory.
    function validateSanction(
        RH.OriginEnvironment memory o,
        RH.Era memory era,
        H.Envelope memory e,
        H.SanctionPayload memory s,
        AH.Query memory q,
        G.Bundle memory bindings
    ) public pure {
        _sanction(o, era, e, s, q, bindings);
    }

    function _sanction(
        RH.OriginEnvironment memory o,
        RH.Era memory era,
        H.Envelope memory e,
        H.SanctionPayload memory s,
        AH.Query memory q,
        G.Bundle memory bindings
    ) private pure {
        _binding(s.binding_, q, bindings);
        if (
            e.value != s.record.recordHash || s.record.artistId != q.artistId
                || s.record.terms.collectionId != q.collectionId
                || s.record.bindingGeneration != s.binding_.generation
                || s.record.bindingHash != s.binding_.bindingHash || s.record.signer == address(0)
                || (s.record.authorityClass != 1
                    && s.record.authorityClass != 3
                    && s.record.authorityClass != 4) || s.record.signer != s.approval.signer
                || s.approval.direct || s.record.signer != s.authority.authorityAddress
                || s.record.authorityClass != s.authority.authorityClass || s.record.signedAt == 0
                || s.record.deadline < s.record.signedAt || s.record.nonce != s.authorization.nonce
                || s.record.deadline != s.authorization.time
                || s.authorization.signature.length == 0 || s.authorization.signature.length > 4096
                || keccak256(abi.encode(s.record.terms)) != keccak256(abi.encode(s.request.terms))
        ) _invalid();
        StreamArtistHashes.Environment memory env =
            StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager);
        if (
            Hashes.record(env, s.record) != e.value
                || Hashes.digest(env, s.record.terms, s.authorization) != s.record.digest
                || s.approval.digest != s.record.digest || s.prepared.subject.chainId != o.chainId
                || s.prepared.subject.domain != keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1")
                || s.prepared.subject.core != o.core
                || s.prepared.subject.finalityRegistry == address(0)
                || s.prepared.subject.scopeType != s.record.terms.scopeType
                || s.prepared.subject.collectionId != s.record.terms.collectionId
                || s.prepared.subject.tokenId != s.record.terms.tokenId
                || s.prepared.subject.scopeId != s.record.terms.scopeId
                || Hashes.subject(s.prepared.subject) != s.record.terms.sanctionSubjectHash
                || keccak256(s.prepared.ceremony) != s.record.terms.statementHash
        ) _invalid();
        uint8 scope = s.record.terms.scopeType;
        if (
            scope > 4
                || (scope == 0 && (s.record.terms.tokenId != 0 || s.record.terms.scopeId != 0))
                || (scope == 1 && (s.record.terms.tokenId == 0 || s.record.terms.scopeId != 0))
                || (scope > 1 && (s.record.terms.tokenId != 0 || s.record.terms.scopeId == 0))
        ) _invalid();
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if (i != 0 && i != 1 && i != 2 && i != 6) {
                if (
                    keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
                ) _invalid();
            } else {
                if (
                    e.before_[i].domainId != RH.ownerDomain(i)
                        || e.after_[i].domainId != RH.ownerDomain(i) || e.before_[i].stateRoot == 0
                        || e.before_[i].recordChainTip == 0
                        || e.before_[i].revision < era.lowerRevisions[i]
                        || e.after_[i].revision > era.checkpoints[i].ownerState.revision
                ) _invalid();
                if (i == 0 || i == 1) {
                    if (keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))) {
                        _invalid();
                    }
                } else if (e.after_[i].revision != e.before_[i].revision + 1) {
                    _invalid();
                }
            }
        }
    }

    function _binding(T.Binding memory b, AH.Query memory q, G.Bundle memory bindings)
        private
        pure
    {
        if (
            !b.accepted || b.artistId != q.artistId || b.generation == 0
                || b.generation > bindings.rows.length
                || keccak256(abi.encode(b))
                    != keccak256(abi.encode(bindings.rows[b.generation - 1].item))
        ) _invalid();
    }

    function _journal(AH.Query memory q, RH.Provenance memory p, H.SanctionRow[] memory rows)
        private
        pure
    {
        uint256 count;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory j = p.journals[6][i];
            if (j.receipt.operation != 12) continue;
            if (
                count >= rows.length || j.receipt.artistId != q.artistId
                    || j.receipt.collectionId != q.collectionId
                    || j.receipt.recordHash != rows[count].record.recordHash
                    || !D.samePoint(j.position.point, rows[count].point)
            ) _invalid();
            ++count;
        }
        if (count != rows.length) _invalid();
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (rows[i].record.recordHash == rows[j].record.recordHash) _invalid();
            }
        }
    }

    function _heads(address source, H.SanctionRow[] memory rows) private view {
        for (uint256 i; i < rows.length; ++i) {
            bytes32 key = SanctionState.associationKey(
                rows[i].record.artistId,
                rows[i].record.bindingGeneration,
                rows[i].record.bindingHash,
                rows[i].record.terms
            );
            bytes32 current = rows[i].record.recordHash;
            for (uint256 j = i + 1; j < rows.length; ++j) {
                if (
                    key
                        == SanctionState.associationKey(
                            rows[j].record.artistId,
                            rows[j].record.bindingGeneration,
                            rows[j].record.bindingHash,
                            rows[j].record.terms
                        )
                ) current = rows[j].record.recordHash;
            }
            if (
                Source(source)
                        .sanctionForAssociation(
                            rows[i].record.artistId,
                            rows[i].record.bindingGeneration,
                            rows[i].record.bindingHash,
                            rows[i].record.terms.scopeType,
                            rows[i].record.terms.collectionId,
                            rows[i].record.terms.tokenId,
                            rows[i].record.terms.scopeId
                        ) != current
            ) _invalid();
        }
    }

    function _confirmed(RH.Provenance memory p, H.Inventory memory x) private view {
        for (uint256 i; i < x.confirmations.length; ++i) {
            H.ConfirmationRow memory c = x.confirmations[i];
            uint256 era = _era(p, c.attributionPoint.environmentHash);
            H.ConfirmationPayload memory payload = Codec.confirmation(
                Catalogue.read(p.origins[era], x.catalogues[era], c.evidence).payload
            );
            uint256 matches;
            for (uint256 j; j < x.sanctions.length; ++j) {
                H.SanctionRow memory s = x.sanctions[j];
                if (s.record.recordHash != c.transition.sanctionRecordHash) continue;
                if (
                    keccak256(abi.encode(payload.sanction)) != keccak256(abi.encode(s.record))
                        || !Clock.before(p, s.point, c.consentPoint)
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    x.confirmations[j].transition.bindingGeneration
                        == c.transition.bindingGeneration
                ) _invalid();
            }
        }
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
