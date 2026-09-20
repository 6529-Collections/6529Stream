// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredIdentitySourceCodec as Codec
} from "./StreamArtistRecoveredIdentitySourceCodec.sol";
import {
    StreamArtistRecoveredIdentityTransportNonces as Nonces
} from "./StreamArtistRecoveredIdentityTransportNonces.sol";
import {
    StreamArtistRecoveredIdentityHydrationImport as Import
} from "./StreamArtistRecoveredIdentityHydrationImport.sol";
import { StreamArtistHistoryState as History } from "./StreamArtistHistoryState.sol";

/// @notice Fixed linked destination transport in the original owner storage context.
library StreamArtistRecoveredIdentityTransportImport {
    function importEncoded(uint256[17] memory roots, bytes calldata encoded) public {
        (, AH.Query memory query, AH.OwnerData memory data, bytes32 value) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        (, Payload.Payload memory payload) = Payload.decode(data.typedState, 2);
        bytes memory bundle = Codec.decode(payload.semanticState, payload.provenance);
        // This profile carries one complete recovered subject. A different subject's nonce lane
        // cannot disappear behind an otherwise valid per-subject semantic projection.
        Nonces.validate(bundle, payload.nonces, value);
        Import.importEncoded(roots, query.artistId, payload.semanticState, payload.provenance);
        History.activate(query.artistId, query.collectionId, value);
    }
}
