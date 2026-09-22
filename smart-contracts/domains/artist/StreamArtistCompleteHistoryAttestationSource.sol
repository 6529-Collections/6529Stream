// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
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
    IStreamArtistAuthenticatedAttestationOwner
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistAttributionOwner
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistRecordPublicationOwner as PublicationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistPersonhoodTypes as Personhood,
    IStreamArtistPersonhoodEvidence
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistCompleteHistoryAttestationValidation as Validation
} from "./StreamArtistCompleteHistoryAttestationValidation.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryAttestationHeads as Heads
} from "./StreamArtistCompleteHistoryAttestationHeads.sol";
import {
    StreamArtistCompleteHistoryAttestationQueries as Queries
} from "./StreamArtistCompleteHistoryAttestationQueries.sol";

/// @notice Exact original source maps collected once in full owner4 native order.
/// @dev Current bundle headers name the latest binding only. Original leaves, publication,
/// personhood summaries and credential heads retain their actual generation and Artist.

library StreamArtistCompleteHistoryAttestationSource {
    function collect(
        address source,
        M.State memory scope,
        CT.Inventory memory inventory,
        Clocks.Result memory clocks,
        ReadinessH.AttestationInput[][] memory inputs
    ) public view returns (bytes[] memory rows) {
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 4);
        Provenance.validateOwnerSource(p, 4, source);
        if (inputs.length != scope.collections.length || p.journal.length > RH.MAX_JOURNAL_ENTRIES) _invalid();
        Original.Bundle[] memory all = new Original.Bundle[](inputs.length);
        uint256 total;
        for (uint256 k; k < all.length; ++k) {
            AH.Query memory q = scope.collections[k];
            Original.Bundle memory b;
            b.provenance = RH.ownerProvenanceHash(p, 4);
            b.artistId = q.artistId;
            b.collectionId = q.collectionId;
            b.bindingHash = q.bindingHash;
            (b.item.state, b.item.generation) =
                IStreamArtistAttributionOwner(source).attributionState(q.collectionId);
            if (inputs[k].length > 128) _invalid();
            b.records = new PubH.Row[](inputs[k].length);
            uint256 count;
            for (uint256 i; i < inputs[k].length; ++i) {
                if (_personhood(inputs[k][i].terms)) ++count;
            }
            b.personhood = new Original.PersonhoodRow[](count);
            all[k] = b;
            total += inputs[k].length;
        }
        uint256 nativeRecords;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 24) ++nativeRecords;
            else if (!Queries.other(p.journal[i].receipt)) _invalid();
        }
        if (total != nativeRecords) _invalid();
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory summaries = new uint256[](all.length);
        Personhood.Summary memory empty;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (Queries.other(entry.receipt)) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            if (entry.receipt.operation != 24 || cursors[k] >= inputs[k].length) _invalid();
            uint256 cursor = cursors[k]++;
            bytes32 hash = entry.receipt.recordHash;
            PubH.Row memory r;
            r.attestation.input = inputs[k][cursor];
            r.attestation.record = IStreamArtistAttributionOwner(source).attestationRecord(hash);
            r.attestation.authorityClass =
                IStreamArtistReadinessAttributionOwner(source).attestationAuthorityClass(hash);
            r.attestation.association =
                IStreamArtistAuthenticatedAttestationOwner(source).attestationAssociation(hash);
            r.attestation.statement = IStreamArtistAttributionOwner(source)
                .statementBytes(r.attestation.record.statementHash);
            r.publication = PublicationOwner(source).publicationAttestation(hash);
            all[k].records[cursor] = r;
            Personhood.Summary memory summary =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummary(hash);
            bytes32 summaryHash =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummaryHash(hash);
            if (_personhood(inputs[k][cursor].terms)) {
                all[k].personhood[summaries[k]++] = Original.PersonhoodRow(
                    hash,
                    _origin(p, entry.position.point.environmentHash).registry,
                    summary,
                    summaryHash
                );
            } else if (
                summaryHash != 0 || keccak256(abi.encode(summary)) != keccak256(abi.encode(empty))
            ) {
                _invalid();
            }
        }
        rows = new bytes[](all.length);
        for (uint256 k; k < all.length; ++k) {
            rows[k] = abi.encode(all[k]);
        }
        Validation.validate(scope, inventory, clocks, rows);
        Heads.requireMatches(source, scope, inventory, all);
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

    function _personhood(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && Credentials.isPersonhood(p.schemaId);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
