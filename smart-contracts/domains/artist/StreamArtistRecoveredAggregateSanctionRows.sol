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
    StreamArtistRecoveredSanctionRows as Original
} from "./StreamArtistRecoveredSanctionRows.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
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
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

/// @notice Complete original op12/op13 rows across an authenticated collection inventory.
/// @dev Catalogues, operations and all seven owner clocks remain global. Collection selectors
/// name current heads; original records join the exact historical binding, including its Artist.
/// The selected profile authenticates those complete binding rows and the full provenance first.
library StreamArtistRecoveredAggregateSanctionRows {
    function collect(
        address source,
        AH.Query[] memory collections,
        RH.Provenance memory p,
        CB.Bundle[] memory bindings
    ) public view returns (H.Inventory memory x) {
        (H.Catalogue[] memory catalogues, H.OperationEvidence[] memory operations) =
            Catalogue.collect(p);
        return fromCatalogue(source, collections, p, bindings, catalogues, operations);
    }

    /// @notice Joins a previously authenticated exhaustive op12/op13 catalogue slice.
    /// @dev The fixed caller must prove the complete slice from its shared all-operations
    /// catalogue and recheck it around apply. This entry point does not rescan that catalogue
    /// or claim that caller-supplied omissions are complete. Every supplied row is re-read from
    /// the original Archive, and every actual native12 in the full provenance must be present.
    function fromCatalogue(
        address source,
        AH.Query[] memory collections,
        RH.Provenance memory p,
        CB.Bundle[] memory bindings,
        H.Catalogue[] memory catalogues,
        H.OperationEvidence[] memory operations
    ) public view returns (H.Inventory memory x) {
        _inputs(collections, p, bindings, catalogues);
        x.catalogues = catalogues;
        x.operations = operations;
        uint256 ns;
        uint256 nc;
        for (uint256 i; i < operations.length; ++i) {
            if (operations[i].operation == 12) ++ns;
            else if (operations[i].operation == 13) ++nc;
            else _invalid();
        }
        if (ns == 0 || ns > RH.MAX_JOURNAL_ENTRIES || nc > H.MAX_CONFIRMATIONS) _invalid();
        x.sanctions = new H.SanctionRow[](ns);
        x.confirmations = new H.ConfirmationRow[](nc);
        ns = 0;
        nc = 0;
        uint256 previousEra;
        uint256 previousIndex;
        uint64 previousRevision;
        for (uint256 i; i < operations.length; ++i) {
            H.OperationEvidence memory operation = operations[i];
            uint256 era = _era(p, operation.originHash);
            RH.OriginEnvironment memory o = p.origins[era];
            H.Envelope memory e = Catalogue.read(o, catalogues[era], operation.evidence);
            if (
                e.operation != operation.operation || era < previousEra
                    || (i != 0
                        && era == previousEra
                        && (operation.evidence.catalogueIndex <= previousIndex
                            || e.after_[6].revision <= previousRevision))
            ) _invalid();
            previousEra = era;
            previousIndex = operation.evidence.catalogueIndex;
            previousRevision = e.after_[6].revision;
            if (e.operation == 12) {
                H.SanctionPayload memory s = Codec.sanction(e.payload);
                uint256 k = collectionIndex(
                    collections, bindings, s.record.terms.collectionId, s.binding_
                );
                // Do not rewrite the signed record or the current selector. Only this proof's
                // collection query uses the actual Artist from the authenticated old binding.
                AH.Query memory q;
                q.artistId = s.binding_.artistId;
                q.collectionId = s.record.terms.collectionId;
                q.bindingHash = s.binding_.bindingHash;
                Original.validateSanction(o, p.eras[era], e, s, q, bindings[k].bindings);
                x.sanctions[ns++] = _sourceRow(source, operation, e, o, s);
            } else {
                (H.ConfirmationPayload memory c, RH.Point memory ap, RH.Point memory cp) =
                    Confirmation.validate(o, p.eras[era], e);
                collectionIndex(collections, bindings, c.transition.collectionId, c.binding_);
                x.confirmations[nc++] = H.ConfirmationRow(ap, cp, operation.evidence, c.transition);
            }
        }
        validateJournal(p, x.sanctions);
        _heads(source, x.sanctions);
        _confirmed(p, x);
    }

    /// @dev Exact assignment only. Authentication of each original binding remains in its
    /// existing full-history profile; no current Artist or same-generation shortcut is used.
    function collectionIndex(
        AH.Query[] memory collections,
        CB.Bundle[] memory bindings,
        uint256 collectionId,
        T.Binding memory binding_
    ) internal pure returns (uint256 selected) {
        if (
            collectionId == 0 || collections.length != bindings.length || !binding_.accepted
                || binding_.artistId == 0 || binding_.generation == 0
        ) _invalid();
        uint256 matches;
        for (uint256 i; i < collections.length; ++i) {
            if (collections[i].collectionId != collectionId) continue;
            if (
                bindings[i].bindings.collectionId != collectionId
                    || binding_.generation > bindings[i].bindings.rows.length
                    || keccak256(abi.encode(binding_))
                        != keccak256(
                            abi.encode(bindings[i].bindings.rows[binding_.generation - 1].item)
                        )
            ) _invalid();
            selected = i;
            ++matches;
        }
        if (matches != 1) _invalid();
    }

    /// @dev The native sequence is whole-owner and retains its original indices and points.
    function validateJournal(RH.Provenance memory p, H.SanctionRow[] memory rows) internal pure {
        uint256 count;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory j = p.journals[6][i];
            if (j.receipt.operation != 12) continue;
            if (
                count >= rows.length || j.receipt.artistId != rows[count].record.artistId
                    || j.receipt.collectionId != rows[count].record.terms.collectionId
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

    function _inputs(
        AH.Query[] memory collections,
        RH.Provenance memory p,
        CB.Bundle[] memory bindings,
        H.Catalogue[] memory catalogues
    ) private pure {
        if (
            collections.length == 0 || collections.length != bindings.length
                || p.origins.length == 0 || p.origins.length > RH.MAX_ERAS
                || p.origins.length != p.eras.length || catalogues.length != p.eras.length
        ) _invalid();
        for (uint256 i; i < collections.length; ++i) {
            if (
                collections[i].collectionId == 0
                    || bindings[i].bindings.collectionId != collections[i].collectionId
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (collections[j].collectionId == collections[i].collectionId) _invalid();
            }
        }
        for (uint256 i; i < p.eras.length; ++i) {
            H.Catalogue memory c = catalogues[i];
            RH.Era memory era = p.eras[i];
            if (
                c.originHash != era.originHash || c.originHash != RH.originHash(p.origins[i])
                    || c.attributionLower != era.lowerRevisions[4]
                    || c.attributionUpper != era.checkpoints[4].ownerState.revision
                    || c.consentLower != era.lowerRevisions[6]
                    || c.consentUpper != era.checkpoints[6].ownerState.revision
            ) _invalid();
        }
    }

    function _sourceRow(
        address source,
        H.OperationEvidence memory operation,
        H.Envelope memory e,
        RH.OriginEnvironment memory o,
        H.SanctionPayload memory s
    ) private view returns (H.SanctionRow memory row) {
        row.point = RH.Point(operation.originHash, 6, e.after_[6].revision);
        row.record = Source(source).sanctionRecord(e.value);
        row.archiveBytes = Source(source).sanctionArchiveBytes(e.value);
        row.archiveFacts = IStreamArtistSanctionArchiveFacts(source).sanctionArchiveFacts(e.value);
        row.evidence = operation.evidence;
        if (keccak256(abi.encode(row.record)) != keccak256(abi.encode(s.record))) _invalid();
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
                s.record.artistId,
                Hashes.ARCHIVE_SCHEMA,
                Hashes.ARCHIVE_CANONICALIZATION,
                keccak256(expected),
                uint64(expected.length)
            );
        if (
            keccak256(expected) != keccak256(row.archiveBytes)
                || keccak256(abi.encode(facts)) != keccak256(abi.encode(row.archiveFacts))
        ) _invalid();
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
        validateConfirmationKeys(x.confirmations);
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
        }
    }

    /// @dev Generation is collection-local, including across a historical Artist correction.
    function validateConfirmationKeys(H.ConfirmationRow[] memory rows) internal pure {
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (
                    rows[j].transition.collectionId == rows[i].transition.collectionId
                        && rows[j].transition.artistId == rows[i].transition.artistId
                        && rows[j].transition.bindingGeneration
                            == rows[i].transition.bindingGeneration
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
