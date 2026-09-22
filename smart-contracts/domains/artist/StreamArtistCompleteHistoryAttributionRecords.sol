// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistRecordPublicationOwner as PublicationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistPersonhoodTypes as Personhood
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistC2PATypes as C2PA
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
import { StreamArtistPersonhoodSummary as Summary } from "./StreamArtistPersonhoodSummary.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryAttestationQueries as Queries
} from "./StreamArtistCompleteHistoryAttestationQueries.sol";

/// @notice Original all-target checks and complete ordered owner4 record installation.
/// @dev Uses the original owner storage reference and fixed delegate context. The
/// caller first proves the family rows and checks every Platform and dispute target before
/// installing any family. Original historical Artists, generations and global order are retained.

library StreamArtistCompleteHistoryAttributionRecords {
    struct Context {
        M.State scope;
        CT.Inventory inventory;
        Original.Bundle[] all;
    }

    function check(AS.State storage s, Context memory c) public view {
        if (
            c.all.length != c.scope.collections.length
                || c.inventory.bindings.bindings.length != c.all.length
        ) _invalid();
        C2PA.Head memory emptyHead;
        for (uint256 a; a < c.scope.artists.length; ++a) {
            bytes32 artist = c.scope.artists[a].artistId;
            if (
                Credentials.state().latest[artist] != 0
                    || keccak256(abi.encode(Credentials.head(artist)))
                        != keccak256(abi.encode(emptyHead))
            ) _invalid();
        }
        for (uint256 k; k < c.all.length; ++k) {
            if (c.all[k].collectionId != c.scope.collections[k].collectionId) _invalid();
            _empty(s, c.all[k]);
            for (uint256 g; g < c.inventory.bindings.bindings[k].bindings.rows.length; ++g) {
                bytes32 artist = c.inventory.bindings.bindings[k].bindings.rows[g].item.artistId;
                if (Credentials.personhoodKey(c.all[k].collectionId, artist) != 0) _invalid();
            }
        }
    }

    function install(AS.State storage s, Context memory c) public {
        for (uint256 k; k < c.all.length; ++k) {
            s.attributions[c.all[k].collectionId] = c.all[k].item;
        }
        uint256[] memory cursors = new uint256[](c.all.length);
        uint256[] memory personhood = new uint256[](c.all.length);
        C2PA.Head[] memory heads = new C2PA.Head[](c.scope.artists.length);
        bytes32[][] memory personhoodHeads = new bytes32[][](c.all.length);
        for (uint256 k; k < c.all.length; ++k) {
            personhoodHeads[k] = new bytes32[](c.scope.artists.length);
        }
        RH.OwnerProvenance memory provenance = RH.ownerProvenance(c.inventory.provenance, 4);
        for (uint256 i; i < provenance.journal.length; ++i) {
            RH.JournalEntry memory entry = provenance.journal[i];
            if (Queries.other(entry.receipt)) continue;
            if (entry.receipt.operation != 24) _invalid();
            uint256 k = Scope.collection(c.scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(c.scope, entry.receipt.artistId);
            Original.Bundle memory b = c.all[k];
            if (cursors[k] >= b.records.length) _invalid();
            PubH.Row memory row = b.records[cursors[k]++];
            ReadinessH.AttestationRow memory r = row.attestation;
            if (
                r.record.generation == 0
                    || r.record.generation > c.inventory.bindings.bindings[k].bindings.rows.length
            ) _invalid();
            T.Binding memory binding_ =
            c.inventory.bindings.bindings[k].bindings.rows[r.record.generation - 1].item;
            if (
                binding_.artistId != entry.receipt.artistId
                    || r.record.recordHash != entry.receipt.recordHash
            ) _invalid();
            bytes32 bindingHash = binding_.bindingHash;
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
            address registry = _origin(provenance, entry.position.point.environmentHash).registry;
            Credentials.note(
                registry,
                binding_.artistId,
                bindingHash,
                r.input.terms,
                r.record,
                r.statement,
                false
            );
            if (_personhood(r.input.terms)) {
                if (personhood[k] >= b.personhood.length) _invalid();
                Original.PersonhoodRow memory expected = b.personhood[personhood[k]++];
                if (
                    Summary.origin(hash) != registry || Summary.hashOf(hash) != expected.summaryHash
                        || keccak256(abi.encode(Summary.get(hash)))
                            != keccak256(abi.encode(expected.summary))
                ) _invalid();
                personhoodHeads[k][a] = hash;
            } else if (Summary.origin(hash) != address(0)) {
                _invalid();
            }
            C2PA.Head memory expectedCredential;
            if (_credential(r.input.terms)) {
                heads[a] = _nextHead(
                    heads[a], binding_.artistId, b.collectionId, r, registry, bindingHash
                );
                expectedCredential = heads[a];
            }
            if (
                keccak256(abi.encode(Credentials.state().records[hash]))
                    != keccak256(abi.encode(expectedCredential))
            ) _invalid();
        }
        for (uint256 a; a < c.scope.artists.length; ++a) {
            if (
                keccak256(abi.encode(Credentials.head(c.scope.artists[a].artistId)))
                    != keccak256(abi.encode(heads[a]))
            ) _invalid();
        }
        for (uint256 k; k < c.all.length; ++k) {
            if (
                cursors[k] != c.all[k].records.length || personhood[k] != c.all[k].personhood.length
            ) _invalid();
            for (uint256 g; g < c.inventory.bindings.bindings[k].bindings.rows.length; ++g) {
                bytes32 artist = c.inventory.bindings.bindings[k].bindings.rows[g].item.artistId;
                uint256 a = Scope.artist(c.scope, artist);
                if (
                    Credentials.personhoodKey(c.all[k].collectionId, artist)
                        != personhoodHeads[k][a]
                ) _invalid();
            }
        }
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
        bytes32 artist,
        uint256 collectionId,
        ReadinessH.AttestationRow memory r,
        address registry,
        bytes32 bindingHash
    ) private pure returns (C2PA.Head memory) {
        C2PA.Payload memory p = Credentials.decode(
            r.statement, artist, r.input.terms.subjectStateHash
        );
        if (p.previousRecordHash != previous.recordHash) _invalid();
        return C2PA.Head(
            previous.revision + 1,
            r.record.recordHash,
            previous.recordHash,
            artist,
            collectionId,
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
