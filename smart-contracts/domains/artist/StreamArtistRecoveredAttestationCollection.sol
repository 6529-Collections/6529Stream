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

/// @notice Fixed original source collection and final-head checks for recovered attestations.
/// @dev Delegate context and every source getter stay unchanged. Complete pure validation still
/// runs between original collection and head comparison; no import state is written here.
library StreamArtistRecoveredAttestationCollection {
    uint256 private constant MAX_RECORDS = 128;

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[] memory inputs
    ) public view returns (Original.Bundle memory b) {
        Provenance.validateOwnerSource(p, 4, source);
        if (inputs.length == 0 || inputs.length > MAX_RECORDS || inputs.length != p.journal.length) revert T.UnsupportedProfile();
        b.provenance = RH.ownerProvenanceHash(p, 4);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        (b.item.state, b.item.generation) =
            IStreamArtistAttributionOwner(source).attributionState(q.collectionId);
        b.records = new PubH.Row[](inputs.length);
        uint256 count;
        for (uint256 i; i < inputs.length; ++i) {
            if (_personhood(inputs[i].terms)) ++count;
        }
        b.personhood = new Original.PersonhoodRow[](count);
        count = 0;
        Personhood.Summary memory empty;
        for (uint256 i; i < inputs.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (entry.receipt.operation != 24) revert T.UnsupportedProfile();
            bytes32 hash = entry.receipt.recordHash;
            PubH.Row memory r;
            r.attestation.input = inputs[i];
            r.attestation.record = IStreamArtistAttributionOwner(source).attestationRecord(hash);
            r.attestation.authorityClass =
                IStreamArtistReadinessAttributionOwner(source).attestationAuthorityClass(hash);
            r.attestation.association =
                IStreamArtistAuthenticatedAttestationOwner(source).attestationAssociation(hash);
            r.attestation.statement = IStreamArtistAttributionOwner(source)
                .statementBytes(r.attestation.record.statementHash);
            r.publication = PublicationOwner(source).publicationAttestation(hash);
            b.records[i] = r;
            Personhood.Summary memory summary =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummary(hash);
            bytes32 summaryHash =
                IStreamArtistPersonhoodEvidence(source).personhoodProofSummaryHash(hash);
            if (_personhood(inputs[i].terms)) {
                b.personhood[count++] = Original.PersonhoodRow(
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
        Validation.validate(b, q, p);
        _sourceHeads(source, b, p);
    }

    function _sourceHeads(address source, Original.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
    {
        C2PA.Head memory head;
        T.AttestationRecord memory personhoodHead;
        for (uint256 i; i < b.records.length; ++i) {
            ReadinessH.AttestationRow memory r = b.records[i].attestation;
            C2PA.Head memory expected;
            if (_credential(r.input.terms)) {
                head = _nextHead(
                    head, b, r, _origin(p, p.journal[i].position.point.environmentHash).registry
                );
                expected = head;
            }
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(source).c2paCredentialRecord(r.record.recordHash)
                        )
                    ) != keccak256(abi.encode(expected))
            ) _invalid();
            if (_personhood(r.input.terms)) personhoodHead = r.record;
            bool last = true;
            for (uint256 j = i + 1; j < b.records.length; ++j) {
                if (_key(b.records[j].attestation.input.terms) == _key(r.input.terms)) {
                    last = false;
                }
            }
            if (
                last
                    && keccak256(
                            abi.encode(
                                IStreamArtistAttributionOwner(source)
                                    .attestation(
                                        b.collectionId,
                                        r.input.terms.subjectKind,
                                        r.input.terms.subjectId
                                    )
                            )
                        ) != keccak256(abi.encode(r.record))
            ) _invalid();
        }
        if (
            keccak256(abi.encode(IStreamArtistC2PAReads(source).c2paCredentialHead(b.artistId)))
                    != keccak256(abi.encode(head))
                || keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(source)
                                .personhoodAttestation(b.collectionId, b.artistId)
                        )
                    ) != keccak256(abi.encode(personhoodHead))
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
