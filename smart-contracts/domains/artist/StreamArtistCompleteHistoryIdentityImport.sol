// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryDecode as Decode
} from "./StreamArtistCompleteHistoryDecode.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
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
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";
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
    StreamArtistUnboundPlatformActivation as EmptyActivation
} from "./StreamArtistUnboundPlatformActivation.sol";
import {
    StreamArtistUnboundPlatformEmptyIdentity as EmptyIdentity
} from "./StreamArtistUnboundPlatformEmptyIdentity.sol";

/// @notice Original canonical Identity maps, global nonce union and verified history lanes.
/// @dev No additional native receipt, provenance commit or principal is created by this worker.
library StreamArtistCompleteHistoryIdentityImport {
    function importState(
        uint256[17] memory roots,
        AH.Query memory anchor,
        bytes memory raw,
        bytes32 value
    ) public {
        (M.State memory s, Payload.Payload memory p, CT.Inventory memory inventory,) =
            Decode.collect(2, anchor, raw);
        if (Guards.commitment() != value) revert RH.InvalidRecoveredHydrationProvenance();
        if (s.rows.length != s.artists.length) revert RH.InvalidRecoveredHydrationProfile();
        if (s.artists.length != 0) {
            for (uint256 i; i < s.rows.length; ++i) {
                s.rows[i] = Codec.decode(s.rows[i], p.provenance);
                Principal.check(roots, s.artists[i].artistId, s.rows[i]);
            }
            // Every principal destination is checked before the shared nonce/timing maps.
            // ordered proves all identities and the exact disjoint original nonce union.
            Nonces.install(roots, Union.ordered(s, p.nonces, inventory.accounts));
            Timing.install(roots, s.rows[0]);
            Principal.registration(roots, s.artists.length);
            for (uint256 i; i < s.rows.length; ++i) {
                Records.install(roots, s.rows[i]);
                Authority.install(roots, s.rows[i]);
                Recovery.install(roots, s.rows[i]);
                Continuations.install(roots, s.rows[i]);
                Principal.finish(roots, s.rows[i], p.provenance);
            }
            // Principal.finish preserves the original op1 points. Collaborator-created
            // registrations additionally retain their actual original op6 artifact point.
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
        } else {
            // Zero rows mean a genuinely empty principal set. Recollect the fixed original
            // certificate instead of placing it in a fabricated zero-Artist bundle slot.
            address source = p.provenance.origins[p.provenance.origins.length - 1].owners[2];
            (bytes memory empty,) = EmptyIdentity.collect(source, p.provenance, s.collections);
            EmptyIdentity.install(roots, p.provenance, p.nonces, s.collections, empty);
            Principal.registration(roots, 0);
        }
        bytes32[] memory artists = new bytes32[](s.artists.length);
        uint256[] memory collections = new uint256[](s.collections.length);
        for (uint256 i; i < artists.length; ++i) {
            artists[i] = s.artists[i].artistId;
        }
        for (uint256 i; i < collections.length; ++i) {
            collections[i] = s.collections[i].collectionId;
        }
        if (artists.length == 0) {
            // This shared lane helper preserves the original collection-only commitment
            // domain. It selects no profile; Decode already required the explicit CT envelope.
            EmptyActivation.activateMultiple(artists, collections, value);
        } else {
            History.activateMultiple(artists, collections, value);
        }
    }
}
