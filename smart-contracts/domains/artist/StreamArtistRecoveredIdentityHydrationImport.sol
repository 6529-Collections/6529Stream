// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceCodec as Codec
} from "./StreamArtistRecoveredIdentitySourceCodec.sol";
import {
    StreamArtistRecoveredIdentityImportPrincipal as Principal
} from "./StreamArtistRecoveredIdentityImportPrincipal.sol";
import {
    StreamArtistRecoveredIdentityImportRecords as Records
} from "./StreamArtistRecoveredIdentityImportRecords.sol";
import {
    StreamArtistRecoveredIdentityImportAuthority as Authority
} from "./StreamArtistRecoveredIdentityImportAuthority.sol";
import {
    StreamArtistRecoveredIdentityImportRecovery as Recovery
} from "./StreamArtistRecoveredIdentityImportRecovery.sol";
import {
    StreamArtistRecoveredIdentityImportContinuations as Continuations
} from "./StreamArtistRecoveredIdentityImportContinuations.sol";
import {
    StreamArtistRecoveredIdentityImportNonces as Nonces
} from "./StreamArtistRecoveredIdentityImportNonces.sol";
import {
    StreamArtistRecoveredIdentityImportTiming as Timing
} from "./StreamArtistRecoveredIdentityImportTiming.sol";

/// @notice Empty-key typed installation by the fixed host after complete source/cutover admission.
/// @dev Roots are the host's declared 17 slots. Replay aliases, provenance, semantic history
/// prefix and the sole owner/Archive mutation remain the common operation60 worker's duties.
/// This worker never invokes original record producers, emits original events or appends native rows.
library StreamArtistRecoveredIdentityHydrationImport {
    // Preserve the original public ABI after moving the checks to fixed workers.
    error InvalidRecoveredIdentity(bytes32 key);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);
    error RecoveredTimingUnavailable();

    function importEncoded(
        uint256[17] memory roots,
        bytes32 artistId,
        bytes memory raw,
        RH.OwnerProvenance memory provenance
    ) public returns (bytes32 commitment) {
        bytes memory canonical = Codec.decode(raw, provenance);
        Principal.check(roots, artistId, canonical);
        Records.install(roots, canonical);
        Authority.install(roots, canonical);
        Recovery.install(roots, canonical);
        Continuations.install(roots, canonical);
        Nonces.install(roots, canonical);
        Timing.install(roots, canonical);
        Principal.finish(roots, canonical, provenance);
        // Codec.decode already proved raw is exactly abi.encode(IH.SCHEMA, b).
        return keccak256(raw);
    }
}
