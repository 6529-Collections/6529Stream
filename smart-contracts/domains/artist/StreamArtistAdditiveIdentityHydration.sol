// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDelegationIdentityHydration.sol";
import "./StreamArtistMultipleIdentityHydration.sol";
import "./StreamArtistHistoryState.sol";
import "./StreamArtistHydrationGuards.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";

/// @notice Fixed transport for the two additive original-living profiles only.
library StreamArtistAdditiveIdentityHydration {
    function exportEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        if (
            bytes4(encoded[:4])
                == IStreamArtistDelegationHydrationOwner.authorityDelegationHydrationState.selector
        ) {
            return StreamArtistDelegationIdentityHydration.exportEncoded(
                identity, grants, revisions, estate, dormancy, findings, encoded[4:]
            );
        }
        if (
            bytes4(encoded[:4])
                != IStreamArtistMultipleHydrationIdentity.authorityLivingIdentityHydrationState
                .selector
        ) revert T.UnsupportedProfile();
        return StreamArtistMultipleIdentityHydration.exportEncoded(
            identity, estate, dormancy, findings, encoded[4:]
        );
    }

    function importEncoded(
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage grants,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistUnavailabilityState.State storage findings,
        bytes calldata encoded
    ) public {
        (, AH.Query memory q, AH.OwnerData memory data,) =
            abi.decode(encoded, (T.ActionContext, AH.Query, AH.OwnerData, bytes32));
        if (StreamArtistDelegationHydrationCodec.tagged(data.typedState, DH.IDENTITY)) {
            StreamArtistDelegationIdentityHydration.importEncoded(
                identity, grants, revisions, estate, dormancy, findings, encoded
            );
            StreamArtistHistoryState.activate(
                q.artistId, q.collectionId, StreamArtistHydrationGuards.commitment()
            );
            return;
        }
        if (StreamArtistMultipleHydrationCodec.isState(data.typedState)) {
            StreamArtistMultipleIdentityHydration.importEncoded(
                identity, estate, dormancy, findings, encoded
            );
            return;
        }
        StreamArtistIdentityHydration.importEncoded(identity, estate, dormancy, findings, encoded);
        StreamArtistHistoryState.activate(
            q.artistId, q.collectionId, StreamArtistHydrationGuards.commitment()
        );
    }
}
