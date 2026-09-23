// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredMultipleCollectionImport as MultipleImport } from "./StreamArtistRecoveredMultipleCollectionImport.sol";
import { StreamArtistRecoveredRevokedAttribution as RecoveredRevoked } from "./StreamArtistRecoveredRevokedAttribution.sol";
import {
    StreamArtistRecoveredCollectionHydration
} from "./StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistRecoveredAttestationHydration
} from "./StreamArtistRecoveredAttestationHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as I
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Decode the original op60 transport after the owner's original tag/revision/nonce guards.
/// @dev Original owner guard application, complete provenance import, commit and Archive remain unchanged.
library StreamArtistAttributionRecoveredImport {
    function importEncoded(AS.State storage s, bytes calldata data) public {
        if (bytes4(data[:4]) != I.applyArtistAuthorityHydration.selector) revert T.InvalidRecord();
        (, AH.Query memory q, AH.OwnerData memory p,) =
            abi.decode(data[4:], (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (MultipleImport.attribution(s, q, p.typedState)) return;
        if (RecoveredRevoked.importIfSelected(s, q, p.typedState)) return;
        if (StreamArtistRecoveredAttestationHydration.selected(p.typedState)) {
            StreamArtistRecoveredAttestationHydration.importState(s, q, p.typedState);
            return;
        }
        StreamArtistRecoveredCollectionHydration.importAttribution(s, q, p.typedState);
    }
}
