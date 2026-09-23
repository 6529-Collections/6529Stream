// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistRecoveredMultipleCodec as Aggregate
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleIdentityCodec as Codec
} from "./StreamArtistRecoveredMultipleIdentityCodec.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonces as Union
} from "./StreamArtistRecoveredMultipleIdentityNonces.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonceImport as Nonces
} from "./StreamArtistRecoveredMultipleIdentityNonceImport.sol";
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

/// @notice One global nonce/timing import, then each complete recovered principal and every lane.
library StreamArtistRecoveredMultipleIdentityImport {
    function importState(
        uint256[17] memory roots,
        AH.Query memory anchor,
        bytes memory raw,
        bytes32 value
    ) public {
        (M.State memory s, Payload.Payload memory p) = Aggregate.outer(2, anchor, raw);
        if (Guards.commitment() != value) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < s.rows.length; ++i) {
            s.rows[i] = Codec.decode(s.rows[i], p.provenance);
            Principal.check(roots, s.artists[i].artistId, s.rows[i]);
        }
        // ordered checks all principal identities, shared timing/registration and the exact
        // disjoint nonce union before any semantic map is installed.
        Nonces.install(roots, Union.ordered(s, p.nonces));
        Timing.install(roots, s.rows[0]);
        Principal.registration(roots, s.artists.length);
        for (uint256 i; i < s.rows.length; ++i) {
            Records.install(roots, s.rows[i]);
            Authority.install(roots, s.rows[i]);
            Recovery.install(roots, s.rows[i]);
            Continuations.install(roots, s.rows[i]);
            Principal.finish(roots, s.rows[i], p.provenance);
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
