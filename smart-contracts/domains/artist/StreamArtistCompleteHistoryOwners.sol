// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
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
    StreamArtistPrimaryCollaboratorNonceUnion as Nonces
} from "./StreamArtistPrimaryCollaboratorNonceUnion.sol";
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

/// @notice Original seven owner envelopes with the complete shared history inventory.
/// @dev The fixed preparation stage proves every family before calling this encoder. It does
/// not advertise the reserved feature, authorize import, or replace any original owner guard.
library StreamArtistCompleteHistoryOwners {
    struct Context {
        Commit.Prepared prepared;
        T.SuiteConfiguration destination;
        RH.Capability[7] expected;
        AH.Origin[][7] replayOrigins;
        CT.Principals principals;
        bytes[] bindings;
        bytes[] attribution;
        bytes[] accepted;
        bytes[] consents;
        CT.Inventory inventory;
        uint256 features;
    }

    function encode(Context memory x, bool requireInventory, bytes32 expectedInventory)
        public
        view
        returns (bytes memory)
    {
        Admission.Certificate memory c = x.prepared.admission;
        _principals(x, c.artists.length);
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        bytes memory auxiliary = abi.encode(x.inventory);
        for (uint8 i; i < 7; ++i) {
            _capabilities(c.source.owners[i], x.destination.owners[i], i, x.features, x.expected[i]);
            Payload.Payload memory payload;
            payload.provenance = RH.ownerProvenance(c.provenance, i);
            payload.publications = Publications.collect(c.source.owners[i], i);
            (x.prepared.data[i], payload.nonces) =
                Guards.collect(c.provenance, i, x.replayOrigins[i]);
            if (i == 2) {
                scope.rows = x.principals.identities;
                // Canonical raw Identity bundles and actual account lanes must partition the
                // exact original global nonce inventory, including the empty-principal case.
                Nonces.ordered(scope, payload.nonces, x.inventory.accounts);
            } else if (i == 5) {
                scope.rows = x.principals.payouts;
            } else if (i == 0) {
                scope.rows = x.bindings;
            } else if (i == 4) {
                scope.rows = x.attribution;
            } else if (i == 3) {
                scope.rows = x.accepted;
            } else if (i == 6) {
                scope.rows = x.consents;
            } else {
                scope.rows = new bytes[](0);
            }
            // Retain the complete scope even for owner4. Its original native records are
            // part of this exact semantic hash, together with all family rows and inventory.
            payload.semanticState = Codec.encode(i, scope, payload.provenance, auxiliary);
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

    function _principals(Context memory x, uint256 count) private pure {
        if (
            (x.features & CT.FEATURE) == 0 || x.principals.identities.length != count
                || x.principals.payouts.length != count
                || x.principals.authoritySupplement.length != count
        ) revert RH.InvalidRecoveredHydrationProfile();
        // Raw canonical class1/3 rows are the current fixed source format. A future authority
        // wrapper must be explicitly integrated; unsupported supplements cannot be dropped.
        for (uint256 i; i < count; ++i) {
            if (x.principals.authoritySupplement[i].length != 0) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
        }
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
