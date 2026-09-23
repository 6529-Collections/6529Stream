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

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Rows
} from "./StreamArtistRecoveredHistoryRecordRows.sol";
/// @notice Original row leaves joined to exact accepted-generation owner4 clocks.
import {
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";

library StreamArtistRecoveredHistoryRecordAttestations {
    function validateEncoded(
        bytes memory raw,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        RH.Point[] memory proposals,
        RH.Point[] memory completions
    ) public pure returns (RH.Point[] memory) {
        bytes[5] memory members = Parts.members(raw);
        Original.Bundle memory b = abi.decode(members[4], (Original.Bundle));
        D.Bundle memory d = abi.decode(members[0], (D.Bundle));
        if (keccak256(members[4]) != keccak256(abi.encode(b))) _invalid();
        return validate(b, d, q, p, proposals, completions);
    }

    function validate(
        Original.Bundle memory b,
        D.Bundle memory d,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        RH.Point[] memory proposals,
        RH.Point[] memory completions
    ) internal pure returns (RH.Point[] memory points) {
        if (
            b.records.length == 0 || b.records.length > 128
                || b.personhood.length > b.records.length
                || b.provenance != RH.ownerProvenanceHash(p, 4) || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || keccak256(abi.encode(b.item)) != keccak256(abi.encode(d.current))
                || proposals.length != d.generations.length
                || completions.length != proposals.length
        ) {
            _invalid();
        }
        points = new RH.Point[](b.records.length);
        uint256 n;
        uint256 personhood;
        bytes32 credential;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.operation != 24) continue;
            if (n == b.records.length) _invalid();
            PubH.Row memory r = b.records[n];
            uint64 g = r.attestation.record.generation;
            if (
                g == 0 || g > d.generations.length || !d.generations[g - 1].accepted
                    || j.receipt.artistId != q.artistId || j.receipt.collectionId != q.collectionId
                    || j.receipt.recordHash != r.attestation.record.recordHash
                    || !Clock.beforeOwner(p, 4, completions[g - 1], j.position.point)
                    || (g < d.generations.length
                        && !Clock.beforeOwner(p, 4, j.position.point, proposals[g]))
            ) {
                _invalid();
            }
            Clock.validateOwnerPoint(p, 4, j.position.point);
            for (uint256 k; k < n; ++k) {
                if (b.records[k].attestation.record.recordHash == j.receipt.recordHash) _invalid();
            }
            points[n++] = j.position.point;
            RH.OriginEnvironment memory o = _origin(p, j.position.point.environmentHash);
            AH.Query memory rowQuery = AH.Query(
                q.artistId, q.collectionId, d.generations[g - 1].bindingHash, q.policies, q.records
            );
            Rows.validateRow(rowQuery, o, r, g);
            if (_personhood(r.attestation.input.terms)) {
                if (personhood == b.personhood.length) _invalid();
                Rows.validateSummary(rowQuery, o, r.attestation, b.personhood[personhood++], g);
            }
            if (_credential(r.attestation.input.terms)) {
                C2PA.Payload memory payload = Credentials.decode(
                    r.attestation.statement, q.artistId, r.attestation.input.terms.subjectStateHash
                );
                if (payload.previousRecordHash != credential) _invalid();
                credential = r.attestation.record.recordHash;
            }
        }
        if (n != b.records.length || personhood != b.personhood.length) _invalid();
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

    function _credential(T.Attestation memory p) private pure returns (bool) {
        return p.subjectKind == 10 && p.schemaId == Credentials.SCHEMA;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
