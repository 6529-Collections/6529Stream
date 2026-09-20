// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as API
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredTimingInventory as TimingAPI
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistOwnerHydration as Original } from "./StreamArtistOwnerHydration.sol";
import { StreamArtistRecoveredOwnerReads as Reads } from "./StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "./StreamArtistRecoveredIdentityHydrationExportRows.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Codec
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredIdentityHydrationImport as Import
} from "./StreamArtistRecoveredIdentityHydrationImport.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";
import { StreamArtistHydrationGuards as Guards } from "./StreamArtistHydrationGuards.sol";
import { StreamArtistHistoryState as History } from "./StreamArtistHistoryState.sol";

/// @notice Fixed typed ABI transport over seventeen declared Identity storage roots.
/// @dev The external host never accepts roots or arbitrary storage selectors from a caller.
library StreamArtistRecoveredIdentityTransport {
    function read(uint256[17] memory roots, Identity.OwnerContext memory owner, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == Raw.recoveredIdentityHydrationActionArtist.selector) {
            return abi.encode(Export.actionArtist(roots, abi.decode(data[4:], (bytes32))));
        }
        if (selector == TimingAPI.recoveredTimingCheckpoint.selector) {
            return abi.encode(Export.timingCheckpoint(roots));
        }
        if (selector == TimingAPI.recoveredTimingEntryAt.selector) {
            return abi.encode(Timing.entryAt(abi.decode(data[4:], (uint256))));
        }
        if (selector == API.recoveredHydrationAuxiliaryPoint.selector) {
            (bytes32 kind, bytes32 key) = abi.decode(data[4:], (bytes32, bytes32));
            RH.OriginEnvironment memory current = Reads.environment(
                Original.Binding(
                    owner.environment.registry, owner.coordinator, owner.archive, owner.domain
                ),
                2
            );
            return abi.encode(Export.auxiliaryPoint(roots, kind, key, RH.originHash(current)));
        }
        if (
            selector != Raw.recoveredIdentityHydrationRaw.selector
                && selector != API.recoveredAuthorityHydrationState.selector
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        (AH.Query memory query, RH.OwnerProvenance memory local) =
            abi.decode(data[4:], (AH.Query, RH.OwnerProvenance));
        IH.Bundle memory bundle = Export.exportBundle(roots, query, local);
        if (selector == Raw.recoveredIdentityHydrationRaw.selector) return abi.encode(bundle);
        return abi.encode(Codec.encode(bundle, local));
    }

    function importEncoded(uint256[17] memory roots, bytes calldata encoded) public {
        (, AH.Query memory query, AH.OwnerData memory data, bytes32 value) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        (, Payload.Payload memory payload) = Payload.decode(data.typedState, 2);
        IH.Bundle memory bundle = Codec.decode(payload.semanticState, payload.provenance);
        // This profile carries one complete recovered subject. A different subject's nonce lane
        // cannot disappear behind an otherwise valid per-subject semantic projection.
        if (bundle.nonces.length != payload.nonces.length || Guards.commitment() != value) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint256 i; i < bundle.nonces.length; ++i) {
            if (
                bundle.nonces[i].kind != payload.nonces[i].index.kind
                    || bundle.nonces[i].key != payload.nonces[i].index.key
                    || keccak256(abi.encode(bundle.nonces[i].words))
                        != keccak256(abi.encode(payload.nonces[i].words))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        Import.importEncoded(roots, query.artistId, payload.semanticState, payload.provenance);
        History.activate(query.artistId, query.collectionId, value);
    }
}
