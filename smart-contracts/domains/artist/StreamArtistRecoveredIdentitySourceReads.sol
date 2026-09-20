// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";

library StreamArtistRecoveredIdentitySourceReads {
    function validate(address source, IH.Bundle calldata bundle, AH.Query calldata query)
        public
        view
    {
        if (
            bundle.artistId != query.artistId || bundle.signatures.length != query.records.length
                || keccak256(abi.encode(bundle.sourceSnapshot))
                    != keccak256(
                        abi.encode(IStreamArtistIdentityOwner(source).ownerStateSnapshotV2())
                    )
        ) {
            revert IH.InvalidRecoveredIdentity(query.artistId);
        }
        for (uint256 i; i < query.records.length; ++i) {
            if (bundle.signatures[i].recordHash != query.records[i]) {
                revert IH.InvalidRecoveredIdentity(query.records[i]);
            }
        }
    }
}
