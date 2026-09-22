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
    StreamArtistRecoveredMultipleAttestationValidation as Validation
} from "./StreamArtistRecoveredMultipleAttestationValidation.sol";

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredHistoryRecordRows as Semantic
} from "./StreamArtistRecoveredHistoryRecordRows.sol";

import {
    StreamArtistRecoveredMultipleAttestationCodec as Codec
} from "./StreamArtistRecoveredMultipleAttestationCodec.sol";
import {
    StreamArtistRecoveredMultipleAttestationClocks as Clocks
} from "./StreamArtistRecoveredMultipleAttestationClocks.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as OwnerPayload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice One guarded owner4 apply; all collections and credential heads are checked before writes.
library StreamArtistRecoveredMultipleAttestationImport {
    function applyState(AS.State storage s, AH.Query memory anchor, bytes memory outer)
        public
        returns (bool)
    {
        if (!Codec.selected(outer, 4)) return false;
        (M.State memory scope, OwnerPayload.Payload memory payload) = Codec.outer(4, anchor, outer);
        (, bytes memory auxiliary) =
            Codec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        Original.Bundle[] memory all = Validation.validate(scope, payload.provenance);
        Clocks.validateLocal(scope, payload.provenance, Clocks.decode(auxiliary));
        for (uint256 k; k < all.length; ++k) {
            _empty(s, all[k]);
        }
        for (uint256 k; k < all.length; ++k) {
            s.attributions[all[k].collectionId] = all[k].item;
        }
        uint256[] memory cursors = new uint256[](all.length);
        uint256[] memory personhood = new uint256[](all.length);
        C2PA.Head[] memory heads = new C2PA.Head[](scope.artists.length);
        T.AttestationRecord[] memory personhoodHeads = new T.AttestationRecord[](all.length);
        for (uint256 i; i < payload.provenance.journal.length; ++i) {
            RH.JournalEntry memory entry = payload.provenance.journal[i];
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(scope, entry.receipt.artistId);
            Original.Bundle memory b = all[k];
            PubH.Row memory row = b.records[cursors[k]++];
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
                _origin(payload.provenance, entry.position.point.environmentHash).registry;
            Credentials.note(
                registry, b.artistId, b.bindingHash, r.input.terms, r.record, r.statement, false
            );
            if (_personhood(r.input.terms)) {
                Original.PersonhoodRow memory expected = b.personhood[personhood[k]++];
                if (
                    Summary.origin(hash) != registry || Summary.hashOf(hash) != expected.summaryHash
                        || keccak256(abi.encode(Summary.get(hash)))
                            != keccak256(abi.encode(expected.summary))
                ) _invalid();
                personhoodHeads[k] = r.record;
            } else if (Summary.origin(hash) != address(0)) {
                _invalid();
            }
            C2PA.Head memory expectedCredential;
            if (_credential(r.input.terms)) {
                heads[a] = _nextHead(heads[a], b, r, registry);
                expectedCredential = heads[a];
            }
            if (
                keccak256(abi.encode(Credentials.state().records[hash]))
                    != keccak256(abi.encode(expectedCredential))
            ) _invalid();
        }
        for (uint256 a; a < scope.artists.length; ++a) {
            if (
                keccak256(abi.encode(Credentials.head(scope.artists[a].artistId)))
                    != keccak256(abi.encode(heads[a]))
            ) _invalid();
        }
        for (uint256 k; k < all.length; ++k) {
            if (
                Credentials.personhoodKey(all[k].collectionId, all[k].artistId)
                    != personhoodHeads[k].recordHash
            ) _invalid();
        }
        return true;
    }

    function _empty(AS.State storage s, Original.Bundle memory b) private view {
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
