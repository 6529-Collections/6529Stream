// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAttributionOwner
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistC2PACredentials as Credentials } from "./StreamArtistC2PACredentials.sol";
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
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Per-record and final source heads follow the original global Artist credential chain.

library StreamArtistRecoveredMultipleDisputeAttestationHeads {
    function requireMatches(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        Original.Bundle[] memory all,
        G.Inventory memory inventory
    ) public view {
        C2PA.Head[] memory heads = new C2PA.Head[](scope.artists.length);
        T.AttestationRecord[] memory personhoodHeads = new T.AttestationRecord[](all.length);
        uint256[] memory cursors = new uint256[](all.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (MD.nativeDispute(entry.receipt.operation)) continue;
            uint256 k = Scope.collection(scope, entry.receipt.collectionId);
            uint256 a = Scope.artist(scope, entry.receipt.artistId);
            uint256 cursor = cursors[k]++;
            ReadinessH.AttestationRow memory r = all[k].records[cursor].attestation;
            C2PA.Head memory expected;
            if (_credential(r.input.terms)) {
                heads[a] = _nextHead(
                    heads[a],
                    all[k],
                    r,
                    _origin(p, entry.position.point.environmentHash).registry,
                    inventory.bindings[k].bindings.rows[r.record.generation - 1].item.bindingHash
                );
                expected = heads[a];
            }
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(source).c2paCredentialRecord(r.record.recordHash)
                        )
                    ) != keccak256(abi.encode(expected))
            ) _invalid();
            if (_personhood(r.input.terms)) personhoodHeads[k] = r.record;
            bool last = true;
            for (uint256 j = cursor + 1; j < all[k].records.length; ++j) {
                if (_key(all[k].records[j].attestation.input.terms) == _key(r.input.terms)) {
                    last = false;
                }
            }
            if (
                last
                    && keccak256(
                            abi.encode(
                                IStreamArtistAttributionOwner(source)
                                    .attestation(
                                        all[k].collectionId,
                                        r.input.terms.subjectKind,
                                        r.input.terms.subjectId
                                    )
                            )
                        ) != keccak256(abi.encode(r.record))
            ) _invalid();
        }
        for (uint256 a; a < scope.artists.length; ++a) {
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(source)
                                .c2paCredentialHead(scope.artists[a].artistId)
                        )
                    ) != keccak256(abi.encode(heads[a]))
            ) _invalid();
        }
        for (uint256 k; k < all.length; ++k) {
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(source)
                                .personhoodAttestation(all[k].collectionId, all[k].artistId)
                        )
                    ) != keccak256(abi.encode(personhoodHeads[k]))
            ) _invalid();
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
