// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Explicit current authority facts, never a substituted historical Binding.
library StreamArtistCurrentAuthorityFacts {
    function read(address identityOwner, bytes32 artistId, bool defensive)
        internal
        view
        returns (R.AuthorityFact memory a)
    {
        a.artistId = artistId;
        (a.authorityAddress, a.authorityClass, a.status,) =
            IStreamArtistIdentityOwner(identityOwner).authorityState(artistId);
        if (
            a.authorityAddress == address(0) || a.authorityClass != 1
                || (a.status != 1 && !(defensive && a.status == 4))
        ) revert T.InvalidIdentity(artistId);
    }

    function requireAccepted(
        T.Binding memory b,
        address signer,
        R.AuthorityFact memory a,
        bool defensive
    ) internal pure {
        if (!b.accepted || b.consentMode != 1 || b.artistId == bytes32(0)) revert T.InvalidRecord();
        requirePrincipal(b.artistId, signer, a, defensive);
    }

    function requirePrincipal(
        bytes32 artistId,
        address signer,
        R.AuthorityFact memory a,
        bool defensive
    ) internal pure {
        if (
            artistId == bytes32(0) || a.artistId != artistId || signer == address(0)
                || a.authorityAddress != signer || a.authorityClass != 1
                || (a.status != 1 && !(defensive && a.status == 4))
        ) revert T.InvalidRecord();
    }
}
