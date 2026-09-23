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
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

library StreamArtistRecoveredHistoryRecordHeads {
    function requireSourceEncoded(
        address source,
        bytes memory raw,
        RH.OwnerProvenance memory p,
        RH.Point[] memory points
    ) public view {
        bytes[5] memory members = Parts.members(raw);
        Original.Bundle memory b = abi.decode(members[4], (Original.Bundle));
        D.Bundle memory history = abi.decode(members[0], (D.Bundle));
        bytes32[] memory bindings = new bytes32[](b.records.length);
        for (uint256 i; i < bindings.length; ++i) {
            bindings[i] =
            history.generations[b.records[i].attestation.record.generation - 1].bindingHash;
        }
        requireSource(source, b, p, bindings, points);
    }

    function requireSource(
        address source,
        Original.Bundle memory b,
        RH.OwnerProvenance memory p,
        bytes32[] memory bindings,
        RH.Point[] memory points
    ) internal view {
        if (bindings.length != b.records.length || points.length != b.records.length) _invalid();
        C2PA.Head memory head;
        T.AttestationRecord memory personhoodHead;
        for (uint256 i; i < b.records.length; ++i) {
            ReadinessH.AttestationRow memory r = b.records[i].attestation;
            C2PA.Head memory expected;
            if (_credential(r.input.terms)) {
                head = _nextHead(
                    head, b, r, _origin(p, points[i].environmentHash).registry, bindings[i]
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
