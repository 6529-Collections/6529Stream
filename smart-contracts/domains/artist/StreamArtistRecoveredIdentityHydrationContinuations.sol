// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityContinuationRows as Rows
} from "./StreamArtistRecoveredIdentityContinuationRows.sol";
import {
    StreamArtistRecoveredIdentityExportEncoding as Encoding
} from "./StreamArtistRecoveredIdentityExportEncoding.sol";

/// @notice Complete original continuation discovery through a fixed typed producer.
/// @dev Complete input encoding precedes every original continuation check and source getter.
/// The worker replaces only the four continuation arrays; all other Bundle fields survive.
library StreamArtistRecoveredIdentityHydrationContinuations {
    // Preserve the original public error surface after moving its checks to the fixed worker.
    error InvalidRecoveredIdentity(bytes32 key);

    function collect(
        uint256[17] memory roots,
        IH.Bundle calldata b,
        RH.OwnerProvenance memory local
    ) public view returns (IH.Bundle memory) {
        bytes memory canonical = abi.encode(b);
        bytes memory fourArrays = Rows.collect(roots, canonical, local);
        bytes memory result = Encoding.replaceContinuations(canonical, fourArrays);
        // The declared return stays the original complete single-Bundle ABI. The join has
        // already produced that encoding, so decoding and re-encoding it would add no checks.
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}
