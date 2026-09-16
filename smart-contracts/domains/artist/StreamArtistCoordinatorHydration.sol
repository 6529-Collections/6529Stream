// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityHydrationOperations.sol";
import "./StreamArtistEntropyFindingHydrationOperations.sol";

/// @notice Fixed original operation60 transport decoder; explicit host routes retain their operation lock.
library StreamArtistCoordinatorHydration {
    function execute(D.CoordinatorContext memory x, bytes calldata data, uint8 profile)
        public
        returns (bytes32)
    {
        if (profile == 1 || profile == 2) {
            (address actor, AH.Request memory p) = abi.decode(data[4:], (address, AH.Request));
            return profile == 1
                ? StreamArtistAuthorityHydrationOperations.hydrate(x, actor, p)
                : StreamArtistAuthorityHydrationOperations.hydrateWithPayout(x, actor, p);
        }
        if (profile == 3) {
            (address actor, EH.Request memory p) = abi.decode(data[4:], (address, EH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithEconomics(x, actor, p);
        }
        if (profile == 4) {
            (address actor, RH.Request memory p) = abi.decode(data[4:], (address, RH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithReadiness(x, actor, p);
        }
        if (profile == 5) {
            (address actor, RH.Request memory p) = abi.decode(data[4:], (address, RH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithPublications(x, actor, p);
        }
        if (profile == 6) {
            (address actor, FH.Request memory p) = abi.decode(data[4:], (address, FH.Request));
            return StreamArtistEntropyFindingHydrationOperations.hydrate(x, actor, p);
        }
        revert T.UnsupportedProfile();
    }
}
