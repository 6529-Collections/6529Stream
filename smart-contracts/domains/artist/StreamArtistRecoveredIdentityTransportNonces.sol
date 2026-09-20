// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import { StreamArtistHydrationGuards as Guards } from "./StreamArtistHydrationGuards.sol";

/// @notice Original complete nonce and commitment checks in the destination owner's context.
library StreamArtistRecoveredIdentityTransportNonces {
    /// @dev Transport passes only the complete canonical result of SourceCodec.decode.
    /// This linked view call retains owner storage; Guards must never run by STATICCALL.
    function validate(bytes calldata canonical, RH.NonceInventory[] calldata nonces, bytes32 value)
        public
        view
    {
        IH.Bundle calldata bundle = Frame.bundle(canonical);
        if (bundle.nonces.length != nonces.length || Guards.commitment() != value) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint256 i; i < bundle.nonces.length; ++i) {
            if (
                bundle.nonces[i].kind != nonces[i].index.kind
                    || bundle.nonces[i].key != nonces[i].index.key
                    || keccak256(abi.encode(bundle.nonces[i].words))
                        != keccak256(abi.encode(nonces[i].words))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
    }
}
