// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleAuthority.sol";

/// @notice Existing signed sale lanes support only an explicitly elected NONE scope.
/// @dev Call at admission and after callbacks, never on accrued auction or refund exits.
library StreamLegacySaleConsent {
    error LegacySaleConsentRequired(uint256 collectionId);
    error LegacySaleConsentReadFailed(address facade, uint256 collectionId);

    function requireNone(
        IStreamArtistAttribution registry,
        bytes32 admittedCodeHash,
        uint256 collectionId,
        address suppliedArtist
    ) internal view {
        StreamSaleArtist.requireArtist(registry, admittedCodeHash, collectionId, suppliedArtist);
        address facade = address(registry);
        bytes memory data =
            abi.encodeCall(IStreamArtistSaleAuthority.saleConsentScope, (collectionId));
        uint256 scope;
        uint256 size;
        bool ok;
        // The admitted current facade uses available gas, as does existing artist admission.
        // A fixed output buffer avoids copying unbounded returndata or revert payloads.
        assembly ("memory-safe") {
            let output := mload(0x40)
            ok := staticcall(gas(), facade, add(data, 32), mload(data), output, 32)
            size := returndatasize()
            scope := mload(output)
        }
        if (!ok || size != 32 || scope > 1) {
            revert LegacySaleConsentReadFailed(facade, collectionId);
        }
        if (scope == 1) revert LegacySaleConsentRequired(collectionId);
    }
}
