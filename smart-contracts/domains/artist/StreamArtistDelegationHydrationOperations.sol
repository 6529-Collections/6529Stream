// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDelegationHydrationFacts.sol";

library StreamArtistDelegationHydrationOperations {
    function hydrate(D.CoordinatorContext memory x, address actor, AH.Request memory p)
        public
        returns (bytes32)
    {
        StreamArtistHydrationPrepared.Bundle memory h =
            StreamArtistDelegationHydrationSource.prepare(x, p);
        StreamArtistDelegationHydrationFacts.check(h, p);
        return StreamArtistHydrationCommit.execute(x, actor, p, h);
    }
}
