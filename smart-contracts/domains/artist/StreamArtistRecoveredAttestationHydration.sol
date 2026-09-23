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
    StreamArtistRecoveredAttestationValidation as Validation
} from "./StreamArtistRecoveredAttestationValidation.sol";

import {
    StreamArtistRecoveredAttestationCollection as Collection
} from "./StreamArtistRecoveredAttestationCollection.sol";

/// @notice Complete original op24 history for a singleton accepted generation-one Attribution.
/// @dev Fixed source maps and flattened native provenance authenticate history. Original Identity
/// authorization/grant-use joins belong to the enclosing Coordinator. This codec never rechecks
/// a historical signer, current subject, grant liveness, notarization head or Metadata consumption.
library StreamArtistRecoveredAttestationHydration {
    // Retain the original public error ABI; the unchanged predicate lives in fixed workers.
    error UnsupportedProfile();

    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_ATTESTATIONS_V1");
    uint256 private constant MAX_RECORDS = 128;

    struct PersonhoodRow {
        bytes32 recordHash;
        // Derived from the authenticated original native occurrence, not a new source getter.
        address originalRegistry;
        Personhood.Summary summary;
        bytes32 summaryHash;
    }

    struct Bundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        AS.Attribution item;
        PubH.Row[] records;
        PersonhoodRow[] personhood;
    }

    function selected(bytes memory outer) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, 4);
        return (h.requiredFeatures & RH.ATTESTATIONS) != 0;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        ReadinessH.AttestationInput[] memory inputs
    ) public view returns (Bundle memory b) {
        return Collection.collect(source, q, p, inputs);
    }

    function encode(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(SCHEMA, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Bundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, Bundle));
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        validate(b, q, p);
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
        Validation.validate(b, q, p);
    }

    function importState(AS.State storage s, AH.Query memory q, bytes memory outer) public {
        (RH.ExportHeader memory h, Payload.Payload memory payload) = Payload.decode(outer, 4);
        if ((h.requiredFeatures & RH.ATTESTATIONS) == 0 || payload.nonces.length != 0) _invalid();
        Bundle memory b = decode(q, payload.provenance, payload.semanticState);
        if (b.item.generation > 1 && (h.requiredFeatures & RH.BINDING_GENERATIONS) == 0) {
            _invalid();
        }
        _empty(s, b);
        s.attributions[q.collectionId] = b.item;
        uint256 personhood;
        C2PA.Head memory head;
        T.AttestationRecord memory personhoodHead;
        for (uint256 i; i < b.records.length; ++i) {
            PubH.Row memory row = b.records[i];
            ReadinessH.AttestationRow memory r = row.attestation;
            bytes32 hash = r.record.recordHash;
            s.records[hash] = r.record;
            s.attestationClasses[hash] = r.authorityClass;
            s.attestationAssociations[hash] = r.association;
            s.attestations[_key(r.input.terms)] = r.record;
            s.publications[hash] = row.publication;
            if (s.statements[r.record.statementHash].length == 0) {
                s.statements[r.record.statementHash] = r.statement;
            }
            StreamArtistPayloadStore.store(keccak256("ARTIST_PUBLICATION_STATEMENT"), r.statement);
            address registry =
                _origin(
                payload.provenance, payload.provenance.journal[i].position.point.environmentHash
            )
            .registry;
            Credentials.note(
                registry, q.artistId, q.bindingHash, r.input.terms, r.record, r.statement, false
            );
            if (_personhood(r.input.terms)) {
                PersonhoodRow memory expected = b.personhood[personhood++];
                if (
                    Summary.origin(hash) != registry || Summary.hashOf(hash) != expected.summaryHash
                        || keccak256(abi.encode(Summary.get(hash)))
                            != keccak256(abi.encode(expected.summary))
                ) _invalid();
                personhoodHead = r.record;
            } else if (Summary.origin(hash) != address(0)) {
                _invalid();
            }
            C2PA.Head memory expectedCredential;
            if (_credential(r.input.terms)) {
                head = _nextHead(head, b, r, registry);
                expectedCredential = head;
            }
            if (
                keccak256(abi.encode(Credentials.state().records[hash]))
                    != keccak256(abi.encode(expectedCredential))
            ) _invalid();
        }
        if (
            keccak256(abi.encode(Credentials.head(q.artistId))) != keccak256(abi.encode(head))
                || Credentials.personhoodKey(q.collectionId, q.artistId)
                    != personhoodHead.recordHash
        ) _invalid();
    }

    function _empty(AS.State storage s, Bundle memory b) private view {
        T.AttestationRecord memory emptyRecord;
        Attest.Association memory emptyAssociation;
        PublicationOwner.Record memory emptyPublication;
        Personhood.Summary memory emptySummary;
        C2PA.Head memory emptyHead;
        if (
            s.attributions[b.collectionId].state != 0
                || s.attributions[b.collectionId].generation != 0
                || Credentials.state().latest[b.artistId] != 0
                || keccak256(abi.encode(Credentials.head(b.artistId)))
                    != keccak256(abi.encode(emptyHead))
                || Credentials.personhoodKey(b.collectionId, b.artistId) != 0
        ) _invalid();
        // Check every target before writing: repeated subjects/statements are legitimate history.
        for (uint256 i; i < b.records.length; ++i) {
            ReadinessH.AttestationRow memory r = b.records[i].attestation;
            bytes32 hash = r.record.recordHash;
            if (
                keccak256(abi.encode(s.records[hash])) != keccak256(abi.encode(emptyRecord))
                    || s.attestationClasses[hash] != 0
                    || keccak256(abi.encode(s.attestationAssociations[hash]))
                        != keccak256(abi.encode(emptyAssociation))
                    || keccak256(abi.encode(s.publications[hash]))
                        != keccak256(abi.encode(emptyPublication))
                    || keccak256(abi.encode(s.attestations[_key(r.input.terms)]))
                        != keccak256(abi.encode(emptyRecord))
                    || s.statements[r.record.statementHash].length != 0
                    || Summary.origin(hash) != address(0) || Summary.hashOf(hash) != 0
                    || keccak256(abi.encode(Summary.get(hash)))
                        != keccak256(abi.encode(emptySummary))
                    || keccak256(abi.encode(Credentials.state().records[hash]))
                        != keccak256(abi.encode(emptyHead))
            ) _invalid();
        }
    }

    function _nextHead(
        C2PA.Head memory previous,
        Bundle memory b,
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
