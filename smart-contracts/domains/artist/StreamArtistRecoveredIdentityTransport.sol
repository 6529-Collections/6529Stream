// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as API
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredTimingInventory as TimingAPI
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistOwnerHydration as Original } from "./StreamArtistOwnerHydration.sol";
import { StreamArtistRecoveredOwnerReads as Reads } from "./StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "./StreamArtistRecoveredIdentityHydrationExportRows.sol";
import {
    StreamArtistRecoveredIdentitySourceValidation as Validation
} from "./StreamArtistRecoveredIdentitySourceValidation.sol";
import {
    StreamArtistRecoveredIdentitySourceTuple as Tuple
} from "./StreamArtistRecoveredIdentitySourceTuple.sol";
import {
    StreamArtistRecoveredIdentityTransportImport as Import
} from "./StreamArtistRecoveredIdentityTransportImport.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

/// @notice Fixed typed ABI transport over seventeen declared Identity storage roots.
/// @dev The external host never accepts roots or arbitrary storage selectors from a caller.
library StreamArtistRecoveredIdentityTransport {
    // Preserve the original public error surface after moving the check to the fixed worker.
    error InvalidRecoveredHydrationProvenance();

    function read(uint256[17] memory roots, Identity.OwnerContext memory owner, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == Raw.recoveredIdentityHydrationActionArtist.selector) {
            return abi.encode(Export.actionArtist(roots, abi.decode(data[4:], (bytes32))));
        }
        if (selector == TimingAPI.recoveredTimingCheckpoint.selector) {
            return abi.encode(Export.timingCheckpoint(roots));
        }
        if (selector == TimingAPI.recoveredTimingEntryAt.selector) {
            return abi.encode(Timing.entryAt(abi.decode(data[4:], (uint256))));
        }
        if (selector == API.recoveredHydrationAuxiliaryPoint.selector) {
            (bytes32 kind, bytes32 key) = abi.decode(data[4:], (bytes32, bytes32));
            RH.OriginEnvironment memory current = Reads.environment(
                Original.Binding(
                    owner.environment.registry, owner.coordinator, owner.archive, owner.domain
                ),
                2
            );
            return abi.encode(Export.auxiliaryPoint(roots, kind, key, RH.originHash(current)));
        }
        if (
            selector != Raw.recoveredIdentityHydrationRaw.selector
                && selector != API.recoveredAuthorityHydrationState.selector
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        (AH.Query memory query, RH.OwnerProvenance memory local) =
            abi.decode(data[4:], (AH.Query, RH.OwnerProvenance));
        bytes memory bundle = Export.exportEncoded(roots, query, local);
        if (selector == Raw.recoveredIdentityHydrationRaw.selector) return bundle;
        Validation.validateEncoded(bundle, local);
        // Export produced a complete canonical single-Bundle encoding. Only the outer
        // envelope changes; every nested offset retains its original typed meaning.
        return abi.encode(bytes.concat(abi.encode(IH.SCHEMA, uint256(64)), Tuple.body(bundle)));
    }

    function importEncoded(uint256[17] memory roots, bytes calldata encoded) public {
        Import.importEncoded(roots, encoded);
    }
}
