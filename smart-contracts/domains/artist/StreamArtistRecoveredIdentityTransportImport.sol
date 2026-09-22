// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistUnboundPlatformCodec as UnboundCodec } from "./StreamArtistUnboundPlatformCodec.sol";
import { StreamArtistUnboundPlatformIdentityImport as UnboundImport } from "./StreamArtistUnboundPlatformIdentityImport.sol";
import { StreamArtistRecoveredMultipleGenerationIdentityImport as GenerationImport } from "./StreamArtistRecoveredMultipleGenerationIdentityImport.sol";
import { StreamArtistRecoveredMultipleGenerationCodec as GenerationAggregate } from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import { StreamArtistRecoveredMultipleAttestationCodec as AttestationAggregate } from "./StreamArtistRecoveredMultipleAttestationCodec.sol";
import { StreamArtistRecoveredMultipleAttestationIdentityImport as AttestationImport } from "./StreamArtistRecoveredMultipleAttestationIdentityImport.sol";
import { StreamArtistRecoveredMultipleConsentCodec as ConsentAggregate } from "./StreamArtistRecoveredMultipleConsentCodec.sol";
import { StreamArtistRecoveredMultipleConsentIdentityImport as ConsentImport } from "./StreamArtistRecoveredMultipleConsentIdentityImport.sol";
import { StreamArtistRecoveredMultipleCodec as Aggregate } from "./StreamArtistRecoveredMultipleCodec.sol";
import { StreamArtistRecoveredMultipleIdentityImport as MultipleImport } from "./StreamArtistRecoveredMultipleIdentityImport.sol";

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
        if (UnboundCodec.selected(data.typedState, 2)) {
            UnboundImport.importState(roots, query, data.typedState, value);
            return;
        }
        if (GenerationAggregate.selected(data.typedState, 2)) {
            GenerationImport.importState(roots, query, data.typedState, value);
            return;
        }
        if (AttestationAggregate.selected(data.typedState, 2)) {
            AttestationImport.importState(roots, query, data.typedState, value);
            return;
        }
        if (ConsentAggregate.selected(data.typedState, 2)) {
            ConsentImport.importState(roots, query, data.typedState, value);
            return;
        }
        if (Aggregate.selected(data.typedState, 2)) {
            MultipleImport.importState(roots, query, data.typedState, value);
            return;
        }
        (, Payload.Payload memory payload) = Payload.decode(data.typedState, 2);
        bytes memory bundle = Codec.decode(payload.semanticState, payload.provenance);
        // This profile carries one complete recovered subject. A different subject's nonce lane
        // cannot disappear behind an otherwise valid per-subject semantic projection.
        Nonces.validate(bundle, payload.nonces, value);
        Import.importEncoded(roots, query.artistId, payload.semanticState, payload.provenance);
        History.activate(query.artistId, query.collectionId, value);
    }
}
