// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import {
    StreamArtistRecoveredDelegationHydration as Delegations
} from "./StreamArtistRecoveredDelegationHydration.sol";

import {
    StreamArtistRecoveredIdentitySourceNative as Native
} from "./StreamArtistRecoveredIdentitySourceNative.sol";
import {
    StreamArtistRecoveredIdentitySourceCauses as Causes
} from "./StreamArtistRecoveredIdentitySourceCauses.sol";
import {
    StreamArtistRecoveredIdentitySourceVestings as Vestings
} from "./StreamArtistRecoveredIdentitySourceVestings.sol";
import {
    StreamArtistRecoveredIdentitySourceGuardians as Guardians
} from "./StreamArtistRecoveredIdentitySourceGuardians.sol";
import {
    StreamArtistRecoveredIdentitySourceActions as Actions
} from "./StreamArtistRecoveredIdentitySourceActions.sol";
import {
    StreamArtistRecoveredIdentitySourceClosures as Closures
} from "./StreamArtistRecoveredIdentitySourceClosures.sol";
import {
    StreamArtistRecoveredIdentitySourceDocuments as Documents
} from "./StreamArtistRecoveredIdentitySourceDocuments.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original complete Identity validation order.
library StreamArtistRecoveredIdentitySourceValidation {
    /// @dev Called only after complete canonical transport validation by the source codec.
    function validateEncoded(bytes calldata raw, RH.OwnerProvenance calldata p)
        public
        pure
        returns (bytes32)
    {
        return validate(Frame.bundle(raw), p);
    }

    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p)
        public
        pure
        returns (bytes32)
    {
        Provenance.validateOwner(p, 2);
        if (
            b.artistId == 0 || b.identity.authorityAddress == address(0)
                || (b.identity.authorityClass != 1 && b.identity.authorityClass != 3)
                || b.identity.status == 0 || b.recoveries.length == 0
                || keccak256(abi.encode(b.sourceSnapshot))
                    != keccak256(abi.encode(p.eras[p.eras.length - 1].checkpoint.ownerState))
        ) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        Timing.validate(b.timing);
        Native.validate(b, p);
        Delegations.validate(b, p);
        Causes.validate(b, p);
        Vestings.validate(b, p);
        Guardians.validate(b, p);
        Actions.validate(b, p);
        Closures.validate(b);
        Documents.validate(b);
        return keccak256(abi.encode(IH.SCHEMA, b));
    }
}
