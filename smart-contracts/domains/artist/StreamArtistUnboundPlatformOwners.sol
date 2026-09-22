// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";

import {
    StreamArtistRecoveredMultipleIdentityNonces as Nonces
} from "./StreamArtistRecoveredMultipleIdentityNonces.sol";
import { StreamArtistUnboundPlatformCodec as Codec } from "./StreamArtistUnboundPlatformCodec.sol";
import {
    StreamArtistUnboundPlatformCollectionSource as Collections
} from "./StreamArtistUnboundPlatformCollectionSource.sol";

import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationCodec as OuterCodec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredPreparationSeal as Seal
} from "./StreamArtistRecoveredPreparationSeal.sol";

import {
    StreamArtistUnboundPlatformEmptyIdentity as Empty
} from "./StreamArtistUnboundPlatformEmptyIdentity.sol";
import {
    StreamArtistUnboundPlatformCollectionRows as Rows
} from "./StreamArtistUnboundPlatformCollectionRows.sol";

/// @notice One complete global payload per owner after the unchanged aggregate source prelude.
library StreamArtistUnboundPlatformOwners {
    struct Context {
        Commit.Prepared prepared;
        T.SuiteConfiguration destination;
        RH.Capability[7] expected;
        AH.Origin[][7] replayOrigins;
        bytes[] identities;
        bytes[] payouts;
        uint256 features;
    }

    /// @dev Keeps owner results and the final seal in one fixed typed frame.
    function encode(Context memory x, bool requireInventory, bytes32 expectedInventory)
        public
        view
        returns (bytes memory)
    {
        Admission.Certificate memory c = x.prepared.admission;
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        for (uint8 i; i < 7; ++i) {
            _capabilities(c.source.owners[i], x.destination.owners[i], i, x.features, x.expected[i]);
            Payload.Payload memory payload;
            payload.provenance = RH.ownerProvenance(c.provenance, i);
            payload.publications = Publications.collect(c.source.owners[i], i);
            (x.prepared.data[i], payload.nonces) =
                Guards.collect(c.provenance, i, x.replayOrigins[i]);
            if (i == 2) {
                scope.rows = x.identities;
                if (scope.artists.length == 0) {
                    Empty.validate(
                        payload.provenance, payload.nonces, scope.collections, scope.rows[0]
                    );
                } else {
                    Nonces.ordered(scope, payload.nonces);
                }
            } else if (i == 5) {
                scope.rows = x.payouts;
                if (scope.artists.length == 0) Rows.empty(payload.provenance, 5);
            } else {
                scope.rows = Collections.collect(c.source, i, scope, c.provenance);
            }
            payload.semanticState = Codec.encode(i, scope, payload.provenance);
            RH.OwnerEra memory last = payload.provenance.eras[payload.provenance.eras.length - 1];
            RH.ExportHeader memory h = RH.ExportHeader(
                RH.PROFILE,
                RH.VERSION,
                i,
                last.originHash,
                last.priorImportCommitment,
                keccak256(payload.semanticState),
                RH.ownerProvenanceHash(payload.provenance, i),
                RH.aliasesHash(i, payload.provenance.aliases),
                x.features,
                payload.provenance.journal.length,
                payload.provenance.aliases.length,
                payload.provenance.eras.length
            );
            x.prepared.data[i].typedState = Payload.encode(i, h, payload);
        }
        return Seal.encode(x.prepared, requireInventory, expectedInventory);
    }

    function _capabilities(
        address source,
        address destination,
        uint8 i,
        uint256 features,
        RH.Capability memory expected
    ) private view {
        RH.Capability memory actual = Owner(source).recoveredAuthorityHydrationCapability();
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        OuterCodec.requireCapability(actual, i, features);
        OuterCodec.requireCapability(
            Owner(destination).recoveredAuthorityHydrationCapability(), i, features
        );
    }
}
