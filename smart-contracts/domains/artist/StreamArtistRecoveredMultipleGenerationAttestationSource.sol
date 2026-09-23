// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

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
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationHeads as Heads
} from "./StreamArtistRecoveredMultipleGenerationAttestationHeads.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";

import { StreamArtistRecoveredMultipleGenerationAttestationSourceRead as SourceRead } from "./StreamArtistRecoveredMultipleGenerationAttestationSourceRead.sol";
import { StreamArtistRecoveredMultipleGenerationAttestationSourceInventory as SourceInventory } from "./StreamArtistRecoveredMultipleGenerationAttestationSourceInventory.sol";

/// @notice Exact original source maps collected once in full owner4 native order.
library StreamArtistRecoveredMultipleGenerationAttestationSource {
    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[][] memory inputs,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view returns (bytes[] memory rows) {
        return collect(source, scope, p, inputs, inventory, clocks, false);
    }

    /// @dev The selected aggregate profile separately proves each original confirmation and
    /// its collection/generation timeline; this flag does not establish sanctioned authority.
    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[][] memory inputs,
        G.Inventory memory inventory,
        Clocks.Result memory clocks,
        bool sanctioned
    ) public view returns (bytes[] memory rows) {
        Original.Bundle[] memory all = SourceInventory.collect(source, scope, p, inputs);
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory summaries = new uint256[](all.length);
        Personhood.Summary memory empty;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (entry.receipt.operation == 44) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            if (
                entry.receipt.operation != 24
                    || entry.receipt.artistId != scope.collections[k].artistId
                    || cursors[k] >= inputs[k].length
            ) _invalid();
            uint256 cursor = cursors[k]++;
            bytes32 hash = entry.receipt.recordHash;
            PubH.Row memory r = SourceRead.row(source, inputs[k][cursor], hash);
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
        scope.rows = rows;
        Validation.validate(scope, p, inventory, clocks, sanctioned);
        Heads.requireMatches(source, scope, p, all, inventory);
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

    function _key(T.Attestation memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId));
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
