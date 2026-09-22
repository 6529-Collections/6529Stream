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
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";

import { StreamArtistRecoveredMultipleGenerationAttestationInventory as InventoryValidation } from "./StreamArtistRecoveredMultipleGenerationAttestationInventory.sol";

/// @notice Validate the complete original owner4 journal in receipt order.
library StreamArtistRecoveredMultipleGenerationAttestationJournal {
    struct Context {
        M.State scope;
        RH.OwnerProvenance provenance;
        G.Inventory inventory;
        Clocks.Result clocks;
        Original.Bundle[] all;
        uint256 total;
    }

    function validate(Context memory x) public pure {
        M.State memory scope = x.scope;
        RH.OwnerProvenance memory p = x.provenance;
        G.Inventory memory inventory = x.inventory;
        Clocks.Result memory clocks = x.clocks;
        Original.Bundle[] memory all = x.all;
        uint256 total = x.total;
        uint256 nativeRecords;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 24) ++nativeRecords;
            else if (p.journal[i].receipt.operation != 44) _invalid();
        }
        if (total != nativeRecords) _invalid();
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory summaries = new uint256[](all.length);
        C2PA.Head[] memory heads = new C2PA.Head[](scope.artists.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (entry.receipt.operation == 44) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(scope, entry.receipt.artistId);
            if (
                entry.receipt.operation != 24
                    || scope.collections[k].artistId != entry.receipt.artistId
                    || cursors[k] >= all[k].records.length
            ) _invalid();
            PubH.Row memory row = all[k].records[cursors[k]++];
            if (entry.receipt.recordHash != row.attestation.record.recordHash) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == entry.receipt.recordHash) _invalid();
            }
            RH.OriginEnvironment memory o = _origin(p, entry.position.point.environmentHash);
            uint64 generation = row.attestation.record.generation;
            if (generation == 0 || generation > inventory.bindings[k].bindings.rows.length) {
                _invalid();
            }
            T.Binding memory binding_ = inventory.bindings[k].bindings.rows[generation - 1].item;
            if (
                !binding_.accepted || binding_.generation != generation
                    || binding_.artistId != entry.receipt.artistId
                    || !Clock.beforeOwner(
                        p,
                        4,
                        clocks.collections[k].attributionCompletions[generation - 1],
                        entry.position.point
                    )
                    || (generation < inventory.bindings[k].bindings.rows.length
                        && !Clock.beforeOwner(
                            p,
                            4,
                            entry.position.point,
                            clocks.collections[k].attributionProposals[generation]
                        ))
            ) _invalid();
            AH.Query memory historical = AH.Query(
                scope.collections[k].artistId,
                scope.collections[k].collectionId,
                binding_.bindingHash,
                scope.collections[k].policies,
                scope.collections[k].records
            );
            Semantic.validateRow(historical, o, row, generation);
            if (_personhood(row.attestation.input.terms)) {
                if (summaries[k] >= all[k].personhood.length) _invalid();
                Semantic.validateSummary(
                    historical, o, row.attestation, all[k].personhood[summaries[k]++], generation
                );
            }
            if (_credential(row.attestation.input.terms)) {
                heads[a] =
                    _nextHead(heads[a], all[k], row.attestation, o.registry, binding_.bindingHash);
            }
        }
        for (uint256 k; k < all.length; ++k) {
            if (cursors[k] != all[k].records.length || summaries[k] != all[k].personhood.length) {
                _invalid();
            }
        }
    }

    function _nextHead(
        C2PA.Head memory previous,
        Original.Bundle memory b,
        ReadinessH.AttestationRow memory r,
        address registry,
        bytes32 bindingHash
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
            bindingHash,
            r.record.generation,
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
