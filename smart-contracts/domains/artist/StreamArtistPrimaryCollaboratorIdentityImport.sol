// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Aggregate
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorIdentityCodec as Codec
} from "./StreamArtistPrimaryCollaboratorIdentityCodec.sol";
import {
    StreamArtistPrimaryCollaboratorNonceUnion as Union
} from "./StreamArtistPrimaryCollaboratorNonceUnion.sol";
import {
    StreamArtistPrimaryCollaboratorNonceImport as Nonces
} from "./StreamArtistPrimaryCollaboratorNonceImport.sol";
import {
    StreamArtistRecoveredMultipleIdentityPrincipal as Principal
} from "./StreamArtistRecoveredMultipleIdentityPrincipal.sol";
import {
    StreamArtistRecoveredIdentityImportRecords as Records
} from "./StreamArtistRecoveredIdentityImportRecords.sol";
import {
    StreamArtistRecoveredIdentityImportAuthority as Authority
} from "./StreamArtistRecoveredIdentityImportAuthority.sol";
import {
    StreamArtistRecoveredIdentityImportRecovery as Recovery
} from "./StreamArtistRecoveredIdentityImportRecovery.sol";
import {
    StreamArtistRecoveredIdentityImportContinuations as Continuations
} from "./StreamArtistRecoveredIdentityImportContinuations.sol";
import {
    StreamArtistRecoveredIdentityImportTiming as Timing
} from "./StreamArtistRecoveredIdentityImportTiming.sol";
import { StreamArtistHydrationGuards as Guards } from "./StreamArtistHydrationGuards.sol";
import { StreamArtistHistoryState as History } from "./StreamArtistHistoryState.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorDecode as Decode
} from "./StreamArtistPrimaryCollaboratorDecode.sol";

/// @notice One global nonce/timing import, then each complete recovered principal and every lane.
library StreamArtistPrimaryCollaboratorIdentityImport {
    function importState(
        uint256[17] memory roots,
        AH.Query memory anchor,
        bytes memory raw,
        bytes32 value
    ) public {
        (M.State memory s, Payload.Payload memory p, PC.Proof memory proof) =
            Decode.collect(2, anchor, raw);
        if (Guards.commitment() != value) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < s.rows.length; ++i) {
            s.rows[i] = Codec.decode(s.rows[i], p.provenance);
            Principal.check(roots, s.artists[i].artistId, s.rows[i]);
        }
        // ordered checks all principal identities, shared timing/registration and the exact
        // disjoint nonce union before any semantic map is installed.
        Nonces.install(roots, Union.ordered(s, p.nonces, proof.accounts));
        Timing.install(roots, s.rows[0]);
        Principal.registration(roots, s.artists.length);
        for (uint256 i; i < s.rows.length; ++i) {
            Records.install(roots, s.rows[i]);
            Authority.install(roots, s.rows[i]);
            Recovery.install(roots, s.rows[i]);
            Continuations.install(roots, s.rows[i]);
            Principal.finish(roots, s.rows[i], p.provenance);
        }
        // The original principal worker covers original op1 registration. This profile
        // additionally retains the authentic original op6 artifact point, without a new
        // native receipt or a point in the successor environment.
        for (uint256 i; i < p.provenance.journal.length; ++i) {
            RH.JournalEntry memory row = p.provenance.journal[i];
            if (row.receipt.operation == 6) {
                ProvenanceState.installArtifact(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), uint16(6)
                        )
                    ),
                    row.receipt.recordHash,
                    row.position.point
                );
            }
        }
        bytes32[] memory artists = new bytes32[](s.artists.length);
        uint256[] memory collections = new uint256[](s.collections.length);
        for (uint256 i; i < artists.length; ++i) {
            artists[i] = s.artists[i].artistId;
        }
        for (uint256 i; i < collections.length; ++i) {
            collections[i] = s.collections[i].collectionId;
        }
        History.activateMultiple(artists, collections, value);
    }
}
