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
import {
    StreamArtistRecoveredAttestationValidation as Validation
} from "./StreamArtistRecoveredAttestationValidation.sol";

/// @notice Complete op24 rows from the unfiltered original owner4 journal.
library StreamArtistRecoveredHistoryRecordCollection {
    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[] memory inputs
    ) public view returns (Original.Bundle memory b) {
        Provenance.validateOwnerSource(p, 4, source);
        uint256 total;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 24) ++total;
        }
        if (total == 0 || total > 128 || inputs.length != total) revert T.UnsupportedProfile();
        b.provenance = RH.ownerProvenanceHash(p, 4);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        (b.item.state, b.item.generation) =
            IStreamArtistAttributionOwner(source).attributionState(q.collectionId);
        b.records = new PubH.Row[](total);
        uint256 personhood;
        for (uint256 i; i < inputs.length; ++i) {
            if (_personhood(inputs[i].terms)) ++personhood;
        }
        b.personhood = new Original.PersonhoodRow[](personhood);
        personhood = 0;
        uint256 n;
        Personhood.Summary memory empty;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (entry.receipt.operation != 24) continue;
            bytes32 hash = entry.receipt.recordHash;
            PubH.Row memory r;
            r.attestation.input = inputs[n];
            r.attestation.record = IStreamArtistAttributionOwner(source).attestationRecord(hash);
            r.attestation.authorityClass =
                IStreamArtistReadinessAttributionOwner(source).attestationAuthorityClass(hash);
            r.attestation.association =
                IStreamArtistAuthenticatedAttestationOwner(source).attestationAssociation(hash);
            r.attestation.statement = IStreamArtistAttributionOwner(source)
                .statementBytes(r.attestation.record.statementHash);
            r.publication = PublicationOwner(source).publicationAttestation(hash);
            b.records[n++] = r;
            Personhood.Summary memory summary =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummary(hash);
            bytes32 summaryHash =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummaryHash(hash);
            if (_personhood(r.attestation.input.terms)) {
                b.personhood[personhood++] = Original.PersonhoodRow(
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
