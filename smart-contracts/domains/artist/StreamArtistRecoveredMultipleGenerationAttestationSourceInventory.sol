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

/// @notice Fixed source inventory and native count for complete owner4 rows.
library StreamArtistRecoveredMultipleGenerationAttestationSourceInventory {
    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[][] memory inputs
    ) public view returns (Original.Bundle[] memory all) {
        Provenance.validateOwnerSource(p, 4, source);
        if (inputs.length != scope.collections.length || p.journal.length > RH.MAX_JOURNAL_ENTRIES) _invalid();
        all = new Original.Bundle[](inputs.length);
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
            else if (p.journal[i].receipt.operation != 44) _invalid();
        }
        if (total != nativeRecords) _invalid();
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
